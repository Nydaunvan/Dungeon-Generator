class_name StatExplain
extends RefCounted
## Contenu des fenêtres de survol des statistiques (affichées par StatTip) : pour chaque statistique, une « section » structurée :
##   title, icon, value (résultat final), color, rule (règle en une phrase), rows (calcul ligne à ligne : {k, v, tone}),
##   results (formules chiffrées), note, sources ([{icon, name, value, tag}] : objets équipés, talents, statuts).
## `tone` d'une ligne : "pos" (vert), "neg" (rouge), "dim", "total" (ligne de total).
## `key` : force | dex | con | int | speed | atk | crit | dodge | guard | reduc_phys | reduc_mag | spell_power | lifesteal | hp | stamina

const ALL := ["force", "dex", "con", "int", "speed", "atk", "crit", "dodge", "guard", "reduc_phys", "reduc_mag", "spell_power", "lifesteal"]
const STAT_COLORS := {"force": Color("e0785a"), "dex": Color("8fcf6a"), "con": Color("e8b45c"), "int": Color("6fb7e8"), "speed": Color("e8d36a")}

static func _sg(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)

static func _pct(n: int) -> String:
	return ("+%d %%" % n) if n > 0 else ("%d %%" % n)

static func _tone(n: int) -> String:
	return "pos" if n > 0 else ("neg" if n < 0 else "dim")

static func _row(k: String, v: String, tone: String = "") -> Dictionary:
	return {"k": k, "v": v, "tone": tone}

## Sources d'un bonus : objets équipés (champs `eq_fields`), talents (effets `tal_fields`), statuts de vitesse si demandé.
static func _sources(c: Dictionary, cfg: Dictionary, eq_fields: Array, tal_fields: Array, unit: String = "", status_speed: bool = false) -> Array:
	var out: Array = []
	var eq: Dictionary = c.get("equipment", {})
	for slot in Characters.SLOTS:
		var it = eq.get(slot)
		if not (it is Dictionary):
			continue
		for f in eq_fields:
			if slot == "weapon" and (f == "bonusHp" or f == "bonusSpellDmg"):
				continue
			var v := int(it.get(f, 0))
			if v != 0:
				out.append({"icon": str(it.get("icon", "")), "name": L.c(str(it.get("name", "?"))), "value": _sg(v) + unit, "tone": _tone(v),
					"tag": L.c(str(Inventory.SLOT_LABELS.get(slot, slot)))})
	for t in c.get("talents", []):
		var opt := Talents.find_option(cfg, str(t.get("id", "")))
		for f in tal_fields:
			var v := int(opt.get("effects", {}).get(f, 0))
			if v != 0:
				out.append({"icon": str(opt.get("icon", "")), "name": str(opt.get("labelFr", t.get("id", ""))), "value": _sg(v) + unit, "tone": _tone(v), "tag": L.t("ui.stat_explain.talent")})
	if status_speed:
		for e in Statuses.active(c):
			var sd := Statuses.def(str(e.type))
			var sb := int(sd.get("speedBonus", 0))
			if sb != 0:
				out.append({"icon": str(sd.get("icon", "")), "name": L.c(str(sd.get("label", e.type))), "value": _sg(sb), "tone": _tone(sb), "tag": L.fa(L.t("ui.party_tip.tours"), int(e.remaining))})
	return out

## Lignes Base / Équipement / Talents / Statuts / Total d'une caractéristique.
static func _bd_rows(c: Dictionary, cfg: Dictionary, key: String) -> Array:
	var bd := Stats.breakdown(c, cfg, key)
	var rows: Array = [_row(L.t("ui.stat_explain.r_base"), str(int(bd.base)))]
	if int(bd.gear) != 0:
		rows.append(_row(L.t("ui.stat_explain.r_equip"), _sg(int(bd.gear)), _tone(int(bd.gear))))
	if int(bd.talent) != 0:
		rows.append(_row(L.t("ui.stat_explain.r_talents"), _sg(int(bd.talent)), _tone(int(bd.talent))))
	if int(bd.status) != 0:
		rows.append(_row(L.t("ui.stat_explain.r_status"), _sg(int(bd.status)), _tone(int(bd.status))))
	rows.append(_row(L.t("ui.stat_explain.r_total"), str(int(bd.total)), "total"))
	return rows

