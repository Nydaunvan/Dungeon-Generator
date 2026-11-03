extends Node
## Compétences vivantes : les 15 contrôles obligatoires, exécutés pour de vrai (moteur de combat, sauvegarde, catalogue).
## Lancer : godot --headless --path . res://tools/check_living_skills.tscn   (code de sortie 1 si un contrôle échoue)

var fails := 0
var total := 0

func check(label: String, cond: bool) -> void:
	total += 1
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _cfg() -> Dictionary:
	return (Data.original_config as Dictionary).duplicate(true)

## Monde minimal : partie, combat, un monstre isolé de face. Aucun hasard hors de la graine donnée.
func world(seed_text: String = "living", on: bool = true) -> Dictionary:
	Settings.living_skills = on
	var cfg := _cfg()
	var gs := GameState.create(cfg)
	GameRng.begin(Seeds.from_text(seed_text))
	var lvl: Dictionary = cfg.levels[0]
	var mon: Dictionary = {}
	for m in lvl.monsters:
		if not bool(m.get("isGroup", false)) and not bool(m.get("isBoss", false)):
			mon = m
			break
	var cb := Combat.new(gs, lvl, null)
	var st: Dictionary = gs.level_state(lvl).monsters[str(mon.id)]
	st["hp"] = 5000.0
	st["maxHp"] = 5000.0
	var v: Vector2i = DungeonGrid.DIRS[0]
	cb.pos = Vector2i(int(st.x) - v.x, int(st.y) - v.y)
	cb.dir = 0
	for c in gs.party:
		var cls := Characters.class_def(cfg, str(c.classId))
		c["spellsKnown"] = (cfg.spells as Array).filter(func(sp): return not bool(sp.get("ultimate", false))).map(func(sp): return str(sp.id))
		c["stamina"] = int(c.get("maxStamina", 100))
	return {"gs": gs, "cb": cb, "mon": mon, "st": st, "lvl": lvl}

## Lance un sort comme le jeu : le héros est prêt (jauge pleine, tour actif), l'endurance et la recharge sont remises.
func _cast(w: Dictionary, caster: Dictionary, sid: String, ally_id: String = "", refill: bool = true) -> bool:
	var cb: Combat = w.cb
	var gs: GameState = w.gs
	gs.active_char_id = str(caster.id)
	cb.ensure_gauges()
	cb.gauges["char_" + str(caster.id)] = 100.0
	if refill:
		caster["stamina"] = int(caster.get("maxStamina", 100))
		caster["spellCooldowns"] = {}
	return cb.cast_spell(caster, sid, ally_id)

func _snapshot(w: Dictionary) -> String:
	var gs: GameState = w.gs
	var out: Array = []
	for c in gs.party:
		out.append([c.id, c.hp, c.get("stamina", 0), c.get("shieldAmount", 0)])
	out.append(w.st.hp)
	return JSON.stringify(out)

func _spell(cfg: Dictionary, id: String) -> Dictionary:
	for s in cfg.spells:
		if str(s.id) == id:
			return s
	return {}

func _first_spell(w: Dictionary, mode_in: Array, exclude_ult: bool = true) -> Array:
	var gs: GameState = w.gs
	for c in gs.party:
		for sid in c.spellsKnown:
			var sp := _spell(gs.cfg, str(sid))
			if mode_in.has(str(sp.get("mode", ""))) and not (exclude_ult and bool(sp.get("ultimate", false))):
				return [c, sp]
	return []

func _ready() -> void:
	var saved_opt := Settings.living_skills
	_t1_catalog()
	_t2_nothing_removed()
	_t3_initial_identical()
	_t4_evolutions()
	_t5_affinity_antifarm()
	_t6_memories_persist()
	_t7_synergies()
	_t8_passives()
	_t9_old_saves()
	_t10_determinism()
	_t11_manifestations_nonblocking()
	_t12_balance()
	_t13_clean_disable()
	_t14_lore()
	_t15_ui_texts()
	_t16_tiers()
	Settings.living_skills = saved_opt
	print("RESULTAT compétences vivantes : %d contrôle(s), %d échec(s) -> %s" % [total, fails, "OK" if fails == 0 else "ECHEC"])
	get_tree().quit(1 if fails > 0 else 0)

# 1. toutes les compétences existantes sont cataloguées, avec des évolutions cohérentes
func _t1_catalog() -> void:
	var cfg := _cfg()
	var all := LivingCatalog.all_skills(cfg)
	var nspell := 0
	var ntal := 0
	var nins := 0
	for e in all:
		match str(e.kind):
			"spell": nspell += 1
			"talent": ntal += 1
			"instinct": nins += 1
	check("1. un profil par sort (%d)" % nspell, nspell == (cfg.spells as Array).size())
	var expected_tal := 0
	for cid in Data.class_talents:
		for tier in Data.class_talents[cid]:
			expected_tal += (tier.options as Array).size()
	check("1. un profil par talent (%d)" % ntal, ntal == expected_tal and ntal > 0)
	check("1. sept instincts", nins == 7)
	var families := {}
	for e in all:
		var p := LivingCatalog.profile(cfg, str(e.id))
		check("1. profil non vide : " + str(e.id), not p.is_empty())
		if p.is_empty():
			continue
		families[p.family] = true
		check("1. au moins deux évolutions : " + str(e.id), (p.branches as Array).size() >= 2)
		var seen := {}
		for b in p.branches:
			var kd: Dictionary = LivingCatalog.KINDS.get(str(b.kind), {})
			check("1. évolution connue et de la bonne famille : %s/%s" % [e.id, b.kind], not kd.is_empty() and (kd.fam as Array).has(str(p.family)))
			check("1. trait de l'évolution actif dans la famille : %s/%s" % [e.id, b.kind], (LivingCatalog.FAMILY_TRAITS[p.family] as Array).has(str(b.trait)))
			check("1. pas de doublon : %s/%s" % [e.id, b.kind], not seen.has(b.kind))
			seen[b.kind] = true
		check("1. traits de départ bornés : " + str(e.id), (p.traits as Dictionary).values().all(func(v): return int(v) >= 12 and int(v) <= 28))
	check("1. les huit familles sont représentées", families.size() == 8)
	for k in LivingCatalog.KINDS:
		check("1. texte FR/EN de l'évolution " + k, L.t("ui.living.k_%s_n" % k) != "ui.living.k_%s_n" % k and L.t("ui.living.k_%s_d" % k) != "ui.living.k_%s_d" % k)

