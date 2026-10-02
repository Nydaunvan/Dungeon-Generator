extends SceneTree
## Capture de la porte d'accès admin : godot --script res://tools/shot_gate.gd -- out=/tmp/gate [lang=en] [size=1280x900]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1280x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var data = root.get_node("Data")
	data.set_lang(str(args.get("lang", "fr")))
	data.admin_unlocked = false
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png("%s_gate.png" % args.get("out", "/tmp/gate"))
	data.set_lang("fr")
	quit()
