extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets de barde (Forward+ / Vulkan) : notes qui filent, portées de lumière, ondes sonores et runes.
## Souffle du guerrier (vent et notes), note perçante (lance sonore), armure de vers (runes et dôme de bronze), cri de guerre (ondes qui
## balaient la vue), lame de l'épopée (épée spectrale), berceuse (lune, étoiles et brume de rêve), ballade protectrice (bulle bleue,
## cordes de harpe), requiem de vigueur (portée dorée qui traverse le groupe), mélodie de dissipation (carillon qui brise les maux).

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.95
	if _tier >= 2:
		_rune_tex()
	match str(ctx.get("fx", "bard_pierce")):
		"bard_breath": _breath(ctx)
		"bard_armor": _armor(ctx)
		"bard_warcry": _warcry(target, ctx)
		"bard_epic": _epic(ctx)
		"bard_lullaby": _lullaby(target, ctx)
		"bard_ballad": _ballad(ctx)
		"bard_requiem": _requiem(ctx)
		"bard_dispel": _dispel_song(ctx)
		_: _pierce(target)

func _ally_at(ctx: Dictionary, depth: float = 2.0) -> Vector3:
	return _slot_pos(int(ctx.get("ally", ctx.get("caster", 1))), depth)

## Note de musique lumineuse (quad à face caméra).
func _note_body(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _note_tex()
	m.albedo_color = _hdr(col, 1.05 * _g)
	m.disable_receive_shadows = true
	m.no_depth_test = true
	m.render_priority = 6
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Notes qui tournent autour de `at` en montant (`n` notes, rayon `rad`, montée `rise`), pendant `dur`.
func _notes_orbit(at: Vector3, col: Color, n: int, rad: float, rise: float, dur: float, size: float = 0.26, delay: float = 0.0) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	for i in n:
		var s := _sprite(_note_tex(), _hdr(col, 1.4 * _g), size * _s, at)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var ph := float(i) / float(n) * TAU
		var dl := delay + 0.08 * float(i)
		var total := dur + dl
		_add(s, total, func(u: float):
			var w := clampf((u * total - dl) / dur, 0.0, 1.0)
			var a := ph + w * 5.0
			(s.node as Node3D).position = at + right * cos(a) * rad + up * (sin(a) * rad * 0.35 + w * rise - 0.2)
			(s.node as Node3D).rotation.z = sin(a) * 0.3
			(s.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.98)

## Notes qui jaillissent d'un point et retombent doucement (impacts).
func _notes_burst(at: Vector3, col: Color, n: int, spread: float, size: float = 0.26) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	for i in n:
		var s := _sprite(_note_tex(), _hdr(col, 1.4 * _g), size * _s, at)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var ang := randf() * TAU
		var vel := Vector3(cos(ang), sin(ang) * 0.8 + 0.5, 0.0) * randf_range(0.9, 1.6) * spread
		_add(s, 0.8, func(u: float):
			(s.node as Node3D).position = at + right * vel.x * u * 0.7 + up * (vel.y * u * 0.7 + u * u * 0.2)
			(s.node as Node3D).rotation.z = ang * 0.2 + u * 1.2
			(s.mat as StandardMaterial3D).albedo_color.a = 1.0 - u * u)

## Portée : cinq lignes de lumière qui se dessinent horizontalement autour de `at`.
func _staff(at: Vector3, width: float, col: Color, dur: float, gap: float = 0.13) -> void:
	var up := cam.global_transform.basis.y
	for i in 5:
		_streak(at + up * (float(i) - 2.0) * gap, 0.0, width, col, dur, 0.04 * float(i), 0.008, 0.0)

# ------------------------------------------------------------------------------------------ NOTE PERÇANTE

func _pierce(target: Dictionary) -> void:
	_base_hue = 0.12
	var start := _start_point()
	var end := _end_point(target)
	var gold := _c(1.0, 0.85, 0.4)
	var hot := _c(1.0, 0.97, 0.85)
	var deep := _c(0.9, 0.5, 0.2)
	var dur := clampf(0.3 + start.distance_to(end) * 0.03, 0.34, 0.5)
	for i in 5:
		var tt := 0.1 + 0.16 * float(i)
		_later(dur * tt, func(): _shock(start.lerp(end, tt), gold, 0.9 + 0.5 * float(i), 0.3))
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": _note_body(gold.lerp(hot, 0.25)), "size": 0.45},
		"halo": [Color(gold, 0.55), 1.1], "core": 0.1,
		"arc": 0.05, "lift": 0.05, "ease": "accel", "grow": 0.2, "orient": false,
		"trails": [{"c": [Color(hot, 0.0), Color(gold, 0.9), Color(deep, 0.0)], "n": 36, "life": 0.3, "sz": [0.06, 0.15], "v": [0.05, 0.35], "k": 1.4, "radius": 0.06}],
		"lamp": [gold, 1.6, 4.5],
	}, func():
		var size := _tsize(target) * _s
		_flash(_w_soft(), _hdr(hot, 1.2 * _g), end, 0.3, 1.7, 0.28)
		_flare4(end, hot, 3.0 * size, 0.4, 0.0)
		for k in 6:
			_streak(end, float(k) / 6.0 * PI, 2.4 * size, gold if k % 2 == 0 else hot, 0.22, 0.0, 0.045, 0.0)
		_notes_burst(end, gold, 4, 1.1)
		_hit_fx(end, target, {
			"size": 0.9,
			"shocks": [[gold, 2.4, 0.4], [hot, 1.5, 0.28, 0.06]],
			"lens": [2.8, 0.08],
			"sparks": {"c": [Color(hot, 1.0), Color(gold, 0.9), Color(deep, 0.0)], "n": 26, "v": [1.0, 3.4], "grav": Vector3(0, -1.5, 0), "life": 0.7},
			"lamp": [gold, 2.0, 5.0, 0.4],
			"shake": 0.02}))

