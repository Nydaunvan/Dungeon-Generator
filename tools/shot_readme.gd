extends SceneTree
## Captures du jeu pour le README : combat (rendu OpenGL, sans les effets Forward+).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_readme.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/readme"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	for i in 400:
		if m.ctrl.model_in_combat():
			break
		m._on_command("forward")
		await create_timer(0.35).timeout
		for mo in get_nodes_in_group("modal"):
			mo.queue_free()
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png(pre + "_combat.png")
	quit(0)
