class_name AdminLevels
extends RefCounted
## Onglet « Niveaux » (`#adminLevels` de l'original) : liste des niveaux (230 px | 1fr), éditeur à onglets Carte / Monstres /
## Objets / Réglages, placement en temps réel (bannière « 🎯 Cliquez sur la carte pour placer »), escaliers, marchand ambulant.
## Mêmes textes, bornes et comportements que le JS 14048-14715 de la référence.

const THEMES := [["stone", "admin.levels.pierre_classique"], ["dirt", "admin.levels.pyramide"], ["damp", "admin.levels.cachot_humide"], ["ruins", "admin.levels.ruines_effondrees"], ["ice", "admin.levels.glace"], ["lava", "admin.levels.lave"], ["temple", "admin.levels.temple_ancien"]]
const DIRS := [[0, "admin.levels.nord"], [1, "admin.levels.est"], [2, "admin.levels.sud"], [3, "admin.levels.ouest"]]
const MAX_LEVELS := 8
const ITEM_TYPES := [["potion", "common.potion"], ["weapon", "common.arme"], ["armor", "common.armure"], ["jewelry", "common.bijou"], ["key", "common.cle"], ["scroll", "common.parchemin"], ["trap", "common.piege"], ["switch", "admin.levels.interrupt"], ["fountain", "common.fontaine"]]
const PERKS := [["lifesteal", "common.vol_de_vie"], ["crit", "common.critique"], ["thorns", "common.renvoi"]]
const BORDER := Color("5a4526")
const GOLD_DIM := Color("a9793a")
const GOLD_BRIGHT := Color("ffd88a")
const PARCH_DIM := Color("b8a781")

static var _sel := ""
static var _tab := "map"
static var _brush := "."
static var _allow_rooms := false
## Cible de placement en cours : {kind: monster|item|merchant|start|teleport, id: String} ou vide.
static var _placement: Dictionary = {}
static var _admin: Node = null
static var _list_box: VBoxContainer = null
static var _sub_host: VBoxContainer = null
static var _name_edit: LineEdit = null
static var _status: Label = null
static var _banner: PanelContainer = null
static var _banner_name: Label = null
static var _grid: MapEditorGrid = null
static var _tab_buttons: Dictionary = {}
static var _stairs_box: VBoxContainer = null
static var _merchant_box: VBoxContainer = null
static var _field_boxes: Dictionary = {}

# ------------------------------------------------------------------ données

static func _cfg() -> Dictionary:
	return Data.admin_config()

static func _levels() -> Array:
	return _cfg().get("levels", [])

static func _current() -> Dictionary:
	for l in _levels():
		if l.id == _sel:
			return l
	var ls := _levels()
	if ls.is_empty():
		return {}
	_sel = str(ls[0].id)
	return ls[0]

static func _level_by_id(id) -> Dictionary:
	for l in _levels():
		if l.id == id:
			return l
	return {}

static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if str(e.id) == id:
			return e
	return {}

## `ensureLevelStairs` : escaliers déduits de la carte (action copiée depuis `stairsAction` si présente).
static func _ensure_stairs(lvl: Dictionary) -> void:
	if lvl.has("stairs"):
		return
	lvl["stairs"] = []
	var rows: Array = lvl.mapRows
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			if row[x] == "S":
				var action: Dictionary = (lvl.stairsAction as Dictionary).duplicate(true) if lvl.get("stairsAction") is Dictionary else {"type": "victory"}
				lvl.stairs.append({"id": "stairs_%d_%d" % [x, y], "x": x, "y": y, "action": action})

static func _prepare(lvl: Dictionary) -> void:
	if not lvl.has("doors"):
		lvl["doors"] = []
	_ensure_stairs(lvl)
	if not lvl.has("monsters"):
		lvl["monsters"] = []
	if not lvl.has("items"):
		lvl["items"] = []

# API fournie par Data (agent « Général ») ; appels dynamiques pour rester valide tant qu'elle n'existe pas.
static func _has_run() -> bool:
	return Data.has_method("admin_has_run") and bool(Data.call("admin_has_run"))

static func _marker() -> Dictionary:
	if Data.has_method("admin_party_marker"):
		var m = Data.call("admin_party_marker")
		if m is Dictionary:
			return m
	return {}

static func _teleport_group(level_id: String, x: int, y: int) -> String:
	if Data.has_method("admin_teleport_group"):
		return str(Data.call("admin_teleport_group", level_id, x, y))
	return L.t("common.aucune_partie_en_cours_lancez")

static func _teleport_village() -> String:
	if Data.has_method("admin_teleport_village"):
		return str(Data.call("admin_teleport_village"))
	return L.t("common.aucune_partie_en_cours_lancez")

static func _alert(text: String) -> void:
	Dialogs.notice(_admin.modals(), "", text)

static func _too_close_to_stairs(lvl: Dictionary, x: int, y: int, min_dist: int = 3) -> bool:
	var rows: Array = lvl.mapRows
	for sy in rows.size():
		var row := str(rows[sy])
		for sx in row.length():
			if row[sx] == "S" and maxi(absi(sx - x), absi(sy - y)) < min_dist:
				return true
	return false

static func _would_make_room(lvl: Dictionary, x: int, y: int) -> bool:
	var rows: Array = lvl.mapRows
	var is_open := func(cx: int, cy: int) -> bool:
		if cx == x and cy == y:
			return true
		if cy < 0 or cy >= rows.size() or cx < 0 or cx >= str(rows[0]).length():
			return false
		return str(rows[cy])[cx] != "#"
	for dx in [-1, 0]:
		for dy in [-1, 0]:
			var bx: int = x + dx
			var by: int = y + dy
			if is_open.call(bx, by) and is_open.call(bx + 1, by) and is_open.call(bx, by + 1) and is_open.call(bx + 1, by + 1):
				return true
	return false

# ------------------------------------------------------------------ outils d'interface

static func _px(v: float) -> float:
	return UiMetrics.css(v)

static func _fs(rem: float) -> int:
	return int(round(UiMetrics.rem(rem)))

## Nombre tel que l'affiche JavaScript (entier sans « .0 », plus court aller-retour sinon).
static func _js_num(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "NaN" if is_nan(v) else ("Infinity" if v > 0.0 else "-Infinity")
	if v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	for d in range(1, 18):
		var s := String.num(v, d)
		if s.to_float() == v:
			return s
	return str(v)

static func _fmt(v) -> String:
	if v == null:
		return ""
	if v is float or v is int:
		return _js_num(float(v))
	return str(v)

## `x||d` de JavaScript pour un nombre.
static func _or(v, d: float) -> float:
	if v == null:
		return d
	var f := float(v) if (v is int or v is float) else (str(v).to_float() if str(v).is_valid_float() else 0.0)
	return d if (f == 0.0 or is_nan(f)) else f

## Valeur numérique stockée : entier si possible (comme JSON), sinon flottant.
static func _store(v: float) -> Variant:
	if is_nan(v) or is_inf(v):
		return 0
	return int(v) if v == floorf(v) and absf(v) < 1e15 else v

## `Number(text)` (champ vide ou invalide → 0 via `||`).
static func _parse(t: String) -> float:
	var s := t.strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0

static func _field_box(focus: bool, pad: Vector2) -> StyleBoxFlat:
	var key := "%s|%s" % [focus, pad]
	if not _field_boxes.has(key):
		var b := StyleBoxFlat.new()
		b.bg_color = Color("150f08")
		b.border_color = GOLD_DIM if focus else BORDER
		b.set_border_width_all(1)
		b.set_corner_radius_all(5)
		b.content_margin_left = _px(pad.x)
		b.content_margin_right = _px(pad.x)
		b.content_margin_top = _px(pad.y)
		b.content_margin_bottom = _px(pad.y)
		_field_boxes[key] = b
	return _field_boxes[key]

static func _style_edit(e: LineEdit, rem: float, pad: Vector2) -> void:
	e.add_theme_stylebox_override("normal", _field_box(false, pad))
	e.add_theme_stylebox_override("focus", _field_box(true, pad))
	e.add_theme_stylebox_override("read_only", _field_box(false, pad))
	e.add_theme_font_size_override("font_size", _fs(rem))
	e.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))

static func _lbl(text: String, rem: float, color: Color = PARCH_DIM, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _fs(rem))
	l.add_theme_color_override("font_color", color)
	if italic:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

