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
	_label.add_theme_color_override("font_color", Color("fffaf0"))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01, 0.96))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

var _tween: Tween

## Style Atlas Noir : barre en parallélogramme (bout droit en biais) ; le chiffre s'écrit à droite de la barre, hors de celle-ci
## (`text_w` px lui sont réservés au-delà du bord droit du contrôle). Les autres barres du jeu gardent l'ancien style.
func use_atlas(fill: Color, show_text: bool = true, text_w: float = 0.0) -> void:
	var bg := SlantBox.new()
	bg.color = Color(0.02, 0.025, 0.028, 0.9)
	bg.border = Color(Atlas.COPPER_DIM, 0.6)
	var fg := SlantBox.new()
	fg.color = fill
	add_theme_stylebox_override("background", bg)
	add_theme_stylebox_override("fill", fg)
	_label.visible = show_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if text_w > 0.0:
		_label.anchor_left = 1.0
		_label.anchor_right = 1.0
		_label.offset_left = 6.0
		_label.offset_right = text_w
		_label.clip_text = false
	else:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label.offset_right = -4.0
	_label.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_MED))
	_label.add_theme_color_override("font_color", Atlas.IVORY)
	_label.add_theme_constant_override("outline_size", 0)

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

## `outline` : épaisseur du contour en fraction de la taille de police (petites barres : contour fin, texte net).
func set_font_size(px: int, outline: float = 0.3) -> void:
	_label.add_theme_font_size_override("font_size", px)
	_label.add_theme_constant_override("outline_size", maxi(2, int(round(px * outline))) if outline < 0.25 else maxi(3, int(round(px * outline))))
