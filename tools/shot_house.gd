extends SceneTree
## Capture d'un modèle de maison. Usage : godot --script res://tools/shot_house.gd -- <modele.fbx> <sortie.png>
func _aabb(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and n.visible:
		var mi := n as MeshInstance3D
		var bb := mi.global_transform * mi.get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_aabb(c, acc)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1000, 700)
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.75, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -40, 0)
	w.add_child(sun)
	var n: Node = (load(a[0]) as PackedScene).instantiate()
	w.add_child(n)
	for c in n.get_children():
		if c is Camera3D or c is Light3D:
			c.queue_free()
	if a.size() > 2:
		for c in n.get_children():
			if c is MeshInstance3D and not str(a[2]).split(',').has(str(c.name)):
				c.visible = false
	await process_frame
	var acc: Array = [null]
	_aabb(n, acc)
	var bb: AABB = acc[0]
	print("AABB ", bb)
	var ctr := bb.get_center()
	var r := bb.size.length()
	var cam := Camera3D.new()
	w.add_child(cam)
	cam.position = ctr + Vector3(0.7, 0.35, 1.0).normalized() * r * 1.3
	cam.look_at(ctr)
	cam.far = r * 10
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(a[1])
	quit()
