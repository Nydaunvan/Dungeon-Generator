extends SceneTree
## Capture du menu replié / déployé en jeu. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_menu.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/menu"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var vc = current_scene.layout.view_controls
	print("VC ", vc.visible, " ", vc.get_global_rect(), " children ", vc.get_child_count(), " mod ", vc.modulate)
	Input.warp_mouse(Vector2(300, 400))
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_closed.png")
	current_scene.layout.header._pinned = true
	var e := InputEventMouseMotion.new()
	e.position = Vector2(1270, 40)
	e.global_position = e.position
	Input.parse_input_event(e)
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png(pre + "_open.png")
	quit()
