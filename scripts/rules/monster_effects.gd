class_name MonsterEffects
extends RefCounted
## Effet (statut) que les coups d'un monstre peuvent infliger aux héros, selon sa famille. Un monstre ne l'a pas toujours : à la génération du niveau,
## chaque monstre qui en a la possibilité le reçoit avec la chance réglée dans l'administration (`monsterStatusChancePct`), les boss presque toujours.
## Champs posés sur le monstre : hitStatus (type de statut), hitStatusLook ("sleep" pour le sommeil), hitStatusChance (% par coup), hitStatusDuration (tours), hitStatusPower.

## icône de la famille → [statut, aspect, chance par coup (%), durée (tours)]. Les familles absentes (rat, gobelin, loup, orc, gnoll, squelette, homme-lézard) n'ont rien.
const FAMILY := {
	"mon_spider": ["poison", "", 35, 3], "mon_naga": ["poison", "", 35, 3], "mon_zombie": ["poison", "", 30, 3], "mon_werewolf": ["poison", "", 35, 3],
	"mon_mummy": ["weaken", "", 40, 3], "mon_cultist": ["weaken", "", 35, 3],
	"mon_skeletonarcher": ["slow", "", 35, 2], "mon_mudgolem": ["slow", "", 35, 2], "mon_slime": ["slow", "", 40, 2],
	"mon_ghost": ["lifedrain", "", 35, 3],
	"mon_gargoyle": ["stun", "", 20, 1], "mon_stonegolem": ["stun", "", 20, 1], "mon_troll": ["stun", "", 20, 1], "mon_ogre": ["stun", "", 20, 1],
	"mon_minotaur": ["stun", "", 20, 1], "mon_mimic": ["stun", "", 25, 1],
	"mon_elemental": ["burn", "", 40, 3], "mon_imp": ["burn", "", 30, 2], "mon_drake": ["burn", "", 35, 3], "mon_darkpanther": ["burn", "", 30, 2],
	"mon_iceelemental": ["freeze", "", 25, 1],
	"mon_harpy": ["warcry", "", 35, 2],
	"mon_beholder": ["stun", "sleep", 30, 2],      # œil hypnotique : sommeil (ou gel, tiré à la génération)
}

## Boss : toujours un effet, plus fréquent et plus long.
const BOSS := {
	"boss_dragon": ["burn", "", 50, 3], "boss_demonlord": ["warcry", "", 50, 3], "boss_troll": ["stun", "", 40, 1], "boss_lich": ["freeze", "", 40, 2],
	"boss_kraken": ["slow", "", 50, 3], "boss_golem": ["stun", "", 40, 1], "boss_spider": ["poison", "", 55, 4], "boss_wraith": ["lifedrain", "", 50, 3],
}

## Champs d'effet pour une famille (icône sans le préfixe « @icon: »). `depth` : étage, pour la puissance des dégâts sur la durée.
## `always` : le monstre l'a à coup sûr (boss) ; sinon `chance_pct` % de chances de l'avoir. Renvoie {} si aucun effet.
static func roll(icon_id: String, is_boss: bool, chance_pct: float, always: bool, depth: int) -> Dictionary:
	var row: Array = (BOSS if is_boss else FAMILY).get(icon_id, [])
	if row.is_empty():
		return {}
	if not always and randf() * 100.0 >= chance_pct:
		return {}
	var type: String = row[0]
	var look: String = row[1]
	if icon_id == "mon_beholder" and randf() < 0.5:
		type = "freeze"
		look = ""
	return {"hitStatus": type, "hitStatusLook": look, "hitStatusChance": int(row[2]), "hitStatusDuration": int(row[3]), "hitStatusPower": 2 + depth / 3}

## Sort factice décrivant l'effet d'un monstre, pour `Statuses.apply_from_spell`. Vide si le monstre n'en a pas.
static func spell_of(def: Dictionary) -> Dictionary:
	var type := str(def.get("hitStatus", ""))
	if type == "":
		return {}
	return {"statusEffect": type, "statusChance": 100, "statusDuration": int(def.get("hitStatusDuration", 2)),
		"statusPower": int(def.get("hitStatusPower", 2)), "statusLook": str(def.get("hitStatusLook", ""))}

## Libellé court (« Poison, 35 %, 3 tours ») pour la fiche du monstre.
static func describe(def: Dictionary) -> String:
	if str(def.get("hitStatus", "")) == "":
		return ""
	return L.fa(L.t("ui.monster_info_modal.inflige"), [Statuses.icon_of({"type": def.hitStatus, "look": def.get("hitStatusLook", "")}),
		Statuses.label_of({"type": def.hitStatus, "look": def.get("hitStatusLook", "")}), int(def.get("hitStatusChance", 0)), int(def.get("hitStatusDuration", 1))])
