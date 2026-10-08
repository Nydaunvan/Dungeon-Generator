class_name Merchant3D
extends Node3D
## Étal du marchand ambulant en vrai 3D (PROPOSITION, pas encore branchée dans le jeu) : ossature de bois, comptoir, auvent de tissu
## déchiré, bannières, étagères (livres, parchemins, coffre), fioles de verre, pièces, sacs, caisses, tonneau, lanterne qui éclaire,
## et le marchand lui-même (chapeau de mage, barbe, cape). Tout est généré par le code ; seules les textures de tissu, de bois et
## l'emblème de fiole viennent de assets/misc/merchant3d (tools/gen_merchant_textures.py).
##
## Repère : sol en y = 0, face à +Z (côté couloir), l'étal fait ~5,8 u de large, ~3,9 de haut, ~1,9 de profondeur.

const TEX := "res://assets/misc/merchant3d/"
const WOOD_LIGHT := Color(0.86, 0.68, 0.5)
const WOOD_DARK := Color(0.62, 0.5, 0.42)

static var _cache: Dictionary = {}
var _t := 0.0
var _lantern_light: OmniLight3D
var _flame: MeshInstance3D
var _sway: Array = []        # [node, phase, amplitude, axe]
var _torso: Node3D
var _head: Node3D

# ------------------------------------------------------------------ matériaux

static func _tex(name: String) -> Texture2D:
	var path := TEX + name
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = t
	return t

static func _mat(color: Color, rough: float = 0.8, metal: float = 0.0, tex: String = "", normal: String = "", tri: float = 0.0) -> StandardMaterial3D:
	var key := "m|%s|%s|%s|%s|%s|%s|%s" % [color.to_html(), rough, metal, tex, normal, tri, 0]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	if tex != "":
		m.albedo_texture = _tex(tex)
	if normal != "" and _tex(normal) != null:
		m.normal_enabled = true
		m.normal_texture = _tex(normal)
		m.normal_scale = 0.8
	if tri > 0.0:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * tri
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m

static func _wood(dark: bool = false) -> StandardMaterial3D:
	return _mat(WOOD_DARK if dark else WOOD_LIGHT, 0.85, 0.0, "wood_dark.webp" if dark else "wood.webp", "wood_dark_n.webp" if dark else "wood_n.webp", 0.55)

static func _iron() -> StandardMaterial3D:
	return _mat(Color(0.55, 0.56, 0.6), 0.55, 0.85, "metal.webp", "metal_n.webp", 0.8)

static func _gold() -> StandardMaterial3D:
	return _mat(Color(1.0, 0.78, 0.32), 0.3, 1.0)

static func _cloth_mat(tex: String, normal: String = "") -> StandardMaterial3D:
	var m := _mat(Color(1, 1, 1), 0.95, 0.0, tex, normal).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ------------------------------------------------------------------ primitives

