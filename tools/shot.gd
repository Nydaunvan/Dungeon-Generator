extends SceneTree
# Usage: godot --path . --rendering-driver opengl3 --script res://tools/shot.gd -- scene=res://scenes/home.tscn out=/tmp/x.png wait=1.5 size=1280x720
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1280x720")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var packed: PackedScene = load(str(args.get("scene", "res://scenes/home.tscn")))
	root.add_child(packed.instantiate())
	await create_timer(float(args.get("wait", "1.5"))).timeout
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(str(args.get("out", "/tmp/shot.png")))
	quit()
