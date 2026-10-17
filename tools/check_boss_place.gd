extends Node
## Contrôle : dans les donjons générés, le boss est toujours au fond du niveau : son chemin depuis l'arrivée fait au moins
## min(max(8, 60 % du chemin jusqu'à la sortie), chemin de sortie − 2) cases.
func _ready() -> void:
	var bad := 0
	var total := 0
	var worst := 999
	for n in 200:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 4, 20, 20, ["normal", "hard", "easy"][n % 3], [])
		for lv in cfg.levels:
			var grid: Array = []
			for r in lv.mapRows:
				grid.append(str(r).split(""))
			var d := DungeonGenerator.bfs(grid, int(lv.startX), int(lv.startY))
			var fwd: Dictionary = lv.stairs[0]
			var far_d: int = d[int(fwd.y)][int(fwd.x)]
			var need := mini(maxi(8, int(ceil(float(far_d) * 0.6))), maxi(far_d - 2, 0))
			for m in lv.monsters:
				if bool(m.get("isBoss", false)):
					total += 1
					var bd: int = d[int(m.y)][int(m.x)]
					worst = mini(worst, bd)
					if bd < need:
						bad += 1
						print("MAUVAIS : boss à ", bd, " (sortie à ", far_d, ", requis ", need, ")")
	print("boss testés : ", total, " — plus proche : ", worst, " cases — ", "OK : boss toujours au fond du niveau" if bad == 0 else "ÉCHEC : %d" % bad)
	get_tree().quit()
