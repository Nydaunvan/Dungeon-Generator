extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets sacrés et de soin (Forward+ / Vulkan). Attaques : lumière du ciel, châtiment (grand trait de lame de lumière), jugement
## (sceau gravé et trois lances), aura de rédemption, lumière purificatrice (flammes blanches), anathème (chaînes rouge et or).
## Soins : soin (hélice de lumière verte), guérison de groupe, célérité (traits de vitesse), bénédiction (pluie dorée et auréole),
## sanctuaire (dôme hexagonal). Palette dorée par défaut ; chaque effet a sa propre palette, que la teinte du sort fait tourner.

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.12
	var fx := str(ctx.get("fx", "holy_light"))
	if _tier >= 2:
		match fx:
			"holy_judgment": GLYPHS.judgment()
			"holy_anathema": GLYPHS.anathema()
			"holy_light", "holy_smite", "holy_aura", "holy_purify": GLYPHS.sun()
	match fx:
		"holy_smite": _smite(target)
		"holy_judgment": _judgment(target)
		"holy_aura": _aura(target, ctx)
		"holy_purify": _purify(target)
		"holy_anathema": _anathema(target)
		"heal_soft": _heal_soft(ctx)
		"heal_group": _heal_group(ctx)
		"heal_haste": _haste(ctx)
		"heal_blessing": _blessing(ctx)
		"heal_sanctuary": _sanctuary(ctx)
		_: _light(target)

func _hot() -> Color:
	return _c(1.0, 0.97, 0.82)

func _mid() -> Color:
	return _c(1.0, 0.85, 0.45)

func _deep() -> Color:
	return _c(0.9, 0.62, 0.22)

func _ally_at(ctx: Dictionary, depth: float = 2.0) -> Vector3:
	return _slot_pos(int(ctx.get("ally", ctx.get("caster", 1))), depth)

func _rays_star(at: Vector3, col: Color, size: float, dur: float, spin: float = 0.9) -> void:
	var star := _sprite(_rays_tex(), _hdr(col, 1.1 * _g), 1.0, at)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, dur, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.6 + u * 2.2) * size
		(star.node as Node3D).rotation.z = u * spin
		(star.mat as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - u) * minf(1.0, u * 8.0))

## Pilier de lumière qui descend du ciel jusqu'au sol puis s'éteint (largeur visible = `width`, hauteur `h`).
func _sky_pillar(base: Vector3, width: float, h: float, dur: float, drop_t: float, power: float = 1.0, col: Color = Color(0, 0, 0, 0), core: Color = Color(0, 0, 0, 0)) -> void:
	var c0 := _mid() if col.a == 0.0 else col
	var c1 := _hot() if core.a == 0.0 else core
	_pillar(base, width * 2.0, h, SH_PILLAR, "pillar", {"col": c0, "core": c1, "power": power * _g, "fade": 0.0, "drop": 0.0}, dur,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("drop", clampf(u / drop_t, 0.0, 1.0))
			m.set_shader_parameter("fade", (1.0 if u < 0.35 else maxf(0.0, 1.0 - (u - 0.35) / 0.65)))
			mi.scale.x = width * 2.0 * (0.75 + 0.3 * clampf((u - drop_t * 0.5) / 0.5, 0.0, 1.0)))

func _gold_hit(at: Vector3, target: Dictionary, big: float = 1.0, decal: Texture2D = null) -> void:
	_hit_fx(at, target, {
		"size": big,
		"flash": [_c(1.0, 0.95, 0.75), 1.2],
		"shocks": [[_mid(), 2.6, 0.5], [_hot(), 1.7, 0.34, 0.06]],
		"ground": [_mid(), 3.0, 0.65],
		"ribbons": {"c": [_c(1, 1, 0.9, 1.0), _c(1, 0.85, 0.4, 0.9), _c(0.9, 0.6, 0.2, 0.0)], "n": 14, "v": [1.6, 4.0], "grav": Vector3(0, 1.0, 0), "life": 0.8},
		"sparks": {"c": [_c(1, 0.98, 0.85, 1.0), _c(1, 0.85, 0.45, 0.9), _c(0.9, 0.6, 0.2, 0.0)], "n": 36, "v": [0.6, 2.8], "grav": Vector3(0, 0.6, 0), "life": 1.0},
		"smoke": [{"c": [_c(1, 0.9, 0.55, 0.0), _c(1, 0.8, 0.35, 0.4), _c(0.9, 0.6, 0.2, 0.0)], "n": 7, "sz": [0.8, 1.4], "rise": 0.5, "life": 1.1, "add": true}],
		"decal": [decal if decal != null else GLYPHS.sun(), _mid(), 1.3 * big, 1.6],
		"lamp": [_c(1.0, 0.88, 0.55), 2.8, 6.0, 0.7],
		"shake": 0.025 * big,
	})

