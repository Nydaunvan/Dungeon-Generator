extends Node
## Règle « Armes seules » : chaque héros part avec une arme épique, équipement trouvé et vendu rare au minimum.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var weapons_ok := true
	var below := 0
	var gear := 0
	var shop_below := 0
	var shop_gear := 0
	for n in 4:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 4, 13, 11, "normal", ["mod_nospells"], 1, 300 + n)
		for t in cfg.party:
			var w = Characters.create(t, cfg).equipment.get("weapon")
			weapons_ok = weapons_ok and w is Dictionary and Rarity.of(w) == "epic"
		for lv in cfg.levels:
			for it in lv.items:
				if ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
					gear += 1
					if Rarity.index(Rarity.of(it)) < Rarity.index("rare"):
						below += 1
		for k in 6:
			for o in Shop.random_offers(cfg, 1 + k % 4, cfg.party):
				if ["weapon", "armor", "jewelry"].has(str(o.type)):
					shop_gear += 1
					if Rarity.index(Rarity.of(o)) < Rarity.index("rare"):
						shop_below += 1
	var ok := weapons_ok and gear > 0 and below == 0 and shop_gear > 0 and shop_below == 0
	print("NOSPELLS armes épiques=%s équipements=%d sous-rare=%d marchands=%d sous-rare=%d -> %s" % [weapons_ok, gear, below, shop_gear, shop_below, "OK" if ok else "ECHEC"])
	get_tree().quit(0 if ok else 1)
