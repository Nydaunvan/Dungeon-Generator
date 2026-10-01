extends SceneTree
## godot --script res://tools/shot_admin.gd -- out=/tmp/x size=1280x900 tabs=general,chars,classes,spells,items,levels [lang=en]
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
	data.admin_unlocked = true
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.5).timeout
	for tab in str(args.get("tabs", "general")).split(","):
		adm._select_tab(tab)
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png("%s_%s.png" % [args.get("out", "/tmp/adm"), tab])
	data.set_lang("fr")
	quit()