## Bouton compact (`button` de l'original) ; `primary` = texte or clair.
static func _btn(text: String, cb: Callable, rem: float = 0.8, primary: bool = false, margins: Vector2 = Vector2(10, 5)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", _fs(rem))
	var cm := [int(_px(margins.x)), int(_px(margins.y)), int(_px(margins.x)), int(_px(margins.y))]
	b.add_theme_stylebox_override("normal", UiTheme.tbox("btn_n", [10, 10, 10, 10], cm))
	b.add_theme_stylebox_override("hover", UiTheme.tbox("btn_h", [10, 10, 10, 10], cm))
	b.add_theme_stylebox_override("pressed", UiTheme.tbox("btn_p", [10, 10, 10, 10], cm))
	b.add_theme_stylebox_override("disabled", UiTheme.tbox("btn_d", [10, 10, 10, 10], cm))
	if primary:
		b.add_theme_color_override("font_color", GOLD_BRIGHT)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func _tipped(c: Control, tip: String) -> Control:
	c.tooltip_text = tip
	return c

## Liste déroulante compacte (`select` de l'original) ; `on_pick` reçoit la valeur de l'option.
static func _dd(options: Array, current, on_pick: Callable, rem: float = 0.74, min_w: float = 0.0, tip: String = "") -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = min_w <= 0.0
	o.clip_text = min_w > 0.0
	o.tooltip_text = tip
	o.add_theme_font_size_override("font_size", _fs(rem))
	o.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	if min_w > 0.0:
		o.custom_minimum_size.x = _px(min_w)
	var sel := 0
	var found := false
	for i in options.size():
		o.add_item(str(options[i][1]))
		if not found and str(options[i][0]) == str(current):
			sel = i
			found = true
	if options.size() > 0:
		o.select(sel)
	o.item_selected.connect(func(i: int): on_pick.call(options[i][0]))
	return o

static func _chk(checked: bool, on_toggle: Callable, tip: String = "", disabled: bool = false, text: String = "") -> CheckBox:
	var c := CheckBox.new()
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = checked
	c.disabled = disabled
	c.tooltip_text = tip
	if text != "":
		c.text = text
		c.add_theme_font_size_override("font_size", _fs(0.72))
	c.toggled.connect(func(on: bool): on_toggle.call(on))
	return c

## Champ « input type=number » : la valeur est enregistrée en direct ; à Entrée / perte de focus le texte est réécrit avec la
## valeur réellement conservée (bornes appliquées). `setter(v: float, final: bool)` renvoie la valeur stockée.
static func _num(shown, w: float, setter: Callable, tip: String = "", rem: float = 0.74, placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = _fmt(shown)
	e.placeholder_text = placeholder
	e.custom_minimum_size.x = _px(maxf(w, 42.0))
	e.tooltip_text = tip
	e.context_menu_enabled = false
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.select_all_on_focus = false
	e.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_edit(e, rem, Vector2(5, 5))
	var ok := RegEx.create_from_string("^[0-9eE.+\\-]*$")
	var last := [e.text]
	var apply := func(final: bool):
		var v := _parse(e.text)
		var stored = setter.call(v, final)
		if final:
			e.text = _fmt(stored)
			last[0] = e.text
	e.text_changed.connect(func(t: String):
		if ok.search(t) == null:
			var c := e.caret_column - 1
			e.text = last[0]
			e.caret_column = clampi(c, 0, e.text.length())
			return
		last[0] = t
		apply.call(false))
	e.text_submitted.connect(func(_t: String):
		apply.call(true)
		e.release_focus())
	e.focus_exited.connect(func(): apply.call(true))
	return e

## Champ texte enregistré en direct dans `target[key]`.
static func _text(target: Dictionary, key: String, w: float, rem: float = 0.74, pad: Vector2 = Vector2(5, 5), placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = str(target.get(key, ""))
	e.placeholder_text = placeholder
	e.custom_minimum_size.x = _px(w)
	_style_edit(e, rem, pad)
	e.text_changed.connect(func(t: String): target[key] = t)
	return e

static func _set_plain(target: Dictionary, key: String, extra: Callable = Callable()) -> Callable:
	return func(v: float, _final: bool):
		target[key] = _store(v)
		if extra.is_valid():
			extra.call()
		return target[key]

static func _set_clamped(target: Dictionary, key: String, lo: float, hi: float) -> Callable:
	return func(v: float, _final: bool):
		target[key] = _store(clampf(v, lo, hi))
		return target[key]

## Ligne `.field-row` : libellé de 140 px (0,75 rem) + champs, passage à la ligne autorisé.
static func _frow(parent: Control, label: String, hint: String = "", min_w: float = 140.0) -> HFlowContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", 6)
	parent.add_child(m)
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 4)
	m.add_child(f)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = _px(min_w)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_lbl(label, 0.75))
	if hint != "":
		box.add_child(_lbl(hint, 0.74, PARCH_DIM, true))
	f.add_child(box)
	return f

static func _field_row_edit(rem: float = 0.85) -> Vector2:
	return Vector2(9, 7)

## Ligne de boutons `.admin-actions`.
static func _actions(parent: Control, specs: Array, top: float = 14.0, bottom: float = 0.0) -> HFlowContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(maxf(0.0, top - 4.0)))
	m.add_theme_constant_override("margin_bottom", int(bottom))
	parent.add_child(m)
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	m.add_child(f)
	for sp in specs:
		f.add_child(_btn(str(sp[0]), sp[1], 0.8, sp.size() > 2 and sp[2]))
	return f

static func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

## Style `.icon-pick-btn` (38×38, fond #1c1610, liseré #5a4526, coins 6) appliqué au bouton d'icône.
static func _icon_btn(b: Button) -> Button:
	b.custom_minimum_size = Vector2(_px(38), _px(38))
	b.add_theme_constant_override("icon_max_width", int(_px(28)))
	for st in ["normal", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("1c1610")
		s.border_color = BORDER
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, s)
	var h := StyleBoxFlat.new()
	h.bg_color = Color("1c1610")
	h.border_color = GOLD_DIM
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	b.add_theme_stylebox_override("hover", h)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

## Ligne en pointillés (séparateur de l'encart « Légendaire »).
class DashLine extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0.5), Vector2(minf(x + 3.0, size.x), 0.5), Color("5a4526"), 1.0)
			x += 6.0

## Rangée : 230 px | 1fr, empilée sous 780 px.
class AdaptiveRow extends BoxContainer:
	var left: Control = null
	func _init() -> void:
		vertical = false
		add_theme_constant_override("separation", 14)
	func _ready() -> void:
		get_viewport().size_changed.connect(_adapt)
		_adapt()
	func _adapt() -> void:
		if left == null:
			return
		var narrow := get_viewport_rect().size.x <= UiMetrics.css(780.0)
		vertical = narrow
		left.custom_minimum_size.x = 0.0 if narrow else UiMetrics.css(230.0)
		left.size_flags_horizontal = Control.SIZE_FILL if not narrow else Control.SIZE_EXPAND_FILL

# ------------------------------------------------------------------ cadre : liste | éditeur