# ------------------------------------------------------------------------------------------ SOUFFLE DU GUERRIER

func _breath(ctx: Dictionary) -> void:
	_base_hue = 0.45
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var hot := _c(0.88, 1.0, 0.95)
	var mid := _c(0.4, 0.95, 0.78)
	var deep := _c(0.1, 0.6, 0.55)
	_flash(_w_soft(), _hdr(mid, 1.0 * _g), at, 0.5, 2.0, 0.55, true)
	_pillar(at - up * 1.0, 1.6, 3.0, SH_PILLAR, "pillar", {"col": mid, "core": hot, "power": 0.45 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.2}, 1.1,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("fade", sin(u * PI) * 0.85))
	# souffle : bouffées claires qui montent en s'élargissant, hélice de vent
	var puffs := _gpu(26, 0.9, true, _soft_mesh(mid, 0.6 * _g, _flame_puff()),
		_pmat_grow(0.3, Vector3.UP, 20.0, 0.8, 1.6, Vector3(0, 0.4, 0), 0.5, 0.9, _ramp(Color(hot, 0.0), Color(mid, 0.5), Color(deep, 0.0)), 0.6, 0.8), at - up * 0.5)
	_free_after(puffs, 1.1)
	_helix(at - up * 0.6, [Color(hot, 0.0), Color(mid, 0.95), Color(deep, 0.0)], 0.5, 1.6, 1.8, 42, 0.8)
	_notes_orbit(at, hot.lerp(mid, 0.3), 5, 0.55, 1.5, 0.9)
	_shock(at, mid, 1.8, 0.5)
	_later(0.12, func(): _shock(at, hot, 1.2, 0.4))
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, mid, 1.5 * _g, 4.0), 0.7)

# ------------------------------------------------------------------------------------------ ARMURE DE VERS

