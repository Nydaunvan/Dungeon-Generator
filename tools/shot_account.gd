extends SceneTree
## Capture de la fenêtre Compte (connecté / connexion). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_account.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/acc"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var AM = load("res://scripts/ui/account_modal.gd")
	for mode in ["account", "login"]:
		var am = AM.new()
		am._modal = load("res://scripts/ui/modal.gd").open(current_scene._modals(), "Compte en ligne", 440.0)
		am._mode = mode
		am._build()
		await create_timer(1.0).timeout
		root.get_texture().get_image().save_png("%s_%s.png" % [pre, mode])
		am._modal.close()
		await create_timer(0.6).timeout
	quit()
