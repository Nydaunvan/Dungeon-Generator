extends SceneTree
## Partie classée factice : minuteur, refus de sauvegarde, fenêtre « Quitter ». Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_ranked_timer.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/rt"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 1, 7)
	cfg["runSeed"] = "graine-test"
	cfg["runId"] = "00000000-0000-0000-0000-000000000001"
	cfg["rankedKind"] = "difficulty"
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var m = current_scene
	print("RANKED=", load("res://scripts/rules/run_log.gd").ranked(), " timer visible=", m.layout.ranked_timer.visible, " text=", m.layout.ranked_timer.text)
	m._on_menu("Slots")
	await create_timer(0.5).timeout
	print("modals after Slots=", get_nodes_in_group("modal").size())
	m._ranked_t0_ms -= (7200 - 500) * 1000; m._ranked_warned = 0
	m.show_message("test")
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_timer.png")
	m._leave_game()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(pre + "_leave.png")
	quit()
