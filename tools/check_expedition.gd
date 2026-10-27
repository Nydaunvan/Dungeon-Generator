extends Node
## Écran « Préparer l'expédition » : (1) le groupe choisi (classes, portraits) se retrouve dans le donjon généré, 2 héros d'une même classe au maximum ;
## (2) statistiques du Barde : dextérité > intelligence > constitution > force ; (3) sans choix, génération graînée inchangée (mêmes niveaux) ;
## (4) l'écran s'ouvre, borne ses réglages (niveaux 1-8, largeur 13-60, hauteur 11-60) et fabrique les `picks` attendus.
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_expedition.tscn
func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var ok := true
	var base: Dictionary = Data.original_config
	var picks := [{"classId": "class_bard", "portrait": 2}, {"classId": "class_bard", "portrait": 0}, {"classId": "class_mage", "portrait": 5}, {"classId": "class_druid", "portrait": -1}]
	var cfg: Dictionary = DungeonGenerator.build_config(base, 2, 15, 15, "normal", [], 1, -1, picks)
	var party: Array = cfg.party
	var want := ["class_bard", "class_bard", "class_mage", "class_druid"]
	var got: Array = party.map(func(h): return str(h.classId))
	print("groupe : ", got, " portraits : ", party.map(func(h): return str(h.portrait).get_file()))
	if got != want:
		ok = false
		print("ECHEC classes")
	if str(party[0].portrait) != "res://assets/portraits/barde_2.webp" or str(party[1].portrait) != "res://assets/portraits/barde_0.webp" or str(party[2].portrait) != "res://assets/portraits/mage_5.webp":
		ok = false
		print("ECHEC portraits")
	var too_many := DungeonGenerator.build_config(base, 1, 9, 9, "normal", [], 1, -1, [{"classId": "class_mage", "portrait": -1}, {"classId": "class_mage", "portrait": -1}, {"classId": "class_mage", "portrait": -1}])
	var mages := (too_many.party as Array).filter(func(h): return str(h.classId) == "class_mage").size()
	print("3 mages demandés -> ", mages, " mage(s), ", (too_many.party as Array).size(), " héros")
	if mages > 2:
		ok = false
	var st: Array = DungeonGenerator.ARCHETYPE_STATS["Barde"]
	print("Barde [FOR, DEX, CON, INT] = ", st)
	if not (st[1] > st[3] and st[3] > st[2] and st[2] > st[0]):
		ok = false
		print("ECHEC ordre des stats du Barde")
	for h in party:
		if str(h.classId) == "class_bard":
			print("  barde généré : FOR ", h.force, " DEX ", h.dex, " CON ", h.con, " INT ", h.int)
	var a: Dictionary = DungeonGenerator.build_config(base, 3, 15, 15, "normal", [], 1, 4242)
	var b: Dictionary = DungeonGenerator.build_config(base, 3, 15, 15, "normal", [], 1, 4242)
	var same := str(a.levels) == str(b.levels) and str((a.party as Array).map(func(h): return h.classId)) == str((b.party as Array).map(func(h): return h.classId))
	print("graine reproductible : ", same)
	if not same:
		ok = false
	# l'écran
	var layer := CanvasLayer.new()      # comme dans le jeu : l'hôte des fenêtres est un CanvasLayer (pas un Control)
	add_child(layer)
	ExpeditionScreen.open(layer, func(_c): pass, {"levels": 99, "width": 3, "height": 500, "diff": "hard"})
	await get_tree().create_timer(0.5).timeout
	var scr: ExpeditionScreen = null
	for m in get_tree().get_nodes_in_group("modal"):
		scr = m.get_meta("screen")
	print("réglages bornés : niveaux ", scr._levels, " largeur ", scr._width, " hauteur ", scr._height)
	if scr._levels != 8 or scr._width != 13 or scr._height != 60:
		ok = false
		print("ECHEC bornes")
	var s1: HSlider = scr._sliders["width"]
	var s2: HSlider = scr._sliders["height"]
	var s3: HSlider = scr._sliders["levels"]
	print("curseurs : largeur ", s1.min_value, "-", s1.max_value, " hauteur ", s2.min_value, "-", s2.max_value, " niveaux ", s3.min_value, "-", s3.max_value)
	if s1.max_value != 60 or s2.max_value != 60 or s1.min_value != 13 or s2.min_value != 11 or s3.max_value != 8:
		ok = false
	scr._slots[0].c = 0
	scr._slots[1].c = 0
	print("assigner une 3e classe identique : ", scr._assign(2, 0))
	if scr._assign(2, 0):
		ok = false
	# la description de la difficulté ne dépasse jamais deux lignes (FR et EN)
	for lang in ["fr", "en"]:
		TranslationServer.set_locale(lang)
		for d in GeneratorDialog.DIFFS:
			scr._diff = str(d[0])
			scr._refresh_dungeon()
			await get_tree().process_frame
			await get_tree().process_frame
			var lc: int = scr._blurb.get_line_count()
			print("description ", lang, " ", d[0], " : ", lc, " ligne(s) (", scr._blurb.text.length(), " car.)")
			if lc > 2:
				ok = false
				print("ECHEC description trop longue : ", d[0])
	# « Générer et jouer » : confirmation d'abord ; « Retour au menu » laisse l'écran ouvert, « Oui » lance la génération
	var launched := [false]
	var before := get_tree().get_nodes_in_group("modal").size()
	scr._on_launch = func(_c): launched[0] = true
	scr._confirm_launch()
	await get_tree().process_frame
	var after := get_tree().get_nodes_in_group("modal").size()
	print("confirmation ouverte : ", after == before + 1, " (modales ", before, " -> ", after, ")")
	if after != before + 1 or launched[0]:
		ok = false
		print("ECHEC confirmation")
	var conf: Modal = null
	for m in get_tree().get_nodes_in_group("modal"):
		if m != scr._modal:
			conf = m
	var btns: Array = conf.find_children("*", "Button", true, false)
	print("boutons de la confirmation : ", btns.map(func(b): return b.text))
	btns[1].pressed.emit()          # « Retour au menu »
	await get_tree().create_timer(0.6).timeout
	print("après retour : écran toujours ouvert = ", is_instance_valid(scr._modal) and not scr._modal.is_queued_for_deletion(), ", lancé = ", launched[0])
	if launched[0] or not is_instance_valid(scr._modal) or scr._modal.is_queued_for_deletion():
		ok = false
		print("ECHEC retour au menu")
	scr._confirm_launch()
	await get_tree().process_frame
	for m in get_tree().get_nodes_in_group("modal"):
		if m != scr._modal and not m.is_queued_for_deletion():
			(m.find_children("*", "Button", true, false)[0] as Button).pressed.emit()          # « Oui »
	for i in 600:
		await get_tree().process_frame
		if launched[0]:
			break
	print("après « Oui » : expédition lancée = ", launched[0])
	if not launched[0]:
		ok = false
		print("ECHEC lancement après confirmation")
	# Annuler / croix / Échap : « retour » appelé ; lancer : jamais
	var backs := [0]
	ExpeditionScreen.open(layer, func(_c): pass, {}, func(): backs[0] += 1)
	await get_tree().create_timer(0.4).timeout
	var sc2: ExpeditionScreen = null
	for m in get_tree().get_nodes_in_group("modal"):
		if not m.is_queued_for_deletion() and m.has_meta("screen"):
			sc2 = m.get_meta("screen")
	for t in ["Annuler|Cancel", "croix"]:
		var btn: Button = null
		for bb in sc2._modal.find_children("*", "Button", true, false):
			if bb.text == "Annuler" or bb.text == "Cancel":
				btn = bb
		if btn != null and t != "croix":
			btn.pressed.emit()
		else:
			sc2._modal.close()
		await get_tree().create_timer(0.3).timeout
		print("retour après ", t, " : ", backs[0])
		if t == "croix":
			break
		ExpeditionScreen.open(layer, func(_c): pass, {}, func(): backs[0] += 1)
		await get_tree().create_timer(0.4).timeout
		for m in get_tree().get_nodes_in_group("modal"):
			if not m.is_queued_for_deletion() and m.has_meta("screen"):
				sc2 = m.get_meta("screen")
	if backs[0] != 2:
		ok = false
		print("ECHEC retour : attendu 2, obtenu ", backs[0])
	ExpeditionScreen.open(layer, func(_c): pass, {}, func(): backs[0] += 100)
	await get_tree().create_timer(0.4).timeout
	for m in get_tree().get_nodes_in_group("modal"):
		if not m.is_queued_for_deletion() and m.has_meta("screen"):
			sc2 = m.get_meta("screen")
	sc2._launch()
	await get_tree().create_timer(0.5).timeout
	print("retour après lancement (doit rester 2) : ", backs[0])
	if backs[0] != 2:
		ok = false
		print("ECHEC : le lancement ne doit pas déclencher le retour")
	print("RESULTAT expédition -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
