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

func _init(title: String = "") -> void:
	_box = FrameBox.new(18.0, Vector4(12, 10, 12, 10))
	add_theme_stylebox_override("panel", _box)
	clip_contents = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	if title != "":
		header_row = HBoxContainer.new()
		header_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(header_row)
		title_label = Label.new()
		title_label.text = title.to_upper()
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var fv := FontVariation.new()
		fv.base_font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		fv.spacing_glyph = 2
		title_label.add_theme_font_override("font", fv)
		title_label.add_theme_font_size_override("font_size", 13)
		title_label.add_theme_color_override("font_color", Color("d9b56e"))
		title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		title_label.add_theme_constant_override("outline_size", 2)
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
