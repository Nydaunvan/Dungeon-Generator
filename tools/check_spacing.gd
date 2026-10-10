extends Node
## Espacement des monstres à la génération : jamais deux monstres à moins de 3 cases (donc pas de combat sur combat), et le plus souvent bien plus.
## Lancer : xvfb-run -a godot --path . res://tools/check_spacing.tscn --quit-after 600

var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _ready() -> void:
	var sizes := [[13, 11], [15, 13], [20, 16], [9, 9], [30, 24]]
	var total_pairs := 0
	var close_pairs := 0      # moins de 6 cases
	var worst := 99
	var boss_worst := 99
	var levels_count := 0
	for sz in sizes:
		for seed in range(1, 15):
			var cfg := DungeonGenerator.build_config(Data.original_config, 3, int(sz[0]), int(sz[1]), "normal", [], 1, Seeds.from_text("espacement-%d-%d" % [int(sz[0]), seed]))
			for lvl in cfg.get("levels", []):
				levels_count += 1
				var ms: Array = lvl.get("monsters", [])
				for i in ms.size():
					for j in range(i + 1, ms.size()):
						var d: int = absi(int(ms[i].x) - int(ms[j].x)) + absi(int(ms[i].y) - int(ms[j].y))
						total_pairs += 1
						worst = mini(worst, d)
						if bool(ms[i].get("isBoss", false)) or bool(ms[j].get("isBoss", false)):
							boss_worst = mini(boss_worst, d)
						if d < 6:
							close_pairs += 1
	print("niveaux : %d, paires : %d, plus proche : %d, plus proche du boss : %d, paires < 6 cases : %d" % [levels_count, total_pairs, worst, boss_worst, close_pairs])
	check("aucun monstre à moins de 3 cases d'un autre", worst >= 3)
	check("aucune paire proche en grande majorité", close_pairs * 10 <= total_pairs)
	print("check_spacing : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