# 2. rien n'est supprimé ni renommé : le catalogue ne modifie jamais les données
func _t2_nothing_removed() -> void:
	var cfg := _cfg()
	var before := JSON.stringify(cfg, "", true).md5_text()
	var ids_before: Array = (cfg.spells as Array).map(func(s): return str(s.id))
	LivingCatalog.all_skills(cfg)
	for e in LivingCatalog.all_skills(cfg):
		LivingCatalog.profile(cfg, str(e.id))
	check("2. le catalogue ne modifie pas les données", JSON.stringify(cfg, "", true).md5_text() == before)
	check("2. identifiants de sorts inchangés", (cfg.spells as Array).map(func(s): return str(s.id)) == ids_before)
	for c in cfg.classes:
		for sid in c.get("allowedSpellIds", []):
			check("2. sort de classe catalogué : " + str(sid), not LivingCatalog.profile(cfg, str(sid)).is_empty())
	var w := world()
	var gs: GameState = w.gs
	check("2. une partie neuve n'a aucun état vivant", gs.living.is_empty())
	check("2. clé de sauvegarde déclarée", GameState.SAVE_FIELDS.has("living"))

# 3. coûts et effets initiaux identiques, option active ou non
func _t3_initial_identical() -> void:
	var probe := world("cost", true)
	var gs: GameState = probe.gs
	var costs_same := true
	for s in gs.cfg.spells:
		for c in gs.party:
			if LivingSkills.adjust_cost(gs, c, s, int(s.get("staminaCost", 15))) != int(s.get("staminaCost", 15)):
				costs_same = false
	check("3. coûts de départ inchangés pour tous les sorts", costs_same)
	var same_runs := 0
	var runs := 0
	for modes in [["damage"], ["damageGroup"], ["healSingle"], ["healParty"], ["shieldSingle"], ["dispelSingle"], ["selfBuff"], ["partyUtility"], ["staminaRestoreSingle"], ["sleepGroup"]]:
		var a := world("same", true)
		var b := world("same", false)
		var pa := _first_spell(a, modes)
		var pb := _first_spell(b, modes)
		if pa.is_empty() or pb.is_empty():
			continue
		for idx in 2:
			var pair: Array = [[a, pa], [b, pb]][idx]
			GameRng.begin(Seeds.from_text("same-cast"))      # le flux de hasard est partagé : on le remet au même point pour chaque partie
			var gw: GameState = pair[0].gs
			var caster: Dictionary = pair[1][0]
			for p in gw.party:
				p["hp"] = maxi(1, int(p.maxHp) / 2)
			var ally: Dictionary = gw.party[0]
			Settings.living_skills = idx == 0
			_cast(pair[0], caster, str(pair[1][1].id), str(ally.id), false)
		runs += 1
		if _snapshot(a) == _snapshot(b):
			same_runs += 1
		else:
			print("   différence : ", modes, " ", _snapshot(a), " / ", _snapshot(b))
	check("3. premier lancer identique avec ou sans l'option (%d/%d modes)" % [same_runs, runs], runs >= 6 and same_runs == runs)

# 4. une évolution se déclenche (choix du joueur), son effet est réel et définitif
func _t4_evolutions() -> void:
	var w := world("evo")
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	check("4. un sort offensif existe", not pick.is_empty())
	var caster: Dictionary = pick[0]
	var sp: Dictionary = pick[1]
	var cid := str(caster.id)
	var sid := str(sp.id)
	check("4. aucune évolution disponible au départ", LivingSkills.available_branches(gs, cid, sid).is_empty())
	var prof := LivingCatalog.profile(gs.cfg, sid)
	var br: Dictionary = prof.branches[0]
	var sk := LivingSkills._sk(gs, LivingCatalog.key(cid, sid))
	sk.a = 30.0
	sk.t[str(br.trait)] = 50
	var avail := LivingSkills.available_branches(gs, cid, sid)
	check("4. l'évolution devient disponible (affinité + trait dominant)", avail.has(str(br.kind)))
	sk.a = 20.0
	check("4. affinité trop faible : rien", LivingSkills.available_branches(gs, cid, sid).is_empty())
	sk.a = 30.0
	check("4. choix refusé pour une évolution non disponible", LivingSkills.evolve(gs, cid, sid, "compassion") != "")
	check("4. éveil accepté", LivingSkills.evolve(gs, cid, sid, str(br.kind)) == "")
	check("4. éveil définitif (second choix refusé)", LivingSkills.evolve(gs, cid, sid, str(br.kind)) != "" and LivingSkills.evolved(gs, cid, sid) == str(br.kind))
	check("4. l'éveil est annoncé dans le carnet", gs.log_lines.slice(-4).any(func(l): return str(l).contains(L.t("ui.living.k_%s_n" % str(br.kind)))))
	# effets réels, mesurés sur le calcul de dégâts
	for kind in ["acharnement", "tactique", "brutes", "temerite", "prudence", "vengeance", "precision"]:
		var w2 := world("evo2")
		var g2: GameState = w2.gs
		var p2 := _first_spell(w2, ["damage"])
		var ca: Dictionary = p2[0]
		var spell: Dictionary = p2[1]
		LivingSkills._sk(g2, LivingCatalog.key(str(ca.id), str(spell.id))).e = kind
		LivingSkills.adjust_cost(g2, ca, spell, 1)
		LivingSkills.begin_cast(g2, ca, spell, {}, w2.mon)
		var holder: Dictionary = w2.st
		holder["hp"] = 1000.0
		holder["maxHp"] = 5000.0
		var d_low := LivingSkills.mod_damage(g2, ca, spell, w2.mon, holder, w2.st, 100, false, 40)
		holder["hp"] = 4900.0
		var d_high := LivingSkills.mod_damage(g2, ca, spell, w2.mon, holder, w2.st, 100, false, 40)
		match kind:
			"acharnement": check("4. acharnement : plus fort sur une cible blessée", d_low > d_high and d_high == 100)
			"precision": check("4. précision : perce la résistance", d_low > 100 and ((LivingCatalog.KINDS[kind].single) as bool))
			"tactique": check("4. tactique : moins bon sur une cible saine", d_high < 100)
			"brutes": check("4. brutes : moins bon contre un adversaire isolé", d_high < 100)
			"temerite": check("4. témérité : plus fort", d_high > 100)
			"prudence": check("4. prudence : un peu moins fort", d_high < 100)
			"vengeance": check("4. vengeance : moins fort sans compagnon en danger", d_high < 100)
		LivingSkills.ctx = {}

	# contrôle : durées et effets réels
	var durs: Array = []
	for evo_c in ["", "domination", "patience"]:
		var wc := world("ctl")
		var gc: GameState = wc.gs
		var sl := _first_spell(wc, ["sleepGroup"])
		if sl.is_empty():
			break
		if evo_c != "":
			LivingSkills._sk(gc, LivingCatalog.key(str(sl[0].id), str(sl[1].id))).e = evo_c
		GameRng.begin(Seeds.from_text("ctl-cast"))
		wc.st["statusEffects"] = []
		_cast(wc, sl[0], str(sl[1].id))
		var longest := 0
		for eff in wc.st.get("statusEffects", []):
			longest = maxi(longest, int(eff.get("remaining", 0)))
		durs.append(longest)
		if evo_c == "patience":
			check("4. patience : recharge allongée (prix)", int(sl[0].spellCooldowns.get(str(sl[1].id), 0)) - GameClock.ms > int(float(sl[1].get("cooldownSec", 6)) * 1000.0))
	check("4. domination et patience allongent le sommeil d'un tour (%s)" % str(durs), durs.size() == 3 and durs[0] > 0 and durs[1] == durs[0] + 1 and durs[2] == durs[0] + 1)
	var wd := world("ctl2")
	var gd: GameState = wd.gs
	var ds := _first_spell(wd, ["dispelSingle"])
	if not ds.is_empty():
		var ally: Dictionary = gd.party[0]
		Statuses.give(ally, "burn", 3, "x")
		LivingSkills._sk(gd, LivingCatalog.key(str(ds[0].id), str(ds[1].id))).e = "domination"
		_cast(wd, ds[0], str(ds[1].id), str(ally.id))
		check("4. domination : la purification laisse une Vigueur", Statuses.has(ally, "vigor") and not Statuses.has(ally, "burn"))

