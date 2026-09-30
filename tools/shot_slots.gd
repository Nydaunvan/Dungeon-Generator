extends SceneTree
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1280x800")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var packed: PackedScene = load("res://scenes/home.tscn")
	var h := packed.instantiate()
	root.add_child(h)
	await create_timer(1.5).timeout
	var layer = h.get("_modal_layer")
	load("res://scripts/ui/slots_modal.gd").open(layer, Callable(), Callable())
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/slots.png")))
	quit()
