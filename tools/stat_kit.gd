extends Node
## Statistiques du kit gothic sur des niveaux générés : arches par niveau (outil de mesure, aucune règle).
func _ready():
	await get_tree().create_timer(1.0).timeout
	var DG = DungeonGenerator
	var tot := {"lv": 0, "arch": 0, "room": 0, "rib": 0, "elig_run": 0, "cells": 0}
	for seed_i in 10:
		for dims in [[13, 11], [19, 15], [25, 21]]:
			var cfg: Dictionary = DG.build_config(Data.original_config, 3, dims[0], dims[1], "normal", [], 1, 1000 + seed_i)
			for lv in cfg.levels:
				var grid := DungeonGrid.new(lv)
				var nd := LevelBuilder.niche_data(grid, lv, false)
				var sp := KitDecor._special_cells(lv, RoomDecor._blocked_cells(lv), nd.niches)
				var ar := KitDecor._arch_edges(lv, grid, sp, str(lv.id).hash())
				tot.lv += 1
				tot.arch += ar.size()
				for a in ar:
					if a.kind == "room":
						tot.room += 1
				tot.rib += KitDecor._rib_edges(grid, sp, str(lv.id).hash(), ar).size()
				var ridx := RoomMap.index(RoomMap.detect(lv.mapRows))
				for y in grid.height:
					for x in grid.width:
						var c := Vector2i(x, y)
						if grid.cell(x, y) == ".": tot.cells += 1
						for e in [Vector2i(1, 0), Vector2i(0, 1)]:
							var nb: Vector2i = c + e
							if grid.cell(nb.x, nb.y) == "." and KitDecor._arch_ok(grid, c, e, sp) and KitDecor._arch_ok(grid, nb, e, sp):
								tot.elig_run += 1
	print(tot, " arches/niveau ", float(tot.arch) / tot.lv)
	get_tree().quit()
