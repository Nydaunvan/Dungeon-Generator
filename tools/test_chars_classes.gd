extends SceneTree
## Onglets Personnages / Classes : cfg.classTalents complet après construction, normalisation, plafonds, ajout/suppression.
## godot --headless --script res://tools/test_chars_classes.gd
var fails := 0
func ok(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1
func find_all(n: Node, pred: Callable, out: Array = []) -> Array:
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		find_all(c, pred, out)
	return out
func _init() -> void:
	root.size = Vector2i(1280, 900)
	await process_frame
	var data = root.get_node("Data")
	data.admin_unlocked = true
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.0).timeout
	var cfg: Dictionary = data.admin_config()
	# talents partiels (cas qui faisait disparaître les paliers des autres classes)
	cfg["classTalents"] = {"class_warrior": (data.class_talents["class_warrior"] as Array).duplicate(true)}
	adm._select_tab("classes")
	await create_timer(1.0).timeout
	var all_ok := true
	for cls in cfg.classes:
		if not (cfg.classTalents as Dictionary).has(cls.id):
			all_ok = false
	ok(all_ok, "classTalents contient toutes les classes après build de l'onglet Classes (%d)" % (cfg.classTalents as Dictionary).size())
	var tal = load("res://scripts/rules/talents.gd")
	ok(tal.tracks(cfg, "class_mage").size() == 5, "Talents.tracks(mage) = 5 paliers avec la config modifiée")
	ok(tal.tracks(cfg, "class_cleric").size() == 5, "Talents.tracks(clerc) = 5 paliers")
	for cls in cfg.classes:
		ok((cls.evolvesTo as Array).size() == 2 and cls.spellProgression is Array, "normalisation %s" % cls.id)
	# tri stable
	var prog := [{"level": 3, "spellId": "a"}, {"level": 1, "spellId": "b"}, {"level": 3, "spellId": "c"}, {"level": 1, "spellId": "d"}]
	(load("res://scripts/admin/admin_classes.gd") as GDScript).call("_stable_sort", prog)
	ok(str(prog.map(func(p): return p.spellId)) == '["b", "d", "a", "c"]', "tri de progression stable : " + str(prog.map(func(p): return p.spellId)))
	# plafond de sorts autorisés par classe : 7e case -> message, pas d'ajout
	var warrior: Dictionary = data.class_by_id("class_warrior")
	warrior["allowedSpellIds"] = []
	for i in 6:
		(warrior.allowedSpellIds as Array).append(cfg.spells[i].id)
	adm._select_tab("classes")
	await create_timer(0.8).timeout
	var boxes := find_all(adm, func(n): return n is CheckBox and not n.button_pressed and not n.disabled and str(n.text).contains(str(cfg.spells[7].name)))
	ok(boxes.size() > 0, "case du 8e sort trouvée")
	if boxes.size() > 0:
		(boxes[0] as CheckBox).button_pressed = true
		await process_frame
		var msgs := find_all(adm, func(n): return n is Label and str(n.text).begins_with("❌"))
		ok(msgs.size() == 1, "message de plafond visible")
		ok((warrior.allowedSpellIds as Array).size() == 6 and not (boxes[0] as CheckBox).button_pressed, "plafond respecté, case décochée")
	# ajout d'une classe via la fenêtre
	var n0: int = (cfg.classes as Array).size()
	var add_btn := find_all(adm, func(n): return n is Button and str(n.text) == "+ Ajouter une classe")
	ok(add_btn.size() == 1, "bouton + Ajouter une classe")
	(add_btn[0] as Button).pressed.emit()
	await create_timer(0.5).timeout
	var create := find_all(adm, func(n): return n is Button and str(n.text) == "Créer")
	ok(create.size() == 1, "bouton Créer dans la fenêtre")
	(create[0] as Button).pressed.emit()
	await create_timer(1.5).timeout
	ok((cfg.classes as Array).size() == n0 + 1, "classe ajoutée")
	var nc: Dictionary = cfg.classes[n0]
	ok(not nc.has("baseSpeed") and (nc.evolvesTo as Array).size() == 2 and int(nc.evolveLevel) == 5, "nouvelle classe sans baseSpeed")
	ok((cfg.classTalents as Dictionary).has(nc.id), "talents créés pour la nouvelle classe")
	# suppression : confirmation puis retrait
	var trash := find_all(adm, func(n): return n is Button and str(n.text) == "🗑")
	ok(trash.size() > 0, "boutons 🗑")
	# onglet Personnages
	adm._select_tab("chars")
	await create_timer(1.0).timeout
	ok(find_all(adm, func(n): return n is Label and str(n.text) == "APERÇU").size() == 1, "tableau Personnages : en-tête Aperçu")
	data.set_lang("fr")
	print("fails=", fails)
	quit(1 if fails > 0 else 0)
