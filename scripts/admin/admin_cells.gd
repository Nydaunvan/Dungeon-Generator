class_name AdminCells
extends RefCounted
## Contrôles compacts des tableaux « .data-table » de l'original (input/select 0,74 rem, fond #150f08, filet #5a4526) :
## champ numérique à la manière de `<input type="number">` (la valeur saisie est validée à la sortie du champ ou sur Entrée,
## les flèches haut/bas la font varier de 1 dans les bornes `min`/`max` de l'attribut HTML), listes déroulantes sombres,
## boutons d'action, séparateur pointillé.

const FIELD_BG := Color("150f08")
const BORDER := Color("5a4526")
const GOLD_DIM := Color("a9793a")

static func field_box(focus: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FIELD_BG
	s.border_color = GOLD_DIM if focus else BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func font_px() -> int:
	return int(UiMetrics.rem(0.74))

static func _style_edit(e: LineEdit) -> void:
	e.add_theme_stylebox_override("normal", field_box())
	e.add_theme_stylebox_override("focus", field_box(true))
	e.add_theme_stylebox_override("read_only", field_box())
	e.add_theme_font_size_override("font_size", font_px())
	e.add_theme_constant_override("minimum_character_width", 1)
	e.focus_mode = Control.FOCUS_CLICK
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## Champ texte de tableau (le nom est enregistré à chaque frappe).
static func text(target: Dictionary, key: String, tip: String = "", on_change: Callable = Callable(), min_w: float = 90.0) -> LineEdit:
	var e := LineEdit.new()
	_style_edit(e)
	e.text = str(target.get(key, ""))
	e.tooltip_text = tip
	e.custom_minimum_size.x = UiMetrics.css(min_w)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String):
		target[key] = t
		if on_change.is_valid():
			on_change.call())
	return e

## Texte d'un nombre comme l'affiche un champ numérique (entier sans « .0 »).
static func fmt(v: float) -> String:
	if is_equal_approx(v, round(v)) and absf(v) < 1e15:
		return str(int(round(v)))
	return str(v)

## Valeur stockée : entier si le nombre est entier (le JSON reste propre), sinon flottant (décimales acceptées comme le HTML).
static func num_value(v: float) -> Variant:
	if is_equal_approx(v, round(v)) and absf(v) < 1e15:
		return int(round(v))
	return v

## `Number(this.value)` d'un champ numérique : texte vide ou invalide -> 0.
static func parse(t: String) -> float:
	var s := t.strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0

## Champ numérique : `target[key]` reçoit la valeur validée.
## Options : w (largeur CSS, au moins 42 comme `.data-table input`), tip, lo/hi (bornes des flèches, comme min/max HTML),
## or (true : `valeur||défaut`, un 0 mémorisé s'affiche comme le défaut), fix (Callable v -> v : bornage à l'édition),
## echo (true : la valeur bornée est renvoyée dans le champ), after (Callable appelé après l'enregistrement).
static func num(target: Dictionary, key: String, default_value: float, o: Dictionary = {}) -> LineEdit:
	var e := LineEdit.new()
	_style_edit(e)
	e.custom_minimum_size.x = UiMetrics.css(maxf(float(o.get("w", 42.0)), 42.0))
	e.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	e.tooltip_text = str(o.get("tip", ""))
	var cur = target.get(key, default_value)
	if not (cur is int or cur is float):
		cur = default_value
	if bool(o.get("or", false)) and float(cur) == 0.0:
		cur = default_value
	e.text = fmt(float(cur))
	var lo: float = float(o.get("lo", -INF))
	var hi: float = float(o.get("hi", INF))
	var fix: Callable = o.get("fix", Callable())
	var after: Callable = o.get("after", Callable())
	var echo: bool = bool(o.get("echo", false))
	var last := [e.text]
	var commit := func(t: String):
		var v := parse(t)
		if fix.is_valid():
			v = float(fix.call(v))
		target[key] = num_value(v)
		last[0] = t
		if echo:
			e.text = fmt(v)
			last[0] = e.text
		if after.is_valid():
			after.call()
	e.text_submitted.connect(func(t: String): commit.call(t))
	e.focus_exited.connect(func():
		if e.text != last[0]:
			commit.call(e.text))
	e.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventKey and ev.pressed and (ev.keycode == KEY_UP or ev.keycode == KEY_DOWN):
			var v := parse(e.text) + (1.0 if ev.keycode == KEY_UP else -1.0)
			v = clampf(v, lo, hi)
			e.text = fmt(v)
			commit.call(e.text)
			e.accept_event())
	return e

