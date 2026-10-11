extends SceneTree
## Ouvre le panneau d'équipement et survole la ligne « PV » avec une vraie souris simulée ; capture la fenêtre de survol.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "/tmp/dock_tip.png"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for i in 120:   # combat de départ éventuel : on le termine
		if not m.ctrl.model_in_combat() and get_nodes_in_group("modal").is_empty():
			break
		if m.ctrl.model_in_combat() and m.ctrl.in_combat():
			m.ctrl.attack()
		await create_timer(0.4).timeout
	await create_timer(1.5).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	m.dock.open_for(str(m.gs.party[0].id))
	await create_timer(1.0).timeout
	await create_timer(1.5).timeout
	var found: Control = null
	var stack: Array = [m.dock]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text.begins_with("PV") and n.get_parent() is HBoxContainer and n.is_visible_in_tree():
			found = n.get_parent()
		for ch in n.get_children():
			stack.append(ch)
	print("ligne PV trouvée : ", found != null)
	if found != null:
		var p: Vector2 = root.get_final_transform() * found.get_global_rect().get_center()
		var ev := InputEventMouseMotion.new()
		ev.position = p
		ev.global_position = p
		Input.parse_input_event(ev)
		root.warp_mouse(p) if false else null
		await create_timer(0.2).timeout
		ev = InputEventMouseMotion.new()
		ev.position = p + Vector2(2, 0)
		ev.global_position = p + Vector2(2, 0)
		Input.parse_input_event(ev)
		await create_timer(0.8).timeout
		var ST = load("res://scripts/ui/stat_tip.gd")
		print("fenêtre visible : ", ST._inst != null and ST._inst.visible)
	root.get_texture().get_image().save_png(out)
	quit()