# ------------------------------------------------------------------------------------------ LUMIÈRE SACRÉE

func _light(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	_sky_pillar(base, 1.4 * size, 6.5, 1.0, 0.16)
	_later(0.1, func():
		_rays_star(at, _mid(), size, 0.65)
		_gold_hit(at, target, 1.0)
		_helix(base, [_c(1, 0.97, 0.8, 0.0), _c(1, 0.85, 0.45, 0.95), _c(1, 0.7, 0.25, 0.0)], 0.6 * size, 1.5, 0.35, 34, 0.6))

# ------------------------------------------------------------------------------------------ CHÂTIMENT SACRÉ

func _smite(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	_flash(_w_soft(), _hdr(_hot(), 1.3 * _g), at + up * 1.9 + right * 1.3, 0.3, 1.5, 0.3)
	_streak(at, 0.95, 3.8 * size, _mid(), 0.36, 0.1, 0.36, 0.22)
	_streak(at, 0.95, 3.4 * size, _hot(), 0.32, 0.12, 0.13, 0.22)
	_later(0.26, func():
		_flare4(at, _hot(), 3.4 * size, 0.5, 0.35)
		_gold_hit(at, target, 1.25)
		_shake(0.03 * _pw, 0.2))

# ------------------------------------------------------------------------------------------ JUGEMENT

func _judgment(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	_glyph_decal(target, GLYPHS.judgment(), _mid(), 1.5 * size, 2.0, 0.45, 3.5)
	_ground_shock(base, _mid(), 3.0 * size, 0.6)
	var lamp := _lamp_node(at + up, _c(1.0, 0.88, 0.55), 1.0 * _g, 7.0)
	for i in 3:
		var ang := float(i) / 3.0 * TAU + 0.5
		var sp := base + Vector3(cos(ang), 0.0, sin(ang)) * 0.95 * size
		_later(0.35 + 0.14 * float(i), func():
			_sky_pillar(sp, 0.45 * size, 6.0, 0.55, 0.12)
			_flash(_w_soft(), _hdr(_mid(), 1.2 * _g), sp + Vector3(0, 0.4, 0), 0.3, 1.3, 0.25)
			_ground_shock(sp, _mid(), 1.6 * size, 0.35)
			_shake(0.012 * _pw, 0.1))
	_later(1.0, func():
		_sky_pillar(base, 1.5 * size, 7.0, 0.9, 0.1, 1.2, _c(1.0, 0.9, 0.55), _c(1, 1, 1))
		_rays_star(at, _hot(), 1.3 * size, 0.7)
		_flare4(at, _hot(), 3.8 * size, 0.55, 0.3)
		_gold_hit(at, target, 1.35, GLYPHS.judgment())
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 4.0 * _g, 0.12)
			tw.tween_property(lamp, "light_energy", 0.0, 0.6)
			tw.tween_callback(lamp.queue_free))
	_keep(2.0)

# ------------------------------------------------------------------------------------------ AURA DE RÉDEMPTION

func _aura(target: Dictionary, ctx: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var src := _caster_anchor(2.0, 0.7)
	_flash(_w_soft(), _hdr(Color(_mid(), 0.8), 1.0 * _g), src, 0.4, 1.5, 0.5, true)
	for i in 3:
		_later(0.12 * float(i), func(): _shock(src, _mid().lerp(_hot(), 0.3 * float(i)), 2.2 + 1.0 * float(i), 0.7))
	_helix(src - up * 0.3, [_c(1, 0.97, 0.8, 0.0), _c(1, 0.85, 0.45, 0.95), _c(1, 0.7, 0.25, 0.0)], 0.5, 1.1, 0.8, 26, 0.5)
	_beam(src, at, _mid(), 0.9, 0.4, 0.2)
	_later(0.5, func():
		_dome(at, 1.2 * size, _mid(), 0.9)
		_sky_pillar(Vector3(at.x, 0.04, at.z), 2.0 * size, 6.0, 0.9, 0.2, 0.6)
		_halo_ring(at + up * 0.8, _hot(), 3.2 * size, 0.9)
		_halo_ring(at + up * 0.8, _mid(), 3.2 * size, 0.9, 1.1, 0.15)
		_gold_hit(at, target, 1.15))

# ------------------------------------------------------------------------------------------ LUMIÈRE PURIFICATRICE

func _purify(target: Dictionary) -> void:
	_base_hue = 0.58
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var hotc := _c(0.85, 0.97, 1.0)
	var midc := _c(0.4, 0.75, 1.0)
	var edge := _c(0.2, 0.4, 0.95)
	_ground_shock(base, midc, 3.0 * size, 0.6)
	_glyph_decal(target, GLYPHS.sun(), midc, 1.3 * size, 1.4, -0.6, 3.5)
	var n := 5
	var dur := 1.0
	for i in n:
		var ang := float(i) / float(n) * TAU + 0.3
		var p := base + Vector3(cos(ang), 0.0, sin(ang)) * 0.95 * size
		var delay := 0.04 * float(i)
		var seed_v := float(i) * 3.1
		_pillar(p, 2.4 * size, 2.7 * size, SH_FLAME, "flame", {"hot": hotc, "mid": midc, "edge": edge, "power": 0.34 * _g, "seed": seed_v, "fade": 0.0, "taper": 1.0},
			dur + delay, func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
				var t := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
				var rise := 1.0 - pow(1.0 - clampf(t / 0.25, 0.0, 1.0), 3.0)
				var fall := 1.0 - clampf((t - 0.7) / 0.3, 0.0, 1.0)
				mi.scale = Vector3(2.4 * size * (0.6 + 0.4 * fall), 2.7 * size * rise * (0.3 + 0.7 * fall), 1.0)
				mi.position = Vector3(p.x, p.y + mi.scale.y * 0.5, p.z)
				m.set_shader_parameter("fade", minf(1.0, t * 10.0) * fall))
	_later(0.4, func():
		_sky_pillar(base, 0.9 * size, 6.5, 0.8, 0.15, 1.0, midc, hotc)
		_rays_star(at, midc, size, 0.6, -0.8)
		_hit_fx(at, target, {
			"size": 1.1,
			"flash": [_c(0.9, 1.0, 1.0), 1.2],
			"shocks": [[midc, 2.6, 0.5], [hotc, 1.7, 0.34, 0.06]],
			"ground": [midc, 3.0, 0.65],
			"sparks": {"c": [_c(1, 1, 1, 1.0), _c(0.7, 0.92, 1.0, 0.9), _c(0.4, 0.65, 1.0, 0.0)], "n": 36, "v": [0.6, 2.8], "grav": Vector3(0, 1.0, 0), "life": 1.0},
			"ribbons": {"c": [_c(1, 1, 1, 1.0), _c(0.7, 0.92, 1.0, 0.9), _c(0.4, 0.65, 1.0, 0.0)], "n": 12, "v": [1.6, 4.0], "grav": Vector3(0, 1.4, 0), "life": 0.8},
			"smoke": [{"c": [_c(0.9, 1.0, 1.0, 0.0), _c(0.7, 0.9, 1.0, 0.4), _c(0.4, 0.6, 1.0, 0.0)], "n": 8, "sz": [0.7, 1.3], "rise": 1.4, "life": 1.1, "add": true}],
			"lamp": [_c(0.8, 0.95, 1.0), 2.8, 6.0, 0.7],
			"shake": 0.02}))

# ------------------------------------------------------------------------------------------ ANATHÈME

func _anathema(target: Dictionary) -> void:
	_base_hue = 0.03
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var red := _c(1.0, 0.25, 0.12)
	var gold := _c(1.0, 0.75, 0.3)
	_glyph_decal(target, GLYPHS.anathema(), red, 1.5 * size, 1.7, 0.5, 4.0)
	_ground_shock(base, red, 3.0 * size, 0.6)
	var lamp := _lamp_node(at, _c(1.0, 0.3, 0.15), 1.2 * _g, 7.0)
	var n := 6
	for i in n:
		var ang := float(i) / float(n) * TAU + 0.2
		var p := base + Vector3(cos(ang), 0.1, sin(ang)) * 2.4 * size
		_later(0.12 * float(i), func():
			_flash(_w_soft(), _hdr(red, 1.1 * _g), p, 0.2, 0.9, 0.25)
			_beam(p, at, red, 0.2, 0.42))
	_later(0.8, func():
		_sky_pillar(base, 0.8 * size, 6.0, 0.6, 0.1, 1.2, red, gold)
		_flare4(at, gold, 3.2 * size, 0.5, -0.3)
		_hit_fx(at, target, {
			"size": 1.25,
			"flash": [_c(1.0, 0.6, 0.35), 1.2],
			"shocks": [[red, 2.8, 0.5], [gold, 1.8, 0.34, 0.06]],
			"ground": [red, 3.2, 0.7],
			"ribbons": {"c": [_c(1, 0.8, 0.5, 1.0), _c(1, 0.3, 0.12, 0.9), _c(0.6, 0.05, 0.03, 0.0)], "n": 20, "v": [2.0, 5.0], "grav": Vector3(0, -2.0, 0), "life": 0.8},
			"sparks": {"c": [_c(1, 0.9, 0.6, 1.0), _c(1, 0.5, 0.2, 0.9), _c(0.7, 0.1, 0.05, 0.0)], "n": 32, "v": [0.8, 3.0], "grav": Vector3(0, 0.3, 0), "life": 1.0},
			"smoke": [{"c": [_c(0.35, 0.08, 0.06, 0.0), _c(0.22, 0.05, 0.04, 0.55), _c(0.08, 0.02, 0.02, 0.0)], "n": 9, "sz": [0.7, 1.2], "rise": 0.7, "life": 1.4}],
			"lamp": [_c(1.0, 0.3, 0.15), 3.2, 6.0, 0.7],
			"shake": 0.045})
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 0.0, 0.7)
			tw.tween_callback(lamp.queue_free))
	_keep(1.8)

# ------------------------------------------------------------------------------------------ SOINS

func _heal_pal() -> Array:
	_base_hue = 0.36
	return [_c(0.92, 1.0, 0.92), _c(0.45, 0.95, 0.55), _c(0.2, 0.7, 0.35)]

## Soin sur un héros : colonne douce, hélice de lumière verte, croix qui montent, onde, lueur.
func _heal_one(at: Vector3, pal: Array, k: float = 1.0) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	_flash(_w_soft(), _hdr(pal[1], 1.1 * _g), at, 0.5 * k, 2.0 * k, 0.55, true)
	_pillar(at - up * 1.0, 1.7 * k, 3.0, SH_PILLAR, "pillar", {"col": pal[1], "core": pal[0], "power": 0.5 * _g, "fade": 0.0, "drop": 1.0, "flow": 1.6}, 1.1,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("fade", sin(u * PI) * 0.9))
	_helix(at - up * 0.55, [Color(pal[0], 0.0), Color(pal[1], 0.95), Color(pal[2], 0.0)], 0.42 * k, 1.5, 0.9, 38, 0.8)
	_shock(at, pal[1], 1.7 * k, 0.55)
	_later(0.1, func(): _shock(at, pal[0], 1.1 * k, 0.4))
	for i in Settings.pc(6):
		var c := _sprite(_cross_tex(), _hdr(Color(pal[0], 1.0), 1.2 * _g), 0.22 * k, at)
		(c.mat as StandardMaterial3D).no_depth_test = true
		var ox := randf_range(-0.45, 0.45) * k
		var delay := randf() * 0.3
		var ph := randf() * TAU
		_add(c, 0.95 + delay, func(u: float):
			var w := clampf((u * (0.95 + delay) - delay) / 0.95, 0.0, 1.0)
			(c.node as Node3D).position = at + right * (ox + sin(w * 5.0 + ph) * 0.06) + up * (w * 1.5 - 0.3)
			(c.node as Node3D).scale = Vector3.ONE * 0.22 * k * (1.0 - w * 0.4)
			(c.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.95)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, pal[1], 1.5 * _g, 4.0), 0.6)

func _heal_soft(ctx: Dictionary) -> void:
	_heal_one(_ally_at(ctx), _heal_pal())

func _heal_group(ctx: Dictionary) -> void:
	var pal := _heal_pal()
	var up := cam.global_transform.basis.y
	var ends := _party_ends(2.2)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var mid: Vector3 = ends[2]
	_flash(_w_soft(), _hdr(Color(pal[1], 0.5), 0.8 * _g), mid, 1.2, 5.0, 0.7, true)
	_shock(mid, pal[1], 6.5, 0.8)
	var rain := _pmat(0.1, Vector3.DOWN, 6.0, 0.8, 1.6, Vector3(0, -0.4, 0), 0.05, 0.11, _ramp(Color(pal[0], 0.0), Color(pal[1], 0.95), Color(pal[2], 0.0)), 0.2, 0.4)
	rain.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(a.distance_to(b) * 0.55, 0.05, 0.4)
	var rp := _gpu(70, 1.1, false, _soft_mesh(pal[1], 1.5 * _g, _w_spark()), rain, mid + up * 1.5)
	_later(0.9, func():
		rp.emitting = false
		_free_after(rp, 1.3))
	for i in _party_slots():
		var si: int = i
		_later(0.07 * float(i), func(): _heal_one(_slot_pos(si, 2.2), pal, 0.85))

# ------------------------------------------------------------------------------------------ CÉLÉRITÉ

func _haste(ctx: Dictionary) -> void:
	_base_hue = 0.52
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var hotc := _c(0.9, 1.0, 1.0)
	var midc := _c(0.4, 0.92, 1.0)
	var deep := _c(0.15, 0.55, 1.0)
	_flash(_w_soft(), _hdr(midc, 1.1 * _g), at, 0.5, 2.0, 0.5, true)
	_shock(at, midc, 1.9, 0.45)
	for i in 7:
		var y := randf_range(-0.5, 0.9)
		var off := randf_range(-0.5, 0.5)
		_streak(at + up * y + right * off, 0.0, randf_range(1.8, 2.8), hotc.lerp(midc, randf()), 0.3, 0.035 * float(i), randf_range(0.03, 0.07), 0.04)
	# rubans de vent qui traversent le héros
	var rib := RibbonTrailMesh.new()
	rib.shape = RibbonTrailMesh.SHAPE_CROSS
	rib.size = 0.045
	rib.sections = 5
	rib.section_length = 0.2
	rib.section_segments = 2
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.vertex_color_use_as_albedo = true
	rm.use_particle_trails = true
	rm.albedo_color = _hdr(midc, 1.5 * _g)
	rib.material = rm
	var wp := _pmat(0.5, right, 3.0, 5.0, 8.0, Vector3.ZERO, 1.0, 1.0, _ramp(Color(hotc, 0.0), Color(midc, 0.9), Color(deep, 0.0)), 0.5, 0.0)
	var wind := _gpu(26, 0.7, true, rib, wp, at - right * 1.6)
	wind.trail_enabled = true
	wind.trail_lifetime = 0.3
	_free_after(wind, 1.2)
	_helix(at - up * 0.6, [Color(hotc, 0.0), Color(midc, 0.95), Color(deep, 0.0)], 0.5, 2.8, 2.2, 44, 0.7)
	_later(0.12, func(): _shock(at, hotc, 1.3, 0.35))
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, midc, 1.6 * _g, 4.0), 0.6)

