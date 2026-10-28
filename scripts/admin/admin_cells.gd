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

## Filet pointillé (séparateur de la ligne « Légendaire »).
class DashLine extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_dashed_line(Vector2(0, 0.5), Vector2(size.x, 0.5), AdminCells.BORDER, 1.0, 3.0)
