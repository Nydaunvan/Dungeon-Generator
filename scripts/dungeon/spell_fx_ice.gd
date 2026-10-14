extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets de glace (Forward+ / Vulkan) : éclat de givre (javelot de cristal, pointes qui jaillissent du sol) et tempête de grêle
## (grêlons qui s'abattent, éclats et givre à chaque impact). Palette cyan et blanc ; la teinte du sort la fait tourner.
## Glace = cristaux à facettes lumineux, brume froide qui rampe au ras du sol, étincelles qui tombent lentement, flocon gravé au sol.

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.55
	if _tier >= 2:
		GLYPHS.frost()
	match str(ctx.get("fx", "ice_shard")):
		"ice_hail":
			_hail(target)
		_:
			_shard_cast(target)

func _key() -> String:
	return str(int(_tint_h * 100.0)) if _tinted else "d"

func _ice_shard_mesh() -> ArrayMesh:
	return _shard_pal("fxi_shard_" + _key(), _c(1.0, 1.0, 1.0), _c(0.7, 0.93, 1.0), _c(0.28, 0.62, 0.95))

## Pointe de cristal debout (prisme hexagonal effilé de hauteur 1, rayon 0,5) : jaillit du sol.
func _spike_mesh() -> ArrayMesh:
	var key := "fxi_spike_" + _key()
	if _shards.has(key):
		return _shards[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cb := _c(0.25, 0.58, 0.95)
	var cm := _c(0.62, 0.9, 1.0)
	var ct := _c(1.0, 1.0, 1.0)
	var ring0: Array = []
	var ring1: Array = []
	for i in 6:
		var a := float(i) / 6.0 * TAU
		ring0.append(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5))
		ring1.append(Vector3(cos(a) * 0.42, 0.62, sin(a) * 0.42))
	var tip := Vector3(0, 1.0, 0)
	for i in 6:
		var j := (i + 1) % 6
		var a0: Vector3 = ring0[i]
		var a1: Vector3 = ring0[j]
		var b0: Vector3 = ring1[i]
		var b1: Vector3 = ring1[j]
		var shade := 0.8 + 0.2 * sin(float(i) * 2.1)
		var cmm := Color(cm.r * shade, cm.g * shade, cm.b * shade, 1.0)
		for tri in [[a0, a1, b0, cb, cb, cmm], [a1, b1, b0, cb, cmm, cmm], [b0, b1, tip, cmm, cmm, ct]]:
			for k in 3:
				st.set_color(tri[3 + k])
				st.add_vertex(tri[k])
	var m := st.commit()
	m.surface_set_material(0, _shard_material())
	_shards[key] = m
	return m

# ------------------------------------------------------------------------------------------ impact

## Impact de glace : éclair, onde de givre, éclats, rubans, étincelles, brume froide, flocon gravé, pointes qui jaillissent.
func _ice_hit(at: Vector3, target: Dictionary, big: float = 1.0, spikes: bool = true) -> void:
	_hit_fx(at, target, {
		"size": big,
		"flash": [_c(0.85, 0.97, 1.0), 1.1],
		"shocks": [[_c(0.6, 0.9, 1.0), 2.6, 0.5], [_c(1.0, 1.0, 1.0), 1.6, 0.3, 0.06]],
		"ground": [_c(0.6, 0.9, 1.0), 3.0, 0.7],
		"shards": {"mesh": _ice_shard_mesh(), "n": 14, "v": [2.0, 5.0], "grav": Vector3(0, -6.0, 0), "sz": [0.18, 0.4]},
		"ribbons": {"c": [_c(1, 1, 1, 1.0), _c(0.6, 0.9, 1.0, 0.9), _c(0.3, 0.6, 1.0, 0.0)], "n": 14, "v": [1.5, 4.0], "grav": Vector3(0, -3.0, 0), "life": 0.7},
		"sparks": {"c": [_c(1, 1, 1, 1.0), _c(0.65, 0.92, 1.0, 0.9), _c(0.4, 0.7, 1.0, 0.0)], "n": 30, "v": [0.4, 2.2], "grav": Vector3(0, -1.2, 0), "life": 1.0},
		"smoke": [
			{"c": [_c(0.7, 0.95, 1.0, 0.0), _c(0.5, 0.85, 1.0, 0.45), _c(0.3, 0.6, 0.95, 0.0)], "n": 6, "sz": [0.8, 1.4], "rise": 0.25, "life": 1.2, "add": true},
			{"c": [_c(0.85, 0.93, 1.0, 0.0), _c(0.78, 0.88, 0.98, 0.4), _c(0.6, 0.72, 0.9, 0.0)], "n": 7, "sz": [0.8, 1.5], "rise": 0.3, "life": 1.7, "y": 0.1},
		],
		"decal": [GLYPHS.frost(), _c(0.7, 0.92, 1.0), 1.3 * big, 1.8],
		"lamp": [_c(0.55, 0.85, 1.0), 2.4, 5.5, 0.6],
		"shake": 0.02 * big,
	})
	if spikes:
		_spikes(at, target, big)

