class_name OrnatePanel
extends PanelContainer
## Panneau de bronze avec rivets aux quatre coins, titre en capitales (Cinzel) et corps libre (`body`).

var body: VBoxContainer
var title_label: Label

func _init(title: String = "") -> void:
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG, UiTheme.BRONZE, 4, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	if title != "":
		title_label = Label.new()
		title_label.text = title.to_upper()
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
		title_label.add_theme_font_size_override("font_size", 15)
		title_label.add_theme_color_override("font_color", UiTheme.PARCH)
		v.add_child(title_label)
		var sep := ColorRect.new()
		sep.color = UiTheme.BRONZE_DARK
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	v.add_child(body)

func _draw() -> void:
	var r := 4.0
	for p in [Vector2(6, 6), Vector2(size.x - 6, 6), Vector2(6, size.y - 6), Vector2(size.x - 6, size.y - 6)]:
		draw_circle(p, r + 1.5, Color.BLACK)
		draw_circle(p, r, UiTheme.BRONZE_LIGHT)
		draw_circle(p + Vector2(-1, -1), r * 0.45, Color("d8c090"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
