class_name StatExplain
extends RefCounted
## Texte d'infobulle d'une statistique : la règle, le calcul chiffré, puis chaque source qui la modifie (objets équipés, talents,
## statuts, niveau) et le résultat final. Utilisé par la fiche de personnage et par le panneau d'équipement.
## `key` : force | dex | con | int | speed | atk | crit | dodge | guard | reduc_phys | reduc_mag | spell_power | lifesteal | hp | stamina

const ALL := ["force", "dex", "con", "int", "speed", "atk", "crit", "dodge", "guard", "reduc_phys", "reduc_mag", "spell_power", "lifesteal"]

static func _sg(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)

## Sources d'un bonus : objets équipés (champ `eq_field`) et talents (effet `tal_field`). Une ligne par source.
static func _sources(c: Dictionary, cfg: Dictionary, eq_fields: Array, tal_fields: Array, status_speed: bool = false) -> String:
	var lines: Array[String] = []
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
				lines.append(L.fa(L.t("ui.stat_explain.line"), [L.c(str(it.get("name", "?"))), _sg(v), L.c(str(Inventory.SLOT_LABELS.get(slot, slot)))]))
	for t in c.get("talents", []):
		var opt := Talents.find_option(cfg, str(t.get("id", "")))
		for f in tal_fields:
			var v := int(opt.get("effects", {}).get(f, 0))
			if v != 0:
				lines.append(L.fa(L.t("ui.stat_explain.line"), [str(opt.get("labelFr", t.get("id", ""))), _sg(v), L.t("ui.stat_explain.talent")]))
	if status_speed:
		for e in Statuses.active(c):
			var sb := int(Statuses.def(str(e.type)).get("speedBonus", 0))
			if sb != 0:
				lines.append(L.fa(L.t("ui.stat_explain.line"), [L.c(str(Statuses.def(str(e.type)).get("label", e.type))), _sg(sb), L.fa(L.t("ui.party_tip.tours"), int(e.remaining))]))
	if lines.is_empty():
		return L.t("ui.stat_explain.aucune_source")
	return "\n".join(lines)

static func _head(title: String) -> String:
	return title + "\n" + "─".repeat(18) + "\n"

static func _sum(c: Dictionary, cfg: Dictionary, key: String) -> String:
	var bd := Stats.breakdown(c, cfg, key)
	return L.fa(L.t("ui.stat_explain.somme"), [int(bd.base), int(bd.gear), int(bd.talent), int(bd.status), int(bd.total)])

