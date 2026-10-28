class_name AxSwitch
extends Control
## Interrupteur 44×24 de l'atelier (maquette : fond doré allumé, pouce sombre à droite).

signal toggled(on: bool)
var on := false

func _init(value: bool = false) -> void:
	on = value
	custom_minimum_size = Vector2(44, 24)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_on(v: bool) -> void:
	on = v
	queue_redraw()

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e8b45c") if on else Color("3a2c18")
	sb.set_corner_radius_all(12)
	draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(44, 24)))
	draw_circle(Vector2(44 - 12, 12) if on else Vector2(12, 12), 9.0, Color("2a1a06") if on else Color("b8a781"))

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		on = not on
		queue_redraw()
		toggled.emit(on)
