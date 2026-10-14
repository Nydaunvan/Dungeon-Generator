extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets d'ombre (Forward+ / Vulkan) : frappe fatale (croix de lames cramoisies), drain de vie (filaments qui remontent vers le lanceur),
## ombre fugace, exécution (lame verticale), lame silencieuse, coup dans l'ombre (brèche d'ombre d'où surgit la lame), mille entailles,
## malédiction (pentagramme vert malsain), pacte obscur (pentagramme cramoisi et flammes sombres), apocalypse sombre (ciel noir, météores violets).
## Ombre = sphères de vide (plasma sombre, bord lumineux), fumée noire qui assombrit vraiment l'image, éclats violets ou cramoisis.

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.75
	var fx := str(ctx.get("fx", "shadow_orb"))
	if _tier >= 2:
		match fx:
			"shadow_curse", "shadow_pact", "shadow_apocalypse": GLYPHS.pentagram()
			"shadow_execute": GLYPHS.anathema()
	match fx:
		"shadow_fatal": _fatal(target)
		"shadow_drain": _drain(target, ctx)
		"shadow_step": _step(target)
		"shadow_execute": _execute(target)
		"shadow_blade": _blade(target)
		"shadow_ambush": _ambush(target)
		"shadow_flurry": _flurry(target)
		"shadow_curse": _curse(target)
		"shadow_pact": _pact(target)
		"shadow_apocalypse": _apocalypse(target, ctx)
		_: _void_orb(target, ctx)

# ------------------------------------------------------------------------------------------ palettes

func _vi_hot() -> Color:
	return _c(0.9, 0.7, 1.0)

func _vi_mid() -> Color:
	return _c(0.55, 0.25, 0.95)

func _vi_deep() -> Color:
	return _c(0.22, 0.05, 0.42)

func _dark() -> Color:
	return Color(0.02, 0.0, 0.05, 1.0)

func _void_smoke(n: int, sz: Array, rise: float, life: float, tint: Color = Color(0.25, 0.12, 0.4)) -> Dictionary:
	return {"c": [Color(tint, 0.0), Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55, 0.7), Color(0.02, 0.0, 0.04, 0.0)], "n": n, "sz": sz, "rise": rise, "life": life, "turb": 0.9}

## Impact d'ombre : sphère de vide qui gonfle, éclair sombre, ondes, rubans, étincelles, fumée noire.
func _void_hit(at: Vector3, target: Dictionary, rim: Color, mid: Color, spark_hot: Color, big: float = 1.0, shake: float = 0.03) -> void:
	var size := _tsize(target) * big * _s
	_hit_fx(at, target, {
		"size": big,
		"flash": [Color(rim, 0.9), 1.0],
		"shocks": [[mid, 2.6, 0.5], [rim, 1.6, 0.34, 0.07]],
		"ground": [mid, 2.8, 0.6],
		"lens": [3.0, 0.07],
		"ribbons": {"c": [Color(spark_hot, 1.0), Color(rim, 0.9), Color(mid, 0.0)], "n": 16, "v": [1.8, 4.5], "grav": Vector3(0, -1.5, 0), "life": 0.8},
		"sparks": {"c": [Color(spark_hot, 1.0), Color(rim, 0.9), Color(mid, 0.0)], "n": 26, "v": [0.7, 3.0], "grav": Vector3(0, 0.3, 0), "life": 0.9},
		"smoke": [_void_smoke(10, [0.7, 1.2], 0.8, 1.5, Color(mid.r * 0.6, mid.g * 0.5, mid.b * 0.7))],
		"lamp": [mid, 2.4, 5.5, 0.55],
		"shake": shake,
	})
	_bloom(at, 1.5 * size, 0.55, _dark(), mid, rim, true, 0.2)

# ------------------------------------------------------------------------------------------ orbe d'ombre (effet par défaut du style)

