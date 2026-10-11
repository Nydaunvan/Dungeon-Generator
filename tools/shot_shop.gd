extends SceneTree
## Capture du marchand : sélectionne un objet équipable et survole une ligne de « Effet sur… ». Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_shop.gd -- <sortie.png> [hover]
func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for ch in n.get_children():
		_labels(ch, out)

func _buttons(n: Node, out: Array) -> void:
	if n is Button and (n as Button).custom_minimum_size.x > 80 and (n as Button).custom_minimum_size.y > 50 and n.is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_buttons(ch, out)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	var gs = m.gs
	for i in 120:
		if not m.ctrl.model_in_combat() and get_nodes_in_group("modal").is_empty():
			break
		if m.ctrl.model_in_combat() and m.ctrl.in_combat():
			m.ctrl.attack()
		await create_timer(0.4).timeout
	await create_timer(1.5).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	gs.gold = 999
	var offers: Array = load("res://scripts/rules/shop.gd").village_offers(gs.cfg, 3)
	load("res://scripts/ui/shop_modal.gd").open(m._modals(), gs, offers, true)
	await create_timer(1.0).timeout
	var target: Label = null
	var cards: Array = []
	_buttons(root, cards)
	print("cartes : ", cards.size())
	for b in cards:
		(b as Button).pressed.emit()
		await create_timer(0.5).timeout
		var ls: Array = []
		_labels(root, ls)
		for l in ls:
			if (l as Label).text.begins_with("Effet sur") and l.is_visible_in_tree():
				target = l
		if target != null:
			break
	print("section trouvée : ", target != null)
	if target != null and a.size() > 1:
		var ls2: Array = []
		_labels(target.get_parent(), ls2)
		var row: Label = null
		for l in ls2:
			if (l as Label).text == "Force" or (l as Label).text.begins_with("Vitesse") or (l as Label).text == "PV":
				row = l
		if row == null:
			for l in ls2:
				if l != target and (l as Label).text.length() > 1 and not (l as Label).text.begins_with("Surv"):
					row = l
					break
		if row != null:
			var p: Vector2 = root.get_final_transform() * row.get_global_rect().get_center()
			for i in 2:
				var ev := InputEventMouseMotion.new()
				ev.position = p + Vector2(i, 0)
				ev.global_position = ev.position
				Input.parse_input_event(ev)
				await create_timer(0.4).timeout
			await create_timer(0.8).timeout
			print("fenêtre : ", load("res://scripts/ui/stat_tip.gd")._inst != null and load("res://scripts/ui/stat_tip.gd")._inst.visible)
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/shop.png")
	quit()