func _armor(ctx: Dictionary) -> void:
	_base_hue = 0.08
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var bronze := _c(1.0, 0.62, 0.25)
	var hot := _c(1.0, 0.92, 0.7)
	var deep := _c(0.7, 0.3, 0.1)
	_flash(_w_soft(), _hdr(bronze, 1.0 * _g), at, 0.5, 2.0, 0.55, true)
	_dome(at + up * 0.1, 0.78, bronze, 1.7, 0.75)
	# anneau de runes qui tourne derrière le héros et se resserre
	var rn := _sprite(_rune_tex(), _hdr(bronze, 1.1 * _g), 3.0, at - _fwd() * 0.15)
	(rn.mat as StandardMaterial3D).no_depth_test = true
	_add(rn, 1.5, func(u: float):
		(rn.node as Node3D).scale = Vector3.ONE * lerpf(3.4, 2.2, 1.0 - pow(1.0 - minf(u * 3.0, 1.0), 3.0))
		(rn.node as Node3D).rotation.z = u * 2.4
		(rn.mat as StandardMaterial3D).albedo_color.a = minf(u * 8.0, 1.0) * (1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)) * 0.9)
	# six plaques d'armure : arcs de lumière qui se posent autour du héros
	for k in 6:
		var a := float(k) / 6.0 * TAU
		var p := at + cam.global_transform.basis.x * cos(a) * 0.62 + up * sin(a) * 0.62
		_streak(p, a + PI * 0.5, 0.75, hot.lerp(bronze, 0.4), 0.45, 0.07 * float(k), 0.12, 0.35)
	_helix(at - up * 0.55, [Color(hot, 0.0), Color(bronze, 0.95), Color(deep, 0.0)], 0.65, 1.0, 1.4, 34, 0.9)
	_notes_orbit(at, hot, 4, 0.7, 0.9, 1.0, 0.22)
	_shock(at, bronze, 2.0, 0.55)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, bronze, 1.5 * _g, 4.0), 0.8)

# ------------------------------------------------------------------------------------------ CRI DE GUERRE

func _warcry(target: Dictionary, ctx: Dictionary) -> void:
	_base_hue = 0.03
	var src := _caster_anchor(2.2, 0.7)
	var red := _c(1.0, 0.35, 0.15)
	var hot := _c(1.0, 0.85, 0.6)
	var deep := _c(0.7, 0.1, 0.05)
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty():
		pts = [target]
	_flash(_w_soft(), _hdr(Color(red, 0.8), 0.9 * _g), src, 0.4, 1.4, 0.5, true)
	for i in 4:
		_later(0.09 * float(i), func(): _shock(src, red.lerp(hot, 0.2 * float(i)), 2.0 + 1.6 * float(i), 0.7))
	for k in 9:
		var a := lerpf(0.35, PI - 0.35, float(k) / 8.0)
		_streak(src + Vector3(0, 0.2, 0), a, 2.4, red.lerp(hot, randf() * 0.5), 0.35, 0.02 * float(k), 0.07, 0.0)
	_shake(0.045 * _pw, 0.45)
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.3 + 0.08 * float(i), func():
			var at := _end_point(tt)
			var size := _tsize(tt) * _s
			_shock(at, red, 2.6 * size, 0.5)
			_ground_shock(Vector3(at.x, 0.05, at.z), red, 3.0 * size, 0.6)
			_hit_fx(at, tt, {
				"size": 0.9,
				"flash": [hot, 1.0],
				"lens": [3.4, 0.11],
				"sparks": {"c": [Color(hot, 1.0), Color(red, 0.9), Color(deep, 0.0)], "n": 24, "v": [1.0, 3.4], "grav": Vector3(0, -1.0, 0), "life": 0.7},
				"smoke": [{"c": [Color(0.5, 0.4, 0.3, 0.0), Color(0.34, 0.28, 0.22, 0.4), Color(0.1, 0.08, 0.06, 0.0)], "n": 6, "sz": [0.6, 1.0], "rise": 0.4, "life": 1.0, "y": -0.5}],
				"lamp": [red, 2.0, 5.0, 0.4]}))
		i += 1

# ------------------------------------------------------------------------------------------ LAME DE L'ÉPOPÉE