func _add(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	(parent if parent != null else self).add_child(mi)
	return mi

func _box(size: Vector3, mat: Material, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(b, mat, pos, parent, rot)

func _cyl(r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO, seg: int = 20) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _add(c, mat, pos, parent, rot)

func _sphere(r: float, mat: Material, pos: Vector3, parent: Node3D = null, scale_: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	var mi := _add(s, mat, pos, parent)
	mi.scale = scale_
	return mi

func _torus(inner: float, outer: float, mat: Material, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 10
	return _add(t, mat, pos, parent, rot)

## Solide de révolution : profil = points (rayon, hauteur) du bas vers le haut ; `warp` déforme les sommets (chapeau tordu, sac…).
static func lathe(profile: Array, segs: int = 28, warp: Callable = Callable()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := profile.size()
	var verts: Array = []
	var norms: Array = []
	for j in rows:
		var p: Vector2 = profile[j]
		var a: Vector2 = profile[maxi(j - 1, 0)]
		var b: Vector2 = profile[mini(j + 1, rows - 1)]
		var tg := (b - a).normalized()
		var n2 := Vector2(tg.y, -tg.x)
		for k in segs + 1:
			var ang := TAU * float(k) / float(segs)
			var c := cos(ang)
			var s := sin(ang)
			var v := Vector3(p.x * c, p.y, p.x * s)
			if warp.is_valid():
				v = warp.call(v)
			verts.append(v)
			norms.append(Vector3(n2.x * c, n2.y, n2.x * s).normalized())
	for j in rows - 1:
		for k in segs:
			var i0 := j * (segs + 1) + k
			var i1 := i0 + 1
			var i2 := i0 + segs + 1
			var i3 := i2 + 1
			for idx in [i0, i2, i1, i1, i2, i3]:
				var u := float(idx % (segs + 1)) / float(segs)
				var vv := float(idx / (segs + 1)) / float(rows - 1)
				st.set_normal(norms[idx])
				st.set_uv(Vector2(u, 1.0 - vv))
				st.add_vertex(verts[idx])
	return st.commit()

## Nappe de tissu : (u, v) ∈ [0,1]² → position ; UV = (u, v), deux faces (le matériau désactive le culling).
static func cloth_mesh(nu: int, nv: int, fn: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for j in nv + 1:
		var row: Array = []
		for i in nu + 1:
			row.append(fn.call(float(i) / nu, float(j) / nv))
		grid.append(row)
	for j in nv:
		for i in nu:
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for q in quad:
				st.set_uv(Vector2(float(q.x) / nu, float(q.y) / nv))
				st.add_vertex(grid[q.y][q.x])
	st.generate_normals()
	return st.commit()

# ------------------------------------------------------------------ construction

func _ready() -> void:
	name = "Merchant3D"
	_build_frame()
	_build_back()
	_build_counter()
	_build_canopy()
	_build_banners()
	_build_goods()
	_build_sides()
	_build_lantern()
	_build_merchant()

func _build_frame() -> void:
	var wd := _wood(true)
	var wl := _wood(false)
	var iron := _iron()
	# montants : avant (grands) et arrière
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.3, 3.85, 0.3), wd, Vector3(sx * 2.62, 1.92, 0.78))
		_box(Vector3(0.26, 3.5, 0.26), wd, Vector3(sx * 2.55, 1.75, -0.78))
		# roues décoratives en haut des montants
		var wheel := _cyl(0.3, 0.3, 0.07, wl, Vector3(sx * 2.62, 3.78, 0.98), null, Vector3(90, 0, 0), 24)
		_torus(0.26, 0.33, wl, Vector3(sx * 2.62, 3.78, 1.02), null, Vector3(90, 0, 0))
		for a in 4:
			_box(Vector3(0.05, 0.56, 0.04), wl, Vector3(sx * 2.62, 3.78, 1.03), null, Vector3(0, 0, a * 45.0))
		_cyl(0.07, 0.07, 0.12, _gold(), Vector3(sx * 2.62, 3.78, 1.06), null, Vector3(90, 0, 0), 12)
		# ferrures et cordages sur les montants
		for y in [2.3, 0.7]:
			_box(Vector3(0.34, 0.2, 0.34), iron, Vector3(sx * 2.62, y, 0.78))
		for y in [3.0, 2.85, 2.72]:
			_torus(0.15, 0.2, _mat(Color(0.7, 0.55, 0.32), 0.95), Vector3(sx * 2.62, y, 0.78), null, Vector3(0, 0, 0))
		# poutres latérales qui dépassent
		_box(Vector3(1.0, 0.2, 0.2), wd, Vector3(sx * 3.15, 3.35, 0.78))
		_box(Vector3(0.18, 0.18, 1.6), wd, Vector3(sx * 2.62, 3.35, 0.0))
	# poutres de faîtage
	_box(Vector3(5.6, 0.24, 0.24), wd, Vector3(0, 3.4, 0.78))
	_box(Vector3(5.2, 0.22, 0.22), wd, Vector3(0, 3.62, -0.78))
	# jambes de force du toit
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.14, 1.15, 0.14), wd, Vector3(sx * 2.0, 2.95, 0.6), null, Vector3(-18, 0, sx * 38.0))

func _build_back() -> void:
	var wd := _wood(true)
	var wl := _wood(false)
	# cloison du fond : planches verticales
	for i in 14:
		var x := -2.45 + i * 0.378
		_box(Vector3(0.36, 3.1, 0.06), wd, Vector3(x, 1.65, -0.95))
	_box(Vector3(5.2, 0.14, 0.1), wl, Vector3(0, 1.0, -0.88))
	_box(Vector3(5.2, 0.14, 0.1), wl, Vector3(0, 3.0, -0.88))
	# étagères à gauche
	for y in [1.85, 2.55]:
		_box(Vector3(2.0, 0.08, 0.55), wl, Vector3(-1.45, y, -0.62))
		for bx in [-2.3, -0.62]:
			_box(Vector3(0.07, 0.22, 0.5), wl, Vector3(bx, y - 0.14, -0.62), null, Vector3(0, 0, 0))
	# coffre
	var chest := _box(Vector3(0.62, 0.34, 0.38), _wood(true), Vector3(-1.95, 2.76, -0.62))
	_box(Vector3(0.66, 0.06, 0.42), _iron(), Vector3(-1.95, 2.93, -0.62))
	for dx in [-0.2, 0.2]:
		_box(Vector3(0.06, 0.4, 0.42), _iron(), Vector3(-1.95 + dx, 2.76, -0.62))
	_box(Vector3(0.1, 0.12, 0.05), _gold(), Vector3(-1.95, 2.8, -0.4))
	# livres
	var cols := [Color(0.35, 0.1, 0.12), Color(0.12, 0.2, 0.3), Color(0.4, 0.18, 0.1), Color(0.2, 0.25, 0.14), Color(0.45, 0.12, 0.15), Color(0.16, 0.14, 0.28)]
	var bx := -1.4
	for i in 7:
		var h := 0.42 + 0.1 * float((i * 5) % 3)
		var w := 0.09 + 0.03 * float(i % 2)
		var lean := 0.0 if i < 6 else 14.0
		_box(Vector3(w, h, 0.3), _mat(cols[i % cols.size()], 0.7), Vector3(bx, 2.59 + h * 0.5, -0.62), null, Vector3(0, 0, lean))
		_box(Vector3(w + 0.005, 0.03, 0.31), _gold(), Vector3(bx, 2.59 + h * 0.8, -0.62), null, Vector3(0, 0, lean))
		bx += w + 0.025
	# parchemins roulés
	var parch := _mat(Color(0.88, 0.78, 0.58), 0.9)
	for i in 4:
		_cyl(0.07, 0.07, 0.55, parch, Vector3(-1.9 + i * 0.0, 1.97 + i * 0.0, -0.62 + 0.0), null, Vector3(0, 0, 90), 14).position = Vector3(-1.62 - (i % 2) * 0.05, 1.93 + (i / 2) * 0.15, -0.55 + (i % 2) * 0.12)
	for i in 2:
		_cyl(0.075, 0.075, 0.1, _mat(Color(0.6, 0.12, 0.1), 0.8), Vector3(-1.5 + i * 0.1, 1.93 + 0.0, -0.4), null, Vector3(0, 0, 90), 12)
	# bocaux sombres
	var glass := _mat(Color(0.25, 0.4, 0.3, 0.7), 0.15, 0.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 3:
		_cyl(0.1, 0.12, 0.3, glass, Vector3(-0.95 + i * 0.22, 2.0, -0.7), null, Vector3.ZERO, 14)
		_cyl(0.07, 0.07, 0.05, _wood(true), Vector3(-0.95 + i * 0.22, 2.18, -0.7), null, Vector3.ZERO, 12)

func _build_counter() -> void:
	var wl := _wood(false)
	var wd := _wood(true)
	_box(Vector3(4.9, 0.13, 1.0), wl, Vector3(0, 1.1, 0.4))                 # plateau
	_box(Vector3(4.9, 0.1, 0.12), wd, Vector3(0, 1.03, 0.9))               # rebord avant
	_box(Vector3(4.6, 0.95, 0.07), wd, Vector3(0, 0.55, 0.78))              # tablier de planches
	for i in 11:
		_box(Vector3(0.015, 0.95, 0.075), _mat(Color(0.2, 0.14, 0.1), 1.0), Vector3(-2.2 + i * 0.44, 0.55, 0.78))
	_box(Vector3(4.6, 0.13, 0.12), wl, Vector3(0, 0.08, 0.84))              # traverse basse
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.22, 1.1, 0.22), wl, Vector3(sx * 1.32, 0.55, 0.86))  # pieds avant
		_box(Vector3(0.1, 0.9, 0.1), wl, Vector3(sx * 1.55, 0.6, 0.86), null, Vector3(0, 0, sx * 38.0))   # croix de Saint-André
	# tissu tombant sur le devant, emblème de fiole
	var front := cloth_mesh(18, 10, func(u: float, v: float) -> Vector3:
		var x := (u - 0.5) * 2.5
		var y := 1.1 - v * 1.0
		var z := 0.93 + 0.05 * sin(u * 9.0 + v * 2.0) * (0.3 + v * 0.7) + 0.03 * v
		return Vector3(x, y, z))
	_add(front, _cloth_mat("front_cloth.webp", ""), Vector3.ZERO)
	# tringle du tissu
	_box(Vector3(2.6, 0.05, 0.08), wl, Vector3(0, 1.11, 0.93))

func _build_canopy() -> void:
	var specs := [["canopy_red.webp", -2.9, -1.0], ["canopy_tan.webp", -1.0, 1.05], ["canopy_red.webp", 1.05, 2.95]]
	for sp in specs:
		var xa: float = sp[1]
		var xb: float = sp[2]
		var mesh := cloth_mesh(20, 10, func(u: float, v: float) -> Vector3:
			var x := lerpf(xa, xb, u)
			var back := Vector3(x, 3.68, -0.9)
			var front := Vector3(x * 1.03, 3.0, 1.18)
			var p := back.lerp(front, v)
			p.y += 0.16 * sin(u * PI) * sin(v * PI) - 0.1 * v * v
			p.y += 0.04 * sin(u * 11.0 + v * 4.0)
			p.z += 0.03 * sin(u * 7.0)
			return p)
		var mi := _add(mesh, _cloth_mat(sp[0], "cloth_red_n.webp" if sp[0] == "canopy_red.webp" else "cloth_tan_n.webp"), Vector3.ZERO)
		_sway.append([mi, randf() * TAU, 0.012, "x"])
	# coutures dorées entre les pans
	for x in [-1.0, 1.05]:
		for i in 4:
			var v := 0.15 + i * 0.17
			var p := Vector3(x, lerpf(3.68, 3.0, v) + 0.13 * sin(v * PI) - 0.1 * v * v, lerpf(-0.9, 1.18, v))
			_box(Vector3(0.14, 0.012, 0.012), _mat(Color(0.9, 0.7, 0.3), 0.5), p + Vector3(0, 0.03, 0), null, Vector3(0, 0, 8.0 * (i % 2 * 2 - 1)))

func _build_banners() -> void:
	for sx in [-1.0, 1.0]:
		var mesh := cloth_mesh(8, 14, func(u: float, v: float) -> Vector3:
			return Vector3((u - 0.5) * 0.95, -v * 2.15, 0.06 * sin(v * 5.0 + u * 2.0) * v))
		var holder := Node3D.new()
		holder.position = Vector3(sx * 3.2, 3.22, 0.95)
		add_child(holder)
		_add(mesh, _cloth_mat("banner_cloth.webp", "cloth_red_n.webp"), Vector3.ZERO, holder)
		_box(Vector3(1.05, 0.06, 0.06), _wood(false), Vector3(0, 0.0, 0.0), holder)
		_cyl(0.045, 0.045, 0.12, _gold(), Vector3(-0.52, 0, 0), holder, Vector3(0, 0, 90), 10)
		_cyl(0.045, 0.045, 0.12, _gold(), Vector3(0.52, 0, 0), holder, Vector3(0, 0, 90), 10)
		for k in [-0.35, 0.35]:
			_torus(0.02, 0.05, _gold(), Vector3(k, 0.02, 0.0), holder, Vector3(90, 0, 0))
		_sway.append([holder, randf() * TAU, 0.05, "z"])

func _glass_mat(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _liquid_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.55
	return m

func _bottle(pos: Vector3, scale_: float, liquid: Color, shape: int = 0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.scale = Vector3.ONE * scale_
	add_child(holder)
	var prof: Array
	var liq: Array
	if shape == 0:      # fiole ronde à long col
		prof = [Vector2(0.0, 0.0), Vector2(0.14, 0.012), Vector2(0.2, 0.07), Vector2(0.22, 0.17), Vector2(0.2, 0.27), Vector2(0.13, 0.36), Vector2(0.07, 0.43), Vector2(0.065, 0.6), Vector2(0.085, 0.63), Vector2(0.085, 0.66)]
		liq = [Vector2(0.0, 0.015), Vector2(0.13, 0.02), Vector2(0.185, 0.075), Vector2(0.205, 0.17), Vector2(0.185, 0.25), Vector2(0.0, 0.265)]
	else:               # fiole conique
		prof = [Vector2(0.0, 0.0), Vector2(0.17, 0.01), Vector2(0.22, 0.05), Vector2(0.14, 0.3), Vector2(0.065, 0.42), Vector2(0.06, 0.58), Vector2(0.08, 0.6), Vector2(0.08, 0.63)]
		liq = [Vector2(0.0, 0.012), Vector2(0.16, 0.02), Vector2(0.205, 0.055), Vector2(0.17, 0.2), Vector2(0.0, 0.2)]
	_add(lathe(prof, 20), _glass_mat(Color(0.85, 0.92, 1.0)), Vector3.ZERO, holder)
	_add(lathe(liq, 20), _liquid_mat(liquid), Vector3.ZERO, holder)
	_cyl(0.058, 0.07, 0.1, _mat(Color(0.55, 0.38, 0.2), 0.9), Vector3(0, 0.69, 0), holder, Vector3.ZERO, 12)

func _coin_stack(pos: Vector3, n: int) -> void:
	for i in n:
		_cyl(0.07, 0.07, 0.016, _gold(), pos + Vector3(0.003 * (i % 2), 0.008 + i * 0.017, 0.003 * (i % 3)), null, Vector3(0, i * 23.0, 0), 16)

func _sack(pos: Vector3, size: float, tint: Color = Color(1, 1, 1), yaw: float = 0.0, open_coins: bool = false) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation_degrees.y = yaw
	add_child(h)
	var m := _mat(tint, 1.0, 0.0, "burlap.webp", "burlap_n.webp", 1.4)
	var prof := [Vector2(0.0, 0.0), Vector2(0.3, 0.015), Vector2(0.42, 0.2), Vector2(0.43, 0.42), Vector2(0.33, 0.66), Vector2(0.17, 0.82), Vector2(0.1, 0.9), Vector2(0.14, 0.98), Vector2(0.2, 1.1), Vector2(0.12, 1.14)]
	var bulge := func(v: Vector3) -> Vector3:
		return Vector3(v.x * (1.0 + 0.08 * sin(v.y * 11.0 + v.z * 8.0)), v.y, v.z * (1.0 + 0.08 * cos(v.y * 9.0 + v.x * 7.0)))
	_add(lathe(prof, 22, bulge), m, Vector3.ZERO, h).scale = Vector3.ONE * size
	_torus(0.05 * size, 0.12 * size, _mat(Color(0.35, 0.24, 0.12), 1.0), Vector3(0, 0.92 * size, 0), h, Vector3(0, 0, 0))
	if open_coins:
		_coin_stack(Vector3(0, 1.02 * size, 0), 4)

func _crate(pos: Vector3, size: Vector3) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	add_child(h)
	var wd := _wood(true)
	var wl := _wood(false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.1, size.y, 0.1), wl, Vector3(sx * (size.x * 0.5 - 0.05), size.y * 0.5, sz * (size.z * 0.5 - 0.05)), h)
	var n := 4
	for i in n:
		var y := 0.1 + (size.y - 0.2) * float(i) / float(n - 1)
		_box(Vector3(size.x, 0.12, 0.05), wd, Vector3(0, y, size.z * 0.5), h)
		_box(Vector3(size.x, 0.12, 0.05), wd, Vector3(0, y, -size.z * 0.5), h)
		_box(Vector3(0.05, 0.12, size.z), wd, Vector3(size.x * 0.5, y, 0), h)
		_box(Vector3(0.05, 0.12, size.z), wd, Vector3(-size.x * 0.5, y, 0), h)
	_box(Vector3(size.x * 1.25, 0.05, 0.04), wl, Vector3(0, size.y * 0.5, size.z * 0.5 + 0.03), h, Vector3(0, 0, 38))
	_box(Vector3(size.x * 1.25, 0.05, 0.04), wl, Vector3(0, size.y * 0.5, size.z * 0.5 + 0.03), h, Vector3(0, 0, -38))
	_box(Vector3(size.x - 0.1, 0.05, size.z - 0.1), wd, Vector3(0, 0.12, 0), h)
	return h

func _sword(parent: Node3D, pos: Vector3, rot: Vector3, length: float = 0.95) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation_degrees = rot
	parent.add_child(h)
	var blade := _mat(Color(0.78, 0.8, 0.84), 0.28, 1.0)
	_box(Vector3(0.06, length, 0.014), blade, Vector3(0, length * 0.5, 0), h)
	_box(Vector3(0.01, length * 0.95, 0.018), _mat(Color(0.45, 0.47, 0.5), 0.4, 1.0), Vector3(0, length * 0.5, 0), h)
	_box(Vector3(0.34, 0.05, 0.06), _mat(Color(0.5, 0.36, 0.2), 0.5, 0.8), Vector3(0, -0.02, 0), h)
	_cyl(0.026, 0.026, 0.22, _mat(Color(0.28, 0.16, 0.1), 0.9), Vector3(0, -0.14, 0), h, Vector3.ZERO, 10)
	_sphere(0.04, _gold(), Vector3(0, -0.27, 0), h)

func _build_goods() -> void:
	# fioles sur un plateau, à gauche du comptoir
	_box(Vector3(1.25, 0.14, 0.5), _wood(false), Vector3(-1.7, 1.24, 0.38))
	for e in [[Vector3(-2.15, 1.31, 0.4), 0.95, Color(0.85, 0.1, 0.1), 0], [Vector3(-1.85, 1.31, 0.33), 0.62, Color(0.8, 0.12, 0.1), 0], [Vector3(-1.58, 1.31, 0.42), 1.05, Color(0.15, 0.4, 0.95), 1],
			[Vector3(-1.3, 1.31, 0.35), 0.62, Color(0.15, 0.45, 0.9), 0], [Vector3(-1.12, 1.31, 0.43), 0.5, Color(0.85, 0.15, 0.12), 0]]:
		_bottle(e[0], e[1], e[2], e[3])
	# pièces, sac de pièces et plume à droite
	_coin_stack(Vector3(-0.75, 1.165, 0.6), 4)
	_coin_stack(Vector3(-0.62, 1.165, 0.68), 3)
	_coin_stack(Vector3(-0.85, 1.165, 0.74), 2)
	for i in 6:
		_cyl(0.07, 0.07, 0.014, _gold(), Vector3(-0.5 + i * 0.09, 1.17, 0.78 + 0.03 * (i % 2)), null, Vector3(0, i * 31.0, 0), 16)
	_sack(Vector3(-0.98, 1.165, 0.12), 0.34, Color(1.0, 0.9, 0.8), 20.0)
	# plateau de droite : sacs, encrier, plume
	var tray := _crate(Vector3(1.45, 1.17, 0.35), Vector3(1.4, 0.34, 0.62))
	_sack(Vector3(1.0, 1.175, 0.3), 0.3, Color(0.85, 0.78, 0.7), -15.0)
	_sack(Vector3(1.38, 1.175, 0.12), 0.38, Color(0.95, 0.85, 0.75), 10.0)
	_sack(Vector3(1.85, 1.175, 0.35), 0.28, Color(0.9, 0.78, 0.65), 40.0)
	_sack(Vector3(1.6, 1.175, 0.58), 0.22, Color(0.8, 0.7, 0.6), 0.0)
	# plume dans un encrier
	_cyl(0.06, 0.08, 0.1, _mat(Color(0.18, 0.12, 0.08), 0.5), Vector3(0.45, 1.22, 0.45), null, Vector3.ZERO, 14)
	var feather := _box(Vector3(0.012, 0.6, 0.12), _mat(Color(0.93, 0.93, 0.9), 0.9), Vector3(0.5, 1.55, 0.43), null, Vector3(0, 0, -16))
	feather.mesh.set("size", Vector3(0.012, 0.6, 0.12))
	_box(Vector3(0.008, 0.62, 0.012), _mat(Color(0.75, 0.74, 0.7), 0.9), Vector3(0.5, 1.55, 0.43), null, Vector3(0, 0, -16))
	# sac suspendu à la poutre
	var hang := Node3D.new()
	hang.position = Vector3(0.95, 3.38, 0.7)
	add_child(hang)
	for i in 5:
		_torus(0.012, 0.03, _iron(), Vector3(0, -0.1 - i * 0.12, 0), hang, Vector3(90 * (i % 2), 0, 0))
	var sack_h := Node3D.new()
	sack_h.position = Vector3(0, -0.85, 0)
	hang.add_child(sack_h)
	var sm := _mat(Color(0.8, 0.65, 0.5), 1.0, 0.0, "burlap.webp", "burlap_n.webp", 1.4)
	var prof := [Vector2(0.0, 0.0), Vector2(0.18, 0.02), Vector2(0.3, 0.2), Vector2(0.27, 0.42), Vector2(0.14, 0.58), Vector2(0.05, 0.68), Vector2(0.08, 0.76)]
	_add(lathe(prof, 20), sm, Vector3(0, -0.12, 0), sack_h)
	_sway.append([hang, randf() * TAU, 0.04, "z"])

func _build_sides() -> void:
	# gauche : caisse d'épées + sac
	var cr := _crate(Vector3(-2.82, 0.0, 0.45), Vector3(0.95, 0.85, 0.8))
	_sword(cr, Vector3(-0.2, 0.78, 0.0), Vector3(0, 0, 22))
	_sword(cr, Vector3(0.05, 0.78, 0.08), Vector3(8, 0, -12), 1.0)
	_sword(cr, Vector3(0.24, 0.78, -0.05), Vector3(-6, 0, 6), 0.9)
	_sack(Vector3(-2.55, 0.0, 1.05), 0.78, Color(0.9, 0.78, 0.65), 25.0)
	_sack(Vector3(-3.05, 0.0, 0.85), 0.55, Color(0.8, 0.7, 0.58), -30.0)
	# droite : tonneau, caisse de parchemins, gros sac de pièces
	var barrel_prof := [Vector2(0.0, 0.0), Vector2(0.4, 0.0), Vector2(0.47, 0.18), Vector2(0.52, 0.55), Vector2(0.5, 0.9), Vector2(0.52, 1.3), Vector2(0.47, 1.62), Vector2(0.4, 1.8), Vector2(0.0, 1.8)]
	var b := _add(lathe(barrel_prof, 26), _mat(Color(0.82, 0.62, 0.42), 0.85, 0.0, "wood.webp", "wood_n.webp", 0.6), Vector3(3.05, 0.0, -0.1))
	b.scale = Vector3(1.0, 0.9, 1.0)
	for y in [0.25, 0.7, 1.1, 1.5]:
		var r := 0.43 + 0.1 * sin((y / 1.65) * PI) * 0.9
		_torus(r - 0.03, r + 0.03, _iron(), Vector3(3.05, y * 0.9 + 0.02, -0.1), null)
	var cr2 := _crate(Vector3(2.45, 0.0, 1.0), Vector3(0.95, 0.9, 0.8))
	var parch := _mat(Color(0.88, 0.78, 0.58), 0.9)
	for i in 5:
		_cyl(0.07, 0.07, 0.8, parch, Vector3(-0.3 + i * 0.15, 0.95, (i % 2) * 0.1 - 0.05), cr2, Vector3(0, 0, 6.0 * (i - 2)), 14)
	_sack(Vector3(3.0, 0.0, 1.15), 0.95, Color(0.95, 0.82, 0.68), -10.0, true)

func _build_lantern() -> void:
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.78, 0.55)
	fill.light_energy = 1.1
	fill.omni_range = 7.0
	fill.position = Vector3(0, 2.7, 2.4)
	add_child(fill)
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.6, 0.4)
	under.light_energy = 0.9
	under.omni_range = 4.0
	under.position = Vector3(0, 2.7, 0.2)
	add_child(under)
	var holder := Node3D.new()
	holder.position = Vector3(1.95, 3.38, 0.75)
	add_child(holder)
	for i in 4:
		_torus(0.012, 0.03, _iron(), Vector3(0, -0.12 - i * 0.12, 0), holder, Vector3(90 * (i % 2), 0, 0))
	var body := Node3D.new()
	body.position = Vector3(0, -0.95, 0)
	holder.add_child(body)
	var iron := _iron()
	var gold_iron := _mat(Color(0.2, 0.18, 0.16), 0.5, 0.9)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.035, 0.52, 0.035), gold_iron, Vector3(sx * 0.15, 0.0, sz * 0.15), body)
	_box(Vector3(0.4, 0.04, 0.4), gold_iron, Vector3(0, -0.28, 0), body)
	_box(Vector3(0.4, 0.04, 0.4), gold_iron, Vector3(0, 0.27, 0), body)
	_add(lathe([Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.17, 0.12), Vector2(0.05, 0.2), Vector2(0.0, 0.22)], 4), gold_iron, Vector3(0, 0.29, 0), body).rotation_degrees.y = 45
	_torus(0.015, 0.05, iron, Vector3(0, 0.55, 0), body, Vector3(90, 0, 0))
	var gl := StandardMaterial3D.new()
	gl.albedo_color = Color(1.0, 0.78, 0.4, 0.38)
	gl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.emission_enabled = true
	gl.emission = Color(1.0, 0.62, 0.22)
	gl.emission_energy_multiplier = 0.9
	gl.roughness = 0.1
	_box(Vector3(0.27, 0.46, 0.27), gl, Vector3.ZERO, body)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.86, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.7, 0.25)
	fm.emission_energy_multiplier = 3.0
	_flame = _sphere(0.07, fm, Vector3(0, -0.05, 0), body, Vector3(1, 1.6, 1))
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.68, 0.34)
	_lantern_light.light_energy = 2.4
	_lantern_light.omni_range = 7.5
	_lantern_light.shadow_enabled = true
	_lantern_light.shadow_bias = 0.08
	_lantern_light.shadow_normal_bias = 1.5
	_lantern_light.position = Vector3(0, -0.05, 0.1)
	body.add_child(_lantern_light)
	_sway.append([holder, randf() * TAU, 0.03, "z"])

