class_name Atelier
extends RefCounted
## Éléments communs de l'atelier de création : en-tête de page, mémoire de la dernière section et des modifications récentes
## (fichier local `user://atelier.json`, hors configuration du donjon), et contrôles de cohérence du donjon.

const FILE := "user://atelier.json"
const MAX_RECENT := 6
const GOLD := Color("ffd88a")
const MUTED := Color("a8977a")
const CREAM := Color("f4e6c6")

static var _mem: Dictionary = {}
static var _loaded := false

# ------------------------------------------------------------------ mémoire locale

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_mem = d

static func _store() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_mem))

## Dernière section ouverte (pour « Reprendre là où tu t'es arrêté »).
static func last_section() -> String:
	_load()
	return str(_mem.get("last", ""))

static func visited(id: String) -> void:
	if id == "home":
		return
	_load()
	_mem["last"] = id
	_store()

## Une section vient d'être enregistrée : elle remonte en tête des modifications récentes.
static func touch(id: String) -> void:
	if id == "home":
		return
	_load()
	var list: Array = _mem.get("recent", [])
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].get("section", "")) == id:
			list.remove_at(i)
	list.push_front({"section": id, "ts": Time.get_unix_time_from_system()})
	while list.size() > MAX_RECENT:
		list.pop_back()
	_mem["recent"] = list
	_store()

static func recent() -> Array:
	_load()
	return _mem.get("recent", [])

## « il y a 2 min », « hier »…
static func ago(ts: float) -> String:
	var d := maxf(0.0, Time.get_unix_time_from_system() - ts)
	if d < 60.0:
		return L.t("ui.atelier.ago_now")
	if d < 3600.0:
		return L.fa(L.t("ui.atelier.ago_min"), int(d / 60.0))
	if d < 86400.0:
		return L.fa(L.t("ui.atelier.ago_h"), int(d / 3600.0))
	if d < 172800.0:
		return L.t("ui.atelier.ago_yesterday")
	return L.fa(L.t("ui.atelier.ago_d"), int(d / 86400.0))

# ------------------------------------------------------------------ en-tête de page

## Nom de la rubrique (« CRÉER », « RÈGLES DU JEU », « PROJET ») qui contient la section.
static func kicker_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return L.t(str(g[0])) if str(g[0]) != "" else ""
	return ""

static func title_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return L.t(str(it[1]))
	return ""

## Titre de page : petit libellé de rubrique en capitales puis grand titre. Renvoie la rangée (pour y ajouter un contrôle à droite).
static func page_header(host: Control, id: String, title: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	host.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var k := Label.new()
	k.text = kicker_of(id)
	k.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE, 2))
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color("9a8863"))
	col.add_child(k)
	var t := Label.new()
	t.text = title if title != "" else title_of(id)
	t.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	return row

# ------------------------------------------------------------------ composants communs

static func box(bg: Color, line: Color, radius: int = 10, px: int = 12, py: int = 8, border: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	return sb

## Pastille-bouton (filtres, sorts, paliers) : `on` = fond et liseré teintés de `tint`.
static func pill(text: String, on: bool, cb: Callable, tint: Color = Color("e8b45c"), height: float = 34.0, size: int = 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", size)
	var bg := Color(tint.r, tint.g, tint.b, 0.14) if on else Color(0.12, 0.09, 0.05, 0.7)
	var line := tint if on else Color("3a2c18")
	for k in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, box(bg, line, int(height / 2.0), 14, 4))
	b.add_theme_stylebox_override("hover", box(Color(tint.r, tint.g, tint.b, 0.2) if on else Color(0.2, 0.15, 0.08, 0.8), line if on else Color("6b5430"), int(height / 2.0), 14, 4))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color("ffd88a") if on else Color("b8a781"))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Bouton plein (principal : doré) ou discret ; `danger` : rouge.
static func button(text: String, cb: Callable, primary: bool = false, danger: bool = false, height: float = 40.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 13)
	var bg := Color(0.16, 0.12, 0.07, 0.7)
	var line := Color("4a3920")
	var fg := Color("e2d2b0")
	if primary:
		bg = Color(0.91, 0.71, 0.36, 0.14)
		line = Color("e8b45c")
		fg = Color("ffd88a")
	elif danger:
		bg = Color(0.31, 0.09, 0.07, 0.35)
		line = Color("6b2a22")
		fg = Color("ff8a78")
	for k in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, box(bg, line, 10, 16, 6))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), line.lightened(0.15), 10, 16, 6))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Carte cliquable (bordure dorée si sélectionnée) : renvoie le conteneur, à remplir par l'appelant, puis `clickable()`.