func _epic(ctx: Dictionary) -> void:
	_base_hue = 0.1
	var at := _slot_pos(int(ctx.get("caster", 1)), 2.1)
	var up := cam.global_transform.basis.y
	var gold := _c(1.0, 0.8, 0.35)
	var hot := _c(1.0, 0.97, 0.85)
	var deep := _c(0.9, 0.45, 0.15)
	_flash(_w_soft(), _hdr(gold, 1.0 * _g), at, 0.5, 2.2, 0.7, true)
	var rn := _sprite(_rune_tex(), _hdr(gold, 1.0 * _g), 3.0, at - _fwd() * 0.15)
	(rn.mat as StandardMaterial3D).no_depth_test = true
	_add(rn, 1.5, func(u: float):
		(rn.node as Node3D).scale = Vector3.ONE * (2.4 + u * 0.8)
		(rn.node as Node3D).rotation.z = -u * 1.8
		(rn.mat as StandardMaterial3D).albedo_color.a = sin(u * PI) * 0.85)
	var blade_c := at + up * 0.95
	_streak(blade_c, 1.5708, 3.0, gold, 0.9, 0.0, 0.05, 0.0)
	_streak(blade_c, 1.5708, 2.8, hot, 0.8, 0.04, 0.02, 0.0)
	_streak(at + up * 0.0, 0.0, 1.2, gold, 0.8, 0.2, 0.05, 0.0)
	_later(0.3, func():
		_flare4(blade_c + up * 1.0, hot, 1.8, 0.7, 0.0)
		_helix(at - up * 0.3, [Color(hot, 0.0), Color(gold, 0.95), Color(deep, 0.0)], 0.35, 1.8, 1.4, 34, 0.7))
	_notes_orbit(at + up * 0.6, hot.lerp(gold, 0.3), 5, 0.6, 1.2, 1.0)
	_shock(at, gold, 2.2, 0.5)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, gold, 1.8 * _g, 4.5), 0.9)

# ------------------------------------------------------------------------------------------ BERCEUSE

func _lullaby(target: Dictionary, ctx: Dictionary) -> void:
	_base_hue = 0.66
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty() and not target.is_empty():
		pts = [target]
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var hot := _c(0.85, 0.88, 1.0)
	var mid := _c(0.4, 0.45, 1.0)
	var deep := _c(0.15, 0.12, 0.6)
	var base := _caster_anchor(2.4, 0.7)
	for i in 3:
		_later(0.18 * float(i), func(): _shock(base, mid.lerp(hot, 0.2 * float(i)), 2.6 + 1.0 * float(i), 1.0))
	_flash(_w_soft(), _hdr(Color(mid, 0.7), 0.2 * _g), base, 0.8, 2.6, 0.7, true)
	_notes_orbit(base + up * 0.5, hot, 5, 1.2, 1.2, 1.4, 0.3)
	for t in pts:
		var tt: Dictionary = t
		var at := _toward_cam(tt.pos) + up * float(tt.get("h", 1.0)) * 0.25
		var size := _tsize(tt) * _s
		# lune qui se lève au-dessus du monstre
		var moon := _sprite(_crescent_tex(), _hdr(hot, 1.0 * _g), 0.8, at + up * 0.9)
		(moon.mat as StandardMaterial3D).no_depth_test = true
		_add(moon, 1.7, func(u: float):
			(moon.node as Node3D).position = at + up * (0.9 + u * 0.3)
			(moon.node as Node3D).scale = Vector3.ONE * (0.5 + 0.5 * minf(u * 4.0, 1.0)) * 0.9 * size
			(moon.node as Node3D).rotation.z = 0.4
			(moon.mat as StandardMaterial3D).albedo_color.a = sin(u * PI) * 0.95)
		# étoiles qui scintillent autour
		for k in 6:
			var st := _sprite(_flare4_tex(), _hdr(hot, 1.2 * _g), 0.2, at)
			(st.mat as StandardMaterial3D).no_depth_test = true
			var pos := at + right * randf_range(-0.7, 0.7) * size + up * randf_range(0.2, 1.2) * size
			var ph := randf() * TAU
			var dl := randf() * 0.5
			_add(st, 1.3 + dl, func(u: float):
				var w := clampf((u * (1.3 + dl) - dl) / 1.3, 0.0, 1.0)
				(st.node as Node3D).position = pos + up * w * 0.15
				(st.node as Node3D).scale = Vector3.ONE * (0.12 + 0.14 * (0.5 + 0.5 * sin(w * 14.0 + ph)))
				(st.mat as StandardMaterial3D).albedo_color.a = sin(w * PI))
		# brume de rêve qui descend sur le monstre
		var mist := _gpu(16, 1.4, true, _soft_mesh(mid, 0.5 * _g, _flame_puff()),
			_pmat_grow(0.5 * size, Vector3.DOWN, 20.0, 0.1, 0.4, Vector3(0, -0.1, 0), 0.6 * size, 1.1 * size, _ramp(Color(hot, 0.0), Color(mid, 0.45), Color(deep, 0.0)), 0.5, 0.5), at + up * 0.8)
		_free_after(mist, 1.6)
		_gpu_zs(at + up * 0.5, size)
		_fade_lamp(_lamp_node(at, mid, 1.2 * _g, 4.0), 1.2)

