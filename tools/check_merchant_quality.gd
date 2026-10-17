extends Node
## Vérifie que le marchand propose des offres variables, dont des « belles affaires » par rapport au stuff porté par le groupe.

func _party(power_scale: int) -> Array:
	var c := {"equipment": {}}
	for s in ["weapon", "head", "body", "hands", "feet", "accessory"]:
		c.equipment[s] = {"type": "weapon" if s == "weapon" else "armor", "slot": s, "bonusAtkMin": 3 * power_scale, "bonusAtkMax": 5 * power_scale,
			"bonusHp": 6 * power_scale, "bonusForce": power_scale}
	return [c]

func _ready() -> void:
	var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 3, 13, 11, "normal", [], 1)
	var bad := 0
	for scale in [0, 1, 3, 8]:
		var party := _party(scale) if scale > 0 else []
		var with_up := 0
		var total := 300
		var distinct := {}
		for t in total:
			GameRng.begin(t + 1)
			for lots in [Shop.merchant_offers(cfg, {}, 2, party), Shop.village_offers(cfg, 2, party)]:
				var up := 0
				for o in lots:
					if str(o.type) in ["weapon", "armor", "jewelry"]:
						distinct[Inventory.power(o)] = true
						if o.get("upgradeOffer", false):
							up += 1
							var ref := Shop.reference_power(party, Shop._slot_of(o))
							if Inventory.power(o) <= ref:
								bad += 1
								print("belle affaire pas meilleure : ", o, " ref ", ref)
				if up > 0:
					with_up += 1
		print("stuff x%d : %d/%d marchands avec une belle affaire, %d puissances distinctes" % [scale, with_up, total * 2, distinct.size()])
		if scale > 0 and with_up < total * 2 * 0.9:
			bad += 1
		if distinct.size() < 15:
			bad += 1
	print("qualité des offres : anomalies %d" % bad)
	get_tree().quit()
