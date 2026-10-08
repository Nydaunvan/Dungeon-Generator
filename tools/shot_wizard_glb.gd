extends SceneTree
func _init() -> void:
	root.size = Vector2i(1200, 1000)
	await process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.25, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-30, 30, 0); root.add_child(l)
	var m: Node3D = load("res://assets/misc/merchant3d/wizard/scene.gltf").instantiate()
	root.add_child(m)
	var aabb := AABB()
	var first := true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("AABB ", aabb)
	var cam := Camera3D.new(); root.add_child(cam)
	var c := aabb.get_center()
	var out := "/tmp/claude-0/s/g"
	for v in [[0.0, "face"], [90.0, "cote"], [180.0, "dos"]]:
		var y := deg_to_rad(v[0])
		cam.position = c + Vector3(sin(y), 0.1, cos(y)) * aabb.size.y * 1.6
		cam.look_at(c)
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png("%s_%s.png" % [out, v[1]])
	quit()
