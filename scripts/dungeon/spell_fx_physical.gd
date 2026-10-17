extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets des coups physiques et des tirs (Forward+ / Vulkan). Acier = traits de lame, étincelles orangées, poussière et éclats de roche ;
## sang = gouttelettes sombres ; poison = filets verts ; tirs = vraie flèche en volume qui file avec un sillage d'air.
## Coup Puissant, Tir Précis, Attaque Sournoise, Rage Sanguinaire, Frénésie, Coup Décisif, Fureur Sanglante, Frappe Discordante, Coup Bas,
## Poison de Lame, Frappe du Croisé, Danse des Lames, Tourbillon, Pas de la Lame, Danse Mortelle ; arcanes : Ralentissement,
## Flèche Arcanique, Volée Perçante, Flèches Stellaires.

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.6
	var fx := str(ctx.get("fx", "phys_power"))
	match fx:
		"phys_archer": _ph_archer(target)
		"phys_sneak": _ph_sneak(target)
		"phys_rage": _ph_rage(target)
		"phys_frenzy": _ph_frenzy(target)
		"phys_decisive": _ph_decisive(target)
		"phys_fury": _ph_fury(target)
		"phys_discord": _ph_discord(target)
		"phys_lowblow": _ph_lowblow(target)
		"phys_poison": _ph_poison(target)
		"phys_crusader": _ph_crusader(target)
		"phys_dance": _ph_dance(target)
		"phys_whirl": _ph_whirl(target)
		"phys_step": _ph_step(target)
		"phys_deadly": _ph_deadly(target)
		"arcane_slow": _ph_slow(target)
		"arcane_arrow": _ph_arcane_arrow(target)
		"arcane_volley": _ph_volley(target)
		"arcane_stars": _ph_stars(target)
		_: _ph_power(target)

# ------------------------------------------------------------------------------------------ palettes et briques

func _steel() -> Color:
	return _c(0.85, 0.93, 1.0)

func _steel_mid() -> Color:
	return _c(0.55, 0.72, 1.0)

func _spark_c() -> Array:
	return [_c(1.0, 0.95, 0.7, 1.0), _c(1.0, 0.55, 0.15, 0.9), _c(0.5, 0.1, 0.02, 0.0)]

func _blood_c() -> Array:
	return [_c(1.0, 0.35, 0.3, 1.0), _c(0.65, 0.03, 0.05, 0.9), _c(0.2, 0.0, 0.02, 0.0)]

func _dust(n: int, size: float, tint: Color = Color(0.5, 0.42, 0.33)) -> Dictionary:
	return {"c": [Color(tint, 0.0), Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.8, 0.5), Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 0.0)], "n": n, "sz": [0.5 * size, 1.0 * size], "rise": 0.35, "life": 1.1, "turb": 0.7, "y": -0.2}

## Coup porté : éclair, étincelles, ondes, éclats, poussière. `col` = couleur des étincelles ([chaud, moyen, froid]).
func _ph_hit(at: Vector3, target: Dictionary, hot: Color, mid: Color, cs: Array, big: float = 1.0, shake: float = 0.03, extra: Dictionary = {}) -> void:
	var p := {
		"size": big,
		"flash": [Color(hot, 0.9), 1.1],
		"shocks": [[mid, 2.8, 0.38], [hot, 1.7, 0.26, 0.05]],
		"lens": [2.8, 0.06],
		"ribbons": {"c": cs, "n": 12, "v": [1.8, 4.6], "grav": Vector3(0, -6.0, 0), "life": 0.6, "w": 0.045},
		"sparks": {"c": cs, "n": 36, "v": [1.2, 4.6], "grav": Vector3(0, -6.0, 0), "life": 0.75, "sz": [0.07, 0.15]},
		"lamp": [mid, 1.8, 4.5, 0.35],
		"shake": shake,
	}
	p.merge(extra, true)
	_hit_fx(at, target, p)

func _ph_blade_node(hot: Color, mid: Color, tail: Color, key: String, scl: Vector3, k: float = 1.15) -> Node3D:
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _shard_pal("fxp_" + key + "_" + (str(int(_tint_h * 100.0)) if _tinted else "d"), hot, mid, tail)
	mi.material_override = _vcol_mat(k * _g)
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return node

## Flèche en volume : fût fin, pointe brillante.
func _ph_arrow_node(hot: Color, mid: Color, tail: Color, key: String) -> Node3D:
	return _ph_blade_node(hot, mid, tail, key, Vector3(0.17, 0.28, 3.8 * _tail_k()), 1.5)

