class_name TrapPit
extends RefCounted
## Piège « fosse » en vrai volume : un trou béant dans le sol de la case (le sol du niveau est découpé par `LevelBuilder`, voir `HALF`),
## aux parois de pierre qui s'assombrissent en descendant, un fond hérissé de pieux et un bord de pierres effritées. Désamorcé, des planches
## sont jetées en travers du trou (le piège reste en place, franchissable) ; un échec laisse la fosse ouverte pour un nouvel essai.
## Repère local : l'origine est au centre de la case, au niveau du sol.

const HALF := 0.85            ## demi-côté du trou (m) ; la case fait 4 m
const DEPTH := 2.4
const RIM := 0.5              ## largeur de la couronne de pierres autour du trou

static var _mesh: ArrayMesh
static var _planks: ArrayMesh
static var _mat: StandardMaterial3D
static var _mat_spikes: StandardMaterial3D

static func make() -> MeshInstance3D:
	_build()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("trap_pit", true)
	var pl := MeshInstance3D.new()
	pl.name = "Planks"
	pl.mesh = _planks
	pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pl.visible = false
	mi.add_child(pl)
	# faible lueur froide au fond : sans elle, l'ombre du bord noie la fosse et on ne voit plus ni les parois ni les pieux
	var l := OmniLight3D.new()
	l.name = "Depth"
	l.light_color = Color(0.75, 0.8, 0.95)
	l.light_energy = 0.9
	l.omni_range = 3.4
	l.light_specular = 0.0
	l.shadow_enabled = false
	l.position = Vector3(0, -0.7, 0)
	mi.add_child(l)
	return mi

## Piège désamorcé : les planches tombent en travers du trou (immédiat au chargement du niveau).
static func cover(root: Node, animate: bool = true) -> void:
	var pl := root.get_node_or_null("Planks") as Node3D
	if pl == null or bool(root.get_meta("trap_pit_off", false)):
		return
	root.set_meta("trap_pit_off", true)
	pl.visible = true
	var dl := root.get_node_or_null("Depth")
	if dl != null:
		dl.queue_free()
	if not animate or not root.is_inside_tree():
		pl.position.y = 0.0
		return
	pl.position.y = 0.9
	var tw := pl.create_tween()
	tw.tween_property(pl, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pl, "position:y", 0.05, 0.07)
	tw.tween_property(pl, "position:y", 0.0, 0.08)

static func _stone_mat() -> StandardMaterial3D:
	if _mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_mat = m
	return _mat

static func _spike_mat() -> StandardMaterial3D:
	return TrapSpikes._spike_mat()

