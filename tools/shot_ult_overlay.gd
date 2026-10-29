extends SceneTree
## Capture : bouton d'ultime doré (droite) et sceau rouge de l'instinct (gauche) affichés ensemble (montage ; en jeu l'instinct masque l'ultime).
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_ult_overlay.gd -- out=/tmp/x size=1600x900 cls=class_assassin both=1
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1600x900")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var Chars: GDScript = load("res://scripts/rules/characters.gd")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var st: Dictionary = lst.get(str(m.id), {})
		if st.is_empty() or not st.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st.x), int(st.y)) - v
			if main.grid.is_walkable(from.x, from.y):
				main.rig.place(main.grid, from.x, from.y, d)
				found = true
				break
		if found:
			break
	main.ctrl.refresh()
	await create_timer(2.0).timeout
	var gs = main.gs
	var hero: Dictionary = gs.party[0]
	hero["classId"] = str(args.get("cls", "class_assassin"))
	hero["level"] = 5
	hero["ultCharge"] = 100.0
	gs.active_char_id = hero.id
	main.ctrl.combat.ensure_gauges()
	main.ctrl.combat.gauges["char_" + str(hero.id)] = 100.0
	var ult = null
	for c in main.instinct_ui.get_parent().get_children():
		var sc = c.get_script()
		if sc != null and sc.get_global_name() == &"UltimateOverlay": ult = c
	if args.has("both"):
		ult.instinct = null
		main.ctrl.instinct_prompt.emit(str(gs.party[1].id), 30.0)
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/ult_overlay")) + "_overlay.png")
	print("shown=", ult._shown)
	quit()