# 5. affinité : progression par palier, plafond par combat, anti-farming
func _t5_affinity_antifarm() -> void:
	var w := world("aff")
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	var cid := str(pick[0].id)
	var sid := str(pick[1].id)
	var key := LivingCatalog.key(cid, sid)
	var gains: Array = []
	for i in 8:
		var led := LivingSkills._led(gs)
		led.xp = 40
		led.hp_min = 1.0
		led.mon = ["rat"]
		led.sk[key] = {"c": 6, "dmg": 100, "heal": 0, "kills": 1, "boss": 0, "low": 0, "stat": 0, "risk": 0, "safe": 0, "newmon": 0, "party": 0, "self": 0, "mon": {}}
		var before := float(LivingSkills._sk(gs, key).a)
		LivingSkills.settle(gs, "win")
		gains.append(float(LivingSkills._sk(gs, key).a) - before)
	check("5. gain jamais supérieur au plafond par combat", gains.all(func(g): return g <= LivingSkills.AFF_CAP_COMBAT + 0.001))
	check("5. gain positif", gains[0] > 0.0)
	check("5. même adversaire en boucle : le gain baisse (%s)" % str(gains), gains[7] < gains[0])
	# combat trivial vs combat marquant
	var w2 := world("aff2")
	var g2: GameState = w2.gs
	var k2 := LivingCatalog.key(str(pick[0].id), sid)
	var res: Array = []
	for xp in [0, 80]:
		var led2 := LivingSkills._led(g2)
		led2.xp = xp
		led2.hp_min = 1.0
		led2.mon = ["m" + str(xp)]
		led2.sk[k2] = {"c": 3, "dmg": 20, "heal": 0, "kills": 0, "boss": 0, "low": 0, "stat": 0, "risk": 0, "safe": 0, "newmon": 0, "party": 0, "self": 0, "mon": {}}
		var b := float(LivingSkills._sk(g2, k2).a)
		LivingSkills.settle(g2, "win")
		res.append(float(LivingSkills._sk(g2, k2).a) - b)
	check("5. un combat trivial rapporte moins qu'un combat marquant (%s)" % str(res), res[0] < res[1])
	# fuite : gain borné
	var led3 := LivingSkills._led(g2)
	led3.xp = 200
	led3.mon = ["x"]
	led3.sk[k2] = {"c": 6, "dmg": 500, "heal": 0, "kills": 3, "boss": 1, "low": 0, "stat": 0, "risk": 0, "safe": 0, "newmon": 0, "party": 0, "self": 0, "mon": {}}
	var b3 := float(LivingSkills._sk(g2, k2).a)
	LivingSkills.settle(g2, "flee")
	check("5. fuir ne rapporte presque rien", float(LivingSkills._sk(g2, k2).a) - b3 <= 1.0)
	check("5. paliers d'affinité ordonnés", LivingSkills.tier(0.0) == 0 and LivingSkills.tier(10.0) == 1 and LivingSkills.tier(25.0) == 2 and LivingSkills.tier(50.0) == 3 and LivingSkills.tier(100.0) == 4)
	# usage réel : lancer un sort dans un vrai combat remplit le registre puis l'affinité
	var w3 := world("aff3")
	var g3: GameState = w3.gs
	var p3 := _first_spell(w3, ["damage"])
	for i in 3:
		_cast(w3, p3[0], str(p3[1].id))
	check("5. un vrai lancer remplit le registre", int(LivingSkills._lsk(g3, LivingCatalog.key(str(p3[0].id), str(p3[1].id))).c) == 3)
	(w3.cb as Combat).end_combat_reset()
	check("5. règlement de fin de combat : affinité créditée", LivingSkills.affinity(g3, str(p3[0].id), str(p3[1].id)) > 0.0 and LivingSkills.state(g3).led.is_empty())