static func _build() -> void:
	if _mesh != null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# parois : quatre faces tournées vers l'intérieur, en bandes qui s'assombrissent avec la profondeur
	var ys := [0.0, -0.5, -1.2, -DEPTH]
	var shade := [0.4, 0.3, 0.2, 0.12]
	var corners := [Vector2(-HALF, -HALF), Vector2(HALF, -HALF), Vector2(HALF, HALF), Vector2(-HALF, HALF)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var inward := Vector3((a + b).x * -0.5, 0, (a + b).y * -0.5).normalized()
		for j in 3:
			var ca := _tone(shade[j], rng, 0.03)
			var cb := _tone(shade[j + 1], rng, 0.03)
			_quad(st, Vector3(a.x, ys[j], a.y), Vector3(b.x, ys[j], b.y), Vector3(b.x, ys[j + 1], b.y), Vector3(a.x, ys[j + 1], a.y), inward, ca, cb)
		# quelques blocs en saillie sur la paroi (joints de maçonnerie)
		for i in 5:
			var t := rng.randf_range(0.12, 0.88)
			var y := rng.randf_range(-1.5, -0.12)
			var p := a.lerp(b, t)
			var e := Vector3(rng.randf_range(0.1, 0.2), rng.randf_range(0.07, 0.14), 0.05)
			var yaw := atan2(inward.x, inward.z)
			_rbox(st, Vector3(p.x, y, p.y) + inward * 0.04, e, yaw, _tone(maxf(0.08, 0.4 * (1.0 + y / 3.5)), rng, 0.02))
	# fond : sol sombre
	_quad(st, Vector3(-HALF, -DEPTH, HALF), Vector3(HALF, -DEPTH, HALF), Vector3(HALF, -DEPTH, -HALF), Vector3(-HALF, -DEPTH, -HALF), Vector3.UP, Color(0.1, 0.085, 0.075), Color(0.1, 0.085, 0.075))
	# couronne de pierres effritées autour du trou
	for i in 22:
		var side := i % 4
		var t := rng.randf_range(-HALF - RIM * 0.5, HALF + RIM * 0.5)
		var off := HALF + rng.randf_range(0.05, RIM)
		var p := Vector2(t, -off)
		match side:
			1: p = Vector2(off, t)
			2: p = Vector2(t, off)
			3: p = Vector2(-off, t)
		var e := Vector3(rng.randf_range(0.06, 0.15), rng.randf_range(0.02, 0.06), rng.randf_range(0.06, 0.13))
		_rbox(st, Vector3(p.x, e.y - 0.004, p.y), e, rng.randf_range(0.0, TAU), _tone(rng.randf_range(0.22, 0.36), rng, 0.04))
	# gravats qui débordent sur le bord du trou
	for i in 8:
		var a := rng.randf_range(0.0, TAU)
		var r := HALF + rng.randf_range(-0.12, 0.02)
		var e := Vector3(rng.randf_range(0.04, 0.09), rng.randf_range(0.03, 0.05), rng.randf_range(0.04, 0.09))
		var p := Vector2(cos(a), sin(a)) * r
		p = Vector2(clampf(p.x, -HALF - 0.02, HALF + 0.02), clampf(p.y, -HALF - 0.02, HALF + 0.02))
		_rbox(st, Vector3(p.x, e.y, p.y), e, rng.randf_range(0.0, TAU), _tone(0.3, rng, 0.04))
	_mesh = ArrayMesh.new()
	st.commit(_mesh)
	_mesh.surface_set_material(0, _stone_mat())
	# pieux du fond (normales lissées, matériau d'acier propre au piège de pointes)
	var sp := SurfaceTool.new()
	sp.begin(Mesh.PRIMITIVE_TRIANGLES)
	sp.set_smooth_group(0)
	var n := 0
	for ix in 4:
		for iz in 4:
			var base := Vector3((float(ix) - 1.5) * 0.4, -DEPTH, (float(iz) - 1.5) * 0.4) + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05))
			TrapSpikes._spike(sp, base, 0.06, rng.randf_range(0.45, 0.8), lean, n % 5 == 2)
			n += 1
	sp.generate_normals()
	sp.commit(_mesh)
	_mesh.surface_set_material(1, _spike_mat())
	# planches jetées en travers (nœud à part, caché tant que le piège est actif)
	var pk := SurfaceTool.new()
	pk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.5, 0.34, 0.19)
	for i in 5:
		var x := (float(i) - 2.0) * 0.36 + rng.randf_range(-0.03, 0.03)
		var w := rng.randf_range(0.15, 0.17)
		_rbox(pk, Vector3(x, 0.035, rng.randf_range(-0.05, 0.05)), Vector3(w, 0.035, 1.18), rng.randf_range(-0.05, 0.05), _tone(0.5, rng, 0.07) * wood * 1.7)
	for z in [-0.55, 0.55]:
		_rbox(pk, Vector3(0, 0.0, z), Vector3(0.98, 0.03, 0.07), 0.0, wood * 0.7)
	_planks = ArrayMesh.new()
	pk.commit(_planks)
	_planks.surface_set_material(0, _stone_mat())

static func _tone(v: float, rng: RandomNumberGenerator, jitter: float) -> Color:
	var j := rng.randf_range(-jitter, jitter)
	return Color(clampf(v + j, 0.0, 1.0), clampf(v * 0.93 + j, 0.0, 1.0), clampf(v * 0.85 + j, 0.0, 1.0))

## Quadrilatère a-b-c-d (a, b en haut, c, d en bas) tourné vers `n`, couleur ca en haut et cb en bas ; sens horaire vu de `n`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ca: Color, cb: Color) -> void:
	var cn := (b - a).cross(c - a)
	var pts: Array = [[a, ca], [b, ca], [c, cb], [a, ca], [c, cb], [d, cb]]
	if cn.dot(n) > 0.0:
		pts = [[a, ca], [c, cb], [b, ca], [a, ca], [d, cb], [c, cb]]
	for p in pts:
		st.set_normal(n)
		st.set_color(p[1])
		st.add_vertex(p[0])

## Boîte tournée de `yaw` autour de Y, normales plates.
static func _rbox(st: SurfaceTool, c: Vector3, e: Vector3, yaw: float, col: Color) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.UP, Vector3.FORWARD], [Vector3.LEFT, Vector3.UP, Vector3.BACK],
		[Vector3.BACK, Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP, Vector3.LEFT],
	]
	for f in faces:
		var n: Vector3 = bs * (f[0] as Vector3)
		var u: Vector3 = bs * ((f[1] as Vector3) * e)
		var v: Vector3 = bs * ((f[2] as Vector3) * e)
		var o := c + bs * ((f[0] as Vector3) * e)
		var p0 := o - u - v
		var p1 := o + u - v
		var p2 := o + u + v
		var p3 := o - u + v
		var cn := (p1 - p0).cross(p2 - p0)
		var quad := [p0, p1, p2, p0, p2, p3]
		if cn.dot(n) > 0.0:
			quad = [p0, p2, p1, p0, p3, p2]
		for p in quad:
			st.set_normal(n)
			st.set_color(col)
			st.add_vertex(p)
