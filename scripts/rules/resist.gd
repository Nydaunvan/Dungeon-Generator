class_name Resist
extends RefCounted
## Résistances par école : physique, feu, glace, nature, sacré, ombre (l'arcane compte comme l'ombre). Valeur en % : positive = résiste, négative = faiblesse.
## Monstres : `resists` {clé: %} sur la fiche du monstre, tirées à la génération selon la famille. Héros : bonus de classe + `resists` des objets équipés.
## Elles s'ajoutent à la résistance physique / magique déjà existante (`resistPhys`, `resistMagic`).

const KEYS := ["phys", "fire", "ice", "nature", "holy", "shadow"]
const ICONS := {"phys": "⚔️", "fire": "🔥", "ice": "❄️", "nature": "🌿", "holy": "✨", "shadow": "🌑"}
const NAME_KEYS := {"phys": "rules.resist.nom_phys", "fire": "rules.resist.nom_fire", "ice": "rules.resist.nom_ice", "nature": "rules.resist.nom_nature",
	"holy": "rules.resist.nom_holy", "shadow": "rules.resist.nom_shadow"}
const ITEM_KEYS := {"phys": "rules.resist.item_phys", "fire": "rules.resist.item_fire", "ice": "rules.resist.item_ice", "nature": "rules.resist.item_nature",
	"holy": "rules.resist.item_holy", "shadow": "rules.resist.item_shadow"}
const MIN_PCT := -50
const MAX_PCT := 90
## École d'un sort → clé de résistance. Les sorts de barde (musique) n'en ont pas : seule la résistance magique joue.
const STYLE_KEY := {"physical": "phys", "fire": "fire", "ice": "ice", "nature": "nature", "holy": "holy", "shadow": "shadow", "arcane": "shadow"}

## Bonus (et petites faiblesses) de chaque classe de héros.
const CLASS_RESISTS := {
	"class_warrior": {"phys": 15}, "class_berserker": {"phys": 20, "ice": -10}, "class_paladin": {"phys": 10, "holy": 20}, "class_crusader": {"phys": 10, "holy": 20, "shadow": -10},
	"class_archer": {"phys": 5, "nature": 10}, "class_magearcher": {"nature": 10, "shadow": 10, "phys": -10},
	"class_rogue": {}, "class_bladedancer": {}, "class_thief": {}, "class_assassin": {"shadow": 10},
	"class_mage": {"shadow": 15, "phys": -10}, "class_elementalist": {"fire": 15, "ice": 15, "phys": -10}, "class_warlock": {"shadow": 20, "holy": -15},
	"class_priest": {"holy": 15, "shadow": 10}, "class_cleric": {"holy": 20, "shadow": 10},
	"class_bard": {}, "class_skald": {"phys": 10}, "class_minstrel": {},
	"class_druid": {"nature": 20, "fire": -10}, "class_warden": {"nature": 25}, "class_stormcaller": {"nature": 25, "ice": 10, "fire": -10},
}

## Monstres, par icône de famille : {clé: [min, max]} (négatif = faiblesse). Rats, gobelins, orcs, gnolls, ogres : rien.
const FAMILY := {
	"mon_elemental": {"fire": [50, 80], "ice": [-50, -25]}, "mon_drake": {"fire": [40, 70], "ice": [-40, -25]},
	"mon_imp": {"fire": [40, 60], "holy": [-40, -25]}, "mon_darkpanther": {"fire": [25, 45], "ice": [-35, -20]},
	"mon_iceelemental": {"ice": [50, 80], "fire": [-50, -25]},
	"mon_skeleton": {"shadow": [40, 60], "phys": [20, 35], "holy": [-50, -25]}, "mon_fossoyeur": {"shadow": [15, 30], "phys": [10, 20], "holy": [-30, -15]}, "mon_veuve": {"shadow": [25, 40], "nature": [10, 25], "holy": [-45, -25], "fire": [-40, -20]}, "mon_porte_cercueil": {"shadow": [30, 45], "phys": [20, 35], "holy": [-45, -25], "fire": [-35, -15]}, "mon_veilleur_os": {"shadow": [40, 60], "phys": [25, 40], "holy": [-50, -25]}, "mon_skeletonarcher": {"shadow": [40, 60], "phys": [20, 35], "holy": [-50, -25]},
	"mon_zombie": {"shadow": [30, 50], "holy": [-50, -25], "fire": [-30, -15]}, "mon_mummy": {"shadow": [30, 50], "fire": [-50, -30], "holy": [-40, -20]},
	"mon_ghost": {"phys": [50, 75], "shadow": [40, 60], "holy": [-50, -30]},
	"mon_stonegolem": {"phys": [40, 60], "shadow": [-40, -25]}, "mon_mudgolem": {"phys": [30, 45], "shadow": [-40, -25]}, "mon_gargoyle": {"phys": [40, 60], "shadow": [-40, -25]},
	"mon_spider": {"nature": [20, 40], "fire": [-45, -25]}, "mon_naga": {"nature": [30, 50], "ice": [-40, -25]},
	"mon_werewolf": {"shadow": [20, 40], "fire": [-35, -20]}, "mon_wolf": {"fire": [-30, -15]},
	"mon_cultist": {"shadow": [30, 50], "holy": [-45, -25]}, "mon_harpy": {"nature": [-40, -25]}, "mon_mimic": {"phys": [25, 40]},
	"mon_troll": {"phys": [15, 30], "fire": [-45, -25]}, "mon_lizardman": {"fire": [20, 40], "ice": [-40, -25]},
	"mon_beholder": {"shadow": [40, 60], "phys": [-30, -15]}, "mon_slime": {"phys": [40, 60], "fire": [-35, -20]},
	"mon_minotaur": {"phys": [10, 25]},
}

