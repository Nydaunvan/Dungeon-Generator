extends SceneTree
## Case de la besace du groupe survolée : elle s'agrandit, passe par-dessus ses voisines et n'est pas rognée par l'ascenseur.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_bag_hover.gd -- out=/tmp/besace_hover
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1700, 900)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(3.0).timeout
	var m = current_scene
	m.wand.paused_if = func(): return true
	await create_timer(6.0).timeout
	var inv = m.gs.inventory
	inv.clear()
	var inv_cls = m.inter.get_script()   # pour atteindre Inventory via le jeu
	for id in ["lib_sword", "lib_axe", "lib_dagger", "lib_staff", "lib_leather_armor", "lib_leather_cap", "lib_boots", "lib_haste_ring", "lib_light_plate", "lib_potion", "lib_potion", "lib_potion", "lib_potion_end", "lib_potion_end"]:
		for d in m.gs.cfg.itemLibrary:
			if d.id == id:
				var it: Dictionary = d.duplicate(true)
				it["uid"] = "%s_%d" % [id, randi()]
				inv.append(it)
	m.layout.bag.refresh()
	await create_timer(1.0).timeout
	var out := str(args.get("out", "/tmp/besace"))
	root.get_texture().get_image().save_png(out + "_colonne.png")
	m.dock.open_for(m.gs.active_char_id, inv[0])
	await create_timer(1.5).timeout
	var tiles: Array = []
	for n in m.dock.find_children("*", "Button", true, false):
		if n.has_signal("quick") and n.is_visible_in_tree() and n.get_global_rect().position.x > 0 and n.get_global_rect().end.x < 1700:
			tiles.append(n)
	print("TUILES ", tiles.size(), " ", tiles.map(func(t): return t.get_global_rect()))
	out = str(args.get("out", "/tmp/besace_hover"))
	for k in [0, 1, 4]:
		if k < tiles.size():
			tiles[k].mouse_entered.emit()
			await create_timer(0.5).timeout
			var r: Rect2 = tiles[k].get_global_rect()
			var img := root.get_texture().get_image()
			var crop := Rect2i(int(r.position.x) - 40, int(r.position.y) - 40, 180, 180)
			crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			img.get_region(crop).save_png("%s_%d.png" % [out, k])
			tiles[k].mouse_exited.emit()
			await create_timer(0.3).timeout
	quit()
