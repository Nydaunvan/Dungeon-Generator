extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets de nature (Forward+ / Vulkan) : épine venimeuse (vraie épine qui file, gerbe de pointes et bulles toxiques), ronces entravantes
## (lianes épineuses qui jaillissent du sol), foudre sauvage (éclair en zigzag, branches, feuilles arrachées), essaim de guêpes (nuée
## qui fond sur chaque cible), bourgeon de vie (fleur qui s'ouvre sur l'allié) et souffle de la forêt (pluie de feuilles et floraisons
## sur tout le groupe) ; puis ceux du Gardien de la Forêt (écorce protectrice, sève régénérante, arbre-monde) et du Druide de la Tempête
## (ouragan de feuilles, colère de la nature). Vert vif et or de pollen ; feuilles opaques (mélange normal) pour que cela ressemble à du feuillage, pas à de la lumière.

static var _nat: Dictionary = {}

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.3
	match str(ctx.get("fx", "nature_thorn")):
		"nature_vines": _vines(target)
		"nature_lightning": _lightning(target)
		"nature_swarm": _swarm(target, ctx)
		"nature_bloom": _bud(ctx)
		"nature_grove": _grove(ctx)
		"nature_bark": _bark(ctx)
		"nature_sap": _sap(ctx)
		"nature_worldtree": _worldtree(ctx)
		"nature_cyclone": _cyclone(target, ctx)
		"nature_wrath": _wrath(target, ctx)
		_: _thorn(target)

# ------------------------------------------------------------------------------------------ palette et briques

func _n_hot() -> Color:
	return _c(0.88, 1.0, 0.72)

func _n_mid() -> Color:
	return _c(0.4, 0.92, 0.25)

func _n_deep() -> Color:
	return _c(0.07, 0.32, 0.09)

func _n_gold() -> Color:
	return _c(1.0, 0.9, 0.45)

func _ally_at(ctx: Dictionary, depth: float = 2.0) -> Vector3:
	return _slot_pos(int(ctx.get("ally", ctx.get("caster", 1))), depth)

