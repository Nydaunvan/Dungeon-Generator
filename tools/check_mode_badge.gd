extends SceneTree
## Pastille de mode en jeu (donjon aléatoire) : partie libre / classée / défi de la semaine / hardcore du mois.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_mode_badge.gd -- <free|difficulty|weekly|hardcore_month>
func _init() -> void:
	var kind := str(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else "free"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	if kind != "free":
		cfg["rankedKind"] = kind
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	print("BADGE ", kind, " -> ", current_scene.layout.type_badge.text)
	quit()
