class_name SaveMenu
extends Button
## Menu « 💾 Sauvegarde ▾ » de la colonne de droite (`.save-menu-trigger` + `#saveMenuDropdown` de l'original) : la liste déroulante
## s'ouvre au-dessus du bouton avec « Emplacements de sauvegarde », « Nouveau », « Exporter », « Importer », l'état
## « Sauvegardé à HH:MM:SS » et le texte d'aide. Inaccessible en combat (`locked`) : le panneau est grisé et inerte.

signal slots_pressed
signal new_pressed
signal export_pressed
signal import_pressed

const HELP := "ui.save_menu.3_emplacements_disponibles_pour"

var _layer: CanvasLayer
var _catcher: Control
var _dd: PanelContainer
var _status: Label
var locked: bool = false:
	set(v):
		locked = v
		if v:
			_close()

func _init() -> void:
	text = L.t("ui.save_menu.sauvegarde")
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, UiMetrics.css(44.0))
	add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	add_theme_color_override("font_color", Color("e2d2b0"))
	add_theme_color_override("font_hover_color", Color("ffd88a"))
	var sst := IronBox.button_styles()
	for k in sst:
		var ib: IronBox = sst[k]
		ib.rivets = false
		ib.radius_css = 3.0
		add_theme_stylebox_override(k, ib)
	var arrow := Label.new()
	arrow.text = "▼"
	arrow.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
	arrow.add_theme_color_override("font_color", Color("b9a880"))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	arrow.offset_right = -UiMetrics.css(14.0)
	arrow.offset_left = -UiMetrics.css(30.0)
	add_child(arrow)
	pressed.connect(_toggle)
	_build()

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 18
	_layer.visible = false
	add_child(_layer)
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close())
	_layer.add_child(_catcher)
	_dd = PanelContainer.new()
	_dd.theme = UiTheme.shared()
	_dd.add_theme_stylebox_override("panel", FrameBox.new(14.0, Vector4(6, 6, 6, 6)))
	_layer.add_child(_dd)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
	_dd.add_child(v)
	v.add_child(_item(L.t("common.emplacements_de_sauvegarde"), slots_pressed))
	v.add_child(_item(L.t("ui.save_menu.nouveau"), new_pressed))
	var hr := ColorRect.new()
	hr.color = Color("070504")
	hr.custom_minimum_size = Vector2(0, 2)
	var hr_box := MarginContainer.new()
	hr_box.add_theme_constant_override("margin_top", int(UiMetrics.css(2.0)))
	hr_box.add_theme_constant_override("margin_bottom", int(UiMetrics.css(2.0)))
	hr_box.add_child(hr)
	v.add_child(hr_box)
	v.add_child(_item(L.t("ui.save_menu.exporter"), export_pressed))
	v.add_child(_item(L.t("ui.save_menu.importer"), import_pressed))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, UiMetrics.rem(0.7) * 1.5)
	_status.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
	_status.add_theme_color_override("font_color", Color("7a6a52"))
	v.add_child(_status)
	var help := Label.new()
	help.text = HELP
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(UiMetrics.css(180.0), 0)
	help.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	help.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.74)))
	help.add_theme_color_override("font_color", Color("b8a781"))
	v.add_child(help)

func _item(label: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("36291a") if st != "hover" else Color("473521")
		sb.border_color = Color("6a5432") if st != "hover" else Color("a9793a")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = UiMetrics.css(9.0)
		sb.content_margin_right = UiMetrics.css(9.0)
		sb.content_margin_top = UiMetrics.css(10.0)
		sb.content_margin_bottom = UiMetrics.css(10.0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	b.pressed.connect(func():
		_close()
		sig.emit())
	return b

## État affiché sous les boutons (« Sauvegardé à 21:11:00 »).
func set_status(msg: String) -> void:
	_status.text = msg

func _toggle() -> void:
	if locked:
		return
	if _layer.visible:
		_close()
	else:
		_open()

func _open() -> void:
	_layer.visible = true
	_dd.modulate.a = 0.0
	var r := get_global_rect()
	_dd.custom_minimum_size = Vector2(r.size.x, 0)
	_dd.size = Vector2(r.size.x, 0)
	await get_tree().process_frame
	_dd.size = Vector2(r.size.x, _dd.get_combined_minimum_size().y)
	_dd.position = Vector2(r.position.x, r.position.y - _dd.size.y - UiMetrics.css(6.0))
	_dd.modulate.a = 1.0

func _close() -> void:
	if _layer != null:
		_layer.visible = false

func _input(event: InputEvent) -> void:
	if _layer != null and _layer.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