func _gpu_zs(at: Vector3, size: float) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	for i in 3:
		var lb := Label3D.new()
		lb.text = "Z" if i != 1 else "z"
		lb.font_size = 72
		lb.pixel_size = 0.012
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.modulate = Color(0.85, 0.88, 1.0, 0.0)
		lb.outline_modulate = Color(0.25, 0.25, 0.7, 0.0)
		lb.outline_size = 10
		lb.position = at
		lb.render_priority = 6
		add_child(lb)
		var delay := 0.2 * float(i)
		var dur := 1.1
		_add({"node": lb}, dur + delay, func(u: float):
			var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
			lb.position = at + right * (0.3 * float(i) - 0.2 + sin(w * 4.0) * 0.08) * size + up * (w * 1.1)
			lb.scale = Vector3.ONE * (0.5 + w * 0.7)
			var a := sin(w * PI)
			lb.modulate.a = a
			lb.outline_modulate.a = a * 0.8)

# ------------------------------------------------------------------------------------------ BALLADE PROTECTRICE

func _ballad(ctx: Dictionary) -> void:
	_base_hue = 0.58
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var hot := _c(0.9, 0.98, 1.0)
	var mid := _c(0.4, 0.75, 1.0)
	var deep := _c(0.15, 0.4, 0.95)
	_flash(_w_soft(), _hdr(mid, 1.0 * _g), at, 0.5, 2.0, 0.6, true)
	_dome(at + up * 0.15, 1.0, mid, 1.8, 0.85)
	# cordes de harpe : filets de lumière verticaux qui montent l'un après l'autre
	for i in 7:
		var x := (float(i) - 3.0) * 0.2
		_beam(at + right * x - up * 0.9, at + right * x + up * (0.7 + 0.2 * sin(float(i) * 1.3)), hot.lerp(mid, 0.3), 0.05, 0.5, 0.06 * float(i))
	_notes_orbit(at, hot, 6, 0.95, 0.4, 1.4, 0.24)
	_shock(at, mid, 2.2, 0.7)
	_later(0.2, func(): _shock(at, hot, 1.6, 0.6))
	_helix(at - up * 0.5, [Color(hot, 0.0), Color(mid, 0.95), Color(deep, 0.0)], 0.6, 1.0, 1.2, 30, 0.9)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, mid, 1.5 * _g, 4.0), 0.9)

# ------------------------------------------------------------------------------------------ REQUIEM DE VIGUEUR