static func _sec(key: String, icon: String, title: String, value: String, rule: String, rows: Array, results: Array, sources: Array, note: String = "") -> Dictionary:
	return {"key": key, "icon": icon, "title": title, "value": value, "color": STAT_COLORS.get(key, Color("e8b45c")), "rule": rule, "rows": rows,
		"results": results, "sources": sources, "note": note}

## Section de la statistique `key` du personnage `c`.
static func data(c: Dictionary, cfg: Dictionary, key: String) -> Dictionary:
	if c.is_empty():
		return {}
	var lvl := int(c.get("level", 1))
	match key:
		"force":
			var f := int(c.get("effForce", 10))
			return _sec(key, "💪", L.t("common.force"), str(f), L.t("ui.party_modal.tip_force"), _bd_rows(c, cfg, key),
				[L.fa(L.t("ui.stat_explain.f_force"), [f, lvl, int(c.get("baseAtkMin", 0))])], _sources(c, cfg, ["bonusForce"], ["bonusForce"]))
		"dex":
			var d := int(c.get("effDex", 10))
			return _sec(key, "🎯", L.t("common.dexterite"), str(d), L.t("ui.party_modal.tip_dex"), _bd_rows(c, cfg, key),
				[L.fa(L.t("ui.stat_explain.f_dex_max"), [int(c.get("baseAtkMin", 0)), d, int(c.get("baseAtkMax", 0))]),
				L.fa(L.t("ui.stat_explain.f_dex_crit"), [d, Stats.crit_from_dex(d)]), L.fa(L.t("ui.stat_explain.f_dex_dodge"), [d, Stats.dodge_from_dex(d)])],
				_sources(c, cfg, ["bonusDex"], ["bonusDex"]))
		"con":
			var k := int(c.get("effCon", 10))
			return _sec(key, "🛡️", L.t("common.constitution"), str(k), L.t("ui.party_modal.tip_con"), _bd_rows(c, cfg, key),
				[L.fa(L.t("ui.stat_explain.f_con_hp"), [k, lvl - 1, 10 + 3 * k + 4 * (lvl - 1)]), L.fa(L.t("ui.stat_explain.f_con_guard"), [k, Stats.guard_from_con(k)])],
				_sources(c, cfg, ["bonusCon"], ["bonusCon"]))
		"int":
			var i := int(c.get("effInt", 10))
			return _sec(key, "✨", L.t("common.intelligence"), str(i), L.t("ui.party_modal.tip_int"), _bd_rows(c, cfg, key),
				[L.fa(L.t("ui.stat_explain.f_int"), [i, Stats.spell_power(i)])], _sources(c, cfg, ["bonusInt"], ["bonusInt"]))
		"speed":
			return _sec(key, "⚡", L.t("common.vitesse"), str(int(c.get("effSpeed", 10))), L.t("ui.party_modal.tip_speed"), _bd_rows(c, cfg, key), [],
				_sources(c, cfg, ["bonusSpeed"], [], "", true))
		"atk":
			var eq := Characters.equipped_bonus(c)
			var tal := Talents.bonus(c, cfg)
			var rows: Array = [_row(L.t("ui.stat_explain.r_base"), "%d – %d" % [int(c.get("baseAtkMin", 0)), int(c.get("baseAtkMax", 0))])]
			if int(eq["bonusAtkMin"]) != 0 or int(eq["bonusAtkMax"]) != 0:
				rows.append(_row(L.t("ui.stat_explain.r_equip"), "+%d – +%d" % [int(eq["bonusAtkMin"]), int(eq["bonusAtkMax"])], "pos"))
			if int(tal.bonusAtkMin) != 0 or int(tal.bonusAtkMax) != 0:
				rows.append(_row(L.t("ui.stat_explain.r_talents"), "+%d – +%d" % [int(tal.bonusAtkMin), int(tal.bonusAtkMax)], "pos"))
			rows.append(_row(L.t("ui.stat_explain.r_total"), "%d – %d" % [int(c.atkMin), int(c.atkMax)], "total"))
			return _sec(key, "⚔️", L.t("common.attaque"), "%d – %d" % [int(c.atkMin), int(c.atkMax)], L.t("ui.stat_explain.rule_atk"), rows, [],
				_sources(c, cfg, ["bonusAtkMin", "bonusAtkMax"], ["bonusAtkMin", "bonusAtkMax"]))
		"crit":
			var dx := int(c.get("effDex", 10))
			var tc := int(c.get("talentCritChance", 0))
			return _sec(key, "💥", L.t("ui.party_modal.critique"), "%d %%" % (Stats.crit_from_dex(dx) + tc), L.t("ui.stat_explain.rule_crit"),
				[_row(L.fa(L.t("ui.stat_explain.r_dex_crit"), dx), _pct(Stats.crit_from_dex(dx))), _row(L.t("ui.stat_explain.r_talents"), _pct(tc), _tone(tc)),
				_row(L.t("ui.stat_explain.r_total"), "%d %%" % (Stats.crit_from_dex(dx) + tc), "total")], [], _sources(c, cfg, [], ["critChance"], " %"),
				L.fa(L.t("ui.stat_explain.cap"), Stats.CAP_CRIT) + " (" + L.t("common.dexterite") + ")")
		"dodge":
			var dd := int(c.get("effDex", 10))
			return _sec(key, "💨", L.t("ui.party_modal.esquive"), "%d %%" % Stats.dodge_from_dex(dd), L.t("ui.party_modal.tip_esquive"),
				[_row(L.fa(L.t("ui.stat_explain.r_dex_dodge"), dd), _pct(Stats.dodge_from_dex(dd))), _row(L.t("ui.stat_explain.r_total"), "%d %%" % Stats.dodge_from_dex(dd), "total")],
				[], _sources(c, cfg, ["bonusDex"], ["bonusDex"]), L.fa(L.t("ui.stat_explain.cap"), Stats.CAP_DODGE))
		"guard":
			var cn := int(c.get("effCon", 10))
			return _sec(key, "🛡️", L.t("ui.party_modal.garde"), "%d %%" % Stats.guard_from_con(cn), L.t("ui.party_modal.tip_garde"),
				[_row(L.fa(L.t("ui.stat_explain.r_con_guard"), cn), _pct(Stats.guard_from_con(cn))), _row(L.t("ui.stat_explain.r_total"), "%d %%" % Stats.guard_from_con(cn), "total")],
				[], _sources(c, cfg, ["bonusCon"], ["bonusCon"]), L.fa(L.t("ui.stat_explain.cap"), Stats.CAP_GUARD))
		"reduc_phys", "reduc_mag":
			var mag := key == "reduc_mag"
			var rf := "resistMagic" if mag else "resistPhys"
			var rt := int(c.get(rf, 0))
			var g := int(c.get("guardPct", 0))
			return _sec(key, "🔮" if mag else "⚔️", L.t("ui.party_modal.reduc_mag") if mag else L.t("ui.party_modal.reduc_phys"), "%d %%" % Stats.reduction(c, mag),
				L.fa(L.t("ui.party_modal.tip_reduc"), [rt, g, Stats.CAP_REDUCTION]),
				[_row(L.t("ui.stat_explain.r_res_talents"), _pct(rt), _tone(rt)), _row(L.t("ui.stat_explain.r_guard"), _pct(g), _tone(g)),
				_row(L.t("ui.stat_explain.r_total"), "%d %%" % Stats.reduction(c, mag), "total")], [], _sources(c, cfg, [], [rf], " %"), L.fa(L.t("ui.stat_explain.cap"), Stats.CAP_REDUCTION))
		"spell_power":
			var eq2 := Characters.equipped_bonus(c)
			var tal2 := Talents.bonus(c, cfg)
			var gear := int(eq2["bonusSpellDmg"]) + int(tal2.bonusSpellDmg)
			var lv := int(floor((lvl - 1) * 0.75))
			var pw := int(c.get("spellPower", 0))
			return _sec(key, "✨", L.t("ui.party_modal.puissance_sorts"), "+%d" % (pw + gear + lv), L.t("ui.stat_explain.rule_spell"),
				[_row(L.t("ui.stat_explain.r_pw_int"), _sg(pw), _tone(pw)), _row(L.t("ui.stat_explain.r_pw_gear"), _sg(gear), _tone(gear)),
				_row(L.t("ui.stat_explain.r_pw_lvl"), _sg(lv), _tone(lv)), _row(L.t("ui.stat_explain.r_total"), _sg(pw + gear + lv), "total")],
				[], _sources(c, cfg, ["bonusSpellDmg"], ["bonusSpellDmg"]), L.fa(L.t("ui.stat_explain.n_pw"), pw))
		"lifesteal":
			var ls := int(c.get("talentLifestealPct", 0))
			return _sec(key, "🩸", L.t("ui.party_modal.vol_vie"), "%d %%" % ls, L.t("ui.party_modal.tip_vol_vie"),
				[_row(L.t("ui.stat_explain.r_life"), _pct(ls), _tone(ls)), _row(L.t("ui.stat_explain.r_total"), "%d %%" % ls, "total")], [], _sources(c, cfg, [], ["lifestealPct"], " %"))
		"hp":
			var k2 := int(c.get("effCon", 10))
			var base_hp := 10 + 3 * k2 + 4 * (lvl - 1)
			var extra := int(c.maxHp) - base_hp
			var rows2: Array = [_row(L.t("ui.stat_explain.r_hp_base"), str(base_hp))]
			if extra != 0:
				rows2.append(_row(L.t("ui.stat_explain.r_hp_extra"), _sg(extra), _tone(extra)))
			rows2.append(_row(L.t("ui.stat_explain.r_total"), str(int(c.maxHp)), "total"))
			return _sec(key, "❤️", L.t("common.pv"), "%d / %d" % [int(c.hp), int(c.maxHp)], L.t("ui.party_modal.tip_con"), rows2,
				[L.fa(L.t("ui.stat_explain.f_con_hp"), [k2, lvl - 1, base_hp])], _sources(c, cfg, ["bonusHp"], ["bonusHp"]))
		"stamina":
			return _sec(key, "💧", L.t("common.endurance"), "%d / %d" % [roundi(float(c.get("stamina", 0))), int(c.get("maxStamina", 100))], L.t("ui.stat_explain.rule_stamina"),
				[_row(L.t("ui.stat_explain.r_sta_cur"), str(roundi(float(c.get("stamina", 0))))), _row(L.t("ui.stat_explain.r_sta_max"), str(int(c.get("maxStamina", 100))), "total")],
				[], _sources(c, cfg, [], ["bonusStamina"]))
	return {}

