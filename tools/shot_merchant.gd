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
	await create_timer(1.5).timeout
	var g: DungeonGrid = m.grid
	var tm: Dictionary = m.level.get("travelingMerchant", {})
	print("marchand: ", tm)
	var mp := Vector2i(int(tm.x), int(tm.y))
	var nd: Vector2i = m.inter.merchant_niche_dir()
	print("niche dir: ", nd)
	var dir := DungeonGrid.DIRS.find(nd)
	var back := mp - nd
	if g.is_walkable(back.x, back.y) and g.is_walkable(back.x - nd.x, back.y - nd.y):
		back = back - nd
	var mn = m.level_node.entities.merchant_node
	print("stall: ", mn, " pos=", mn.position if mn else null, " vis=", mn.visible if mn else null, " rig=", m.rig.position)
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
