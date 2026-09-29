class_name DungeonGrid
extends RefCounted
## Grille du niveau (mapRows). '#' mur, '.' sol, 'D' porte, 'S' escalier.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)] # N, E, S, O

var level: Dictionary
var rows: Array[String] = []
var width: int = 0
var height: int = 0
var doors: Dictionary = {}   # Vector2i -> définition de porte
var stairs: Dictionary = {}  # Vector2i -> définition d'escalier
var opened: Dictionary = {}  # id de porte -> true

func _init(lvl: Dictionary) -> void:
	level = lvl
	for r in lvl.mapRows:
		rows.append(str(r))
	height = rows.size()
	width = rows[0].length() if height > 0 else 0
	for d in lvl.get("doors", []):
		doors[Vector2i(int(d.x), int(d.y))] = d
	for s in lvl.get("stairs", []):
		stairs[Vector2i(int(s.x), int(s.y))] = s

func cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= width:
		return "#"
	return rows[y].substr(x, 1)

func door_at(x: int, y: int) -> Dictionary:
	return doors.get(Vector2i(x, y), {})

func stairs_at(x: int, y: int) -> Dictionary:
	return stairs.get(Vector2i(x, y), {})

func is_walkable(x: int, y: int) -> bool:
	var c := cell(x, y)
	if c == "#" or c == "S":
		return false
	if c == "D":
		var d := door_at(x, y)
		return not d.is_empty() and opened.has(str(d.get("id", "")))
	return true
