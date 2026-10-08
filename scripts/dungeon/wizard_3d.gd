class_name Wizard3D
extends Node3D
## Le magicien de l'étal (Merchant3D), sculpté par le code : tête modelée (arcades, nez, pommettes, orbites, lèvres, menton) avec
## couleurs de peau par sommet, yeux à iris et paupières qui clignent, sourcils/moustache/barbe/cheveux faits de centaines de mèches,
## oreilles, cou, bras en manches effilées et vraies mains (paume, 4 doigts à 3 phalanges, pouce, ongles) posées sur le comptoir.
## Repère local : pieds en y = 0, face à +Z. Le buste est à y = 1.15 (le dessus du comptoir est à y = 1.165).

const HEAD_R := Vector3(0.172, 0.228, 0.2)
const SKIN := Color(0.74, 0.62, 0.56)

var _torso: Node3D
var _head: Node3D
var _lids_up: Array = []
var _lids_dn: Array = []
var _eyes: Array = []
var _t := 0.0
var _next_blink := 2.5
var _blink := -1.0
var _rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ matériaux

static func _skin_mat(vertex_colors: bool, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "w|skin|%s|%s" % [vertex_colors, tint.to_html()]
	if Merchant3D._cache.has(key):
		return Merchant3D._cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.vertex_color_use_as_albedo = vertex_colors
	m.roughness = 0.52
	m.metallic_specular = 0.45
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.6
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.045
	nz.fractal_octaves = 4
	var nt := NoiseTexture2D.new()
	nt.noise = nz
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 2.2
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.55
	m.uv1_scale = Vector3(5, 4, 1)
	Merchant3D._cache[key] = m
	return m

static func _hair_mat() -> StandardMaterial3D:
	var key := "w|hair"
	if Merchant3D._cache.has(key):
		return Merchant3D._cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.62
	m.metallic_specular = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.25
	Merchant3D._cache[key] = m
	return m

# ------------------------------------------------------------------ primitives

func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _ball(r: float, mat: Material, pos: Vector3, parent: Node3D, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	var mi := _add(s, mat, pos, parent)
	mi.scale = sc
	return mi

## Tube effilé à bouts arrondis entre deux points.
func _tube(p0: Vector3, p1: Vector3, r0: float, r1: float, mat: Material, parent: Node3D, seg: int = 16) -> MeshInstance3D:
	var h := p0.distance_to(p1)
	var prof := [Vector2(0.0, -r0), Vector2(r0 * 0.55, -r0 * 0.83), Vector2(r0 * 0.9, -r0 * 0.44), Vector2(r0, 0.0),
		Vector2(lerpf(r0, r1, 0.5), h * 0.5), Vector2(r1, h), Vector2(r1 * 0.9, h + r1 * 0.44), Vector2(r1 * 0.55, h + r1 * 0.83), Vector2(0.0, h + r1)]
	var mi := _add(Merchant3D.lathe(prof, seg), mat, p0, parent)
	var dir := (p1 - p0).normalized()
	if dir.dot(Vector3.UP) < -0.999:
		mi.basis = Basis(Vector3.RIGHT, PI)
	else:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))
	return mi

# ------------------------------------------------------------------ mèches (rubans effilés, deux faces)

