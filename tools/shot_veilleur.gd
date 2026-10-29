extends SceneTree
## Essai d'intégration du Veilleur Os : combat contre lui, puis poses d'attaque (×4), coup reçu et mort.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tools/shot_veilleur.gd -- out=/tmp/vo
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1600x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	var out := str(args.get("out", "/tmp/vo"))
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	for mm in main.level.monsters:
		mm["icon"] = "@icon:mon_veilleur_os"
		mm.erase("isBoss")
	main.load_level(main.level_index)
	await create_timer(1.5).timeout
	g = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var st: Dictionary = lst.get(str(m.id), {})
		if st.is_empty() or not st.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st.x), int(st.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				found = true
				break
		if found:
			break
	main.ctrl.refresh()
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "_idle.png")
	var stage = main.level_node.stage
	var mid: String = stage.mon_id
	for i in 4:
		stage.react(mid, "attack")
		await create_timer(0.28).timeout
		root.get_texture().get_image().save_png(out + "_attack%d.png" % i)
		await create_timer(0.9).timeout
	stage.react(mid, "hit")
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png(out + "_hit.png")
	await create_timer(0.8).timeout
	stage.die_all()
	await create_timer(0.45).timeout
	root.get_texture().get_image().save_png(out + "_dead.png")
	quit()