# 6. les souvenirs persistent (sauvegarde) et restent peu nombreux
func _t6_memories_persist() -> void:
	var w := world("mem")
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	var key := LivingCatalog.key(str(pick[0].id), str(pick[1].id))
	LivingSkills._remember(gs, key, "first_kill", "rat")
	LivingSkills._remember(gs, key, "first_boss", "g2")
	LivingSkills._remember(gs, key, "first_boss", "g2")
	for i in 12:
		LivingSkills._remember(gs, key, "env", "theme%d" % i)
		LivingSkills._remember(gs, key, "narrow", "m%d" % i)
	var mems: Array = LivingSkills._sk(gs, key).m
	check("6. au plus %d souvenirs gardés" % LivingSkills.MEM_MAX, mems.size() <= LivingSkills.MEM_MAX)
	check("6. un souvenir important est conservé", LivingSkills._has_mem(gs, key, "first_boss"))
	var data := gs.to_save()
	var back := GameState.from_save(gs.cfg, JSON.parse_string(JSON.stringify(data)))
	check("6. l'état vivant survit à la sauvegarde (JSON)", JSON.stringify(back.living, "", true) == JSON.stringify(JSON.parse_string(JSON.stringify(gs.living)), "", true) and not back.living.is_empty())
	check("6. souvenirs relus", LivingSkills._has_mem(back, key, "first_boss"))
	check("6. texte d'un souvenir", LivingSkills.memory_text(back, mems[0]) != "")

# 7. synergies : conditions strictes
func _t7_synergies() -> void:
	var w := world("syn")
	var gs: GameState = w.gs
	var fire := {}
	var nat := {}
	for s in gs.cfg.spells:
		if str(s.get("style", "")) == "fire" and str(s.get("mode", "")) == "damage" and fire.is_empty():
			fire = s
		if str(s.get("style", "")) in ["nature", "arcane"] and str(s.get("mode", "")) == "damage" and nat.is_empty():
			nat = s
	check("7. sorts de test trouvés", not fire.is_empty() and not nat.is_empty())
	var ka := LivingCatalog.key("hero_a", str(fire.id))
	var kb := LivingCatalog.key("hero_b", str(nat.id))
	var led := LivingSkills._led(gs)
	led.n = 4
	led.recent = [[ka, 4, str(fire.id), "", false]]
	check("7. sans lien : pas d'accord", LivingSkills._find_combo(gs, kb, nat, {}).is_empty())
	LivingSkills.state(gs).rel[LivingSkills._pair(ka, kb)] = {"v": 3}
	var found := LivingSkills._find_combo(gs, kb, nat, {})
	check("7. lien de niveau 1 : accord trouvé", str(found.get("id", "")) == "embrasement")
	led.n = 20
	check("7. trop loin dans le temps : pas d'accord", LivingSkills._find_combo(gs, kb, nat, {}).is_empty())
	led.n = 4
	check("7. même compétence : pas d'accord avec soi-même", LivingSkills._find_combo(gs, ka, nat, {}).is_empty())
	check("7. niveaux de lien", LivingSkills.rel_level(gs, ka, kb) == 1)
	LivingSkills.state(gs).rel[LivingSkills._pair(ka, kb)] = {"v": 14}
	check("7. lien de niveau 3 à 14 combats", LivingSkills.rel_level(gs, ka, kb) == 3)
	check("7. type de relation cohérent", LivingSkills.rel_type(gs, ka, kb, 3) in ["complementaire", "rivale", "protectrice", "antagoniste", "fusionnelle"])
	# les relations se tissent à partir de lancers réels, à travers deux héros
	var w2 := world("syn2")
	var g2: GameState = w2.gs
	var fire2 := {}
	var nat2 := {}
	for sp2 in g2.cfg.spells:
		if bool(sp2.get("ultimate", false)) or str(sp2.get("mode", "")) != "damage":
			continue
		if str(sp2.get("style", "")) == "fire" and fire2.is_empty():
			fire2 = sp2
		if str(sp2.get("style", "")) in ["nature", "arcane"] and nat2.is_empty():
			nat2 = sp2
	if g2.party.size() >= 2 and not fire2.is_empty() and not nat2.is_empty():
		var h1: Dictionary = g2.party[0]
		var h2: Dictionary = g2.party[1]
		for i in LivingSkills.REL_AT[0]:
			_cast(w2, h1, str(fire2.id))
			_cast(w2, h2, str(nat2.id))
			(w2.cb as Combat).end_combat_reset()
		var lvl := LivingSkills.rel_level(g2, LivingCatalog.key(str(h1.id), str(fire2.id)), LivingCatalog.key(str(h2.id), str(nat2.id)))
		check("7. une relation réelle naît entre deux héros après %d combats communs" % LivingSkills.REL_AT[0], lvl >= 1)
		for i in LivingSkills.REL_AT[1] - LivingSkills.REL_AT[0]:
			_cast(w2, h1, str(fire2.id))
			_cast(w2, h2, str(nat2.id))
			(w2.cb as Combat).end_combat_reset()
		check("7. niveau 2 après %d combats communs" % LivingSkills.REL_AT[1], LivingSkills.rel_level(g2, LivingCatalog.key(str(h1.id), str(fire2.id)), LivingCatalog.key(str(h2.id), str(nat2.id))) == 2)
		# l'accord se déclenche pour de vrai : le second sort fait plus de dégâts sur une cible qui brûle
		GameRng.begin(Seeds.from_text("combo"))
		var hp0 := float(w2.st.hp)
		_cast(w2, h1, str(fire2.id))
		w2.st["statusEffects"] = [{"type": "burn", "remaining": 3, "power": 1}]
		var hp1 := float(w2.st.hp)
		_cast(w2, h2, str(nat2.id))
		var announced := g2.log_lines.slice(-14).any(func(l): return str(l).begins_with(LivingSkills.MARK))
		check("7. l'accord est annoncé dans le carnet", announced)
		check("7. le second sort a bien frappé", float(w2.st.hp) < hp1 and hp1 < hp0)
		var gain_with := hp1 - float(w2.st.hp)
		# même enchaînement sans aucun lien entre les deux compétences : le bonus d'accord n'existe pas
		var w3 := world("syn2")
		var g3: GameState = w3.gs
		GameRng.begin(Seeds.from_text("combo"))
		_cast(w3, g3.party[0], str(fire2.id))
		w3.st["statusEffects"] = [{"type": "burn", "remaining": 3, "power": 1}]
		var h3 := float(w3.st.hp)
		_cast(w3, g3.party[1], str(nat2.id))
		check("7. sans lien, pas de bonus d'accord (%.0f contre %.0f avec)" % [h3 - float(w3.st.hp), gain_with], gain_with > h3 - float(w3.st.hp))
	for cid in LivingSkills.COMBOS:
		check("7. texte de l'accord " + cid, L.t("ui.living.combo_%s" % cid) != "ui.living.combo_%s" % cid and L.t("ui.living.combod_%s" % cid) != "ui.living.combod_%s" % cid)