# ------------------------------------------------------------------------------------------ BÉNÉDICTION

func _blessing(ctx: Dictionary) -> void:
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	_flash(_w_soft(), _hdr(_mid(), 1.0 * _g), at, 0.6, 2.2, 0.7, true)
	_pillar(at - up * 0.8, 2.2, 3.4, SH_PILLAR, "pillar", {"col": _mid(), "core": _hot(), "power": 0.45 * _g, "fade": 0.0, "drop": 1.0, "flow": 1.2}, 1.3,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("fade", sin(u * PI) * 0.85))
	# pluie de lumière dorée qui tombe doucement autour du héros
	var rain := _pmat(0.1, Vector3.DOWN, 4.0, 0.6, 1.1, Vector3(0, -0.3, 0), 0.05, 0.12, _ramp(Color(_hot(), 0.0), Color(_mid(), 0.95), Color(_deep(), 0.0)), 0.2, 0.5)
	rain.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(0.7, 0.05, 0.3)
	var rp := _gpu(60, 1.3, false, _soft_mesh(_mid(), 1.6 * _g, _w_spark()), rain, at + up * 1.5)
	_later(1.0, func():
		rp.emitting = false
		_free_after(rp, 1.5))
	_halo_ring(at + up * 0.75, _hot(), 1.7, 1.0, 1.0)
	_halo_ring(at + up * 0.75, _mid(), 2.4, 1.1, 1.0, 0.18)
	_halo_ring(at + up * 0.35, _mid(), 1.6, 0.9, 1.0, 0.3)
	for i in Settings.pc(5):
		var c := _sprite(_cross_tex(), _hdr(_hot(), 1.2 * _g), 0.2, at)
		(c.mat as StandardMaterial3D).no_depth_test = true
		var ox := randf_range(-0.5, 0.5)
		var delay := randf() * 0.4
		_add(c, 1.0 + delay, func(u: float):
			var w := clampf((u * (1.0 + delay) - delay) / 1.0, 0.0, 1.0)
			(c.node as Node3D).position = at + right * (ox + sin(w * 4.0) * 0.05) + up * (1.3 - w * 1.5)
			(c.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.95)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, _mid(), 1.6 * _g, 4.0), 0.9)

