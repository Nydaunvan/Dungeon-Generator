class_name Talents
extends RefCounted
## Talents (un choix à 2 options tous les 5 niveaux) et évolution de classe. Les choix en attente sont empilés dans
## `gs.choice_queue` ({kind: "talent"|"evolve", char_id, level}) et présentés par le jeu hors combat.

const LEVELS := [5, 10, 15, 20, 25]
const ZERO := {"bonusForce": 0, "bonusDex": 0, "bonusCon": 0, "bonusInt": 0, "bonusHp": 0, "bonusStamina": 0, "bonusAtkMin": 0,
	"bonusAtkMax": 0, "bonusSpellDmg": 0, "critChance": 0, "lifestealPct": 0, "resistPhys": 0, "resistMagic": 0}

static func source(cfg: Dictionary) -> Dictionary:
	var s = cfg.get("classTalents")
	return s if s is Dictionary and not (s as Dictionary).is_empty() else Data.class_talents

static func tracks(cfg: Dictionary, class_id: String) -> Array:
	return source(cfg).get(class_id, [])

static func find_option(cfg: Dictionary, id: String) -> Dictionary:
	var src := source(cfg)
	for cid in src:
		for track in src[cid]:
			for o in track.options:
				if str(o.id) == id:
					return o
	return {}

## Somme des effets des talents choisis par le personnage.
static func bonus(c: Dictionary, cfg: Dictionary) -> Dictionary:
	var acc := ZERO.duplicate()
	for ch in c.get("talents", []):
		var opt := find_option(cfg, str(ch.get("id", "")))
		for k in opt.get("effects", {}):
			acc[k] = int(acc.get(k, 0)) + int(opt.effects[k])
	return acc

static func effect_label(e: Dictionary) -> String:
	var p: Array = []
	for pair in [["bonusForce", L.t("common.force")], ["bonusDex", L.t("common.dexterite")], ["bonusCon", L.t("common.constitution")], ["bonusInt", L.t("common.intelligence")],
			["critChance", L.t("rules.talents.chances_de_coup_critique")], ["lifestealPct", L.t("rules.talents.des_degats_infliges_restaures")],
			["resistPhys", L.t("rules.talents.resistance_physique")], ["resistMagic", L.t("rules.talents.resistance_magique")], ["bonusSpellDmg", L.t("rules.talents.degats_soin_de_sort")],
			["bonusHp", "PV max"], ["bonusStamina", L.t("common.endurance_max")], ["bonusAtkMin", L.t("rules.talents.degats_min")], ["bonusAtkMax", L.t("rules.talents.degats_max")]]:
		if int(e.get(pair[0], 0)) != 0:
			p.append("+%d %s" % [int(e[pair[0]]), pair[1]])
	return ", ".join(p)

static func respec_cost(cfg: Dictionary, level: int) -> int:
	var base := int(cfg.get("talentMasterBaseCost", 80))
	return int(round(base * (maxi(0, LEVELS.find(level)) + 1)))

## Un choix de talent est-il déjà empilé pour ce palier ?
static func _queued(gs: GameState, kind: String, id: String, level: int) -> bool:
	for q in gs.choice_queue:
		if q.kind == kind and str(q.char_id) == id and int(q.level) == level:
			return true
	return false

## À appeler après une montée de niveau ou un changement de classe.
static func check_unlock(gs: GameState, c: Dictionary) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var evo: Array = cls.get("evolvesTo", [])
	if not evo.is_empty() and not bool(c.get("_evolutionPending", false)) and int(c.level) >= int(cls.get("evolveLevel", 99)):
		c["_evolutionPending"] = true
		gs.choice_queue.append({"kind": "evolve", "char_id": str(c.id), "level": int(c.level)})
	var chosen := {}
	for t in c.get("talents", []):
		chosen[int(t.level)] = true
	for track in tracks(gs.cfg, str(c.get("classId", ""))):
		var lv := int(track.level)
		if int(c.level) >= lv and not chosen.has(lv) and not _queued(gs, "talent", str(c.id), lv):
			gs.choice_queue.append({"kind": "talent", "char_id": str(c.id), "level": lv})

static func track_at(cfg: Dictionary, class_id: String, level: int) -> Dictionary:
	for track in tracks(cfg, class_id):
		if int(track.level) == level:
			return track
	return {}

static func choose(gs: GameState, c: Dictionary, level: int, talent_id: String) -> void:
	if not c.has("talents"):
		c["talents"] = []
	for t in c.talents:
		if int(t.level) == level:
			return
	c.talents.append({"level": level, "id": talent_id})
	Characters.recompute(c, gs.cfg)
	var opt := find_option(gs.cfg, talent_id)
	gs.add_log(L.fa(L.t("rules.talents.choisit_le_talent"), [c.name, opt.get("icon", ""), opt.get("labelFr", "")]))

## Change un talent déjà choisi contre de l'or. Renvoie "" si réussi, sinon le motif.
static func respec(gs: GameState, c: Dictionary, level: int, new_id: String) -> String:
	var idx := -1
	for i in c.get("talents", []).size():
		if int(c.talents[i].level) == level:
			idx = i
	if idx < 0:
		return L.t("rules.talents.aucun_talent_a_changer")
	var cost := respec_cost(gs.cfg, level)
	if gs.gold < cost:
		gs.add_log(L.t("rules.talents.pas_assez_or_pour_changer"))
		return L.t("rules.talents.pas_assez_or_pour_changer_2")
	gs.gold -= cost
	gs.stats["goldSpentTotal"] = int(gs.stats.get("goldSpentTotal", 0)) + cost
	c.talents[idx]["id"] = new_id
	Characters.recompute(c, gs.cfg)
	var opt := find_option(gs.cfg, new_id)
	gs.add_log(L.fa(L.t("rules.talents.choisit_le_talent_cout_or"), [c.name, opt.get("icon", ""), opt.get("labelFr", ""), cost]))
	return ""

static func evolve(gs: GameState, c: Dictionary, class_id: String) -> void:
	var cls := Characters.class_def(gs.cfg, class_id)
	c["classId"] = class_id
	c["icon"] = cls.get("icon", c.get("icon", ""))
	c["_evolutionPending"] = false
	Characters.recompute(c, gs.cfg)
	Sound.sfx("evolve")
	gs.add_log(L.fa(L.t("rules.talents.evolue_en"), [c.name, cls.get("icon", ""), cls.get("name", "")]))
	check_unlock(gs, c)
