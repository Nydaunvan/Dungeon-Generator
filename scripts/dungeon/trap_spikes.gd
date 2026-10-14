class_name TrapSpikes
extends RefCounted
## Piège « pointes au sol » en vrai volume : plaque de fer biseautée, douilles sombres et 25 pointes d'acier (hauteurs et inclinaisons
## variées, quelques pointes tachées de sang). Le maillage est construit une fois puis partagé par tous les pièges du donjon.

const PLATE := 1.5            ## côté de la plaque (m) ; la case fait 4 m
const PLATE_H := 0.05
const GRID := 5
const SPACING := 0.27
const SIDES := 8

static var _mesh: ArrayMesh
static var _mat_spikes: StandardMaterial3D
static var _mat_plate: StandardMaterial3D
static var _stain: Texture2D

static func make() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _get_mesh()
	mi.set_surface_override_material(0, _plate_mat())
	mi.set_surface_override_material(1, _spike_mat())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# ombre de contact douce autour de la plaque (le sol paraît légèrement noirci)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(PLATE * 1.55, PLATE * 1.55)
	q.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _stain_tex()
	sm.render_priority = 1
	q.material_override = sm
	q.rotation.x = -PI * 0.5
	q.position.y = -0.004
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(q)
	return mi

static func _stain_tex() -> Texture2D:
	if _stain == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0).length()
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.05, 0.04, 0.03, 0.62 * a * a * (3.0 - 2.0 * a)))
		_stain = ImageTexture.create_from_image(img)
	return _stain

static func _plate_mat() -> StandardMaterial3D:
	if _mat_plate == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.55
		m.roughness = 0.55
		_mat_plate = m
	return _mat_plate

static func _spike_mat() -> StandardMaterial3D:
	if _mat_spikes == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.85
		m.roughness = 0.32
		_mat_spikes = m
	return _mat_spikes

static func _get_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var mesh := ArrayMesh.new()
	# surface 0 : plaque et douilles (normales explicites)
	var pl := SurfaceTool.new()
	pl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := PLATE * 0.5
	var iron := Color(0.17, 0.155, 0.15)
	var edge := Color(0.26, 0.23, 0.2)
	_box(pl, Vector3(0, PLATE_H * 0.25, 0), Vector3(h, PLATE_H * 0.25, h), edge)                     # socle large
	_box(pl, Vector3(0, PLATE_H * 0.75, 0), Vector3(h - 0.045, PLATE_H * 0.25, h - 0.045), iron)     # dessus en retrait (biseau)
	# rivets aux quatre coins
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_prism(pl, Vector3(sx * (h - 0.09), PLATE_H, sz * (h - 0.09)), 0.028, 0.02, 8, edge)
	# douilles sombres autour de chaque pointe
	for ix in GRID:
		for iz in GRID:
			_prism(pl, _spike_pos(ix, iz) + Vector3(0, PLATE_H, 0), 0.075, 0.018, 10, Color(0.045, 0.04, 0.04))
	pl.commit(mesh)
	# surface 1 : pointes (normales lissées)
	var sp := SurfaceTool.new()
	sp.begin(Mesh.PRIMITIVE_TRIANGLES)
	sp.set_smooth_group(0)
	var blood := [3, 7, 11, 13, 18, 21]
	for ix in GRID:
		for iz in GRID:
			var idx := ix * GRID + iz
			var hsh := float((idx * 7919 + 13) % 97) / 97.0
			var hsh2 := float((idx * 104729 + 7) % 89) / 89.0
			var hgt := 0.30 + 0.12 * hsh + (0.06 if (ix + iz) % 2 == 0 else 0.0)
			var lean := Vector3((hsh2 - 0.5) * 0.07, 0, (hsh - 0.5) * 0.07)
			_spike(sp, _spike_pos(ix, iz) + Vector3(0, PLATE_H, 0), 0.058, hgt, lean, blood.has(idx))
	sp.generate_normals()
	sp.commit(mesh)
	_mesh = mesh
	return mesh

