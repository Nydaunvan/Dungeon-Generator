extends SceneTree
## Capture de la page d'accueil.
## Lancer : xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tools/shot_home.gd -- out=/tmp/home size=1600x900
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1600x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var data = root.get_node("Data")
	data.go_home()
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/home")) + ".png")
	quit()