func _void_orb(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if str(ctx.get("mode", "damage")) == "damageGroup" and not pts.is_empty():
		var i := 0
		for t in pts:
			var tt: Dictionary = t
			_later(0.1 * float(i), func(): _void_orb_one(tt))
			i += 1
		return
	_void_orb_one(target)

func _void_orb_one(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var dur := clampf(0.36 + start.distance_to(end) * 0.035, 0.4, 0.58)
	_fly(start, end, dur, {
		"body": {"kind": "plasma", "size": 0.4, "hot": _dark(), "mid": _vi_deep(), "rim": _vi_hot(), "mix": true},
		"halo": [_c(0.45, 0.2, 0.9, 0.45), 1.3],
		"arc": 0.2, "lift": 0.12, "ease": "accel", "grow": 0.3, "orient": false,
		"trails": [
			{"c": [_c(0.5, 0.3, 0.9, 0.0), _c(0.3, 0.12, 0.6, 0.7), _c(0.05, 0.0, 0.12, 0.0)], "n": 22, "life": 0.6, "sz": [0.3, 0.55], "v": [0.1, 0.4],
				"grav": Vector3(0, 0.3, 0), "mix": true, "radius": 0.12, "turb": 0.6, "tex": _smoke_puff()},
			{"c": [_c(0.9, 0.7, 1.0, 0.0), _c(0.6, 0.3, 1.0, 0.9), _c(0.3, 0.1, 0.8, 0.0)], "n": 28, "life": 0.34, "sz": [0.06, 0.14], "v": [0.1, 0.5], "k": 1.4, "radius": 0.12},
		],
		"lamp": [_vi_mid(), 1.6, 4.5],
	}, func(): _void_hit(end, target, _vi_hot(), _vi_mid(), _c(1.0, 0.9, 1.0)))

# ------------------------------------------------------------------------------------------ FRAPPE FATALE

func _fatal(target: Dictionary) -> void:
	_base_hue = 0.98
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0) * _s
	var red := _c(1.0, 0.15, 0.2)
	var hot := _c(1.0, 0.75, 0.75)
	_streak(at, 0.78, 3.4 * size, red, 0.28, 0.0, 0.2, 0.15)
	_streak(at, 0.78, 3.0 * size, hot, 0.26, 0.02, 0.07, 0.15)
	_streak(at, -0.78, 3.4 * size, red, 0.28, 0.12, 0.2, -0.15)
	_streak(at, -0.78, 3.0 * size, hot, 0.26, 0.14, 0.07, -0.15)
	_later(0.2, func():
		_flare4(at, hot, 3.0 * size, 0.45, 0.2)
		_void_hit(at, target, hot, red, _c(1.0, 0.9, 0.9), 1.1, 0.045)
		_hit_fx(at, target, {"sparks": {"c": [_c(1, 0.5, 0.5, 1.0), _c(0.8, 0.05, 0.08, 0.9), _c(0.3, 0.0, 0.02, 0.0)], "n": 30, "v": [1.0, 4.0], "grav": Vector3(0, -7.0, 0), "life": 0.7, "sz": [0.05, 0.1]}}))

# ------------------------------------------------------------------------------------------ DRAIN DE VIE

func _drain(target: Dictionary, ctx: Dictionary) -> void:
	_base_hue = 0.98
	var at := _end_point(target)
	var src := _slot_pos(int(ctx.get("caster", 1)), 2.0)
	var size := _tsize(target) * _s
	var red := _c(1.0, 0.18, 0.25)
	var hot := _c(1.0, 0.8, 0.8)
	var deep := _c(0.4, 0.02, 0.08)
	_bloom(at, 1.7 * size, 0.55, _dark(), deep, red, true, 0.0)
	_shock(at, red, 2.6 * size, 0.5)
	_hit_fx(at, target, {"size": 0.8, "smoke": [_void_smoke(8, [0.6, 1.0], 0.6, 1.2, Color(0.4, 0.05, 0.1))], "lamp": [red, 2.0, 5.0, 0.5]})
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var n := 6
	for i in n:
		var off := right * randf_range(-0.7, 0.7) * size + up * randf_range(-0.5, 0.6) * size
		_later(0.1 + 0.07 * float(i), func():
			_fly(at + off, src, 0.6, {
				"body": {"kind": "plasma", "size": 0.2, "hot": hot, "mid": red, "rim": deep},
				"halo": [Color(red, 0.5), 0.7], "core": 0.06,
				"arc": randf_range(0.5, 0.9), "lift": 0.35, "ease": "smooth", "grow": -0.3, "orient": false,
				"trails": [{"c": [Color(hot, 0.0), Color(red, 0.9), Color(deep, 0.0)], "n": 30, "life": 0.4, "sz": [0.05, 0.12], "v": [0.05, 0.3], "k": 1.5, "radius": 0.05}],
			}, func(): _absorb(src, red, hot)))

func _absorb(at: Vector3, red: Color, hot: Color) -> void:
	_flash(_w_soft(), _hdr(red, 1.2 * _g), at, 0.3, 1.2, 0.3, true)
	_shock(at, hot, 1.4, 0.35)

# ------------------------------------------------------------------------------------------ OMBRE FUGACE

func _step(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	_bloom(at, 1.7 * size, 0.5, _dark(), _vi_deep(), _vi_mid(), true, 0.2)
	_hit_fx(at, target, {
		"size": 1.0,
		"shocks": [[_vi_mid(), 2.2, 0.4]],
		"ground": [_vi_mid(), 2.4, 0.5],
		"smoke": [_void_smoke(16, [0.5, 1.0], 0.5, 1.5, Color(0.3, 0.15, 0.5))],
		"sparks": {"c": [Color(_vi_hot(), 1.0), Color(_vi_mid(), 0.9), Color(_vi_deep(), 0.0)], "n": 24, "v": [0.5, 2.2], "grav": Vector3(0, 0.4, 0), "life": 0.9},
		"lamp": [_vi_mid(), 1.8, 5.0, 0.5],
		"shake": 0.0})
	for i in 3:
		var ang := randf_range(-0.9, 0.9) + float(i) * 1.1
		_streak(at + up * randf_range(-0.3, 0.4), ang, 2.4 * size, _vi_hot().lerp(_vi_mid(), randf() * 0.5), 0.22, 0.07 * float(i), 0.07, 0.1)
	_helix(at - up * 0.7, [Color(_vi_hot(), 0.0), Color(_vi_mid(), 0.9), Color(_vi_deep(), 0.0)], 0.5 * size, 1.4, 1.6, 30, 0.5)

# ------------------------------------------------------------------------------------------ EXÉCUTION

func _execute(target: Dictionary) -> void:
	_base_hue = 0.0
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var red := _c(1.0, 0.12, 0.12)
	var hot := _c(1.0, 0.8, 0.75)
	_glyph_decal(target, GLYPHS.anathema(), red, 1.4 * size, 1.4, -0.4, 3.5)
	var lamp := _lamp_node(at + up, red, 0.8 * _g, 6.0)
	# la lame verticale tombe du haut de la vue
	_streak(at + up * 0.4, 1.5708, 6.0 * size, red, 0.32, 0.25, 0.28, 0.0)
	_streak(at + up * 0.4, 1.5708, 5.4 * size, hot, 0.28, 0.27, 0.1, 0.0)
	_later(0.4, func():
		_flare4(at, hot, 3.6 * size, 0.55, 0.0)
		_void_hit(at, target, hot, red, _c(1.0, 0.9, 0.85), 1.35, 0.075)
		_hit_fx(at, target, {"sparks": {"c": [_c(1, 0.5, 0.45, 1.0), _c(0.85, 0.05, 0.06, 0.9), _c(0.3, 0.0, 0.02, 0.0)], "n": 46, "v": [1.0, 4.5], "grav": Vector3(0, -8.0, 0), "life": 0.8, "sz": [0.05, 0.11]}})
		_ground_shock(base, red, 3.6 * size, 0.7)
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 3.6 * _g, 0.08)
			tw.tween_property(lamp, "light_energy", 0.0, 0.6)
			tw.tween_callback(lamp.queue_free))
	_keep(1.5)

# ------------------------------------------------------------------------------------------ LAME SILENCIEUSE

func _blade(target: Dictionary) -> void:
	var start := _start_point() + cam.global_transform.basis.x * 0.5
	var end := _end_point(target)
	var dur := clampf(0.28 + start.distance_to(end) * 0.025, 0.3, 0.42)
	var mesh := _shard_pal("fxs_blade_" + (str(int(_tint_h * 100.0)) if _tinted else "d"), _c(0.85, 0.7, 1.0), _c(0.38, 0.18, 0.65), _c(0.06, 0.02, 0.14))
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _vcol_mat(1.15 * _g)
	mi.scale = Vector3(0.45, 0.8, 3.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": node, "size": 0.7},
		"arc": 0.0, "lift": 0.0, "ease": "lin", "grow": 0.0,
		"trails": [
			{"c": [_c(0.4, 0.2, 0.7, 0.0), _c(0.2, 0.08, 0.4, 0.55), _c(0.03, 0.0, 0.06, 0.0)], "n": 26, "life": 0.4, "sz": [0.14, 0.3], "v": [0.05, 0.25], "mix": true, "radius": 0.05, "turb": 0.4, "tex": _smoke_puff()},
			{"c": [_c(0.9, 0.75, 1.0, 0.0), _c(0.6, 0.35, 1.0, 0.8), _c(0.3, 0.1, 0.8, 0.0)], "n": 20, "life": 0.25, "sz": [0.04, 0.09], "v": [0.0, 0.2], "k": 1.2, "radius": 0.03},
		],
	}, func():
		_streak(end, 1.5708, 2.8 * _tsize(target) * _s, _vi_hot(), 0.22, 0.0, 0.06, 0.0)
		_hit_fx(end, target, {
			"size": 0.8,
			"sparks": {"c": [Color(_vi_hot(), 1.0), Color(_vi_mid(), 0.9), Color(_vi_deep(), 0.0)], "n": 14, "v": [0.6, 2.4], "grav": Vector3(0, -2.0, 0), "life": 0.6},
			"smoke": [_void_smoke(5, [0.4, 0.8], 0.5, 1.0)],
			"lamp": [_vi_mid(), 1.2, 4.0, 0.3]}))

