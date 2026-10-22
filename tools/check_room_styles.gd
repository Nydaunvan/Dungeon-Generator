extends Node
## Vérifie les styles de salle : attribution déterministe et variée, contenu respecté (boss, trésor, marchand), choix de l'éditeur,
## et accessoires jamais au centre d'une case ni sur une case occupée (objet, escalier, marchand, départ).

const CELL := LevelBuilder.CELL

func _ready() -> void:
	var bad := 0
	var rooms_n := 0
	var consec := 0
	var counts := {}
	var props_total := 0
	var worst := 0
	for t in 40:
		var theme: String = ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"][t % 7]
		var cfg: Dictionary = DungeonGenerator.build_config(Data.config, 2, 25, 19, "normal", [], 1, 9000 + t)
		for lv in cfg.levels:
			lv["theme"] = theme
			var rows: Array = lv.mapRows
			var rooms := RoomMap.detect(rows)
			if rooms.is_empty():
				continue
			var st1 := RoomStyles.assign(lv, rooms, theme)
			var st2 := RoomStyles.assign(lv, rooms, theme)
			if st1 != st2:
				bad += 1
				print("ÉCHEC non déterministe")
			var idx := RoomMap.index(rooms)
			var forced := {}
			for m in lv.monsters:
				if bool(m.get("isBoss", false)) and idx.has(Vector2i(int(m.x), int(m.y))):
					forced[idx[Vector2i(int(m.x), int(m.y))]] = "repaire"
			for id in forced:
				if st1[id] != "repaire":
					bad += 1
					print("ÉCHEC boss sans repaire")
			var tm = lv.get("travelingMerchant")
			if tm is Dictionary and idx.has(Vector2i(int(tm.x), int(tm.y))) and not forced.has(idx[Vector2i(int(tm.x), int(tm.y))]):
				if st1[idx[Vector2i(int(tm.x), int(tm.y))]] != "marche":
					bad += 1
					print("ÉCHEC marchand sans marché")
			var chest_rooms: Array = []
			for it in lv.items:
				if str(it.get("type", "")) == "chest" and idx.has(Vector2i(int(it.x), int(it.y))):
					chest_rooms.append(idx[Vector2i(int(it.x), int(it.y))])
			if not chest_rooms.is_empty():
				var any_rich := false
				for sid in chest_rooms:
					if st1[sid] == "tresor" or st1[sid] == "repaire" or st1[sid] == "marche":
						any_rich = true
				if not any_rich:
					bad += 1
					print("ÉCHEC niveau avec coffres en salle mais sans salle de trésor")
			# variété : jamais deux styles courants identiques de suite (salles triées haut-gauche)
			var order: Array = rooms.duplicate()
			order.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y or (a.rect.position.y == b.rect.position.y and a.rect.position.x < b.rect.position.x))
			for i in range(1, order.size()):
				var a: String = st1[int(order[i - 1].id)]
				var b: String = st1[int(order[i].id)]
				if a == b and RoomStyles.GENERAL.has(a):
					consec += 1
			for r in rooms:
				rooms_n += 1
				counts[st1[int(r.id)]] = int(counts.get(st1[int(r.id)], 0)) + 1
			# choix de l'éditeur prioritaire
			var ov := {RoomStyles.key_of(rooms[0].rect): "repaire"}
			lv["roomStyles"] = ov
			if RoomStyles.assign(lv, rooms, theme)[int(rooms[0].id)] != "repaire":
				bad += 1
				print("ÉCHEC choix de l'éditeur ignoré")
			lv.erase("roomStyles")
			# accessoires : chaque style sur chaque salle
			var blocked := {}
			for it in lv.items:
				blocked[Vector2i(int(it.x), int(it.y))] = true
			for st in lv.stairs:
				blocked[Vector2i(int(st.x), int(st.y))] = true
			if tm is Dictionary:
				blocked[Vector2i(int(tm.x), int(tm.y))] = true
			blocked[Vector2i(int(lv.startX), int(lv.startY))] = true
			for r in rooms:
				var inside := {}
				for c in r.cells:
					inside[c] = true
				for style in RoomStyles.ALL:
					for ved in [true, false]:
						var plan := RoomProps.plan({"rows": rows, "inside": inside, "cells": r.cells, "rect": r.rect, "blocked": blocked, "seed": 1234 + int(r.id), "vedette": ved, "style": style})
						props_total += plan.prims.size()
						worst = maxi(worst, plan.prims.size())
						var vtx = plan.vertex
						for pr in plan.prims:
							var p: Vector3 = pr.p
							var h: float = float(pr.z.y)
							if str(pr.s) == "box" and float(pr.pit) != 0.0:
								h = 0.5
							if h < 0.16 or (str(pr.s) == "cyl" and (float(pr.pit) != 0.0 or float(pr.rol) != 0.0)):
								continue      # tapis, flaques, pièces : à plat
							if vtx != null and Vector2(p.x, p.z).distance_to(Vector2((vtx.x - 0.5) * CELL, (vtx.y - 0.5) * CELL)) < 1.7:
								continue      # pièce maîtresse sur un sommet
							var cell := Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))
							var dx := absf(p.x - cell.x * CELL)
							var dz := absf(p.z - cell.y * CELL)
							if dx < 0.8 and dz < 0.8:
								bad += 1
								print("ÉCHEC accessoire au centre d'une case : ", style, " ", p, " ", pr.m)
							if blocked.has(cell) and p.y < CELL - 0.5 and p.y > 0.0:
								bad += 1
								print("ÉCHEC accessoire sur case occupée : ", style, " ", cell, " ", pr.m)
	if consec > 0:
		bad += 1
		print("ÉCHEC styles courants identiques consécutifs : ", consec)
	print("salles=", rooms_n, " styles=", counts, " accessoires/salle moyen=", props_total / maxi(1, rooms_n * 20), " max=", worst)
	for s in RoomStyles.GENERAL:
		if int(counts.get(s, 0)) == 0:
			bad += 1
			print("ÉCHEC style jamais tiré : ", s)
	print("check_room_styles : ", "OK" if bad == 0 else "%d échec(s)" % bad)
	get_tree().quit(1 if bad > 0 else 0)
