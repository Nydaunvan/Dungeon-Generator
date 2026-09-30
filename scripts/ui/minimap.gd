class_name Minimap
extends Control
## Mini-carte (portage de renderMinimap) : cases vues (jusqu'à 4 devant le groupe) et visitées, portes, escaliers, fontaines,
## marchand découvert, monstres vivants. Molette / double-clic : zoom. Le modificateur « Brouillard épais » réduit la zone visible.

var grid: DungeonGrid
var rig: PlayerRig
var gs: GameState
var zoom: int = 1
var full: bool = false   # carte plein écran : tout le niveau, sans zoom
var merchant_cell: Callable = Callable()   # () -> Vector2i, (-1, -1) tant que le marchand n'est pas découvert

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func bind(g: DungeonGrid, r: PlayerRig, state: GameState) -> void:
	grid = g
	rig = r
	gs = state
	zoom = 1
	mark_visited()
	reveal()

func _ls() -> Dictionary:
	return gs.level_state(grid.level)

static func _k(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

## La case du groupe est visitée (à appeler après chaque pas).
func mark_visited() -> void:
	if grid == null:
		return
	var ls := _ls()
	ls.get_or_add("visited", {})[_k(rig.gx, rig.gy)] = true
	ls.get_or_add("seen", {})[_k(rig.gx, rig.gy)] = true

## Découvre les 4 cases devant le groupe (et la suivante, même si c'est un mur).
func reveal() -> void:
	if grid == null:
		return
	var seen: Dictionary = _ls().get_or_add("seen", {})
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	for d in 5:
		seen[_k(rig.gx + v.x * d, rig.gy + v.y * d)] = true
	queue_redraw()

func _max_zoom() -> int:
	return maxi(1, int(floor(maxi(grid.width, grid.height) / 10.0)))

func _gui_input(event: InputEvent) -> void:
	if grid == null or full:
		return
	var step := 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = -1
		elif event.double_click:
			zoom = zoom % _max_zoom() + 1   # tactile : double-toucher fait défiler les niveaux de zoom
			queue_redraw()
			accept_event()
			return
	if step != 0:
		zoom = clampi(zoom + step, 1, _max_zoom())
		queue_redraw()
		accept_event()

func _draw() -> void:
	if grid == null or gs == null:
		return
	var ls := _ls()
	var seen: Dictionary = ls.get("seen", {})
	var visited: Dictionary = ls.get("visited", {})
	var W := grid.width
	var H := grid.height
	# zone affichée, centrée sur le groupe (mêmes formules que le JS, en « pixels virtuels »)
	var z := clampi(zoom, 1, _max_zoom())
	var base_px := clampi(int(floor(320.0 / maxi(W, H))), 3, 16)
	var cpx := mini(28, base_px * z)
	var fog := (gs.cfg.get("runModifierIds", []) as Array).has("mod_fog")
	var budget := 130 if fog else 300
	var vw := maxi(4, mini(W, int(floor(budget / float(cpx)))))
	var vh := maxi(4, mini(H, int(floor(budget / float(cpx)))))
	if full:
		vw = W
		vh = H
	var ox := clampi(rig.gx - vw / 2, 0, W - vw)
	var oy := clampi(rig.gy - vh / 2, 0, H - vh)
	var cs := minf(size.x / vw, size.y / vh)
	var origin := (size - Vector2(vw, vh) * cs) * 0.5
	draw_rect(Rect2(origin, Vector2(vw, vh) * cs), Color("080604"))
	for y in range(oy, oy + vh):
		for x in range(ox, ox + vw):
			var key := _k(x, y)
			var vis := visited.has(key)
			if not vis and not seen.has(key):
				continue
			var ch := grid.cell(x, y)
			var col := Color("2b2620") if ch == "#" else (Color("c9a86a") if vis else Color("6e5a3e"))
			if ch == "D":
				col = Color("5a3712") if vis else Color("3a2a18")
			elif ch == "S":
				col = Color("8a5f16") if vis else Color("5a4212")
			var pos := origin + Vector2(x - ox, y - oy) * cs
			draw_rect(Rect2(pos, Vector2(cs, cs) * (1.0 - 1.0 / float(cpx))), col)
			if ch == "S" and cs >= 5.0:
				var c := pos + Vector2(cs, cs) * 0.5
				var r := cs * 0.32
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), Color("ffe08a"))
			elif ch == "D" and cs >= 5.0:
				draw_rect(Rect2(pos + Vector2(cs, cs) * 0.3, Vector2(cs, cs) * 0.4), Color("e8b45c"))
	for it in grid.level.get("items", []):
		if str(it.get("type", "")) != "fountain":
			continue
		var fk := _k(int(it.x), int(it.y))
		if not (seen.has(fk) or visited.has(fk)) or int(it.x) < ox or int(it.x) >= ox + vw or int(it.y) < oy or int(it.y) >= oy + vh:
			continue
		var fc := origin + (Vector2(int(it.x) - ox, int(it.y) - oy) + Vector2(0.5, 0.5)) * cs
		draw_circle(fc, maxf(cs * 0.32, 2.5), Color("6fd0e8"))
	if merchant_cell.is_valid():
		var mc: Vector2i = merchant_cell.call()
		if mc.x >= ox and mc.x < ox + vw and mc.y >= oy and mc.y < oy + vh:
			var mp := origin + (Vector2(mc.x - ox, mc.y - oy) + Vector2(0.5, 0.5)) * cs
			draw_circle(mp, maxf(cs * 0.36, 2.5), Color("e8b45c"))
			draw_arc(mp, maxf(cs * 0.36, 2.5), 0, TAU, 16, Color("8a4fc8"), 1.4)
	var mons: Dictionary = ls.get("monsters", {})
	for m in grid.level.get("monsters", []):
		var st: Dictionary = mons.get(str(m.id), {})
		if st.is_empty() or not st.alive or st.hidden:
			continue
		var x := int(st.x)
		var y := int(st.y)
		var mk := _k(x, y)
		if not (seen.has(mk) or visited.has(mk)) or x < ox or x >= ox + vw or y < oy or y >= oy + vh:
			continue
		var boss := bool(m.get("isBoss", false))
		var mp2 := origin + (Vector2(x - ox, y - oy) + Vector2(0.5, 0.5)) * cs
		var rr := maxf(cs * 0.28, 4.5 if boss else 3.0)
		draw_circle(mp2, rr, Color("ffd88a") if boss else Color("c23b3b"))
		if boss:
			draw_arc(mp2, rr, 0, TAU, 16, Color("c23b3b"), 1.2)
	var pc := origin + (Vector2(rig.gx - ox, rig.gy - oy) + Vector2(0.5, 0.5)) * cs
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	var f := Vector2(v.x, v.y)
	var side := Vector2(-f.y, f.x)
	var r2 := cs * 0.45
	draw_colored_polygon(PackedVector2Array([pc + f * r2, pc - f * r2 * 0.7 + side * r2 * 0.7, pc - f * r2 * 0.7 - side * r2 * 0.7]), UiTheme.GOLD)

## Proportions du canevas de l'original (cases visibles en largeur / hauteur) : le cadre s'y adapte.
func view_aspect() -> float:
	if grid == null:
		return 1.11
	var z := clampi(zoom, 1, _max_zoom())
	var base_px := clampi(int(floor(320.0 / maxi(grid.width, grid.height))), 3, 16)
	var cpx := mini(28, base_px * z)
	var fog := gs != null and (gs.cfg.get("runModifierIds", []) as Array).has("mod_fog")
	var budget := 130 if fog else 300
	var vw := maxi(4, mini(grid.width, int(floor(budget / float(cpx)))))
	var vh := maxi(4, mini(grid.height, int(floor(budget / float(cpx)))))
	if full:
		return float(grid.width) / float(grid.height)
	return float(vw) / float(vh)
