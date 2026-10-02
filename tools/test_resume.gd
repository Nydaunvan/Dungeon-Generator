extends SceneTree
## Reprise de partie depuis l'administration : godot --headless --script res://tools/test_resume.gd
## Ajoute un monstre, un objet et un marchand à la configuration suspendue, déplace un monstre, réduit un groupe, reprend la partie
## et vérifie que la partie reflète les changements, sans erreur. Contrôle aussi que resume_game.config EST gs.cfg.
var fails := 0
func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7)
	data.launch(cfg, "random")
	await create_timer(1.5).timeout
	var m = current_scene
	# suspension comme l'entrée « Admin » du menu
	data.resume_game = m.snapshot()
	check(is_same(data.resume_game.config, m.gs.cfg), "resume_game.config est le MÊME Dictionary que gs.cfg")
	check(data.admin_has_run(), "admin_has_run()")
	check(is_same(data.admin_config(), data.resume_game.config), "admin_config() = config suspendue")
	var marker: Dictionary = data.admin_party_marker()
	check(marker.has("level_id"), "admin_party_marker() : %s" % str(marker))
	var acfg: Dictionary = data.admin_config()
	var lvl: Dictionary = acfg.levels[0]
	# état déjà créé pour ce niveau (le groupe y a joué)
	var lid := str(lvl.id)
	check(m.gs.level_states.has(lid), "niveau 0 déjà visité")
	# 1. nouveau monstre
	var occupied := {}
	for mo in lvl.monsters: occupied["%d,%d" % [int(mo.x), int(mo.y)]] = true
	for it in lvl.items: occupied["%d,%d" % [int(it.x), int(it.y)]] = true
	occupied["%d,%d" % [int(lvl.startX), int(lvl.startY)]] = true
	var free: Array = []
	for y in lvl.mapRows.size():
		for x in (lvl.mapRows[y] as String).length():
			if lvl.mapRows[y][x] == "." and not occupied.has("%d,%d" % [x, y]):
				free.append(Vector2i(x, y))
	var nm: Dictionary = (lvl.monsters[0] as Dictionary).duplicate(true)
	nm["id"] = "test_new_monster"
	nm["x"] = free[0].x
	nm["y"] = free[0].y
	nm["isGroup"] = false
	lvl.monsters.append(nm)
	# 2. nouvel objet
	var ni: Dictionary = (lvl.items[0] as Dictionary).duplicate(true)
	ni["id"] = "test_new_item"
	ni["x"] = free[1].x
	ni["y"] = free[1].y
	lvl.items.append(ni)
	# 3. marchand
	lvl["travelingMerchant"] = {"x": free[2].x, "y": free[2].y, "patrolRadius": 5}
	# 4. monstre déplacé
	var moved: Dictionary = lvl.monsters[0]
	moved["x"] = free[3].x
	moved["y"] = free[3].y
	# 5. groupe réduit (ou créé puis réduit)
	var grp: Dictionary = {}
	for mo in lvl.monsters:
		if bool(mo.get("isGroup", false)):
			grp = mo
	if grp.is_empty():
		grp = lvl.monsters[1] if lvl.monsters.size() > 2 else lvl.monsters[0]
		grp["isGroup"] = true
		grp["groupSize"] = 3
		m.gs.level_state(lvl).monsters[str(grp.id)] = m.gs.monster_state(grp)
	grp["groupSize"] = 2
	print("groupe: ", grp.id, " taille voulue 2")
	# reprise
	data.resume_from_admin()
	var psv: Dictionary = data.pending_save.duplicate(true)   # état restauré, avant toute errance des monstres
	await create_timer(1.5).timeout
	var m2 = current_scene
	check(m2 != m and m2.gs != null, "scène de jeu rechargée")
	var gs = m2.gs
	var ls: Dictionary = gs.level_states.get(lid, {})
	check(ls.get("monsters", {}).has("test_new_monster"), "monstre ajouté présent")
	check(ls.get("items_state", {}).has("test_new_item"), "objet ajouté présent")
	check(ls.get("merchant") is Dictionary, "marchand ajouté présent (la patrouille peut l'avoir déplacé)")
	var ms: Dictionary = psv.level_states[lid].monsters[str(moved.id)]
	check(int(ms.x) == free[3].x and int(ms.y) == free[3].y, "monstre déplacé suivi")
	var gst: Dictionary = ls.monsters[str(grp.id)]
	check((gst.get("members", []) as Array).size() == 2, "groupe réduit à 2")
	check(is_same(gs.cfg, data.play_config), "gs.cfg = play_config après reprise")
	# aller-retour supplémentaire
	data.resume_game = m2.snapshot()
	data.resume_from_admin()
	await create_timer(1.0).timeout
	check(current_scene.gs.level_states.has(lid), "second aller-retour sans perte")
	print("ÉCHECS: %d" % fails)
	quit()
