class_name MapEditorGrid
extends Control
## Grille de la carte d'un niveau (éditeur), fidèle à `.map-grid` / `.map-cell` de l'original :
## cases de 38 px, écart 2 px, marge 6 px, fond noir à liseré #5a4526 ; sol / mur / porte / escalier ; pastilles de 13 px
## (monstre en haut à droite, objet en bas à gauche, départ en haut à gauche, groupe en bas à droite) ; survol d'une pastille
## retirable : lueur rouge + luminosité + zoom ; info-bulle de case (FloatingTip : `tooltip_text` + méta `tip_rect`).
## Pas de glisser-déposer : l'original ne peint qu'au clic.

## Clic sur une case (hors pastille retirable).
signal cell_pressed(x: int, y: int)
## Clic sur une pastille retirable : `kind` = "mon" ou "item", `id` = identifiant de l'entité de tête de la case.
signal badge_pressed(x: int, y: int, kind: String, id: String)

const GAP := 2.0
const PAD := 10.0
const BORDER := 1.0
const C_FLOOR := Color("5c4b34")
const C_WALL := Color("1c1610")
const C_STAIRS := Color("e8b45c")
const C_BORDER := Color("5a4526")
const C_BACK := Color("0c0905")
const C_MON := Color("e0584a")
const C_ITEM := Color("ffd88a")
const C_START := Color("6fcf7f")
const C_PARTY := Color("6aa8ff")
const C_DOOR_FILL := Color("3d2814")
const C_DOOR_LINE := Color("b07a3c")

## Taille d'une case en pixels (40 dans la maquette ; réduite pour tenir dans la zone disponible).
var cell := 40.0
var lvl: Dictionary = {}
## Marqueur du groupe en jeu ({} ou {level_id, x, y}), fourni par `Data.admin_party_marker()`.
var party_marker: Dictionary = {}
## Case sélectionnée (anneau doré), (-1, -1) = aucune.
var selected := Vector2i(-1, -1)
var _hover := Vector2i(-1, -1)
## Pastille retirable survolée : "" / "mon" / "item".
var _hover_badge := ""
var _mons: Dictionary = {}
var _items: Dictionary = {}
var _party := Vector2i(-1, -1)
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_level(l: Dictionary) -> void:
	lvl = l
	refresh()

func _rows() -> Array:
	return lvl.get("mapRows", [])

func _w() -> int:
	var rows := _rows()
	return str(rows[0]).length() if rows.size() > 0 else 0

## Relit le niveau (entités, groupe, taille) et redessine.
func refresh() -> void:
	_mons = _index(lvl.get("monsters", []))
	_items = _index(lvl.get("items", []))
	_party = Vector2i(-1, -1)
	if not party_marker.is_empty() and str(party_marker.get("level_id", "")) == str(lvl.get("id", "#")):
		_party = Vector2i(int(party_marker.get("x", -1)), int(party_marker.get("y", -1)))
	set_process(_party.x >= 0)
	var w := _w()
	var h := _rows().size()
	custom_minimum_size = Vector2(w * cell + maxf(0.0, w - 1.0) * GAP + 2.0 * (PAD + BORDER), h * cell + maxf(0.0, h - 1.0) * GAP + 2.0 * (PAD + BORDER))
	queue_redraw()

