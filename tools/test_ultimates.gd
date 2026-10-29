extends SceneTree
## Ultimes des classes évoluées : jauge, déblocage, effets des 14 techniques.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/test_ultimates.gd -- out=/tmp/x
var fails := 0
var Chars: GDScript          # chargé à l'exécution : characters.gd cite l'autoload Sound, absent à la compilation d'un script d'outil
func ok(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1600, 900)
	await process_frame
	Chars = load("res://scripts/rules/characters.gd")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	var out := str(args.get("out", "/tmp/ult"))
	main.wand.paused_if = func(): return true
	var cfg: Dictionary = main.gs.cfg
	# 14 ultimes déclarés, chacun rattaché à une classe évoluée
	var n_ult := 0
	var classes: Array = []
	for c in cfg.classes:
		if str(c.get("ultimateSpellId", "")) != "":
			n_ult += 1
			classes.append(c)
			ok(str(c.get("evolvesFrom", "")) != "", "%s est une classe évoluée" % c.id)
	ok(n_ult == 14, "14 classes évoluées ont un ultime (%d)" % n_ult)
	# place le groupe devant un monstre
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var st: Dictionary = lst.get(str(m.id), {})
		if st.is_empty() or not st.alive or not m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st.x), int(st.y)) - v
			if main.grid.is_walkable(from.x, from.y):
				main.rig.place(main.grid, from.x, from.y, d)
				found = true
				break
		if found:
			break
	if not found:
		for m in main.level.monsters:
			var st2: Dictionary = lst.get(str(m.id), {})
			if st2.is_empty() or not st2.alive:
				continue
			for d in 4:
				var v2: Vector2i = DungeonGrid.DIRS[d]
				var from2 := Vector2i(int(st2.x), int(st2.y)) - v2
				if main.grid.is_walkable(from2.x, from2.y):
					main.rig.place(main.grid, from2.x, from2.y, d)
					found = true
					break
			if found:
				break
	main.ctrl.refresh()
	await create_timer(2.0).timeout
	var cb = main.ctrl.combat
	var gs = main.gs
	var hero: Dictionary = gs.party[0]
	# classe de base : verrouillé
	ok(Chars.ultimate_id(cfg, hero) == "", "héros de classe de base : ultime verrouillé (%s)" % str(hero.classId))
	root.get_texture().get_image().save_png(out + "_locked.png")
	var target: Dictionary = cb.front_monster()
	ok(not target.is_empty(), "un monstre en face")
	var cast_n := 0
	for cls in classes:
		hero["classId"] = cls.id
		hero["level"] = 5
		hero["hp"] = int(hero.maxHp)
		hero["statusEffects"] = []
		var sid: String = cls.ultimateSpellId
		ok(Chars.ultimate_id(cfg, hero) == sid, "%s : ultime %s débloqué" % [cls.id, sid])
		# monstres remis à neuf
		for k in lst:
			var s: Dictionary = lst[k]
			s["hp"] = float(s.maxHp) * 3.0 if not s.has("members") else s.hp
			s["maxHp"] = float(s.maxHp) * (3.0 if not s.has("members") else 1.0)
			s["alive"] = true
			if s.has("members"):
				for mem in s.members:
					mem["hp"] = float(mem.maxHp) * 3.0
					mem["maxHp"] = float(mem.maxHp) * 3.0
					mem["alive"] = true
		hero["ultCharge"] = 0.0
		var spell: Dictionary = cb.spell_def(sid)
		gs.active_char_id = hero.id
		cb.ensure_gauges()
		cb.gauges["char_" + str(hero.id)] = 100.0
		ok(not cb.cast_spell(hero, sid), "%s : refusé jauge vide" % sid)
		hero["ultCharge"] = 100.0
		cb.gauges["char_" + str(hero.id)] = 100.0
		gs.party[1]["hp"] = 0 if str(spell.get("id", "")) == "spell_ult_cleric" else gs.party[1].hp
		if str(spell.get("id", "")) == "spell_ult_cleric":
			gs.party[2]["hp"] = 5
		var hp_before := _total(lst)
		var party_hp := int(gs.party[2].hp)
		var gold0: int = gs.gold
		var res: bool = cb.cast_spell(hero, sid)
		ok(res, "%s : lancé" % sid)
		ok(float(hero.ultCharge) == 0.0, "%s : jauge vidée" % sid)
		var hp_after := _total(lst)
		match str(spell.mode):
			"damage", "damageGroup":
				ok(hp_after < hp_before, "%s : dégâts infligés (%d)" % [sid, int(hp_before - hp_after)])
			"healParty":
				ok(int(gs.party[1].hp) > 0 and int(gs.party[2].hp) > party_hp, "%s : relève + soin" % sid)
		if sid == "spell_ult_thief":
			ok(gs.gold > gold0, "%s : or ramassé" % sid)
		if sid == "spell_ult_warlock" or sid == "spell_ult_berserker":
			ok(int(hero.hp) < int(hero.maxHp) or sid == "spell_ult_warlock", "%s : sacrifice de PV" % sid)
		cast_n += 1
		await create_timer(0.35).timeout
		if args.has("shots"):
			root.get_texture().get_image().save_png("%s_%s.png" % [out, sid])
		# fin de tour factice : on libère l'acteur
		cb.advance_gauges_once()
		cb.events.clear()
	ok(cast_n == 14, "14 ultimes lancés")
	# gain de jauge sur coup porté / reçu
	hero["classId"] = "class_berserker"
	hero["ultCharge"] = 0.0
	Chars.ult_gain(cfg, hero, "gainHit")
	ok(float(hero.ultCharge) == 10.0, "gain par coup porté +10")
	Chars.ult_gain(cfg, hero, "gainTaken")
	ok(float(hero.ultCharge) == 16.0, "gain par coup reçu +6")
	for i in 20:
		Chars.ult_gain(cfg, hero, "gainHit")
	ok(float(hero.ultCharge) == 100.0, "jauge plafonnée à 100")
	hero["ultCharge"] = 100.0
	main.ctrl.refresh()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(out + "_ready.png")
	print("FAILS=%d" % fails)
	quit()

func _total(lst: Dictionary) -> float:
	var t := 0.0
	for k in lst:
		var s: Dictionary = lst[k]
		if s.has("members"):
			for mem in s.members:
				t += maxf(0.0, float(mem.hp))
		else:
			t += maxf(0.0, float(s.hp))
	return t
