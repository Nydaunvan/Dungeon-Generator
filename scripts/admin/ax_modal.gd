class_name AxModal
extends Control
## Fenêtre de l'atelier (maquette « Groupe », sélecteur de portraits) : voile sombre, panneau #16100a bordé #5a4526 (rayon 18, ombre),
## en-tête (titre Cinzel + information à droite), corps, boutons « Annuler / Valider » en pied.

signal closed

var body: VBoxContainer
var _foot: HBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer

static func open(host: Node, title_text: String, info: String = "", width: float = 420.0, scroll_h: float = 0.0) -> AxModal:
	var m := AxModal.new()
	host.add_child(m)
	m._build(title_text, info, width, scroll_h)
	return m

func _build(title_text: String, info: String, width: float, scroll_h: float) -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = Ax.panel(Color("16100a"), Ax.LINE3, 18, 0, 0)
	var st := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	st.shadow_color = Color(0, 0, 0, 0.75)
	st.shadow_size = 40
	st.set_content_margin_all(0)
	_panel.clip_contents = true
	_panel.custom_minimum_size.x = minf(width, get_viewport_rect().size.x - 24.0)
	center.add_child(_panel)
	var col := Ax.vbox(0)
	_panel.add_child(col)
	var head := Ax.hbox(10)
	var t := Ax.title(title_text, 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if info != "":
		head.add_child(Ax.lab(info, 12, Ax.MUTED))
	col.add_child(Ax.margin(head, 18, 14, 18, 14))
	col.add_child(Ax.line())
	body = Ax.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scroll_h > 0.0:
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.custom_minimum_size.y = minf(scroll_h, get_viewport_rect().size.y * 0.6)
		_scroll.add_child(Ax.margin(body, 18, 16, 18, 16))
		col.add_child(_scroll)
	else:
		col.add_child(Ax.margin(body, 18, 16, 18, 16))
	_foot = Ax.hbox(10)
	col.add_child(Ax.margin(_foot, 18, 0, 18, 16))

## Boutons du pied : [{"text", "cb", "primary"}] ; chacun ferme la fenêtre après son rappel sauf si `keep`.
func set_buttons(items: Array) -> void:
	for ch in _foot.get_children():
		ch.queue_free()
	for it in items:
		var cb: Callable = it.get("cb", Callable())
		var keep: bool = bool(it.get("keep", false))
		var b := Ax.btn(str(it.text), func():
			if cb.is_valid():
				cb.call()
			if not keep:
				close(), "primary" if bool(it.get("primary", false)) else "ghost", 40.0, 16, 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_foot.add_child(b)

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
