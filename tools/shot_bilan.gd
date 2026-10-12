extends SceneTree
## Capture du bilan de combat détaillé (fenêtre de victoire) : un bot attaque jusqu'à la fin du premier combat.
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_bilan.gd -- /tmp/bilan.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/bilan.png"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var ctrl = m.ctrl
	var t_wait := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < t_wait and not ctrl.model_in_combat():
		await process_frame
	var t_end := Time.get_ticks_msec() + 90000
	var seen := false
	while Time.get_ticks_msec() < t_end:
		for n in get_nodes_in_group("modal"):
			if n is Modal:
				seen = true
		if seen:
			break
		if ctrl.model_in_combat() and not ctrl._busy and float(ctrl.combat.gauges.get("char_" + str(m.gs.active_char_id), 0.0)) >= 100.0:
			ctrl.attack()
		await process_frame
	await create_timer(1.0).timeout
	print("fenêtre vue : ", seen)
	root.get_texture().get_image().save_png(out)
	quit()
