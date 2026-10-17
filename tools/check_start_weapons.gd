extends Node
## Vérifie que chaque classe démarre avec son arme emblématique (bâton pour mage/druide, épée guerrier, arc archer, masse prêtre, dague roublard…).

func _ready() -> void:
	var bad := 0
	var seen := {}
	for t in 300:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.config, 3 + t % 3, 13, 11, ["normal", "hard", "hardcore"][t % 3], [], 1)
		for h in cfg.party:
			var cls := Characters.class_def(cfg, str(h.classId))
			var want := Characters.signature_weapon_type(cls)
			var c := Characters.create(h, cfg)
			var w = c.equipment.get("weapon")
			var got := str(w.get("weaponType", "")) if w != null else ""
			seen[str(h.classId)] = got
			if got != want:
				bad += 1
				print("classe ", h.classId, " : ", got, " au lieu de ", want)
	print(seen)
	print("armes de départ : anomalies %d" % bad)
	get_tree().quit()