# ------------------------------------------------------------------------------------------ SANCTUAIRE

func _sanctuary(_ctx: Dictionary) -> void:
	var up := cam.global_transform.basis.y
	var ends := _party_ends(3.2)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var mid: Vector3 = ends[2]
	var radius := a.distance_to(b) * 0.48
	_flash(_w_soft(), _hdr(Color(_mid(), 0.7), 0.8 * _g), mid, 1.2, 6.0, 1.0, true)
	var star := _sprite(_rays_tex(), _hdr(_mid(), 0.7 * _g), 1.0, mid - _fwd() * 0.2)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, 1.6, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * radius * (1.5 + u * 1.6)
		(star.node as Node3D).rotation.z = u * 0.7
		(star.mat as StandardMaterial3D).albedo_color.a = sin(u * PI) * 0.7)
	_dome(mid + up * 0.3, radius, _mid(), 1.7, 0.26)
	_shock(mid, _mid(), radius * 3.4, 0.9)
	for i in _party_slots():
		var si: int = i
		var p := _slot_pos(si, 2.2)
		_later(0.12 * float(i), func():
			_pillar(p - up * 1.0, 0.9, 3.4, SH_PILLAR, "pillar", {"col": _mid(), "core": _hot(), "power": 0.8 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.0}, 1.2,
				func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
					m.set_shader_parameter("fade", sin(u * PI))))
		_later(0.12 * float(i) + 0.1, func(): _helix(p - up * 0.5, [Color(_hot(), 0.0), Color(_mid(), 0.95), Color(_deep(), 0.0)], 0.4, 1.3, 0.8, 26, 0.9))
	_fade_lamp(_lamp_node(mid + _fwd() * -0.3, _mid(), 2.2 * _g, 7.0), 1.5)
