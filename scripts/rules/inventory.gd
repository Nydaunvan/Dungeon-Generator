class_name Inventory
extends RefCounted
## Besace commune du groupe : onglets, piles, équiper / déséquiper, potions. Portage de bagTabOf / equipItem / usePotionAt.

const MAX_PER_TAB := 12
const SLOT_LABELS := {"weapon": "common.arme", "head": "rules.inventory.tete", "body": "Torse", "hands": "Mains", "feet": "Pieds", "accessory": "common.bijou"}
const TAB_LABELS := {"items": "rules.inventory.objets", "potions": "rules.inventory.potions", "keys": "rules.inventory.cles_parchemins"}

static func tab_of(it: Dictionary) -> String:
	var t := str(it.get("type", ""))
	if t == "potion":
		return "potions"
	if t == "key" or t == "scroll":
		return "keys"
	return "items"

## Clé de pile : potions simples et parchemins identiques occupent un seul emplacement.
static func stack_key(it: Dictionary) -> String:
	var t := str(it.get("type", ""))
	var heal := int(it.get("heal", 0))
	var sta := int(it.get("staminaRestore", 0))
	if t == "potion" and ((heal > 0 and sta == 0) or (sta > 0 and heal == 0)):
		return "potion|%d|%d" % [heal, sta]
	if t == "scroll":
		return "scroll|" + str(it.get("spellId", ""))
	return ""

static func tab_count(gs: GameState, tab: String) -> int:
	var seen := {}
	var n := 0
	for it in gs.inventory:
		if tab_of(it) != tab:
			continue
		var k := stack_key(it)
		if k != "":
			if seen.has(k):
				continue
			seen[k] = true
		n += 1
	return n

static func has_space(gs: GameState, it: Dictionary) -> bool:
	var tab := tab_of(it)
	var k := stack_key(it)
	if k != "":
		for x in gs.inventory:
			if tab_of(x) == tab and stack_key(x) == k:
				return true
	return tab_count(gs, tab) < MAX_PER_TAB

## Copie d'un objet de niveau / de bibliothèque sans position.
static func make_instance(def: Dictionary) -> Dictionary:
	var inst: Dictionary = def.duplicate(true)
	inst.erase("x")
	inst.erase("y")
	inst["uid"] = "%s_%d" % [str(def.get("id", "obj")), GameRng.i("ids")]
	return inst

static func add(gs: GameState, it: Dictionary) -> bool:
	if not has_space(gs, it):
		return false
	gs.inventory.append(it)
	return true

## Puissance brute d'un objet équipable (sert aux repères ▲ / ▼ et au tri) : attaque moyenne + somme des bonus.
static func power(it) -> float:
	if it == null:
		return 0.0
	return float(int(it.get("bonusAtkMin", 0)) + int(it.get("bonusAtkMax", 0))) * 0.5 + float(it.get("bonusHp", 0)) * 0.3 \
		+ float(int(it.get("bonusSpellDmg", 0)) + int(it.get("bonusForce", 0)) + int(it.get("bonusDex", 0)) + int(it.get("bonusCon", 0)) \
		+ int(it.get("bonusInt", 0)) + int(it.get("bonusSpeed", 0)))

## Compare un objet de la besace à ce que porte le personnage `c` à son emplacement : 1 meilleur, -1 moins bon, 0 égal ou non équipable.
static func upgrade(c: Dictionary, it: Dictionary) -> int:
	var slot := slot_of(it)
	if slot == "" or c.is_empty():
		return 0
	var d := power(it) - power(c.get("equipment", {}).get(slot))
	return 1 if d > 0.001 else (-1 if d < -0.001 else 0)

const SORT_MODES := ["type", "power", "name"]

static func _rank(it: Dictionary) -> int:
	match str(it.get("type", "")):
		"weapon": return 0
		"armor": return 1 + ["head", "body", "hands", "feet"].find(str(it.get("slot", "body")))
		"jewelry": return 6
		"potion": return 7
		"scroll": return 8
		"key": return 9
	return 10

## Range les objets d'un onglet (à leurs emplacements actuels) : par type, par puissance décroissante ou par nom. Stable.
static func sort_tab(gs: GameState, tab: String, mode: String) -> void:
	var slots: Array = []
	var entries: Array = []
	for i in gs.inventory.size():
		var it: Dictionary = gs.inventory[i]
		if tab_of(it) == tab:
			slots.append(i)
			entries.append({"it": it, "n": entries.size()})
	entries.sort_custom(func(a, b):
		var x: Dictionary = a.it
		var y: Dictionary = b.it
		var kx := 0.0
		var ky := 0.0
		match mode:
			"power":
				kx = -power(x)
				ky = -power(y)
			"name":
				var nx := str(x.get("name", "")).to_lower()
				var ny := str(y.get("name", "")).to_lower()
				if nx != ny:
					return nx < ny
			_:
				kx = float(_rank(x))
				ky = float(_rank(y))
				if kx == ky:
					var nx2 := str(x.get("name", "")).to_lower()
					var ny2 := str(y.get("name", "")).to_lower()
					if nx2 != ny2:
						return nx2 < ny2
		if kx != ky:
			return kx < ky
		return int(a.n) < int(b.n))
	for k in slots.size():
		gs.inventory[slots[k]] = entries[k].it

static func slot_of(it: Dictionary) -> String:
	match str(it.get("type", "")):
		"weapon": return "weapon"
		"armor": return str(it.get("slot", "body"))
		"jewelry": return "accessory"
	return ""

static func can_equip(it: Dictionary) -> bool:
	return slot_of(it) != ""