static func card(selected: bool, pad: int = 14, radius: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0.91, 0.71, 0.36, 0.1) if selected else Color(0.1, 0.075, 0.043, 0.85),
		Color("e8b45c") if selected else Color("3a2c18"), radius, pad, pad))
	return p

static func ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_mouse(ch)

## Rend `c` cliquable : ses enfants laissent passer la souris.
static func clickable(c: Control, cb: Callable) -> void:
	ignore_mouse(c)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			cb.call())

## Onglets soulignés (page ou panneau) : `items` = [[id, libellé], …] ; l'onglet actif est souligné d'or.
static func tabs(items: Array, current: String, cb: Callable, size: int = 14) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for it in items:
		var id: String = it[0]
		var on := id == current
		var b := Button.new()
		b.text = str(it[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", size)
		for k in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.04) if k == "hover" and not on else Color(0, 0, 0, 0)
			sb.border_color = Color("e8b45c") if on else Color(0, 0, 0, 0)
			sb.border_width_bottom = 2
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			b.add_theme_stylebox_override(k, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color("ffd88a") if on else Color("b8a781"))
		b.pressed.connect(func(): cb.call(id))
		h.add_child(b)
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.add_child(h)
	var line := ColorRect.new()
	line.color = Color("3a2c18")
	line.custom_minimum_size = Vector2(0, 1)
	wrap.add_child(line)
	return wrap

static func muted(text: String, size: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MUTED)
	return l

## Intertitre de section en capitales dorées (Cinzel).
static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 2))
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("e8b45c"))
	return l

## Barre fine dorée (caractéristiques) : valeur sur `max_v`.
static func bar(value: float, max_v: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = max_v
	b.value = minf(value, max_v)
	b.custom_minimum_size = Vector2(60, 8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2a2014")
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e8b45c")
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b

# ------------------------------------------------------------------ contrôles du donjon

## Contrôles de cohérence du donjon en cours d'édition : [{"state": "ok"|"warn"|"bad", "title", "text"}, …].
static func checks() -> Array:
	var cfg: Dictionary = Data.admin_config()
	var out: Array = []
	var levels: Array = cfg.get("levels", [])
	var no_start: Array = []
	var no_exit: Array = []
	var no_rooms: Array = []
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var rows: Array = lv.get("mapRows", [])
		var sx := int(lv.get("startX", -1))
		var sy := int(lv.get("startY", -1))
		var ok_start := sy >= 0 and sy < rows.size() and sx >= 0 and sx < str(rows[sy]).length() and str(rows[sy])[sx] != "#"
		if not ok_start:
			no_start.append(i + 1)
		if (lv.get("stairs", []) as Array).is_empty() and not _has_stairs_cell(rows):
			no_exit.append(i + 1)
	for n in no_exit:
		out.append({"state": "bad", "title": L.fa(L.t("ui.atelier.chk_no_exit"), n), "text": L.t("ui.atelier.chk_no_exit_d")})
	for n in no_start:
		out.append({"state": "bad", "title": L.fa(L.t("ui.atelier.chk_no_start"), n), "text": L.t("ui.atelier.chk_no_start_d")})
	for n in no_rooms:
		out.append({"state": "warn", "title": L.fa(L.t("ui.atelier.chk_no_room"), n), "text": L.t("ui.atelier.chk_no_room_d")})
	var party: Array = cfg.get("party", [])
	if party.is_empty():
		out.append({"state": "bad", "title": L.t("ui.atelier.chk_no_party"), "text": L.t("ui.atelier.chk_no_party_d")})
	else:
		out.append({"state": "ok", "title": L.t("ui.atelier.chk_party_ok"), "text": L.fa(L.t("ui.atelier.chk_party_ok_d"), party.size())})
	if no_start.is_empty() and not levels.is_empty():
		out.append({"state": "ok", "title": L.t("ui.atelier.chk_start_ok"), "text": L.fa(L.t("ui.atelier.chk_start_ok_d"), [levels.size(), levels.size()])})
	if levels.is_empty():
		out.append({"state": "bad", "title": L.t("ui.atelier.chk_no_level"), "text": L.t("ui.atelier.chk_no_level_d")})
	return out

static func _has_stairs_cell(rows: Array) -> bool:
	for r in rows:
		if "S" in str(r):
			return true
	return false
