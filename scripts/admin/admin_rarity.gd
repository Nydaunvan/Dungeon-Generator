class_name AdminRarity
extends RefCounted
## Éditeur de rareté d'un objet d'équipement dans l'administration : palier, puis une capacité (valeur en %) par emplacement du palier.
## `on_change` est rappelée après un changement de palier (pour redessiner la fiche).

const SLOTS := {"common": 0, "uncommon": 1, "rare": 1, "epic": 2, "legendary": 1, "mythic": 2}

static func _tiers() -> Array:
	var out: Array = []
	for id in Rarity.ORDER:
		out.append([id, str(Rarity.DEF[id].key)])
	return out

static func _perk_options() -> Array:
	var out: Array = []
	for id in Rarity.PERK_NAMES.keys():
		out.append([id, str(Rarity.PERK_NAMES[id])])
	return out

## Remplit `parent` : liste « Rareté » et, selon le palier, les capacités. Les anciens champs legendary* restent synchronisés.
static func build(parent: Control, it: Dictionary, on_change: Callable) -> void:
	var cur := Rarity.of(it)
	# objet légendaire d'avant les raretés : ses capacités deviennent explicites dès qu'on le modifie ici
	if not (it.get("perks") is Array) and not Rarity.perks_of(it).is_empty():
		it["perks"] = Rarity.perks_of(it).duplicate(true)
	var f := AdminUtil.flow(parent)
	AdminUtil.chip(f, L.t("ui.rarity.rarete"), AdminUtil.dropdown(_tiers(), cur, func(x):
		_set_tier(it, str(x))
		on_change.call(), 150.0))
	if cur == "common":
		return
	var perks: Array = it.get("perks", [])
	for k in int(SLOTS[cur]):
		var p: Dictionary = perks[k] if k < perks.size() else {"id": "crit", "value": 5}
		var f2 := AdminUtil.flow(parent)
		var slot := k
		AdminUtil.chip(f2, L.t("rules.rarity.capacite"), AdminUtil.dropdown(_perk_options(), str(p.id), func(x):
			_edit(it, slot, "id", str(x))
			on_change.call(), 170.0))
		var s := SpinBox.new()
		s.min_value = 1
		s.max_value = 100
		s.value = float(p.get("value", 5))
		s.custom_minimum_size = Vector2(84, 0)
		s.value_changed.connect(func(v: float): _edit(it, slot, "value", int(v)))
		AdminUtil.chip(f2, L.t("rules.rarity.valeur_pct"), s)

static func _set_tier(it: Dictionary, tier: String) -> void:
	if tier == "common":
		for k in ["rarity", "perks", "legendary", "legendaryPerk", "legendaryValue"]:
			it.erase(k)
		return
	it["rarity"] = tier
	var perks: Array = (it.get("perks", []) as Array).duplicate(true)
	var want: int = SLOTS[tier]
	while perks.size() < want:
		perks.append({"id": "lifesteal" if perks.is_empty() else "crit", "value": 10})
	perks.resize(want)
	it["perks"] = perks
	_sync(it)

static func _edit(it: Dictionary, slot: int, field: String, value) -> void:
	var perks: Array = it.get("perks", [])
	while perks.size() <= slot:
		perks.append({"id": "crit", "value": 5})
	perks[slot][field] = value
	it["perks"] = perks
	_sync(it)

## Compatibilité : le premier palier légendaire garde ses champs historiques (legendary, legendaryPerk, legendaryValue).
static func _sync(it: Dictionary) -> void:
	var tier := Rarity.of(it)
	if tier == "legendary" or tier == "mythic":
		it["legendary"] = true
		var perks: Array = it.get("perks", [])
		if not perks.is_empty():
			it["legendaryPerk"] = perks[0].id
			it["legendaryValue"] = perks[0].value
	else:
		it.erase("legendary")
		it.erase("legendaryPerk")
		it.erase("legendaryValue")
