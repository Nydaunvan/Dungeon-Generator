class_name TouchControls
extends GridContainer
## Croix de déplacement tactile : ↶ ↑ ↷ / ← ↓ →. Émet `command` (turn_left, forward, turn_right, left, back, right).

signal command(cmd: String)

var _buttons: Array[Button] = []

func _init() -> void:
	columns = 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 3)
	var layout := [["↶", "turn_left"], ["↑", "forward"], ["↷", "turn_right"],
		["←", "left"], ["↓", "back"], ["→", "right"]]
	for item in layout:
		var b := Button.new()
		b.text = item[0]
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.88)
		var cmd: String = item[1]
		b.pressed.connect(func(): command.emit(cmd))
		add_child(b)
		_buttons.append(b)
	set_side(48.0)

func set_side(px: float) -> void:
	for b in _buttons:
		b.custom_minimum_size = Vector2(px, px)
		b.add_theme_font_size_override("font_size", int(px * 0.5))
