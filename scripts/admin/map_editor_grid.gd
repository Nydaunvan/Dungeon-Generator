class_name MapEditorGrid
extends Control
## Grille de la carte d'un niveau (éditeur) : dessin des murs, sols, portes, escaliers, monstres, objets, départ.
## Émet `cell_pressed` au clic (avec l'éventuelle pastille cliquée) et `cell_dragged` en glissant bouton enfoncé.

signal cell_pressed(x: int, y: int, badge: String)
signal cell_dragged(x: int, y: int)

const CS := 34.0

var lvl: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _last_drag := Vector2i(-1, -1)
var _dragging := false
var _mon_by_cell: Dictionary = {}
var _item_by_cell: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_level(l: Dictionary) -> void:
	lvl = l
	refresh()

func refresh() -> void:
	_mon_by_cell.clear()
	_item_by_cell.clear()
	for m in lvl.get("monsters", []):
		_mon_by_cell[Vector2i(int(m.x), int(m.y))] = m
	for it in lvl.get("items", []):
		if str(it.get("type", "")) == "decor":
			continue
		_item_by_cell[Vector2i(int(it.x), int(it.y))] = it
	var rows: Array = lvl.get("mapRows", [])
	var w := (str(rows[0]).length() if rows.size() > 0 else 1)
	custom_minimum_size = Vector2(w * CS, rows.size() * CS)
	queue_redraw()

func _cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(floor(p.x / CS)), int(floor(p.y / CS)))
	var rows: Array = lvl.get("mapRows", [])
	if rows.is_empty() or c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= str(rows[0]).length():
		return Vector2i(-1, -1)
	return c

func _badge_at(c: Vector2i, p: Vector2) -> String:
	var local := p - Vector2(c) * CS
	if _mon_by_cell.has(c) and Rect2(1, 1, 16, 16).has_point(local):
		return "mon:" + str(_mon_by_cell[c].id)
	if _item_by_cell.has(c) and Rect2(CS - 17, CS - 17, 16, 16).has_point(local):
		return "item:" + str(_item_by_cell[c].id)
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var c := _cell_at(mb.position)
				if c.x >= 0:
					_dragging = true
					_last_drag = c
					cell_pressed.emit(c.x, c.y, _badge_at(c, mb.position))
			else:
				_dragging = false
				_last_drag = Vector2i(-1, -1)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var c := _cell_at(mm.position)
		if c != _hover:
			_hover = c
			queue_redraw()
		if _dragging and c.x >= 0 and c != _last_drag:
			_last_drag = c
			cell_dragged.emit(c.x, c.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2i(-1, -1)
		_dragging = false
		queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	var c := _cell_at(at_position)
	if c.x < 0:
		return ""
	var lines: Array = []
	if int(lvl.get("startX", -1)) == c.x and int(lvl.get("startY", -1)) == c.y:
		lines.append("Point de départ")
	var ch := str(lvl.mapRows[c.y])[c.x]
	if ch == "D":
		var locked := true
		for d in lvl.get("doors", []):
			if int(d.x) == c.x and int(d.y) == c.y:
				locked = bool(d.get("locked", true))
		lines.append("Porte (%s par défaut)" % ("verrouillée" if locked else "déverrouillée"))
	if ch == "S":
		for s in lvl.get("stairs", []):
			if int(s.x) == c.x and int(s.y) == c.y:
				var a: Dictionary = s.get("action", {})
				if a.get("type") == "victory":
					lines.append("Escalier → fin de partie (victoire)")
				else:
					var name := "niveau inconnu"
					for l in Data.config.get("levels", []):
						if l.id == a.get("targetId"):
							name = str(l.name)
					lines.append("Escalier → " + name)
	if _mon_by_cell.has(c):
		var m: Dictionary = _mon_by_cell[c]
		lines.append("Monstre : %s%s" % [m.get("name", "?"), " (caché)" if m.get("startHidden", false) else ""])
	if _item_by_cell.has(c):
		var it: Dictionary = _item_by_cell[c]
		lines.append("Objet : %s%s" % [it.get("name", "?"), " (caché)" if it.get("startHidden", false) else ""])
	return "\n".join(lines)

func _icon(icon: String, rect: Rect2, font: Font) -> void:
	if icon.begins_with("@icon:"):
		var t: Texture2D = IconResolver.texture(icon)
		if t != null:
			draw_texture_rect(t, rect, false)
			return
	elif icon != "":
		var fs := int(rect.size.y * 0.8)
		draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.82), icon, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x + 4.0, fs)
		return
	draw_rect(rect, Color("c9a35a"))

func _draw() -> void:
	var rows: Array = lvl.get("mapRows", [])
	if rows.is_empty():
		return
	var font := UiTheme.font(UiTheme.F_BODY)
	var sx := int(lvl.get("startX", -1))
	var sy := int(lvl.get("startY", -1))
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var r := Rect2(x * CS, y * CS, CS - 1.0, CS - 1.0)
			var ch := row[x]
			var col := Color("6d5a3c")
			match ch:
				"#": col = Color("1c1611")
				"D": col = Color("8a5a2a")
				"S": col = Color("3f5f8f")
			draw_rect(r, col)
			if ch == "#":
				draw_rect(r, Color("2d241a"), false, 1.0)
			if ch == "D":
				draw_rect(Rect2(r.position + Vector2(9, 5), Vector2(CS - 20, CS - 11)), Color("d8ac5c"), false, 2.0)
			elif ch == "S":
				draw_string(font, r.position + Vector2(7, 24), "✨", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			var cell := Vector2i(x, y)
			if _mon_by_cell.has(cell):
				var m: Dictionary = _mon_by_cell[cell]
				draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(16, 16)), Color(0.35, 0.05, 0.05, 0.85))
				_icon(str(m.get("icon", "")), Rect2(r.position + Vector2(1, 1), Vector2(16, 16)), font)
			if _item_by_cell.has(cell):
				var it: Dictionary = _item_by_cell[cell]
				draw_rect(Rect2(r.position + Vector2(CS - 18, CS - 18), Vector2(16, 16)), Color(0.05, 0.2, 0.3, 0.85))
				_icon(str(it.get("icon", "")), Rect2(r.position + Vector2(CS - 18, CS - 18), Vector2(16, 16)), font)
			if x == sx and y == sy:
				draw_string(font, r.position + Vector2(CS - 17, 14), "🚩", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	if _hover.x >= 0:
		draw_rect(Rect2(_hover.x * CS, _hover.y * CS, CS - 1.0, CS - 1.0), Color(1, 0.85, 0.4, 0.9), false, 2.0)
