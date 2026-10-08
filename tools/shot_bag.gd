extends SceneTree
## Captures de la besace (colonne de droite + volet d'équipement) avec un sac garni.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_bag.gd -- out=/tmp/besace
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1500, 900)
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
	root.get_texture().get_image().save_png(out + "_volet.png")
	var tile = null
	for n in m.dock.find_children("*", "Button", true, false):
		if n.has_signal("quick"):
			tile = n
			break
	if tile != null:
		load("res://scripts/ui/bag_common.gd").show_item_tip(tile, m.gs, tile.it, m.gs.active_char_id)
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png(out + "_tip.png")
		load("res://scripts/ui/bag_common.gd").hide_item_tip()
	for n in m.dock.find_children("*", "Control", true, false):
		if n.has_signal("selected") and n.get("_bar") != null:
			n.selected.emit(1)
			break
	await create_timer(0.05).timeout
	root.get_texture().get_image().save_png(out + "_slide.png")
	quit()