## Feuille (pointe en haut, nervure centrale).
static func _leaf_tex() -> Texture2D:
	if _nat.has("leaf"):
		return _nat["leaf"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var t := (float(y) + 0.5) / float(n)          # 0 = pointe, 1 = base
			var half := sin(pow(t, 0.75) * PI) * 0.6
			var a := clampf((half - absf(u)) * 16.0, 0.0, 1.0)
			var rib := exp(-absf(u) * 26.0)
			var vein := 0.5 + 0.5 * sin((t * 9.0 - absf(u) * 4.0) * PI)
			var shade := 0.72 + 0.18 * (1.0 - absf(u) / maxf(half, 0.05)) + rib * 0.2 + vein * 0.06
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	var tex := ImageTexture.create_from_image(img)
	_nat["leaf"] = tex
	return tex

## Pétale (goutte allongée, pointe en haut).
static func _petal_tex() -> Texture2D:
	if _nat.has("petal"):
		return _nat["petal"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var t := (float(y) + 0.5) / float(n)
			var half := pow(sin(pow(t, 0.6) * PI), 0.8) * 0.5
			var a := clampf((half - absf(u)) * 14.0, 0.0, 1.0)
			var glow := 0.55 + 0.45 * t
			img.set_pixel(x, y, Color(glow, glow, glow, a * (0.85 + 0.15 * t)))
	var tex := ImageTexture.create_from_image(img)
	_nat["petal"] = tex
	return tex

## Épine : cône facetté, pointe vers -Z (avant du projectile).
static func _thorn_mesh() -> ArrayMesh:
	if _nat.has("thorn"):
		return _nat["thorn"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var tip := Vector3(0, 0, -0.75)
	var base_z := 0.25
	var r := 0.09
	var ring: Array = []
	for i in sides:
		var ang := TAU * float(i) / float(sides)
		ring.append(Vector3(cos(ang) * r, sin(ang) * r, base_z))
	for i in sides:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % sides]
		var sh := 0.65 + 0.35 * cos(TAU * (float(i) + 0.5) / float(sides) - 0.9)
		st.set_color(Color(0.95, 1.0, 0.8))
		st.add_vertex(tip)
		st.set_color(Color(0.38 * sh + 0.1, 0.9 * sh, 0.22 * sh, 1.0))
		st.add_vertex(a)
		st.add_vertex(b)
		st.set_color(Color(0.08, 0.28, 0.06))
		st.add_vertex(Vector3(0, 0, base_z + 0.05))
		st.add_vertex(b)
		st.add_vertex(a)
	var m := st.commit()
	_nat["thorn"] = m
	return m

## Liane : tube effilé qui s'enroule, avec des épines ; pousse le long de +Y (hauteur 1).
static func _vine_mesh(seed_i: int) -> ArrayMesh:
	var key := "vine%d" % seed_i
	if _nat.has(key):
		return _nat[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var segs := 26
	var sides := 7
	var turns := rng.randf_range(1.2, 2.2)
	var phase := rng.randf() * TAU
	var amp := rng.randf_range(0.16, 0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var centers: Array = []
	for s in segs + 1:
		var t := float(s) / float(segs)
		var c := Vector3(sin(t * TAU * turns + phase) * amp * t, t, cos(t * TAU * turns + phase) * amp * t)
		centers.append(c)
	var light := Vector3(0.5, 0.7, 0.5).normalized()
	for s in segs + 1:
		var t := float(s) / float(segs)
		var rad := lerpf(0.075, 0.008, pow(t, 0.8))
		var fwd: Vector3 = ((centers[mini(s + 1, segs)] as Vector3) - (centers[maxi(s - 1, 0)] as Vector3)).normalized()
		var side := fwd.cross(Vector3.RIGHT if absf(fwd.x) < 0.9 else Vector3.FORWARD).normalized()
		var up2 := fwd.cross(side).normalized()
		var ring: Array = []
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			var n := side * cos(ang) + up2 * sin(ang)
			var col := Color(0.12, 0.38, 0.1).lerp(Color(0.55, 1.0, 0.3), pow(t, 1.4))
			var sh := 0.45 + 0.55 * maxf(0.0, n.dot(light))
			ring.append([(centers[s] as Vector3) + n * rad, Color(col.r * sh, col.g * sh, col.b * sh, 1.0)])
		rings.append(ring)
	for s in segs:
		for k in sides:
			var a: Array = rings[s][k]
			var b: Array = rings[s][(k + 1) % sides]
			var c2: Array = rings[s + 1][k]
			var d: Array = rings[s + 1][(k + 1) % sides]
			for tri in [[a, c2, b], [b, c2, d]]:
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	# épines : petits cônes tournés vers l'extérieur
	for s in range(3, segs - 1, 3):
		var t := float(s) / float(segs)
		var c: Vector3 = centers[s]
		var ang := rng.randf() * TAU
		var out := Vector3(cos(ang), 0.35, sin(ang)).normalized()
		var tl := lerpf(0.09, 0.03, t)
		var bw := lerpf(0.04, 0.012, t)
		var perp := out.cross(Vector3.UP).normalized() * bw
		var perp2 := out.cross(perp).normalized() * bw
		var tip_p := c + out * tl
		var base_pts := [c + perp, c + perp2, c - perp, c - perp2]
		for k in 4:
			st.set_color(Color(0.95, 1.0, 0.75))
			st.add_vertex(tip_p)
			st.set_color(Color(0.3, 0.7, 0.18))
			st.add_vertex(base_pts[k])
			st.add_vertex(base_pts[(k + 1) % 4])
	var m := st.commit()
	_nat[key] = m
	return m

func _n_leaves(at: Vector3, size: float, n: int, v: Array = [1.0, 3.2], grav: Vector3 = Vector3(0, -2.2, 0), life: float = 1.3) -> void:
	var cs := [Color(0.55, 0.85, 0.25, 1.0), Color(0.22, 0.6, 0.12, 1.0), Color(0.12, 0.35, 0.08, 0.0)]
	var pm := _pmat(0.1, Vector3.UP, 180.0, float(v[0]) * size, float(v[1]) * size, grav, 0.14, 0.28, _ramp(cs[0], cs[1], cs[2]), 0.35, 0.9)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -220.0
	pm.angular_velocity_max = 220.0
	_free_after(_gpu(n, life, true, _smoke_mesh(Color.WHITE, _leaf_tex()), pm, at), life + 0.2)

func _n_hit(at: Vector3, target: Dictionary, big: float = 1.0, shake: float = 0.03, extra: Dictionary = {}) -> void:
	var hot := _n_hot()
	var mid := _n_mid()
	var deep := _n_deep()
	var p := {
		"size": big,
		"flash": [Color(hot, 0.9), 0.9],
		"shocks": [[mid, 2.4, 0.4], [hot, 1.5, 0.28, 0.06]],
		"ground": [mid, 2.6, 0.55],
		"lens": [2.4, 0.05],
		"sparks": {"c": [Color(hot, 1.0), Color(mid, 0.9), Color(deep, 0.0)], "n": 24, "v": [0.8, 3.2], "grav": Vector3(0, -2.5, 0), "life": 0.8},
		"lamp": [mid, 1.8, 4.5, 0.4],
		"shake": shake,
	}
	p.merge(extra, true)
	_hit_fx(at, target, p)
	_n_leaves(at, _tsize(target) * big * _s, 8)

# ------------------------------------------------------------------------------------------ ÉPINE VENIMEUSE

func _thorn(target: Dictionary) -> void:
	var start := _start_point() + cam.global_transform.basis.x * 0.3
	var end := _end_point(target)
	var dur := clampf(0.3 + start.distance_to(end) * 0.028, 0.34, 0.48)
	var size := _tsize(target) * _s
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _thorn_mesh()
	mi.material_override = _vcol_mat(1.25 * _g)
	mi.scale = Vector3(1.0, 1.0, 1.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": node, "size": 0.8},
		"halo": [Color(_n_mid(), 0.4), 0.9], "core": 0.06,
		"arc": 0.1, "lift": 0.05, "ease": "accel", "grow": 0.0, "spin": 0.0,
		"trails": [
			{"c": [Color(_n_hot(), 0.0), Color(_n_mid(), 0.9), Color(_n_deep(), 0.0)], "n": 30, "life": 0.3, "sz": [0.05, 0.12], "v": [0.05, 0.3], "k": 1.3, "radius": 0.05},
			{"c": [Color(0.35, 0.8, 0.2, 0.0), Color(0.2, 0.5, 0.1, 0.55), Color(0.05, 0.15, 0.03, 0.0)], "n": 12, "life": 0.45, "sz": [0.16, 0.3], "v": [0.05, 0.2], "mix": true, "radius": 0.06, "turb": 0.5, "tex": _smoke_puff()}],
		"lamp": [_n_mid(), 1.3, 4.0],
	}, func():
		# gerbe de pointes qui jaillissent de l'impact
		_hit_fx(end, target, {"shards": {"mesh": _thorn_mesh(), "n": 12, "v": [1.6, 3.6], "sz": [0.16, 0.3], "grav": Vector3(0, -3.0, 0)}, "size": 1.0})
		_n_hit(end, target, 0.95, 0.025)
		# bulles de poison
		var bub := _gpu(14, 1.2, true, _soft_mesh(_n_mid(), 0.9 * _g, _w_spark()),
			_pmat_grow(0.3 * size, Vector3.UP, 25.0, 0.3, 0.8, Vector3(0, 0.3, 0), 0.05, 0.14, _ramp(Color(_n_hot(), 0.0), Color(_n_mid(), 0.9), Color(_n_deep(), 0.0)), 0.5, 0.3), end)
		_free_after(bub, 1.5))

# ------------------------------------------------------------------------------------------ RONCES ENTRAVANTES

func _vines(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	_ground_shock(base, _n_mid(), 3.4 * size, 0.7)
	var lamp := _lamp_node(at, _n_mid(), 0.8 * _g, 5.5)
	var n := 8
	for i in n:
		var ang := float(i) / float(n) * TAU + randf() * 0.4
		var r := (0.3 + randf() * 0.4) * size
		var p := base + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var h := (1.5 + randf() * 1.0) * size
		var delay := 0.05 * float(i)
		var life := 1.5
		_later(delay, func():
			var mat := _vcol_mat(1.1 * _g)
			var vm := _mesh_node(_vine_mesh(1 + i % 4), mat, p, 1.0)
			vm.rotation.y = ang
			var seed_f := randf() * TAU
			_add({"node": vm}, life, func(u: float):
				var grow := 1.0 - pow(1.0 - clampf(u / 0.28, 0.0, 1.0), 3.0)
				var wither := 1.0 - clampf((u - 0.72) / 0.28, 0.0, 1.0)
				vm.scale = Vector3(size * 1.3 * (0.6 + 0.4 * wither), h * grow * (0.15 + 0.85 * wither), size * 1.3 * (0.6 + 0.4 * wither))
				vm.rotation.z = sin(u * 7.0 + seed_f) * 0.07 * grow))
		_later(delay + 0.04, func():
			_n_leaves(p + Vector3(0, 0.1, 0), 0.4 * size, 2, [0.5, 1.5], Vector3(0, -1.5, 0), 1.0))
	_later(0.35, func():
		_n_hit(at, target, 1.0, 0.04, {"ground": [_n_mid(), 3.0, 0.6]})
		_shock(at, _n_hot(), 1.4 * size, 0.5))
	_later(0.9, func():
		if lamp != null:
			var tw := create_tween()
			tw.tween_property(lamp, "light_energy", 0.0, 0.6)
			tw.tween_callback(lamp.queue_free))
	_keep(2.0)

# ------------------------------------------------------------------------------------------ FOUDRE SAUVAGE

func _zigzag(a: Vector3, b: Vector3, n: int, jitter: float) -> Array:
	var right := cam.global_transform.basis.x
	var pts: Array = [a]
	var axis := b - a
	for i in range(1, n):
		var t := float(i) / float(n)
		pts.append(a + axis * t + right * randf_range(-1.0, 1.0) * jitter + cam.global_transform.basis.y * randf_range(-0.3, 0.3) * jitter)
	pts.append(b)
	return pts

func _bolt(pts: Array, col: Color, width: float, dur: float, delay: float = 0.0) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := (b - a) * 0.3                  # les segments se recouvrent : l'éclair reste continu
		_beam(a - d, b + d, col, width, dur, delay)

func _lightning(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var top := at + up * 4.2 + right * randf_range(-0.5, 0.5)
	var glow := _c(0.7, 1.0, 0.45)
	var white := _c(0.95, 1.0, 0.9)
	_flash(_w_soft(), _hdr(Color(glow, 0.45), 0.7 * _g), top, 1.5, 6.0, 0.35, true)       # le ciel s'allume
	_later(0.12, func():
		var main_pts := _zigzag(top, at, 9, 0.38)
		_bolt(main_pts, glow, 0.5 * size, 0.3)
		_bolt(main_pts, white, 0.16 * size, 0.28)
		for b in 3:
			var from: Vector3 = main_pts[2 + b * 2]
			var to := from + (at - top).normalized() * 1.2 + right * randf_range(-1.2, 1.2) * size + up * randf_range(-0.6, 0.2)
			_bolt(_zigzag(from, to, 4, 0.2), glow, 0.2 * size, 0.24, 0.05)
		_flare4(at, white, 3.4 * size, 0.45, 0.2)
		_flash(_w_soft(), _hdr(white, 1.3 * _g), at, 0.3, 2.0 * size, 0.3)
		_ground_shock(base, glow, 3.4 * size, 0.55)
		_n_hit(at, target, 1.25, 0.07, {"shocks": [[glow, 3.0, 0.45], [white, 1.8, 0.3, 0.05]], "lens": [3.2, 0.08]})
		_n_leaves(at, 1.4 * size, 10, [2.0, 5.0], Vector3(0, -3.0, 0), 1.2)
		_fade_lamp(_lamp_node(at + up * 0.5, glow, 3.4 * _g, 7.0), 0.5))
	_keep(1.6)

# ------------------------------------------------------------------------------------------ ESSAIM DE GUÊPES

func _swarm(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if str(ctx.get("mode", "damage")) != "damageGroup" or pts.is_empty():
		pts = [target] if not target.is_empty() else [{}]
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.12 * float(i), func(): _swarm_one(tt))
		i += 1
	_keep(2.4)

func _swarm_one(target: Dictionary) -> void:
	var start := _start_point() + cam.global_transform.basis.x * randf_range(-0.4, 0.4)
	var end := _end_point(target)
	var dur := clampf(0.5 + start.distance_to(end) * 0.04, 0.55, 0.8)
	var size := _tsize(target) * _s
	var amber := _c(1.0, 0.78, 0.2)
	_fly(start, end, dur, {
		"body": {"kind": "none"},
		"arc": 0.5, "lift": 0.2, "ease": "smooth", "grow": 0.0,
		"trails": [
			{"c": [Color(0.05, 0.04, 0.02, 0.0), Color(0.06, 0.05, 0.02, 0.95), Color(0.0, 0.0, 0.0, 0.0)], "n": 46, "life": 0.5, "sz": [0.04, 0.09], "v": [0.2, 0.9], "mix": true, "radius": 0.28, "turb": 1.8, "tex": _w_spark()},
			{"c": [Color(amber, 0.0), Color(amber, 1.0), Color(0.6, 0.3, 0.05, 0.0)], "n": 34, "life": 0.35, "sz": [0.03, 0.07], "v": [0.2, 0.8], "k": 1.3, "radius": 0.3, "turb": 1.6}],
		"lamp": [amber, 0.8, 3.0],
	}, func():
		_flash(_w_spark(), _hdr(amber, 1.2 * _g), end, 0.2, 1.2 * size, 0.25)
		_n_hit(end, target, 0.75, 0.02, {"flash": [Color(amber, 0.8), 0.7], "shocks": [[amber, 1.8, 0.3]], "lens": [0.0, 0.0],
			"sparks": {"c": [Color(1.0, 0.95, 0.6, 1.0), Color(amber, 0.9), Color(0.5, 0.25, 0.03, 0.0)], "n": 20, "v": [0.6, 2.4], "grav": Vector3(0, -1.5, 0), "life": 0.7}})
		# la nuée reste un instant autour de la cible, piquants lumineux
		var cloud := _gpu(40, 1.1, false, _soft_mesh(amber, 1.1 * _g, _w_spark()),
			_pmat(0.55 * size, Vector3.UP, 180.0, 0.1, 0.5, Vector3.ZERO, 0.03, 0.07, _ramp(Color(1, 0.95, 0.6, 0.0), Color(amber, 1.0), Color(0.5, 0.3, 0.05, 0.0)), 0.3, 1.6), end)
		var dark := _gpu(30, 1.1, false, _smoke_mesh(Color.WHITE, _w_spark()),
			_pmat(0.55 * size, Vector3.UP, 180.0, 0.1, 0.5, Vector3.ZERO, 0.04, 0.09, _ramp(Color(0.05, 0.04, 0.02, 0.0), Color(0.05, 0.04, 0.02, 0.95), Color(0, 0, 0, 0.0)), 0.3, 1.6), end)
		_later(0.7, func():
			cloud.emitting = false
			dark.emitting = false
			_free_after(cloud, 1.3)
			_free_after(dark, 1.3))
		for k in 5:
			_later(0.1 * float(k), func():
				_flash(_w_spark(), _hdr(_c(1.0, 0.95, 0.6), 1.3 * _g), end + Vector3(randf_range(-0.4, 0.4), randf_range(-0.4, 0.5), 0.0) * size, 0.1, 0.45 * size, 0.14)))

# ------------------------------------------------------------------------------------------ BOURGEON DE VIE

## Fleur qui s'ouvre en `at` : pétales en couronne, cœur de pollen, feuilles qui tournent.
func _flower(at: Vector3, size: float, delay: float = 0.0, dur: float = 1.5) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var petals := 8
	var pink := _c(1.0, 0.82, 0.92)
	for layer in 2:
		for k in petals:
			var a0 := float(k) / float(petals) * TAU + float(layer) * PI / float(petals)
			var col := pink.lerp(_n_hot(), 0.35 + 0.35 * float(layer))
			var s := _sprite(_petal_tex(), Color(col.r, col.g, col.b, 1.0), 0.4 * size, at)
			(s.mat as StandardMaterial3D).no_depth_test = true
			(s.mat as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			var rad := 0.34 * size * (1.0 - 0.35 * float(layer))
			_add(s, dur + delay, func(u: float):
				var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
				(s.node as Node3D).visible = w > 0.0
				var open := 1.0 - pow(1.0 - clampf(w / 0.45, 0.0, 1.0), 3.0)
				var a := a0 + w * 0.8
				(s.node as Node3D).position = at + (right * cos(a) + up * sin(a) * 0.9) * rad * open
				(s.node as Node3D).rotation.z = a - PI * 0.5
				(s.node as Node3D).scale = Vector3.ONE * 0.45 * size * open * (1.0 - 0.2 * float(layer))
				(s.mat as StandardMaterial3D).albedo_color.a = sin(minf(w * 1.15, 1.0) * PI) * 0.95)
	_later(delay, func():
		_flash(_w_soft(), _hdr(_n_gold(), 1.0 * _g), at, 0.2 * size, 1.1 * size, 0.7, true)
		_flare4(at, _n_gold(), 1.7 * size, 0.7, 0.3)
		_helix(at - up * 0.35 * size, [Color(_n_hot(), 0.0), Color(_n_mid(), 0.95), Color(_n_deep(), 0.0)], 0.4 * size, 1.1 * size, 2.0, 24, 0.7, _leaf_tex(), [0.07, 0.14])
		var pollen := _gpu(22, 1.3, true, _soft_mesh(_n_gold(), 1.2 * _g, _w_spark()),
			_pmat_grow(0.12 * size, Vector3.UP, 60.0, 0.3, 0.9, Vector3(0, 0.2, 0), 0.04, 0.1, _ramp(Color(1, 1, 0.8, 0.0), Color(_n_gold(), 1.0), Color(0.8, 0.5, 0.1, 0.0)), 0.4, 0.4), at)
		_free_after(pollen, 1.5))

func _bud(ctx: Dictionary) -> void:
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	_flash(_w_soft(), _hdr(_n_mid(), 0.9 * _g), at, 0.5, 2.0, 0.6, true)
	_pillar(at - up * 1.0, 1.4, 3.0, SH_PILLAR, "pillar", {"col": _n_mid(), "core": _n_hot(), "power": 0.4 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.0}, 1.2,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("fade", sin(u * PI) * 0.8))
	_flower(at + up * 0.15, 1.0)
	_halo_ring(at - up * 0.3, _n_mid(), 2.0, 0.9, 1.15, 0.1)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, _n_mid(), 1.5 * _g, 4.0), 1.0)
	_keep(1.8)

# ------------------------------------------------------------------------------------------ SOUFFLE DE LA FORÊT

func _grove(_ctx: Dictionary, rain_for: float = 1.5, rain_free: float = 2.2) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	# pluie de feuilles sur toute la largeur de la vue
	var top := cam.global_position + _fwd() * 2.6 + up * 1.6
	var pm := _pmat(0.1, Vector3.DOWN, 12.0, 0.2, 0.6, Vector3(0, -0.9, 0), 0.16, 0.3,
		_ramp(Color(0.55, 0.9, 0.3, 0.0), Color(0.3, 0.75, 0.18, 1.0), Color(0.12, 0.4, 0.08, 0.0)), 0.2, 1.1)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.6, 0.1, 0.6)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -160.0
	pm.angular_velocity_max = 160.0
	var rain := _gpu(70, 2.0, false, _smoke_mesh(Color.WHITE, _leaf_tex()), pm, top)
	rain.global_transform = Transform3D(cam.global_transform.basis, top)
	_later(rain_for, func():
		rain.emitting = false
		_free_after(rain, rain_free))
	for i in _party_slots():
		var at := _slot_pos(int(i), 2.0)
		_flower(at + up * 0.1, 0.8, 0.12 * float(i), 1.3)
		_pillar(at - up * 1.0, 1.2, 2.6, SH_PILLAR, "pillar", {"col": _n_mid(), "core": _n_hot(), "power": 0.3 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.0}, 1.2,
			func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
				m.set_shader_parameter("fade", sin(u * PI) * 0.7))
		_later(0.12 * float(i), func(): _shock(at, _n_mid(), 1.8, 0.6))
	_fade_lamp(_lamp_node(cam.global_position + _fwd() * 1.2, _n_mid(), 1.6 * _g, 6.0), 1.4)
	_keep(2.4)

# ------------------------------------------------------------------------------------------ LIANES AUTOUR D'UN POINT

## Couronne de lianes qui jaillissent du sol autour de `base`, restent un instant puis se flétrissent.
func _vine_ring(base: Vector3, size: float, n: int, hgt: float, life: float, radius: float, delay0: float = 0.0) -> void:
	for i in n:
		var ang := float(i) / float(n) * TAU + randf() * 0.4
		var r := radius * (0.7 + randf() * 0.5) * size
		var p := base + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var h := hgt * (0.75 + randf() * 0.5) * size
		_later(delay0 + 0.05 * float(i), func():
			var vm := _mesh_node(_vine_mesh(1 + i % 4), _vcol_mat(1.1 * _g), p, 1.0)
			vm.rotation.y = ang
			var seed_f := randf() * TAU
			_add({"node": vm}, life, func(u: float):
				var grow := 1.0 - pow(1.0 - clampf(u / 0.28, 0.0, 1.0), 3.0)
				var wither := 1.0 - clampf((u - 0.72) / 0.28, 0.0, 1.0)
				vm.scale = Vector3(size * 1.2 * (0.6 + 0.4 * wither), h * grow * (0.15 + 0.85 * wither), size * 1.2 * (0.6 + 0.4 * wither))
				vm.rotation.z = sin(u * 7.0 + seed_f) * 0.07 * grow))

# ------------------------------------------------------------------------------------------ ÉCORCE PROTECTRICE

func _bark(ctx: Dictionary) -> void:
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var bark := _c(0.78, 0.5, 0.22)
	var moss := _n_mid()
	_flash(_w_soft(), _hdr(Color(moss, 0.9), 0.9 * _g), at, 0.5, 2.0, 0.55, true)
	_dome(at + up * 0.1, 0.8, _c(0.5, 0.78, 0.25), 1.7, 0.6)
	_vine_ring(at - up * 0.95, 0.55, 6, 1.5, 1.7, 0.45)
	# plaques d'écorce qui se posent autour du héros
	for k in 6:
		var a := float(k) / 6.0 * TAU
		var p := at + right * cos(a) * 0.6 + up * sin(a) * 0.62
		_streak(p, a + PI * 0.5, 0.7, bark.lerp(_n_hot(), 0.25), 0.5, 0.07 * float(k), 0.14, 0.3)
	_helix(at - up * 0.6, [Color(_n_hot(), 0.0), Color(moss, 0.95), Color(_n_deep(), 0.0)], 0.6, 1.0, 1.6, 26, 0.9, _leaf_tex(), [0.07, 0.14])
	_n_leaves(at, 0.5, 8, [0.8, 1.8], Vector3(0, -1.2, 0), 1.2)
	_shock(at - up * 0.8, moss, 2.0, 0.6)
	_halo_ring(at - up * 0.7, bark, 1.8, 0.8, 1.15, 0.05)
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, moss, 1.4 * _g, 4.0), 0.9)
	_keep(2.0)

# ------------------------------------------------------------------------------------------ SÈVE RÉGÉNÉRANTE

func _sap(ctx: Dictionary) -> void:
	var at := _ally_at(ctx)
	var up := cam.global_transform.basis.y
	var amber := _c(1.0, 0.78, 0.28)
	var deep := _c(0.6, 0.32, 0.06)
	_flash(_w_soft(), _hdr(Color(amber, 0.9), 1.0 * _g), at, 0.5, 2.2, 0.7, true)
	_pillar(at - up * 1.0, 1.1, 3.2, SH_PILLAR, "pillar", {"col": amber, "core": _n_hot(), "power": 0.45 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.6}, 1.3,
		func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
			m.set_shader_parameter("fade", sin(u * PI) * 0.85))
	# gouttes de sève dorée qui montent en spirale, feuilles qui tournent en sens inverse
	_helix(at - up * 0.75, [Color(_n_hot(), 0.0), Color(amber, 0.95), Color(deep, 0.0)], 0.5, 1.5, 2.6, 42, 1.0)
	_helix(at - up * 0.75, [Color(_n_hot(), 0.0), Color(_n_mid(), 0.95), Color(_n_deep(), 0.0)], 0.66, 1.2, -1.9, 18, 0.9, _leaf_tex(), [0.07, 0.14])
	_halo_ring(at - up * 0.8, amber, 2.0, 0.9, 1.15)
	_halo_ring(at - up * 0.8, _n_mid(), 1.4, 0.8, 1.15, 0.2)
	_n_leaves(at - up * 0.6, 0.7, 8, [0.8, 2.0], Vector3(0, 1.0, 0), 1.4)
	_later(0.35, func(): _flash(_w_spark(), _hdr(_n_gold(), 1.2 * _g), at + up * 0.2, 0.2, 1.0, 0.4))
	_fade_lamp(_lamp_node(at + _fwd() * -0.3, amber, 1.5 * _g, 4.0), 1.1)
	_keep(1.9)

# ------------------------------------------------------------------------------------------ ARBRE-MONDE

## Tronc : cône évasé à la base (racines), écorce striée, pousse le long de +Y (hauteur 1, rayon de base 1).
static func _trunk_mesh() -> ArrayMesh:
	if _nat.has("trunk"):
		return _nat["trunk"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var segs := 18
	var sides := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var light := Vector3(0.5, 0.6, 0.6).normalized()
	var rings: Array = []
	for s in segs + 1:
		var t := float(s) / float(segs)
		var rad := lerpf(0.2, 0.075, pow(t, 0.7)) + 0.22 * pow(1.0 - t, 6.0)      # évasement des racines
		var ring: Array = []
		for k in sides:
			var ang := TAU * float(k) / float(sides)
			var n := Vector3(cos(ang), 0.0, sin(ang))
			var bump := 1.0 + 0.16 * sin(ang * 5.0 + t * 3.0) * (1.0 - t * 0.5)
			var sh := 0.4 + 0.6 * maxf(0.0, n.dot(light))
			var stripe := 0.78 + 0.22 * sin(ang * 9.0 + t * 5.0)
			var col := Color(0.36, 0.22, 0.1).lerp(Color(0.48, 0.34, 0.16), t) * sh * stripe
			ring.append([Vector3(n.x * rad * bump, t, n.z * rad * bump), Color(col.r, col.g, col.b, 1.0)])
		rings.append(ring)
	for s in segs:
		for k in sides:
			var a: Array = rings[s][k]
			var b: Array = rings[s][(k + 1) % sides]
			var c: Array = rings[s + 1][k]
			var d: Array = rings[s + 1][(k + 1) % sides]
			for tri in [[a, c, b], [b, c, d]]:
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	var m := st.commit()
	_nat["trunk"] = m
	return m

func _worldtree(ctx: Dictionary) -> void:
	var up := cam.global_transform.basis.y
	var c: Vector3 = _party_ends(3.0)[2]
	var base := c - up * 1.1
	var height := 3.8
	var tm := _mesh_node(_trunk_mesh(), _vcol_mat(1.05 * _g), base, 1.0)
	tm.scale = Vector3(0.01, 0.01, 0.01)
	_add({"node": tm}, 2.8, func(u: float):
		var grow := 1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 3.0)
		var fade := 1.0 - clampf((u - 0.8) / 0.2, 0.0, 1.0)
		tm.scale = Vector3(2.6 * (0.3 + 0.7 * grow) * (0.4 + 0.6 * fade), height * grow * (0.2 + 0.8 * fade), 2.6 * (0.3 + 0.7 * grow) * (0.4 + 0.6 * fade)))
	_ground_shock(Vector3(base.x, base.y + 0.05, base.z), _n_mid(), 4.2, 0.8)
	_vine_ring(base, 1.0, 7, 1.0, 2.6, 0.55)
	# branches : lianes qui s'écartent depuis la cime
	var top := base + up * height * 0.9
	for k in 5:
		var a := lerpf(-1.0, 1.0, float(k) / 4.0)
		_later(0.35 + 0.06 * float(k), func():
			var bm := _mesh_node(_vine_mesh(1 + k % 4), _vcol_mat(1.1 * _g), top - up * 0.3, 1.0)
			bm.rotation.z = -a * 1.1
			_add({"node": bm}, 2.0, func(u: float):
				var grow := 1.0 - pow(1.0 - clampf(u / 0.35, 0.0, 1.0), 3.0)
				var wither := 1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0)
				bm.scale = Vector3(2.0 * wither, 2.4 * grow * (0.2 + 0.8 * wither), 2.0 * wither)))
	# cime : lueur et gerbe de feuilles, puis la pluie de soin du souffle de la forêt
	_later(0.5, func():
		_flash(_w_soft(), _hdr(_n_mid(), 1.0 * _g), top, 1.0, 5.0, 1.4, true)
		_flash(_w_soft(), _hdr(_n_gold(), 0.7 * _g), top, 0.6, 3.0, 1.0, true)
		_crown(top, 1.7, 2.0)
		_flare4(top, _n_gold(), 3.0, 0.9, 0.3))
	_later(0.45, func(): _grove(ctx, 0.9, 1.7))
	_fade_lamp(_lamp_node(top, _n_mid(), 2.0 * _g, 8.0), 2.4)
	_keep(3.0)

