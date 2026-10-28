extends SceneTree
## godot --script res://tools/shot_atelier.gd -- tab=party [sub=items] [size=1440x900] [out=/tmp/x.png] [scroll=0] [lang=fr]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1440x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var data = root.get_node("Data")
	data.set_lang(str(args.get("lang", "fr")))
	data.admin_unlocked = true
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.5).timeout
	if args.has("sub"):
		load("res://scripts/admin/atelier_party.gd").set("sub", str(args.sub))
	if args.has("ctab"):
		load("res://scripts/admin/admin_classes.gd").set("_ctab", str(args.ctab))
	adm._select_tab(str(args.get("tab", "home")))
	await create_timer(1.2).timeout
	if args.has("scroll") and adm._scroll != null:
		adm._scroll.scroll_vertical = int(args.scroll)
		await create_timer(0.4).timeout
	if args.has("call"):
		await create_timer(0.1).timeout
		adm.call(str(args.call))
		await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/claude-0/at.png")))
	data.set_lang("fr")
	quit()