static func build(host: VBoxContainer, admin: Node) -> void:
	_admin = admin
	_tab_buttons = {}
	_grid = null
	_banner = null
	_stairs_box = null
	_merchant_box = null
	var layout := AdaptiveRow.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(layout)
	# ---- colonne gauche : liste des niveaux
	var lp := OrnatePanel.new(L.t("admin.levels.niveaux_du_donjon"))
	layout.add_child(lp)
	layout.left = lp
	layout._adapt()
	var link := RichTextLabel.new()
	link.bbcode_enabled = true
	link.fit_content = true
	link.scroll_active = false
	link.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link.add_theme_font_size_override("normal_font_size", _fs(0.74))
	link.add_theme_color_override("default_color", GOLD_DIM)
	link.text = "[center][url=tuto][u]%s[/u][/url][/center]" % L.t("admin.levels.besoin_aide_voir_l_etape").replace("[", "[lb]")
	link.meta_clicked.connect(func(_m): GuideBook.open(admin.modals(), "levels", "tutorial"))
	link.meta_hover_started.connect(func(_m): link.add_theme_color_override("default_color", GOLD_BRIGHT))
	link.meta_hover_ended.connect(func(_m): link.add_theme_color_override("default_color", GOLD_DIM))
	lp.body.add_child(link)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 5)
	lp.body.add_child(_list_box)
	var add := _btn(L.t("admin.levels.ajouter_un_niveau"), func(): _add_level(), 0.8, true, Vector2(6, 10))
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.body.add_child(add)
	# ---- colonne droite : éditeur
	var ep := OrnatePanel.new(L.t("admin.levels.edition_du_niveau"))
	ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(ep)
	var nrow := _frow(ep.body, L.t("admin.levels.nom_du_niveau"))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = _px(208)
	_style_edit(_name_edit, 0.85, Vector2(9, 7))
	_name_edit.text_changed.connect(func(t: String):
		var l := _current()
		if not l.is_empty():
			l["name"] = t
			_render_list())
	nrow.add_child(_name_edit)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	ep.body.add_child(tabs)
	var group := ButtonGroup.new()
	for t in [["map", L.t("admin.levels.carte")], ["mon", L.t("admin.levels.monstres")], ["item", L.t("admin.levels.objets")], ["cfg", L.t("admin.levels.reglages")]]:
		var tb := _btn(str(t[1]), Callable(), 0.72, false, Vector2(12, 6))
		tb.toggle_mode = true
		tb.button_group = group
		tb.button_pressed = _tab == t[0]
		var id: String = t[0]
		tb.pressed.connect(func():
			_tab = id
			_render_sub())
		for st in ["pressed", "hover_pressed"]:
			tb.add_theme_stylebox_override(st, UiTheme.tbox("btn_h", [10, 10, 10, 10], [int(_px(12)), int(_px(6)), int(_px(12)), int(_px(6))]))
		tb.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
		tb.add_theme_color_override("font_hover_pressed_color", GOLD_BRIGHT)
		tabs.add_child(tb)
		_tab_buttons[id] = tb
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	ep.body.add_child(sp)
	_sub_host = VBoxContainer.new()
	_sub_host.add_theme_constant_override("separation", 4)
	_sub_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ep.body.add_child(_sub_host)
	_status = _lbl("", 0.7, Color("7a6a52"))
	var acts := _actions(ep.body, [[L.t("common.enregistrer_la_configuration"), func(): admin.confirm_save(_status), true], [L.t("admin.levels.supprimer_ce_niveau"), func(): _delete_level()]])
	ep.body.add_child(_status)
	_render_list()
	_render_editor()

static func _row_box(sel: bool, hover: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.91, 0.71, 0.36, 0.08) if sel else Color(1, 1, 1, 0.02)
	b.border_color = GOLD_DIM if sel else (BORDER if hover else Color(0, 0, 0, 0))
	b.set_border_width_all(1)
	b.set_corner_radius_all(6)
	b.content_margin_left = _px(8)
	b.content_margin_right = _px(8)
	b.content_margin_top = _px(8)
	b.content_margin_bottom = _px(8)
	return b

static func _render_list() -> void:
	if _list_box == null or not is_instance_valid(_list_box):
		return
	_clear(_list_box)
	var levels := _levels()
	for i in levels.size():
		var l: Dictionary = levels[i]
		var lid := str(l.id)
		var sel := lid == _sel
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _row_box(sel, false))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_entered.connect(func():
			if is_instance_valid(row) and lid != _sel:
				row.add_theme_stylebox_override("panel", _row_box(false, true)))
		row.mouse_exited.connect(func():
			if is_instance_valid(row):
				row.add_theme_stylebox_override("panel", _row_box(lid == _sel, false)))
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select(lid))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		row.add_child(h)
		var nm := _lbl(str(l.get("name", "")), 0.82, GOLD_BRIGHT if sel else UiTheme.PARCH)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.custom_minimum_size.x = 10
		h.add_child(nm)
		var mini := HBoxContainer.new()
		mini.add_theme_constant_override("separation", 3)
		h.add_child(mini)
		var idx := i
		for d in [["↑", -1], ["↓", 1]]:
			var dd: int = d[1]
			mini.add_child(_btn(str(d[0]), func():
				var ls := _levels()
				if idx + dd >= 0 and idx + dd < ls.size():
					var tmp = ls[idx]
					ls[idx] = ls[idx + dd]
					ls[idx + dd] = tmp
					_render_list(), 0.65, false, Vector2(6, 2)))
		_list_box.add_child(row)

static func _select(id: String) -> void:
	_sel = id
	if str(_placement.get("kind", "")) != "teleport":
		_placement = {}
	_render_list()
	_render_editor()

## `renderLevelEditor` : champ du nom + contenu de l'onglet courant.
static func _render_editor() -> void:
	var lvl := _current()
	if _name_edit == null or not is_instance_valid(_name_edit):
		return
	if lvl.is_empty():
		_name_edit.text = ""
		_clear(_sub_host)
		return
	_prepare(lvl)
	_name_edit.text = str(lvl.get("name", ""))
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == _tab)
	_render_sub()

static func _render_sub() -> void:
	if _sub_host == null or not is_instance_valid(_sub_host):
		return
	_clear(_sub_host)
	_banner = null
	_grid = null
	_stairs_box = null
	_merchant_box = null
	var lvl := _current()
	if lvl.is_empty():
		return
	_prepare(lvl)
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == _tab)
	match _tab:
		"map": _map_sub(_sub_host, lvl)
		"mon": _monsters_sub(_sub_host, lvl)
		"item": _items_sub(_sub_host, lvl)
		"cfg": _cfg_sub(_sub_host, lvl)

static func _add_level() -> void:
	if _levels().size() >= MAX_LEVELS:
		_alert(L.t("admin.levels.un_donjon_ne_peut_pas"))
		return
	var rows: Array = []
	for y in 8:
		rows.append("#".repeat(8))
	var id := "lvl_%d" % Time.get_ticks_msec()
	_levels().append({"id": id, "name": L.t("admin.levels.nouveau_niveau"), "theme": "stone", "mapRows": rows, "startX": 1, "startY": 1, "startDir": 1, "stairs": [], "doors": [], "monsters": [], "items": []})
	_sel = id
	_render_list()
	_render_editor()

static func _delete_level() -> void:
	if _levels().size() <= 1:
		_alert(L.t("admin.levels.il_doit_rester_au_moins"))
		return
	var go := func():
		var removed := _sel
		var ls := _levels()
		for i in range(ls.size() - 1, -1, -1):
			if ls[i].id == removed:
				ls.remove_at(i)
		for l in ls:
			for st in l.get("stairs", []):
				var a: Dictionary = st.get("action", {})
				if a.get("type") == "level" and a.get("targetId") == removed:
					st["action"] = {"type": "victory"}
		_sel = str(ls[0].id)
		_render_list()
		_render_editor()
	Dialogs.confirm(_admin.modals(), "", L.t("admin.levels.supprimer_ce_niveau_definitivement"), go)

# ------------------------------------------------------------------ placement

static func _placement_name(lvl: Dictionary) -> String:
	match str(_placement.get("kind", "")):
		"monster": return str(_find(lvl.monsters, str(_placement.id)).get("name", ""))
		"item": return str(_find(lvl.items, str(_placement.id)).get("name", ""))
		"merchant": return L.t("admin.levels.le_marchand_ambulant")
		"teleport": return L.t("admin.levels.le_groupe_teleportation")
	return L.t("admin.levels.le_point_de_depart")

## `updatePlacementBanner` : encadré or (12 %), liseré or terni, rayon 6.
static func _update_banner() -> void:
	if _banner == null or not is_instance_valid(_banner):
		return
	if _placement.is_empty():
		_banner.visible = false
		return
	_banner.visible = true
	_banner_name.text = _placement_name(_current())

static func _build_banner(parent: Control) -> void:
	_banner = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.71, 0.36, 0.12)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = _px(12)
	sb.content_margin_right = _px(12)
	sb.content_margin_top = _px(8)
	sb.content_margin_bottom = _px(8)
	_banner.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_banner.add_child(h)
	var span := HBoxContainer.new()
	span.add_theme_constant_override("separation", 0)
	span.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	span.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pre := _lbl(L.t("admin.levels.cliquez_sur_la_carte_pour"), 0.8, UiTheme.PARCH)
	span.add_child(pre)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(5, 0)
	span.add_child(sp)
	_banner_name = _lbl("", 0.8, UiTheme.PARCH)
	_banner_name.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	span.add_child(_banner_name)
	h.add_child(span)
	h.add_child(_btn(L.t("common.annuler"), func():
		_placement = {}
		_update_banner(), 0.7, false, Vector2(10, 4)))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", 6)
	m.add_child(_banner)
	parent.add_child(m)
	_banner.visible = false
	_update_banner()

