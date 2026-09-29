class_name Characters
extends RefCounted
## Personnages : création, stats dérivées, expérience. Portage de initialState / recomputeCharacterDerived / awardXP.
## (Talents, statuts et modificateurs de partie seront branchés plus tard : leurs bonus valent 0 pour l'instant.)

const SLOTS := ["weapon", "head", "body", "hands", "feet", "accessory"]
const MAX_LEVEL := 30

static func xp_to_next(level: int) -> int:
	var x := 20
	for i in range(1, level):
		x = int(round(x * 1.6))
	return x

static func class_def(cfg: Dictionary, class_id: String) -> Dictionary:
	for c in cfg.get("classes", []):
		if c.get("id") == class_id:
			return c
	return {}

static func instantiate_item(lib_id: String, cfg: Dictionary) -> Dictionary:
	for def in cfg.get("itemLibrary", []):
		if def.get("id") == lib_id:
			var inst: Dictionary = def.duplicate(true)
			inst["id"] = "%s_%d" % [lib_id, randi()]
			return inst
	return {}

static func start_weapon(t: Dictionary, cfg: Dictionary) -> Dictionary:
	var cls := class_def(cfg, str(t.get("classId", "")))
	var types: Array = cls.get("allowedWeaponTypes", [])
	if types.is_empty():
		return {}
	return {"id": "start_" + str(t.id), "name": "Arme de départ", "icon": "⚔️", "type": "weapon",
		"weaponType": types[0], "bonusAtkMin": 1, "bonusAtkMax": 2}

static func create(t: Dictionary, cfg: Dictionary) -> Dictionary:
	var c: Dictionary = t.duplicate(true)
	var lvl := int(t.get("level", 1))
	var max_sta := int(t.get("maxStamina", 100))
	c["level"] = lvl
	c["xp"] = int(t.get("xp", 0))
	c["xpToNext"] = xp_to_next(lvl)
	c["stamina"] = max_sta
	c["maxStamina"] = max_sta
	c["statusEffects"] = []
	c["shieldAmount"] = 0
	c["spellsKnown"] = (t.get("spellsKnown", []) as Array).duplicate()
	c["spellCooldowns"] = {}
	var eq := {}
	for s in SLOTS:
		eq[s] = null
	c["equipment"] = eq
	var start: Dictionary = t.get("startEquipment", {})
	for s in SLOTS:
		if start.has(s):
			var inst := instantiate_item(str(start[s]), cfg)
			if not inst.is_empty():
				eq[s] = inst
	if eq["weapon"] == null:
		var sw := start_weapon(t, cfg)
		if not sw.is_empty():
			eq["weapon"] = sw
	recompute(c, cfg)
	c["hp"] = c["maxHp"]
	return c

static func equipped_bonus(c: Dictionary) -> Dictionary:
	var b := {"bonusAtkMin": 0, "bonusAtkMax": 0, "bonusHp": 0, "bonusSpellDmg": 0,
		"bonusForce": 0, "bonusDex": 0, "bonusCon": 0, "bonusInt": 0, "bonusSpeed": 0}
	var eq: Dictionary = c.get("equipment", {})
	for slot in SLOTS:
		var it = eq.get(slot)
		if it == null:
			continue
		for k in b.keys():
			if slot == "weapon" and (k == "bonusHp" or k == "bonusSpellDmg"):
				continue   # l'arme n'apporte ni PV ni dégâts de sort (comme le JS)
			b[k] += int(it.get(k, 0))
	return b

