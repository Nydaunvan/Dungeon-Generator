extends SceneTree
## Capture de l'étal du marchand dans sa niche.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_merchant.gd -- out=/tmp/marchand
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 800)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(2.5).timeout
	var m = current_scene
	m.wand.paused_if = func(): return true
	var li := 1
	m.load_level(li)
	await create_timer(8.0).timeout
	var g: DungeonGrid = m.grid
	var tm: Dictionary = m.wand.merchant()
	print("marchand: ", tm)
	var mp := Vector2i(int(tm.x), int(tm.y))
	var nd: Vector2i = m.inter.merchant_niche_dir()
	print("niche dir: ", nd, " tm=", m.level.get("travelingMerchant"))
	var dir := DungeonGrid.DIRS.find(nd)
	var back := mp - nd
	if g.is_walkable(back.x, back.y) and g.is_walkable(back.x - nd.x, back.y - nd.y):
		back = back - nd
	print("wand merchant: ", m.wand.merchant(), " stall rot=", m.level_node.entities.merchant_node.rotation.y, " grid same=", m.level_node.entities._grid == m.grid)
	var mn = m.level_node.entities.merchant_node
	print("stall: ", mn, " pos=", mn.position if mn else null, " vis=", mn.visible if mn else null, " rig=", m.rig.position)
	var eg = m.level_node.entities._grid
	for yy in range(mp.y - 2, mp.y + 3):
		var a := ""
		var b := ""
		for xx in range(mp.x - 4, mp.x + 5):
			a += str(g.cell(xx, yy))
			b += str(eg.cell(xx, yy))
		print("ROW main=", a, " ents=", b)
	print("stall children=", mn.get_child_count(), " in_tree=", mn.is_inside_tree(), " gpos=", mn.global_position, " parent=", mn.get_parent().name, " parent_vis=", mn.get_parent().visible, " cam=", m.rig.global_position)
	m.rig.place(g, mp.x, mp.y, dir)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/marchand")) + "_pres.png")
	if g.is_walkable(back.x, back.y):
		m.rig.place(g, back.x, back.y, dir)
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png(str(args.get("out", "/tmp/marchand")) + "_loin.png")
	var side := mp + Vector2i(-nd.y, nd.x)
	if g.is_walkable(side.x, side.y):
		m.rig.place(g, side.x, side.y, dir)
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png(str(args.get("out", "/tmp/marchand")) + "_cote.png")
	quit()