## Étoiles d'étourdissement qui tournent au-dessus du monstre.
func _ph_stun(at: Vector3, col: Color, size: float, dur: float = 1.0, delay: float = 0.0) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var top := at + up * 0.7 * size
	for i in 4:
		var s := _sprite(_flare4_tex(), _hdr(col, 1.3 * _g), 0.28 * _s, top)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var a0 := float(i) * TAU / 4.0
		_add(s, dur + delay, func(u: float):
			var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
			var a := a0 + w * 7.0
			(s.node as Node3D).visible = w > 0.0
			(s.node as Node3D).position = top + right * cos(a) * 0.5 * size + up * sin(a) * 0.1 * size + Vector3(0, 0, 0)
			(s.node as Node3D).rotation.z = w * 6.0
			(s.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.98)

## Trait de lame avec son éclat de croisement (croix de lumière) à l'arrivée.
func _ph_cut(at: Vector3, ang: float, length: float, hot: Color, mid: Color, delay: float, thick: float = 0.2, bend: float = 0.2) -> void:
	_streak(at, ang, length, mid, 0.26, delay, thick, bend)
	_streak(at, ang, length * 0.9, hot, 0.24, delay + 0.015, thick * 0.35, bend)

# ------------------------------------------------------------------------------------------ COUP PUISSANT

func _ph_power(target: Dictionary) -> void:
	_base_hue = 0.58
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	# grand coup en diagonale, du haut gauche vers le bas droit
	_ph_cut(at, 0.9, 4.2 * size, _steel(), _steel_mid(), 0.0, 0.26, 0.22)
	_later(0.17, func():
		_flare4(at, _steel(), 3.2 * size, 0.4, 0.15)
		_ph_hit(at, target, _c(1.0, 0.95, 0.85), _c(1.0, 0.7, 0.3), _spark_c(), 1.1, 0.05, {
			"ground": [Color(0.9, 0.75, 0.5), 3.0, 0.5],
			"shards": {"mesh": _rock_mesh(5), "n": 9, "v": [1.8, 3.8], "sz": [0.08, 0.17]},
			"smoke": [_dust(8, 0.8)]})
		_ground_shock(base, _c(0.9, 0.8, 0.6), 3.0 * size, 0.5)
		_ph_cut(at + up * 0.0, -0.4, 2.0 * size, _c(1.0, 0.85, 0.6), _c(1.0, 0.6, 0.25), 0.0, 0.1, -0.1))
	_keep(1.4)

# ------------------------------------------------------------------------------------------ TIR PRÉCIS

func _ph_archer(target: Dictionary) -> void:
	_base_hue = 0.12
	var start := _start_point() + _side(0.4)
	var end := _end_point(target)
	var dur := clampf(0.22 + start.distance_to(end) * 0.022, 0.26, 0.38)
	var size := _tsize(target) * _s
	var gold := _c(1.0, 0.85, 0.5)
	var wind := _c(0.85, 0.95, 1.0)
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": _ph_arrow_node(_c(1.0, 0.98, 0.9), _c(1.0, 0.8, 0.45), _c(0.5, 0.3, 0.1), "arrow"), "size": 1.1}, "halo": [Color(gold, 0.35), 0.7], "core": 0.07,
		"arc": 0.0, "lift": 0.0, "ease": "lin", "grow": 0.0,
		"trails": [{"c": [Color(wind, 0.0), Color(wind, 0.5), Color(wind, 0.0)], "n": 24, "life": 0.22, "sz": [0.03, 0.07], "v": [0.0, 0.15], "k": 1.0, "radius": 0.03}],
	}, func():
		# réticule : cercle fin qui se resserre sur le point d'impact
		_shock(end, gold, 2.4 * size, 0.28)
		_flare4(end, _c(1.0, 0.97, 0.85), 2.4 * size, 0.3, 0.0)
		_streak(end, 0.0, 2.2 * size, gold, 0.2, 0.0, 0.03, 0.0)
		_streak(end, 1.5708, 2.2 * size, gold, 0.2, 0.0, 0.03, 0.0)
		_ph_hit(end, target, _c(1.0, 0.97, 0.85), gold, _spark_c(), 0.8, 0.025, {"shocks": [[gold, 1.6, 0.3]], "lens": [1.8, 0.04]}))

# ------------------------------------------------------------------------------------------ ATTAQUE SOURNOISE

func _ph_sneak(target: Dictionary) -> void:
	_base_hue = 0.4
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var teal := _c(0.4, 1.0, 0.85)
	var hot := _c(0.92, 1.0, 0.97)
	# deux lames croisées, très rapides, sorties de l'ombre (fumée sombre derrière le monstre)
	_hit_fx(at - right * 0.25 * size, {}, {"size": 0.7, "smoke": [{"c": [Color(0.1, 0.2, 0.2, 0.0), Color(0.05, 0.12, 0.12, 0.6), Color(0.0, 0.02, 0.02, 0.0)], "n": 8, "sz": [0.4, 0.8], "rise": 0.3, "life": 0.9, "turb": 0.8}]})
	_ph_cut(at + up * 0.2 * size, 0.65, 3.0 * size, hot, teal, 0.0, 0.14, 0.15)
	_ph_cut(at - up * 0.1 * size, -0.65, 3.0 * size, hot, teal, 0.1, 0.14, -0.15)
	_later(0.18, func():
		_flash(_w_soft(), _hdr(Color(1.0, 0.25, 0.25), 1.2 * _g), at, 0.2, 1.4 * size, 0.3)    # point vital : éclat rouge
		_ph_hit(at, target, hot, teal, _spark_c(), 0.9, 0.03))

