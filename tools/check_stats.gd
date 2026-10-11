extends SceneTree
## Stats : barème Force/Dex/Con/Int/Vitesse, réduction des dégâts (résistances + garde), esquive, puissance des sorts, vitesse des monstres.
## xvfb-run -a godot --path . --script res://tools/check_stats.gd
var fails := 0
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func total_hp(gs) -> int:
	var t := 0
	for c in gs.party: t += int(c.hp)
	return t

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var S = load("res://scripts/rules/stats.gd")
	# barème
	check("critique : Dex 10 → 0", S.crit_from_dex(10) == 0)
	check("critique : Dex 17 → 7", S.crit_from_dex(17) == 7)
	check("critique plafonné à 25", S.crit_from_dex(99) == 25)
	check("esquive : Dex 17 → 5", S.dodge_from_dex(17) == 5)
	check("esquive plafonnée à 20", S.dodge_from_dex(99) == 20)
	check("garde : Con 14 → 4", S.guard_from_con(14) == 4)
	check("garde : Con 8 → 0", S.guard_from_con(8) == 0)
	check("sorts : Int 10 → +2", S.spell_power(10) == 2)
	check("sorts : Int 16 → +4", S.spell_power(16) == 4)
	check("sorts : Int 3 → 0", S.spell_power(3) == 0)
	check("monstre sans vitesse, Dex 9 → 8", S.monster_speed({"dex": 9}) == 8.0)
	check("monstre sans vitesse, Dex 15 → 10", S.monster_speed({"dex": 15}) == 10.0)
	check("monstre avec vitesse 13", S.monster_speed({"dex": 3, "speed": 13}) == 13.0)
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var gs = m.gs
	var ctrl = m.ctrl
	var c: Dictionary = gs.party[3]
	# les valeurs dérivées suivent les caractéristiques effectives
	c["int"] = 16
	c["dex"] = 20
	c["con"] = 15
	var CH = load("res://scripts/rules/characters.gd")
	CH.recompute(c, gs.cfg)
	check("spellPower suit l'Intelligence (%d)" % int(c.spellPower), int(c.spellPower) == S.spell_power(int(c.effInt)))
	check("critDexPct suit la Dextérité", int(c.critDexPct) == S.crit_from_dex(int(c.effDex)))
	check("dodgePct suit la Dextérité", int(c.dodgePct) == S.dodge_from_dex(int(c.effDex)))
	check("guardPct suit la Constitution", int(c.guardPct) == S.guard_from_con(int(c.effCon)))
	var bd = S.breakdown(c, gs.cfg, "int")
	check("décomposition Int : total = base + équipement + talents", int(bd.total) == int(bd.base) + int(bd.gear) + int(bd.talent))
	var sb = S.spell_bonus(c, "healSingle")
	check("bonus de sort de soin = Int + équip + niveau", int(sb.total) == int(sb.power) + int(sb.gear) + int(sb.level))
	check("bonus de bouclier = Int seule", int(S.spell_bonus(c, "shieldSingle").total) == int(c.spellPower))
	# réduction des dégâts subis par les monstres
	var combat = ctrl.combat
	var def := {"id": "t", "name": "Test"}
	var st := {"atkMin": 10, "atkMax": 10, "enraged": false}
	for h in gs.party:
		h["hp"] = 200
		h["maxHp"] = 200
		h["shieldAmount"] = 0
		h["dodgePct"] = 0
		h["guardPct"] = 0
		h["resistPhys"] = 0
	var before := total_hp(gs)
	for i in 20: combat._monster_attack_party(def, st)
	var loss0 := before - total_hp(gs)
	check("sans réduction : 10 dégâts par coup (%d)" % loss0, loss0 == 200)
	for h in gs.party:
		h["hp"] = 200
		h["resistPhys"] = 30
		h["guardPct"] = 20
	before = total_hp(gs)
	for i in 20: combat._monster_attack_party(def, st)
	var loss1 := before - total_hp(gs)
	check("30 %% de résistance + 20 %% de garde = 50 %% de moins (%d)" % loss1, loss1 == 100)
	for h in gs.party:
		h["hp"] = 200
		h["resistPhys"] = 90
		h["guardPct"] = 25
	before = total_hp(gs)
	for i in 20: combat._monster_attack_party(def, st)
	var loss2 := before - total_hp(gs)
	check("réduction plafonnée à 75 %% (%d)" % loss2, loss2 == 20 * 3 or loss2 == 20 * 2)
	for h in gs.party:
		h["hp"] = 200
		h["resistPhys"] = 0
		h["guardPct"] = 0
		h["dodgePct"] = 100
	before = total_hp(gs)
	for i in 20: combat._monster_attack_party(def, st)
	check("100 %% d'esquive : aucun dégât", before == total_hp(gs))
	print("check_stats : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
