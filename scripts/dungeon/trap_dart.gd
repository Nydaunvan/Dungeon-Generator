class_name TrapDart
extends RefCounted
## Piège « fléchettes » en vrai mécanisme mural : plaque de fer rivetée encastrée dans le mur, huit trous cerclés d'où sortent des
## fléchettes (hampe de bois, pointe d'acier, empennage rouge) et dalle de déclenchement posée au sol, sur la case voisine du mur.
## Repère local : l'origine est sur la face du mur, +Z va vers le couloir, +Y vers le haut. Le nœud se pose à hauteur d'yeux (HEIGHT).
## Déclenché, il tire une salve de fléchettes puis se réarme ; désamorcé, les fléchettes rentrent dans leurs trous pour de bon.

const HEIGHT := 1.5            ## hauteur de la plaque au-dessus du sol (m)
const CELL_DEPTH := 2.0        ## distance du mur au centre de la case (CELL / 2)
const COLS := 4
const ROWS := 2
const PITCH := 0.34
const DART_LEN := 0.42

static var _plate_mesh: ArrayMesh
static var _slab_mesh: ArrayMesh
static var _dart_mesh: ArrayMesh
static var _mat_plate: StandardMaterial3D
static var _mat_dart: StandardMaterial3D

## `yaw` : rotation du nœud pour que +Z regarde vers la case (voir `yaw_for`).
## `height` : hauteur de la plaque au-dessus du sol (la dalle reste posée au sol, quelle que soit la hauteur).
static func make(height: float = HEIGHT) -> MeshInstance3D:
	_build_meshes()
	var mi := MeshInstance3D.new()
	mi.mesh = _plate_mesh
	mi.material_override = _plate_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.set_meta("trap_dart", true)
	var darts := MeshInstance3D.new()
	darts.name = "Darts"
	darts.mesh = _dart_mesh
	darts.material_override = _dart_mat()
	darts.position.z = 0.07
	darts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.add_child(darts)
	var slab := MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = _slab_mesh
	slab.material_override = _plate_mat()
	slab.position.y = -height
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(slab)
	return mi

## Angle (autour de Y) qui oriente +Z vers l'intérieur de la case, le mur étant dans la direction `d` depuis la case.
static func yaw_for(d: Vector2i) -> float:
	return atan2(-float(d.x), -float(d.y))

