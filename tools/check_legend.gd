extends Node
## Règle « Héros solitaire » du Défi de la semaine : butin ×2 et tout légendaire, monstres un peu plus costauds, un seul héros.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var gear := 0
	var not_legend := 0
	var loot_rule := 0
	var loot_base := 0
	var mon_ok := true
	var party_ok := true
	for n in 5:
		var seed_v := 500 + n
		var a: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 13, 11, "normal", ["mod_solo", "mod_legend"], 1, seed_v)
		var b: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 13, 11, "normal", ["mod_solo"], 1, seed_v)
		party_ok = party_ok and (a.party as Array).size() == 1
		for lv in a.levels:
			for it in lv.items:
				var t := str(it.get("type", ""))
				if t == "weapon" or t == "armor" or t == "jewelry":
					gear += 1
					if not ["legendary", "mythic"].has(Rarity.of(it)):
						not_legend += 1
			loot_rule += (lv.items as Array).size()
			for m in lv.monsters:
				if absf(float(m.get("hpMult", 1.0)) - (1.25 if not m.get("isBoss", false) else float(m.hpMult))) > 0.001 and not m.get("isBoss", false):
					mon_ok = false
		for lv in b.levels:
			loot_base += (lv.items as Array).size()
	var ok := party_ok and mon_ok and gear > 0 and not_legend == 0 and loot_rule > loot_base
	print("LEGEND équipements=%d non légendaires=%d objets avec règle=%d sans=%d monstres ok=%s héros seul=%s -> %s" % [gear, not_legend, loot_rule, loot_base, mon_ok, party_ok, "OK" if ok else "ECHEC"])
	get_tree().quit(0 if ok else 1)
