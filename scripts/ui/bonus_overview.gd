class_name BonusOverview
extends RefCounted
## Vue d'ensemble de TOUT ce qui améliore un héros : bonus de l'équipement (caractéristiques, PV, attaque, vitesse, résistances d'école, capacités des
## raretés, ensemble mythique), des talents, des statuts, de la classe, de la Constitution et des modificateurs d'expédition. Chaque ligne donne
## son total puis, en dessous, CHAQUE source (objet avec son emplacement, talent, statut, classe…) et sa part. Utilisée par la fiche d'inventaire.
## Résultat : [{title, entries: [{icon, label, value, tone, subs: [{text, tone}]}], inactive: [noms]}]

const STATS := ["force", "dex", "con", "int", "speed"]
const COMBAT := ["hp", "stamina", "atk", "crit", "dodge", "guard", "reduc_phys", "reduc_mag", "spell_power", "lifesteal"]
const PERKS := ["spell", "execute", "bleed", "critdmg", "thorns", "gold", "last_stand"]

static func _subs_of(sec: Dictionary) -> Array:
	var subs: Array = []
	for s in sec.get("sources", []):
		var head := str(s.get("name", "")).strip_edges()
		var tag := str(s.get("tag", ""))
		var txt := head + (" (%s)" % tag if tag != "" else "")
		var parts: Array = s.get("parts", [])
		if parts.is_empty():
			txt += "  " + str(s.get("value", ""))
		else:
			var bits: Array = []
			for p in parts:
				bits.append(("%s %s" % [str(p.get("label", "")), str(p.get("value", ""))]).strip_edges())
			txt += "  " + " · ".join(bits)
		subs.append({"icon": str(s.get("icon", "")), "text": txt, "tone": str(s.get("tone", ""))})
	return subs

static func _entry(sec: Dictionary, extra_subs: Array = [], tone: String = "pos") -> Dictionary:
	return {"icon": str(sec.get("icon", "")), "label": str(sec.get("title", "")), "value": str(sec.get("value", "")), "tone": tone,
		"subs": extra_subs + _subs_of(sec)}