## Couronne de feuillage : feuilles opaques qui naissent dans une sphère de rayon `radius` autour de `at` et y restent `dur` secondes.
func _crown(at: Vector3, radius: float, dur: float) -> void:
	var pm := _pmat(radius, Vector3.UP, 180.0, 0.05, 0.35, Vector3(0, -0.15, 0), 0.34, 0.6,
		_ramp(Color(0.55, 0.9, 0.3, 0.0), Color(0.3, 0.78, 0.18, 1.0), Color(0.14, 0.45, 0.08, 0.0)), 0.5, 0.3)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -40.0
	pm.angular_velocity_max = 40.0
	var crown := _gpu(90, 1.8, false, _smoke_mesh(Color.WHITE, _leaf_tex()), pm, at)
	_later(dur * 0.55, func():
		crown.emitting = false
		_free_after(crown, 1.9))

# ------------------------------------------------------------------------------------------ OURAGAN DE FEUILLES

func _cyclone(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if str(ctx.get("mode", "damage")) != "damageGroup" or pts.is_empty():
		pts = [target] if not target.is_empty() else [{}]
	var src := _start_point()
	_flash(_w_soft(), _hdr(Color(_n_mid(), 0.7), 0.8 * _g), src, 0.3, 1.5, 0.4, true)
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.08 + 0.13 * float(i), func(): _cyclone_one(tt))
		i += 1
	_keep(2.6)

