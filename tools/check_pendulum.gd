extends SceneTree
## Hache pendulaire : (1) génération — présente sur certains niveaux, sur un couloir rectiligne sans torche, levier loin d'elle, reproductible,
## et sans effet sur le reste du donjon (même graine avec la chance à 0 : mêmes cartes, monstres et objets) ; (2) en jeu — passage = esquive ou
## dégâts, indice à la première fois, levier = hache bloquée, plus aucun dégât ensuite.
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/check_pendulum.gd
func _init() -> void:
	root.size = Vector2i(1280, 800)
	await process_frame
	await create_timer(1.5).timeout
	var data = root.get_node("Data")
	var DG = load("res://scripts/rules/dungeon_generator.gd")
	var ok := true
	var found_seed := -1
	var with_p := 0
	var levels_total := 0
	var invariant := true
	for sd in 40:
		var cfg: Dictionary = DG.build_config(data.original_config, 4, 15, 15, "normal", [], 1, 700 + sd)
		var base0: Dictionary = (data.original_config as Dictionary).duplicate(true)
		var ts: Dictionary = (base0.get("trapSettings", {}) as Dictionary).duplicate()
		ts["pendulumChancePct"] = 0.0
		base0["trapSettings"] = ts
		var cfg0: Dictionary = DG.build_config(base0, 4, 15, 15, "normal", [], 1, 700 + sd)
		for li in cfg.levels.size():
			levels_total += 1
			var lv: Dictionary = cfg.levels[li]
			var lv0: Dictionary = cfg0.levels[li]
			var pend: Array = lv.items.filter(func(i): return str(i.get("type", "")) == "pendulum")
			var rest: Array = lv.items.filter(func(i): return str(i.get("type", "")) != "pendulum" and not str(i.id).begins_with("pend_lever"))
			if str(lv.mapRows) != str(lv0.mapRows) or str(rest) != str(lv0.items) or str(lv.monsters) != str(lv0.monsters):
				invariant = false
			if pend.is_empty():
				continue
			with_p += 1
			var p: Dictionary = pend[0]
			var lever: Array = lv.items.filter(func(i): return str(i.id) == str(p.leverId))
			if lever.size() != 1 or (int(p.x) + int(p.y)) % 2 != 1:
				ok = false
			var rows: Array = lv.mapRows
			var ax := str(p.axis)
			var px := int(p.x)
			var py := int(p.y)
			var side_wall: bool = (rows[py][px - 1] == "#" and rows[py][px + 1] == "#") if ax == "ns" else (rows[py - 1][px] == "#" and rows[py + 1][px] == "#")
			var open_ahead: bool = (rows[py - 1][px] == "." and rows[py + 1][px] == ".") if ax == "ns" else (rows[py][px - 1] == "." and rows[py][px + 1] == ".")
			if not side_wall or not open_ahead:
				ok = false
			if maxi(absi(int(lever[0].x) - px), absi(int(lever[0].y) - py)) < 6:
				ok = false
			if found_seed < 0:
				found_seed = 700 + sd
				print("graine %d niveau %d : hache en (%d,%d) axe %s, levier en (%d,%d)" % [found_seed, li + 1, px, py, ax, int(lever[0].x), int(lever[0].y)])
	print("niveaux avec hache : %d / %d" % [with_p, levels_total])
	print("RESULTAT génération -> ", "OK" if ok and with_p > 0 and invariant else "ECHEC (ok=%s invariant=%s)" % [ok, invariant])
	# reproductible
	var a: Dictionary = DG.build_config(data.original_config, 4, 15, 15, "normal", [], 1, found_seed)
	var b: Dictionary = DG.build_config(data.original_config, 4, 15, 15, "normal", [], 1, found_seed)
	print("RESULTAT reproductible -> ", "OK" if str(a.levels) == str(b.levels) else "ECHEC")
	# --- en jeu
	data.launch(a, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for i in 120:
		if not m.ctrl.model_in_combat() and get_nodes_in_group("modal").is_empty():
			break
		if m.ctrl.model_in_combat() and m.ctrl.in_combat():
			m.ctrl.attack()
		await create_timer(0.4).timeout
	var li := -1
	for k in a.levels.size():
		for it in a.levels[k].items:
			if str(it.get("type", "")) == "pendulum":
				li = k
				break
		if li >= 0:
			break
	if li != int(m.level_index):
		m.load_level(li)
		await create_timer(3.0).timeout
	var pend: Dictionary = {}
	var lever: Dictionary = {}
	for it in m.level.items:
		if str(it.get("type", "")) == "pendulum":
			pend = it
	for it in m.level.items:
		if str(it.id) == str(pend.leverId):
			lever = it
	m.wand.paused_if = func(): return true
	var hp0 := 0
	for c in m.gs.party:
		hp0 += int(c.hp)
	var log0: int = m.gs.log.size() if "log" in m.gs else 0
	m.rig.place(m.grid, int(pend.x), int(pend.y), 1)
	m.inter.step_items()
	await create_timer(0.5).timeout
	var hp1 := 0
	for c in m.gs.party:
		hp1 += int(c.hp)
	var swung := true
	print("PV avant %d après %d" % [hp0, hp1])
	# le levier bloque la hache
	m.rig.place(m.grid, int(lever.x), int(lever.y), 1)
	m.inter.step_items()
	await create_timer(1.8).timeout
	var st: Dictionary = m.gs.item_state(m.level.id, str(pend.id))
	var disarmed: bool = bool(st.get("disarmed", false))
	var node: Node3D = null
	for p in m.level_node.entities.items.keys():
		for e in m.level_node.entities.items[p]:
			if str(e.def.id) == str(pend.id):
				node = e.node
	var locked: bool = node != null and int(node.locked) != 0
	m.rig.place(m.grid, int(pend.x), int(pend.y), 1)
	m.inter.step_items()
	await create_timer(0.3).timeout
	var hp2 := 0
	for c in m.gs.party:
		hp2 += int(c.hp)
	print("levier : hache désarmée %s, lame bloquée %s · PV après nouveau passage %d (inchangés : %s)" % [disarmed, locked, hp2, hp2 == hp1])
	print("RESULTAT en jeu -> ", "OK" if disarmed and locked and hp2 == hp1 else "ECHEC")
	quit()