# 8. passifs (talents) : crédités par les événements, effets bornés
func _t8_passives() -> void:
	var cfg := _cfg()
	var kinds := {}
	for e in LivingCatalog.all_skills(cfg):
		if str(e.kind) == "talent":
			kinds[LivingCatalog.passive_kind(LivingCatalog.talent_option(cfg, str(e.id)))] = true
	check("8. les cinq orientations de passifs sont employées", kinds.size() == 5)
	var w := world("pas")
	var gs: GameState = w.gs
	var hero: Dictionary = gs.party[0]
	var tal_id := ""
	for e in LivingCatalog.all_skills(gs.cfg):
		if str(e.kind) == "talent" and LivingCatalog.passive_kind(LivingCatalog.talent_option(gs.cfg, str(e.id))) == "p_focus":
			tal_id = str(e.id)
			break
	check("8. un talent « œil exercé » existe", tal_id != "")
	hero["talents"] = [{"id": tal_id, "level": 5}]
	check("8. sans éveil : aucun bonus de critique", LivingSkills.crit_bonus(gs, hero, w.mon) == 0)
	LivingSkills._sk(gs, LivingCatalog.key(str(hero.id), tal_id)).e = "p_focus"
	gs.bestiary[str(w.mon.id)] = 5
	check("8. éveillé et adversaire connu : +6 critique", LivingSkills.crit_bonus(gs, hero, w.mon) == 6)
	gs.bestiary[str(w.mon.id)] = 0
	check("8. adversaire inconnu : pas de bonus", LivingSkills.crit_bonus(gs, hero, w.mon) == 0)
	var led := LivingSkills._led(gs)
	led.hp_min = 0.2
	led.xp = 40
	led.ps[str(hero.id)] = {"crit": 5, "melee": 4, "spell": 0, "hit": 3, "low": 2, "steal": 0, "inst": 0}
	LivingSkills.settle(gs, "win")
	check("8. un passif gagne de l'affinité par les événements qui lui correspondent", LivingSkills.affinity(gs, str(hero.id), tal_id) > 0.0)
	# second souffle : une seule fois par combat
	var sid2 := ""
	for e in LivingCatalog.all_skills(gs.cfg):
		if str(e.kind) == "talent" and e.id != tal_id:
			sid2 = str(e.id)
			break
	hero["talents"] = [{"id": sid2, "level": 5}]
	LivingSkills._sk(gs, LivingCatalog.key(str(hero.id), sid2)).e = "p_souffle"
	hero["hp"] = 1
	LivingSkills.on_turn(gs, hero)
	var hp1 := int(hero.hp)
	hero["hp"] = 1
	LivingSkills.on_turn(gs, hero)
	check("8. second souffle : une seule fois par combat", hp1 > 1 and int(hero.hp) == 1)
	hero["hp"] = int(hero.maxHp)
	hero["talents"] = [{"id": sid2, "level": 5}]
	LivingSkills._sk(gs, LivingCatalog.key(str(hero.id), sid2)).e = "p_ancre"
	var base_dmg := 20
	for other in gs.party:
		other["hp"] = int(other.maxHp)
	check("8. ancre : aucun effet si tous les compagnons vont bien", LivingSkills.mod_incoming(gs, hero, base_dmg) == base_dmg)
	gs.party[1]["hp"] = 1
	check("8. ancre : amortit si un compagnon est en danger", LivingSkills.mod_incoming(gs, hero, base_dmg) < base_dmg)

# 9. anciennes sauvegardes
func _t9_old_saves() -> void:
	var w := world("old")
	var gs: GameState = w.gs
	var data := gs.to_save()
	data.erase("living")
	var old := GameState.from_save(gs.cfg, JSON.parse_string(JSON.stringify(data)))
	check("9. sauvegarde sans état vivant : chargée", old.party.size() == gs.party.size() and old.living.is_empty())
	var pick := _first_spell(w, ["damage"])
	check("9. compétences jouables comme avant", LivingSkills.traits(old, str(pick[0].id), str(pick[1].id)).size() > 0 and LivingSkills.affinity(old, str(pick[0].id), str(pick[1].id)) == 0.0)
	var d := {"schema": 19, "config": gs.cfg.duplicate(true), "dungeonOrigin": "custom", "save": {"living": "mauvais format"}}
	var notes := SaveMigrations.migrate(d, Data.original_config)
	check("9. migration 19 → %d" % SaveMigrations.SCHEMA, int(d.schema) == SaveMigrations.SCHEMA and SaveMigrations.SCHEMA >= 20)
	check("9. un état mal formé est écarté sans toucher au reste", d.save.living is Dictionary and (d.save.living as Dictionary).is_empty())
	var d2 := {"schema": 19, "config": gs.cfg.duplicate(true), "dungeonOrigin": "custom", "save": {"gold": 7}}
	SaveMigrations.migrate(d2, Data.original_config)
	check("9. sauvegarde ordinaire : données intactes", int(d2.save.gold) == 7 and not d2.save.has("living"))
	check("9. notes de migration sans erreur", notes is Array)