static func _start_placement(kind: String, id: String = "") -> void:
	_placement = {"kind": kind, "id": id}
	_tab = "map"
	_render_sub()

# ------------------------------------------------------------------ onglet Carte

static func _radio_icon(on: bool) -> Texture2D:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(7.5, 7.5)
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if on:
				if d <= 7.2 and d > 5.0:
					col = Color("0075ff")
				elif d <= 5.0 and d > 3.6:
					col = Color.WHITE
				elif d <= 3.6:
					col = Color("0075ff")
			else:
				if d <= 7.2 and d > 6.2:
					col = Color("767676")
				elif d <= 6.2:
					col = Color.WHITE
			if col.a > 0.0:
				var edge := clampf(7.7 - d, 0.0, 1.0)
				col.a *= edge
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

static func _map_sub(ep: VBoxContainer, lvl: Dictionary) -> void:
	_build_banner(ep)
	# dimensions
	var rows: Array = lvl.mapRows
	var dims := {"w": str(rows[0]).length(), "h": rows.size()}
	var dl := HFlowContainer.new()
	dl.add_theme_constant_override("h_separation", 8)
	dl.add_theme_constant_override("v_separation", 4)
	var dm := MarginContainer.new()
	dm.add_theme_constant_override("margin_bottom", 6)
	dm.add_child(dl)
	ep.add_child(dm)
	var cap60 := func(key: String) -> Callable:
		return func(v: float, _final: bool):
			if v > 60.0:
				dims[key] = 60.0
			else:
				dims[key] = v
			return dims[key]
	for spec in [[L.t("admin.levels.largeur"), "w"], [L.t("admin.levels.hauteur"), "h"]]:
		var lb := HBoxContainer.new()
		lb.add_theme_constant_override("separation", 4)
		lb.custom_minimum_size.x = _px(140)
		lb.add_child(_lbl(str(spec[0]), 0.75))
		lb.add_child(_lbl(L.t("admin.levels.max_60"), 0.74, PARCH_DIM, true))
		dl.add_child(lb)
		var key: String = spec[1]
		var ne := _num(dims[key], 70, cap60.call(key), "", 0.85)
		_style_edit(ne, 0.85, Vector2(9, 7))
		ne.custom_minimum_size.x = _px(70)
		dl.add_child(ne)
	dl.add_child(_btn(L.t("admin.levels.redimensionner"), func(): _resize(lvl, dims)))
	# pinceaux
	var bl := HFlowContainer.new()
	bl.add_theme_constant_override("h_separation", 14)
	bl.add_theme_constant_override("v_separation", 4)
	bl.add_child(_lbl(L.t("admin.levels.pinceau"), 0.8))
	var group := ButtonGroup.new()
	var ric := _radio_icon(true)
	var ric0 := _radio_icon(false)
	for br in [[".", L.t("admin.levels.sol")], ["#", L.t("admin.levels.mur")], ["D", L.t("admin.levels.porte")], ["S", L.t("common.escalier")]]:
		var cb := CheckBox.new()
		cb.text = str(br[1])
		cb.toggle_mode = true
		cb.button_group = group
		cb.button_pressed = _brush == br[0]
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", _fs(0.8))
		cb.add_theme_icon_override("checked", ric)
		cb.add_theme_icon_override("unchecked", ric0)
		cb.add_theme_icon_override("radio_checked", ric)
		cb.add_theme_icon_override("radio_unchecked", ric0)
		cb.add_theme_constant_override("h_separation", 5)
		var ch: String = br[0]
		cb.pressed.connect(func(): _brush = ch)
		bl.add_child(cb)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_bottom", 6)
	bm.add_child(bl)
	ep.add_child(bm)
	var rl := HFlowContainer.new()
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_bottom", 6)
	rm.add_child(rl)
	ep.add_child(rm)
	var rooms := CheckBox.new()
	rooms.text = L.t("admin.levels.autoriser_les_salles_test_desactive")
	rooms.focus_mode = Control.FOCUS_NONE
	rooms.button_pressed = _allow_rooms
	rooms.add_theme_font_size_override("font_size", _fs(0.78))
	rooms.toggled.connect(func(on: bool): _allow_rooms = on)
	rl.add_child(rooms)
	# grille
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid = MapEditorGrid.new()
	scroll.add_child(_grid)
	_grid.party_marker = _marker()
	_grid.set_level(lvl)
	ep.add_child(scroll)
	_grid.cell_pressed.connect(func(x: int, y: int): _on_cell(lvl, x, y))
	_grid.badge_pressed.connect(func(x: int, y: int, kind: String, id: String): _on_badge(lvl, kind, id))
	Form.hint(ep, L.t("admin.levels.cliquez_sur_une_case_pour"), _fs(0.74))

static func _refresh_grid() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.party_marker = _marker()
		_grid.refresh()

static func _resize(lvl: Dictionary, dims: Dictionary) -> void:
	var W := clampi(int(_or(dims.w, 8.0)), 4, 60)
	var H := clampi(int(_or(dims.h, 8.0)), 4, 60)
	var old: Array = lvl.mapRows
	var nr: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += str(old[y])[x] if (y < old.size() and x < str(old[0]).length()) else "#"
		nr.append(row)
	lvl["mapRows"] = nr
	_render_sub()

## Clic sur une pastille retirable : retire l'entité du niveau (`onMapGridClick`).
static func _on_badge(lvl: Dictionary, kind: String, id: String) -> void:
	if kind == "mon":
		var arr: Array = lvl.monsters
		for i in arr.size():
			if str(arr[i].id) == id:
				arr.remove_at(i)
				break
	else:
		_remove_item(lvl, id)
	_refresh_grid()

static func _remove_item(lvl: Dictionary, id: String) -> void:
	var items: Array = lvl.items
	for i in items.size():
		if str(items[i].id) == id:
			items.remove_at(i)
			break
	for m in lvl.monsters:
		if m.get("lootItemId") == id:
			m["lootItemId"] = ""
		if m.get("lootItemId2") == id:
			m["lootItemId2"] = ""

## Clic sur une case : placement en cours, sinon peinture (`onMapCellPaint`).
static func _on_cell(lvl: Dictionary, x: int, y: int) -> void:
	if not _placement.is_empty():
		_place(lvl, x, y)
		return
	_paint(lvl, x, y)

