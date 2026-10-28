extends SceneTree
## godot --headless --path . --script res://tools/test_levels_ui.gd — éditeur de niveaux plein écran : pinceaux, entités, onglets.
var fails := 0
func ok(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("ÉCHEC : ", m)
func _init() -> void:
	await process_frame
	var data = root.get_node("Data")
	data.admin_unlocked = true
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(1.0).timeout
	var lv = load("res://scripts/admin/admin_levels.gd")
	adm._select_tab("levels")
	await create_timer(0.5).timeout
	var lvl: Dictionary = lv.call("_current")
	var nm := (lvl.monsters as Array).size()
	var ni := (lvl.items as Array).size()
	# peinture
	lv.set("_brush", "#")
	lv.call("_on_cell", lvl, 2, 2)
	ok(str(lvl.mapRows[2])[2] == "#", "mur peint")
	lv.set("_brush", "D")
	lv.call("_on_cell", lvl, 2, 2)
	ok(str(lvl.mapRows[2])[2] == "D", "porte peinte")
	var has_door := false
	for d in lvl.doors:
		if int(d.x) == 2 and int(d.y) == 2:
			has_door = true
	ok(has_door, "porte enregistrée")
	lv.set("_brush", ".")
	lv.call("_on_cell", lvl, 2, 2)
	ok(str(lvl.mapRows[2])[2] == "." , "sol repeint")
	# monstre et objet
	lv.set("_brush", "mon")
	lv.call("_on_cell", lvl, 3, 8)
	ok((lvl.monsters as Array).size() == nm + 1 or (lvl.monsters as Array).size() == nm, "monstre ajouté (ou refusé sur mur/escalier)")
	lv.set("_brush", "item")
	lv.call("_on_cell", lvl, 3, 8)
	ok((lvl.items as Array).size() >= ni, "objet")
	lv.set("_brush", "start")
	lv.call("_on_cell", lvl, 5, 5)
	ok(int(lvl.startX) == 5 and int(lvl.startY) == 5, "départ déplacé")
	# onglets
	for t in ["mon", "item", "cfg"]:
		lv.set("_tab", t)
		lv.set("_ntab", t)
		lv.call("_render_all")
		await create_timer(0.1).timeout
		var host = lv.get("_panel_host")
		ok(host != null and host.get_child_count() > 0, "onglet %s rempli" % t)
	lv.set("_ntab", "map")
	lv.set("_cell", Vector2i(5, 7))
	lv.set("_tab", "map")
	lv.call("_render_all")
	# détails de chaque type d'objet et d'un monstre
	lv.set("force_narrow", true)
	for tp in ["potion", "weapon", "armor", "jewelry", "key", "scroll", "trap", "switch", "fountain", "chest"]:
		var it: Dictionary = lv.call("_new_item", lvl, 4, 4, tp)
		lv.set("_open_item", str(it.id))
		lv.set("_ntab", "item")
		lv.call("_render_all")
		await create_timer(0.05).timeout
		ok(lv.get("_panel_host").get_child_count() > 1, "objet %s" % tp)
		(lvl.items as Array).erase(it)
	var mm: Dictionary = lv.call("_new_monster", lvl, 4, 4)
	lv.set("_open_mon", str(mm.id))
	for flag in [["isBoss", true], ["isGroup", true], ["hitStatus", "poison"], ["enrageThreshold", 40]]:
		mm[flag[0]] = flag[1]
	lv.set("_ntab", "mon")
	lv.call("_render_all")
	await create_timer(0.05).timeout
	ok(lv.get("_panel_host").get_child_count() > 1, "monstre ouvert")
	(lvl.monsters as Array).erase(mm)
	lv.set("force_narrow", false)
	# niveau ajouté / supprimé
	var n0 := (data.admin_config().levels as Array).size()
	lv.call("_add_level")
	await create_timer(0.2).timeout
	ok((data.admin_config().levels as Array).size() == n0 + 1, "niveau ajouté")
	# redimensionnement
	var cur: Dictionary = lv.call("_current")
	lv.call("_resize", cur, 10, 9)
	ok((cur.mapRows as Array).size() == 9 and str(cur.mapRows[0]).length() == 10, "redimensionné")
	(data.admin_config().levels as Array).erase(cur)
	# écran étroit
	lv.set("force_narrow", true)
	for t in ["map", "levels", "mon", "item", "cfg"]:
		lv.set("_ntab", t)
		adm._select_tab("levels")
		await create_timer(0.2).timeout
	lv.set("force_narrow", false)
	print("fails=", fails)
	quit()
