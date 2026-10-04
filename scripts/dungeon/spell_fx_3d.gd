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

## Point légèrement devant le sprite (vers la caméra) : les effets additifs ne se découpent pas dans le plan du monstre.
func _toward_cam(p: Vector3) -> Vector3:
	return p + (cam.global_position - p).normalized() * 0.3

static var _shard_mesh: ArrayMesh
static var _ring_tex: Texture2D

## Éclat de cristal (octaèdre allongé, 8 triangles) : pointe blanche, corps violet clair, queue violet profond.
## Orienté le long de -Z ; sans éclairage (vertex colors), donc aucun coût de lumière.
static func _shard() -> ArrayMesh:
	if _shard_mesh != null:
		return _shard_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0, -0.5)
	var tail := Vector3(0, 0, 0.3)
	var w := 0.11
	var ring := [Vector3(w, 0, 0), Vector3(0, w, 0), Vector3(-w, 0, 0), Vector3(0, -w, 0)]
	var c_tip := Color(1, 1, 1, 1)
	var c_mid := Color(0.78, 0.62, 1.0, 1)
	var c_tail := Color(0.42, 0.22, 0.85, 1)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for tri in [[tip, a, b, c_tip, c_mid, c_mid], [tail, b, a, c_tail, c_mid, c_mid]]:
			for k in 3:
				st.set_color(tri[3 + k])
				st.add_vertex(tri[k])
	_shard_mesh = st.commit()
	return _shard_mesh

static func _shard_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

static func _ring_tex_tint(key: String, tint: Color) -> Texture2D:
	return _radial(key, [[0.0, Color(tint, 0)], [0.62, Color(tint, 0)], [0.84, Color(1, 1, 1, 0.95).lerp(Color(tint, 0.95), 0.35)], [0.93, Color(tint, 0.5)], [1.0, Color(tint, 0)]])

static func _ring_texture() -> Texture2D:
	return _radial("ring", [[0.0, Color(0.7, 0.5, 1, 0)], [0.62, Color(0.7, 0.5, 1, 0)], [0.84, Color(0.92, 0.84, 1, 0.95)], [0.93, Color(0.65, 0.42, 1, 0.5)], [1.0, Color(0.5, 0.3, 0.9, 0)]])