## paths : liste de { pts: Array[Vector3], w: largeur à la racine, col: Color }
func _ribbons(paths: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pa in paths:
		var pts: Array = pa.pts
		var n := pts.size()
		var left: Array = []
		var right: Array = []
		for k in n:
			var a: Vector3 = pts[maxi(k - 1, 0)]
			var b: Vector3 = pts[mini(k + 1, n - 1)]
			var tg := (b - a).normalized()
			var side := tg.cross(Vector3.BACK)
			if side.length() < 0.2:
				side = tg.cross(Vector3.RIGHT)
			side = side.normalized()
			var t := float(k) / float(n - 1)
			var w: float = float(pa.w) * 0.5 * (1.0 - t * 0.92)
			left.append((pts[k] as Vector3) - side * w)
			right.append((pts[k] as Vector3) + side * w)
		for k in n - 1:
			var t0 := float(k) / float(n - 1)
			var t1 := float(k + 1) / float(n - 1)
			var c0: Color = (pa.col as Color).darkened(0.25 * (1.0 - t0))   # racine plus sombre : ombre portée sur la peau
			var c1: Color = (pa.col as Color).darkened(0.25 * (1.0 - t1))
			for q in [[left[k], c0], [right[k], c0], [left[k + 1], c1], [right[k], c0], [right[k + 1], c1], [left[k + 1], c1]]:
				st.set_color((q[1] as Color).srgb_to_linear())
				st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()

func _hair_col(grey: float) -> Color:
	var g := _rng.randf_range(0.7, 0.9) * grey
	return Color(g, g * 0.985, g * 0.96)

# ------------------------------------------------------------------ tête sculptée

static func _g(p: Vector3, c: Vector3, s: Vector3) -> float:
	var d := (p - c) / s
	return exp(-d.dot(d) * 0.5)

func _head_mesh() -> ArrayMesh:
	const NA := 80
	const NT := 60
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := SKIN
	for j in NT + 1:
		var th := -PI * 0.5 + PI * float(j) / NT
		for i in NA + 1:
			var ph := -PI + TAU * float(i) / NA
			var d := Vector3(cos(th) * sin(ph), sin(th), cos(th) * cos(ph))
			var p := Vector3(d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z)
			# mâchoire plus étroite, crâne plus large en haut
			var jaw := smoothstep(-0.02, -0.2, p.y)
			p.x *= 1.0 - 0.3 * jaw
			p.z *= 1.0 - 0.1 * jaw * (1.0 if p.z < 0.0 else 0.0)
			var front := clampf(d.z, 0.0, 1.0)
			var disp := 0.0
			var col := base
			for sx in [-1.0, 1.0]:
				# orbites creusées, arcades, pommettes, creux des joues, ailes du nez
				var socket := _g(p, Vector3(sx * 0.072, 0.04, 0.17), Vector3(0.036, 0.03, 0.05))
				disp -= 0.026 * socket
				disp += 0.024 * _g(p, Vector3(sx * 0.07, 0.092, 0.175), Vector3(0.05, 0.016, 0.05))
				disp += 0.022 * _g(p, Vector3(sx * 0.1, -0.03, 0.14), Vector3(0.04, 0.035, 0.06))
				disp -= 0.013 * _g(p, Vector3(sx * 0.085, -0.1, 0.13), Vector3(0.04, 0.04, 0.06))
				disp += 0.017 * _g(p, Vector3(sx * 0.03, -0.062, 0.19), Vector3(0.015, 0.014, 0.02))
				disp -= 0.012 * _g(p, Vector3(sx * 0.056, -0.075, 0.18), Vector3(0.012, 0.028, 0.03))   # sillon naso-génien
				disp += 0.01 * _g(p, Vector3(sx * 0.14, 0.1, 0.06), Vector3(0.03, 0.04, 0.05))          # tempes
				col = col.lerp(Color(0.74, 0.52, 0.5), 0.2 * _g(p, Vector3(sx * 0.105, -0.035, 0.14), Vector3(0.045, 0.04, 0.06)))
				col = col.lerp(Color(0.6, 0.44, 0.42), 0.5 * _g(p, Vector3(sx * 0.072, 0.015, 0.18), Vector3(0.04, 0.02, 0.05)))
				col = col.lerp(Color(0.66, 0.5, 0.45), 0.3 * socket)
				col = col.lerp(Color(0.22, 0.1, 0.09), 0.9 * _g(p, Vector3(sx * 0.016, -0.074, 0.198), Vector3(0.008, 0.005, 0.012)))
				col = col.lerp(Color(0.7, 0.5, 0.45), 0.35 * _g(p, Vector3(sx * 0.056, -0.075, 0.18), Vector3(0.01, 0.03, 0.03)))
			# nez : arête, pointe, cloison
			disp += 0.034 * _g(p, Vector3(0, 0.03, 0.2), Vector3(0.016, 0.05, 0.03))
			disp += 0.042 * _g(p, Vector3(0, -0.052, 0.21), Vector3(0.022, 0.02, 0.03))
			disp += 0.012 * _g(p, Vector3(0, 0.1, 0.2), Vector3(0.03, 0.02, 0.03))                # glabelle
			col = col.lerp(Color(0.78, 0.55, 0.5), 0.2 * _g(p, Vector3(0, -0.052, 0.21), Vector3(0.024, 0.02, 0.03)))
			# bouche : lèvres, fente, menton
			disp += 0.011 * _g(p, Vector3(0, -0.098, 0.19), Vector3(0.034, 0.008, 0.04))
			disp += 0.012 * _g(p, Vector3(0, -0.122, 0.185), Vector3(0.03, 0.009, 0.04))
			disp -= 0.006 * _g(p, Vector3(0, -0.11, 0.19), Vector3(0.036, 0.003, 0.04))
			col = col.lerp(Color(0.7, 0.34, 0.33), 0.9 * _g(p, Vector3(0, -0.103, 0.19), Vector3(0.034, 0.016, 0.05)))
			col = col.lerp(Color(0.32, 0.14, 0.14), 0.8 * _g(p, Vector3(0, -0.111, 0.19), Vector3(0.03, 0.002, 0.05)))
			disp += 0.028 * _g(p, Vector3(0, -0.19, 0.15), Vector3(0.04, 0.035, 0.06))
			disp -= 0.01 * _g(p, Vector3(0, -0.15, 0.18), Vector3(0.04, 0.012, 0.04))
			# front : ridules fines
			col = col.darkened(0.1 * clampf(1.0 - absf(fposmod(p.y * 160.0, 1.0) - 0.5) * 8.0, 0.0, 1.0) * smoothstep(0.1, 0.125, p.y) * front)
			col = col.lightened(0.04 * smoothstep(0.08, 0.2, p.y))
			p += d * disp
			st.set_color(col.srgb_to_linear())
			st.set_uv(Vector2(float(i) / NA, float(j) / NT))
			st.add_vertex(p)
	for j in NT:
		for i in NA:
			var i0 := j * (NA + 1) + i
			var i1 := i0 + 1
			var i2 := i0 + NA + 1
			var i3 := i2 + 1
			for idx in [i0, i2, i1, i1, i2, i3]:
				st.add_index(idx)
	st.generate_normals()
	return st.commit()

# ------------------------------------------------------------------ construction

func _ready() -> void:
	_rng.seed = 424242
	var skin := _skin_mat(false, Color(0.82, 0.66, 0.57))
	var tunic := Merchant3D._mat(Color(0.42, 0.4, 0.2), 0.9)
	var cloak := Merchant3D._mat(Color(0.34, 0.2, 0.22), 0.9, 0.0, "cloth_red.webp", "cloth_red_n.webp", 0.9)
	var cloak_dark := Merchant3D._mat(Color(0.2, 0.12, 0.13), 0.95)
	var strap := Merchant3D._mat(Color(0.45, 0.26, 0.12), 0.7)
	var gold := Merchant3D._gold()
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.15, 0)
	add_child(_torso)
	# buste : tunique + cape + bretelles
	_add(Merchant3D.lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.0), Vector2(0.44, 0.35), Vector2(0.42, 0.62), Vector2(0.3, 0.82), Vector2(0.13, 0.9), Vector2(0.0, 0.92)], 26), tunic, Vector3.ZERO, _torso)
	var cape := Merchant3D.lathe([Vector2(0.0, 0.62), Vector2(0.6, 0.55), Vector2(0.58, 0.72), Vector2(0.48, 0.86), Vector2(0.28, 0.94), Vector2(0.0, 0.96)], 28)
	_add(cape, cloak, Vector3(0, 0.0, -0.03), _torso).scale = Vector3(1.12, 1.0, 0.78)
	_add(Merchant3D.lathe([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.54, 0.22), Vector2(0.4, 0.5), Vector2(0.26, 0.62)], 26), cloak_dark, Vector3(0, 0.45, -0.18), _torso).scale = Vector3(1.0, 1.0, 0.7)
	for sx in [-1.0, 1.0]:
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = Vector3(0.06, 0.72, 0.03)
		bm.mesh = bx
		bm.material_override = strap
		bm.position = Vector3(sx * 0.17, 0.46, 0.27)
		bm.rotation_degrees = Vector3(-8, 0, sx * 4)
		_torso.add_child(bm)
		_ball(0.032, gold, Vector3(sx * 0.17, 0.5, 0.31), _torso)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.05
		tm.outer_radius = 0.078
		ring.mesh = tm
		ring.material_override = gold
		ring.position = Vector3(sx * 0.13, 0.84, 0.2)
		ring.rotation_degrees = Vector3(90, 0, 0)
		_torso.add_child(ring)
	var brooch := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.1, 0.1, 0.03)
	brooch.mesh = bb
	brooch.material_override = gold
	brooch.position = Vector3(0, 0.6, 0.31)
	brooch.rotation_degrees.z = 45
	_torso.add_child(brooch)
	_ball(0.028, Merchant3D._mat(Color(0.2, 0.5, 0.35), 0.2, 0.2), Vector3(0, 0.6, 0.335), _torso)
	# cou + col de cape
	_tube(Vector3(0, 0.84, 0.02), Vector3(0, 1.1, 0.04), 0.085, 0.07, skin, _torso)
	var col_m := MeshInstance3D.new()
	var ct := TorusMesh.new()
	ct.inner_radius = 0.1
	ct.outer_radius = 0.17
	col_m.mesh = ct
	col_m.material_override = cloak
	col_m.position = Vector3(0, 0.9, 0.03)
	col_m.scale = Vector3(1.2, 1.0, 1.0)
	_torso.add_child(col_m)
	for sx in [-1.0, 1.0]:
		_build_arm(sx, tunic, cloak_dark, gold, skin)
	_build_head(skin)
	_build_hat()

