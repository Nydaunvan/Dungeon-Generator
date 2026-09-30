class_name OrnatePanel
extends PanelContainer
## Panneau « .panel » de l'original : cadre fer riveté (border-image), fond sombre grisé de saleté,
## titre h3 en capitales espacées, et — dans la colonne de droite du jeu — médaillon crâne + crochets.

var body: VBoxContainer
var title_label: Label
var header_row: HBoxContainer
var medal: bool = false:
	set(v):
		medal = v
		queue_redraw()
var hooks: bool = false:
	set(v):
		hooks = v
		queue_redraw()
var _box: FrameBox
var _v: VBoxContainer

func _init(title: String = "", modal: bool = false) -> void:
	_box = FrameBox.new(18.0, Vector4(24, 22, 24, 22) if modal else Vector4(12, 10, 12, 10))
	add_theme_stylebox_override("panel", _box)
	clip_contents = false
	var v := VBoxContainer.new()
	_v = v
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	if title != "":
		header_row = HBoxContainer.new()
		header_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(header_row)
		title_label = Label.new()
		title_label.text = title if modal else title.to_upper()
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var fv := FontVariation.new()
		fv.base_font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		fv.spacing_glyph = 0 if modal else 2
		title_label.add_theme_font_override("font", fv)
		title_label.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.15)) if modal else 13)
		title_label.add_theme_color_override("font_color", Color("ffd88a") if modal else Color("d9b56e"))
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if modal else TextServer.AUTOWRAP_OFF
		title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		title_label.add_theme_constant_override("outline_size", 2)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(title_label)
		var sep := ColorRect.new()
		sep.color = Color("070504")
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
		var hi := ColorRect.new()
		hi.color = Color(1, 0.9, 0.75, 0.08)
		hi.custom_minimum_size = Vector2(0, 1)
		v.add_child(hi)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)

func _draw() -> void:
	if not (medal or hooks):
		return
	if hooks:
		var hs := UiMetrics.design_size(Vector2(14, 24))
		var hk := UiMetrics.tex("hook", Vector2(14, 24))
		var y := -UiMetrics.css(20.0)
		draw_texture_rect(hk, Rect2(Vector2(UiMetrics.css(6.0), y), hs), false)
		draw_texture_rect(hk, Rect2(Vector2(size.x - UiMetrics.css(6.0) - hs.x, y), hs), false)
	if medal:
		var ms := UiMetrics.design_size(Vector2(80, 40))
		draw_texture_rect(UiMetrics.tex("medal", Vector2(80, 40)), Rect2(Vector2(size.x * 0.5 - ms.x * 0.5, -UiMetrics.css(14.0)), ms), false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

## En-tête « .changelog-header » de l'original (fenêtres de sauvegarde, aide…) : titre doré à gauche, croix carrée rivetée
## à droite, filet #5a4526 en dessous ; le corps est paddé de 16/20 px.
func use_framed_header(title: String, on_close: Callable) -> void:
	_box.pad_css = Vector4(0, 0, 0, 0)
	_box.rescale()
	_v.add_theme_constant_override("separation", 0)
	var head := MarginContainer.new()
	for side in ["left", "right"]:
		head.add_theme_constant_override("margin_" + side, int(UiMetrics.css(20.0)))
	for side in ["top", "bottom"]:
		head.add_theme_constant_override("margin_" + side, int(UiMetrics.css(14.0)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	head.add_child(row)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	t.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.12)))
	t.add_theme_color_override("font_color", Color("ffd88a"))
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("outline_size", 2)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(t)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(UiMetrics.css(32.0), UiMetrics.css(32.0))
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.0)))
	x.add_theme_color_override("font_color", Color("e2d2b0"))
	x.add_theme_color_override("font_hover_color", Color("f5cccc"))
	var st := IronBox.button_styles(Color("b03a3a"))
	for k in st:
		x.add_theme_stylebox_override(k, st[k])
	x.pressed.connect(func(): on_close.call())
	row.add_child(x)
	_v.add_child(head)
	_v.move_child(head, 0)
	var line := ColorRect.new()
	line.color = Color("5a4526")
	line.custom_minimum_size = Vector2(0, maxf(1.0, UiMetrics.css(1.0)))
	_v.add_child(line)
	_v.move_child(line, 1)
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, int(UiMetrics.css(20.0)))
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UiMetrics.css(16.0)))
	body.reparent(pad)
	_v.add_child(pad)