static func _fx_mat(tex: Texture2D, particles: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if particles else BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.render_priority = 5
	return m

static func _lite() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")

func _particles(amount: int, life: float, one_shot: bool, mesh: Mesh, ramp: Gradient) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.randomness = 0.5
	p.local_coords = false
	p.fixed_fps = 30
	p.emitting = false
	p.mesh = mesh
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _ramp(c0: Color, c1: Color, c2: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([c0, c1, c2])
	return g

static func _quad(tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _fx_mat(tex, true)
	return q

## Éclat Arcanique : un cristal d'arcane jaillit du bas de l'écran, tournoie, laisse une traînée d'étincelles,
## frappe le CENTRE du monstre et éclate (flash, onde de choc, éclats, étincelles). Tout est en sprites additifs,
## un seul petit maillage et deux émetteurs de particules : très léger (pas de lumière dynamique sur Web / mobile).
func _arcane(target: Dictionary) -> void:
	var fwd := _fwd()
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var start := cam.global_position + fwd * 0.6 - up * 0.42
	var end: Vector3 = start + fwd * 4.0
	if not target.is_empty():
		end = _toward_cam(target.pos)
	var dist := start.distance_to(end)
	var dur := clampf(0.30 + dist * 0.035, 0.34, 0.5)

	# corps du projectile
	var holder := Node3D.new()
	holder.position = start
	add_child(holder)
	var body := MeshInstance3D.new()
	body.mesh = _shard()
	body.material_override = _shard_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.scale = Vector3(1.0, 1.0, 1.0) * 1.35
	holder.add_child(body)
	var halo := _sprite(_arcane_tex(), Color(0.72, 0.55, 1.0, 0.85), 0.8, start)
	var core := _sprite(_arcane_tex(), Color(1, 1, 1, 1), 0.24, start)
	# traînée : étincelles qui restent derrière
	var trail := _particles(26, 0.22, false, _quad(_arcane_tex()), _ramp(Color(0.85, 0.7, 1, 0.0), Color(0.65, 0.45, 1, 0.8), Color(0.4, 0.2, 0.9, 0.0)))
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.05
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.35
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.26
	trail.position = start
	add_child(trail)
	trail.emitting = true
	# petits éclats qui orbitent autour du cristal
	var motes: Array = []
	for i in 3:
		motes.append(_sprite(_spark_tex(), Color(0.85, 0.75, 1.0, 0.9), 0.14, start))
	var arc_amp := 0.28 * (1.0 if randf() < 0.5 else -1.0)
	var spin := 0.0
	var prev := start
	var proj := {"node": holder}
	_add(proj, dur, func(u: float):
		var k := u * u * (1.5 - 0.5 * u)                       # part lentement, accélère vers la cible
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc_amp) + up * (sin(k * PI) * 0.1)
		var dir := (pos - prev)
		if dir.length() > 0.0001:
			holder.look_at(pos + dir.normalized(), up)
		prev = pos
		holder.position = pos
		spin += 0.5
		body.rotation.z = spin
		(halo.node as Node3D).position = pos
		(core.node as Node3D).position = pos
		trail.position = pos
		var pulse := 1.0 + sin(spin * 1.7) * 0.12
		(halo.node as Node3D).scale = Vector3.ONE * 0.8 * pulse
		for i in motes.size():
			var ang := spin * 1.3 + float(i) * TAU / 3.0
			var rad := 0.17 * (1.0 - u * 0.4)
			(motes[i].node as Node3D).position = pos + right * cos(ang) * rad + up * sin(ang) * rad
		if u >= 1.0:
			holder.queue_free()
			trail.emitting = false
			get_tree().create_timer(0.45).timeout.connect(trail.queue_free)
			for m in motes:
				(m.node as Node).queue_free()
			(halo.node as Node).queue_free()
			(core.node as Node).queue_free()
			_arcane_burst(end, target))

func _arcane_burst(at: Vector3, target: Dictionary) -> void:
	var size := 1.0
	if not target.is_empty():
		size = clampf(float(target.get("w", 1.0)) * 0.55, 0.7, 1.6)
	# flash blanc-violet
	var fl := _sprite(_arcane_tex(), Color(0.95, 0.88, 1.0, 1.0), 0.5 * size, at)
	_add(fl, 0.28, func(v: float):
		var sc := (0.5 + v * 2.3) * size
		(fl.node as Node3D).scale = Vector3.ONE * sc
		(fl.mat as StandardMaterial3D).albedo_color.a = (1.0 - v) * (1.0 - v))
	# onde de choc
	var ring := _sprite(_ring_texture(), Color(1, 1, 1, 0.95), 0.4 * size, at)
	(ring.mat as StandardMaterial3D).no_depth_test = true
	_add(ring, 0.38, func(v: float):
		var e := 1.0 - pow(1.0 - v, 3.0)
		(ring.node as Node3D).scale = Vector3.ONE * (0.4 + e * 1.9) * size
		(ring.mat as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - v))
	# éclats de cristal projetés
	var shards := _particles(10, 0.55, true, _shard(), _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
	(shards.mesh as ArrayMesh).surface_set_material(0, _shard_material())
	shards.position = at
	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shards.emission_sphere_radius = 0.05
	shards.direction = Vector3.UP
	shards.spread = 180.0
	shards.initial_velocity_min = 2.0 * size
	shards.initial_velocity_max = 4.2 * size
	shards.gravity = Vector3(0, -4.5, 0)
	shards.angle_min = -180.0
	shards.angle_max = 180.0
	shards.scale_amount_min = 0.18
	shards.scale_amount_max = 0.38
	shards.scale_amount_curve = _shrink_curve()
	shards.particle_flag_align_y = false
	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0
	add_child(shards)
	shards.emitting = true
	# étincelles
	var sparks := _particles(_spark_count(), 0.5, true, _quad(_spark_tex()), _ramp(Color(1, 0.95, 1, 1), Color(0.78, 0.6, 1, 0.9), Color(0.5, 0.3, 1, 0)))
	sparks.position = at
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.06
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.2 * size
	sparks.initial_velocity_max = 3.4 * size
	sparks.gravity = Vector3(0, -1.2, 0)
	sparks.scale_amount_min = 0.08
	sparks.scale_amount_max = 0.18
	sparks.scale_amount_curve = _shrink_curve()
	add_child(sparks)
	sparks.emitting = true
	# lueur dynamique brève (desktop uniquement)
	if not _lite():
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(0.7, 0.5, 1.0)
		lamp.omni_range = 5.0
		lamp.light_energy = 2.2
		lamp.shadow_enabled = false
		lamp.position = at
		add_child(lamp)
		var tw := create_tween()
		tw.tween_property(lamp, "light_energy", 0.0, 0.3)
		tw.tween_callback(lamp.queue_free)
	_later(0.8, func(): pass)   # garde le nœud en vie le temps que les particules finissent
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(shards): shards.queue_free()
		if is_instance_valid(sparks): sparks.queue_free())

static func _spark_count() -> int:
	return 14 if _lite() else 26

static func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	return c


# =====================================================================================================
# BOULE DE FEU : grosse sphère de flammes orange qui fonce en laissant une queue de comète et des braises ;
# explosion rouge-orangé qui gonfle, braises qui montent, fumée sombre. Chaleur : tout en orange / rouge.
# =====================================================================================================

static var _smoke_t: Texture2D
static var _rays_t: Texture2D
static var _beam_t: Texture2D

static func _smoke_tex() -> Texture2D:
	if _smoke_t == null:
		_smoke_t = _radial("smoke", [[0.0, Color(0.16, 0.12, 0.1, 0.55)], [0.6, Color(0.1, 0.08, 0.07, 0.3)], [1.0, Color(0.08, 0.06, 0.05, 0)]])
	return _smoke_t

func _fire(target: Dictionary) -> void:
	var fwd := _fwd()
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var start := cam.global_position + fwd * 0.6 - up * 0.4 + right * 0.15
	var end: Vector3 = start + fwd * 4.0
	if not target.is_empty():
		end = _toward_cam(target.pos)
	var dist := start.distance_to(end)
	var dur := clampf(0.36 + dist * 0.035, 0.4, 0.58)
	var orb := _sprite(_fire_tex(), Color(1.0, 0.8, 0.45, 1.0), 1.0, start)
	var core := _sprite(_fire_tex(), Color(1.0, 0.97, 0.8, 1.0), 0.5, start)
	# queue de comète : langues de flamme qui restent derrière, montent un peu et s'éteignent
	var tail := _particles(34, 0.38, false, _quad(_fire_tex()), _ramp(Color(1, 0.9, 0.5, 0.0), Color(1, 0.5, 0.12, 0.85), Color(0.5, 0.06, 0.02, 0.0)))
	tail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	tail.emission_sphere_radius = 0.12
	tail.direction = Vector3.UP
	tail.spread = 60.0
	tail.initial_velocity_min = 0.2
	tail.initial_velocity_max = 0.7
	tail.gravity = Vector3(0, 0.9, 0)
	tail.scale_amount_min = 0.3
	tail.scale_amount_max = 0.55
	tail.scale_amount_curve = _shrink_curve()
	tail.position = start
	add_child(tail)
	tail.emitting = true
	var embers := _particles(16, 0.5, false, _quad(_spark_tex()), _ramp(Color(1, 0.95, 0.7, 1), Color(1, 0.6, 0.2, 0.9), Color(1, 0.3, 0.05, 0)))
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.1
	embers.spread = 180.0
	embers.initial_velocity_min = 0.3
	embers.initial_velocity_max = 1.1
	embers.gravity = Vector3(0, 0.6, 0)
	embers.scale_amount_min = 0.05
	embers.scale_amount_max = 0.11
	embers.position = start
	add_child(embers)
	embers.emitting = true
	var seed_f := randf() * TAU
	var proj := {"node": orb.node}
	var prev := start
	_add(proj, dur, func(u: float):
		var k := u * u * (1.6 - 0.6 * u)
		var pos := start.lerp(end, k) + up * (sin(k * PI) * 0.18)     # légère cloche : la boule « retombe » sur la cible
		prev = pos
		var fl := 1.0 + sin(u * 38.0 + seed_f) * 0.08 + sin(u * 61.0) * 0.05
		(orb.node as Node3D).position = pos
		(orb.node as Node3D).scale = Vector3.ONE * (1.0 + 0.35 * k) * fl
		(core.node as Node3D).position = pos
		(core.node as Node3D).scale = Vector3.ONE * (0.5 + 0.2 * k) * fl
		(orb.node as Node3D).rotation.z += 0.12
		tail.position = pos
		embers.position = pos
		if u >= 1.0:
			(orb.node as Node).queue_free()
			(core.node as Node).queue_free()
			tail.emitting = false
			embers.emitting = false
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(tail): tail.queue_free()
				if is_instance_valid(embers): embers.queue_free())
			_fire_burst(end, target))

func _fire_burst(at: Vector3, target: Dictionary) -> void:
	var size := 1.0
	if not target.is_empty():
		size = clampf(float(target.get("w", 1.0)) * 0.6, 0.75, 1.7)
	# éclair blanc-jaune
	var fl := _sprite(_fire_tex(), Color(1.0, 0.95, 0.7, 1.0), 0.6 * size, at)
	_add(fl, 0.22, func(v: float):
		(fl.node as Node3D).scale = Vector3.ONE * (0.6 + v * 2.2) * size
		(fl.mat as StandardMaterial3D).albedo_color.a = (1.0 - v) * (1.0 - v))
	# boule de feu qui gonfle : trois nuées décalées qui s'étendent puis rougissent
	for i in 3:
		var off := Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.25), 0.0) * size
		var b := _sprite(_fire_tex(), Color(1.0, 0.7, 0.3, 0.95), 0.7 * size, at + off)
		var delay := 0.04 * i
		_add(b, 0.5, func(v: float):
			var w := clampf((v - delay) / (1.0 - delay), 0.0, 1.0)
			(b.node as Node3D).scale = Vector3.ONE * (0.7 + (1.0 - pow(1.0 - w, 2.0)) * 2.0) * size * (1.0 - 0.12 * i)
			var col := Color(1.0, 0.75, 0.35).lerp(Color(0.75, 0.15, 0.04), w)
			col.a = 0.95 * (1.0 - w * w)
			(b.mat as StandardMaterial3D).albedo_color = col)
	# onde de chaleur
	var ring := _sprite(_ring_tex_tint("ring_fire", Color(1.0, 0.45, 0.1)), Color(1, 1, 1, 0.9), 0.4 * size, at)
	(ring.mat as StandardMaterial3D).no_depth_test = true
	_add(ring, 0.4, func(v: float):
		(ring.node as Node3D).scale = Vector3.ONE * (0.4 + (1.0 - pow(1.0 - v, 3.0)) * 2.4) * size
		(ring.mat as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - v))
	# flammèches projetées + braises qui montent
	var chunks := _particles(12 if _lite() else 18, 0.5, true, _quad(_fire_tex()), _ramp(Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0.9), Color(0.4, 0.05, 0.02, 0)))
	chunks.position = at
	chunks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chunks.emission_sphere_radius = 0.1
	chunks.direction = Vector3.UP
	chunks.spread = 180.0
	chunks.initial_velocity_min = 1.5 * size
	chunks.initial_velocity_max = 3.6 * size
	chunks.gravity = Vector3(0, -2.5, 0)
	chunks.scale_amount_min = 0.22
	chunks.scale_amount_max = 0.42
	chunks.scale_amount_curve = _shrink_curve()
	add_child(chunks)
	chunks.emitting = true
	var rising := _particles(14 if _lite() else 24, 0.9, true, _quad(_spark_tex()), _ramp(Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.15, 0.85), Color(0.9, 0.2, 0.05, 0)))
	rising.position = at
	rising.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rising.emission_sphere_radius = 0.2 * size
	rising.direction = Vector3.UP
	rising.spread = 70.0
	rising.initial_velocity_min = 0.6
	rising.initial_velocity_max = 1.8
	rising.gravity = Vector3(0, 0.8, 0)
	rising.scale_amount_min = 0.05
	rising.scale_amount_max = 0.12
	add_child(rising)
	rising.emitting = true
	# fumée sombre (alpha normal, pas additive) : donne du poids à l'explosion
	for i in (2 if _lite() else 4):
		var sm := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		sm.mesh = q
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		smat.billboard_keep_scale = true
		smat.albedo_texture = _smoke_tex()
		smat.render_priority = 4
		sm.material_override = smat
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var base := at + Vector3(randf_range(-0.25, 0.25), randf_range(-0.1, 0.2), 0.0) * size
		sm.position = base
		add_child(sm)
		var smp := {"node": sm, "mat": smat}
		var d0 := 0.1 + 0.05 * i
		_add(smp, 0.8, func(v: float):
			var w := clampf((v - d0) / (1.0 - d0), 0.0, 1.0)
			sm.position = base + Vector3(0, w * 0.9, 0)
			sm.scale = Vector3.ONE * (0.6 + w * 1.4) * size
			smat.albedo_color = Color(1, 1, 1, sin(w * PI) * 0.75))
	if not _lite():
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.55, 0.2)
		lamp.omni_range = 6.0
		lamp.light_energy = 3.0
		lamp.position = at
		add_child(lamp)
		var tw := create_tween()
		tw.tween_property(lamp, "light_energy", 0.0, 0.45)
		tw.tween_callback(lamp.queue_free)
	_later(1.0, func(): pass)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(chunks): chunks.queue_free()
		if is_instance_valid(rising): rising.queue_free())

