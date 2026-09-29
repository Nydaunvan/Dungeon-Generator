class_name DungeonGrid
extends RefCounted
## Grille du niveau (mapRows). '#' mur, '.' sol, 'D' porte, 'S' escalier.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # N, E, S, O

var rows: Array[String] = []
var width: int = 0
var height: int = 0

func _init(map_rows: Array) -> void:
	for r in map_rows:
		rows.append(str(r))
	height = rows.size()
	width = rows[0].length() if height > 0 else 0

func cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= width:
		return "#"
	return rows[y].substr(x, 1)

func is_walkable(x: int, y: int) -> bool:
	var c := cell(x, y)
	return c != "#" and c != "D" and c != "S"
