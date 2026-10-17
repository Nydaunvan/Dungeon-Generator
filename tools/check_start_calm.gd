extends Node
## Aucun monstre près de l'arrivée du joueur (départ et escalier de retour), et répit à l'arrivée dans un niveau.
func _ready() -> void:
	var worst := 99
	var worst_boss := 99
	var n := 0
	for s in 60:
		var cfg := DungeonGenerator.build_config(Data.active(), 3, 13, 11, ["easy", "normal", "hard", "hardcore"][s % 4], [], 1, 1000 + s)
		for lv in cfg.levels:
			var spots: Array = [Vector2i(int(lv.startX), int(lv.startY))]
			for st in lv.get("stairs", []):
				spots.append(Vector2i(int(st.x), int(st.y)))
			for m in lv.monsters:
				if m.get("isBoss", false):
					worst_boss = mini(worst_boss, absi(int(m.x) - spots[0].x) + absi(int(m.y) - spots[0].y))
					continue
				for sp in spots:
					worst = mini(worst, absi(int(m.x) - sp.x) + absi(int(m.y) - sp.y))
			n += 1
	var good: bool = worst >= 5 and worst_boss >= 6 and Wanderers.ARRIVAL_CALM_TICKS >= 16
	print("STARTCALM niveaux=", n, " plus_proche=", worst, " boss=", worst_boss, " repit=", Wanderers.ARRIVAL_CALM_TICKS, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