## Liste déroulante sombre de tableau ; `options` = [[valeur, libellé], …] ; si la valeur courante est absente, la première
## option est affichée (comme un `<select>` sans option sélectionnée), sans rien écrire.
static func option(options: Array, current, on_pick: Callable, width: float = 0.0, tip: String = "", size_rem: float = 0.74) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.tooltip_text = tip
	o.fit_to_longest_item = false
	o.clip_text = true
	o.alignment = HORIZONTAL_ALIGNMENT_LEFT
	o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		o.add_theme_stylebox_override(st, field_box(st == "hover"))
	o.add_theme_font_size_override("font_size", int(UiMetrics.rem(size_rem)))
	o.add_theme_color_override("font_color", UiTheme.PARCH)
	o.add_theme_color_override("font_hover_color", UiTheme.PARCH)
	o.add_theme_color_override("font_pressed_color", UiTheme.PARCH)
	o.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	if width > 0.0:
		o.custom_minimum_size.x = UiMetrics.css(width)
	var sel := 0
	for i in options.size():
		o.add_item(str(options[i][1]))
		if str(options[i][0]) == str(current):
			sel = i
	if options.size() > 0:
		o.select(sel)
	var pm := o.get_popup()
	pm.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	o.item_selected.connect(func(i: int): on_pick.call(options[i][0]))
	return o

## Case à cocher de tableau (libellé 0,65–0,72 rem, infobulle sur toute l'étiquette).
static func check(label: String, on: bool, on_toggle: Callable, size_rem: float = 0.72, tip: String = "") -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.tooltip_text = tip
	c.add_theme_font_size_override("font_size", int(UiMetrics.rem(size_rem)))
	c.add_theme_constant_override("h_separation", 5)
	c.toggled.connect(func(v: bool): on_toggle.call(v))
	return c

## Petit texte en ligne (« PV soin », « End. », « - »).
static func inline(text: String, dim: bool = false, size_rem: float = 0.74, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(size_rem)))
	l.add_theme_color_override("font_color", UiTheme.DIM if dim else UiTheme.PARCH)
	if italic:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

## Bouton 🗑 de fin de ligne.
static func trash(on_press: Callable) -> Button:
	var b := Button.new()
	b.text = "🗑"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiMetrics.css(34.0), UiMetrics.css(38.0))
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	b.pressed.connect(func(): on_press.call())
	return b

## Rangée « .admin-actions » : boutons côte à côte (espacement 8, 14 px au-dessus) ; `primary` = texte doré clair.
static func actions(parent: Control, specs: Array) -> HFlowContainer:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, UiMetrics.css(10.0))
	parent.add_child(sp)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(UiMetrics.css(8.0)))
	h.add_theme_constant_override("v_separation", int(UiMetrics.css(8.0)))
	for s in specs:
		var b := Button.new()
		b.text = str(s.get("text", ""))
		b.focus_mode = Control.FOCUS_NONE
		if bool(s.get("primary", false)):
			b.add_theme_color_override("font_color", Color("ffd88a"))
			b.add_theme_color_override("font_hover_color", Color("fff0c8"))
		b.pressed.connect(s.get("cb"))
		h.add_child(b)
	parent.add_child(h)
	return h

## `.save-status` : petit texte gris sous les boutons (0,7 rem, #7a6a52, hauteur mini 1 em).
static func status_label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
	l.add_theme_color_override("font_color", Color("7a6a52"))
	l.custom_minimum_size.y = UiMetrics.rem(0.7) * 1.4
	parent.add_child(l)
	return l

## Filet pointillé (séparateur de la ligne « Légendaire »).
class DashLine extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_dashed_line(Vector2(0, 0.5), Vector2(size.x, 0.5), AdminCells.BORDER, 1.0, 3.0)

static func dash_line(parent: Control) -> Control:
	var d := DashLine.new()
	parent.add_child(d)
	return d

## En-têtes de tableau : retour à la ligne comme les `<th>` HTML (le texte passe sur deux lignes quand la colonne est étroite).
static func wrap_headers(grid: GridContainer, n: int) -> void:
	for i in n:
		var l := grid.get_child(i) as Label
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_vertical = Control.SIZE_SHRINK_END