## Pointes de glace qui jaillissent du sol autour du monstre, restent un instant puis éclatent.
func _spikes(at: Vector3, target: Dictionary, big: float) -> void:
	var size := _tsize(target) * big * _s
	var base := Vector3(at.x, 0.02, at.z)
	var mesh := _spike_mesh()
	var mat := _vcol_mat(1.1 * _g)
	var n := 7
	for i in n:
		var ang := float(i) / float(n - 1) * TAU + randf() * 0.4
		var rad := 0.0 if i == 0 else randf_range(0.55, 0.95) * size
		var hh := (1.7 if i == 0 else randf_range(0.7, 1.25)) * size
		var ww := (0.4 if i == 0 else randf_range(0.2, 0.3)) * size
		var tilt := 0.0 if i == 0 else randf_range(0.12, 0.38)
		var delay := 0.0 if i == 0 else randf_range(0.02, 0.1)
		var pos := base + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var mi := _mesh_node(mesh, mat, pos, 1.0)
		mi.rotation = Vector3(sin(ang) * tilt, randf() * TAU, -cos(ang) * tilt)
		mi.scale = Vector3(0.01, 0.01, 0.01)
		var life := 0.95
		_add({"node": mi}, life + delay, func(u: float):
			var t := clampf((u * (life + delay) - delay) / life, 0.0, 1.0)
			var grow := 1.0 - pow(1.0 - clampf(t / 0.14, 0.0, 1.0), 3.0)
			var out := clampf((t - 0.78) / 0.22, 0.0, 1.0)
			mi.scale = Vector3(ww * grow * (1.0 - out), hh * grow * (1.0 - out * 0.6), ww * grow * (1.0 - out))
			mi.visible = t > 0.0 and out < 1.0)
	_later(0.75, func():
		var pm := _pmat(0.5 * size, Vector3.UP, 60.0, 1.0, 3.0, Vector3(0, -6.0, 0), 0.12, 0.28, _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		var sm := _ice_shard_mesh()
		sm.surface_set_material(0, _vcol_mat(1.2 * _g))
		_free_after(_gpu(12, 0.6, true, sm, pm, base + Vector3(0, 0.4, 0)), 0.8))

# ------------------------------------------------------------------------------------------ ÉCLAT DE GIVRE

func _shard_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var dur := clampf(0.34 + start.distance_to(end) * 0.035, 0.38, 0.55)
	var node := Node3D.new()
	var mesh := _ice_shard_mesh()
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _vcol_mat(1.2 * _g)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := float(i) / 3.0 * TAU
		mi.position = Vector3(cos(a), sin(a), 0) * 0.06
		mi.rotation = Vector3(sin(a) * 0.12, cos(a) * 0.12, a)
		mi.scale = Vector3(1.0, 1.0, 2.6 - float(i) * 0.5)
		node.add_child(mi)
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": node, "size": 0.62},
		"halo": [_c(0.55, 0.88, 1.0, 0.55), 1.0],
		"core": 0.1, "arc": 0.1, "lift": 0.08, "ease": "accel", "grow": 0.2, "spin": 14.0,
		"trails": [
			{"c": [_c(0.9, 1.0, 1.0, 0.0), _c(0.7, 0.95, 1.0, 0.9), _c(0.5, 0.8, 1.0, 0.0)], "n": 34, "life": 0.34, "sz": [0.07, 0.16], "v": [0.05, 0.45],
				"grav": Vector3(0, -0.8, 0), "k": 1.3, "radius": 0.09},
			{"c": [_c(0.85, 0.95, 1.0, 0.0), _c(0.78, 0.9, 1.0, 0.35), _c(0.6, 0.75, 0.95, 0.0)], "n": 14, "life": 0.6, "sz": [0.2, 0.4], "v": [0.05, 0.3],
				"grav": Vector3(0, -0.3, 0), "mix": true, "radius": 0.1, "turb": 0.4, "tex": _smoke_puff()},
		],
		"lamp": [_c(0.55, 0.85, 1.0), 1.8, 4.5],
	}, func(): _ice_hit(end, target))

# ------------------------------------------------------------------------------------------ TEMPÊTE DE GRÊLE