# ------------------------------------------------------------------------------------------ COUP DANS L'OMBRE

func _ambush(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var portal := at + right * 1.1 * size + up * 0.25
	_bloom(portal, 1.5 * size, 0.7, _dark(), _vi_deep(), _vi_hot(), true, 0.0)
	_shock(portal, _vi_mid(), 2.0 * size, 0.5)
	_hit_fx(portal, {}, {"size": 0.7, "smoke": [_void_smoke(8, [0.4, 0.8], 0.4, 1.0)], "lamp": [_vi_mid(), 1.6, 4.0, 0.4]})
	_beam(portal, at, _vi_hot(), 0.3 * size, 0.24, 0.3)
	_streak(at, 0.55, 3.0 * size, _vi_hot(), 0.26, 0.38, 0.12, 0.2)
	_later(0.46, func():
		_flash(_w_soft(), _hdr(_vi_hot(), 1.2 * _g), at, 0.3, 1.5, 0.3)
		_void_hit(at, target, _vi_hot(), _vi_mid(), _c(1.0, 0.9, 1.0), 0.95, 0.03))

# ------------------------------------------------------------------------------------------ MILLE ENTAILLES

func _flurry(target: Dictionary) -> void:
	_base_hue = 0.9
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var cols := [_c(1.0, 0.3, 0.55), _c(0.75, 0.3, 1.0), _c(1.0, 0.85, 0.95)]
	var n := 12
	for i in n:
		var p := at + right * randf_range(-0.35, 0.35) * size + up * randf_range(-0.4, 0.45) * size
		var ang := randf_range(-1.4, 1.4)
		var delay := 0.05 * float(i)
		_streak(p, ang, randf_range(1.6, 2.6) * size, cols[i % 3], 0.2, delay, randf_range(0.05, 0.1), randf_range(-0.2, 0.2))
		_later(delay + 0.05, func():
			_flash(_w_spark(), _hdr(cols[(i + 1) % 3], 1.3 * _g), p, 0.15, 0.6, 0.15)
			if i % 3 == 0:
				_shake(0.012 * _pw, 0.06))
	_later(0.7, func():
		_streak(at, 0.8, 3.6 * size, cols[0], 0.26, 0.0, 0.22, 0.15)
		_streak(at, -0.8, 3.6 * size, cols[1], 0.26, 0.06, 0.22, -0.15)
		_later(0.18, func():
			_flare4(at, cols[2], 3.2 * size, 0.45, 0.2)
			_void_hit(at, target, cols[2], cols[0], _c(1.0, 0.9, 0.95), 1.15, 0.05)))

# ------------------------------------------------------------------------------------------ MALÉDICTION

func _curse(target: Dictionary) -> void:
	_base_hue = 0.28
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var green := _c(0.55, 0.95, 0.3)
	var hot := _c(0.85, 1.0, 0.7)
	var deep := _c(0.12, 0.3, 0.1)
	_glyph_decal(target, GLYPHS.pentagram(), green, 1.45 * size, 2.0, 0.6, 3.5)
	_ground_shock(base, green, 3.0 * size, 0.7)
	var lamp := _lamp_node(at, green, 0.9 * _g, 6.0)
	_later(0.3, func():
		_bloom(at, 1.5 * size, 0.9, _dark(), deep, green, true, 0.3)
		_helix(base, [Color(hot, 0.0), Color(green, 0.95), Color(deep, 0.0)], 0.7 * size, 1.4, 1.2, 40, 1.0)
		var sm := _gpu(16, 1.5, false, _smoke_mesh(Color.WHITE, _smoke_puff()),
			_pmat_grow(0.6 * size, Vector3.UP, 15.0, 0.4, 1.0, Vector3(0, 0.5, 0), 0.6 * size, 1.2 * size, _ramp(Color(0.2, 0.3, 0.2, 0.0), Color(0.1, 0.16, 0.1, 0.65), Color(0.02, 0.04, 0.02, 0.0)), 0.4, 0.7), base + Vector3(0, 0.2, 0))
		_later(1.0, func():
			sm.emitting = false
			_free_after(sm, 1.8))
		_shock(at, green, 2.6 * size, 0.6)
		_lens(at, 3.0 * size, 0.05 * _pw, 0.9))
	_later(1.4, func():
		_flash(_w_soft(), _hdr(green, 1.1 * _g), at, 0.4, 2.0, 0.4)
		_shock(at, hot, 2.0 * size, 0.45)
		_hit_fx(at, target, {"sparks": {"c": [Color(hot, 1.0), Color(green, 0.9), Color(deep, 0.0)], "n": 24, "v": [0.6, 2.4], "grav": Vector3(0, 0.6, 0), "life": 0.9}, "shake": 0.02})
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 0.0, 0.7)
			tw.tween_callback(lamp.queue_free))
	_keep(2.2)