# ------------------------------------------------------------------ bras et mains

func _build_arm(sx: float, sleeve: Material, cuff: Material, gold: Material, skin: Material) -> void:
	var sh := Vector3(sx * 0.4, 0.68, -0.01)
	var el := Vector3(sx * 0.56, 0.3, 0.17)
	var wr := Vector3(sx * 0.5, 0.07, 0.56)
	_ball(0.105, sleeve, sh, _torso)
	_tube(sh, el, 0.115, 0.098, sleeve, _torso, 20)
	_ball(0.099, sleeve, el, _torso)
	_tube(el, wr, 0.098, 0.082, sleeve, _torso, 20)
	# revers de manche
	var cuff_m := MeshInstance3D.new()
	var tmc := TorusMesh.new()
	tmc.inner_radius = 0.062
	tmc.outer_radius = 0.088
	cuff_m.mesh = tmc
	cuff_m.material_override = cuff
	cuff_m.position = wr
	cuff_m.basis = Basis(Quaternion(Vector3.UP, (wr - el).normalized()))
	_torso.add_child(cuff_m)
	var band := MeshInstance3D.new()
	var tmb := TorusMesh.new()
	tmb.inner_radius = 0.084
	tmb.outer_radius = 0.09
	band.mesh = tmb
	band.material_override = gold
	band.position = wr + (wr - el).normalized() * 0.02
	band.basis = cuff_m.basis
	_torso.add_child(band)
	# poignet
	_tube(wr + (wr - el).normalized() * 0.01, Vector3(sx * 0.5, 0.045, 0.66), 0.058, 0.052, skin, _torso)
	var hand := Node3D.new()
	hand.position = Vector3(sx * 0.5, 0.037, 0.66)
	hand.rotation_degrees.y = -sx * 7.0
	_torso.add_child(hand)
	hand.scale = Vector3.ONE * 1.22
	_build_hand(hand, sx, skin)

