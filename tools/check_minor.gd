extends SceneTree
## Petites corrections : raccourcis de sorts en exploration, fenêtre d'évolution immédiate avec icônes, classe mise à jour sur la carte du personnage.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_minor.gd
var fails := 0
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func key(code: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = p
		Input.parse_input_event(e)

func find_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for ch in n.get_children():
		find_buttons(ch, out)

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var gs = m.gs
	var ctrl = m.ctrl
	for i in 120:   # un piège ou un combat de départ peut encore se jouer : on le termine (attaque) puis on attend le calme
		if not ctrl.model_in_combat() and get_nodes_in_group("modal").is_empty():
			break
		if ctrl.model_in_combat() and ctrl.in_combat():
			ctrl.attack()
		await create_timer(0.4).timeout
	await create_timer(1.5).timeout
	for mo in get_nodes_in_group("modal"):   # butin / montée de niveau d'un combat de départ : on referme
		mo.queue_free()
	gs.choice_queue.clear()
	await create_timer(0.5).timeout
	check("partie chargée hors combat", gs != null and not ctrl.in_combat())
	# 1. raccourci de sort hors combat : la touche 2 lance le premier sort (ici un sort sur allié → attend la cible)
	var c: Dictionary = gs.party[0]
	for h in gs.party:
		h["hp"] = h["maxHp"]
	gs.active_char_id = str(c.id)
	c["spellsKnown"] = ["spell_bard1"]
	ctrl.pending_spell = ""
	key(KEY_2)
	await create_timer(0.4).timeout
	check("touche 2 hors combat : sort lancé (cible demandée)", ctrl.pending_spell == "spell_bard1")
	ctrl.pending_spell = ""
	# 2. évolution : la fenêtre apparaît d'elle-même, avec les icônes des classes
	var w: Dictionary = {}
	for h in gs.party:
		if str(h.classId) == "class_warrior":
			w = h
	if w.is_empty():
		w = gs.party[0]
		w["classId"] = "class_warrior"
		w["icon"] = "@icon:misc_shield"
	w["_evolutionPending"] = true
	gs.choice_queue.append({"kind": "evolve", "char_id": str(w.id), "level": int(w.level)})
	await create_timer(1.2).timeout
	var modals := get_nodes_in_group("modal")
	check("fenêtre d'évolution ouverte sans action du joueur", not modals.is_empty())
	var btns: Array = []
	for mo in modals:
		find_buttons(mo, btns)
	var with_icon := 0
	for b in btns:
		if (b as Button).icon != null:
			with_icon += 1
		check("aucun texte « @icon » dans les boutons", not (b as Button).text.contains("@icon"))
	check("deux classes d'évolution avec icône (%d)" % with_icon, with_icon == 2)
	# choix de la première évolution : la carte du personnage suit
	for b in btns:
		if (b as Button).icon != null:
			(b as Button).pressed.emit()
			break
	await create_timer(1.0).timeout
	var cls = load("res://scripts/rules/characters.gd").class_def(gs.cfg, str(w.classId))
	check("classe évoluée (%s)" % str(w.classId), str(cls.get("evolvesFrom", "")) == "Guerrier")
	var hud = m.layout.hud
	if hud != null:
		hud.refresh()
		var card = hud._cards[str(w.id)].card
		check("carte du personnage : classe « %s »" % card.cls_lbl.text, card.cls_lbl.text == str(cls.name))
	else:
		print("(party_hud introuvable dans layout)")
	# infobulles de statistiques : règle + calcul + sources, pour chaque statistique
	var eqc: Dictionary = gs.party[1]
	eqc["equipment"]["weapon"] = {"name": "Épée de test", "type": "weapon", "slot": "weapon", "bonusForce": 3, "bonusAtkMin": 1}
	load("res://scripts/rules/characters.gd").recompute(eqc, gs.cfg)
	var SE = load("res://scripts/ui/stat_explain.gd")
	for k in SE.ALL + ["hp", "stamina"]:
		var tx: String = SE.text(eqc, gs.cfg, k)
		check("infobulle « %s » non vide" % k, tx.length() > 40)
		check("infobulle « %s » sans clé brute" % k, not tx.contains("ui.") and not tx.contains("%d"))
	check("infobulle Force cite l'objet équipé", SE.text(eqc, gs.cfg, "force").contains("Épée de test"))
	check("infobulle Attaque cite l'objet équipé", SE.text(eqc, gs.cfg, "atk").contains("Épée de test"))
	print("check_minor : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
