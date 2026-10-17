class_name Stats
extends RefCounted
## Formules de stats — portage fidèle de computeCharBase / computeMonsterDerived (JS).

static func char_base(c: Dictionary) -> Dictionary:
	var level: int = int(c.get("level", 1))
	var max_hp: int = 10 + int(c.get("con", 10)) * 3 + (level - 1) * 4
	var level_atk_bonus: int = (level - 1) / 2
	var atk_min: int = int(floor(int(c.get("force", 10)) / 3.0)) + level_atk_bonus
	var atk_max: int = atk_min + 2 + int(floor(int(c.get("dex", 10)) / 4.0))
	return {"maxHp": max_hp, "baseAtkMin": atk_min, "baseAtkMax": atk_max}

static func monster_derived(m: Dictionary) -> Dictionary:
	var max_hp: float = (5.0 + float(m.get("con", 8)) * 2.8) * float(m.get("hpMult", 1.0))       # hpMult : boss des donjons générés
	var atk_min: int = maxi(1, int(floor(float(m.get("force", 8)) / 2.5)))
	var atk_max: int = atk_min + 1 + int(floor(float(m.get("dex", 8)) / 3.3))
	var dm := float(m.get("dmgMult", 1.0))
	if dm != 1.0:
		atk_min = maxi(1, int(round(atk_min * dm)))
		atk_max = maxi(atk_min, int(round(atk_max * dm)))
	return {"maxHp": max_hp, "atkMin": atk_min, "atkMax": atk_max}


# ------------------------------------------------------------------ effets des caractéristiques (barème unique, affiché tel quel dans le jeu)
## Force : dégâts minimum (Force ÷ 3). Dextérité : dégâts maximum (Dex ÷ 4), plus critique et esquive (ci-dessous).
## Constitution : PV (10 + 3 × Con) et garde. Intelligence : puissance des sorts. Vitesse : fréquence des tours.
## Les bonus ne commencent qu'au-dessus de 10 : en dessous, une caractéristique faible ne pénalise pas davantage.

const CAP_REDUCTION := 75     ## réduction maximale de dégâts subis (%), garde et résistances cumulées
const CAP_CRIT := 25
const CAP_DODGE := 20
const CAP_GUARD := 25

## Chance de coup critique (%) apportée par la Dextérité : 1 % par point au-dessus de 10.
static func crit_from_dex(dex: int) -> int:
	return clampi(dex - 10, 0, CAP_CRIT)

## Chance d'esquiver l'attaque d'un monstre (%) : 0,8 % par point de Dextérité au-dessus de 10.
static func dodge_from_dex(dex: int) -> int:
	return clampi(int(floor((dex - 10) * 0.8)), 0, CAP_DODGE)

## Garde (%) : réduction de tous les dégâts subis, 1 % par point de Constitution au-dessus de 10.
static func guard_from_con(con: int) -> int:
	return clampi(con - 10, 0, CAP_GUARD)

## Puissance des sorts : +1 tous les 3 points d'Intelligence, après les 3 premiers points (Int 10 = +2). S'ajoute aux dégâts, soins, boucliers et restaurations.
static func spell_power(intel: int) -> int:
	return maxi(0, intel / 3 - 1)

## Vitesse d'un monstre : celle de sa fiche, sinon 8 modifiée par sa Dextérité (+1 tous les 3 points au-dessus de 9).
static func monster_speed(m: Dictionary) -> float:
	if m.has("speed") and m.speed != null:
		return maxf(1.0, round(float(m.speed)))
	return maxf(1.0, 8.0 + round((float(m.get("dex", 9)) - 9.0) / 3.0))

## Réduction (%) des dégâts physiques / magiques subis par un héros : résistance des talents + garde, plafonnée.
static func reduction(c: Dictionary, magic: bool) -> int:
	var r := int(c.get("resistMagic", 0)) if magic else int(c.get("resistPhys", 0))
	return clampi(r + int(c.get("guardPct", 0)), 0, CAP_REDUCTION)


## Décomposition d'une caractéristique pour l'affichage : {base, gear, talent, status, total}. `key` : force | dex | con | int | speed.
static func breakdown(c: Dictionary, cfg: Dictionary, key: String) -> Dictionary:
	var eq := Characters.equipped_bonus(c)
	var tal := Talents.bonus(c, cfg)
	match key:
		"force": return _bd(int(c.get("force", 10)), int(eq["bonusForce"]), int(tal.bonusForce), 0, int(c.get("effForce", 10)))
		"dex": return _bd(int(c.get("dex", 10)), int(eq["bonusDex"]), int(tal.bonusDex), 0, int(c.get("effDex", 10)))
		"con": return _bd(int(c.get("con", 10)), int(eq["bonusCon"]), int(tal.bonusCon), 0, int(c.get("effCon", 10)))
		"int": return _bd(int(c.get("int", 10)), int(eq["bonusInt"]), int(tal.bonusInt), 0, int(c.get("effInt", 10)))
		_:
			var cls := Characters.class_def(cfg, str(c.get("classId", "")))
			var base: int = int(c["baseSpeed"]) if c.has("baseSpeed") else int(cls.get("baseSpeed", 10))
			return _bd(base, int(eq["bonusSpeed"]), 0, Statuses.speed_bonus(c), int(c.get("effSpeed", base)))

static func _bd(base: int, gear: int, talent: int, status: int, total: int) -> Dictionary:
	return {"base": base, "gear": gear, "talent": talent, "status": status, "total": total}


## Bonus d'un sort pour son lanceur, comme le calcule le combat : {power (Intelligence), gear (équipement/talents), level, total}.
## Dégâts et soins reçoivent les trois ; boucliers et restaurations d'endurance seulement la puissance (Intelligence).
static func spell_bonus(c: Dictionary, mode: String) -> Dictionary:
	var power := int(c.get("spellPower", spell_power(int(c.get("effInt", 10)))))
	var full := ["damage", "damageGroup", "healSingle", "healParty"].has(mode)
	var gear := int(c.get("bonusSpellDmg", 0)) if full else 0
	var lvl := int(floor((int(c.get("level", 1)) - 1) * 0.75)) if full else 0
	return {"power": power, "gear": gear, "level": lvl, "total": power + gear + lvl}