func _cyclone_one(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.05, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	_ground_shock(base, _n_mid(), 3.2 * size, 0.7)
	# colonne de feuilles et de poussière verte qui tourne et monte
	for layer in 3:
		var rad := (0.3 + 0.2 * float(layer)) * size
		_helix(base, [Color(_n_hot(), 0.0), Color(_n_mid(), 1.0), Color(_n_deep(), 0.0)], rad, (1.6 + 0.5 * float(layer)) * size, (3.4 - 0.8 * float(layer)) * (1.0 if layer % 2 == 0 else -1.0), 34, 0.9, _leaf_tex(), [0.2, 0.36])
	_helix(base, [Color(1, 1, 0.85, 0.0), Color(0.8, 1.0, 0.6, 0.7), Color(0.3, 0.6, 0.2, 0.0)], 0.5 * size, 1.8 * size, 4.0, 24, 0.9)
	for k in 4:
		var a := randf() * TAU
		_streak(base + up * (0.3 + 0.45 * float(k)) * size, a, 1.6 * size, _n_hot().lerp(_n_mid(), 0.4), 0.55, 0.06 * float(k), 0.1, 0.8)
	_fade_lamp(_lamp_node(at, _n_mid(), 1.6 * _g, 5.0), 0.9)
	_later(0.45, func():
		_n_hit(at, target, 1.15, 0.05, {"shocks": [[_n_mid(), 3.0, 0.45], [_n_hot(), 1.8, 0.3, 0.05]], "lens": [2.8, 0.06]})
		_n_leaves(at, 1.2 * size, 12, [2.0, 4.5], Vector3(0, -2.0, 0), 1.2))

# ------------------------------------------------------------------------------------------ COLÈRE DE LA NATURE

func _wrath(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if str(ctx.get("mode", "damage")) != "damageGroup" or pts.is_empty():
		pts = [target] if not target.is_empty() else [{}]
	var up := cam.global_transform.basis.y
	var glow := _c(0.7, 1.0, 0.45)
	# le ciel s'obscurcit puis s'embrase, le sol tremble
	_flash(_w_soft(), _hdr(Color(glow, 0.5), 1.0 * _g), cam.global_position + _fwd() * 3.2 + up * 2.2, 1.0, 10.0, 0.7, true)
	_fade_lamp(_lamp_node(cam.global_position + _fwd() * 2.0 + up * 1.5, glow, 2.2 * _g, 9.0), 1.6)
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.3 + 0.16 * float(i), func(): _wrath_one(tt))
		i += 1
	_keep(2.8)

func _wrath_one(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var top := at + up * 4.6 + right * randf_range(-0.6, 0.6)
	var glow := _c(0.7, 1.0, 0.45)
	var white := _c(0.95, 1.0, 0.9)
	var pts := _zigzag(top, at, 10, 0.45)
	_bolt(pts, glow, 0.75 * size, 0.34)
	_bolt(pts, white, 0.24 * size, 0.3)
	for b in 4:
		var from: Vector3 = pts[2 + b * 2]
		var to := from + (at - top).normalized() * 1.4 + right * randf_range(-1.5, 1.5) * size + up * randf_range(-0.8, 0.2)
		_bolt(_zigzag(from, to, 4, 0.22), glow, 0.24 * size, 0.26, 0.05)
	_flare4(at, white, 4.0 * size, 0.5, 0.2)
	_flash(_w_soft(), _hdr(white, 1.4 * _g), at, 0.3, 2.4 * size, 0.35)
	_ground_shock(base, glow, 4.0 * size, 0.6)
	_vine_ring(base, size, 6, 1.9, 1.4, 0.55, 0.05)
	_n_hit(at, target, 1.5, 0.08, {"shocks": [[glow, 3.4, 0.5], [white, 2.0, 0.32, 0.05]], "lens": [3.4, 0.09],
		"shards": {"mesh": _thorn_mesh(), "n": 14, "v": [2.0, 4.0], "sz": [0.18, 0.34], "grav": Vector3(0, -3.0, 0)}})
	_n_leaves(at, 1.6 * size, 14, [2.0, 5.0], Vector3(0, -3.0, 0), 1.3)
	_fade_lamp(_lamp_node(at + up * 0.5, glow, 3.4 * _g, 7.0), 0.6)