# ------------------------------------------------------------------------------------------ RAGE SANGUINAIRE

func _ph_rage(target: Dictionary) -> void:
	_base_hue = 0.98
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var red := _c(1.0, 0.2, 0.15)
	var hot := _c(1.0, 0.8, 0.7)
	# trois griffures parallèles
	for i in 3:
		var off := up * (float(i) - 1.0) * 0.28 * size + cam.global_transform.basis.x * (float(i) - 1.0) * -0.12 * size
		_ph_cut(at + off, 0.95, 3.6 * size, hot, red, 0.07 * float(i), 0.2, 0.2)
	_later(0.24, func():
		_ph_hit(at, target, hot, red, _blood_c(), 1.1, 0.05, {
			"ribbons": {"c": [_c(1.0, 0.4, 0.35, 1.0), _c(0.7, 0.04, 0.06, 0.9), _c(0.2, 0.0, 0.02, 0.0)], "n": 14, "v": [1.5, 4.0], "grav": Vector3(0, -6.0, 0), "life": 0.7},
			"lamp": [red, 2.2, 5.0, 0.45]})
		_bloom(at, 1.2 * size, 0.4, _c(0.2, 0.0, 0.02), _c(0.7, 0.04, 0.06), red, true, 0.1))
	_keep(1.2)

# ------------------------------------------------------------------------------------------ FRÉNÉSIE

func _ph_frenzy(target: Dictionary) -> void:
	_base_hue = 0.03
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var orange := _c(1.0, 0.45, 0.12)
	var hot := _c(1.0, 0.9, 0.7)
	var n := 9
	for i in n:
		var p := at + right * randf_range(-0.4, 0.4) * size + up * randf_range(-0.4, 0.4) * size
		var ang := (0.9 if i % 2 == 0 else -0.8) + randf_range(-0.3, 0.3)
		var delay := 0.045 * float(i) * (1.0 - 0.02 * float(i))
		_ph_cut(p, ang, randf_range(2.2, 3.4) * size, hot, orange if i % 3 else _c(1.0, 0.2, 0.15), delay, randf_range(0.1, 0.18), randf_range(-0.2, 0.2))
		_later(delay + 0.06, func():
			_flash(_w_spark(), _hdr(hot, 1.4 * _g), p, 0.15, 0.7 * size, 0.15)
			if i % 3 == 0:
				_shake(0.014 * _pw, 0.06))
	_later(0.55, func():
		_flare4(at, hot, 3.4 * size, 0.45, 0.2)
		_ph_hit(at, target, hot, orange, _spark_c(), 1.2, 0.06, {"lamp": [orange, 2.4, 5.5, 0.5]}))
	_keep(1.4)

# ------------------------------------------------------------------------------------------ COUP DÉCISIF

func _ph_decisive(target: Dictionary) -> void:
	_base_hue = 0.1
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var gold := _c(1.0, 0.75, 0.3)
	var hot := _c(1.0, 0.97, 0.85)
	var lamp := _lamp_node(at + up * 0.8, gold, 0.6 * _g, 6.0)
	# la hache tombe à la verticale
	_streak(at + up * 0.4, 1.5708, 6.0 * size, gold, 0.3, 0.15, 0.3, 0.0)
	_streak(at + up * 0.4, 1.5708, 5.4 * size, hot, 0.26, 0.17, 0.1, 0.0)
	_later(0.3, func():
		_flare4(at, hot, 3.8 * size, 0.55, 0.0)
		_ph_hit(at, target, hot, gold, _spark_c(), 1.35, 0.08, {
			"ground": [gold, 3.6, 0.6],
			"shards": {"mesh": _rock_mesh(7), "n": 12, "v": [2.0, 4.4], "sz": [0.09, 0.2]},
			"smoke": [_dust(10, 0.9)]})
		_ground_shock(base, gold, 3.6 * size, 0.6)
		_ph_stun(at, hot, size, 1.2, 0.15)
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 3.0 * _g, 0.07)
			tw.tween_property(lamp, "light_energy", 0.0, 0.6)
			tw.tween_callback(lamp.queue_free))
	_keep(1.8)

# ------------------------------------------------------------------------------------------ FUREUR SANGLANTE