# ------------------------------------------------------------------------------------------ PACTE OBSCUR

func _pact(target: Dictionary) -> void:
	_base_hue = 0.95
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var red := _c(0.95, 0.12, 0.2)
	var hot := _c(1.0, 0.7, 0.7)
	var deep := _c(0.25, 0.02, 0.1)
	var fl_hot := _c(1.0, 0.4, 0.32)
	_glyph_decal(target, GLYPHS.pentagram(), red, 1.6 * size, 2.0, -0.5, 4.0)
	_ground_shock(base, red, 3.2 * size, 0.7)
	var lamp := _lamp_node(at, red, 1.0 * _g, 7.0)
	for k in 5:
		var ang := -PI * 0.5 + float(k) * TAU / 5.0
		var p := base + Vector3(cos(ang), 0.0, sin(ang)) * 0.8 * 1.6 * size
		var seed_v := float(k) * 2.3
		var dur := 1.1
		var delay := 0.3 + 0.07 * float(k)
		_later(delay, func():
			_pillar(p, 1.8 * size, 2.4 * size, SH_FLAME, "flame", {"hot": fl_hot, "mid": _c(0.8, 0.06, 0.12), "edge": deep, "power": 0.42 * _g, "seed": seed_v, "fade": 0.0, "taper": 1.1},
				dur, func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
					var rise := 1.0 - pow(1.0 - clampf(u / 0.25, 0.0, 1.0), 3.0)
					var fall := 1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0)
					mi.scale = Vector3(1.8 * size * (0.6 + 0.4 * fall), 2.4 * size * rise * (0.3 + 0.7 * fall), 1.0)
					mi.position = Vector3(p.x, p.y + mi.scale.y * 0.5, p.z)
					m.set_shader_parameter("fade", minf(1.0, u * 8.0) * fall)))
	_later(0.8, func():
		_bloom(at, 1.4 * size, 0.7, _dark(), deep, red, true, 0.0)
		_sky_pillar_dark(base, 1.4 * size, 6.5, 0.9, red, hot)
		_flare4(at, hot, 3.0 * size, 0.5, 0.0)
		_void_hit(at, target, hot, red, _c(1.0, 0.9, 0.9), 1.3, 0.05)
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 3.5 * _g, 0.1)
			tw.tween_property(lamp, "light_energy", 0.0, 0.7)
			tw.tween_callback(lamp.queue_free))
	_keep(1.8)