static func equip(gs: GameState, c: Dictionary, idx: int) -> bool:
	if idx < 0 or idx >= gs.inventory.size():
		return false
	var it: Dictionary = gs.inventory[idx]
	var slot := slot_of(it)
	if slot == "":
		return false
	var eq: Dictionary = c.get("equipment", {})
	var old = eq.get(slot)
	eq[slot] = it
	c["equipment"] = eq
	gs.inventory.remove_at(idx)
	if old != null:
		gs.inventory.append(old)
	Characters.recompute(c, gs.cfg)
	gs.add_log(L.fa(L.t("rules.inventory.equipe"), [c.name, _icon_txt(it), it.get("name", "")]))
	return true

static func unequip(gs: GameState, c: Dictionary, slot: String) -> bool:
	var eq: Dictionary = c.get("equipment", {})
	var it = eq.get(slot)
	if it == null:
		return false
	if not has_space(gs, it):
		gs.add_log(L.fa(L.t("rules.inventory.impossible_de_desequiper_l_onglet"), [TAB_LABELS[tab_of(it)], MAX_PER_TAB, MAX_PER_TAB]))
		return false
	eq[slot] = null
	gs.inventory.append(it)
	Characters.recompute(c, gs.cfg)
	return true

## Boit une potion ; renvoie les PV rendus (-1 si impossible).
static func use_potion(gs: GameState, c: Dictionary, idx: int) -> int:
	if idx < 0 or idx >= gs.inventory.size():
		return -1
	var it: Dictionary = gs.inventory[idx]
	if str(it.get("type", "")) != "potion" or int(c.hp) <= 0:
		return -1
	if Statuses.has(c, "freeze"):
		gs.add_log(L.fa(L.t("rules.inventory.est_gele_impossible_de_lui"), c.name))
		return -1
	var healed := 0
	var restored := 0
	if int(it.get("heal", 0)) > 0:
		var before := int(c.hp)
		c["hp"] = mini(int(c.maxHp), before + int(it.heal))
		healed = int(c.hp) - before
	if int(it.get("staminaRestore", 0)) > 0:
		var before_s := int(c.get("stamina", 0))
		c["stamina"] = mini(int(c.get("maxStamina", 100)), before_s + int(it.staminaRestore))
		restored = int(c.stamina) - before_s
	gs.stats["potionsUsed"] = int(gs.stats.get("potionsUsed", 0)) + 1
	var parts: Array[String] = []
	if healed > 0:
		parts.append("%d PV" % healed)
	if restored > 0:
		parts.append(L.fa(L.t("rules.inventory.endurance"), restored))
	gs.add_log(L.fa(L.t("rules.inventory.boit_et_recupere"), [c.name, _icon_txt(it), it.get("name", ""), " et ".join(parts) if not parts.is_empty() else "0"]), true)
	gs.inventory.remove_at(idx)
	return healed

static func discard(gs: GameState, idx: int) -> bool:
	if idx < 0 or idx >= gs.inventory.size():
		return false
	var it: Dictionary = gs.inventory[idx]
	if str(it.get("type", "")) == "key":
		gs.add_log(L.t("rules.inventory.une_cle_ne_peut_jamais"))
		return false
	gs.inventory.remove_at(idx)
	gs.add_log(L.fa(L.t("rules.inventory.le_groupe_se_debarrasse_definitivement"), it.get("name", "")))
	return true

static func find_key(gs: GameState, door_id: String) -> int:
	for i in gs.inventory.size():
		var it: Dictionary = gs.inventory[i]
		if str(it.get("type", "")) == "key" and str(it.get("opensDoorId", "")) == door_id:
			return i
	return -1

static func _icon_txt(it: Dictionary) -> String:
	var ic := str(it.get("icon", ""))
	return "" if ic.begins_with("@icon:") else ic

## Lignes descriptives d'un objet (bonus, effet).
static func describe(it: Dictionary, cfg: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var atk_min := int(it.get("bonusAtkMin", 0))
	var atk_max := int(it.get("bonusAtkMax", 0))
	if atk_min != 0 or atk_max != 0:
		out.append("Attaque +%d / +%d" % [atk_min, atk_max])
	for pair in [["bonusHp", L.t("common.pv")], ["bonusSpellDmg", L.t("common.degats_de_sort")], ["bonusForce", L.t("common.force")], ["bonusDex", L.t("common.dexterite")],
			["bonusCon", L.t("common.constitution")], ["bonusInt", L.t("common.intelligence")], ["bonusSpeed", L.t("common.vitesse")]]:
		var v := int(it.get(pair[0], 0))
		if v != 0:
			out.append("%s %+d" % [pair[1], v])
	if int(it.get("heal", 0)) > 0:
		out.append("Rend %d PV" % int(it.heal))
	if int(it.get("staminaRestore", 0)) > 0:
		out.append(L.fa(L.t("common.rend_endurance"), int(it.staminaRestore)))
	match str(it.get("type", "")):
		"key": out.append(L.t("rules.inventory.ouvre_une_porte_verrouillee"))
		"scroll":
			for sp in cfg.get("spells", []):
				if sp.get("id") == it.get("spellId"):
					out.append(L.fa(L.t("rules.inventory.lance_usage_unique_sans_cout"), sp.name))
		"weapon":
			if it.has("weaponType"):
				out.insert(0, "Arme : %s" % str(it.weaponType))
		"armor", "jewelry":
			var s := slot_of(it)
			if s != "":
				out.insert(0, "Emplacement : %s" % SLOT_LABELS.get(s, s))
	if out.is_empty():
		out.append(L.t("rules.inventory.aucun_bonus"))
	return out
