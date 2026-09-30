class_name SpellFx3D
extends Node3D
## Effets de sorts en 3D : éclair arcanique, flash sacré, boule de feu (port de castArcaneBolt / castHolyFlash / castFireball).
## Sprites additifs à face caméra, animés par le temps.

const TABLE := {"spell_arc1": "arcane", "spell_holy1": "holy", "spell_fire1": "fire"}

static var _tex: Dictionary = {}

var cam: Camera3D
var _parts: Array = []     # {node, mat, t0, dur, fn}
var _t: float = 0.0

static func has(spell_id: String) -> bool:
	return TABLE.has(spell_id)

static func _radial(key: String, stops: Array) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_tex[key] = t
	return t

static func _arcane_tex() -> Texture2D:
	return _radial("arcane", [[0.0, Color(1, 1, 1, 1)], [0.3, Color(0.85, 0.75, 1, 0.95)], [0.65, Color(0.6, 0.4, 0.95, 0.5)], [1.0, Color(0.5, 0.3, 0.9, 0)]])

static func _holy_tex() -> Texture2D:
	return _radial("holy", [[0.0, Color(1, 1, 1, 1)], [0.3, Color(1, 0.96, 0.78, 0.95)], [0.65, Color(0.91, 0.7, 0.36, 0.55)], [1.0, Color(0.86, 0.63, 0.24, 0)]])

static func _spark_tex() -> Texture2D:
	return _radial("spark", [[0.0, Color(1, 0.98, 0.9, 1)], [1.0, Color(1, 0.86, 0.55, 0)]])

static func _fire_tex() -> Texture2D:
	return _radial("fire", [[0.0, Color(1, 0.98, 0.86, 1)], [0.25, Color(1, 0.78, 0.24, 0.98)], [0.55, Color(1, 0.43, 0.12, 0.85)], [0.8, Color(0.78, 0.16, 0.04, 0.45)], [1.0, Color(0.63, 0.08, 0.02, 0)]])

func _sprite(tex: Texture2D, color: Color, size: float, pos: Vector3) -> Dictionary:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = color
	m.disable_receive_shadows = true
	m.no_depth_test = false
	m.render_priority = 5
	mi.material_override = m
	mi.scale = Vector3(size, size, size)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return {"node": mi, "mat": m}

func _add(p: Dictionary, dur: float, fn: Callable) -> void:
	p["t0"] = _t
	p["dur"] = dur
	p["fn"] = fn
	_parts.append(p)

func _process(delta: float) -> void:
	_t += delta
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		var u := clampf((_t - float(p.t0)) / float(p.dur), 0.0, 1.0)
		p.fn.call(u)
		if u >= 1.0:
			(p.node as Node).queue_free()
			_parts.remove_at(i)
	if _parts.is_empty() and _pending == 0:
		queue_free()

var _pending: int = 0

func _later(sec: float, fn: Callable) -> void:
	_pending += 1
	get_tree().create_timer(sec).timeout.connect(func():
		_pending -= 1
		if is_instance_valid(self):
			fn.call())

## Lance l'effet. `target` = {"pos", "h"} du combattant visé (vide : devant la caméra).
static func cast(host: Node, camera: Camera3D, spell_id: String, target: Dictionary) -> void:
	if not TABLE.has(spell_id) or camera == null:
		return
	var fx := SpellFx3D.new()
	fx.name = "SpellFx"
	fx.cam = camera
	host.add_child(fx)
	match TABLE[spell_id]:
		"arcane": fx._arcane(target)
		"holy": fx._holy(target)
		"fire": fx._fire(target)

func _fwd() -> Vector3:
	return -cam.global_transform.basis.z

func _projectile(start: Vector3, end: Vector3, tex: Texture2D, col: Color, trail_col: Color, size: float, trail_size: float, dur: float, trail_chance: float, spin: bool, on_hit: Callable) -> void:
	var b := _sprite(tex, col, size, start)
	_add(b, dur, func(u: float):
		(b.node as Node3D).position = start.lerp(end, u)
		if spin:
			(b.node as Node3D).rotation.z += 0.25
		if randf() < trail_chance:
			var tr := _sprite(tex, trail_col, trail_size, (b.node as Node3D).position)
			_add(tr, 0.28, func(v: float):
				var s := trail_size * (1.0 - v * 0.5)
				(tr.node as Node3D).scale = Vector3(s, s, s)
				(tr.mat as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - v))
		if u >= 1.0:
			on_hit.call())

