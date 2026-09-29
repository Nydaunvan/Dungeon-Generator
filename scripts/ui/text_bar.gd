class_name TextBar
extends ProgressBar
## Barre de progression avec texte centré (« 40/40 PV »).

var _label: Label

func _init(fill: Color = Color.WHITE, height: int = 18, font_size: int = 12) -> void:
	show_percentage = false
	custom_minimum_size = Vector2(0, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.02, 0.02, 0.9)
	bg.border_color = Color("3a2c1c")
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	add_theme_stylebox_override("background", bg)
	add_theme_stylebox_override("fill", fg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

func set_values(v: float, max_v: float, text: String) -> void:
	max_value = maxf(1.0, max_v)
	value = v
	_label.text = text

func set_font_size(px: int) -> void:
	_label.add_theme_font_size_override("font_size", px)
