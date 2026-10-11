extends SceneTree
## Capture du détail des parchemins chez le marchand. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_scroll.gd -- <préfixe>
func _buttons(n: Node, out: Array) -> void:
	if n is Button and (n as Button).size.x > 80 and (n as Button).size.y > 50 and (n as Button).toggle_mode == false and n.is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_buttons(ch, out)

func _tabs(n: Node, out: Array) -> void:
	if n is Button and (n as Button).toggle_mode and n.is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_tabs(ch, out)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/scr"
	root.size = Vector2i(1280, 900)
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
	var want := ["spell_fire1", "spell_heal2", "spell_bard2", "spell_skald4"]
	var list: Array = []
	var seen := {}
	for sp in gs.cfg.spells:
		var md := str(sp.mode)
		if want.has(sp.id) or (not seen.has(md) and ["sleepGroup", "partyUtility", "shieldSingle", "healParty"].has(md)):
			seen[md] = true
			list.append({"name": "Parchemin de " + str(sp.name), "icon": "@icon:misc_scroll", "type": "scroll", "spellId": sp.id})
	var offers: Array = load("res://scripts/rules/shop.gd")._finish(list, "village_merchant_offer", true)
	print("parchemins : ", offers.size())
	load("res://scripts/ui/shop_modal.gd").open(m._modals(), gs, offers, true)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_open.png")
	print("modales : ", get_nodes_in_group("modal").size())
	var tabs: Array = []
	_tabs(root, tabs)
	for t in tabs:
		if (t as Button).text.begins_with("Parchemins") or (t as Button).text.begins_with("Scrolls"):
			(t as Button).pressed.emit()
	await create_timer(0.8).timeout
	var cards: Array = []
	_buttons(root, cards)
	print("cartes : ", cards.size())
	for i in 3:
		var cs: Array = []
		_buttons(root, cs)
		if i >= cs.size():
			break
		(cs[i] as Button).pressed.emit()
		await create_timer(0.8).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [pre, i])
	quit()