## Salve tirée vers le couloir : les fléchettes partent d'un trait, puis le mécanisme se recharge (le piège reste actif).
static func fire(root: Node3D) -> void:
	var darts := root.get_node_or_null("Darts") as MeshInstance3D
	if darts == null or not root.is_inside_tree() or not darts.visible:
		return
	var volley := MeshInstance3D.new()
	volley.mesh = darts.mesh
	volley.material_override = darts.material_override
	volley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(volley)
	volley.position = darts.position
	var tw := volley.create_tween()
	tw.tween_property(volley, "position:z", darts.position.z + 3.4, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(volley.queue_free)
	darts.scale.z = 0.001
	var rl := darts.create_tween()
	rl.tween_interval(0.5)
	rl.tween_property(darts, "scale:z", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Désamorcé : les fléchettes rentrent dans leurs trous (immédiat au chargement du niveau).
static func retract(root: Node, animate: bool = true) -> void:
	var darts := root.get_node_or_null("Darts") as Node3D
	if darts == null:
		return
	root.set_meta("trap_dart_off", true)
	for t in darts.get_children():
		t.queue_free()
	if not animate or not root.is_inside_tree():
		darts.scale.z = 0.001
		darts.visible = false
		return
	var tw := darts.create_tween()
	tw.tween_property(darts, "scale:z", 0.001, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(darts):
			darts.visible = false)

static func _plate_mat() -> StandardMaterial3D:
	if _mat_plate == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.5
		m.roughness = 0.6
		_mat_plate = m
	return _mat_plate

static func _dart_mat() -> StandardMaterial3D:
	if _mat_dart == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.45
		m.roughness = 0.45
		_mat_dart = m
	return _mat_dart

static func _hole_pos(c: int, r: int) -> Vector2:
	return Vector2((float(c) - float(COLS - 1) * 0.5) * PITCH, (float(r) - float(ROWS - 1) * 0.5) * PITCH)

static func _build_meshes() -> void:
	if _plate_mesh != null:
		return
	var iron := Color(0.3, 0.29, 0.28)
	var edge := Color(0.44, 0.4, 0.33)
	var stone := Color(0.15, 0.14, 0.13)
	var dark := Color(0.015, 0.012, 0.012)
	var rust := Color(0.34, 0.2, 0.12)
	# plaque : encadrement de pierre, tôle de fer, rivets, trous cerclés
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	TrapSpikes.add_box(st, Vector3(0, 0, 0.02), Vector3(0.88, 0.5, 0.02), stone)
	TrapSpikes.add_box(st, Vector3(0, 0, 0.045), Vector3(0.8, 0.43, 0.025), edge)
	TrapSpikes.add_box(st, Vector3(0, 0, 0.062), Vector3(0.76, 0.39, 0.012), iron)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			_cyl(st, Vector3(sx * 0.7, sy * 0.3, 0.07), 0.028, 0.02, 0.022, 8, rust)
	for r in ROWS:
		for c in COLS:
			var h := _hole_pos(c, r)
			_cyl(st, Vector3(h.x, h.y, 0.07), 0.085, 0.07, 0.03, 12, edge)        # collerette
			_cyl(st, Vector3(h.x, h.y, 0.1), 0.058, 0.058, 0.004, 12, dark)       # trou
	_plate_mesh = ArrayMesh.new()
	st.commit(_plate_mesh)
	# dalle de déclenchement : sur la case voisine, au sol
	var sl := SurfaceTool.new()
	sl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fy := 0.0
	TrapSpikes.add_box(sl, Vector3(0, fy + 0.02, CELL_DEPTH), Vector3(0.62, 0.02, 0.62), stone)
	TrapSpikes.add_box(sl, Vector3(0, fy + 0.045, CELL_DEPTH), Vector3(0.52, 0.012, 0.52), edge)
	TrapSpikes.add_box(sl, Vector3(0, fy + 0.059, CELL_DEPTH), Vector3(0.14, 0.005, 0.14), rust)
	_slab_mesh = ArrayMesh.new()
	sl.commit(_slab_mesh)
	# fléchettes : une par trou, pointe vers +Z
	var ds := SurfaceTool.new()
	ds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := Color(0.42, 0.28, 0.15)
	var steel := Color(0.78, 0.8, 0.84)
	var red := Color(0.62, 0.08, 0.06)
	for r in ROWS:
		for c in COLS:
			var h := _hole_pos(c, r)
			_cyl(ds, Vector3(h.x, h.y, 0.0), 0.014, 0.014, DART_LEN * 0.8, 6, wood)
			_cyl(ds, Vector3(h.x, h.y, DART_LEN * 0.8), 0.022, 0.0, DART_LEN * 0.2, 6, steel)
			TrapSpikes.add_box(ds, Vector3(h.x, h.y, 0.035), Vector3(0.002, 0.03, 0.035), red)
			TrapSpikes.add_box(ds, Vector3(h.x, h.y, 0.035), Vector3(0.03, 0.002, 0.035), red)
	_dart_mesh = ArrayMesh.new()
	ds.commit(_dart_mesh)

## Tronc de cône d'axe Z (de `base` vers +Z) : rayons r0 (base) et r1 (bout, 0 = pointe), dessus fermé ; normales de la surface.
static func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, length: float, sides: int, col: Color) -> void:
	var xf := Basis(Vector3.RIGHT, PI * 0.5)        # fait de Y l'axe du tronc : Y -> +Z, avec conservation du sens des faces
	var slope := (r0 - r1) / maxf(length, 0.0001)
	for k in sides:
		var a0 := float(k) / float(sides) * TAU
		var a1 := float(k + 1) / float(sides) * TAU
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n0 := Vector3(d0.x, slope, d0.z).normalized()
		var n1 := Vector3(d1.x, slope, d1.z).normalized()
		var b0 := d0 * r0
		var b1 := d1 * r0
		var t0 := d0 * r1 + Vector3(0, length, 0)
		var t1 := d1 * r1 + Vector3(0, length, 0)
		for p in [[b0, n0], [b1, n1], [t0, n0], [b1, n1], [t1, n1], [t0, n0]]:
			st.set_normal(xf * (p[1] as Vector3))
			st.set_color(col)
			st.add_vertex(base + xf * (p[0] as Vector3))
		if r1 > 0.0:
			for p in [Vector3(0, length, 0), t0, t1]:
				st.set_normal(xf * Vector3.UP)
				st.set_color(col)
				st.add_vertex(base + xf * (p as Vector3))
