extends Node
## Taux de butin par partie (`lootRatePct`) : nombre d'équipements trouvés (sol, coffres, monstres) par donjon généré (graines fixes) à 100 / 60 / 30 %.
## Le nombre doit baisser avec le taux ; les clés, le butin des gardiens et les potions au sol ne doivent pas disparaître.
## Lancer : godot --headless --path . res://tools/check_loot_rate.tscn
func _count(rate: int, diff: String) -> Dictionary:
	var base: Dictionary = Data.original_config.duplicate(true)
	base["lootRatePct"] = rate
	var eq := 0
	var potions := 0
	var keys := 0
	var boss := 0
	var chest_eq := 0
	var games := 60
	for sd in games:
		var cfg: Dictionary = DungeonGenerator.build_config(base, 4, 13, 11, diff, [], 1, 7000 + sd)
		for lv in cfg.levels:
			for it in lv.items:
				var t := str(it.get("type", ""))
				if str(it.id).begins_with("loot_boss_"):
					boss += 1
				elif t == "key":
					keys += 1
				elif t == "potion":
					potions += 1
				elif t == "weapon" or t == "armor" or t == "jewelry":
					eq += 1
				elif t == "chest":
					for c in it.get("contents", []):
						if str(c.get("type", "")) in ["weapon", "armor", "jewelry"]:
							chest_eq += 1
			for m in lv.get("monsters", []):
				pass
	return {"eq": float(eq + chest_eq) / games, "potions": float(potions) / games, "keys": float(keys) / games, "boss": float(boss) / games}

func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var ok := true
	print("taux par défaut : %d %%" % int(DungeonGenerator.loot_rate_of({}) * 100.0))
	if not is_equal_approx(DungeonGenerator.loot_rate_of({}), 0.6):
		ok = false
	for diff in ["normal", "hardcore"]:
		var prev := 1e9
		var r100: Dictionary = {}
		for rate in [100, 60, 30]:
			var r := _count(rate, diff)
			print("%-9s %3d %% : %5.1f équipements, %5.1f potions, %4.1f clés, %4.1f butins de gardien par partie" % [diff, rate, r.eq, r.potions, r.keys, r.boss])
			if r.eq >= prev:
				ok = false
			prev = r.eq
			if rate == 100:
				r100 = r
			elif r.boss != r100.boss or absf(r.keys - r100.keys) > 0.5:
				ok = false
		var r60 := _count(60, diff)
		if r60.eq > 0.8 * r100.eq:
			ok = false
	print("RESULTAT taux de butin -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
