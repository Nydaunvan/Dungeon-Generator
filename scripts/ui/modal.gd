class_name Modal
extends Control
## Fenêtre modale habillée (fond assombri + panneau de bronze). Corps défilant + rangée de boutons fixe.

signal closed

var panel: OrnatePanel
var content: VBoxContainer
var _scroll: ScrollContainer
var _buttons_row: BoxContainer
var _width: float = 380.0
## Échap ferme la fenêtre (sauf choix obligatoire : talent, évolution, piège, victoire…).
var esc_closes: bool = true

static func open(host: Node, title: String, width: float = 380.0) -> Modal:
	var m := Modal.new()
	m._width = width
	m._build(title)
	host.add_child(m)
	return m

## Variante « .slots-box » : titre à gauche, croix carrée à droite, liste paddée.
static func open_framed(host: Node, title: String, width: float = 560.0) -> Modal:
	var m := Modal.new()
	m._width = width
	m._framed_title = title
	m._build("")
	host.add_child(m)
	return m

var _framed_title: String = ""

func _build(title: String) -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.shared()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = OrnatePanel.new(title, _framed_title == "")
	if _framed_title != "":
		panel.use_framed_header(_framed_title, close)
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	panel.custom_minimum_size = Vector2(minf(_width, vp.x - 24.0), 0)
	center.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.body.add_child(_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_scroll.add_child(content)
	_buttons_row = VBoxContainer.new()
	panel.body.add_child(_buttons_row)
	call_deferred("_fit")
	call_deferred("_animate_in")

func _input(event: InputEvent) -> void:
	if not esc_closes or is_queued_for_deletion() or not event.is_action_pressed("ui_cancel"):
		return
	var top: Node = null
	for n in get_tree().get_nodes_in_group("modal"):
		if not n.is_queued_for_deletion():
			top = n
	if top == self:
		get_viewport().set_input_as_handled()
		close()

func _animate_in() -> void:
	UiFx.pop_in(panel, 0.18)

func _fit() -> void:
	var vp := get_viewport_rect().size
	var want := content.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(0, minf(want, vp.y * 0.66))
	panel.custom_minimum_size.x = minf(_width, vp.x - 24.0)

func add_text(text: String, color: Color = UiTheme.PARCH, size: int = 16, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(minf(_width, get_viewport_rect().size.x - 24.0) - 100.0, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if italic:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	content.add_child(l)
	call_deferred("_fit")
	return l

## Ligne icône + texte.
func add_row(icon: Texture2D, text: String, color: Color = UiTheme.PARCH) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon != null:
		var t := TextureRect.new()
		t.texture = icon
		t.custom_minimum_size = Vector2(36, 36)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(t)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	h.add_child(l)
	content.add_child(h)
	call_deferred("_fit")
	return h

## Boutons du bas : [{"text", "cb", "disabled", "primary"}]. `cb` est un Callable (sans argument).
## Par défaut en colonne pleine largeur (2 ou 3 boutons), comme `.modal-actions` de l'original ; `row` force une rangée.
func set_buttons(specs: Array, row: bool = false) -> void:
	var as_row := row or specs.size() > 3
	var parent := _buttons_row.get_parent()
	var idx := _buttons_row.get_index()
	_buttons_row.queue_free()
	_buttons_row = HBoxContainer.new() if as_row else VBoxContainer.new()
	_buttons_row.add_theme_constant_override("separation", int(UiMetrics.css(10.0)) if not as_row else int(UiMetrics.css(10.0)))
	parent.add_child(_buttons_row)
	parent.move_child(_buttons_row, idx)
	var first := true
	for sp in specs:
		var b := Button.new()
		b.text = str(sp.get("text", ""))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = bool(sp.get("disabled", false))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiMetrics.css(40.0))
		var primary: bool = bool(sp.get("primary", first and specs.size() > 1))
		first = false
		var st := IronBox.modal_styles(primary)
		for k in st:
			b.add_theme_stylebox_override(k, st[k])
		b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.9)))
		b.add_theme_color_override("font_color", Color("ffd88a") if primary else Color("e2d2b0"))
		b.add_theme_color_override("font_hover_color", Color("fff0c8") if primary else Color("f4e6c6"))
		b.add_theme_color_override("font_disabled_color", Color("7a6a50"))
		var cb: Callable = sp.get("cb", Callable())
		b.pressed.connect(func():
			if cb.is_valid():
				cb.call())
		_buttons_row.add_child(b)
	call_deferred("_fit")

## Bouton dans le corps (liste d'actions).
func add_button(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.pressed.connect(func(): cb.call())
	content.add_child(b)
	call_deferred("_fit")
	return b

func close() -> void:
	closed.emit()
	queue_free()