func _requiem(_ctx: Dictionary) -> void:
	_base_hue = 0.14
	var up := cam.global_transform.basis.y
	var ends := _party_ends(2.2)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var mid: Vector3 = ends[2]
	var width := a.distance_to(b) * 1.25
	var gold := _c(1.0, 0.82, 0.35)
	var hot := _c(1.0, 0.97, 0.8)
	var green := _c(0.55, 1.0, 0.5)
	_flash(_w_soft(), _hdr(Color(gold, 0.6), 0.9 * _g), mid, 1.2, 6.0, 0.9, true)
	_staff(mid + up * 0.1, width, gold, 1.0)
	# notes posées sur la portée qui s'élèvent
	var n := 8
	for i in n:
		var x := (float(i) / float(n - 1) - 0.5) * width * 0.85
		var y := (float(i % 5) - 2.0) * 0.13 * 0.5
		var s := _sprite(_note_tex(), _hdr(hot.lerp(gold, 0.3), 1.4 * _g), 0.3 * _s, mid)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var dl := 0.07 * float(i)
		var p0 := mid + cam.global_transform.basis.x * x + up * (0.1 + y)
		_add(s, 1.3 + dl, func(u: float):
			var w := clampf((u * (1.3 + dl) - dl) / 1.3, 0.0, 1.0)
			(s.node as Node3D).position = p0 + up * (w * w * 1.4)
			(s.mat as StandardMaterial3D).albedo_color.a = minf(w * 6.0, 1.0) * (1.0 - clampf((w - 0.6) / 0.4, 0.0, 1.0)))
	for i in _party_slots():
		var si: int = i
		var p := _slot_pos(si, 2.2)
		_later(0.2 + 0.08 * float(i), func():
			_shock(p, green, 1.7, 0.55)
			_helix(p - up * 0.55, [Color(hot, 0.0), Color(gold.lerp(green, 0.4), 0.95), Color(green, 0.0)], 0.42, 1.4, 0.8, 26, 0.7))
	_fade_lamp(_lamp_node(mid + _fwd() * -0.3, gold, 2.0 * _g, 7.0), 1.2)

# ------------------------------------------------------------------------------------------ MÉLODIE DE DISSIPATION

func _dispel_song(ctx: Dictionary) -> void:
	_base_hue = 0.72
	var at := _ally_at(ctx, 2.1)
	var up := cam.global_transform.basis.y
	var hot := _c(0.97, 0.95, 1.0)
	var mid := _c(0.75, 0.7, 1.0)
	var deep := _c(0.4, 0.35, 0.9)
	_flash(_w_soft(), _hdr(mid, 0.4 * _g), at, 0.3, 1.5, 0.4, true)
	for i in 2:
		_later(0.12 * float(i), func(): _shock(at, mid.lerp(deep, 0.3 * float(i)), 1.8 + 0.9 * float(i), 0.55))
	for k in 8:
		_streak(at, float(k) / 8.0 * PI, 1.9, hot, 0.25, 0.0, 0.035, 0.0)
	_flare4(at, mid, 1.5, 0.45, 0.3)
	# les maux : fumée sombre chassée vers le haut, éclats de verre brillant
	var smoke := _gpu(12, 1.0, true, _smoke_mesh(Color.WHITE, _smoke_puff()),
		_pmat_grow(0.2, Vector3.UP, 25.0, 0.9, 1.8, Vector3(0, 0.6, 0), 0.4, 0.7, _ramp(Color(0.4, 0.3, 0.55, 0.0), Color(0.22, 0.15, 0.35, 0.6), Color(0.05, 0.02, 0.1, 0.0)), 0.5, 0.6), at)
	_free_after(smoke, 1.2)
	var glass := _gpu(34, 0.9, true, _soft_mesh(hot, 1.6 * _g, _flare4_tex()),
		_pmat(0.15, Vector3.UP, 180.0, 0.8, 2.6, Vector3(0, 0.5, 0), 0.06, 0.14, _ramp(Color(hot, 1.0), Color(mid, 0.9), Color(deep, 0.0)), 0.6, 0.6), at)
	_free_after(glass, 1.1)
	_notes_burst(at, hot, 4, 1.0, 0.24)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, mid, 1.6 * _g, 4.0), 0.6)
