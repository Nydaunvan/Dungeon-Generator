class_name StudioViewer
extends SubViewportContainer
## Fenêtre 3D : caméra orbitale (glisser = tourner, molette = zoom, clic droit/milieu = déplacer), sol, éclairage,
## modèle courant et squelette dessiné par-dessus.

signal bone_picked(index: int)

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var overlay: MeshInstance3D
var yaw := 0.6
var pitch := -0.2
var dist := 5.5
var target := Vector3(0, 1.0, 0)
var show_bones := true
var selected := -1
var skeleton: Skeleton3D = null
var player: AnimationPlayer = null
var _bone_list: Array = []

func _init() -> void:
	stretch = true
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("17130f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a7f6e")
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	vp.add_child(_floor())
	overlay = MeshInstance3D.new()
	overlay.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	m.render_priority = 10
	overlay.material_override = m
	vp.add_child(overlay)
	_apply_cam()

func _floor() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-6, 7):
		var c := Color(0.36, 0.3, 0.22) if i != 0 else Color(0.6, 0.5, 0.3)
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(i * 0.5, 0, -3))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(i * 0.5, 0, 3))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(-3, 0, i * 0.5))
		im.surface_set_color(c)
		im.surface_add_vertex(Vector3(3, 0, i * 0.5))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	return mi

func _apply_cam() -> void:
	pitch = clampf(pitch, -1.45, 1.45)
	dist = clampf(dist, 1.0, 20.0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	cam.look_at_from_position(target + dir * dist, target, Vector3.UP)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= mm.relative.x * 0.008
			pitch -= mm.relative.y * 0.008
			_apply_cam()
		elif mm.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			var right := cam.global_transform.basis.x
			var up := cam.global_transform.basis.y
			target += (-right * mm.relative.x + up * mm.relative.y) * 0.004 * dist
			_apply_cam()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
			_apply_cam()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
			_apply_cam()

func frame_model() -> void:
	target = Vector3(0, 1.0, 0)
	dist = 5.5
	_apply_cam()

## Remplace le modèle affiché ; renvoie la racine affichée.
func show_node(n: Node3D) -> void:
	for c in holder.get_children():
		c.queue_free()
	skeleton = null
	player = null
	if n == null:
		_redraw()
		return
	holder.add_child(n)
	skeleton = n.get_node_or_null("Skeleton3D") as Skeleton3D
	player = n.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_redraw()

func set_bone_list(bones: Array) -> void:
	_bone_list = bones
	_redraw()

func _process(_d: float) -> void:
	if show_bones:
		_redraw()

func _joint_pos(i: int) -> Vector3:
	if skeleton != null and i < skeleton.get_bone_count():
		return skeleton.get_bone_global_pose(i).origin
	var p: Array = _bone_list[i].pos
	return Vector3(p[0], p[1], p[2])

## Dessine les os : lignes parent → enfant et petite croix à chaque articulation (l'os choisi est en rouge).
func _redraw() -> void:
	var im := overlay.mesh as ImmediateMesh
	im.clear_surfaces()
	if not show_bones or _bone_list.is_empty():
		return
	var idx := {}
	for i in _bone_list.size():
		idx[str(_bone_list[i].name)] = i
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var yellow := Color(1, 0.85, 0.3)
	var red := Color(1, 0.25, 0.2)
	for i in _bone_list.size():
		var a := _joint_pos(i)
		var sel := i == selected
		var col := red if sel else yellow
		var s := 0.05 if sel else 0.03
		for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			im.surface_set_color(col)
			im.surface_add_vertex(a - ax * s)
			im.surface_set_color(col)
			im.surface_add_vertex(a + ax * s)
		var par := str(_bone_list[i].parent)
		if par != "" and idx.has(par):
			im.surface_set_color(Color(1, 0.6, 0.2))
			im.surface_add_vertex(_joint_pos(int(idx[par])))
			im.surface_set_color(Color(1, 0.6, 0.2))
			im.surface_add_vertex(a)
	im.surface_end()

## Index de l'os dont l'articulation est la plus proche du point cliqué à l'écran (ou -1).
func pick_bone(screen_pos: Vector2) -> int:
	var best := -1
	var best_d := 18.0
	for i in _bone_list.size():
		var w := _joint_pos(i)
		if cam.is_position_behind(w):
			continue
		var d := cam.unproject_position(w).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = i
	return best
