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

const CELL := 38.0
const GAP := 2.0
const PAD := 6.0
const BORDER := 1.0
const BADGE := 13.0
const C_FLOOR := Color("5c4b34")
const C_WALL := Color("1c1610")
const C_STAIRS := Color("e8b45c")
const C_DOOR := Color("6b4423")
const C_BORDER := Color("5a4526")

var lvl: Dictionary = {}
## Marqueur du groupe en jeu ({} ou {level_id, x, y}), fourni par `Data.admin_party_marker()`.
var party_marker: Dictionary = {}
var _hover := Vector2i(-1, -1)
## Pastille retirable survolée : "" / "mon" / "item".
var _hover_badge := ""
var _mons: Dictionary = {}
var _items: Dictionary = {}
var _party := Vector2i(-1, -1)
var _t := 0.0
var _boxes: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for k in ["floor", "wall", "stairs", "door"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"floor": C_FLOOR, "wall": C_WALL, "stairs": C_STAIRS, "door": C_DOOR}[k]
		b.set_corner_radius_all(4)
		_boxes[k] = b

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
	custom_minimum_size = Vector2(w * CELL + maxf(0.0, w - 1.0) * GAP + 2.0 * (PAD + BORDER), h * CELL + maxf(0.0, h - 1.0) * GAP + 2.0 * (PAD + BORDER))
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
	return Vector2(PAD + BORDER + c.x * (CELL + GAP), PAD + BORDER + c.y * (CELL + GAP))

func _cell_at(p: Vector2) -> Vector2i:
	var rows := _rows()
	if rows.is_empty():
		return Vector2i(-1, -1)
	var q := p - Vector2(PAD + BORDER, PAD + BORDER)
	if q.x < 0.0 or q.y < 0.0:
		return Vector2i(-1, -1)
	var cx := int(floor(q.x / (CELL + GAP)))
	var cy := int(floor(q.y / (CELL + GAP)))
	if cx >= _w() or cy >= rows.size():
		return Vector2i(-1, -1)
	if fposmod(q.x, CELL + GAP) > CELL or fposmod(q.y, CELL + GAP) > CELL:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

static func _off(r: Rect2, o: Vector2) -> Rect2:
	return Rect2(r.position + o, r.size)

# Rectangles de pastille, relatifs à la case.
func _mon_rect() -> Rect2:
	return Rect2(CELL - 1.0 - BADGE, 0.0, BADGE, BADGE)

func _item_rect() -> Rect2:
	return Rect2(1.0, CELL - BADGE, BADGE, BADGE)

func _start_rect() -> Rect2:
	return Rect2(1.0, 0.0, BADGE, BADGE)

func _party_rect() -> Rect2:
	return Rect2(CELL - 1.0 - BADGE, CELL - BADGE, BADGE, BADGE)

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
	set_meta("tip_rect", Rect2(get_global_rect().position + _origin(_hover), Vector2(CELL, CELL)))

# ------------------------------------------------------------------ dessin

func _glyph(font: Font, text: String, rect: Rect2, fs: int, col: Color = Color.WHITE) -> void:
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	var p := Vector2(rect.position.x + (rect.size.x - sz.x) * 0.5, rect.position.y + rect.size.y * 0.5 + (asc - desc) * 0.5)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Icône d'entité (image du jeu ou emoji) dans `rect` (pastille de 13 px).
func _icon(icon: String, rect: Rect2, font: Font, col: Color = Color.WHITE) -> void:
	if icon.begins_with("@icon:"):
		var t: Texture2D = IconResolver.texture(icon)
		if t != null:
			draw_texture_rect(t, rect, false, col)
		else:
			_glyph(font, "❓", rect, int(rect.size.y), col)
	elif icon != "":
		_glyph(font, icon, rect, int(rect.size.y), col)

## Pastille avec ombre portée (0 1px 1px #000) ; `hot` = survolée et retirable.
func _badge(icon: String, rect: Rect2, font: Font, hot: bool) -> void:
	if hot:
		var c := rect.get_center()
		for r in [11.0, 9.0, 7.5]:
			draw_circle(c, r, Color(1.0, 0.23, 0.23, 0.13))
		var big := Rect2(c - rect.size * 0.5 * 1.35, rect.size * 1.35)
		_icon(icon, _off(big, Vector2(0, 1)), font, Color(0, 0, 0, 0.7))
		_icon(icon, big, font, Color(1.4, 1.4, 1.4, 1.0))
	else:
		_icon(icon, _off(rect, Vector2(0, 1)), font, Color(0, 0, 0, 0.6))
		_icon(icon, rect, font)

func _draw() -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var font := UiTheme.font(UiTheme.F_BODY)
	var w := _w()
	var sz := size
	# fond noir, liseré, coins arrondis (6 px)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.BLACK
	bg.border_color = C_BORDER
	bg.set_border_width_all(int(BORDER))
	bg.set_corner_radius_all(6)
	draw_style_box(bg, Rect2(Vector2.ZERO, Vector2(maxf(sz.x, custom_minimum_size.x), maxf(sz.y, custom_minimum_size.y))))
	var sx := int(lvl.get("startX", -999))
	var sy := int(lvl.get("startY", -999))
	for y in rows.size():
		var row := str(rows[y])
		for x in w:
			var ch := row[x] if x < row.length() else "#"
			var c := Vector2i(x, y)
			var o := _origin(c)
			var r := Rect2(o, Vector2(CELL, CELL))
			if _hover == c:
				# button:hover { box-shadow: 0 2px 10px rgba(232,180,92,.25) }
				for i in 5:
					var e := 1.5 + i * 2.0
					draw_rect(Rect2(o + Vector2(-e, -e + 2.0), Vector2(CELL + 2.0 * e, CELL + 2.0 * e)), Color(0.91, 0.71, 0.36, 0.045))
			var key := "floor"
			match ch:
				"#": key = "wall"
				"S": key = "stairs"
				"D": key = "door"
			draw_style_box(_boxes[key], r)
			if ch == "S":
				_glyph(font, "✨", r, 17)
			elif ch == "D":
				_glyph(font, "🚪", r, 17)
			if _mons.has(c):
				var m: Dictionary = (_mons[c] as Array)[0]
				_badge(str(m.get("icon", "")), _off(_mon_rect(), o), font, _hover == c and _hover_badge == "mon")
			if _items.has(c):
				var it: Dictionary = (_items[c] as Array)[0]
				_badge(str(it.get("icon", "")), _off(_item_rect(), o), font, _hover == c and _hover_badge == "item")
			if x == sx and y == sy:
				_badge("🚩", _off(_start_rect(), o), font, false)
			if _party == c:
				var pr := _off(_party_rect(), o)
				var pulse := 1.0 + 0.25 * (1.0 - cos(_t / 1.2 * TAU)) * 0.5
				var ctr := pr.get_center()
				for rr in [10.0, 8.0, 6.5]:
					draw_circle(ctr, rr * pulse, Color(0.47, 0.86, 1.0, 0.16))
				var prs := Rect2(ctr - pr.size * 0.5 * pulse, pr.size * pulse)
				_icon("🧑‍🤝‍🧑", _off(prs, Vector2(0, 1)), font, Color(0, 0, 0, 0.6))
				_icon("🧑‍🤝‍🧑", prs, font)