func _ph_fury(target: Dictionary) -> void:
	_base_hue = 0.98
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var red := _c(1.0, 0.12, 0.1)
	var hot := _c(1.0, 0.75, 0.6)
	var deep := _c(0.3, 0.0, 0.03)
	var lamp := _lamp_node(at, red, 0.9 * _g, 7.0)
	_ground_shock(base, red, 3.4 * size, 0.7)
	for k in 3:
		var ang := 0.5 + float(k) * 0.45
		_ph_cut(at, ang if k != 1 else -ang, 4.4 * size, hot, red, 0.12 * float(k), 0.26, 0.2 * (1.0 if k != 1 else -1.0))
	_later(0.4, func():
		_pillar(base, 2.0 * size, 3.0 * size, SH_FLAME, "flame", {"hot": _c(1.0, 0.45, 0.3), "mid": _c(0.85, 0.06, 0.1), "edge": deep, "power": 0.4 * _g, "seed": 4.0, "fade": 0.0, "taper": 1.1}, 1.0,
			func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
				var rise := 1.0 - pow(1.0 - clampf(u / 0.25, 0.0, 1.0), 3.0)
				var fall := 1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0)
				mi.scale = Vector3(2.0 * size * (0.6 + 0.4 * fall), 3.0 * size * rise * (0.3 + 0.7 * fall), 1.0)
				mi.position = Vector3(base.x, base.y + mi.scale.y * 0.5, base.z)
				m.set_shader_parameter("fade", minf(1.0, u * 8.0) * fall))
		_flare4(at, hot, 3.6 * size, 0.5, 0.2)
		_ph_hit(at, target, hot, red, _blood_c(), 1.3, 0.08, {
			"ribbons": {"c": [_c(1.0, 0.4, 0.35, 1.0), _c(0.75, 0.04, 0.06, 0.9), _c(0.2, 0.0, 0.02, 0.0)], "n": 22, "v": [1.8, 4.8], "grav": Vector3(0, -6.0, 0), "life": 0.8},
			"ground": [red, 3.4, 0.6],
			"lamp": [red, 2.6, 6.0, 0.6]})
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 3.0 * _g, 0.1)
			tw.tween_property(lamp, "light_energy", 0.0, 0.8)
			tw.tween_callback(lamp.queue_free))
	_keep(2.0)

# ------------------------------------------------------------------------------------------ FRAPPE DISCORDANTE

func _ph_discord(target: Dictionary) -> void:
	_base_hue = 0.85
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var mag := _c(1.0, 0.3, 0.8)
	var cyan := _c(0.3, 0.95, 1.0)
	var hot := _c(1.0, 0.95, 1.0)
	# deux ondes qui ne s'accordent pas : décalées, de couleurs opposées, avec une lentille qui tord l'image
	_shock(at, mag, 2.2 * size, 0.5)
	_shock(at + right * 0.12 * size, cyan, 2.6 * size, 0.55, 0.06)
	_shock(at - right * 0.12 * size, mag, 3.0 * size, 0.6, 0.12)
	_lens(at, 3.4 * size, 0.09 * _pw, 0.6)
	# éclairs en dents de scie
	for k in 7:
		var ang := float(k) / 7.0 * PI + randf_range(-0.15, 0.15)
		_streak(at, ang, randf_range(1.8, 2.8) * size, mag if k % 2 == 0 else cyan, 0.2, 0.03 * float(k), 0.05, randf_range(-0.6, 0.6))
	# notes brisées qui jaillissent
	for k in 5:
		var s := _sprite(_note_tex(), _hdr(mag if k % 2 == 0 else cyan, 1.4 * _g), 0.26 * _s, at)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var ang2 := randf() * TAU
		var vel := Vector3(cos(ang2), sin(ang2) * 0.7 + 0.4, 0.0) * randf_range(0.9, 1.6)
		_add(s, 0.7, func(u: float):
			(s.node as Node3D).position = at + right * vel.x * u * 0.8 + up * (vel.y * u * 0.8 - u * u * 0.3)
			(s.node as Node3D).rotation.z = ang2 + u * 4.0
			(s.mat as StandardMaterial3D).albedo_color.a = 1.0 - u * u)
	_flare4(at, hot, 2.6 * size, 0.35, 0.3)
	_ph_hit(at, target, hot, mag, [Color(hot, 1.0), Color(mag, 0.9), Color(cyan, 0.0)], 0.9, 0.04, {"shocks": [], "lens": [0.0, 0.0]})
	_keep(1.0)

# ------------------------------------------------------------------------------------------ COUP BAS

func _ph_lowblow(target: Dictionary) -> void:
	_base_hue = 0.55
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var hot := _c(0.95, 0.98, 1.0)
	var mid := _c(0.6, 0.78, 1.0)
	# coup de dague remontant depuis le bas : trait vertical qui part du sol, nuage de poussière
	_streak(at - up * 0.5 * size, 1.5708, 3.2 * size, mid, 0.26, 0.0, 0.14, 0.12)
	_streak(at - up * 0.5 * size, 1.5708, 2.9 * size, hot, 0.24, 0.015, 0.05, 0.12)
	_ground_shock(base, _c(0.85, 0.8, 0.7), 2.2 * size, 0.4)
	_later(0.14, func():
		_ph_hit(at - up * 0.1 * size, target, hot, mid, _spark_c(), 0.9, 0.04, {"smoke": [_dust(6, 0.6)]})
		_ph_stun(at, hot, size, 1.0, 0.1))
	_keep(1.4)