## Infobulle complète pour la statistique `key` du personnage `c`.
static func text(c: Dictionary, cfg: Dictionary, key: String) -> String:
	if c.is_empty():
		return ""
	var lvl := int(c.get("level", 1))
	var out := ""
	var src_title := L.t("ui.stat_explain.sources")
	match key:
		"force":
			var f := int(c.get("effForce", 10))
			out = _head(L.t("common.force")) + L.t("ui.party_modal.tip_force") + "\n\n" + _sum(c, cfg, "force") + "\n" \
				+ L.fa(L.t("ui.stat_explain.res_force"), [f, lvl, f / 3, (lvl - 1) / 2, int(c.get("baseAtkMin", 0))]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusForce"], ["bonusForce"])
		"dex":
			var d := int(c.get("effDex", 10))
			out = _head(L.t("common.dexterite")) + L.t("ui.party_modal.tip_dex") + "\n\n" + _sum(c, cfg, "dex") + "\n" \
				+ L.fa(L.t("ui.stat_explain.res_dex"), [int(c.get("baseAtkMin", 0)), d / 4, int(c.get("baseAtkMax", 0)), d, Stats.crit_from_dex(d), d, Stats.dodge_from_dex(d)]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusDex"], ["bonusDex"])
		"con":
			var k := int(c.get("effCon", 10))
			out = _head(L.t("common.constitution")) + L.t("ui.party_modal.tip_con") + "\n\n" + _sum(c, cfg, "con") + "\n" \
				+ L.fa(L.t("ui.stat_explain.res_con"), [k, lvl - 1, 10 + 3 * k + 4 * (lvl - 1), int(c.maxHp), k, Stats.guard_from_con(k)]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusCon", "bonusHp"], ["bonusCon", "bonusHp"])
		"int":
			var i := int(c.get("effInt", 10))
			out = _head(L.t("common.intelligence")) + L.t("ui.party_modal.tip_int") + "\n\n" + _sum(c, cfg, "int") + "\n" \
				+ L.fa(L.t("ui.stat_explain.res_int"), [i, i / 3, Stats.spell_power(i)]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusInt"], ["bonusInt"])
		"speed":
			out = _head(L.t("common.vitesse")) + L.t("ui.party_modal.tip_speed") + "\n\n" + _sum(c, cfg, "speed") + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusSpeed"], [], true)
		"atk":
			var eq := Characters.equipped_bonus(c)
			var tal := Talents.bonus(c, cfg)
			out = _head(L.t("common.attaque")) + L.t("ui.stat_explain.rule_atk") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_atk"), [int(c.get("baseAtkMin", 0)), int(c.get("baseAtkMax", 0)), int(eq["bonusAtkMin"]), int(eq["bonusAtkMax"]), int(tal.bonusAtkMin), int(tal.bonusAtkMax), int(c.atkMin), int(c.atkMax)]) \
				+ "\n\n" + src_title + "\n" + _sources(c, cfg, ["bonusAtkMin", "bonusAtkMax"], ["bonusAtkMin", "bonusAtkMax"])
		"crit":
			var dx := int(c.get("effDex", 10))
			out = _head(L.t("ui.party_modal.critique")) + L.t("ui.stat_explain.rule_crit") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_crit"), [Stats.crit_from_dex(dx), int(c.get("talentCritChance", 0)), int(c.get("talentCritChance", 0)) + Stats.crit_from_dex(dx), Stats.CAP_CRIT]) \
				+ "\n\n" + src_title + "\n" + _sources(c, cfg, [], ["critChance"])
		"dodge":
			var dd := int(c.get("effDex", 10))
			out = _head(L.t("ui.party_modal.esquive")) + L.t("ui.party_modal.tip_esquive") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_dodge"), [dd, Stats.dodge_from_dex(dd), Stats.CAP_DODGE]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusDex"], ["bonusDex"])
		"guard":
			var cn := int(c.get("effCon", 10))
			out = _head(L.t("ui.party_modal.garde")) + L.t("ui.party_modal.tip_garde") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_guard"), [cn, Stats.guard_from_con(cn), Stats.CAP_GUARD]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusCon"], ["bonusCon"])
		"reduc_phys", "reduc_mag":
			var mag := key == "reduc_mag"
			var rf := "resistMagic" if mag else "resistPhys"
			out = _head(L.t("ui.party_modal.reduc_mag") if mag else L.t("ui.party_modal.reduc_phys")) \
				+ L.fa(L.t("ui.party_modal.tip_reduc"), [int(c.get(rf, 0)), int(c.get("guardPct", 0)), Stats.CAP_REDUCTION]) + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_reduc"), [int(c.get(rf, 0)), int(c.get("guardPct", 0)), Stats.reduction(c, mag), Stats.CAP_REDUCTION]) \
				+ "\n\n" + src_title + "\n" + _sources(c, cfg, [], [rf])
		"spell_power":
			var eq2 := Characters.equipped_bonus(c)
			var tal2 := Talents.bonus(c, cfg)
			var gear := int(eq2["bonusSpellDmg"]) + int(tal2.bonusSpellDmg)
			var lv := int(floor((lvl - 1) * 0.75))
			var pw := int(c.get("spellPower", 0))
			out = _head(L.t("ui.party_modal.puissance_sorts")) + L.t("ui.stat_explain.rule_spell") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_spell"), [pw, gear, lv, pw + gear + lv, pw]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, ["bonusSpellDmg"], ["bonusSpellDmg"])
		"lifesteal":
			out = _head(L.t("ui.party_modal.vol_vie")) + L.t("ui.party_modal.tip_vol_vie") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_life"), int(c.get("talentLifestealPct", 0))) + "\n\n" + src_title + "\n" + _sources(c, cfg, [], ["lifestealPct"])
		"hp":
			return text(c, cfg, "con")
		"stamina":
			out = _head(L.t("common.endurance")) + L.t("ui.stat_explain.rule_stamina") + "\n\n" \
				+ L.fa(L.t("ui.stat_explain.res_stamina"), [roundi(float(c.get("stamina", 0))), int(c.get("maxStamina", 100))]) + "\n\n" + src_title + "\n" \
				+ _sources(c, cfg, [], ["bonusStamina"])
	return out

## Plusieurs statistiques à la suite (ligne de synthèse regroupant plusieurs valeurs).
static func many(c: Dictionary, cfg: Dictionary, keys: Array) -> String:
	var parts: Array[String] = []
	for k in keys:
		parts.append(text(c, cfg, str(k)))
	return "\n\n".join(parts)
