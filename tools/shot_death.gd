extends Node
## Mort du dernier monstre : mesure le délai entre le coup et l'effondrement, et vérifie que la salle de combat reste affichée pendant l'animation de mort.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/shot_death.tscn -- out=/tmp/d

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var tree := get_tree()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await tree.create_timer(2.5).timeout
	var out := str(args.get("out", "/tmp/d"))
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var placed := false
	for m in main.level.monsters:
		var st0: Dictionary = lst.get(str(m.id), {})
		if st0.is_empty() or not st0.alive or m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st0.x), int(st0.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				st0["hp"] = 1.0
				placed = true
				break
		if placed:
			break
	main.ctrl.refresh()
	await tree.create_timer(2.5).timeout
	var st = main.level_node.stage
	main.ctrl.attack()
	var t0 := Time.get_ticks_msec()
	var t_death := -1
	var t_fx_end := -1
	var t_exit := -1
	var shot := false
	var was_busy := false
	var t_fx_start := -1
	while Time.get_ticks_msec() - t0 < 12000:
		await tree.process_frame
		var t := Time.get_ticks_msec() - t0
		if t_death < 0 and st._nodes.is_empty():
			t_death = t
		if SpellFx3D.busy():
			if not was_busy:
				t_fx_start = t
			was_busy = true
		elif was_busy and t_fx_end < 0:
			t_fx_end = t
		if t_exit < 0 and not st.active:
			t_exit = t
			break
		if t_death >= 0 and not shot and t > t_death + 250:
			shot = true
			get_viewport().get_texture().get_image().save_png(out + "_mort.png")
	print("effet visuel de ", t_fx_start, " à ", t_fx_end, " ms ; mort du monstre à ", t_death, " ms, retour à l'exploration à ", t_exit, " ms")
	tree.quit()
