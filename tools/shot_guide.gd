extends SceneTree
## Capture d'un sujet du guide. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_guide.gd -- <id sujet> <sortie.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	load("res://scripts/ui/guide_book.gd").open(m._modals(), a[0] if a.size() > 0 else "stats")
	await create_timer(1.5).timeout
	var pages := int(a[2]) if a.size() > 2 else 0
	for i in pages:   # tourne les pages
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Button and (n as Button).text.begins_with("Suivante") and n.is_visible_in_tree():
				(n as Button).pressed.emit()
			for ch in n.get_children():
				stack.append(ch)
		await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(a[1] if a.size() > 1 else "/tmp/guide.png")
	quit()
