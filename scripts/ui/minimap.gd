class_name Minimap
extends Control
## Mini-carte : cases découvertes, portes, escaliers, joueur (flèche).

var grid: DungeonGrid
var rig: PlayerRig
var seen: Dictionary = {}   # niveau -> { Vector2i: true }
var _level_id: String = ""

func bind(g: DungeonGrid, r: PlayerRig) -> void:
	grid = g
	rig = r
	_level_id = str(g.level.get("id", ""))
	if not seen.has(_level_id):
		seen[_level_id] = {}
	reveal()

## Découvre les cases proches du joueur.
func reveal() -> void:
	if grid == null:
		return
	var s: Dictionary = seen[_level_id]
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			s[Vector2i(rig.gx + dx, rig.gy + dy)] = true
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0705"))
	if grid == null:
		return
	var cs := minf(size.x / grid.width, size.y / grid.height)
	var origin := (size - Vector2(grid.width, grid.height) * cs) * 0.5
	var s: Dictionary = seen[_level_id]
	for y in grid.height:
		for x in grid.width:
			if not s.has(Vector2i(x, y)):
				continue
			var ch := grid.cell(x, y)
			var col := Color("2b2118")
			match ch:
				"#": col = Color("5a4630")
				".": col = Color("8a7250").darkened(0.45)
				"D":
					var d := grid.door_at(x, y)
					col = Color("6a4a20") if (d.is_empty() or not grid.opened.has(str(d.id))) else Color("8a7250").darkened(0.45)
				"S": col = Color("4a7ac8")
			draw_rect(Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-0.5), col)
	# joueur : triangle orienté
	var c := origin + (Vector2(rig.gx, rig.gy) + Vector2(0.5, 0.5)) * cs
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	var f := Vector2(v.x, v.y)
	var side := Vector2(-f.y, f.x)
	var r := cs * 0.42
	draw_colored_polygon(PackedVector2Array([c + f * r, c - f * r * 0.7 + side * r * 0.7, c - f * r * 0.7 - side * r * 0.7]), UiTheme.GOLD)
