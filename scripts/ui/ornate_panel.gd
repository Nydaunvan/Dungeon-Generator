class_name OrnatePanel
extends PanelContainer
## Panneau de bronze rivé (texture 9 découpes), médaillon-crâne en haut, titre en capitales (Cinzel), corps libre (`body`).

var body: VBoxContainer
var title_label: Label
var header_row: HBoxContainer

func _init(title: String = "") -> void:
	add_theme_stylebox_override("panel", UiTheme.tbox("frame_panel", [12, 12, 12, 12], [14, 20, 14, 12]))
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
		title_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		title_label.add_theme_font_size_override("font_size", 15)
		title_label.add_theme_color_override("font_color", Color("e0c48a"))
		header_row.add_child(title_label)
		var sep := ColorRect.new()
		sep.color = Color("3a2c1c")
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)

func _draw() -> void:
	var m := UiTheme.tex("medallion")
	if m != null:
		draw_texture(m, Vector2(size.x * 0.5 - 20.0, -12.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