func _build_hand(h: Node3D, sx: float, skin: Material) -> void:
	var nail := Merchant3D._mat(Color(0.92, 0.78, 0.7), 0.35)
	var vein := _skin_mat(false, Color(0.82, 0.64, 0.56))
	# paume (dessus légèrement bombé) et talon de la main
	_ball(0.05, skin, Vector3(0, 0.002, 0.04), h, Vector3(1.0, 0.42, 1.15))
	_ball(0.04, vein, Vector3(-sx * 0.012, 0.012, 0.0), h, Vector3(1.1, 0.5, 0.9))
	# métacarpiens (dos de la main)
	var xs := [-0.036, -0.012, 0.012, 0.036]
	var lens := [0.074, 0.083, 0.077, 0.06]
	var curl := [20.0, 24.0, 28.0, 32.0]
	for f in 4:
		var fx: float = xs[f] * sx
		var base := Vector3(fx, 0.004, 0.085)
		var rad := 0.0118 - 0.0012 * f * 0.5
		var spread: float = (float(f) - 1.5) * 4.0 * sx
		var dir0 := Vector3(sin(deg_to_rad(spread)), 0.0, cos(deg_to_rad(spread)))
		_ball(rad * 1.15, skin, base, h)
		var p := base
		var seg_len: Array = [lens[f] * 0.46, lens[f] * 0.3, lens[f] * 0.24]
		var pitch := 0.0
		for s in 3:
			pitch += deg_to_rad(float(curl[f]) * (0.5 + 0.35 * s) * 0.55)
			var d := Vector3(dir0.x * cos(pitch), -sin(pitch), dir0.z * cos(pitch)).normalized()
			var np: Vector3 = p + d * float(seg_len[s])
			var r0 := rad * (1.0 - 0.1 * s)
			var r1 := rad * (1.0 - 0.1 * (s + 1)) * 0.96
			_tube(p, np, r0, r1, skin, h, 12)
			_ball(r1 * 1.06, skin, np, h)
			p = np
		# ongle
		var nd := Vector3(dir0.x * cos(pitch), -sin(pitch), dir0.z * cos(pitch)).normalized()
		var nm := _ball(rad * 0.82, nail, p - nd * 0.011 + Vector3(0, rad * 0.55, 0), h, Vector3(0.95, 0.3, 1.25))
		nm.look_at_from_position(nm.position, nm.position + nd, Vector3.UP)
		nm.scale = Vector3(0.95, 0.3, 1.25)
	# pouce : deux phalanges + métacarpien, écarté vers l'intérieur
	var tb := Vector3(-sx * 0.036, 0.0, 0.03)
	var td := Vector3(-sx * 0.55, -0.12, 0.83).normalized()
	var t1 := tb + td * 0.04
	var t2 := t1 + Vector3(-sx * 0.42, -0.2, 0.88).normalized() * 0.037
	var t3 := t2 + Vector3(-sx * 0.3, -0.3, 0.9).normalized() * 0.033
	_tube(tb, t1, 0.0165, 0.0145, skin, h, 12)
	_ball(0.0148, skin, t1, h)
	_tube(t1, t2, 0.0142, 0.0128, skin, h, 12)
	_ball(0.0132, skin, t2, h)
	_tube(t2, t3, 0.0126, 0.0112, skin, h, 12)
	_ball(0.0115, skin, t3, h)
	_ball(0.0105, nail, t3 + Vector3(0, 0.007, 0.004), h, Vector3(0.95, 0.3, 1.2))

