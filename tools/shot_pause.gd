extends SceneTree
## Capture de la pastille de pause (fenêtre ouverte) et du symbole de pause manuelle. Usage : ... --script res://tools/shot_pause.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/pause"
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for i in 120:
		if not m.ctrl.model_in_combat() and get_nodes_in_group("modal").is_empty():
			break
		if m.ctrl.model_in_combat() and m.ctrl.in_combat():
			m.ctrl.attack()
		await create_timer(0.4).timeout
	await create_timer(1.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.5).timeout
	var offers: Array = load("res://scripts/rules/shop.gd").village_offers(m.gs.cfg, 3)
	load("res://scripts/ui/shop_modal.gd").open(m._modals(), m.gs, offers, true)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_badge.png")
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.8).timeout
	load("res://scripts/ui/pause_overlay.gd").toggle(self)
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(pre + "_overlay.png")
	paused = false
	quit()
