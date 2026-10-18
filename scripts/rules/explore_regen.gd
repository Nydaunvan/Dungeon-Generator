class_name ExploreRegen
extends RefCounted
## Régénération des PV en exploration (« second souffle ») : tous les N pas hors combat, chaque héros vivant regagne 1 % de ses PV max
## (au moins 1), jusqu'à 60 % de ses PV max. Fondée sur les pas, jamais sur le temps réel : rejeu et parties classées restent identiques.

const STEPS := {"easy": 6, "normal": 8, "hard": 12, "hardcore": 20}
const CAP_PCT := 60.0
const AFTER_COMBAT_STEPS := 2     # pas qui suivent un combat sans aucun gain
const TRAIL := 4                  # derniers pas mémorisés : revenir sur une case récente ne compte pas (pas de va-et-vient pour farmer)
const HEALER_BONUS := 1.25        # Prêtre / Druide et leurs évolutions

static func enabled(cfg: Dictionary) -> bool:
	return bool((cfg.get("staminaSettings", {}) as Dictionary).get("exploreRegen", true))

static func interval(difficulty: String) -> int:
	return int(STEPS.get(difficulty, STEPS.normal))

static func family(cfg: Dictionary, c: Dictionary) -> String:
	var cls := Characters.class_def(cfg, str(c.get("classId", "")))
	return str(cls.get("evolvesFrom", cls.get("name", "")))

## PV rendus à un héros pour une impulsion (0 si rien : mort, plein jusqu'au plafond, poison/brûlure).
static func gain_for(cfg: Dictionary, c: Dictionary) -> int:
	if int(c.get("hp", 0)) <= 0 or Statuses.has(c, "poison") or Statuses.has(c, "burn"):
		return 0
	var max_hp := int(c.get("maxHp", 1))
	var cap := int(floor(max_hp * CAP_PCT / 100.0))
	if int(c.hp) >= cap:
		return 0
	var mult := 1.0 + 0.001 * float(maxi(0, int(c.get("effCon", 10)) - 10))
	if ["Prêtre", "Druide"].has(family(cfg, c)):
		mult *= HEALER_BONUS
	var g := maxi(1, int(round(max_hp * 0.01 * mult)))
	return mini(g, cap - int(c.hp))

## Appelée après chaque pas (hors combat) ; renvoie {char_id: pv rendus} pour l'affichage. `cell` : case atteinte.
static func on_step(gs: GameState, cell: Vector2i, difficulty: String, in_combat: bool) -> Dictionary:
	var out := {}
	var trail: Array = gs.stats.get("regenTrail", [])
	var fresh := not trail.has([cell.x, cell.y])
	trail.append([cell.x, cell.y])
	while trail.size() > TRAIL:
		trail.pop_front()
	gs.stats["regenTrail"] = trail
	if in_combat or not enabled(gs.cfg):
		return out
	var cool := int(gs.stats.get("regenCooldown", 0))
	if cool > 0:
		gs.stats["regenCooldown"] = cool - 1
		return out
	if not fresh:
		return out
	var n := int(gs.stats.get("regenSteps", 0)) + 1
	if n < interval(difficulty):
		gs.stats["regenSteps"] = n
		return out
	gs.stats["regenSteps"] = 0
	for c in gs.alive_party():
		var g := gain_for(gs.cfg, c)
		if g > 0:
			c["hp"] = int(c.hp) + g
			out[str(c.id)] = g
	return out