# ------------------------------------------------------------------------------------------ POISON DE LAME

func _ph_poison(target: Dictionary) -> void:
	_base_hue = 0.3
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var green := _c(0.45, 1.0, 0.25)
	var hot := _c(0.9, 1.0, 0.75)
	var deep := _c(0.1, 0.35, 0.08)
	_ph_cut(at, 0.8, 3.4 * size, hot, green, 0.0, 0.16, 0.2)
	_later(0.14, func():
		_ph_hit(at, target, hot, green, [Color(hot, 1.0), Color(green, 0.9), Color(deep, 0.0)], 0.9, 0.03, {
			"flash": [Color(green, 0.8), 0.7],
			"smoke": [{"c": [Color(0.3, 0.6, 0.15, 0.0), Color(0.18, 0.4, 0.1, 0.55), Color(0.04, 0.1, 0.03, 0.0)], "n": 10, "sz": [0.5, 1.0], "rise": 0.5, "life": 1.3, "turb": 0.9}],
			"ribbons": {"c": [Color(hot, 1.0), Color(green, 0.9), Color(deep, 0.0)], "n": 12, "v": [1.2, 3.0], "grav": Vector3(0, -5.0, 0), "life": 0.8}})
		# bulles toxiques qui montent
		var bub := _gpu(14, 1.3, true, _soft_mesh(green, 0.9 * _g, _w_spark()),
			_pmat_grow(0.3 * size, Vector3.UP, 20.0, 0.3, 0.8, Vector3(0, 0.3, 0), 0.06, 0.16, _ramp(Color(hot, 0.0), Color(green, 0.9), Color(deep, 0.0)), 0.5, 0.3), at - up * 0.2 * size)
		_free_after(bub, 1.6))
	_keep(1.8)

# ------------------------------------------------------------------------------------------ FRAPPE DU CROISÉ

func _ph_crusader(target: Dictionary) -> void:
	_base_hue = 0.11
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var gold := _c(1.0, 0.82, 0.35)
	var hot := _c(1.0, 0.98, 0.88)
	# coup de masse horizontal, lourd, qui laisse une croix de lumière
	_ph_cut(at, 0.12, 4.2 * size, hot, gold, 0.0, 0.3, 0.1)
	_later(0.16, func():
		_flare4(at, hot, 3.4 * size, 0.5, 0.0)
		var cross := _sprite(_cross_tex(), _hdr(gold, 1.3 * _g), 1.5 * size, at)
		(cross.mat as StandardMaterial3D).no_depth_test = true
		_add(cross, 0.7, func(u: float):
			(cross.node as Node3D).scale = Vector3.ONE * (0.7 + 0.5 * u)
			(cross.mat as StandardMaterial3D).albedo_color.a = sin(minf(u * 1.6, 1.0) * PI * 0.5) * (1.0 - u) * 0.95)
		_ph_hit(at, target, hot, gold, [Color(hot, 1.0), Color(gold, 0.9), Color(0.6, 0.3, 0.05, 0.0)], 1.15, 0.06, {
			"ground": [gold, 3.0, 0.5],
			"smoke": [_dust(6, 0.7, Color(0.7, 0.6, 0.4))]})
		_ground_shock(base, gold, 3.0 * size, 0.5)
		_ph_stun(at, hot, size, 1.0, 0.1))
	_keep(1.6)

# ------------------------------------------------------------------------------------------ DANSE DES LAMES

func _ph_dance(target: Dictionary) -> void:
	_base_hue = 0.5
	var at := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var cy := _c(0.55, 0.95, 1.0)
	var hot := _c(0.95, 1.0, 1.0)
	var rose := _c(1.0, 0.7, 0.9)
	# trois arcs élégants, très courbes, l'un après l'autre
	_streak(at + up * 0.2 * size, 0.7, 4.0 * size, cy, 0.34, 0.0, 0.14, 0.7)
	_streak(at + up * 0.2 * size, 0.7, 3.6 * size, hot, 0.3, 0.02, 0.05, 0.7)
	_streak(at - up * 0.1 * size, -0.6, 4.0 * size, rose, 0.34, 0.14, 0.14, -0.7)
	_streak(at - up * 0.1 * size, -0.6, 3.6 * size, hot, 0.3, 0.16, 0.05, -0.7)
	_streak(at, 0.05, 4.4 * size, cy, 0.36, 0.28, 0.12, 0.8)
	_later(0.42, func():
		_flare4(at, hot, 3.0 * size, 0.4, 0.2)
		_ph_hit(at, target, hot, cy, [Color(hot, 1.0), Color(cy, 0.9), Color(0.1, 0.3, 0.6, 0.0)], 1.0, 0.04))
	_keep(1.2)

# ------------------------------------------------------------------------------------------ TOURBILLON

