class_name Statuses
extends RefCounted
## Statuts (poison, brûlure, étourdissement, célérité…) — portage de STATUS_DEFS, tryApplyStatusFromSpell
## et des ticks du HTML. Un statut : {"type", "remaining", "power", "casterId"}.

static func defs() -> Dictionary:
	return Data.constants.get("STATUS_DEFS", {})

static func def(type: String) -> Dictionary:
	return defs().get(type, {})

## Statuts encore actifs (durée restante > 0 et type connu), du plus prioritaire au moins prioritaire.
const PRIORITY := ["freeze", "stun", "burn", "poison", "lifedrain", "weaken", "warcry", "slow", "haste", "vigor", "weaponfire"]

static func active(holder: Dictionary) -> Array:
	var out: Array = []
	for e in holder.get("statusEffects", []):
		if int(e.get("remaining", 0)) > 0 and not def(str(e.type)).is_empty():
			out.append(e)
	out.sort_custom(func(a, b): return PRIORITY.find(str(a.type)) < PRIORITY.find(str(b.type)))
	return out

static func has(holder: Dictionary, type: String) -> bool:
	for e in active(holder):
		if str(e.type) == type:
			return true
	return false

## Étourdi / gelé : ne peut pas agir.
static func is_disabled(holder: Dictionary) -> bool:
	for e in active(holder):
		if bool(def(str(e.type)).get("disables", false)):
			return true
	return false

static func speed_bonus(holder: Dictionary) -> int:
	var total := 0
	for e in active(holder):
		total += int(def(str(e.type)).get("speedBonus", 0))
	return total

static func flat_damage_bonus(holder: Dictionary) -> int:
	for e in active(holder):
		var b := int(def(str(e.type)).get("bonusDmgFlat", 0))
		if b > 0:
			return b
	return 0

## Réduction (%) des dégâts infligés par un monstre affaibli / vulnérable.
static func damage_reduction_pct(holder: Dictionary) -> int:
	for e in active(holder):
		var p := int(def(str(e.type)).get("dmgReductionPct", 0))
		if p > 0:
			return p
	return 0

static func resist_reduction_pct(holder: Dictionary) -> int:
	for e in active(holder):
		var p := int(def(str(e.type)).get("resistReductionPct", 0))
		if p > 0:
			return p
	return 0

## Libellé de la pastille de portrait (gel, brûlure, poison) ou "".
static func badge_type(c: Dictionary) -> String:
	for t in ["freeze", "burn", "poison"]:
		if has(c, t):
			return t
	return ""

## Tente d'appliquer le statut d'un sort. `spell_override` permet de forcer type/durée (sommeil).
static func apply_from_spell(gs: GameState, spell: Dictionary, holder: Dictionary, display_name: String,
		caster_id: String, is_party: bool) -> bool:
	var type := str(spell.get("statusEffect", ""))
	var sdef := def(type)
	if type == "" or sdef.is_empty():
		return false
	if GameRng.f("combat") * 100.0 > float(spell.get("statusChance", 0)):
		return false
	var duration := maxi(1, int(spell.get("statusDuration", 3)))
	var power := maxi(1, int(spell.get("statusPower", 3)))
	if is_party and (bool(sdef.get("dot", false)) or bool(sdef.get("disables", false))) and has(holder, "vigor"):
		var cut := int(def("vigor").get("statusDurationCutPct", 0))
		if cut > 0:
			duration = maxi(1, int(round(duration * (1.0 - cut / 100.0))))
	var list: Array = holder.get("statusEffects", [])
	var found := false
	for e in list:
		if str(e.type) == type:
			e["remaining"] = duration
			e["power"] = power
			e["casterId"] = caster_id
			found = true
	if not found:
		list.append({"type": type, "remaining": duration, "power": power, "casterId": caster_id})
	holder["statusEffects"] = list
	gs.add_log(L.fa(L.t("rules.statuses.est_affecte_par"), [sdef.icon, display_name, sdef.label]), is_party)
	if is_party:
		Characters.recompute(holder, gs.cfg)
	return true

## Retire les statuts négatifs (dégâts sur la durée / incapacitants) — sort de dissipation.
static func dispel(holder: Dictionary) -> Array:
	var removed: Array = []
	var kept: Array = []
	for e in holder.get("statusEffects", []):
		var d := def(str(e.type))
		if not d.is_empty() and (bool(d.get("dot", false)) or bool(d.get("disables", false))):
			removed.append(str(d.label))
		else:
			kept.append(e)
	holder["statusEffects"] = kept
	return removed

static func give(holder: Dictionary, type: String, duration: int, caster_id: String) -> void:
	var list: Array = (holder.get("statusEffects", []) as Array).filter(func(e): return str(e.type) != type)
	list.append({"type": type, "remaining": duration, "power": 1, "casterId": caster_id})
	holder["statusEffects"] = list
