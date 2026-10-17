extends Node
## Résistances par école : génération (famille, boss), objets épiques, dégâts d'un sort de feu sur un monstre résistant / faible, réduction d'un héros.
func _ready() -> void:
	var fam := 0
	var with := 0
	var boss := 0
	var boss_res := 0
	for s in 30:
		var cfg := DungeonGenerator.build_config(Data.active(), 3, 13, 11, "normal", [], 1, 700 + s)
		for lv in cfg.levels:
			for m in lv.monsters:
				var icon := str(m.get("icon", "")).trim_prefix("@icon:")
				if m.get("isBoss", false):
					boss += 1
					boss_res += 1 if m.get("resists") is Dictionary else 0
				elif Resist.FAMILY.has(icon):
					fam += 1
					with += 1 if m.get("resists") is Dictionary else 0
	var pct := 100.0 * with / maxf(1.0, fam)
	# objets : épique+ armure / bijou seulement
	var it_ok := true
	for tier in ["common", "rare", "epic", "legendary", "mythic"]:
		for tp in ["armor", "jewelry", "weapon"]:
			var it := {"type": tp, "name": "x", "bonusHp": 10}
			Rarity.apply(it, tier, func(): return randf())
			var has: bool = it.get("resists") is Dictionary
			var want: bool = ["epic", "legendary", "mythic"].has(tier) and tp != "weapon"
			if has != want:
				it_ok = false
	# combat
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var placed := false
	for m in main.level.monsters:
		var stt: Dictionary = lst.get(str(m.id), {})
		if stt.is_empty() or not stt.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(stt.x), int(stt.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				placed = true
				break
		if placed:
			break
	main.ctrl.refresh()
	await get_tree().create_timer(2.0).timeout
	var eng: Dictionary = main.ctrl.combat.engaged()
	var mon: Dictionary = eng.monster
	var st: Dictionary = main.ctrl.combat.lstate().monsters[str(mon.id)]
	var att: Dictionary = main.gs.party[0]
	att["talentCritChance"] = -1000
	mon["resistMagic"] = 0
	mon["resistPhys"] = 0
	var res := {}
	for case in [["none", {}, "fire"], ["res", {"fire": 50}, "fire"], ["weak", {"fire": -50}, "fire"], ["other", {"fire": 50}, "ice"]]:
		mon["resists"] = case[1]
		st["hp"] = 100000.0
		st["maxHp"] = 100000.0
		main.ctrl.combat._hit_monster(att, mon, 100, true, "lance", false, false, {"style": case[2], "id": "t"}, false)
		res[case[0]] = int(round(100000.0 - float(st.hp)))
	var hero := {"classId": "class_warrior", "guardPct": 0, "resistPhys": 0, "resistMagic": 0, "equipment": {}, "statusEffects": []}
	var plain: int = main.ctrl.combat._hero_reduction(hero, 100, false, "")
	var warr: int = main.ctrl.combat._hero_reduction(hero, 100, false, "phys")
	hero["classId"] = "class_mage"
	var mage: int = main.ctrl.combat._hero_reduction(hero, 100, false, "phys")
	var good: bool = fam > 100 and pct > 50.0 and pct < 90.0 and boss == boss_res and it_ok \
		and res.none == 100 and res.res == 50 and res.weak == 150 and res.other == 100 and plain == 100 and warr == 85 and mage == 110
	print("RESIST familles=", fam, " avec=", snappedf(pct, 0.1), "% boss=", boss_res, "/", boss, " objets=", it_ok, " dégâts=", res, " héros=", plain, "/", warr, "/", mage, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
