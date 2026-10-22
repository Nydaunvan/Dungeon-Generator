extends Node
## Salles du générateur : niveau toujours connecté, sortie et départ jamais dans une salle, aucune porte dans une salle, salles de taille bornée
## (jamais un niveau d'une seule salle), part de salles raisonnable, bien réparties ; ancien labyrinthe (legacy_layout) sans aucune salle.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var DG = DungeonGenerator
	var fails: Array = []
	var total_levels := 0
	var with_rooms := 0
	var worst_share := 0.0
	var worst_dim := 0
	var rooms_total := 0
	var chests_total := 0
	var chests_in_rooms := 0
	var shares: Array = []
	for seed_i in 10:
		for dims in [[13, 11], [19, 15], [9, 9]]:
			var cfg: Dictionary = DG.build_config(Data.original_config, 3, dims[0], dims[1], "normal", [], 1, 1000 + seed_i)
			for lv in cfg.levels:
				total_levels += 1
				var rows: Array = lv.mapRows
				var grid: Array = []
				for r in rows:
					grid.append(str(r).split(""))
				var sx := int(lv.startX)
				var sy := int(lv.startY)
				var dist: Array = DG.bfs(grid, sx, sy)
				var floor_n := 0
				for y in rows.size():
					for x in str(rows[0]).length():
						var ch: String = grid[y][x]
						if ch != "#":
							floor_n += 1
							if ch != "S" and int(dist[y][x]) < 0 and not (ch == "D"):
								fails.append("case inaccessible %d,%d (graine %d, %s)" % [x, y, 1000 + seed_i, str(dims)])
				var rooms := RoomMap.detect(rows)
				var idx := RoomMap.index(rooms)
				if not rooms.is_empty():
					with_rooms += 1
				rooms_total += rooms.size()
				var in_rooms := 0
				for r in rooms:
					in_rooms += r.cells.size()
					worst_dim = maxi(worst_dim, maxi(r.rect.size.x, r.rect.size.y))
					if r.rect.size.x > 5 or r.rect.size.y > 5:
						fails.append("salle trop grande %s" % str(r.rect))
				var share := float(in_rooms) / float(maxi(1, floor_n))
				shares.append(share)
				worst_share = maxf(worst_share, share)
				if share > 0.55:
					fails.append("trop de salles : %.0f %%" % (share * 100.0))
				if idx.has(Vector2i(sx, sy)):
					fails.append("départ dans une salle")
				for st in lv.stairs:
					if idx.has(Vector2i(int(st.x), int(st.y))):
						fails.append("escalier dans une salle")
				for d in lv.doors:
					if idx.has(Vector2i(int(d.x), int(d.y))):
						fails.append("porte dans une salle")
				# coffres : sur une case de sol libre, contre un vrai mur, contenu non vide, jamais avec un autre objet, un escalier ou une porte
				var taken := {}
				for it in lv.items:
					if str(it.get("type", "")) != "chest":
						taken[Vector2i(int(it.x), int(it.y))] = taken.get(Vector2i(int(it.x), int(it.y)), 0) + 1
				for it in lv.items:
					if str(it.get("type", "")) != "chest":
						continue
					chests_total += 1
					var cp := Vector2i(int(it.x), int(it.y))
					if str(rows[cp.y])[cp.x] != ".":
						fails.append("coffre hors d'une case de sol")
					if taken.has(cp):
						fails.append("coffre sur la case d'un autre objet")
					var dv: Vector2i = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "O": Vector2i(-1, 0)}.get(str(it.get("wall", "")), Vector2i.ZERO)
					if dv == Vector2i.ZERO or str(rows[cp.y + dv.y])[cp.x + dv.x] != "#":
						fails.append("coffre sans mur à son dos")
					if (it.get("contents", []) as Array).is_empty() or int(it.get("gold", 0)) <= 0:
						fails.append("coffre vide")
					if idx.has(cp):
						chests_in_rooms += 1
	print("coffres ", chests_total, " dont en salle ", chests_in_rooms)
	if chests_total == 0:
		fails.append("aucun coffre généré")
	print("niveaux ", total_levels, " dont avec salles ", with_rooms, " ; salles ", rooms_total, " ; plus grande dimension ", worst_dim, " ; part max ", int(worst_share * 100), " %")
	# ancien labyrinthe : aucune salle
	DG.legacy_layout = true
	var legacy_rooms := 0
	for seed_i in 10:
		var cfg2: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 500 + seed_i)
		for lv in cfg2.levels:
			legacy_rooms += RoomMap.detect(lv.mapRows).size()
			for it in lv.items:
				if str(it.get("type", "")) == "chest":
					fails.append("coffre dans l'ancien labyrinthe")
	DG.legacy_layout = false
	print("ancien labyrinthe : salles ", legacy_rooms)
	if legacy_rooms != 0:
		fails.append("legacy_layout produit des salles")
	if with_rooms < total_levels / 2:
		fails.append("trop peu de niveaux avec salles (%d/%d)" % [with_rooms, total_levels])
	# reproductibilité : même graine -> même donjon
	var a: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 77)
	var b: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 77)
	if JSON.stringify(a.levels) != JSON.stringify(b.levels):
		fails.append("génération non reproductible")
	var uniq := {}
	for f in fails:
		uniq[f] = int(uniq.get(f, 0)) + 1
	for f in uniq:
		print("ECHEC ", f, " x", uniq[f])
	print("RESULTAT salles -> %s" % ("OK" if fails.is_empty() else "ECHEC"))
	get_tree().quit()