## Sections de plusieurs statistiques.
static func many_data(c: Dictionary, cfg: Dictionary, keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		var s := data(c, cfg, str(k))
		if not s.is_empty():
			out.append(s)
	return out

## Section d'une statistique de monstre (fiche du monstre) : règle chiffrée + statuts qui la modifient.
static func monster_section(icon: String, title: String, value: String, rule: String, def_st: Dictionary, with_status: bool = true) -> Dictionary:
	var src: Array = []
	if with_status:
		for e in Statuses.active(def_st):
			var sd := Statuses.def(str(e.type))
			src.append({"icon": str(sd.get("icon", "✨")), "name": L.c(str(sd.get("label", e.type))), "value": "", "tone": "dim", "tag": L.fa(L.t("ui.party_tip.tours"), int(e.remaining))})
	return {"key": "", "icon": icon, "title": title, "value": value, "color": Color("e8b45c"), "rule": rule, "rows": [], "results": [], "sources": src, "note": ""}

## Texte brut d'une section (tests, lecteurs d'écran).
static func flatten(sections: Array) -> String:
	var parts: Array[String] = []
	for s in sections:
		var t: String = "%s %s : %s\n%s" % [s.icon, s.title, s.value, s.rule]
		for r in s.rows:
			t += "\n%s : %s" % [r.k, r.v]
		for r in s.results:
			t += "\n→ " + str(r)
		for r in s.sources:
			t += "\n• %s %s (%s)" % [r.name, r.value, r.tag]
		if str(s.note) != "":
			t += "\n" + str(s.note)
		parts.append(t)
	return "\n\n".join(parts)

static func text(c: Dictionary, cfg: Dictionary, key: String) -> String:
	return flatten(many_data(c, cfg, [key]))