func _sky_pillar_dark(base: Vector3, width: float, h: float, dur: float, col: Color, core: Color) -> void:
	_pillar(base, width * 2.0, h, SH_PILLAR, "pillar", {"col": col, "core": core, "power": 1.0 * _g, "fade": 0.0, "drop": 0.0}, dur,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("drop", clampf(u / 0.14, 0.0, 1.0))
			m.set_shader_parameter("fade", (1.0 if u < 0.35 else maxf(0.0, 1.0 - (u - 0.35) / 0.65)))
			mi.scale.x = width * 2.0 * (0.75 + 0.3 * clampf((u - 0.07) / 0.5, 0.0, 1.0)))

# ------------------------------------------------------------------------------------------ APOCALYPSE SOMBRE

func _apocalypse(target: Dictionary, ctx: Dictionary) -> void:
	_base_hue = 0.78
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty():
		pts = [target]
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var center := cam.global_position + _fwd() * 5.5 + up * 1.8
	# ciel qui s'assombrit : voile sombre devant la vue, puis vortex de vide en haut
	var veil := _sprite(_smoke_puff(), Color(1, 1, 1, 0.0), 1.0, cam.global_position + _fwd() * 1.2)
	(veil.mat as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	(veil.mat as StandardMaterial3D).no_depth_test = true
	(veil.mat as StandardMaterial3D).render_priority = 1
	(veil.mat as StandardMaterial3D).albedo_color = Color(0.03, 0.0, 0.06, 0.0)
	(veil.node as Node3D).scale = Vector3.ONE * 5.0
	_add(veil, 2.0, func(u: float):
		var a := sin(u * PI) * 0.5
		(veil.mat as StandardMaterial3D).albedo_color = Color(0.03, 0.0, 0.06, a))
	var vm := _plasma_mat(_dark(), _vi_deep(), _vi_hot(), true)
	var vortex := _mesh_node(_unit_sphere(), vm, center, 0.5)
	_add({"node": vortex}, 1.9, func(u: float):
		vortex.scale = Vector3.ONE * (0.5 + 5.0 * (1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 2.0))) * (1.0 - clampf((u - 0.8) / 0.2, 0.0, 1.0))
		vm.set_shader_parameter("time_s", u * 1.9)
		vortex.rotation.y = u * 3.0)
	_shock(center, _vi_mid(), 9.0, 0.9)
	var lamp := _lamp_node(center, _vi_mid(), 1.4 * _g, 12.0)
	_fade_lamp(lamp, 2.0)
	_shake(0.02 * _pw, 0.6)
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.45 + 0.17 * float(i), func(): _dark_meteor(tt))
		i += 1

