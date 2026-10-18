extends SceneTree
## Mort du dernier monstre : la salle de combat doit rester affichée pendant l'animation de mort, puis laisser place à l'exploration.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_death.gd -- out=/tmp/d
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 800)
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	var out := str(args.get("out", "/tmp/d"))
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var placed := false
	for m in main.level.monsters:
		var st: Dictionary = lst.get(str(m.id), {})
		if st.is_empty() or not st.alive or m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st.x), int(st.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				st["hp"] = 1.0
				placed = true
				break
		if placed:
			break
	main.ctrl.refresh()
	await create_timer(2.5).timeout
	print("avant coup : in_combat=", main.ctrl.in_combat(), " stage=", main.level_node.stage.active)
	main.ctrl.attack()
	var t0 := Time.get_ticks_msec()
	for k in 12:
		await create_timer(0.15).timeout
		var t := Time.get_ticks_msec() - t0
		print("t=", t, " ms  in_combat=", main.ctrl.in_combat(), " model=", main.ctrl.model_in_combat(), " stage=", main.level_node.stage.active)
		if k >= 3 and k <= 6:
			root.get_texture().get_image().save_png("%s_%d.png" % [out, k])
	quit()