# 10. déterminisme : aucun hasard consommé, rejeu identique, inactif en partie classée
func _t10_determinism() -> void:
	var w := world("det", true)
	var before := JSON.stringify(GameRng.export_state())
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	var key := LivingCatalog.key(str(pick[0].id), str(pick[1].id))
	# les opérations propres au système ne tirent aucune valeur aléatoire
	LivingSkills.adjust_cost(gs, pick[0], pick[1], 10)
	LivingSkills.begin_cast(gs, pick[0], pick[1], {}, w.mon)
	LivingSkills.note_hit(gs, pick[0], pick[1], w.mon, 12, false, 0)
	LivingSkills.end_cast(gs, pick[0], pick[1], {}, w.mon)
	LivingSkills.settle(gs, "win")
	LivingSkills._say(gs, "tier", key, ["x"])
	check("10. aucun flux de hasard consommé par le système", JSON.stringify(GameRng.export_state()) == before)
	# deux parties identiques, mêmes actions : mêmes résultats, mêmes états vivants
	var snaps: Array = []
	for r in 2:
		var a := world("rejeu", true)
		var pa := _first_spell(a, ["damage"])
		for i in 4:
			_cast(a, pa[0], str(pa[1].id))
		(a.cb as Combat).end_combat_reset()
		snaps.append(_snapshot(a) + JSON.stringify(a.gs.living, "", true) + JSON.stringify(a.gs.log_lines))
	check("10. rejeu identique (résultats, état vivant, carnet)", snaps[0] == snaps[1])
	var ranked := world("ranked", true)
	ranked.gs.run_seed = "abc"
	check("10. inactif en partie classée", not LivingSkills.active(ranked.gs))
	var pr := _first_spell(ranked, ["damage"])
	_cast(ranked, pr[0], str(pr[1].id))
	ranked.cb.end_combat_reset()
	check("10. partie classée : aucun état créé", ranked.gs.living.is_empty())

# 11. manifestations rares du carnet, jamais bloquantes ; humeur sans refus
func _t11_manifestations_nonblocking() -> void:
	var w := world("say")
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	var key := LivingCatalog.key(str(pick[0].id), str(pick[1].id))
	var led := LivingSkills._led(gs)
	var shown := 0
	var lines0 := gs.log_lines.size()
	for i in 40:
		led.n = i
		if LivingSkills._say(gs, "tier", key, ["Test"]):
			shown += 1
	check("11. au plus %d manifestations par combat (vu %d)" % [LivingSkills.SAY_MAX, shown], shown <= LivingSkills.SAY_MAX and shown >= 1)
	check("11. chaque manifestation est une ligne entre guillemets du carnet", gs.log_lines.size() - lines0 == shown and str(gs.log_lines.back()).begins_with(LivingSkills.MARK))
	led.say = 0
	led.say_n = -99
	led.n = 1
	LivingSkills._say(gs, "tier", key, ["A"])
	led.n = 2
	var second := LivingSkills._say(gs, "tier", key, ["B"])
	check("11. deux manifestations ne se suivent pas de trop près", not second)
	# humeur : jamais de refus
	var w2 := world("mood")
	var g2: GameState = w2.gs
	var p2 := _first_spell(w2, ["damage"])
	var ca: Dictionary = p2[0]
	var base := int(p2[1].get("staminaCost", 15))
	LivingSkills._sk(g2, LivingCatalog.key(str(ca.id), str(p2[1].id))).t["ins"] = 80
	ca["hp"] = 1
	ca["stamina"] = base
	check("11. humeur : coût majoré mais lancer jamais refusé (endurance = coût de base)", _cast(w2, ca, str(p2[1].id), "", false))
	check("11. humeur : endurance de base seule consommée si le surcoût n'est pas payable", int(ca.stamina) == 0)
	ca["stamina"] = 100
	ca["spellCooldowns"] = {}
	var paid := LivingSkills.adjust_cost(g2, ca, p2[1], base)
	check("11. humeur : surcoût réel quand l'endurance suffit", paid > base)
	# les conflits sont annoncés mais ne coûtent rien : relation antagoniste
	var fire := {}
	var ice := {}
	for s in gs.cfg.spells:
		if str(s.style) == "fire" and fire.is_empty():
			fire = s
		if str(s.style) == "ice" and ice.is_empty():
			ice = s
	if not fire.is_empty() and not ice.is_empty():
		check("11. feu et glace : relation antagoniste (tension annoncée, aucune pénalité)", LivingSkills.rel_type(gs, LivingCatalog.key("a", str(fire.id)), LivingCatalog.key("b", str(ice.id)), 1) == "antagoniste")

# 12. équilibre : plafond de multiplicateur et pires cas bornés pour chaque évolution
func _t12_balance() -> void:
	var worst_hi := 0.0
	var worst_lo := 9.0
	for kind in LivingCatalog.KINDS:
		var fam: Array = LivingCatalog.KINDS[kind].fam
		if not (fam.has("offense") or fam.has("technique")):
			continue
		var w := world("bal")
		var gs: GameState = w.gs
		var pick := _first_spell(w, ["damage"] if not LivingCatalog.KINDS[kind].get("group", false) else ["damageGroup"])
		if pick.is_empty():
			pick = _first_spell(w, ["damage"])
		var ca: Dictionary = pick[0]
		var sp: Dictionary = pick[1]
		LivingSkills._sk(gs, LivingCatalog.key(str(ca.id), str(sp.id))).e = kind
		for hp_case in [100.0, 3000.0]:
			for ally_low in [false, true]:
				LivingSkills.adjust_cost(gs, ca, sp, 1)
				LivingSkills.begin_cast(gs, ca, sp, {}, w.mon)
				LivingSkills.ctx["mood"] = true
				LivingSkills.ctx["combo"] = {"id": "embrasement", "lvl": 3, "first": "x"}
				var holder: Dictionary = w.st
				holder["hp"] = hp_case
				holder["maxHp"] = 5000.0
				holder["statusEffects"] = [{"type": "burn", "remaining": 3}]
				if ally_low and gs.party.size() > 1:
					gs.party[1]["hp"] = 1
				var out := LivingSkills.mod_damage(gs, ca, sp, w.mon, holder, w.st, 100, false, 60)
				worst_hi = maxf(worst_hi, float(out) / 100.0)
				worst_lo = minf(worst_lo, float(out) / 100.0)
				LivingSkills.ctx = {}
				if gs.party.size() > 1:
					gs.party[1]["hp"] = int(gs.party[1].maxHp)
	check("12. multiplicateur maximal ≤ %.1f (vu %.2f)" % [LivingSkills.MULT_CAP, worst_hi], worst_hi <= LivingSkills.MULT_CAP + 0.01)
	check("12. aucune évolution n'écrase les dégâts (minimum %.2f)" % worst_lo, worst_lo >= 0.6)
	# équité entre classes : chaque classe a des compétences vivantes de plusieurs familles et des évolutions
	var cfg := _cfg()
	var thin := 0
	for c in cfg.classes:
		var fams := {}
		for sid in c.get("allowedSpellIds", []):
			var p := LivingCatalog.profile(cfg, str(sid))
			if not p.is_empty():
				fams[p.family] = true
		for opt_tier in Data.class_talents.get(str(c.id), []):
			fams["passif"] = true
		if fams.size() < 2:
			thin += 1
	check("12. aucune classe réduite à une seule famille de compétences (%d)" % thin, thin == 0)
	var nbr := {}
	for e in LivingCatalog.all_skills(cfg):
		var p := LivingCatalog.profile(cfg, str(e.id))
		nbr[p.family] = int(nbr.get(p.family, 0)) + 1
	check("12. toutes les familles offrent au moins deux évolutions distinctes", LivingCatalog.FAMILY_KINDS.values().all(func(v): return (v as Array).size() >= 2))

