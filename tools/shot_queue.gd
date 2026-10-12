extends SceneTree
## Capture de la frise d'initiative en combat (rang + vitesse sur chaque pastille).
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_queue.gd -- /tmp/queue.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/queue.png"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var t_end := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < t_end and not m.ctrl.in_combat():
		await process_frame
	await create_timer(2.0).timeout
	print("en combat : ", m.ctrl.in_combat(), " ordre : ", " ".join(m.ctrl.combat.round_order()))
	root.get_texture().get_image().save_png(out)
	quit()
