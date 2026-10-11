extends Node
## Vérifie le marchand ambulant : toujours fixe, contre un mur (étal dans une niche), et 2-3 parchemins en vente.

func _ready() -> void:
	var base: Dictionary = Data.config
	var bad := 0
	var n := 0
	for t in 200:
		var cfg: Dictionary = DungeonGenerator.build_config(base, 3, 13, 11, "normal", [], 1)
		for lv in cfg.levels:
			var tm = lv.get("travelingMerchant")
			if tm == null:
				continue
			n += 1
			var rows: Array = lv.mapRows
			if int(tm.patrolRadius) != 0 or DungeonGenerator._wall_sides(rows, int(tm.x), int(tm.y)) < 1:   # l'étal est logé dans un décroché du mur : il ne bloque jamais la case
				bad += 1
				print("place", tm, DungeonGenerator._wall_sides(rows, int(tm.x), int(tm.y)))
			var offers := Shop.merchant_offers(cfg, tm, 1)
			var sc := 0
			for o in offers:
				if str(o.type) == "scroll":
					sc += 1
			for lots in [offers, Shop.village_offers(cfg, 1)]:
				var ph := 0
				var ps := 0
				for o in lots:
					if str(o.type) == "potion":
						if int(o.get("heal", 0)) > 0:
							ph += 1
						else:
							ps += 1
				if ph < 1 or ph > 6 or ps < 1 or ps > 6:
					bad += 1
					print("potions", ph, ps)
			if sc < 2 and (cfg.get("spells", []) as Array).size() >= 2:
				bad += 1
				print("scrolls", sc, offers.size())
	print("marchands : %d, anomalies : %d" % [n, bad])
	get_tree().quit()
