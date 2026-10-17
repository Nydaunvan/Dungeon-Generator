extends Node
## Contrôle sur de nombreux donjons générés : la clé d'une porte verrouillée n'est jamais sur un escalier ni sur le départ,
## ni derrière la porte qu'elle ouvre (atteignable depuis le départ avec la porte fermée).
func _ready() -> void:
	var bad := 0
	var locked := 0
	for n in 150:
		var cfg: Dictionary = DungeonGenerator.build_config(Data.original_config, 3, 20, 20, "normal", [])
		for lv in cfg.levels:
			var rows: Array = lv.mapRows
			var grid: Array = []
			for r in rows:
				grid.append(str(r).split(""))
			var stairs := {}
			for st in lv.stairs:
				stairs["%d,%d" % [int(st.x), int(st.y)]] = true
			for it in lv.items:
				if str(it.get("type", "")) != "key" or bool(it.get("startHidden", false)):
					continue
				locked += 1
				var door := {}
				for d in lv.doors:
					if str(d.id) == str(it.get("opensDoorId", "")):
						door = d
				var k := "%d,%d" % [int(it.x), int(it.y)]
				var d2 := DungeonGenerator.bfs(grid, int(lv.startX), int(lv.startY), Vector2i(int(door.x), int(door.y)))
				if stairs.has(k) or (int(it.x) == int(lv.startX) and int(it.y) == int(lv.startY)) or d2[int(it.y)][int(it.x)] == -1:
					bad += 1
					print("MAUVAIS : clé en ", k, " escalier=", stairs.has(k))
	print("clés testées : ", locked, " — ", "OK : clés bien placées" if bad == 0 else "ÉCHEC : %d" % bad)
	get_tree().quit()
