extends SceneTree
## Capture de la vue 3D d'un niveau (même graine) pour comparer deux versions du constructeur de niveau. Usage : … --script res://tools/shot_level.gd -- 31 /tmp/lvl.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 31
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 1, n, n, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(9.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var guard := 0
	while m.wand.level.is_empty() and guard < 600:
		await create_timer(0.1).timeout
		guard += 1
	m.wand.paused_if = func(): return true
	m.layout.sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await create_timer(2.0).timeout
	root.get_viewport().get_texture().get_image().save_png(a[1] if a.size() > 1 else "/tmp/lvl.png")
	var meshes := 0
	var stack: Array = [m.level_node]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is MeshInstance3D and str(nd.name).begins_with("LevelMesh"): meshes += 1
		stack.append_array(nd.get_children())
	print("blocs de décor : ", meshes, "  prims=", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), " draw=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	quit()