static func _place(lvl: Dictionary, x: int, y: int) -> void:
	match str(_placement.get("kind", "")):
		"monster":
			if _too_close_to_stairs(lvl, x, y):
				_alert(L.t("admin.levels.un_monstre_ne_peut_pas"))
				return
			var m := _find(lvl.monsters, str(_placement.id))
			if not m.is_empty():
				m["x"] = x
				m["y"] = y
		"item":
			var it := _find(lvl.items, str(_placement.id))
			if not it.is_empty():
				it["x"] = x
				it["y"] = y
		"merchant":
			if not (lvl.get("travelingMerchant") is Dictionary):
				lvl["travelingMerchant"] = {"x": x, "y": y, "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			else:
				lvl.travelingMerchant["x"] = x
				lvl.travelingMerchant["y"] = y
		"start":
			lvl["startX"] = x
			lvl["startY"] = y
		"teleport":
			if str(lvl.mapRows[y])[x] == "#":
				_alert(L.t("admin.levels.case_muree_choisissez_une_case"))
				return
			var err: String = _teleport_group(str(lvl.id), x, y)
			if err != "":
				_alert(err)
				_placement = {}
				_update_banner()
				return
	_placement = {}
	_render_sub()

static func _paint(lvl: Dictionary, x: int, y: int) -> void:
	var rows: Array = lvl.mapRows
	if _brush == "." and not _allow_rooms and _would_make_room(lvl, x, y):
		_alert(L.t("admin.levels.impossible_cela_creerait_une"))
		return
	var row := str(rows[y])
	rows[y] = row.substr(0, x) + _brush + row.substr(x + 1)
	var doors: Array = lvl.doors
	var stairs: Array = lvl.stairs
	for i in range(doors.size() - 1, -1, -1):
		if int(doors[i].x) == x and int(doors[i].y) == y:
			doors.remove_at(i)
	for i in range(stairs.size() - 1, -1, -1):
		if int(stairs[i].x) == x and int(stairs[i].y) == y:
			stairs.remove_at(i)
	if _brush == "D":
		doors.append({"id": "door_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "locked": true})
	elif _brush == "S":
		stairs.append({"id": "stairs_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "action": {"type": "victory"}})
	_refresh_grid()

# ------------------------------------------------------------------ onglet Monstres

static func _mon_derived(m: Dictionary) -> Dictionary:
	var max_hp := 5.0 + _or(m.get("con"), 8.0) * 2.8
	var amin := maxf(1.0, floorf(_or(m.get("force"), 8.0) / 2.5))
	var amax := amin + 1.0 + floorf(_or(m.get("dex"), 8.0) / 3.3)
	return {"maxHp": max_hp, "atkMin": amin, "atkMax": amax}

static func _preview_text(m: Dictionary) -> String:
	var d := _mon_derived(m)
	return "PV%s·%d-%d" % [_js_num(d.maxHp), int(d.atkMin), int(d.atkMax)]

static func _door_options(lvl: Dictionary) -> Array:
	var out: Array = [["", L.t("admin.levels.aucune")]]
	for d in lvl.get("doors", []):
		out.append([d.id, L.fa(L.t("common.porte"), [int(d.x), int(d.y)])])
	return out

static func _loot_button(lvl: Dictionary, m: Dictionary, key: String, tip: String) -> Button:
	var cur = null
	var id := str(m.get(key, ""))
	if id != "":
		cur = _find(lvl.items, id)
		if (cur as Dictionary).is_empty():
			cur = null
	var label := L.t("common.aucun") if cur == null else "%s %s" % [AdminUtil.icon_text_fallback(str(cur.get("icon", ""))), cur.get("name", "")]
	var b := _btn(label, func():
		LootPicker.open(_admin.modals(), lvl.items, func(picked: String):
			m[key] = picked
			_render_sub.call_deferred()), 0.8, false, Vector2(6, 10))
	b.tooltip_text = tip
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := b.get_theme_font("font")
	var want := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(0.8)).x + _px(24)
	b.custom_minimum_size.x = minf(want, _px(150))
	return b

static func _monsters_sub(host: VBoxContainer, lvl: Dictionary) -> void:
	var headers := [L.t("common.icone"), L.t("common.nom"), L.t("admin.levels.position"), L.t("common.for"), "Dex", "Con", L.t("common.vitesse"), L.t("common.apercu"), L.t("admin.levels.res_phys"), L.t("admin.levels.res_mag"), "XP", L.t("common.or"), L.t("admin.levels.capacite_chance"), L.t("admin.levels.seuil_rage"), "Zone", L.t("common.vitesse_attaque"), L.t("admin.levels.ouvre_porte"), L.t("admin.levels.butin"), L.t("admin.levels.chance"), L.t("admin.levels.butin_2"), L.t("admin.levels.chance_2"), "Boss", L.t("admin.levels.groupe"), L.t("admin.levels.cache"), "", ""]
	var widths := [38, 90, 40, 42, 42, 42, 42, 64, 42, 42, 42, 42, 220, 42, 42, 90, 100, 110, 44, 110, 44, 15, 40, 15, 0, 0]
	var g := AdminTable.create(host, headers, widths)
	var spells: Array = [["", L.t("admin.levels.attaque_simple")]]
	for s in _cfg().get("spells", []):
		if s.get("mode") == "damage":
			spells.append([s.id, AdminUtil.spell_label(s)])
	for m in lvl.monsters:
		_monster_row(g, lvl, m, spells)
	var ab := Form.buttons(host, [[L.t("admin.levels.ajouter_un_monstre"), func(): _add_monster(lvl)]])
	ab.get_child(0).add_theme_font_size_override("font_size", _fs(0.8))

static func _monster_row(g: GridContainer, lvl: Dictionary, m: Dictionary, spells: Array) -> void:
	var mid := str(m.id)
	AdminTable.cell(g, _icon_btn(IconPicker.button(_admin.modals(), m, "icon", Callable(), 26.0)))
	AdminTable.cell(g, _text(m, "name", 90))
	AdminTable.text_cell(g, "%d,%d" % [int(m.x), int(m.y)], false, 0.72).clip_text = false
	var prev := _lbl(_preview_text(m), 0.6)
	var upd := func(): prev.text = _preview_text(m)
	for k in ["force", "dex", "con"]:
		var key: String = k
		var set_stat := func(v: float, final: bool):
			m[key] = _store(v)
			upd.call()
			return _or(m[key], 8.0)
		AdminTable.cell(g, _num(_or(m.get(key), 8.0), 36, set_stat))
	var set_speed := func(v: float, _f: bool):
		m["speed"] = _store(v)
		return m["speed"]
	AdminTable.cell(g, _num(m.get("speed", 8), 36, set_speed, L.t("admin.levels.vitesse_determine_l_ordre_de")))
	AdminTable.cell(g, prev)
	AdminTable.cell(g, _num(_or(m.get("resistPhys"), 0.0), 38, _set_clamped(m, "resistPhys", 0, 100), L.t("admin.levels.resistance_physique")))
	AdminTable.cell(g, _num(_or(m.get("resistMagic"), 0.0), 38, _set_clamped(m, "resistMagic", 0, 100), L.t("admin.levels.resistance_magique")))
	var set_xp := func(v: float, _f: bool):
		m["xpReward"] = _store(v)
		return _or(m["xpReward"], 10.0)
	AdminTable.cell(g, _num(_or(m.get("xpReward"), 10.0), 40, set_xp))
	var set_gold := func(v: float, _f: bool):
		m["goldReward"] = _store(v)
		return _or(m["goldReward"], 0.0)
	AdminTable.cell(g, _num(_or(m.get("goldReward"), 0.0), 40, set_gold, L.t("admin.levels.or_gagne_a_la_mort")))
	# capacité spéciale (+ chance si une capacité est choisie)
	var cap := HBoxContainer.new()
	cap.add_theme_constant_override("separation", 4)
	cap.custom_minimum_size.x = _px(220)
	var sel := _dd(spells, m.get("abilitySpellId", ""), func(v):
		m["abilitySpellId"] = v
		_render_sub.call_deferred(), 0.68, 0.0, L.t("admin.levels.capacite_speciale_remplace_parfois"))
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(sel)
	if str(m.get("abilitySpellId", "")) != "":
		var set_ch := func(v: float, _f: bool):
			m["abilityChance"] = _store(clampf(v, 0.0, 100.0))
			return m["abilityChance"]
		cap.add_child(_num(m.get("abilityChance", 30), 48, set_ch, L.t("admin.levels.chance_utiliser_la_capacite")))
	AdminTable.cell(g, cap)
	AdminTable.cell(g, _num(_or(m.get("enrageThreshold"), 0.0), 40, _set_clamped(m, "enrageThreshold", 0, 100), L.t("admin.levels.seuil_de_pv_declenchant_la")))
	var set_zone := func(v: float, _f: bool):
		m["patrolRadius"] = _store(maxf(0.0, v))
		return m["patrolRadius"]
	AdminTable.cell(g, _num(_or(m.get("patrolRadius"), 0.0), 38, set_zone, L.t("admin.levels.rayon_de_deplacement_automatique")))
	# cadence d'attaque : curseur 1–3 s
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 3)
	var asv := float(m.get("attackSpeed", 2))
	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value = asv
	slider.custom_minimum_size = Vector2(_px(64), 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = L.t("admin.levels.rapidite_attaque_automatique")
	var sl := _lbl("%.1fs" % asv, 0.65)
	slider.value_changed.connect(func(v: float):
		m["attackSpeed"] = _store(clampf(v if v != 0.0 else 2.0, 1.0, 3.0))
		sl.text = "%.1fs" % v)
	sp.add_child(slider)
	sp.add_child(sl)
	AdminTable.cell(g, sp)
	AdminTable.cell(g, _dd(_door_options(lvl), m.get("opensDoorId", ""), func(v): m["opensDoorId"] = v, 0.74, 100))
	AdminTable.cell(g, _loot_button(lvl, m, "lootItemId", L.t("admin.levels.objet_cree_dans_la_liste")))
	AdminTable.cell(g, _num(m.get("lootChance", 100), 44, func(v: float, _f: bool):
		m["lootChance"] = _store(v)
		return m["lootChance"], L.t("admin.levels.chance_de_laisser_tomber_le")))
	AdminTable.cell(g, _loot_button(lvl, m, "lootItemId2", L.t("admin.levels.second_emplacement_de_butin_ex")))
	AdminTable.cell(g, _num(m.get("lootChance2", 100), 44, func(v: float, _f: bool):
		m["lootChance2"] = _store(v)
		return m["lootChance2"], L.t("admin.levels.chance_de_laisser_tomber_ce")))
	# boss / groupe (exclusifs)
	var boss := _chk(bool(m.get("isBoss", false)), func(on: bool):
		m["isBoss"] = on
		if on:
			m["isGroup"] = false
		_render_sub.call_deferred(), L.t("admin.levels.affichage_imposant_monstre_de"), bool(m.get("isGroup", false)))
	var bc := CenterContainer.new()
	bc.add_child(boss)
	AdminTable.cell(g, bc)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 2)
	gh.add_child(_chk(bool(m.get("isGroup", false)), func(on: bool):
		m["isGroup"] = on
		if on:
			m["isBoss"] = false
			if _or(m.get("groupSize"), 0.0) == 0.0:
				m["groupSize"] = 2
		_render_sub.call_deferred(), L.t("admin.levels.ce_monstre_apparait_en_groupe"), bool(m.get("isBoss", false))))
	if bool(m.get("isGroup", false)):
		gh.add_child(_dd([[2, "2"], [3, "3"]], 3 if int(_or(m.get("groupSize"), 2.0)) == 3 else 2, func(v): m["groupSize"] = 3 if int(v) == 3 else 2, 0.65, 38, L.t("admin.levels.nombre_de_monstres_dans_le")))
	AdminTable.cell(g, gh)
	var hc := CenterContainer.new()
	hc.add_child(_chk(bool(m.get("startHidden", false)), func(on: bool): m["startHidden"] = on, L.t("admin.levels.cache_tant_qu_un_interrupteur")))
	AdminTable.cell(g, hc)
	AdminTable.cell(g, _tipped(_btn("🎯", func(): _start_placement("monster", mid), 0.8, false, Vector2(10, 10)), L.t("admin.levels.placer_sur_la_carte")))
	AdminTable.cell(g, _btn("🗑", func():
		(lvl.monsters as Array).erase(m)
		_render_sub.call_deferred(), 0.8, false, Vector2(10, 10)))

static func _add_monster(lvl: Dictionary) -> void:
	lvl.monsters.append({"id": "mon_%d" % Time.get_ticks_msec(), "name": L.t("admin.levels.nouveau_monstre"), "icon": "👹", "x": int(lvl.startX), "y": int(lvl.startY), "force": 8, "dex": 8, "con": 8, "resistPhys": 0, "resistMagic": 0, "xpReward": 10, "goldReward": 5, "abilitySpellId": "", "abilityChance": 30, "enrageThreshold": 0, "patrolRadius": 3, "attackSpeed": 2, "opensDoorId": "", "startHidden": false, "isBoss": false, "lootItemId": "", "lootChance": 100, "lootItemId2": "", "lootChance2": 100})
	_render_sub()

# ------------------------------------------------------------------ onglet Objets

## `clampItemStat` de l'original.
static func _clamp_item_stat(it: Dictionary, field: String, v: float) -> float:
	if ["heal", "trapDmgMin", "trapDmgMax"].has(field):
		return maxf(1.0, v)
	if (field == "bonusAtkMin" or field == "bonusAtkMax") and it.get("type") == "weapon":
		return maxf(1.0, v)
	if ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"].has(field):
		return clampf(v, 0.0, 100.0)
	if ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg"].has(field):
		return maxf(0.0, v)
	return v

static func _item_stat(it: Dictionary, field: String, shown: float, w: float, tip: String = "") -> LineEdit:
	var setter := func(v: float, _f: bool):
		it[field] = _store(_clamp_item_stat(it, field, v))
		return it[field]
	return _num(shown, w, setter, tip)

static func _stat_label(text: String, rem: float = 0.7, dim: bool = false) -> Label:
	return _lbl(text, rem, PARCH_DIM if dim else UiTheme.PARCH)

static func _boosts(row: Control, it: Dictionary) -> void:
	for x in [[L.t("common.for"), "bonusForce", L.t("common.bonus_force")], ["Dex", "bonusDex", L.t("common.bonus_dexterite")], ["Con", "bonusCon", L.t("common.bonus_constitution")], ["Int", "bonusInt", L.t("common.bonus_intelligence")], ["Vit", "bonusSpeed", L.t("common.bonus_vitesse_initiative")]]:
		row.add_child(_lbl(str(x[0]), 0.62))
		row.add_child(_item_stat(it, str(x[1]), _or(it.get(x[1]), 0.0), 26, str(x[2])))

## Encart « ✨ Légendaire » (filet pointillé, case, bonus + valeur en %).
static func _legendary(root: VBoxContainer, it: Dictionary) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	root.add_child(sp)
	root.add_child(DashLine.new())
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 6)
	root.add_child(sp2)
	root.add_child(_chk(bool(it.get("legendary", false)), func(on: bool):
		it["legendary"] = on
		_render_sub.call_deferred(), "", false, L.t("common.legendaire")))
	if bool(it.get("legendary", false)):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.add_child(_dd(PERKS, it.get("legendaryPerk", ""), func(v): it["legendaryPerk"] = v, 0.74))
		h.add_child(_num(_or(it.get("legendaryValue"), 15.0), 44, func(v: float, _f: bool):
			it["legendaryValue"] = _store(v)
			return it["legendaryValue"], L.t("common.valeur_du_bonus")))
		h.add_child(_stat_label("%"))
		root.add_child(h)

static func _classes_allowing(spell_id: String) -> Array:
	var out: Array = []
	for c in _cfg().get("classes", []):
		if AdminUtil.eff_spells(c).has(spell_id):
			out.append(str(c.get("name", "")))
	return out

## `itemDetailsHtml` : champs propres au type de l'objet.
static func _item_details(it: Dictionary, lvl: Dictionary) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	match str(it.get("type", "")):
		"potion":
			row.add_child(_item_stat(it, "heal", _or(it.get("heal"), 0.0), 44, L.t("common.soin")))
			row.add_child(_stat_label(L.t("common.pv")))
			row.add_child(_item_stat(it, "staminaRestore", _or(it.get("staminaRestore"), 0.0), 44, L.t("common.endurance")))
			row.add_child(_stat_label(L.t("common.end")))
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			row.add_child(_dd(wt, it.get("weaponType", ""), func(v): it["weaponType"] = v, 0.62, 52))
			row.add_child(_item_stat(it, "bonusAtkMin", _or(it.get("bonusAtkMin"), 0.0), 32, L.t("admin.levels.bonus_min")))
			row.add_child(_stat_label("-"))
			row.add_child(_item_stat(it, "bonusAtkMax", _or(it.get("bonusAtkMax"), 0.0), 32, L.t("admin.levels.bonus_max")))
			_boosts(row, it)
			_legendary(root, it)
		"armor":
			var slots: Array = []
			for s in Data.constants.get("SLOT_TYPES", []):
				if s.id != "weapon" and s.id != "accessory":
					slots.append([s.id, s.label])
			row.add_child(_dd(slots, it.get("slot", ""), func(v): it["slot"] = v, 0.74, 90))
			row.add_child(_item_stat(it, "bonusHp", _or(it.get("bonusHp"), 0.0), 30, L.t("common.bonus_pv_tank")))
			row.add_child(_stat_label(L.t("common.pv")))
			row.add_child(_item_stat(it, "bonusAtkMin", _or(it.get("bonusAtkMin"), 0.0), 28, L.t("common.bonus_attaque_min_guerrier_archer")))
			row.add_child(_stat_label("-"))
			row.add_child(_item_stat(it, "bonusAtkMax", _or(it.get("bonusAtkMax"), 0.0), 28, L.t("common.bonus_attaque_max")))
			row.add_child(_stat_label(L.t("common.atq")))
			row.add_child(_item_stat(it, "bonusSpellDmg", _or(it.get("bonusSpellDmg"), 0.0), 28, L.t("common.bonus_degats_de_sort_mage")))
			row.add_child(_stat_label(L.t("common.sort")))
			_boosts(row, it)
			_legendary(root, it)
		"jewelry":
			row.add_child(_item_stat(it, "bonusHp", _or(it.get("bonusHp"), 0.0), 30, L.t("common.bonus_pv")))
			row.add_child(_stat_label(L.t("common.pv")))
			row.add_child(_item_stat(it, "bonusAtkMin", _or(it.get("bonusAtkMin"), 0.0), 28, L.t("common.bonus_attaque_min")))
			row.add_child(_stat_label("-"))
			row.add_child(_item_stat(it, "bonusAtkMax", _or(it.get("bonusAtkMax"), 0.0), 28, L.t("common.bonus_attaque_max")))
			row.add_child(_stat_label(L.t("common.atq")))
			row.add_child(_item_stat(it, "bonusSpellDmg", _or(it.get("bonusSpellDmg"), 0.0), 28, L.t("common.bonus_degats_de_sort")))
			row.add_child(_stat_label(L.t("common.sort")))
			_boosts(row, it)
			_legendary(root, it)
		"key":
			row.add_child(_dd(_door_options(lvl), it.get("opensDoorId", ""), func(v): it["opensDoorId"] = v, 0.74, 100))
		"trap":
			row.add_child(_item_stat(it, "trapDmgMin", _or(it.get("trapDmgMin"), 1.0), 34, L.t("common.degats_min")))
			row.add_child(_stat_label("-"))
			row.add_child(_item_stat(it, "trapDmgMax", _or(it.get("trapDmgMax"), 4.0), 34, L.t("common.degats_max")))
			var pc := _chk(bool(it.get("permanent", false)), func(on: bool): it["permanent"] = on, "", false, "Permanent")
			row.add_child(pc)
		"switch":
			var doors: Array = [["", L.t("admin.levels.porte_aucune")]]
			for d in lvl.get("doors", []):
				doors.append([d.id, L.fa(L.t("admin.levels.porte_2"), [int(d.x), int(d.y)])])
			var mons: Array = [["", L.t("admin.levels.monstre_aucun")]]
			for m in lvl.monsters:
				mons.append([m.id, "👹 %s %s" % [AdminUtil.icon_text_fallback(str(m.get("icon", ""))), m.get("name", "")]])
			var its: Array = [["", L.t("admin.levels.objet_aucun")]]
			for o in lvl.items:
				if o.id != it.id:
					its.append([o.id, "💎 %s %s" % [AdminUtil.icon_text_fallback(str(o.get("icon", ""))), o.get("name", "")]])
			row.add_child(_dd(doors, it.get("switchOpensDoorId", ""), func(v): it["switchOpensDoorId"] = v, 0.74))
			row.add_child(_dd(mons, it.get("switchRevealMonsterId", ""), func(v): it["switchRevealMonsterId"] = v, 0.74))
			row.add_child(_dd(its, it.get("switchRevealItemId", ""), func(v): it["switchRevealItemId"] = v, 0.74))
			row.add_child(_text(it, "message", 180, 0.74, Vector2(5, 5), L.t("common.message_affiche")))
		"fountain":
			var h := _lbl(L.t("admin.levels.restaure_pv_endurance_du_groupe"), 0.74, PARCH_DIM, true)
			row.add_child(h)
		"scroll":
			var so: Array = []
			for s in _cfg().get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			if so.is_empty():
				so.append(["", L.t("common.aucun_sort_defini_2")])
			var hint := _lbl("", 0.74, PARCH_DIM, true)
			var upd := func():
				var sid := str(it.get("spellId", ""))
				if sid == "":
					hint.text = "—"
				else:
					var names := _classes_allowing(sid)
					hint.text = ", ".join(names) if not names.is_empty() else L.t("admin.levels.aucune_classe")
			row.add_child(_dd(so, it.get("spellId", ""), func(v):
				it["spellId"] = v
				upd.call(), 0.74, 150))
			upd.call()
			row.add_child(hint)
		_:
			row.add_child(_lbl("—", 0.7))
	return root

static func _items_sub(host: VBoxContainer, lvl: Dictionary) -> void:
	var headers := [L.t("common.icone"), L.t("common.nom"), L.t("common.type"), L.t("admin.levels.position"), L.t("common.details"), L.t("admin.levels.cache"), "", ""]
	var widths := [38, 75, 78, 40, 0, 15, 0, 0]
	var g := AdminTable.create(host, headers, widths)
	for it in lvl.items:
		if str(it.get("type", "")) != "decor":
			_item_row(g, lvl, it)
	var ab := Form.buttons(host, [[L.t("common.ajouter_un_objet"), func(): _add_item(lvl)]])
	ab.get_child(0).add_theme_font_size_override("font_size", _fs(0.8))

static func _item_row(g: GridContainer, lvl: Dictionary, it: Dictionary) -> void:
	var iid := str(it.id)
	AdminTable.cell(g, _icon_btn(IconPicker.button(_admin.modals(), it, "icon", Callable(), 26.0)))
	AdminTable.cell(g, _text(it, "name", 75, 0.68, Vector2(3, 2)))
	AdminTable.cell(g, _dd(ITEM_TYPES, it.get("type", ""), func(v):
		it["type"] = v
		_render_sub.call_deferred(), 0.65, 78))
	AdminTable.text_cell(g, "%d,%d" % [int(it.x), int(it.y)], false, 0.72)
	AdminTable.cell(g, _item_details(it, lvl))
	var hc := CenterContainer.new()
	hc.add_child(_chk(bool(it.get("startHidden", false)), func(on: bool): it["startHidden"] = on, L.t("admin.levels.cache_tant_qu_un_interrupteur_2")))
	AdminTable.cell(g, hc)
	AdminTable.cell(g, _tipped(_btn("🎯", func(): _start_placement("item", iid), 0.8, false, Vector2(10, 10)), L.t("admin.levels.placer_sur_la_carte")))
	AdminTable.cell(g, _btn("🗑", func():
		_remove_item(lvl, iid)
		_render_sub.call_deferred(), 0.8, false, Vector2(10, 10)))

static func _add_item(lvl: Dictionary) -> void:
	lvl.items.append({"id": "item_%d" % Time.get_ticks_msec(), "name": L.t("common.nouvel_objet"), "icon": "💎", "x": int(lvl.startX), "y": int(lvl.startY), "type": "potion", "startHidden": false})
	_render_sub()

# ------------------------------------------------------------------ onglet Réglages

static func _light_slider(ep: Control, label: String, lvl: Dictionary, key: String, lo: float, hi: float, def: float) -> void:
	var r := _frow(ep, label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	var cur: float = float(lvl[key]) if lvl.get(key) != null else def
	s.value = cur
	s.custom_minimum_size = Vector2(_px(160), 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := _lbl("%.2f" % cur, 0.74, PARCH_DIM, true)
	v.custom_minimum_size.x = _px(34)
	s.value_changed.connect(func(x: float):
		var q := snappedf(x, 0.05)
		lvl[key] = q
		v.text = "%.2f" % q)
	r.add_child(s)
	r.add_child(v)

static func _cfg_sub(ep: VBoxContainer, lvl: Dictionary) -> void:
	var tr_ := _frow(ep, L.t("admin.levels.theme_visuel"))
	tr_.add_child(_dd(THEMES, lvl.get("theme", "stone"), func(v): lvl["theme"] = v, 0.85, 0))
	_light_slider(ep, L.t("admin.levels.lumiere_ambiante"), lvl, "lightAmbient", 0.1, 1.6, 1.1)
	_light_slider(ep, L.t("admin.levels.intensite_des_torches"), lvl, "lightTorch", 0.2, 2.6, 1.4)
	for spec in [[L.t("admin.levels.position_de_depart"), "startX"], [L.t("admin.levels.position_de_depart_y"), "startY"]]:
		var key: String = spec[1]
		var r := _frow(ep, str(spec[0]))
		var e := _num(lvl.get(key, 0), 70, func(v: float, _f: bool):
			lvl[key] = _store(v)
			return lvl[key], "", 0.85)
		_style_edit(e, 0.85, Vector2(9, 7))
		e.custom_minimum_size.x = _px(70)
		r.add_child(e)
	var rd := _frow(ep, L.t("admin.levels.direction_de_depart"))
	rd.add_child(_dd(DIRS, int(lvl.get("startDir", 1)), func(v): lvl["startDir"] = int(v), 0.85))
	_actions(ep, [
		[L.t("admin.levels.choisir_le_depart_sur_la"), func(): _start_placement("start")],
		[L.t("admin.levels.teleporter_le_groupe_ici_tests"), func(): _pick_teleport()],
		[L.t("admin.levels.teleporter_au_village_tests"), func(): _go_village()]], 0.0, 14.0)
	ep.add_child(_lbl(L.t("admin.levels.escaliers_de_ce_niveau"), 1.0, UiTheme.PARCH))
	_stairs_box = VBoxContainer.new()
	_stairs_box.add_theme_constant_override("separation", 12)
	ep.add_child(_stairs_box)
	_render_stairs(lvl)
	var h := Form.hint(ep, L.t("admin.levels.peignez_sur_la_carte_onglet"), _fs(0.74))
	ep.add_child(_lbl(L.t("common.marchand_ambulant"), 1.0, UiTheme.PARCH))
	_merchant_box = VBoxContainer.new()
	_merchant_box.add_theme_constant_override("separation", 4)
	ep.add_child(_merchant_box)
	_render_merchant(lvl)

static func _pick_teleport() -> void:
	if not _has_run():
		_alert(L.t("common.aucune_partie_en_cours_lancez"))
		return
	_start_placement("teleport")

static func _go_village() -> void:
	var err: String = _teleport_village()
	if err != "":
		_alert(err)

# ---- escaliers

static func _card_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(1, 1, 1, 0.02)
	b.border_color = BORDER
	b.set_border_width_all(1)
	b.set_corner_radius_all(8)
	b.content_margin_left = _px(10)
	b.content_margin_right = _px(10)
	b.content_margin_top = _px(8)
	b.content_margin_bottom = _px(8)
	return b

static func _render_stairs(lvl: Dictionary) -> void:
	if _stairs_box == null or not is_instance_valid(_stairs_box):
		return
	_clear(_stairs_box)
	_ensure_stairs(lvl)
	var stairs: Array = lvl.stairs
	if stairs.is_empty():
		_stairs_box.add_child(_lbl(L.t("admin.levels.aucun_escalier_sur_ce_niveau"), 0.74, PARCH_DIM, true))
		return
	var others: Array = []
	for l in _levels():
		if l.id != lvl.id:
			others.append([l.id, str(l.get("name", ""))])
	for st in stairs:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_box())
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		var hd := HBoxContainer.new()
		hd.add_theme_constant_override("separation", 8)
		hd.add_child(_lbl("✨", 1.2, UiTheme.PARCH))
		var tl := _lbl(L.fa(L.t("admin.levels.escalier_en"), [int(st.x), int(st.y)]), 0.8, UiTheme.PARCH)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(tl)
		v.add_child(hd)
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 6)
		v.add_child(sp)
		var act: Dictionary = st.get("action", {})
		if not (st.get("action") is Dictionary):
			st["action"] = act
		var ra := _frow(v, "Action")
		ra.add_child(_dd([["victory", L.t("admin.levels.terminer_la_partie_victoire")], ["level", L.t("admin.levels.aller_vers_un_autre_niveau")]], act.get("type", "victory"), func(val):
			if val == "victory":
				st["action"] = {"type": "victory"}
			else:
				st["action"] = {"type": "level", "targetId": others[0][0] if not others.is_empty() else null}
			_render_stairs.call_deferred(lvl), 0.85))
		if act.get("type") == "level":
			var target := _level_by_id(act.get("targetId"))
			var rt := _frow(v, L.t("admin.levels.niveau_cible"))
			rt.add_child(_dd(others, act.get("targetId", ""), func(val):
				act["targetId"] = val
				_render_stairs.call_deferred(lvl), 0.85))
			var rx := _frow(v, L.t("admin.levels.arrivee"))
			rx.add_child(_raw_num(act, "targetX", 60, _fmt(target.get("startX", 0)) if not target.is_empty() else "0"))
			var ylab := _lbl("Y", 0.75)
			ylab.custom_minimum_size.x = _px(20)
			rx.add_child(ylab)
			rx.add_child(_raw_num(act, "targetY", 60, _fmt(target.get("startY", 0)) if not target.is_empty() else "0"))
			var rdir := _frow(v, L.t("admin.levels.direction_arrivee"))
			var dir_opts: Array = [["", L.t("admin.levels.par_defaut_du_niveau")]]
			for d in DIRS:
				dir_opts.append([str(d[0]), d[1]])
			var cur_dir := ""
			if act.has("targetDir") and str(act.targetDir) != "":
				cur_dir = str(int(_parse(str(act.targetDir))))
			rdir.add_child(_dd(dir_opts, cur_dir, func(val): act["targetDir"] = val, 0.85))
			var hint := L.fa(L.t("admin.levels.laissez_y_vides_pour_arriver"), (str(target.get("name", "")) if not target.is_empty() else L.t("admin.levels.ce_niveau")))
			Form.hint(v, hint, _fs(0.74))
		_stairs_box.add_child(card)

## Champ numérique conservant le texte tel quel (« Arrivée X / Y » : l'original stocke la valeur saisie, vide = départ du niveau).
static func _raw_num(target: Dictionary, key: String, w: float, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = str(target[key]) if target.has(key) and target[key] != null else ""
	e.placeholder_text = placeholder
	e.custom_minimum_size.x = _px(w)
	e.context_menu_enabled = false
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_style_edit(e, 0.85, Vector2(9, 7))
	var ok := RegEx.create_from_string("^[0-9eE.+\\-]*$")
	var last := [e.text]
	e.text_changed.connect(func(t: String):
		if ok.search(t) == null:
			var c := e.caret_column - 1
			e.text = last[0]
			e.caret_column = clampi(c, 0, e.text.length())
			return
		last[0] = t
		var s := t.strip_edges()
		target[key] = s if (s == "" or s.is_valid_float()) else "")
	return e

# ---- marchand ambulant

static func _render_merchant(lvl: Dictionary) -> void:
	if _merchant_box == null or not is_instance_valid(_merchant_box):
		return
	_clear(_merchant_box)
	var box := _merchant_box
	var tm = lvl.get("travelingMerchant")
	if not (tm is Dictionary):
		Form.hint(box, L.t("admin.levels.aucun_marchand_sur_ce_niveau"), _fs(0.74))
		_actions(box, [[L.t("admin.levels.ajouter_un_marchand_ambulant"), func():
			lvl["travelingMerchant"] = {"x": int(lvl.startX), "y": int(lvl.startY), "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			_render_merchant(lvl)]], 0.0)
		return
	var count := 8 if int(_or(tm.get("lootSlotCount"), 6.0)) == 8 else 6
	if not (tm.get("lootItemIds") is Array):
		tm["lootItemIds"] = []
	var ids: Array = tm.lootItemIds
	var rp := _frow(box, L.t("admin.levels.position"))
	rp.add_child(_lbl("%d, %d" % [int(tm.x), int(tm.y)], 1.0, UiTheme.PARCH))
	rp.add_child(_tipped(_btn("🎯", func(): _start_placement("merchant"), 0.8, false, Vector2(10, 10)), L.t("admin.levels.placer_sur_la_carte")))
	var rr := _frow(box, L.t("admin.levels.rayon_de_patrouille"))
	var e := _num(_or(tm.get("patrolRadius"), 4.0), 60, func(v: float, _f: bool):
		tm["patrolRadius"] = _store(maxf(0.0, v))
		return tm["patrolRadius"], "", 0.85)
	_style_edit(e, 0.85, Vector2(9, 7))
	e.custom_minimum_size.x = _px(60)
	rr.add_child(e)
	var rc := _frow(box, L.t("admin.levels.nombre_objets_en_vente"))
	rc.add_child(_dd([[6, "6"], [8, "8"]], count, func(v):
		tm["lootSlotCount"] = 8 if int(v) == 8 else 6
		_render_merchant.call_deferred(lvl), 0.85))
	Form.hint(box, L.t("admin.levels.emplacements_laisses_vides_le"), _fs(0.74))
	var lib: Array = [["", L.t("admin.levels.vide")]]
	for it in _cfg().get("itemLibrary", []):
		lib.append([it.id, str(it.get("name", ""))])
	for i in count:
		var slot := i
		var rs := _frow(box, L.fa(L.t("common.emplacement"), (i + 1)))
		var cur := str(ids[slot]) if slot < ids.size() and ids[slot] != null else ""
		rs.add_child(_dd(lib, cur, func(v):
			while ids.size() <= slot:
				ids.append("")
			ids[slot] = v, 0.85))
	_actions(box, [[L.t("admin.levels.retirer_le_marchand_de_ce"), func():
		lvl["travelingMerchant"] = null
		_render_merchant(lvl)]], 10.0)