# ------------------------------------------------------------------ tête

func _build_head(skin: Material) -> void:
	var skin_vc := _skin_mat(true)
	var white := Merchant3D._mat(Color(0.96, 0.96, 0.94), 0.25)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.26, 0.04)
	_torso.add_child(_head)
	_add(_head_mesh(), skin_vc, Vector3.ZERO, _head)
	# oreilles : conque + creux
	for sx in [-1.0, 1.0]:
		var ear := _ball(0.036, skin, Vector3(sx * 0.168, -0.012, -0.008), _head, Vector3(0.38, 1.25, 0.85))
		ear.rotation_degrees = Vector3(0, 0, sx * -8)
		_ball(0.022, _skin_mat(false, Color(0.75, 0.52, 0.46)), Vector3(sx * 0.163, -0.014, -0.002), _head, Vector3(0.3, 1.0, 0.7))
		var lobe := _ball(0.011, skin, Vector3(sx * 0.17, -0.062, -0.004), _head, Vector3(0.6, 1.2, 0.8))
		lobe.rotation_degrees.z = sx * -8
	# yeux
	var iris := Merchant3D._mat(Color(0.32, 0.5, 0.62), 0.25)
	var lid_m := _skin_mat(false, Color(0.86, 0.66, 0.55))
	for sx in [-1.0, 1.0]:
		var ec := Vector3(sx * 0.072, 0.041, 0.146)
		var eye := Node3D.new()
		eye.position = ec
		_head.add_child(eye)
		_ball(0.0275, white, Vector3.ZERO, eye)
		_ball(0.0155, iris, Vector3(0, 0, 0.0228), eye, Vector3(1, 1, 0.4))
		_ball(0.0085, Merchant3D._mat(Color(0.03, 0.03, 0.04), 0.2), Vector3(0, 0, 0.0265), eye, Vector3(1, 1, 0.4))
		var glint := _ball(0.0045, _unshaded(Color(1, 1, 1)), Vector3(sx * 0.0065, 0.0075, 0.0295), eye)
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyes.append(eye)
		# paupières : calottes sphériques, montée / descente pour cligner
		var up := Node3D.new()
		up.position = ec
		_head.add_child(up)
		up.rotation_degrees.x = 0.0
		_add(_cap(0.0295, 88.0), lid_m, Vector3.ZERO, up)
		var dn := Node3D.new()
		dn.position = ec
		_head.add_child(dn)
		_add(_cap(0.0293, 72.0), lid_m, Vector3.ZERO, dn).rotation_degrees.x = 180.0
		_lids_up.append(up)
		_lids_dn.append(dn)
		# sourcils fournis
		var paths: Array = []
		for k in 52:
			var t := _rng.randf()
			var root := Vector3(sx * lerpf(0.03, 0.118, t), 0.098 + 0.014 * sin(t * PI) - 0.012 * t * t + _rng.randf_range(-0.008, 0.008), 0.188 - 0.045 * t * t + 0.006)
			var tipd := Vector3(sx * 0.024, 0.016 - 0.03 * t * 0.5, 0.004)
			var seg := PackedVector3Array()
			var pts: Array = []
			for q in 4:
				var u := float(q) / 3.0
				pts.append(root + tipd * u * _rng.randf_range(0.9, 1.7) + Vector3(0, 0.006 * sin(u * PI) * _rng.randf_range(0.5, 1.4), 0.006 * u))
			paths.append({"pts": pts, "w": 0.013, "col": _hair_col(1.0)})
		_add(_ribbons(paths), _hair_mat(), Vector3.ZERO, _head).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# moustache + barbe + cheveux
	_add(_ribbons(_mustache_paths()), _hair_mat(), Vector3.ZERO, _head)
	_add(_ribbons(_beard_paths()), _hair_mat(), Vector3.ZERO, _head)
	_add(_ribbons(_side_hair_paths()), _hair_mat(), Vector3.ZERO, _head)
	# sous-couche de barbe (volume plein sous les mèches)
	_add(Merchant3D.lathe([Vector2(0.0, -0.4), Vector2(0.05, -0.34), Vector2(0.11, -0.2), Vector2(0.15, -0.07), Vector2(0.15, 0.0), Vector2(0.0, 0.0)], 24, func(v: Vector3) -> Vector3:
		return Vector3(v.x * 1.05, v.y, v.z * 0.78)), Merchant3D._mat(Color(0.86, 0.86, 0.84), 0.8), Vector3(0, -0.08, 0.1), _head)

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## Calotte de sphère de demi-angle `deg` autour de +Y.
func _cap(r: float, deg: float) -> ArrayMesh:
	var prof: Array = []
	var n := 10
	for k in n + 1:
		var a := deg_to_rad(deg) * (1.0 - float(k) / n)
		prof.append(Vector2(r * sin(a), r * cos(a)))
	return Merchant3D.lathe(prof, 22)

