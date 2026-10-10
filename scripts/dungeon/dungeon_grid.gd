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
var opening_until: Dictionary = {}   # id de porte -> temps de jeu (GameClock.ms) à partir duquel on peut passer
## Délai avant de pouvoir passer sous une grille qui monte (≈ mi-course de l'animation d'ouverture). Fixé en temps DE JEU, pas en
## temps d'animation, pour que la partie se rejoue à l'identique.
const OPEN_PASS_MS := 2400

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

## La grille commence à s'ouvrir : infranchissable jusqu'à `OPEN_PASS_MS` de temps de jeu.
func start_opening(id: String) -> void:
	if not opened.has(id) and not opening_until.has(id):
		opening_until[id] = GameClock.ms + OPEN_PASS_MS

func _promote() -> void:
	if opening_until.is_empty():
		return
	for id in opening_until.keys():
		if GameClock.ms >= int(opening_until[id]):
			opened[id] = true
			opening_until.erase(id)

func is_open(id: String) -> bool:
	_promote()
	return opened.has(id)

func is_opening(id: String) -> bool:
	_promote()
	return opening_until.has(id)

func is_walkable(x: int, y: int) -> bool:
	var c := cell(x, y)
	if c == "#" or c == "S":
		return false
	if c == "D":
		var d := door_at(x, y)
		return not d.is_empty() and is_open(str(d.get("id", "")))
	return true
