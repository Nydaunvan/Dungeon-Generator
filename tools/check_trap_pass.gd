extends Node
## Vérifie que chaque piège généré est sur le passage obligé (le bloquer coupe la sortie) et jamais dans une impasse ; mesure le temps de génération.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var DG = DungeonGenerator
	var bad := 0
	var traps := 0
	var loot := 0
	var worst := 0
	for n in 6:
		var t0 := Time.get_ticks_msec()
		var cfg: Dictionary = DG.build_config(Data.config, 3, 25, 25, "normal", [], 1)
		worst = maxi(worst, Time.get_ticks_msec() - t0)
		for lv in cfg.levels:
			var rows: Array = lv.mapRows
			var grid: Array = []
			for r in rows:
				grid.append(str(r).split(""))
			var sx := int(lv.startX)
			var sy := int(lv.startY)
			var far: Dictionary = {}
			for st in lv.stairs:
				if str(st.id).ends_with("_fwd"):
					far = st
			for it in lv.items:
				if str(it.get("type", "")) == "trap":
					traps += 1
					var d: Array = DG.bfs(grid, sx, sy, Vector2i(int(it.x), int(it.y)))
					if int(d[int(far.y)][int(far.x)]) >= 0:
						bad += 1
				elif str(it.id).contains("trapless"):
					loot += 1
	print("pièges : %d hors passage : %d · objets en remplacement : %d · génération max %d ms" % [traps, bad, loot, worst])
	print("RESULTAT passage des pièges -> ", "OK" if bad == 0 and traps > 0 else "ECHEC")
	get_tree().quit()