# 13. désactivation propre
func _t13_clean_disable() -> void:
	var a := world("off", false)
	var gs: GameState = a.gs
	var pick := _first_spell(a, ["damage"])
	check("13. option coupée : système inactif", not LivingSkills.active(gs))
	LivingSkills._sk(gs, LivingCatalog.key(str(pick[0].id), str(pick[1].id))).e = "temerite"      # même une évolution présente est ignorée
	var living_before := JSON.stringify(gs.living, "", true)
	check("13. coût inchangé", LivingSkills.adjust_cost(gs, pick[0], pick[1], 12) == 12)
	check("13. dégâts inchangés", LivingSkills.mod_damage(gs, pick[0], pick[1], a.mon, a.st, a.st, 50, false, 0) == 50)
	check("13. soins et boucliers inchangés", LivingSkills.mod_heal(gs, pick[0], pick[1], pick[0], 30) == 30 and LivingSkills.mod_shield(gs, pick[0], pick[1], pick[0], 30) == 30)
	check("13. évolution refusée", LivingSkills.evolve(gs, str(pick[0].id), str(pick[1].id), "temerite") != "")
	for i in 3:
		_cast(a, pick[0], str(pick[1].id))
	(a.cb as Combat).end_combat_reset()
	check("13. aucun enregistrement pendant un combat", JSON.stringify(gs.living, "", true) == living_before and LivingSkills.state(gs).led.is_empty())
	check("13. aucune manifestation dans le carnet", not gs.log_lines.any(func(l): return str(l).begins_with(LivingSkills.MARK)))
	# réactivation : les données gardées reprennent
	Settings.living_skills = true
	check("13. réactivation possible", LivingSkills.active(gs))
	Settings.living_skills = true

# 14. lore : fragments progressifs, textes présents
func _t14_lore() -> void:
	var w := world("lore")
	var gs: GameState = w.gs
	var seen := 0
	for i in 25:
		var before := LivingSkills.lore_unlocked(gs)
		LivingSkills._fragment(gs, 1)
		if LivingSkills.lore_unlocked(gs) > before:
			seen += 1
	check("14. cinq fragments de lore révélés en tout (%d)" % seen, seen == LivingSkills.LORE_AT.size())
	check("14. ordre croissant", (LivingSkills.state(gs).log as Array) == [0, 1, 2, 3, 4])
	for i in LivingSkills.LORE_AT.size():
		check("14. texte de lore %d" % (i + 1), L.t("ui.living.lore_%d" % (i + 1)) != "ui.living.lore_%d" % (i + 1))

# 15. interface et textes : la fiche se construit pour chaque type de compétence
func _t15_ui_texts() -> void:
	var w := world("ui")
	var gs: GameState = w.gs
	var hero: Dictionary = gs.party[0]
	var host := Control.new()
	add_child(host)
	var n := 0
	for sid in LivingSkills.skills_of(gs, hero):
		var m := LivingModal.open(host, gs, str(hero.id), str(sid))
		n += 1
		check("15. fiche construite : " + str(sid), m.modal != null and m.modal.content.get_child_count() > 3)
		m.modal.close()
	check("15. fiches ouvertes (sorts, talents, instinct)", n >= 2)
	var pm := PartyModal.open(host, gs, str(hero.id))
	pm.cat = "living"
	pm._render()
	check("15. onglet « Vie des compétences »", pm.modal.content.get_child_count() >= 1)
	for t in range(LivingCatalog.TRAITS.size()):
		var k: String = "ui.living.trait_%s" % LivingCatalog.TRAITS[t]
		check("15. nom de trait " + k, L.t(k) != k)
	for i in 5:
		check("15. nom de palier %d" % i, L.t("ui.living.tier_%d" % i) != "ui.living.tier_%d" % i)
	host.queue_free()