static func recompute(c: Dictionary, cfg: Dictionary) -> void:
	var eq := equipped_bonus(c)
	var f := int(c.get("force", 10)) + int(eq["bonusForce"])
	var d := int(c.get("dex", 10)) + int(eq["bonusDex"])
	var co := int(c.get("con", 10)) + int(eq["bonusCon"])
	var i := int(c.get("int", 10)) + int(eq["bonusInt"])
	var b := Stats.char_base({"force": f, "dex": d, "con": co, "level": c.get("level", 1)})
	c["maxHp"] = maxi(1, int(round(b.maxHp + eq["bonusHp"])))
	c["baseAtkMin"] = b.baseAtkMin
	c["baseAtkMax"] = b.baseAtkMax
	c["atkMin"] = int(b.baseAtkMin) + int(eq["bonusAtkMin"])
	c["atkMax"] = int(b.baseAtkMax) + int(eq["bonusAtkMax"])
	c["bonusSpellDmg"] = eq["bonusSpellDmg"]
	c["effForce"] = f
	c["effDex"] = d
	c["effCon"] = co
	c["effInt"] = i
	var cls := class_def(cfg, str(c.get("classId", "")))
	var base_speed: int = int(c["baseSpeed"]) if c.has("baseSpeed") else int(cls.get("baseSpeed", 10))
	c["effSpeed"] = maxi(1, base_speed + int(eq["bonusSpeed"]))
	if not c.has("baseMaxStamina"):
		c["baseMaxStamina"] = int(c.get("maxStamina", 100))
	c["maxStamina"] = maxi(10, int(round(c["baseMaxStamina"])))
	c["talentCritChance"] = 0
	c["talentLifestealPct"] = 0
	c["resistPhys"] = 0
	c["resistMagic"] = 0
	if int(c.get("hp", 0)) > c["maxHp"]:
		c["hp"] = c["maxHp"]
	if int(c.get("stamina", 0)) > c["maxStamina"]:
		c["stamina"] = c["maxStamina"]

static func award_xp(gs: GameState, c: Dictionary, amount: int) -> void:
	if amount <= 0 or int(c.hp) <= 0:
		return
	if int(c.level) >= MAX_LEVEL:
		c["xp"] = 0
		return
	c["xp"] = int(c.xp) + amount
	var growth: Dictionary = gs.cfg.get("levelUpGrowth", {"statPerLevel": 0.4, "staminaPerLevel": 2})
	while int(c.xp) >= int(c.xpToNext) and int(c.level) < MAX_LEVEL:
		c["xp"] = int(c.xp) - int(c.xpToNext)
		c["level"] = int(c.level) + 1
		var old_max := int(c.maxHp)
		var old_max_sta := int(c.maxStamina)
		c["statGrowthAccum"] = float(c.get("statGrowthAccum", 0.0)) + float(growth.get("statPerLevel", 0.4))
		while float(c["statGrowthAccum"]) >= 1.0:
			c["statGrowthAccum"] = float(c["statGrowthAccum"]) - 1.0
			for k in ["force", "dex", "con", "int"]:
				c[k] = int(c.get(k, 10)) + 1
		c["baseMaxStamina"] = int(c.get("baseMaxStamina", c.get("maxStamina", 100))) + int(growth.get("staminaPerLevel", 2))
		recompute(c, gs.cfg)
		c["hp"] = int(c.hp) + (int(c.maxHp) - old_max)
		c["stamina"] = mini(int(c.maxStamina), int(c.get("stamina", 0)) + maxi(0, int(c.maxStamina) - old_max_sta))
		c["xpToNext"] = int(round(int(c.xpToNext) * 1.6))
		gs.add_log("🎉 %s monte au niveau %d !" % [c.name, c.level])
		learn_spells(gs, c)
	if int(c.level) >= MAX_LEVEL:
		c["xp"] = 0

const MAX_SPELLS := 6

## Sorts appris automatiquement selon la progression de la classe (niveau atteint).
static func learn_spells(gs: GameState, c: Dictionary) -> void:
	var cls := class_def(gs.cfg, str(c.get("classId", "")))
	var known: Array = c.get("spellsKnown", [])
	for step in cls.get("spellProgression", []):
		if int(step.get("level", 99)) <= int(c.level) and not known.has(step.spellId) and known.size() < MAX_SPELLS:
			known.append(step.spellId)
			var name := str(step.spellId)
			for sp in gs.cfg.get("spells", []):
				if sp.get("id") == step.spellId:
					name = str(sp.name)
			gs.add_log("📖 %s apprend %s !" % [c.name, name])
	c["spellsKnown"] = known