func _ph_whirl(target: Dictionary) -> void:
	_base_hue = 0.5
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var cy := _c(0.6, 0.95, 1.0)
	var hot := _c(0.95, 1.0, 1.0)
	var deep := _c(0.1, 0.4, 0.9)
	# lames qui tournent à plat autour du monstre, comme des éclairs sur un cercle, puis anneau de vent
	for k in 6:
		var a := float(k) / 6.0 * TAU
		var p := at + Vector3(cos(a), 0.0, sin(a)) * 0.0
		_later(0.04 * float(k), func():
			_streak(at, a + 1.5708, 3.4 * size, cy, 0.3, 0.0, 0.14, 0.9)
			_streak(at, a + 1.5708, 3.0 * size, hot, 0.26, 0.0, 0.05, 0.9))
	_helix(base, [Color(hot, 0.0), Color(cy, 0.9), Color(deep, 0.0)], 0.8 * size, 1.6 * size, 3.0, 60, 0.9)
	_halo_ring(at, cy, 3.0 * size, 0.6, 1.2)
	_ground_shock(base, cy, 3.4 * size, 0.6, 0.1)
	_later(0.3, func():
		_flare4(at, hot, 3.2 * size, 0.4, 0.5)
		_ph_hit(at, target, hot, cy, [Color(hot, 1.0), Color(cy, 0.9), Color(0.1, 0.3, 0.7, 0.0)], 1.1, 0.05))
	_keep(1.4)

# ------------------------------------------------------------------------------------------ PAS DE LA LAME

func _ph_step(target: Dictionary) -> void:
	_base_hue = 0.5
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var right := cam.global_transform.basis.x
	var cy := _c(0.6, 0.95, 1.0)
	var hot := _c(0.95, 1.0, 1.0)
	# fente : le danseur traverse le monstre en un éclair, images rémanentes derrière lui, traînée au sol
	var a := at - right * 2.2 * size
	var b := at + right * 2.2 * size
	for i in 4:
		_streak(at + Vector3(0, float(i - 1) * 0.1 * size, 0), 0.0, 5.2 * size, cy if i % 2 == 0 else hot, 0.22, 0.02 * float(i), 0.04 + 0.05 * float(i % 2), 0.0)
	_beam(a, b, hot, 0.1 * size, 0.2, 0.0)
	_ground_shock(Vector3(a.x, 0.04, a.z), cy, 1.6 * size, 0.4)
	_later(0.14, func():
		_flare4(at, hot, 3.2 * size, 0.4, 0.0)
		_ph_hit(at, target, hot, cy, [Color(hot, 1.0), Color(cy, 0.9), Color(0.1, 0.3, 0.7, 0.0)], 1.05, 0.05)
		_ground_shock(Vector3(b.x, 0.04, b.z), cy, 2.2 * size, 0.5)
		_ph_cut(at, 0.0, 4.6 * size, hot, cy, 0.0, 0.12, 0.0))
	_keep(1.2)

# ------------------------------------------------------------------------------------------ DANSE MORTELLE

func _ph_deadly(target: Dictionary) -> void:
	_base_hue = 0.93
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var rose := _c(1.0, 0.35, 0.65)
	var cy := _c(0.6, 0.9, 1.0)
	var hot := _c(1.0, 0.95, 0.98)
	var lamp := _lamp_node(at, rose, 0.7 * _g, 6.0)
	# valse de lames : arcs alternés rose et glacé de plus en plus rapides, finale en grande croix
	var n := 8
	for i in n:
		var side := 1.0 if i % 2 == 0 else -1.0
		var p := at + right * randf_range(-0.2, 0.2) * size + up * randf_range(-0.25, 0.25) * size
		var delay := 0.09 * float(i) * (1.0 - 0.025 * float(i))
		_streak(p, side * randf_range(0.4, 0.9), randf_range(3.0, 4.2) * size, rose if i % 2 == 0 else cy, 0.3, delay, 0.13, side * 0.6)
		_streak(p, side * 0.7, 2.8 * size, hot, 0.26, delay + 0.015, 0.045, side * 0.6)
		_later(delay + 0.09, func():
			_flash(_w_spark(), _hdr(hot, 1.3 * _g), p, 0.15, 0.7 * size, 0.18)
			_shake(0.01 * _pw, 0.06))
	_helix(base, [Color(hot, 0.0), Color(rose, 0.9), Color(cy, 0.0)], 0.7 * size, 1.5 * size, 2.5, 50, 1.0)
	_ground_shock(base, rose, 3.2 * size, 0.7, 0.15)
	_later(0.95, func():
		_streak(at, 0.8, 5.2 * size, rose, 0.3, 0.0, 0.26, 0.15)
		_streak(at, -0.8, 5.2 * size, cy, 0.3, 0.05, 0.26, -0.15)
		_later(0.2, func():
			_flare4(at, hot, 4.0 * size, 0.55, 0.3)
			_ph_hit(at, target, hot, rose, [Color(hot, 1.0), Color(rose, 0.9), Color(0.5, 0.05, 0.25, 0.0)], 1.4, 0.08, {
				"ground": [rose, 3.4, 0.6], "lamp": [rose, 2.6, 6.0, 0.6]})
			if lamp != null:
				var tw := create_tween()
				tw.tween_property(lamp, "light_energy", 3.0 * _g, 0.08)
				tw.tween_property(lamp, "light_energy", 0.0, 0.7)
				tw.tween_callback(lamp.queue_free)))
	_keep(2.4)