func _arcane(target: Dictionary) -> void:
	var start := cam.global_position + _fwd() * 0.5 + Vector3(0, -0.35, 0)
	var end: Vector3 = start + _fwd() * 4.0
	if not target.is_empty():
		end = target.pos + Vector3(0, float(target.h) * 0.35, 0)
	_projectile(start, end, _arcane_tex(), Color("c9a8ff"), Color(0.61, 0.5, 0.83, 0.55), 0.55, 0.32, 0.34, 0.6, true, func():
		var fl := _sprite(_arcane_tex(), Color("e8d0ff"), 0.4, end)
		_add(fl, 0.26, func(v: float):
			var s := 0.4 + v * 1.6
			(fl.node as Node3D).scale = Vector3(s, s, s)
			(fl.mat as StandardMaterial3D).albedo_color.a = 1.0 - v))

func _holy(target: Dictionary) -> void:
	var pos := cam.global_position + _fwd() * 2.0 + Vector3(0, -0.1, 0)
	if not target.is_empty():
		pos = target.pos + Vector3(0, float(target.h) * 0.4, 0)
	var fl := _sprite(_holy_tex(), Color("fff2c8"), 0.15, pos)
	_add(fl, 0.38, func(u: float):
		var s := 0.15 + (u / 0.3) * 1.5 if u < 0.3 else 1.65 - ((u - 0.3) / 0.7) * 1.65
		s = maxf(0.01, s)
		(fl.node as Node3D).scale = Vector3(s, s, s)
		(fl.mat as StandardMaterial3D).albedo_color.a = 1.0 if u < 0.3 else maxf(0.0, 1.0 - (u - 0.3) / 0.7))
	for i in 14:
		var sp := _sprite(_spark_tex(), Color.WHITE, 0.14, pos)
		var ang := randf() * TAU
		var el := (randf() - 0.5) * 0.6
		var spd := 1.6 + randf() * 1.7
		var vel := Vector3(cos(ang) * spd, sin(ang) * spd * 0.5 + el, sin(ang) * spd * 0.4)
		_add(sp, 0.38, func(u: float):
			(sp.node as Node3D).position = pos + vel * (u * 0.38)
			(sp.mat as StandardMaterial3D).albedo_color.a = 1.0 - u)

func _fire(target: Dictionary) -> void:
	var start := cam.global_position + _fwd() * 0.5 + Vector3(0, -0.3, 0)
	var end: Vector3 = start + _fwd() * 4.0
	if not target.is_empty():
		end = target.pos + Vector3(0, float(target.h) * 0.38, 0)
	_projectile(start, end, _fire_tex(), Color("ffcf80"), Color(1, 0.5, 0.19, 0.5), 1.7, 1.35, 0.38, 0.5, false, func():
		var fl := _sprite(_fire_tex(), Color("ffe0a0"), 0.9, end)
		_add(fl, 0.42, func(u: float):
			var s := 0.6 + u * 2.1
			(fl.node as Node3D).scale = Vector3(s, s, s)
			(fl.mat as StandardMaterial3D).albedo_color.a = maxf(0.0, 1.0 - u * 1.3))
		var cols := [Color("ffe8a0"), Color("ffb050"), Color("ff7a30"), Color("ff4d18")]
		for i in 18:
			var bit := _sprite(_fire_tex(), cols[randi() % 4], 0.32, end)
			var ang := randf() * TAU
			var vel := Vector3(cos(ang) * (2.0 + randf() * 2.4), (randf() - 0.3) * 1.2, sin(ang) * (2.0 + randf() * 2.4))
			_add(bit, 0.42, func(u: float):
				(bit.node as Node3D).position = end + vel * (u * 0.42)
				(bit.mat as StandardMaterial3D).albedo_color.a = 1.0 - u))
