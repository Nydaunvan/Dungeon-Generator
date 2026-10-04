extends SceneTree
## Captures de la proposition de fontaine 3D, dans une salle de pierre éclairée par une torche :
## godot --rendering-driver opengl3 --path . --script res://tools/shot_fountain.gd -- out=/tmp/fontaine [gif=1]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(720, 720)
	await process_frame
	var TM = load("res://scripts/dungeon/theme_materials.gd")
	var TL = load("res://scripts/dungeon/torch_layer.gd")
	var FT = load("res://scripts/dungeon/fountain_3d.gd")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.3)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var mats = TM.for_theme("stone")
	# salle : sol, fond et mur de droite
	var floor_ := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(8, 8)
	floor_.mesh = fq
	floor_.rotation_degrees.x = -90
	floor_.material_override = mats.floor
	root.add_child(floor_)
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(8, 4)
	back.mesh = bq
	back.position = Vector3(0, 2, -2.6)
	back.material_override = mats.wall
	root.add_child(back)
	var side := MeshInstance3D.new()
	side.mesh = bq
	side.position = Vector3(3.0, 2, 0)
	side.rotation_degrees.y = -90
	side.material_override = mats.wall
	root.add_child(side)
	var layer = TL.new()
	layer.add_torch(Vector3(-1.6, 2.2, -2.56), 0.0, "stone")
	layer.add_torch(Vector3(1.6, 2.2, -2.56), 0.0, "stone")
	root.add_child(layer)
	var fountain = FT.new()
	root.add_child(fountain)
	var cam := Camera3D.new()
	cam.fov = 42
	root.add_child(cam)
	var out := str(args.get("out", "/tmp/fontaine"))
	var look := func(yaw: float, pitch: float, dist: float, target: Vector3) -> void:
		var y := deg_to_rad(yaw)
		var p := deg_to_rad(pitch)
		cam.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * dist
		cam.look_at(target)
	var shot := func(name: String) -> void:
		root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	await create_timer(2.0).timeout
	# ----- fontaine active
	look.call(28.0, 14.0, 4.6, Vector3(0, 0.95, 0))
	await create_timer(0.6).timeout
	shot.call("actif_34")
	look.call(0.0, 7.0, 4.2, Vector3(0, 0.9, 0))
	await create_timer(0.3).timeout
	shot.call("actif_face")
	look.call(-35.0, 26.0, 2.5, Vector3(0, 0.75, 0))
	await create_timer(0.3).timeout
	shot.call("actif_detail")
	look.call(10.0, 62.0, 4.4, Vector3(0, 0.6, 0))
	await create_timer(0.3).timeout
	shot.call("actif_haut")
	# ----- animation (GIF) : on enchaîne des images de la vue 3/4
	if str(args.get("gif", "0")) == "1":
		look.call(28.0, 14.0, 4.6, Vector3(0, 0.95, 0))
		for i in 30:
			await create_timer(0.07).timeout
			shot.call("anim_%02d" % i)
	# ----- fontaine désactivée (minuteur en cours)
	fountain.set_active(false)
	await create_timer(7.5).timeout
	look.call(28.0, 14.0, 4.6, Vector3(0, 0.95, 0))
	await create_timer(0.4).timeout
	shot.call("inactif_34")
	look.call(10.0, 62.0, 4.4, Vector3(0, 0.6, 0))
	await create_timer(0.3).timeout
	shot.call("inactif_haut")
	quit()
