class_name Shop
extends RefCounted
## Boutiques : prix, offres du marchand ambulant / du village, achat et vente. Portage de generateShopOffers & co.

const WEAPON_STAT := {"sword": "bonusForce", "axe": "bonusForce", "mace": "bonusForce", "dagger": "bonusDex", "bow": "bonusDex", "staff": "bonusInt"}

static func price(item: Dictionary) -> int:
	var p := 8.0
	var t := str(item.get("type", ""))
	if t == "weapon":
		p = 10.0 + (int(item.get("bonusAtkMin", 0)) + int(item.get("bonusAtkMax", 0))) * 4.0
	elif t == "armor" or t == "jewelry":
		p = 8.0 + int(item.get("bonusHp", 0)) * 1.2 + int(item.get("bonusSpellDmg", 0)) * 5.0 \
			+ (int(item.get("bonusForce", 0)) + int(item.get("bonusDex", 0)) + int(item.get("bonusCon", 0)) + int(item.get("bonusInt", 0))) * 3.0 \
			+ (int(item.get("bonusAtkMin", 0)) + int(item.get("bonusAtkMax", 0))) * 3.0
	elif t == "potion":
		p = 3.0 + int(item.get("heal", 0)) * 0.8 + int(item.get("staminaRestore", 0)) * 0.6
	elif t == "scroll":
		p = 30.0
	return maxi(3, int(round(p)))

static func sell_price(item: Dictionary) -> int:
	return int(round(price(item) * 0.5))

# ------------------------------------------------------------------ génération

static func _flavor(list: Array, fallback: String) -> Dictionary:
	var sprite: int = list[GameRng.i("loot") % list.size()]
	var label := str((Data.constants.get("ITEM_SPRITE_LABELS", {}) as Dictionary).get(str(sprite), ""))
	return {"name": label if label != "" else fallback, "icon": ("@icon:spr_%d" % sprite) if label != "" else "@icon:potion_heal"}

static func _secondary(base: Dictionary, pool: Array, run: int) -> Dictionary:
	var order := pool.duplicate()
	GameRng.shuffle("loot", order)
	var count := GameRng.range_i("loot", 1, mini(2, order.size()))
	for k in count:
		var field: String = order[k]
		base[field] = int(base.get(field, 0)) + GameRng.range_i("loot", 1, 2) + int(floor(run / 2.0))
	return base

static func _weapon_bonus(weapon_type: String, run: int) -> Dictionary:
	var primary: String = WEAPON_STAT.get(weapon_type, "bonusForce")
	var pool: Array = ["bonusInt", "bonusDex"] if primary == "bonusInt" else ["bonusForce", "bonusDex", "bonusCon"]
	return _secondary({}, pool, run)

static func _armor_stats(run: int) -> Dictionary:
	var roll := GameRng.f("loot")
	var base: Dictionary
	if roll < 0.4:
		base = {"bonusHp": maxi(2, int(round(6 + run * 2)))}
		_secondary(base, ["bonusCon", "bonusForce"], run)
	elif roll < 0.7:
		var mn := maxi(2, int(round(2 + run * 1.2)))
		base = {"bonusAtkMin": mn, "bonusAtkMax": mn + GameRng.range_i("loot", 2, 3)}
		_secondary(base, ["bonusForce", "bonusDex"], run)
	else:
		base = {"bonusSpellDmg": maxi(2, int(round(2 + run * 1.2)))}
		_secondary(base, ["bonusInt"], run)
	if GameRng.f("loot") < 0.12:
		base["bonusSpeed"] = 1
	return base

static func _weapon_offer(run: int, min_base: int, spread: Array) -> Dictionary:
	var wt: String = DungeonGenerator.WEAPON_TYPES[GameRng.i("loot") % DungeonGenerator.WEAPON_TYPES.size()]
	var fl := _flavor(DungeonGenerator.EQUIP_ICONS.get(wt, DungeonGenerator.EQUIP_ICONS.sword), L.t("rules.shop.arme_du_marchand"))
	var mn := min_base
	var it := {"name": fl.name, "icon": fl.icon, "type": "weapon", "weaponType": wt, "bonusAtkMin": mn, "bonusAtkMax": mn + GameRng.range_i("loot", spread[0], spread[1])}
	it.merge(_weapon_bonus(wt, run), true)
	return it