static func build(c: Dictionary, cfg: Dictionary) -> Array:
	var groups: Array = []
	if c.is_empty():
		return groups
	# 1. caractéristiques et vitesse : seulement celles que l'équipement, un talent ou un statut modifie
	var g1: Array = []
	for k in STATS:
		var sec := StatExplain.data(c, cfg, k)
		if not (sec.get("sources", []) as Array).is_empty():
			g1.append(_entry(sec))
	groups.append({"title": L.t("ui.bonus.g_stats"), "entries": g1, "inactive": []})
	# 2. combat : valeurs dérivées qui reçoivent un bonus d'objet, de talent ou de statut
	var g2: Array = []
	for k in COMBAT:
		var sec := StatExplain.data(c, cfg, k)
		if not (sec.get("sources", []) as Array).is_empty():
			g2.append(_entry(sec))
	groups.append({"title": L.t("ui.bonus.g_combat"), "entries": g2, "inactive": []})
	# 3. résistances d'école : classe + objets (une faiblesse apparaît aussi, en rouge)
	var g3: Array = []
	var off3: Array = []
	for rk in Resist.KEYS:
		var sec := StatExplain.data(c, cfg, "res_" + rk)
		var tot := Resist.of_hero(c, rk)
		if tot == 0 and (sec.get("sources", []) as Array).is_empty():
			off3.append(L.t(str(Resist.NAME_KEYS[rk])))
			continue
		var cls_bonus := int((Resist.CLASS_RESISTS.get(str(c.get("classId", "")), {}) as Dictionary).get(rk, 0))
		var pre: Array = []
		if cls_bonus != 0:
			pre.append({"text": "%s  %s" % [L.t("ui.stat_explain.r_class"), StatExplain._pct(cls_bonus)], "tone": StatExplain._tone(cls_bonus)})
		g3.append(_entry(sec, pre, StatExplain._tone(tot)))
	groups.append({"title": L.t("ui.bonus.g_resist"), "entries": g3, "inactive": off3})
	# 4. capacités des objets rares (+ ensemble mythique)
	var g4: Array = []
	var off4: Array = []
	for pk in PERKS:
		var sec := StatExplain.data(c, cfg, "perk_" + pk)
		if Rarity.perk_sum(c, pk) > 0:
			g4.append(_entry(sec))
		else:
			off4.append(L.t(str(Rarity.PERK_NAMES[pk])))
	var mythic := 0
	for slot in Characters.SLOTS:
		if Rarity.of((c.get("equipment", {}) as Dictionary).get(slot)) == "mythic":
			mythic += 1
	g4.append({"icon": "🔴", "label": L.t("ui.bonus.set_mythic"), "value": L.fa(L.t("ui.bonus.set_progress"), mythic), "tone": "pos" if mythic >= 2 else "dim",
		"subs": [{"text": L.t("ui.bonus.set_rule"), "tone": "dim"}]})
	groups.append({"title": L.t("ui.bonus.g_perks"), "entries": g4, "inactive": off4})
	# 5. talents choisis
	var g5: Array = []
	for t in c.get("talents", []):
		var opt := Talents.find_option(cfg, str(t.get("id", "")))
		if opt.is_empty():
			continue
		g5.append({"icon": str(opt.get("icon", "")), "label": str(opt.get("labelFr", t.get("id", ""))), "value": "", "tone": "pos",
			"subs": [{"text": Talents.effect_label(opt.get("effects", {})), "tone": "pos"}]})
	groups.append({"title": L.t("ui.bonus.g_talents"), "entries": g5, "inactive": []})
	# 6. statuts actifs
	var g6: Array = []
	for e in Statuses.active(c):
		var subs: Array = []
		for line in Statuses.effect_lines(e):
			subs.append({"text": "• " + str(line), "tone": "dim"})
		g6.append({"icon": Statuses.icon_of(e), "label": L.c(Statuses.label_of(e)), "value": L.fa(L.t("ui.party_tip.tours"), int(e.remaining)), "tone": "neg" if Statuses.is_harmful(e) else "pos",
			"subs": subs})
	groups.append({"title": L.t("ui.bonus.g_status"), "entries": g6, "inactive": []})
	# 7. classe, Constitution et partie en cours
	var g7: Array = []
	var con_over := maxi(0, int(c.get("effCon", 10)) - 10)
	if con_over > 0:
		g7.append({"icon": "🛡️", "label": L.t("common.constitution"), "value": "+%d" % con_over, "tone": "pos", "subs": [
			{"text": L.fa(L.t("ui.bonus.con_regen"), ("%.1f" % (con_over * 0.1)).replace(".", L.t("ui.instinct.decimal"))), "tone": "dim"}, {"text": L.fa(L.t("ui.bonus.con_instinct"), con_over), "tone": "dim"}]})
	if ["Prêtre", "Druide"].has(ExploreRegen.family(cfg, c)):
		g7.append({"icon": "✚", "label": L.t("ui.bonus.healer"), "value": "×%s" % str(ExploreRegen.HEALER_BONUS).replace(".", L.t("ui.instinct.decimal")), "tone": "pos", "subs": [{"text": L.t("ui.bonus.healer_rule"), "tone": "dim"}]})
	if bool(c.get("hpDoubleStart", false)):
		g7.append({"icon": "💀", "label": L.t("ui.bonus.hardcore"), "value": "×2 " + L.t("common.pv"), "tone": "pos", "subs": [{"text": L.t("ui.bonus.hardcore_rule"), "tone": "dim"}]})
	for mid in cfg.get("runModifierIds", []):
		for mod in DungeonGenerator.run_modifiers() + Unlocks.unlocked_modifiers():
			if str(mod.id) == str(mid):
				g7.append({"icon": str(mod.icon), "label": str(mod.labelFr), "value": "", "tone": "dim", "subs": [{"text": str(mod.descFr), "tone": "dim"}]})
	groups.append({"title": L.t("ui.bonus.g_party"), "entries": g7, "inactive": []})
	return groups