func _index(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for e in list:
		var k := Vector2i(int(e.x), int(e.y))
		if not out.has(k):
			out[k] = []
		(out[k] as Array).append(e)
	return out

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _origin(c: Vector2i) -> Vector2:
	return Vector2(PAD + BORDER + c.x * (cell + GAP), PAD + BORDER + c.y * (cell + GAP))

func _cell_at(p: Vector2) -> Vector2i:
	var rows := _rows()
	if rows.is_empty():
		return Vector2i(-1, -1)
	var q := p - Vector2(PAD + BORDER, PAD + BORDER)
	if q.x < 0.0 or q.y < 0.0:
		return Vector2i(-1, -1)
	var cx := int(floor(q.x / (cell + GAP)))
	var cy := int(floor(q.y / (cell + GAP)))
	if cx >= _w() or cy >= rows.size():
		return Vector2i(-1, -1)
	if fposmod(q.x, cell + GAP) > cell or fposmod(q.y, cell + GAP) > cell:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

static func _off(r: Rect2, o: Vector2) -> Rect2:
	return Rect2(r.position + o, r.size)

# Rectangles de pastille (14 px pour une case de 40), relatifs à la case.
func _badge_px() -> float:
	return roundf(cell * 0.35)

func _inset() -> float:
	return roundf(cell * 0.075)

func _mon_rect() -> Rect2:
	return Rect2(cell - _inset() - _badge_px(), _inset(), _badge_px(), _badge_px())

func _item_rect() -> Rect2:
	return Rect2(_inset(), cell - _inset() - _badge_px(), _badge_px(), _badge_px())

func _start_rect() -> Rect2:
	return Rect2(_inset(), _inset(), _badge_px(), _badge_px())

func _party_rect() -> Rect2:
	return Rect2(cell - _inset() - _badge_px(), cell - _inset() - _badge_px(), _badge_px(), _badge_px())

## "mon" / "item" / "" selon la pastille retirable sous le curseur.
func _badge_at(c: Vector2i, p: Vector2) -> String:
	var local := p - _origin(c)
	if _mons.has(c) and _mon_rect().has_point(local):
		return "mon"
	if _items.has(c) and _item_rect().has_point(local):
		return "item"
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var c := _cell_at(mb.position)
			if c.x < 0:
				return
			var b := _badge_at(c, mb.position)
			if b == "mon":
				badge_pressed.emit(c.x, c.y, "mon", str((_mons[c] as Array)[0].id))
			elif b == "item":
				badge_pressed.emit(c.x, c.y, "item", str((_items[c] as Array)[0].id))
			else:
				cell_pressed.emit(c.x, c.y)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var c := _cell_at(mm.position)
		var hb := _badge_at(c, mm.position) if c.x >= 0 else ""
		if c != _hover or hb != _hover_badge:
			_hover = c
			_hover_badge = hb
			_update_tip()
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2i(-1, -1)
		_hover_badge = ""
		_update_tip()
		queue_redraw()

# ------------------------------------------------------------------ info-bulle

func _tip_lines(c: Vector2i) -> Array:
	var lines: Array = []
	var rows := _rows()
	if int(lvl.get("startX", -999)) == c.x and int(lvl.get("startY", -999)) == c.y:
		lines.append(L.t("admin.map_editor_grid.point_de_depart"))
	if _party == c:
		lines.append(L.t("admin.map_editor_grid.groupe_actuellement_ici"))
	var ch := str(rows[c.y])[c.x]
	if ch == "D":
		var def_locked := false
		var found := false
		for d in lvl.get("doors", []):
			if int(d.x) == c.x and int(d.y) == c.y:
				found = true
				def_locked = d.get("locked", true) != false
				break
		lines.append(L.t("admin.map_editor_grid.porte_verrouillee_par_defaut") if (found and def_locked) else L.t("admin.map_editor_grid.porte_deverrouillee_par_defaut"))
	if ch == "S":
		for s in lvl.get("stairs", []):
			if int(s.x) == c.x and int(s.y) == c.y:
				var a: Dictionary = s.get("action", {})
				if a.get("type") == "victory":
					lines.append(L.t("admin.map_editor_grid.escalier_fin_de_partie_victoire"))
				else:
					var nm := L.t("admin.map_editor_grid.niveau_inconnu")
					for l in Data.admin_config().get("levels", []):
						if l.id == a.get("targetId"):
							nm = str(l.name)
					lines.append(L.fa(L.t("admin.map_editor_grid.escalier"), nm))
				break
	for m in _mons.get(c, []):
		lines.append(L.fa(L.t("admin.map_editor_grid.monstre"), str(m.get("name", ""))) + (L.t("admin.map_editor_grid.cache") if m.get("startHidden", false) else ""))
	for it in _items.get(c, []):
		var pre := L.t("admin.map_editor_grid.objet") if str(it.get("type", "")) == "switch" else L.t("admin.map_editor_grid.objet_2")
		lines.append(pre % str(it.get("name", "")) + (L.t("admin.map_editor_grid.cache") if it.get("startHidden", false) else ""))
	return lines

func _update_tip() -> void:
	tooltip_text = ""
	remove_meta("tip_rect")
	if _hover.x < 0:
		return
	var lines := _tip_lines(_hover)
	if lines.is_empty():
		return
	tooltip_text = "\n".join(lines)
	set_meta("tip_rect", Rect2(get_global_rect().position + _origin(_hover), Vector2(cell, cell)))

# ------------------------------------------------------------------ dessin

## Pastille de la maquette : 14 px, liseré de 2 px couleur du fond de la carte ; `hot` = retirable et survolée (lueur rouge, zoom).
func _marker(kind: String, rect: Rect2, col: Color, hot: bool) -> void:
	var r := rect
	if hot:
		var c := rect.get_center()
		for k in [rect.size.x * 0.85, rect.size.x * 0.7, rect.size.x * 0.58]:
			draw_circle(c, k, Color(1.0, 0.23, 0.23, 0.13))
		r = Rect2(c - rect.size * 0.675, rect.size * 1.35)
		col = col.lightened(0.25)
	var st := StyleBoxFlat.new()
	st.bg_color = col
	st.border_color = C_BACK
	st.set_border_width_all(2)
	st.set_corner_radius_all(int(r.size.x * 0.5) if kind != "item" else 4)
	draw_style_box(st, r)

func _draw() -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var w := _w()
	var sz := size
	# plateau : fond #0c0905, liseré #5a4526, coins arrondis (14 px)
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BACK
	bg.border_color = C_BORDER
	bg.set_border_width_all(int(BORDER))
	bg.set_corner_radius_all(14)
	bg.shadow_color = Color(0, 0, 0, 0.45)
	bg.shadow_size = 18
	draw_style_box(bg, Rect2(Vector2.ZERO, Vector2(maxf(sz.x, custom_minimum_size.x), maxf(sz.y, custom_minimum_size.y))))
	var sx := int(lvl.get("startX", -999))
	var sy := int(lvl.get("startY", -999))
	var radius := int(roundf(cell * 0.15))
	for y in rows.size():
		var row := str(rows[y])
		for x in w:
			var ch := row[x] if x < row.length() else "#"
			var c := Vector2i(x, y)
			var o := _origin(c)
			var r := Rect2(o, Vector2(cell, cell))
			var col := C_FLOOR
			if ch == "#":
				col = C_WALL
			elif ch == "S":
				col = C_STAIRS
			var st := StyleBoxFlat.new()
			st.bg_color = col.lightened(0.12) if _hover == c and ch != "#" else (col.lightened(0.5) if _hover == c else col)
			st.set_corner_radius_all(radius)
			if selected == c:
				st.border_color = Ax.GOLD
				st.set_border_width_all(2)
				st.shadow_color = Color(0.91, 0.706, 0.361, 0.5)
				st.shadow_size = 7
			draw_style_box(st, r)
			if ch == "D":
				var door := StyleBoxFlat.new()
				door.bg_color = C_DOOR_FILL
				door.border_color = C_DOOR_LINE
				door.border_width_left = 2
				door.border_width_right = 2
				door.border_width_top = 2
				var rr := int(cell * 0.25)
				door.corner_radius_top_left = rr
				door.corner_radius_top_right = rr
				draw_style_box(door, Rect2(o + Vector2(cell * 0.2, cell * 0.15), Vector2(cell * 0.6, cell * 0.85)))
			elif ch == "S":
				var k := cell / 24.0
				var pts := PackedVector2Array([Vector2(5, 18), Vector2(9, 18), Vector2(9, 14), Vector2(13, 14), Vector2(13, 10), Vector2(17, 10), Vector2(17, 6), Vector2(19, 6)])
				for i in pts.size():
					pts[i] = o + pts[i] * k
				draw_polyline(pts, Color("2a1a06"), 2.0 * maxf(k, 0.6), true)
			if _mons.has(c):
				_marker("mon", _off(_mon_rect(), o), C_MON, _hover == c and _hover_badge == "mon")
			if _items.has(c):
				_marker("item", _off(_item_rect(), o), C_ITEM, _hover == c and _hover_badge == "item")
			if x == sx and y == sy:
				_marker("start", _off(_start_rect(), o), C_START, false)
			if _party == c:
				var pr := _off(_party_rect(), o)
				var pulse := 1.0 + 0.25 * (1.0 - cos(_t / 1.2 * TAU)) * 0.5
				var ctr := pr.get_center()
				for rr2 in [pr.size.x * 0.8, pr.size.x * 0.65, pr.size.x * 0.55]:
					draw_circle(ctr, rr2 * pulse, Color(C_PARTY.r, C_PARTY.g, C_PARTY.b, 0.16))
				_marker("party", pr, C_PARTY, false)
