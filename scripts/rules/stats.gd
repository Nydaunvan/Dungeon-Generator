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
	var max_hp: float = 5.0 + float(m.get("con", 8)) * 2.8
	var atk_min: int = maxi(1, int(floor(float(m.get("force", 8)) / 2.5)))
	var atk_max: int = atk_min + 1 + int(floor(float(m.get("dex", 8)) / 3.3))
	return {"maxHp": max_hp, "atkMin": atk_min, "atkMax": atk_max}
