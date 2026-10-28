extends SceneTree
## godot --script res://tools/shot_atelier.gd -- tab=party [sub=items] [size=1440x900] [out=/tmp/x.png] [scroll=0] [lang=fr]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1440x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	if args.has("logical"):
		var lg := str(args.logical).split("x")
		root.content_scale_size = Vector2i(int(lg[0]), int(lg[1]))
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
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
	var lv = load("res://scripts/admin/admin_levels.gd")
	if args.has("narrow"):
		lv.set("force_narrow", true)
	if args.has("lvtab"):
		lv.set("_tab", str(args.lvtab))
		lv.set("_ntab", str(args.lvtab))
	adm._select_tab(str(args.get("tab", "home")))
	await create_timer(1.2).timeout
	if args.has("lvcell"):
		var c := str(args.lvcell).split(",")
		lv.set("_cell", Vector2i(int(c[0]), int(c[1])))
		lv.call("_render_all")
		await create_timer(0.5).timeout
	if args.has("lvopen"):
		var o := str(args.lvopen)
		if o == "mon":
			var l = lv.call("_current")
			lv.set("_open_mon", str(l.monsters[0].id))
		else:
			var l = lv.call("_current")
			for it in l.items:
				if str(it.get("type", "")) == o:
					lv.set("_open_item", str(it.id))
					break
		lv.call("_render_sub")
		await create_timer(0.5).timeout
	if args.has("lvscroll"):
		var sc = lv.get("_panel_scroll")
		if sc != null:
			sc.scroll_vertical = int(args.lvscroll)
			await create_timer(0.4).timeout
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