static func _spike_pos(ix: int, iz: int) -> Vector3:
	var o := float(GRID - 1) * 0.5
	return Vector3((float(ix) - o) * SPACING, 0.0, (float(iz) - o) * SPACING)

## Pointe : trois anneaux (base, tiers, pointe) ; dégradé rouille → acier clair, sang vers la pointe sur certaines.
static func _spike(st: SurfaceTool, base: Vector3, r: float, height: float, lean: Vector3, bloody: bool) -> void:
	var rings := [[0.0, 1.0], [0.35, 0.62], [0.75, 0.3], [1.0, 0.0]]
	var cols: Array = []
	for rg in rings:
		var t: float = rg[0]
		var c := Color(0.36, 0.30, 0.26).lerp(Color(0.74, 0.77, 0.82), clampf(t * 3.0, 0.0, 1.0)).lerp(Color(0.92, 0.94, 0.97), clampf((t - 0.6) * 2.5, 0.0, 1.0))
		if bloody:
			c = c.lerp(Color(0.34, 0.035, 0.03), clampf((t - 0.15) * 1.6, 0.0, 0.85))
		cols.append(c)
	for k in SIDES:
		var a0 := float(k) / float(SIDES) * TAU
		var a1 := float(k + 1) / float(SIDES) * TAU
		for j in rings.size() - 1:
			var ra: Array = rings[j]
			var rb: Array = rings[j + 1]
			var pa0 := _ring_pt(base, r, height, lean, ra, a0)
			var pa1 := _ring_pt(base, r, height, lean, ra, a1)
			var pb0 := _ring_pt(base, r, height, lean, rb, a0)
			var pb1 := _ring_pt(base, r, height, lean, rb, a1)
			_tri(st, pa0, pb0, pa1, cols[j], cols[j + 1], cols[j])
			if float(rb[1]) > 0.0:
				_tri(st, pa1, pb0, pb1, cols[j], cols[j + 1], cols[j + 1])

static func _ring_pt(base: Vector3, r: float, height: float, lean: Vector3, ring: Array, ang: float) -> Vector3:
	var t: float = ring[0]
	var rr := r * float(ring[1])
	return base + Vector3(cos(ang) * rr, t * height, sin(ang) * rr) + lean * (t * t)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	# sens horaire vu de l'extérieur (convention de Godot) : de l'extérieur, a → b → c tourne dans le sens horaire
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)

## Boîte alignée sur les axes, normales plates.
static func _box(st: SurfaceTool, c: Vector3, e: Vector3, col: Color) -> void:
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.UP, Vector3.FORWARD], [Vector3.LEFT, Vector3.UP, Vector3.BACK],
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP, Vector3.LEFT],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1] * e
		var v: Vector3 = f[2] * e
		var o := c + n * e
		var p0 := o - u - v
		var p1 := o + u - v
		var p2 := o + u + v
		var p3 := o - u + v
		var cn: Vector3 = (p1 - p0).cross(p2 - p0)
		var quad := [p0, p1, p2, p0, p2, p3]
		if cn.dot(n) > 0.0:       # trigonométrique vu de l'extérieur : on inverse pour obtenir le sens horaire
			quad = [p0, p2, p1, p0, p3, p2]
		for p in quad:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(p)

## Petit cylindre vertical (douille, rivet) posé en `base`, avec dessus plat.
static func _prism(st: SurfaceTool, base: Vector3, r: float, height: float, sides: int, col: Color) -> void:
	var top := base + Vector3(0, height, 0)
	for k in sides:
		var a0 := float(k) / float(sides) * TAU
		var a1 := float(k + 1) / float(sides) * TAU
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var nm := (d0 + d1).normalized()
		for p in [[base + d0 * r, nm], [top + d0 * r, nm], [base + d1 * r, nm], [base + d1 * r, nm], [top + d0 * r, nm], [top + d1 * r, nm]]:
			st.set_normal(p[1])
			st.set_color(col)
			st.add_vertex(p[0])
		for p in [[top, Vector3.UP], [top + d1 * r, Vector3.UP], [top + d0 * r, Vector3.UP]]:
			st.set_normal(p[1])
			st.set_color(col)
			st.add_vertex(p[0])
