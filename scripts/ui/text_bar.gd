class_name TextBar
extends ProgressBar
## Barre de progression avec texte centré (« 40/40 PV »).

var _label: Label

func _init(fill: Color = Color.WHITE, height: int = 18, font_size: int = 12) -> void:
	show_percentage = false
	custom_minimum_size = Vector2(0, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1a1108")
	bg.border_color = Color("3a2c18")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	add_theme_stylebox_override("background", bg)
	add_theme_stylebox_override("fill", fg)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

var _tween: Tween

## Met à jour la barre ; la valeur glisse doucement vers la cible (comme la transition CSS du HTML).
func set_values(v: float, max_v: float, text: String) -> void:
	max_value = maxf(1.0, max_v)
	_label.text = text
	if not is_inside_tree() or absf(value - v) < 0.01:
		value = v
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "value", v, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_height(px: float) -> void:
	custom_minimum_size = Vector2(0, px)
	set_font_size(int(clampf(px * 0.68, 8.0, 22.0)))

func set_font_size(px: int) -> void:
	_label.add_theme_font_size_override("font_size", px)