func _dark_meteor(target: Dictionary) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var end := _end_point(target)
	var start := end + up * 6.0 + right * 2.4 + _fwd() * 2.2
	var node := Node3D.new()
	var rm := _smat("rock", SH_ROCK, 5).duplicate() as ShaderMaterial
	rm.set_shader_parameter("stone", _c(0.06, 0.03, 0.1))
	rm.set_shader_parameter("lava", _vi_mid())
	rm.set_shader_parameter("power", _g)
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_mesh(9)
	rock.material_override = rm
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(rock)
	_fly(start, end, 0.5, {
		"body": {"kind": "mesh", "node": node, "size": 0.85},
		"halo": [_c(0.5, 0.2, 1.0, 0.6), 2.0],
		"arc": 0.0, "lift": 0.0, "ease": "accel", "grow": 0.2, "orient": false, "spin": 5.0,
		"trails": [
			{"c": [_c(0.7, 0.4, 1.0, 0.0), _c(0.5, 0.2, 0.95, 0.85), _c(0.15, 0.03, 0.4, 0.0)], "n": 70, "life": 0.6, "sz": [0.3, 0.8], "v": [0.1, 0.6], "grav": Vector3(0, 0.6, 0), "turb": 0.8, "k": 1.0, "radius": 0.2, "tex": _flame_puff(), "damp": 0.8},
			{"c": [_c(0.3, 0.15, 0.5, 0.0), _c(0.12, 0.04, 0.25, 0.6), _c(0.02, 0.0, 0.05, 0.0)], "n": 22, "life": 0.9, "sz": [0.5, 1.0], "v": [0.1, 0.4], "grav": Vector3(0, 0.6, 0), "mix": true, "radius": 0.2, "turb": 0.5, "tex": _smoke_puff()},
		],
		"lamp": [_vi_mid(), 2.4, 6.0],
	}, func():
		_void_hit(end, target, _vi_hot(), _vi_mid(), _c(1.0, 0.9, 1.0), 1.3, 0.06)
		_glyph_decal(target, GLYPHS.scorch(), _vi_mid(), 1.4, 1.4))
