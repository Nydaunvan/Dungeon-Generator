extends Node
## Règle « Héros solitaire » du Défi de la semaine : un seul héros avec une arme rare, équipement rare au minimum, butin plus abondant, monstres plus costauds, dégâts ×1,33.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var gear := 0
	var below := 0
	var high := 0
	var loot_rule := 0
	var loot_base := 0
	var mon_ok := true
	var party_ok := true
	var weapon_ok := true
	for n in 6:
		var seed_v := 500 + n
		var a: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 15, 15, "normal", ["mod_solo", "mod_legend"], 1, seed_v)
		var b: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 15, 15, "normal", ["mod_solo"], 1, seed_v)
		party_ok = party_ok and (a.party as Array).size() == 1
		var hero := Characters.create((a.party as Array)[0], a)
		var w = hero.equipment.get("weapon")
		weapon_ok = weapon_ok and w is Dictionary and Rarity.of(w) == "rare"
		for lv in a.levels:
			for it in lv.items:
				var t := str(it.get("type", ""))
				if t == "weapon" or t == "armor" or t == "jewelry":
					gear += 1
					if Rarity.index(Rarity.of(it)) < Rarity.index("rare"):
						below += 1
					if Rarity.index(Rarity.of(it)) >= Rarity.index("epic"):
						high += 1
			loot_rule += (lv.items as Array).size()
			for m in lv.monsters:
				if not m.get("isBoss", false) and absf(float(m.get("hpMult", 1.0)) - 1.25) > 0.001:
					mon_ok = false
		for lv in b.levels:
			loot_base += (lv.items as Array).size()
	var shop_below := 0
	var shop_gear := 0
	var cfg_s: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 15, 15, "normal", ["mod_solo", "mod_legend"], 1, 77)
	for k in 12:
		for o in Shop.random_offers(cfg_s, 1 + k % 4, cfg_s.party):
			if ["weapon", "armor", "jewelry"].has(str(o.type)):
				shop_gear += 1
				if Rarity.index(Rarity.of(o)) < Rarity.index("rare"):
					shop_below += 1
	var xp_ok := absf(float(DungeonGenerator.combine_mods(["mod_solo", "mod_legend"]).xpMult) - 2.0) < 0.001
	var dm := float(DungeonGenerator.combine_mods(["mod_solo", "mod_legend"]).dmgMult)
	var ok := party_ok and mon_ok and weapon_ok and gear > 0 and below == 0 and loot_rule > loot_base and absf(dm - 1.3333) < 0.001 and shop_gear > 0 and shop_below == 0 and xp_ok
	print("SOLO équipements=%d sous-rare=%d épique+=%d objets avec règle=%d sans=%d arme rare=%s monstres=%s héros seul=%s dégâts=%.3f marchands=%d sous-rare=%d xp×2=%s -> %s" % [gear, below, high, loot_rule, loot_base, weapon_ok, mon_ok, party_ok, dm, shop_gear, shop_below, xp_ok, "OK" if ok else "ECHEC"])
	get_tree().quit(0 if ok else 1)