func _hail(target: Dictionary) -> void:
	var at := _end_point(target)
	var up := cam.global_transform.basis.y
	var size := _tsize(target) * _s
	# nuage de tempête au-dessus de la cible, flocons qui tournoient
	var cloud := _gpu(10, 1.4, false, _smoke_mesh(Color.WHITE, _smoke_puff()),
		_pmat_grow(1.1 * size, Vector3.UP, 20.0, 0.1, 0.4, Vector3.ZERO, 1.2 * size, 2.0 * size, _ramp(_c(0.75, 0.85, 0.95, 0.0), _c(0.6, 0.72, 0.88, 0.5), _c(0.4, 0.5, 0.7, 0.0)), 0.5, 0.5),
		Vector3(at.x, at.y + 3.4, at.z))
	var snow := _gpu(44, 1.0, false, _soft_mesh(_c(0.85, 0.97, 1.0), 1.3 * _g, _w_spark()),
		_pmat(1.0 * size, Vector3.DOWN, 20.0, 1.5, 3.0, Vector3(0, -1.0, 0), 0.04, 0.09, _ramp(_c(1, 1, 1, 0.0), _c(0.9, 0.98, 1.0, 0.9), _c(0.7, 0.9, 1.0, 0.0)), 0.2, 1.0),
		Vector3(at.x, at.y + 3.0, at.z))
	_later(1.0, func():
		cloud.emitting = false
		snow.emitting = false
		_free_after(cloud, 1.8)
		_free_after(snow, 1.2))
	_lens(at + Vector3(0, 0.0, 0), 0.0, 0.0, 0.0)
	var lamp := _lamp_node(at + Vector3(0, 1.0, 0), _c(0.55, 0.85, 1.0), 1.2 * _g, 7.0)
	_fade_lamp(lamp, 1.3)
	# grêlons : chacun tombe d'en haut sur un point autour de la cible et éclate au sol
	var n := maxi(6, Settings.pc(11))
	for i in n:
		var d := randf() * 0.16 * float(i) * 0.85 + 0.08
		var spot := Vector3(at.x + randf_range(-1.0, 1.0) * size, 0.03, at.z + randf_range(-0.7, 0.7) * size)
		if i == n - 1:
			spot = Vector3(at.x, 0.03, at.z)
		_later(d, func(): _hailstone(spot, target, i == n - 1))
	_shake(0.0, 0.01)

func _hailstone(spot: Vector3, target: Dictionary, last: bool) -> void:
	var start := spot + Vector3(randf_range(-0.4, 0.4), 5.0, randf_range(-0.2, 0.2))
	var dur := 0.26
	var mesh := _ice_shard_mesh()
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _vcol_mat(1.3 * _g)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.0, 1.0, 1.6)
	node.add_child(mi)
	var end := spot + Vector3(0, 0.08, 0)
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": node, "size": 0.5 if not last else 0.8},
		"halo": [_c(0.6, 0.9, 1.0, 0.4), 0.45],
		"arc": 0.0, "lift": 0.0, "ease": "lin", "grow": 0.0, "spin": 6.0,
		"trails": [{"c": [_c(0.9, 1.0, 1.0, 0.0), _c(0.7, 0.95, 1.0, 0.8), _c(0.5, 0.8, 1.0, 0.0)], "n": 14, "life": 0.18, "sz": [0.05, 0.1], "v": [0.0, 0.15], "k": 1.3, "radius": 0.04}],
	}, func():
		if last:
			_ice_hit(Vector3(spot.x, at_height(target), spot.z), target, 1.0, true)
		else:
			_mini_ice(Vector3(spot.x, 0.1, spot.z)))

func at_height(target: Dictionary) -> float:
	return float(target.pos.y) if not target.is_empty() else 0.9

## Petit éclatement d'un grêlon au sol : étincelle, éclats, onde plate, un peu de givre.
func _mini_ice(at: Vector3) -> void:
	_flash(_w_soft(), _hdr(_c(0.85, 0.97, 1.0), 1.1 * _g), at, 0.2, 0.9, 0.18)
	_ground_shock(at, _c(0.7, 0.93, 1.0), 1.2, 0.3)
	var sm := _ice_shard_mesh()
	sm.surface_set_material(0, _vcol_mat(1.2 * _g))
	var pm := _pmat(0.04, Vector3.UP, 70.0, 1.2, 3.0, Vector3(0, -7.0, 0), 0.1, 0.2, _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	_free_after(_gpu(5, 0.5, true, sm, pm, at), 0.7)
	var sp := _pmat(0.05, Vector3.UP, 80.0, 0.6, 2.0, Vector3(0, -1.5, 0), 0.05, 0.1, _ramp(_c(1, 1, 1, 1.0), _c(0.65, 0.92, 1.0, 0.9), _c(0.4, 0.7, 1.0, 0.0)))
	_free_after(_gpu(10, 0.6, true, _soft_mesh(_c(0.8, 0.95, 1.0), 1.4 * _g, _w_spark()), sp, at), 0.8)
	if randf() < 0.6:
		_shake(0.008 * _pw, 0.08)