func _mustache_paths() -> Array:
	var paths: Array = []
	for sx in [-1.0, 1.0]:
		for k in 46:
			var t := _rng.randf()
			var root := Vector3(sx * _rng.randf_range(0.004, 0.034), -0.078 - 0.014 * _rng.randf(), 0.205 - 0.006 * _rng.randf())
			var len := _rng.randf_range(0.1, 0.17) * (0.7 + 0.5 * t)
			var pts: Array = []
			for q in 6:
				var u := float(q) / 5.0
				var x: float = root.x + sx * len * 0.8 * u
				var y := root.y - 0.05 * sin(u * PI * 0.8) * (0.4 + t) + 0.03 * u * u - 0.012 * u
				var z := root.z - 0.05 * u * u + 0.02 * u * (1.0 - u)
				pts.append(Vector3(x, y, z) + Vector3(0, 0, 0.004 * sin(u * 9.0 + t * 7.0)))
			paths.append({"pts": pts, "w": 0.016, "col": _hair_col(0.95)})
	return paths

func _beard_paths() -> Array:
	var paths: Array = []
	for k in 520:
		var ph := _rng.randf_range(-1.38, 1.38)
		var cen := 1.0 - absf(ph) / 1.45
		var th := _rng.randf_range(-0.78, -0.08)
		var d := Vector3(cos(th) * sin(ph), sin(th), cos(th) * cos(ph))
		var root := Vector3(d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z) * 1.015
		root.x *= 1.0 - 0.3 * smoothstep(-0.02, -0.2, root.y)
		# on laisse la fente de la bouche dégagée
		if absf(root.x) < 0.04 and root.y > -0.125 and root.y < -0.085 and root.z > 0.15:
			continue
		var length := (0.16 + 0.3 * cen * cen + 0.08 * _rng.randf()) * (0.55 + 0.9 * clampf((-root.y - 0.02) / 0.2, 0.0, 1.0))
		var wav := _rng.randf_range(0.0, TAU)
		var pts: Array = []
		var n := 6
		for q in n:
			var u := float(q) / float(n - 1)
			var x := root.x * (1.0 - 0.45 * u) + 0.018 * sin(wav + u * 5.0) * u
			var y := root.y - length * u
			var z := root.z + (0.06 + 0.1 * cen) * sin(u * PI * 0.5) + 0.08 * u * cen - 0.01 * u
			pts.append(Vector3(x, y, z))
		paths.append({"pts": pts, "w": 0.02, "col": _hair_col(0.97)})
	return paths

