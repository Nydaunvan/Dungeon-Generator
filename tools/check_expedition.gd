extends Node
## Écran « Préparer l'expédition » : (1) le groupe choisi (classes, portraits) se retrouve dans le donjon généré, 2 héros d'une même classe au maximum ;
## (2) statistiques du Barde : dextérité > intelligence > constitution > force ; (3) sans choix, génération graînée inchangée (mêmes niveaux) ;
## (4) l'écran s'ouvre, borne ses réglages (niveaux 1-8, taille 7-60) et fabrique les `picks` attendus.
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
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	ExpeditionScreen.open(layer, func(_c): pass, {"levels": 99, "width": 3, "height": 500, "diff": "hard"})
	await get_tree().create_timer(0.5).timeout
	var scr: ExpeditionScreen = null
	for m in get_tree().get_nodes_in_group("modal"):
		scr = m.get_meta("screen")
	print("réglages bornés : niveaux ", scr._levels, " largeur ", scr._width, " hauteur ", scr._height)
	if scr._levels != 8 or scr._width != 7 or scr._height != 60:
		ok = false
		print("ECHEC bornes")
	var s1: HSlider = scr._sliders["width"]
	var s2: HSlider = scr._sliders["height"]
	var s3: HSlider = scr._sliders["levels"]
	print("curseurs : largeur ", s1.min_value, "-", s1.max_value, " hauteur ", s2.min_value, "-", s2.max_value, " niveaux ", s3.min_value, "-", s3.max_value)
	if s1.max_value != 60 or s2.max_value != 60 or s1.min_value != 7 or s3.max_value != 8:
		ok = false
	scr._slots[0].c = 0
	scr._slots[1].c = 0
	print("assigner une 3e classe identique : ", scr._assign(2, 0))
	if scr._assign(2, 0):
		ok = false
	print("RESULTAT expédition -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
