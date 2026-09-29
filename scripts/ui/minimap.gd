class_name Minimap
extends Control
## Mini-carte : seules les cases découvertes sont dessinées (sol clair sur fond noir), portes, escaliers, joueur.

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

## Découvre les cases visibles : voisinage immédiat + les 4 directions jusqu'au premier mur.
func reveal() -> void:
	if grid == null:
		return
	var s: Dictionary = seen[_level_id]
	var p := Vector2i(rig.gx, rig.gy)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			s[p + Vector2i(dx, dy)] = true
	for v in DungeonGrid.DIRS:
		var q: Vector2i = p
		for i in 12:
			q += v
			s[q] = true
			var ch := grid.cell(q.x, q.y)
			if ch == "#" or ch == "S" or (ch == "D" and not grid.is_walkable(q.x, q.y)):
				break
	queue_redraw()

func _draw() -> void:
	if grid == null:
		return
	# recadre sur la zone découverte pour que la carte reste lisible
	var s: Dictionary = seen[_level_id]
	var lo := Vector2i(grid.width, grid.height)
	var hi := Vector2i(-1, -1)
	for k in s:
		var c: Vector2i = k
		if grid.cell(c.x, c.y) == "#":
			continue
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if hi.x < 0:
		return
	var cols := maxi(hi.x - lo.x + 1, 8)
	var rows := maxi(hi.y - lo.y + 1, 6)
	var cs := minf(size.x / cols, size.y / rows)
	cs = minf(cs, 22.0)
	var origin := (size - Vector2(cols, rows) * cs) * 0.5
	for k in s:
		var c: Vector2i = k
		var ch := grid.cell(c.x, c.y)
		if ch == "#":
			continue
		var col := Color("9c8158")
		if ch == "D":
			var d := grid.door_at(c.x, c.y)
			col = Color("c98a2e") if (d.is_empty() or not grid.opened.has(str(d.id))) else col
		elif ch == "S":
			col = Color("4fb3d9")
		var pos := origin + Vector2(c.x - lo.x, c.y - lo.y) * cs
		draw_rect(Rect2(pos, Vector2(cs, cs)).grow(-0.6), col)
	var pc := origin + (Vector2(rig.gx - lo.x, rig.gy - lo.y) + Vector2(0.5, 0.5)) * cs
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	var f := Vector2(v.x, v.y)
	var side := Vector2(-f.y, f.x)
	var r := cs * 0.45
	draw_colored_polygon(PackedVector2Array([pc + f * r, pc - f * r * 0.7 + side * r * 0.7, pc - f * r * 0.7 - side * r * 0.7]), UiTheme.GOLD)