# 16. paliers « liée » (seconde évolution) et « fusionnelle » (geste signature, une fois par combat)
func _t16_tiers() -> void:
	var w := world("tiers")
	var gs: GameState = w.gs
	var pick := _first_spell(w, ["damage"])
	var caster: Dictionary = pick[0]
	var sid := str(pick[1].id)
	var cid := str(caster.id)
	var prof := LivingCatalog.profile(gs.cfg, sid)
	var key := LivingCatalog.key(cid, sid)
	var sk := LivingSkills._sk(gs, key)
	for b in prof.branches:
		sk.t[str(b.trait)] = 55
	sk.a = 30.0
	var k1 := str(prof.branches[0].kind)
	var k2 := str(prof.branches[1].kind)
	check("16. attachée : première évolution éveillable", LivingSkills.evolve(gs, cid, sid, k1) == "")
	check("16. attachée seulement : pas de seconde évolution", LivingSkills.available_branches(gs, cid, sid).is_empty())
	check("16. seconde évolution refusée avant « liée »", LivingSkills.evolve(gs, cid, sid, k2) != "" and LivingSkills.evos_of(gs, cid, sid).size() == 1)
	sk.a = 50.0
	var av := LivingSkills.available_branches(gs, cid, sid)
	check("16. liée : les autres branches sont éveillables, pas la première", av.has(k2) and not av.has(k1))
	check("16. seconde évolution acceptée", LivingSkills.evolve(gs, cid, sid, k2) == "" and LivingSkills.evos_of(gs, cid, sid) == [k1, k2])
	check("16. au plus deux évolutions", LivingSkills.available_branches(gs, cid, sid).is_empty() and LivingSkills.evolve(gs, cid, sid, str(prof.branches[2].kind)) != "")
	check("16. la description donne les deux évolutions", str(LivingSkills.describe(gs, cid, sid).evolved2) == k2)
	# les deux évolutions se cumulent (dans le plafond)
	var dmg_for := func(evs: Array) -> int:
		var w2 := world("tiers2")
		var g2: GameState = w2.gs
		var p2 := _first_spell(w2, ["damage"])
		var k := LivingCatalog.key(str(p2[0].id), str(p2[1].id))
		var s2 := LivingSkills._sk(g2, k)
		s2.e = evs[0] if evs.size() > 0 else ""
		s2["e2"] = evs[1] if evs.size() > 1 else ""
		LivingSkills.adjust_cost(g2, p2[0], p2[1], 1)
		LivingSkills.begin_cast(g2, p2[0], p2[1], {}, w2.mon)
		var holder: Dictionary = w2.st
		holder["hp"] = 1000.0
		holder["maxHp"] = 5000.0
		var r := LivingSkills.mod_damage(g2, p2[0], p2[1], w2.mon, holder, w2.st, 100, false, 0)
		LivingSkills.ctx = {}
		return r
	var only_a: int = dmg_for.call(["acharnement"])
	var both: int = dmg_for.call(["acharnement", "temerite"])
	check("16. deux évolutions : effets cumulés (%d > %d)" % [both, only_a], both > only_a and both <= int(100.0 * LivingSkills.MULT_CAP))
	# geste signature : attaque
	var loss := func(aff: float, twice: bool) -> Array:
		var w3 := world("tiers3")
		var g3: GameState = w3.gs
		var p3 := _first_spell(w3, ["damage"])
		LivingSkills._sk(g3, LivingCatalog.key(str(p3[0].id), str(p3[1].id))).a = aff
		var out: Array = []
		for i in (2 if twice else 1):
			w3.st["hp"] = 5000.0
			GameRng.begin(Seeds.from_text("tiers-cast"))
			_cast(w3, p3[0], str(p3[1].id))
			out.append(5000.0 - float(w3.st.hp))
		out.append(LivingSkills.sig_ready(g3, LivingCatalog.key(str(p3[0].id), str(p3[1].id))))
		out.append(g3.log_lines.slice(-6).any(func(l): return str(l).begins_with(LivingSkills.MARK)))
		return out
	var base: Array = loss.call(60.0, true)
	var fused: Array = loss.call(85.0, true)
	check("16. fusionnelle : le premier lancer est plus fort que sans geste (%s vs %s)" % [str(fused[0]), str(base[0])], float(fused[0]) > float(base[0]))
	check("16. fusionnelle : le second lancer du même combat retombe au niveau normal", absf(float(fused[1]) - float(base[1])) < 0.01)
	check("16. le geste est dépensé et annoncé dans le carnet", fused[2] == false and fused[3] == true and base[2] == false)
	# le geste revient au combat suivant
	var w4 := world("tiers4")
	var g4: GameState = w4.gs
	var p4 := _first_spell(w4, ["damage"])
	var k4 := LivingCatalog.key(str(p4[0].id), str(p4[1].id))
	LivingSkills._sk(g4, k4).a = 85.0
	check("16. geste prêt", LivingSkills.sig_ready(g4, k4))
	_cast(w4, p4[0], str(p4[1].id))
	check("16. geste dépensé", not LivingSkills.sig_ready(g4, k4))
	LivingSkills.settle(g4, "win")
	check("16. geste de nouveau prêt au combat suivant", LivingSkills.sig_ready(g4, k4))
	# soin : le compagnon le plus blessé reçoit aussi une part
	var heal_gain := func(aff: float) -> int:
		var w5 := world("tiers5")
		var g5: GameState = w5.gs
		var p5 := _first_spell(w5, ["healSingle"])
		if p5.is_empty():
			return -1
		LivingSkills._sk(g5, LivingCatalog.key(str(p5[0].id), str(p5[1].id))).a = aff
		var tgt: Dictionary = g5.party[0]
		var other: Dictionary = g5.party[1] if str(g5.party[1].id) != str(tgt.id) else g5.party[2]
		tgt["hp"] = int(tgt.maxHp) / 2
		other["hp"] = int(other.maxHp) / 4
		var before := int(other.hp)
		GameRng.begin(Seeds.from_text("tiers-heal"))
		_cast(w5, p5[0], str(p5[1].id), str(tgt.id))
		return int(other.hp) - before
	var hb: int = heal_gain.call(60.0)
	var hf: int = heal_gain.call(85.0)
	if hb >= 0:
		check("16. soin fusionnel : le compagnon le plus blessé en profite (%d > %d)" % [hf, hb], hf > hb)
	# textes et fiche
	for fam in ["offense", "technique", "soin", "defense", "controle", "soutien", "passif", "instinct"]:
		check("16. texte du geste " + fam, L.t("ui.living.sig_d_" + fam) != "ui.living.sig_d_" + fam and L.t("ui.living.sig_log_" + fam).count("%s") == 2)
	var host := Control.new()
	add_child(host)
	var lm := LivingModal.open(host, gs, cid, sid)
	check("16. fiche avec deux évolutions et geste signature", lm.modal != null and lm.modal.content.get_child_count() > 5)
	lm.modal.close()
	host.queue_free()
