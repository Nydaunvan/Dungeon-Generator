extends Node
## Butin des boss selon la difficulté : part de légendaires et de mythiques sur un grand nombre de donjons générés (graines fixes), sans puis avec « Nid de monstres ».
## Les taux doivent croître de Facile à Hardcore (légendaire très rare et mythique quasi inexistant en Facile).
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_boss_loot.tscn
func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	var base: Dictionary = Data.original_config
	var ok := true
	var prev_leg := -1.0
	var prev_myth := -1.0
	for mods in [[], ["mod_horde2"]]:
		prev_leg = -1.0
		prev_myth = -1.0
		for diff in ["easy", "normal", "hard", "hardcore"]:
			var bosses := 0
			var leg := 0
			var myth := 0
			for sd in 150:
				var cfg: Dictionary = DungeonGenerator.build_config(base, 4, 13, 11, diff, mods, 1, 9000 + sd)
				for lv in cfg.levels:
					for it in lv.items:
						if str(it.id).begins_with("loot_boss_"):
							bosses += 1
							var r := str(it.get("rarity", ""))
							if r == "legendary" or r == "mythic":
								leg += 1
							if r == "mythic":
								myth += 1
			var pl := 100.0 * leg / maxf(1.0, bosses)
			var pm := 100.0 * myth / maxf(1.0, bosses)
			print("%-9s %-12s %d boss : légendaire ou mieux %5.1f %%  dont mythique %5.1f %%" % [diff, "avec Nid" if not mods.is_empty() else "sans modif.", bosses, pl, pm])
			if mods.is_empty():
				if pl < prev_leg or pm < prev_myth:
					ok = false
				prev_leg = pl
				prev_myth = pm
				if diff == "easy" and (pl > 12.0 or pm > 3.0):
					ok = false
				if diff == "easy" and pm <= 0.0:
					print("  (mythique impossible en Facile : attendu ‘quasi inexistant mais possible’)")
	print("RESULTAT butin des boss -> ", "OK" if ok else "ECHEC")
	get_tree().quit()