func _side_hair_paths() -> Array:
	var paths: Array = []
	for sx in [-1.0, 1.0]:
		for k in 70:
			var ph: float = sx * _rng.randf_range(1.75, 2.4)
			var th := _rng.randf_range(0.0, 0.55)
			var d := Vector3(cos(th) * sin(ph), sin(th), cos(th) * cos(ph))
			var root := Vector3(d.x * HEAD_R.x, d.y * HEAD_R.y, d.z * HEAD_R.z) * 1.0
			var length := _rng.randf_range(0.3, 0.52)
			var wav := _rng.randf_range(0.0, TAU)
			var pts: Array = []
			for q in 6:
				var u := float(q) / 5.0
				pts.append(Vector3(root.x + sx * (0.03 + 0.05 * u) + 0.012 * sin(wav + u * 4.0), root.y - length * u, root.z - 0.01 + 0.03 * u))
			paths.append({"pts": pts, "w": 0.02, "col": _hair_col(0.9)})
	return paths

# ------------------------------------------------------------------ chapeau

func _build_hat() -> void:
	var strap := Merchant3D._mat(Color(0.45, 0.26, 0.12), 0.7)
	var gold := Merchant3D._gold()
	var brim_prof := [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.42, -0.015), Vector2(0.62, -0.06), Vector2(0.66, -0.1), Vector2(0.64, -0.1), Vector2(0.42, -0.04), Vector2(0.0, 0.03)]
	var hat_m := Merchant3D._mat(Color(0.34, 0.22, 0.14), 0.75, 0.0, "wood_dark.webp", "wood_dark_n.webp", 0.7)
	var hat := Node3D.new()
	hat.position = Vector3(0, 0.125, -0.01)
	hat.rotation_degrees = Vector3(-9, 0, 0)
	_head.add_child(hat)
	_add(Merchant3D.lathe(brim_prof, 36), hat_m, Vector3.ZERO, hat)
	var crown := Merchant3D.lathe([Vector2(0.24, 0.0), Vector2(0.23, 0.12), Vector2(0.2, 0.3), Vector2(0.15, 0.48), Vector2(0.09, 0.62), Vector2(0.04, 0.72), Vector2(0.0, 0.76)], 28, func(v: Vector3) -> Vector3:
		var t := clampf(v.y / 0.76, 0.0, 1.0)
		return Vector3(v.x, v.y, v.z - 0.34 * t * t))
	_add(crown, hat_m, Vector3.ZERO, hat)
	var band := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.215
	tm.outer_radius = 0.268
	band.mesh = tm
	band.material_override = strap
	band.position = Vector3(0, 0.04, 0.0)
	hat.add_child(band)
	var buckle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.03)
	buckle.mesh = bm
	buckle.material_override = gold
	buckle.position = Vector3(0, 0.05, 0.27)
	hat.add_child(buckle)
	var tongue := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(0.05, 0.06, 0.035)
	tongue.mesh = bm2
	tongue.material_override = strap
	tongue.position = Vector3(0, 0.05, 0.275)
	hat.add_child(tongue)

# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	_t += delta
	_torso.scale = Vector3(1.0, 1.0 + 0.008 * sin(_t * 1.6), 1.0)
	_head.rotation.y = 0.12 * sin(_t * 0.45)
	_head.rotation.x = 0.03 * sin(_t * 0.8)
	# clignement
	if _blink < 0.0 and _t > _next_blink:
		_blink = 0.0
	var k := 0.0
	if _blink >= 0.0:
		_blink += delta
		k = sin(clampf(_blink / 0.18, 0.0, 1.0) * PI)
		if _blink > 0.18:
			_blink = -1.0
			_next_blink = _t + _rng.randf_range(2.5, 5.5)
	for u in _lids_up:
		(u as Node3D).rotation.x = deg_to_rad(36.0 * k)
	for d in _lids_dn:
		(d as Node3D).rotation.x = deg_to_rad(-24.0 * k)
