extends Node
## Vérifie le système de raretés : répartition des paliers par origine, capacités, bonus, prix, application des capacités en combat.

func _ok(cond: bool, what: String) -> int:
	if not cond:
		print("  ÉCHEC : ", what)
	return 0 if cond else 1

func _ready() -> void:
	var bad := 0
	var base: Dictionary = Data.config
	# 1) répartition des paliers sur 150 donjons de difficulté normale (3 niveaux et plus)
	var count := {}
	var boss_tiers := {}
	var n_items := 0
	for t in 40:
		GameRng.begin(t + 1)
		var cfg: Dictionary = DungeonGenerator.build_config(base, 6, 13, 11, "normal", [], 1 + t % 4)
		for lv in cfg.levels:
			for it in lv.items:
				if not ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
					continue
				var r := Rarity.of(it)
				count[r] = int(count.get(r, 0)) + 1
				n_items += 1
				if str(it.id).begins_with("loot_boss_"):
					boss_tiers[r] = int(boss_tiers.get(r, 0)) + 1
				# cohérence : nombre de capacités attendu
				var np := Rarity.perks_of(it).size()
				var want: int = {"common": 0, "uncommon": 1, "rare": 1, "epic": 2, "legendary": 1, "mythic": 2}[r]
				bad += _ok(np == want, "%s : %d capacité(s) au lieu de %d (%s)" % [r, np, want, it.name])
				bad += _ok((r == "legendary" or r == "mythic") == bool(it.get("legendary", false)), "indicateur legendary de %s" % r)
	print("objets d'équipement : %d  répartition : %s" % [n_items, count])
	print("butin des gardiens : ", boss_tiers)
	bad += _ok(int(boss_tiers.get("common", 0)) == 0 and int(boss_tiers.get("uncommon", 0)) == 0, "un gardien laisse toujours au moins du rare")
	for r in ["common", "uncommon", "rare", "epic", "legendary"]:
		bad += _ok(int(count.get(r, 0)) > 0, "palier %s présent" % r)
	bad += _ok(int(count.get("common", 0)) > int(count.get("rare", 0)) and int(count.get("rare", 0)) > int(count.get("legendary", 0)), "les paliers élevés sont plus rares")
	# 2) prix croissants avec la rareté, à bonus égaux
	var sword := {"type": "weapon", "bonusAtkMin": 3, "bonusAtkMax": 5}
	var last := 0
	for r in Rarity.ORDER:
		var it := sword.duplicate()
		it["rarity"] = r
		var p := Shop.price(it)
		bad += _ok(p >= last, "prix croissant avec la rareté (%s : %d)" % [r, p])
		last = p
	# 3) ancien objet légendaire sans champ rarity
	var old := {"type": "weapon", "legendary": true, "legendaryPerk": "crit", "legendaryValue": 20}
	bad += _ok(Rarity.of(old) == "legendary" and Rarity.perks_of(old).size() == 1, "ancien légendaire reconnu")
	# 4) capacités en combat : esquive, critique, ensemble mythique
	var hero := {"equipment": {"weapon": {"type": "weapon", "perks": [{"id": "crit", "value": 4}], "rarity": "uncommon"},
		"head": {"type": "armor", "perks": [{"id": "crit", "value": 6}, {"id": "dodge", "value": 3}], "rarity": "mythic"},
		"body": {"type": "armor", "perks": [{"id": "gold", "value": 5}], "rarity": "mythic"}}}
	bad += _ok(Rarity.perk_sum(hero, "crit") == 4 + 6 + 10, "critique cumulé + ensemble mythique : %d" % Rarity.perk_sum(hero, "crit"))
	bad += _ok(Rarity.perk_sum(hero, "dodge") == 3, "esquive")
	# 5) marchand
	var cfg2: Dictionary = DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1)
	var shop_count := {}
	var party := [hero]
	for t in 200:
		GameRng.begin(t + 1)
		for o in Shop.village_offers(cfg2, 3, party):
			if ["weapon", "armor", "jewelry"].has(str(o.type)):
				shop_count[Rarity.of(o)] = int(shop_count.get(Rarity.of(o), 0)) + 1
				bad += _ok(Rarity.of(o) != "legendary" and Rarity.of(o) != "mythic", "pas de légendaire chez le marchand")
	print("marchand du village : ", shop_count)
	bad += _ok(int(shop_count.get("rare", 0)) > 0 and int(shop_count.get("common", 0)) > 0, "le marchand propose du commun et du rare")
	print("raretés : anomalies %d" % bad)
	get_tree().quit()