static func _gear_offer(run: int) -> Dictionary:
	var slots := ["head", "body", "hands", "feet", "accessory"]
	var slot: String = slots[GameRng.i("loot") % slots.size()]
	var jewelry := slot == "accessory"
	var key: String = "jewelry" if jewelry else slot
	var fl := _flavor(DungeonGenerator.EQUIP_ICONS.get(key, DungeonGenerator.EQUIP_ICONS.body), L.t("rules.shop.bijou_du_marchand") if jewelry else L.t("rules.shop.equipement_du_marchand"))
	var it := {"name": fl.name, "icon": fl.icon, "type": "jewelry" if jewelry else "armor"}
	if not jewelry:
		it["slot"] = slot
	it.merge(_armor_stats(run), true)
	return it

static func _finish(offers: Array, prefix: String, village: bool) -> Array:
	for i in offers.size():
		var o: Dictionary = offers[i]
		o["id"] = "%s_%d" % [prefix, i]
		var base := price(o)
		o["price"] = int(round(base * 1.7)) if (village and ["weapon", "armor", "jewelry"].has(str(o.type))) else base
	return offers

## Offres aléatoires du marchand ambulant (generateShopOffers).
static func random_offers(cfg: Dictionary, run: int) -> Array:
	var offers: Array = []
	for k in 2:
		offers.append(_weapon_offer(run, 2 + int(floor(run / 2.0)), [1, 3]))
	for k in 2:
		offers.append(_gear_offer(run))
	for k in 2:
		offers.append({"name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "type": "potion", "heal": 8 + run * 2})
	var spells: Array = (cfg.get("spells", []) as Array).duplicate()
	GameRng.shuffle("loot", spells)
	for i in mini(GameRng.range_i("loot", 2, 3), spells.size()):
		offers.append({"name": L.t("common.parchemin_de") + str(spells[i].name), "icon": "@icon:misc_scroll", "type": "scroll", "spellId": spells[i].id})
	return _finish(offers, "shop_offer", false)

## Offres du marchand ambulant d'un niveau : objets choisis dans l'admin d'abord, puis complétés au hasard.
static func merchant_offers(cfg: Dictionary, tm: Dictionary, run: int) -> Array:
	var slot_count := 8 if int(tm.get("lootSlotCount", 6)) == 8 else 6
	var offers: Array = []
	var ids: Array = []
	for id in tm.get("lootItemIds", []):
		if str(id) != "" and ids.size() < slot_count:
			ids.append(id)
	for id in ids:
		for def in cfg.get("itemLibrary", []):
			if def.get("id") == id:
				var inst := Inventory.make_instance(def)
				inst["id"] = "merchant_offer_%d" % offers.size()
				inst["price"] = price(inst)
				offers.append(inst)
	# Le complément aléatoire garantit quelques parchemins : on réserve leurs places avant d'achever avec le reste.
	var rnd := random_offers(cfg, run)
	var scrolls: Array = rnd.filter(func(o): return str(o.type) == "scroll")
	var others: Array = rnd.filter(func(o): return str(o.type) != "scroll")
	var free := slot_count - offers.size()
	var n_scroll := mini(scrolls.size(), mini(maxi(2, free / 3), maxi(0, free)))
	var pick: Array = others.slice(0, maxi(0, free - n_scroll))
	pick.append_array(scrolls.slice(0, n_scroll))
	for o in pick:
		var c: Dictionary = (o as Dictionary).duplicate(true)
		c["id"] = "merchant_offer_%d" % offers.size()
		offers.append(c)
	return offers

## Offres du marchand du village (plus riches : run + 2, quantités de potions, plusieurs parchemins).
static func village_offers(cfg: Dictionary, run: int) -> Array:
	var boosted := run + 2
	var offers: Array = []
	for k in 2:
		offers.append(_weapon_offer(boosted, 3 + int(floor(boosted / 2.0)), [2, 4]))
	for k in 2:
		offers.append(_gear_offer(boosted))
	var heal := GameRng.range_i("loot", 8, 15)
	var sta := GameRng.range_i("loot", 8, 15)
	for k in GameRng.range_i("loot", 1, 10):
		offers.append({"name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "type": "potion", "heal": heal})
	for k in GameRng.range_i("loot", 1, 10):
		offers.append({"name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "type": "potion", "staminaRestore": sta})
	var spells: Array = (cfg.get("spells", []) as Array).duplicate()
	GameRng.shuffle("loot", spells)
	var n := mini(GameRng.range_i("loot", 1, 5), spells.size())
	for i in n:
		offers.append({"name": L.t("common.parchemin_de") + str(spells[i].name), "icon": "@icon:misc_scroll", "type": "scroll", "spellId": spells[i].id})
	return _finish(offers, "village_merchant_offer", true)

# ------------------------------------------------------------------ transactions

## Achète l'offre `idx` (au rang courant de `offers`). Renvoie "" si réussi, sinon le motif de l'échec.
static func buy(gs: GameState, offers: Array, idx: int, quiet: bool = false) -> String:
	RunLog.unrecorded("boutique.buy")
	if idx < 0 or idx >= offers.size():
		return "Offre introuvable."
	var o: Dictionary = offers[idx]
	if gs.gold < int(o.price):
		return L.t("common.pas_assez_or")
	var inst: Dictionary = o.duplicate(true)
	inst.erase("price")
	inst["id"] = "bought_%d" % GameRng.i("ids")
	if not Inventory.add(gs, inst):
		return L.fa(L.t("rules.shop.l_onglet_de_la_besace"), str(Inventory.TAB_LABELS.get(Inventory.tab_of(inst), "")))
	gs.gold -= int(o.price)
	gs.stats["itemsBought"] = int(gs.stats.get("itemsBought", 0)) + 1
	if not quiet:
		gs.add_log(L.fa(L.t("rules.shop.le_groupe_achete_pour_pieces"), [o.name, int(o.price)]))
	offers.remove_at(idx)
	return ""

static func sell(gs: GameState, idx: int, quiet: bool = false) -> String:
	RunLog.unrecorded("boutique.sell")
	if idx < 0 or idx >= gs.inventory.size():
		return L.t("rules.shop.objet_introuvable")
	var it: Dictionary = gs.inventory[idx]
	if str(it.get("type", "")) == "key":
		return L.t("rules.shop.une_cle_ne_peut_jamais")
	var p := sell_price(it)
	gs.gold += p
	gs.inventory.remove_at(idx)
	gs.stats["itemsSold"] = int(gs.stats.get("itemsSold", 0)) + 1
	if not quiet:
		gs.add_log(L.fa(L.t("rules.shop.le_groupe_vend_pour_pieces"), [it.name, p]))
	return ""

## Résumé court des bonus (« Atq +2-4, PV +3 »).
static func summary(it: Dictionary, cfg: Dictionary) -> String:
	var parts: Array = []
	if int(it.get("bonusAtkMin", 0)) != 0 or int(it.get("bonusAtkMax", 0)) != 0:
		parts.append("Atq +%d-%d" % [int(it.get("bonusAtkMin", 0)), int(it.get("bonusAtkMax", 0))])
	for pair in [["bonusHp", L.t("common.pv")], ["bonusSpellDmg", L.t("common.sort")], ["bonusForce", L.t("common.for")], ["bonusDex", "Dex"], ["bonusCon", "Con"], ["bonusInt", "Int"], ["bonusSpeed", "Vit"]]:
		if int(it.get(pair[0], 0)) != 0:
			parts.append("%s +%d" % [pair[1], int(it[pair[0]])])
	if int(it.get("heal", 0)) > 0:
		parts.append("Soigne %d PV" % int(it.heal))
	if int(it.get("staminaRestore", 0)) > 0:
		parts.append(L.fa(L.t("common.rend_endurance"), int(it.staminaRestore)))
	if str(it.get("type", "")) == "scroll":
		for sp in cfg.get("spells", []):
			if sp.get("id") == it.get("spellId"):
				parts.append("Invoque %s (x1)" % sp.name)
	return ", ".join(parts) if not parts.is_empty() else L.t("rules.shop.aucun_bonus")