# ------------------------------------------------------------------------------------------ RALENTISSEMENT

func _ph_slow(target: Dictionary) -> void:
	_base_hue = 0.62
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var hot := _c(0.88, 0.95, 1.0)
	var mid := _c(0.45, 0.6, 1.0)
	var deep := _c(0.2, 0.2, 0.7)
	# le temps qui se fige : anneaux de lumière qui SE RESSERRENT autour du monstre, sable d'argent qui retombe lentement
	for i in 4:
		var d := 0.18 * float(i)
		var s := _sprite(_ring_tex_tint("slowring" + str(i), mid), Color(1, 1, 1, 0.9), 3.4 * size, at)
		(s.mat as StandardMaterial3D).no_depth_test = true
		_add(s, 1.3 + d, func(u: float):
			var w := clampf((u * (1.3 + d) - d) / 1.3, 0.0, 1.0)
			(s.node as Node3D).visible = w > 0.0
			(s.node as Node3D).scale = Vector3.ONE * lerpf(3.4, 0.9, 1.0 - pow(1.0 - w, 2.0)) * size
			(s.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.9)
	_halo_ring(at, mid, 2.2 * size, 1.2, 1.15, 0.1)
	_ground_shock(base, mid, 3.0 * size, 0.9)
	_lens(at, 3.2 * size, 0.06 * _pw, 1.1)
	var sand := _gpu(40, 1.6, true, _soft_mesh(hot, 1.1 * _g, _w_spark()),
		_pmat(0.7 * size, Vector3.DOWN, 25.0, 0.1, 0.4, Vector3(0, -0.25, 0), 0.04, 0.09, _ramp(Color(hot, 0.0), Color(hot, 1.0), Color(deep, 0.0)), 1.0, 0.5), at + up * 0.9 * size)
	_free_after(sand, 1.9)
	_bloom(at, 1.3 * size, 1.0, _c(0.05, 0.05, 0.2), deep, mid, true, 0.0)
	_later(0.5, func():
		_flare4(at, hot, 2.4 * size, 0.6, 0.15)
		_hit_fx(at, target, {"size": 0.8, "shocks": [[mid, 2.0, 0.6]], "lamp": [mid, 1.6, 4.5, 0.7]}))
	_keep(2.0)

# ------------------------------------------------------------------------------------------ FLÈCHE ARCANIQUE

func _ph_arcane_arrow(target: Dictionary) -> void:
	_base_hue = 0.74
	var start := _start_point() + _side(0.4)
	var end := _end_point(target)
	var dur := clampf(0.28 + start.distance_to(end) * 0.024, 0.3, 0.42)
	var vi := _c(0.65, 0.4, 1.0)
	var hot := _c(0.93, 0.88, 1.0)
	var deep := _c(0.3, 0.15, 0.8)
	var size := _tsize(target) * _s
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": _ph_blade_node(hot, vi, deep, "aarrow", Vector3(0.14, 0.24, 2.8), 1.4), "size": 0.8},
		"halo": [Color(vi, 0.5), 1.0], "core": 0.1,
		"arc": 0.0, "lift": 0.0, "ease": "accel", "grow": 0.0,
		"trails": [
			{"c": [Color(hot, 0.0), Color(vi, 0.9), Color(deep, 0.0)], "n": 36, "life": 0.35, "sz": [0.05, 0.13], "v": [0.05, 0.3], "k": 1.4, "radius": 0.05},
			{"c": [Color(vi, 0.0), Color(deep, 0.5), Color(deep, 0.0)], "n": 14, "life": 0.5, "sz": [0.25, 0.4], "v": [0.05, 0.2], "mix": true, "radius": 0.08, "tex": _smoke_puff()}],
		"lamp": [vi, 1.4, 4.0],
	}, func():
		_flare4(end, hot, 3.0 * size, 0.4, 0.2)
		_hit_fx(end, target, {
			"size": 0.9,
			"flash": [Color(vi, 0.9), 0.8],
			"shocks": [[vi, 2.2, 0.4], [hot, 1.4, 0.28, 0.06]],
			"lens": [2.6, 0.06],
			"sparks": {"c": [Color(hot, 1.0), Color(vi, 0.9), Color(deep, 0.0)], "n": 26, "v": [1.0, 3.4], "grav": Vector3(0, -1.0, 0), "life": 0.8},
			"lamp": [vi, 2.0, 5.0, 0.4], "shake": 0.025}))

# ------------------------------------------------------------------------------------------ VOLÉE PERÇANTE

