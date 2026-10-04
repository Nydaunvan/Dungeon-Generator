extends SceneTree
## Captures d'une torche murale sous plusieurs angles (calage de la flamme) :
## godot --rendering-driver opengl3 --path . --script res://tools/shot_torch.gd -- out=/tmp/torch [theme=stone]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(640, 640)
	await process_frame
	var theme := str(args.get("theme", "stone"))
	# chargées à l'exécution : les autoloads (Data) n'existent pas encore à la compilation de ce script
	var TM = load("res://scripts/dungeon/theme_materials.gd")
	var TL = load("res://scripts/dungeon/torch_layer.gd")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.36, 0.28)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	# mur de pierre (plan Z = -0.04, face vers +Z)
	var wall := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6, 4)
	wall.mesh = q
	wall.material_override = TM.for_theme("stone").wall
	wall.position = Vector3(0, 0, -0.04)
	root.add_child(wall)
	var floor_ := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(6, 3)
	floor_.mesh = fq
	floor_.rotation_degrees.x = -90
	floor_.position = Vector3(0, -1.2, 1.4)
	floor_.material_override = TM.for_theme("stone").floor
	root.add_child(floor_)
	var layer = TL.new()
	layer.add_torch(Vector3.ZERO, 0.0, theme)
	root.add_child(layer)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var target := Vector3(0, 0.1, 0.18)
	var views := {"face": [0.0, 0.0], "g45": [-45.0, 0.0], "d45": [45.0, 0.0], "g75": [-75.0, 8.0], "dessus": [0.0, 55.0], "dessous": [0.0, -45.0], "d_loin": [30.0, 10.0]}
	var out := str(args.get("out", "/tmp/torch"))
	for name in views:
		var yaw: float = deg_to_rad(views[name][0])
		var pitch: float = deg_to_rad(views[name][1])
		var dist := 1.25 if name != "d_loin" else 3.2
		cam.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
		cam.look_at(target)
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	quit()
