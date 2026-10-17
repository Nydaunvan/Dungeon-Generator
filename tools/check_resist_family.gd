extends Node
## Contrôle : dans les donjons générés, tout monstre (et boss) d'une famille à résistances les a TOUJOURS, chaque valeur est
## dans sa fourchette et jamais zéro (un élémentaire de feu résiste toujours au feu, un élémentaire de glace à la glace).
func _ready() -> void:
	var seen := 0
	var bad := 0
	var fam := {}
	for n in 120:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 4, 20, 20, "normal", [])
		for lv in cfg.levels:
			for m in lv.monsters:
				var id := str(m.get("icon", "")).replace("@icon:", "")
				var row: Dictionary = (Resist.BOSS if bool(m.get("isBoss", false)) else Resist.FAMILY).get(id, {})
				if row.is_empty():
					continue
				seen += 1
				fam[id] = true
				var res: Dictionary = m.get("resists", {})
				for k in row.keys():
					var v := int(res.get(k, 0))
					if v == 0 or v < int(row[k][0]) or v > int(row[k][1]):
						bad += 1
						print("MAUVAIS : ", id, " ", k, "=", v)
	print("monstres testés : ", seen, " familles : ", fam.size(), " — ", "OK : résistances de famille toujours présentes" if bad == 0 else "ÉCHEC : %d" % bad)
	get_tree().quit()