func _ph_volley(target: Dictionary) -> void:
	_base_hue = 0.55
	var start := _start_point()
	var end := _end_point(target)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var cy := _c(0.45, 0.9, 1.0)
	var hot := _c(0.92, 1.0, 1.0)
	var deep := _c(0.1, 0.35, 0.85)
	var n := 5
	for i in n:
		var off := (float(i) - 2.0)
		var a := start + right * off * 0.35 - up * absf(off) * 0.05
		var b := end + right * off * 0.22 * size + up * (randf() - 0.5) * 0.4 * size
		var dur := clampf(0.26 + a.distance_to(b) * 0.022, 0.3, 0.42)
		_later(0.07 * float(i), func():
			_fly(a, b, dur, {
				"body": {"kind": "mesh", "node": _ph_blade_node(hot, cy, deep, "volley", Vector3(0.11, 0.2, 2.3), 1.3), "size": 0.7},
				"halo": [Color(cy, 0.4), 0.8], "core": 0.07,
				"arc": 0.0, "lift": 0.0, "ease": "accel", "grow": 0.0,
				"trails": [{"c": [Color(hot, 0.0), Color(cy, 0.85), Color(deep, 0.0)], "n": 26, "life": 0.28, "sz": [0.04, 0.1], "v": [0.05, 0.25], "k": 1.3, "radius": 0.04}],
			}, func():
				_flash(_w_soft(), _hdr(hot, 1.2 * _g), b, 0.2, 1.1 * size, 0.25)
				_shock(b, cy, 1.5 * size, 0.3)
				_hit_fx(b, target, {"size": 0.5, "sparks": {"c": [Color(hot, 1.0), Color(cy, 0.9), Color(deep, 0.0)], "n": 10, "v": [0.8, 2.6], "grav": Vector3(0, -3.0, 0), "life": 0.6},
					"shake": 0.01 if i == n - 1 else 0.0, "lamp": [cy, 1.2, 3.5, 0.25]})
				if i == 2:
					_lens(b, 2.6 * size, 0.05 * _pw, 0.4)))
	_later(0.07 * float(n - 1) + 0.35, func():
		_flare4(end, hot, 3.0 * size, 0.4, 0.0))
	_keep(1.4)

# ------------------------------------------------------------------------------------------ FLÈCHES STELLAIRES

func _ph_stars(target: Dictionary) -> void:
	_base_hue = 0.14
	var end := _end_point(target)
	var base := Vector3(end.x, 0.04, end.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var gold := _c(1.0, 0.85, 0.45)
	var hot := _c(1.0, 0.98, 0.88)
	var blue := _c(0.5, 0.65, 1.0)
	var n := 6
	var pts: Array = []
	for i in n:
		var p := end + right * randf_range(-0.7, 0.7) * size + up * randf_range(-0.45, 0.5) * size
		pts.append(p)
	# ciel étoilé : les flèches tombent du haut, têtes en étoile à quatre branches, puis une constellation relie les impacts
	for i in n:
		var p: Vector3 = pts[i]
		var from := p + up * 3.6 + right * 0.6
		var dur := 0.3
		_later(0.09 * float(i), func():
			_fly(from, p, dur, {
				"body": {"kind": "mesh", "node": _ph_blade_node(hot, gold, blue, "star", Vector3(0.1, 0.18, 2.0), 1.3), "size": 0.7},
				"halo": [Color(gold, 0.55), 0.8], "core": 0.08,
				"arc": 0.0, "lift": 0.0, "ease": "accel", "grow": 0.0,
				"trails": [{"c": [Color(hot, 0.0), Color(gold, 0.9), Color(blue, 0.0)], "n": 24, "life": 0.3, "sz": [0.05, 0.12], "v": [0.05, 0.25], "k": 1.4, "radius": 0.04}],
			}, func():
				_flare4(p, hot, 2.2 * size, 0.55, 0.4)
				_flash(_w_soft(), _hdr(gold, 1.2 * _g), p, 0.2, 1.4 * size, 0.3)
				_hit_fx(p, target, {"size": 0.45, "sparks": {"c": [Color(hot, 1.0), Color(gold, 0.9), Color(blue, 0.0)], "n": 8, "v": [0.6, 2.2], "grav": Vector3(0, -2.0, 0), "life": 0.6},
					"shake": 0.008, "lamp": [gold, 1.2, 3.5, 0.25]})))
	var t0 := 0.09 * float(n - 1) + dur_end()
	for i in n - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		_beam(a, b, gold.lerp(hot, 0.4), 0.04, 0.5, t0 + 0.05 * float(i))
	_later(t0 + 0.2, func():
		_flare4(end, hot, 3.6 * size, 0.55, 0.3)
		_shock(end, gold, 3.0 * size, 0.6)
		_ground_shock(base, gold, 3.0 * size, 0.6)
		_lens(end, 3.0 * size, 0.05 * _pw, 0.5)
		_fade_lamp(_lamp_node(end, gold, 2.4 * _g, 6.0), 0.6))
	_keep(2.0)

func dur_end() -> float:
	return 0.3
