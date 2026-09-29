extends Control
## Point d'entrée temporaire : vérifie que les données et les formules sont chargées.

func _ready() -> void:
	var cfg: Dictionary = Data.config
	print("Donjon : ", cfg.get("title", "?"))
	print("Niveaux: %d | Classes: %d | Sorts: %d" % [cfg.levels.size(), cfg.classes.size(), cfg.spells.size()])
	for c in cfg.party:
		var b := Stats.char_base(c)
		print("%s -> PV %d, ATK %d-%d" % [c.name, b.maxHp, b.baseAtkMin, b.baseAtkMax])
