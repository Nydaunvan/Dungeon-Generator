class_name TouchControls
extends Control
## Croix de déplacement de l'original : ▲ / ↺ ↻ / ▼ (cellules de 28 px CSS, écart 2 px), sur un fond en croix sale.

signal command(cmd: String)

var _buttons: Array[Button] = []
var _cells: Array = [[1, 0, "▲", "forward"], [0, 1, "↺", "turn_left"], [2, 1, "↻", "turn_right"], [1, 2, "▼", "back"]]
var cell: float = 28.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiMetrics.register(self)
	var st := IronBox.button_styles()
	for item in _cells:
		var b := Button.new()
		b.text = item[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color("e2d2b0"))
		b.add_theme_color_override("font_hover_color", Color("ffd88a"))
		b.add_theme_color_override("font_pressed_color", Color("ffd88a"))
		for k in st:
			b.add_theme_stylebox_override(k, st[k])
		var cmd: String = item[3]
		b.pressed.connect(func(): command.emit(cmd))
		add_child(b)
		_buttons.append(b)
	rescale()

func rescale() -> void:
	set_side(UiMetrics.css(cell))

func set_side(px: float) -> void:
	var gap := UiMetrics.css(2.0)
	custom_minimum_size = Vector2(px * 3.0 + gap * 2.0, px * 3.0 + gap * 2.0)
	size = custom_minimum_size
	for i in _buttons.size():
		var it: Array = _cells[i]
		_buttons[i].position = Vector2(it[0] * (px + gap), it[1] * (px + gap))
		_buttons[i].size = Vector2(px, px)
		_buttons[i].add_theme_font_size_override("font_size", int(px * 0.56))
	queue_redraw()

func _draw() -> void:
	# fond en croix (inset -5 px), bords droits comme le clip-path de l'original
	var e := UiMetrics.css(5.0)
	var s := size
	var a := s.x * 0.3
	var b := s.x * 0.7
	var pts := PackedVector2Array([Vector2(a, 0), Vector2(b, 0), Vector2(b, a), Vector2(s.x, a), Vector2(s.x, b), Vector2(b, b), Vector2(b, s.y), Vector2(a, s.y), Vector2(a, b), Vector2(0, b), Vector2(0, a), Vector2(a, a)])
	var big := PackedVector2Array()
	var c := s * 0.5
	for p in pts:
		big.append(p + (p - c).normalized() * e * 1.2)
	draw_colored_polygon(big, Color(0.05, 0.03, 0.02, 0.9))
