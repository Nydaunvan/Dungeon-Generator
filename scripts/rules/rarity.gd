class_name Rarity
extends RefCounted
## Raretés des objets d'équipement : commun, inhabituel, rare, épique, légendaire, mythique.
## Chaque palier multiplie les bonus de l'objet et lui donne des capacités (`perks` : [{id, value}]).
## Un objet sans champ `rarity` est commun, sauf s'il porte l'ancien indicateur `legendary` (alors légendaire) : aucune migration.

const ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

## color : nom et bordure · mult : bonus de caractéristiques · price : multiplicateur de prix · key : nom du palier (langue).
const DEF := {
	"common": {"color": "b8b2a4", "mult": 1.0, "price": 1.0, "key": "rules.rarity.commun"},
	"uncommon": {"color": "6fcf6f", "mult": 1.15, "price": 1.5, "key": "rules.rarity.inhabituel"},
	"rare": {"color": "5aa9ff", "mult": 1.3, "price": 2.5, "key": "rules.rarity.rare"},
	"epic": {"color": "b36bff", "mult": 1.5, "price": 4.0, "key": "rules.rarity.epique"},
	"legendary": {"color": "ffa83d", "mult": 1.7, "price": 7.0, "key": "rules.rarity.legendaire"},
	"mythic": {"color": "ff5a4d", "mult": 2.0, "price": 12.0, "key": "rules.rarity.mythique"},
}

## Capacités tirables par palier : {id, lo, hi}. Épique et mythique en cumulent deux (voir `_tiers_for_perks`).
const POOLS := {
	"uncommon": [{"id": "crit", "lo": 2, "hi": 4}, {"id": "dodge", "lo": 2, "hi": 4}, {"id": "gold", "lo": 5, "hi": 10}],
	"rare": [{"id": "lifesteal", "lo": 3, "hi": 6}, {"id": "thorns", "lo": 5, "hi": 10}, {"id": "spell", "lo": 6, "hi": 12}, {"id": "crit", "lo": 5, "hi": 8}],
	"epic": [{"id": "execute", "lo": 15, "hi": 30}, {"id": "bleed", "lo": 15, "hi": 25}, {"id": "critdmg", "lo": 25, "hi": 50}, {"id": "lifesteal", "lo": 7, "hi": 11}],
	"legendary": [{"id": "lifesteal", "lo": 12, "hi": 20}, {"id": "crit", "lo": 15, "hi": 25}, {"id": "thorns", "lo": 12, "hi": 20}, {"id": "last_stand", "lo": 1, "hi": 1}],
}

## Libellé de chaque capacité (une clé de langue avec un seul « %d », sauf `last_stand`).
const PERK_KEYS := {
	"crit": "rules.rarity.perk_crit", "dodge": "rules.rarity.perk_dodge", "gold": "rules.rarity.perk_gold",
	"lifesteal": "rules.rarity.perk_lifesteal", "thorns": "rules.rarity.perk_thorns", "spell": "rules.rarity.perk_spell",
	"execute": "rules.rarity.perk_execute", "bleed": "rules.rarity.perk_bleed", "critdmg": "rules.rarity.perk_critdmg",
	"last_stand": "rules.rarity.perk_last_stand",
}

## Nom court de chaque capacité (éditeur de l'administration).
const PERK_NAMES := {
	"crit": "rules.rarity.nom_crit", "dodge": "rules.rarity.nom_dodge", "gold": "rules.rarity.nom_gold", "lifesteal": "rules.rarity.nom_lifesteal",
	"thorns": "rules.rarity.nom_thorns", "spell": "rules.rarity.nom_spell", "execute": "rules.rarity.nom_execute", "bleed": "rules.rarity.nom_bleed",
	"critdmg": "rules.rarity.nom_critdmg", "last_stand": "rules.rarity.nom_last_stand",
}

# ------------------------------------------------------------------ lecture

static func of(it) -> String:
	if it == null or not (it is Dictionary):
		return "common"
	var r := str(it.get("rarity", ""))
	if DEF.has(r):
		return r
	return "legendary" if bool(it.get("legendary", false)) else "common"

static func index(id: String) -> int:
	return maxi(0, ORDER.find(id))

static func color(it) -> Color:
	return Color(str(DEF[of(it)].color))

static func tier_color(id: String) -> Color:
	return Color(str((DEF.get(id, DEF.common) as Dictionary).color))

static func label(it) -> String:
	return L.t(str(DEF[of(it)].key))

static func is_special(it) -> bool:
	return of(it) != "common"

static func price_mult(it) -> float:
	return float(DEF[of(it)].price)

## Capacités d'un objet : celles de `perks`, sinon (objet légendaire d'avant les raretés ou créé dans l'administration) l'ancien couple bonus / valeur.
static func perks_of(it) -> Array:
	if it == null or not (it is Dictionary):
		return []
	if it.get("perks") is Array and not (it.perks as Array).is_empty():
		return it.perks
	if bool(it.get("legendary", false)) and str(it.get("legendaryPerk", "")) != "":
		return [{"id": str(it.legendaryPerk), "value": int(it.get("legendaryValue", 0))}]
	return []

static func perk_line(p: Dictionary) -> String:
	var id := str(p.get("id", ""))
	if not PERK_KEYS.has(id):
		return id
	if id == "last_stand":
		return L.t(PERK_KEYS[id])
	return L.fa(L.t(PERK_KEYS[id]), int(p.get("value", 0)))

## Lignes d'infobulle d'un objet : « Rare » puis ses capacités.
static func lines(it) -> Array:
	var out: Array = []
	for p in perks_of(it):
		out.append(perk_line(p))
	return out