# =====================================================================================================
# FLASH SACRÉ : pas de projectile. Un pilier de lumière dorée tombe du ciel sur la cible, un cercle sacré
# s'ouvre au sol, des rais d'étoile tournent, des particules d'or s'élèvent. Tout est doré / blanc, vertical.
# =====================================================================================================

static func _rays_tex() -> Texture2D:
	if _rays_t == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var dx := (float(x) + 0.5) / n * 2.0 - 1.0
				var dy := (float(y) + 0.5) / n * 2.0 - 1.0
				var r := sqrt(dx * dx + dy * dy)
				var ang := atan2(dy, dx)
				var rays := pow(absf(cos(ang * 4.0)), 28.0) * 0.9 + pow(absf(cos(ang * 4.0 + PI * 0.25)), 60.0) * 0.35
				var fall := clampf(1.0 - r, 0.0, 1.0)
				var glow := pow(fall, 2.2) * 0.9
				var a := clampf(rays * pow(fall, 1.4) + glow, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.93, 0.7, a))
		_rays_t = ImageTexture.create_from_image(img)
	return _rays_t

static func _beam_tex() -> Texture2D:
	if _beam_t == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 0.5, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 0.85, 0.5, 0), Color(1, 0.88, 0.55, 0.5), Color(1, 1, 0.95, 1), Color(1, 0.88, 0.55, 0.5), Color(1, 0.85, 0.5, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_LINEAR
		t.fill_from = Vector2(0, 0.5)
		t.fill_to = Vector2(1, 0.5)
		t.width = 128
		t.height = 8
		_beam_t = t
	return _beam_t

func _holy(target: Dictionary) -> void:
	var at := cam.global_position + _fwd() * 2.0
	if not target.is_empty():
		at = _toward_cam(target.pos)
	var size := 1.0
	if not target.is_empty():
		size = clampf(float(target.get("w", 1.0)) * 0.6, 0.75, 1.6)
	var floor_y := 0.04
	var top := at.y + 4.5
	# pilier de lumière : s'abat du haut puis s'élargit et s'éteint
	var beam := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2.ONE
	beam.mesh = bq
	var bm := _fx_mat(_beam_tex(), false)
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bm.no_depth_test = true
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(at.x, top, at.z)
	add_child(beam)
	var bp := {"node": beam, "mat": bm}
	_add(bp, 0.62, func(u: float):
		var drop := clampf(u / 0.2, 0.0, 1.0)
		var bottom := lerpf(top, floor_y, 1.0 - pow(1.0 - drop, 3.0))
		var h := top - bottom
		beam.position = Vector3(at.x, (top + bottom) * 0.5, at.z)
		var wide := (0.5 + clampf((u - 0.18) / 0.5, 0.0, 1.0) * 0.6) * size
		beam.scale = Vector3(wide, h, 1.0)
		var a := 1.0 if u < 0.35 else maxf(0.0, 1.0 - (u - 0.35) / 0.65)
		bm.albedo_color = Color(1, 1, 1, a))
	# cercle sacré au sol (anneau horizontal) + disque de lumière
	var ring := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2.ONE
	ring.mesh = rq
	var rm := _fx_mat(_ring_tex_tint("ring_holy", Color(1.0, 0.8, 0.35)), false)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.no_depth_test = true
	ring.material_override = rm
	ring.rotation.x = -PI * 0.5
	ring.position = Vector3(at.x, floor_y + 0.02, at.z)
	add_child(ring)
	var rp := {"node": ring, "mat": rm}
	_add(rp, 0.7, func(u: float):
		var e := 1.0 - pow(1.0 - clampf(u / 0.7, 0.0, 1.0), 3.0)
		ring.scale = Vector3.ONE * (0.4 + e * 2.1) * size
		rm.albedo_color = Color(1, 1, 1, (1.0 - u) * 0.95))
	# flash + étoile à rais qui tourne, centrés sur le corps de la cible
	var flash := _sprite(_holy_tex(), Color(1.0, 0.96, 0.8, 1.0), 0.3, at)
	_add(flash, 0.4, func(u: float):
		var sc := (0.3 + (u / 0.3) * 1.7 if u < 0.3 else 2.0 - ((u - 0.3) / 0.7) * 1.2) * size
		(flash.node as Node3D).scale = Vector3.ONE * maxf(0.01, sc)
		(flash.mat as StandardMaterial3D).albedo_color.a = 1.0 if u < 0.3 else maxf(0.0, 1.0 - (u - 0.3) / 0.7))
	var star := _sprite(_rays_tex(), Color(1.0, 0.92, 0.65, 0.95), 1.0, at)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, 0.6, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.6 + u * 2.4) * size
		(star.node as Node3D).rotation.z = u * 0.9
		(star.mat as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - u) * minf(1.0, u * 8.0))
	# particules d'or qui s'élèvent autour de la cible
	var motes := _particles(14 if _lite() else 26, 0.8, true, _quad(_spark_tex()), _ramp(Color(1, 0.97, 0.8, 0), Color(1, 0.85, 0.45, 0.95), Color(1, 0.7, 0.25, 0)))
	motes.position = Vector3(at.x, floor_y + 0.1, at.z)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.55 * size
	motes.direction = Vector3.UP
	motes.spread = 15.0
	motes.initial_velocity_min = 0.8
	motes.initial_velocity_max = 2.2
	motes.gravity = Vector3(0, 0.3, 0)
	motes.scale_amount_min = 0.06
	motes.scale_amount_max = 0.15
	add_child(motes)
	motes.emitting = true
	if not _lite():
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.88, 0.55)
		lamp.omni_range = 6.0
		lamp.light_energy = 2.6
		lamp.position = at + Vector3(0, 0.5, 0)
		add_child(lamp)
		var tw := create_tween()
		tw.tween_property(lamp, "light_energy", 0.0, 0.6)
		tw.tween_callback(lamp.queue_free)
	_later(1.0, func(): pass)
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(motes): motes.queue_free())
