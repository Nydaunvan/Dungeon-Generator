class_name TouchControls
extends MarginContainer
## Pavé de commandes tactile, adaptatif (mobile portrait / paysage / PC).
## Émet `command` avec : "turn_left", "forward", "turn_right", "left", "back", "right", "interact".

signal command(cmd: String)

var _grid: GridContainer
var _buttons: Array[Button] = []
var _spacers: Array[Control] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)
	var layout := [
		["", ""], ["✋", "interact"], ["", ""],
		["↶", "turn_left"], ["↑", "forward"], ["↷", "turn_right"],
		["←", "left"], ["↓", "back"], ["→", "right"],
	]
	for item in layout:
		if item[1] == "":
			var spacer := Control.new()
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid.add_child(spacer)
			_spacers.append(spacer)
			continue
		var b := Button.new()
		b.text = item[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): command.emit(item[1]))
		_grid.add_child(b)
		_buttons.append(b)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	var vp := get_viewport_rect().size
	var side := clampf(minf(vp.x, vp.y) * 0.15, 56.0, 120.0)
	for b in _buttons:
		b.custom_minimum_size = Vector2(side, side)
		b.add_theme_font_size_override("font_size", int(side * 0.45))
	for sp in _spacers:
		sp.custom_minimum_size = Vector2(side, side * 0.6)
	var m := int(side * 0.25)
	add_theme_constant_override("margin_left", m)
	add_theme_constant_override("margin_right", m)
	add_theme_constant_override("margin_bottom", m)
