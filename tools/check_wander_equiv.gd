extends SceneTree
## Le pas des monstres optimisé (index des cases et des pièges) donne EXACTEMENT les mêmes déplacements que les parcours complets d'origine.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_wander_equiv.gd -- 41
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 41
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 1, n, n, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var w = m.wand
	var guard := 0
	while w.level.is_empty() and guard < 600:
		await create_timer(0.1).timeout
		guard += 1
	await create_timer(1.0).timeout
	var ms: Dictionary = m.gs.level_state(m.level).monsters
	var snap := {}
	for k in ms:
		snap[k] = [ms[k].x, ms[k].y]
	var rng0 := GameRng.export_state()
	m.gs.stats["calmTicks"] = 0
	var res := []
	for pass_i in 2:
		for k in snap:
			ms[k]["x"] = snap[k][0]
			ms[k]["y"] = snap[k][1]
		GameRng.import_state(rng0.duplicate(true))
		m.gs.stats["calmTicks"] = 0
		w.force_slow = pass_i == 1
		var t := Time.get_ticks_usec()
		for i in 120:
			w._tick()
		var dt := (Time.get_ticks_usec() - t) / 120
		var sig := ""
		for k in ms:
			sig += "%s:%d,%d;" % [k, ms[k].x, ms[k].y]
		res.append([sig.hash(), dt])
	var moved := 0
	for k in snap:
		if ms[k].x != snap[k][0] or ms[k].y != snap[k][1]: moved += 1
	print("rapide : %d µs/pas  |  d'origine : %d µs/pas  |  monstres déplacés=%d" % [res[0][1], res[1][1], moved])
	print("RESULTAT équivalence -> ", "OK" if res[0][0] == res[1][0] and moved > 0 else "ECHEC")
	quit()