func _build_merchant() -> void:
	var m := Node3D.new()
	m.name = "Marchand"
	m.position = Vector3(0.1, 0.0, -0.1)
	add_child(m)
	var skin := _mat(Color(0.9, 0.7, 0.58), 0.7)
	var cloak := _mat(Color(0.34, 0.2, 0.22), 0.9, 0.0, "cloth_red.webp", "cloth_red_n.webp", 0.9)
	var cloak_dark := _mat(Color(0.2, 0.12, 0.13), 0.95)
	var tunic := _mat(Color(0.42, 0.4, 0.2), 0.9)
	var strap := _mat(Color(0.45, 0.26, 0.12), 0.7)
	var beard_m := _mat(Color(0.95, 0.94, 0.92), 0.9)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.15, 0)
	m.add_child(_torso)
	# buste : tunique olive + cape qui retombe sur les épaules
	_add(lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.0), Vector2(0.44, 0.35), Vector2(0.42, 0.62), Vector2(0.3, 0.82), Vector2(0.13, 0.9), Vector2(0.0, 0.92)], 26), tunic, Vector3.ZERO, _torso)
	var cape := lathe([Vector2(0.0, 0.62), Vector2(0.6, 0.55), Vector2(0.58, 0.72), Vector2(0.48, 0.86), Vector2(0.28, 0.94), Vector2(0.0, 0.96)], 28)
	_add(cape, cloak, Vector3(0, 0.0, -0.03), _torso).scale = Vector3(1.12, 1.0, 0.78)
	_add(lathe([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.54, 0.22), Vector2(0.4, 0.5), Vector2(0.26, 0.62)], 26), cloak_dark, Vector3(0, 0.45, -0.18), _torso).scale = Vector3(1.0, 1.0, 0.7)
	# bretelles, boutons, broche
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.72, 0.03), strap, Vector3(sx * 0.17, 0.46, 0.27), _torso, Vector3(-8, 0, sx * 4))
		_sphere(0.032, _gold(), Vector3(sx * 0.17, 0.5, 0.31), _torso)
	for sx in [-1.0, 1.0]:
		_cyl(0.065, 0.065, 0.025, _gold(), Vector3(sx * 0.13, 0.84, 0.19), _torso, Vector3(90, 0, 0), 14)
		_torus(0.05, 0.078, _gold(), Vector3(sx * 0.13, 0.84, 0.2), _torso, Vector3(90, 0, 0))
	_box(Vector3(0.1, 0.1, 0.03), _gold(), Vector3(0, 0.6, 0.31), _torso, Vector3(0, 0, 45))
	_sphere(0.028, _mat(Color(0.2, 0.5, 0.35), 0.2, 0.2), Vector3(0, 0.6, 0.335), _torso)
	# bras posés sur le comptoir : manche + main
	for sx in [-1.0, 1.0]:
		var arm := _box(Vector3(0.2, 0.2, 0.62), tunic, Vector3(sx * 0.52, 0.2, 0.3), _torso, Vector3(18, sx * -12, 0))
		_sphere(0.115, skin, Vector3(sx * 0.58, 0.02, 0.66), _torso, Vector3(1.0, 0.7, 1.15))
		for f in 4:
			_sphere(0.034, skin, Vector3(sx * (0.5 + f * 0.044), 0.0, 0.76), _torso, Vector3(1, 0.9, 1.3))
	# tête
	_head = Node3D.new()
	_head.position = Vector3(0, 1.28, 0.03)
	_torso.add_child(_head)
	_sphere(0.215, skin, Vector3.ZERO, _head, Vector3(0.95, 1.12, 1.0))
	_sphere(0.045, skin, Vector3(0, -0.02, 0.2), _head, Vector3(0.9, 1.0, 1.1))            # nez
	for sx in [-1.0, 1.0]:
		var eye_w := _sphere(0.034, _mat(Color(0.95, 0.94, 0.9), 0.4), Vector3(sx * 0.085, 0.045, 0.185), _head, Vector3(1.2, 0.75, 0.6))
		_sphere(0.017, _mat(Color(0.12, 0.1, 0.1), 0.2), Vector3(sx * 0.085, 0.045, 0.2), _head, Vector3(1, 1, 0.6))
		_box(Vector3(0.13, 0.026, 0.05), _mat(Color(0.85, 0.85, 0.85), 0.9), Vector3(sx * 0.09, 0.105, 0.19), _head, Vector3(0, 0, sx * -20))   # sourcils
		_sphere(0.04, skin, Vector3(sx * 0.21, 0.0, 0.0), _head, Vector3(0.6, 1.2, 0.9))     # oreilles
		_sphere(0.06, beard_m, Vector3(sx * 0.19, -0.04, 0.02), _head, Vector3(0.7, 1.4, 1.0))   # favoris
		_sphere(0.05, beard_m, Vector3(sx * 0.05, -0.085, 0.215), _head, Vector3(1.5, 0.7, 0.8))  # moustache
	# barbe : cône effilé
	_add(lathe([Vector2(0.0, -0.46), Vector2(0.05, -0.38), Vector2(0.14, -0.22), Vector2(0.2, -0.09), Vector2(0.19, 0.0), Vector2(0.0, 0.0)], 22, func(v: Vector3) -> Vector3:
		return Vector3(v.x * 1.0, v.y, v.z * 0.8 + 0.1 + (v.y + 0.1) * 0.0)), beard_m, Vector3(0, -0.07, 0.05), _head)
	# chapeau de mage : bord large + calotte tordue + ruban + boucle
	var brim_prof := [Vector2(0.0, 0.0), Vector2(0.25, 0.0), Vector2(0.42, -0.015), Vector2(0.62, -0.06), Vector2(0.66, -0.1), Vector2(0.64, -0.1), Vector2(0.42, -0.04), Vector2(0.0, 0.03)]
	var hat_m := _mat(Color(0.34, 0.22, 0.14), 0.75, 0.0, "wood_dark.webp", "wood_dark_n.webp", 0.7)
	var hat := Node3D.new()
	hat.position = Vector3(0, 0.15, 0.0)
	hat.rotation_degrees = Vector3(-6, 0, 0)
	_head.add_child(hat)
	_add(lathe(brim_prof, 36), hat_m, Vector3.ZERO, hat)
	var crown := lathe([Vector2(0.24, 0.0), Vector2(0.23, 0.12), Vector2(0.2, 0.3), Vector2(0.15, 0.48), Vector2(0.09, 0.62), Vector2(0.04, 0.72), Vector2(0.0, 0.76)], 28, func(v: Vector3) -> Vector3:
		var t := clampf(v.y / 0.76, 0.0, 1.0)
		return Vector3(v.x, v.y, v.z - 0.34 * t * t - 0.0)).duplicate()
	_add(crown, hat_m, Vector3(0, 0.0, 0.0), hat)
	_torus(0.215, 0.268, strap, Vector3(0, 0.04, 0.0), hat)
	_box(Vector3(0.1, 0.1, 0.03), _gold(), Vector3(0, 0.05, 0.27), hat)
	_box(Vector3(0.05, 0.06, 0.035), strap, Vector3(0, 0.05, 0.275), hat)

# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	_t += delta
	if _lantern_light != null:
		var f := 1.0 + 0.07 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0 + 1.7) + 0.03 * sin(_t * 41.0)
		_lantern_light.light_energy = 2.4 * f
		if _flame != null:
			_flame.scale = Vector3(1.0, 1.6 * (0.94 + 0.1 * f), 1.0)
	for s in _sway:
		var n: Node3D = s[0]
		var a: float = sin(_t * 0.9 + float(s[1])) * float(s[2])
		if str(s[3]) == "z":
			n.rotation.z = a
		else:
			n.rotation.x = a * 0.5
	if _torso != null:
		_torso.scale = Vector3(1.0, 1.0 + 0.008 * sin(_t * 1.6), 1.0)
		_head.rotation.y = 0.12 * sin(_t * 0.45)
		_head.rotation.x = 0.03 * sin(_t * 0.8)