const BOSS := {
	"boss_dragon": {"fire": [60, 85], "ice": [-45, -30]}, "boss_demonlord": {"fire": [40, 60], "shadow": [40, 60], "holy": [-50, -35]},
	"boss_troll": {"phys": [30, 45], "fire": [-45, -30]}, "boss_lich": {"shadow": [60, 80], "ice": [30, 50], "holy": [-50, -35]},
	"boss_kraken": {"fire": [40, 60], "nature": [-45, -30]}, "boss_golem": {"phys": [50, 70], "shadow": [-45, -30]},
	"boss_spider": {"nature": [40, 60], "fire": [-50, -35]}, "boss_wraith": {"phys": [60, 80], "shadow": [50, 70], "holy": [-50, -35]},
}

static func style_key(style: String) -> String:
	return str(STYLE_KEY.get(style, ""))

## Résistances tirées pour un monstre : {"resists": {...}} (vide si la famille n'en a pas). Toutes les écoles de la famille sont présentes, avec
## une valeur au hasard dans sa fourchette, jamais zéro. `always` à faux : tirage de chance (`chance_pct`), non utilisé par le générateur.
static func roll(icon_id: String, is_boss: bool, chance_pct: float, always: bool) -> Dictionary:
	var row: Dictionary = (BOSS if is_boss else FAMILY).get(icon_id, {})
	if row.is_empty() or (not always and randf() * 100.0 >= chance_pct):
		return {}
	var out := {}
	for k in row.keys():
		out[k] = randi_range(int(row[k][0]), int(row[k][1]))
	return {"resists": out}

## Résistance (%) d'une fiche de monstre à une école (0 si aucune).
static func of_monster(def: Dictionary, key: String) -> int:
	if key == "":
		return 0
	var r = def.get("resists")
	return int((r as Dictionary).get(key, 0)) if r is Dictionary else 0

## Résistances d'un héros : bonus de classe + `resists` des objets équipés. {clé: %} (clés à 0 absentes).
static func hero(c: Dictionary) -> Dictionary:
	var out: Dictionary = (CLASS_RESISTS.get(str(c.get("classId", "")), {}) as Dictionary).duplicate()
	for slot in Characters.SLOTS:
		var it = (c.get("equipment", {}) as Dictionary).get(slot)
		if it is Dictionary and it.get("resists") is Dictionary:
			for k in (it.resists as Dictionary).keys():
				out[k] = int(out.get(k, 0)) + int((it.resists as Dictionary)[k])
	for k in out.keys():
		if int(out[k]) == 0:
			out.erase(k)
		else:
			out[k] = clampi(int(out[k]), MIN_PCT, MAX_PCT)
	return out

static func of_hero(c: Dictionary, key: String) -> int:
	return int(hero(c).get(key, 0)) if key != "" else 0

## « 🔥 +50 % · ❄️ −40 % » pour les fiches (vide si aucune résistance).
static func summary(res: Dictionary) -> String:
	var parts: Array[String] = []
	for k in KEYS:
		var v := int(res.get(k, 0))
		if v != 0:
			parts.append("%s %s%d %%" % [ICONS[k], "+" if v > 0 else "−", absi(v)])
	return " · ".join(parts)

## Objets : résistance élémentaire d'une armure ou d'un bijou de rareté épique ou plus.
static func roll_item(item: Dictionary, tier: String, f: Callable) -> void:
	item.erase("resists")
	if not ["epic", "legendary", "mythic"].has(tier) or not ["armor", "jewelry"].has(str(item.get("type", ""))):
		return
	var lo := 10
	var hi := 15
	if tier == "legendary":
		lo = 15
		hi = 22
	elif tier == "mythic":
		lo = 20
		hi = 30
	var picks := 2 if tier == "mythic" else 1
	var pool: Array = KEYS.duplicate()
	var res := {}
	for i in picks:
		var idx := mini(pool.size() - 1, int(float(f.call()) * pool.size()))
		var key: String = pool.pop_at(idx)
		res[key] = lo + int(float(f.call()) * (hi - lo + 1))
	item["resists"] = res
