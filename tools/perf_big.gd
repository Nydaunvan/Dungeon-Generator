extends SceneTree
## Profil d'un grand donjon : charge un niveau WxH, relève objets / appels de dessin / sommets / lumières, puis le coût d'un pas (déplacement, pas des monstres).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/perf_big.gd -- 61
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 61
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 1, n, n, "normal", [], 5, 1)
	var t0 := Time.get_ticks_msec()
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(1.0).timeout
	var lv: Dictionary = m.level
	var ms := 0
	for it in lv.monsters: ms += 1
	print("niveau %dx%d : monstres=%d objets=%d" % [m.grid.width, m.grid.height, ms, lv.get("items", []).size()])
	print("noeuds=%d objets=%d draw=%d prims=%d lumières omni=%d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		get_nodes_in_group("torch_light").size()])
	var lights := 0
	var meshes := 0
	var stack: Array = [m.layout.sub_viewport]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Light3D and nd.visible: lights += 1
		if nd is MeshInstance3D: meshes += 1
		stack.append_array(nd.get_children())
	print("lumières visibles=%d MeshInstance3D=%d" % [lights, meshes])
	# coût d'un pas
	var fr := 0
	var t1 := Time.get_ticks_usec()
	for i in 6:
		m._on_command("forward")
		await process_frame
		fr += 1
	print("6 pas + 6 images : %d ms" % ((Time.get_ticks_usec() - t1) / 1000))
	var t2 := Time.get_ticks_usec()
	for i in 20:
		m.wand._tick()
	print("Wanderers._tick x20 : %d ms (%d µs/pas)" % [(Time.get_ticks_usec() - t2) / 1000, (Time.get_ticks_usec() - t2) / 20])
	var t3 := Time.get_ticks_usec()
	for i in 20:
		m.layout.minimap.reveal()
	print("minimap.reveal x20 : %d µs/appel" % ((Time.get_ticks_usec() - t3) / 20))
	var t4 := Time.get_ticks_usec()
	for i in 20:
		m.layout.minimap.mark_visited()
	print("minimap.mark_visited x20 : %d µs/appel" % ((Time.get_ticks_usec() - t4) / 20))
	var t5 := Time.get_ticks_usec()
	for i in 20:
		m.ctrl.refresh()
	print("ctrl.refresh x20 : %d µs/appel" % ((Time.get_ticks_usec() - t5) / 20))
	var t6 := Time.get_ticks_usec()
	for i in 100:
		m.ctrl.combat.in_combat()
	print("combat.in_combat x100 : %d µs/appel" % ((Time.get_ticks_usec() - t6) / 100))
	var t7 := Time.get_ticks_usec()
	for i in 20:
		m.ctrl.changed.emit()
	print("ctrl.changed.emit x20 : %d µs/appel" % ((Time.get_ticks_usec() - t7) / 20))
	for cn in m.ctrl.changed.get_connections():
		var cal: Callable = cn.callable
		var t8 := Time.get_ticks_usec()
		for i in 5:
			cal.call()
		print("  écouteur %s : %d µs" % [cal.get_method(), (Time.get_ticks_usec() - t8) / 5])
	# images : temps de process moyen
	var tp := 0.0
	var tph := 0.0
	var fcount := 0
	for i in 60:
		await process_frame
		tp += Performance.get_monitor(Performance.TIME_PROCESS)
		tph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		fcount += 1
	print("TIME_PROCESS moyen=%.2f ms  fps=%.1f" % [tp / fcount * 1000.0, Performance.get_monitor(Performance.TIME_FPS)])
	quit()
