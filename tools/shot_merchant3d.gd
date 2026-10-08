extends SceneTree
## Captures de la proposition de marchand 3D :
## godot --rendering-driver opengl3 --path . --script res://tools/shot_merchant3d.gd -- out=/tmp/marchand
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1600, 1000)
	await process_frame
	var TM = load("res://scripts/dungeon/theme_materials.gd")
	var TL = load("res://scripts/dungeon/torch_layer.gd")
	var MC = load("res://scripts/dungeon/merchant_3d.gd")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.3)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var mats = TM.for_theme("stone")
	var bq := QuadMesh.new()
	bq.size = Vector2(14, 6)
	var back := MeshInstance3D.new()
	back.mesh = bq
	back.position = Vector3(0, 3, -1.0)
	back.material_override = mats.wall
	root.add_child(back)
	var floor_ := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(14, 10)
	floor_.mesh = fq
	floor_.rotation_degrees.x = -90
	floor_.material_override = mats.floor
	root.add_child(floor_)
	var m = MC.new()
	root.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	var out := str(args.get("out", "/tmp/marchand"))
	var look := func(yaw: float, pitch: float, dist: float, target: Vector3) -> void:
		var y := deg_to_rad(yaw)
		var p := deg_to_rad(pitch)
		cam.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
		cam.look_at(target)
	var shot := func(name: String) -> void:
		root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	await create_timer(2.0).timeout
	look.call(0.0, 4.0, 7.5, Vector3(0, 1.7, 0))
	await create_timer(0.5).timeout
	shot.call("face")
	look.call(28.0, 12.0, 6.5, Vector3(0, 1.5, 0))
	await create_timer(0.3).timeout
	shot.call("34")
	look.call(-12.0, 8.0, 3.6, Vector3(0, 1.2, 0.3))
	await create_timer(0.3).timeout
	shot.call("detail")
	quit()