## Capacités actives d'un personnage : [{perk, value, item}] sur tout son équipement, plus l'effet d'ensemble mythique (2 pièces ou plus : +10 % critique).
static func equipped_perks(c: Dictionary) -> Array:
	var out: Array = []
	var eq: Dictionary = c.get("equipment", {})
	var mythic := 0
	for slot in Characters.SLOTS:
		var it = eq.get(slot)
		if it == null:
			continue
		if of(it) == "mythic":
			mythic += 1
		for p in perks_of(it):
			out.append({"perk": str(p.id), "value": int(p.get("value", 0)), "item": it})
	if mythic >= 2:
		out.append({"perk": "crit", "value": 10, "item": null})
	return out

static func perk_sum(c: Dictionary, perk: String) -> int:
	var total := 0
	for p in equipped_perks(c):
		if p.perk == perk:
			total += int(p.value)
	return total

# ------------------------------------------------------------------ tirage

## Poids de chaque palier selon l'origine de l'objet. `source` : floor, monster, boss, reward, shop, village. Plus on descend, plus la partie
## est avancée et plus la difficulté est haute, plus les paliers élevés sont fréquents.
static func weights(source: String, depth: int, run_bonus: int, difficulty: String) -> Dictionary:
	var w: Dictionary
	match source:
		"monster": w = {"common": 56.0, "uncommon": 28.0, "rare": 14.0, "epic": 2.0}
		"boss": w = {"rare": 60.0, "epic": 40.0}
		"reward": w = {"rare": 50.0, "epic": 50.0}
		"deal": w = {"rare": 75.0, "epic": 25.0}     # belle affaire chez le marchand
		"shop": w = {"common": 55.0, "uncommon": 33.0, "rare": 11.0, "epic": 1.0}
		"village": w = {"common": 45.0, "uncommon": 35.0, "rare": 16.0, "epic": 4.0}
		_: w = {"common": 71.0, "uncommon": 22.0, "rare": 6.5, "epic": 0.5}
	var diff_mult := {"easy": 0.85, "hard": 1.15, "hardcore": 1.3}.get(difficulty, 1.0) as float
	var scale := minf(2.0, 1.0 + 0.12 * depth + 0.2 * run_bonus) * diff_mult
	for k in w.keys():
		var i := index(k)
		if i >= 1 and source != "boss" and source != "reward" and source != "deal":
			w[k] = float(w[k]) * pow(scale, 1.0 + 0.5 * (i - 1))
	return w

## Tire un palier. `f` : fonction sans argument renvoyant un flottant dans [0, 1[ (le flux aléatoire de l'appelant).
static func roll(w: Dictionary, f: Callable) -> String:
	var total := 0.0
	for k in w.keys():
		total += float(w[k])
	var r := float(f.call()) * total
	for k in ORDER:
		if not w.has(k):
			continue
		r -= float(w[k])
		if r < 0.0:
			return k
	return ORDER[0]

static func _pick(tier: String, f: Callable, taken: Array) -> Dictionary:
	var pool: Array = (POOLS.get(tier, []) as Array).filter(func(p): return not taken.has(p.id))
	if pool.is_empty():
		pool = POOLS.get(tier, [])
	if pool.is_empty():
		return {}
	var e: Dictionary = pool[mini(pool.size() - 1, int(float(f.call()) * pool.size()))]
	return {"id": e.id, "value": int(e.lo) + int(float(f.call()) * (int(e.hi) - int(e.lo) + 1))}

## Paliers dont on tire une capacité pour chaque rareté.
static func _tiers_for_perks(tier: String) -> Array:
	match tier:
		"uncommon": return ["uncommon"]
		"rare": return ["rare"]
		"epic": return ["epic", "uncommon"]
		"legendary": return ["legendary"]
		"mythic": return ["legendary", "epic"]
	return []

const _SCALED := ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg", "bonusForce", "bonusDex", "bonusCon", "bonusInt"]

## Fait de `item` (généré commun) un objet de ce palier : bonus multipliés, capacités tirées.
static func apply(item: Dictionary, tier: String, f: Callable) -> Dictionary:
	if tier == "common" or not DEF.has(tier):
		return item
	_scale(item, float(DEF[tier].mult))
	_set_perks(item, tier, f)
	return item

## Remonte un objet déjà tiré à un palier supérieur (bonus multipliés de l'écart, capacités du nouveau palier).
static func upgrade_to(item: Dictionary, tier: String, f: Callable) -> Dictionary:
	var cur := of(item)
	if index(tier) <= index(cur):
		return item
	_scale(item, float(DEF[tier].mult) / float(DEF[cur].mult))
	_set_perks(item, tier, f)
	return item

static func _scale(item: Dictionary, ratio: float) -> void:
	for k in _SCALED:
		var v := int(item.get(k, 0))
		if v > 0:
			item[k] = maxi(v + 1, int(round(v * ratio)))

static func _set_perks(item: Dictionary, tier: String, f: Callable) -> void:
	item["rarity"] = tier
	var perks: Array = []
	var taken: Array = []
	for t in _tiers_for_perks(tier):
		var p := _pick(t, f, taken)
		if not p.is_empty():
			perks.append(p)
			taken.append(p.id)
	item["perks"] = perks
	if tier == "legendary" or tier == "mythic":
		item["legendary"] = true
		if not perks.is_empty():
			item["legendaryPerk"] = perks[0].id    # compatibilité (éditeur de l'administration, anciennes lectures)
			item["legendaryValue"] = perks[0].value
	else:
		item.erase("legendary")
		item.erase("legendaryPerk")
		item.erase("legendaryValue")
