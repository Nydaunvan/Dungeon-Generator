class_name SpellDisc
extends Control
## Disque de bronze rivé (attaque, sorts, arcs des cartes) dessiné en vectoriel : net à toute taille.
## Port des styles .ab-slot / .ab-attack-btn / .csa-icon-btn du HTML.

signal pressed
signal tip_show
signal tip_hide

const LONG_PRESS := 0.45

var tone: String = "spell"      # "spell", "attack", "empty"
var glyph: String = ""
var tex: Texture2D = null
var cd_text: String = ""
var dim: float = 1.0
var highlight: bool = false
var disabled: bool = false
var _hover: bool = false
var _down: bool = false
var _long: bool = false
var _timer: Timer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(30, 30)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = LONG_PRESS
	_timer.timeout.connect(func():
		_long = true
		tip_show.emit())
	add_child(_timer)
	mouse_entered.connect(func():
		_hover = true
		queue_redraw()
		if tone == "spell":
			tip_show.emit())
	mouse_exited.connect(func():
		_hover = false
		_down = false
		_timer.stop()
		queue_redraw()
		tip_hide.emit())
	resized.connect(func(): pivot_offset = size * 0.5)

func set_state(g: String, t: Texture2D, cd: String, dimmed: float, hl: bool = false) -> void:
	if g == glyph and t == tex and cd == cd_text and is_equal_approx(dimmed, dim) and hl == highlight:
		return
	glyph = g
	tex = t
	cd_text = cd
	dim = dimmed
	highlight = hl
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_long = false
			if e.device != -1 or DisplayServer.is_touchscreen_available():
				_timer.start()
		else:
			_timer.stop()
			var was_long := _long
			_long = false
			if _down and not was_long and not disabled and tone != "empty":
				pressed.emit()
			if was_long:
				tip_hide.emit()
			_down = false
		queue_redraw()
		accept_event()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	if _hover and not _down and tone != "empty":
		r += 1.0
	var k := clampf(r / 23.0, 0.6, 2.2)
	var mod := Color(1, 1, 1, dim)
	if _down:
		r *= 0.94
	# anneaux extérieurs : noir, bronze, noir
	draw_circle(c, r + 3.0 * k, Color("070504") * mod, true, -1.0, true)
	draw_circle(c, r + 2.0 * k, (Color("e8b45c") if (_hover or highlight) else Color("5a4630")) * mod, true, -1.0, true)
	draw_circle(c, r + 1.0 * k, Color("070504") * mod, true, -1.0, true)
	# corps : dégradé radial (lumière en haut à gauche)
	var hi := Color("4a4034") if tone == "empty" else (Color("6e6252") if tone == "attack" else Color("8a7c66"))
	var mid := Color("2a2119") if tone == "empty" else (Color("3a2f24") if tone == "attack" else Color("4a3f30"))
	var lo := Color("120d09") if tone == "empty" else Color("0c0906")
	var steps := 18
	for i in steps:
		var t := float(i) / float(steps - 1)
		var rr := r * (1.0 - t * 0.92)
		var off := Vector2(-0.16, -0.24) * r * t
		var col: Color
		if t < 0.5:
			col = lo.lerp(mid, t / 0.5)
		else:
			col = mid.lerp(hi, (t - 0.5) / 0.5)
		draw_circle(c + off, rr, col * mod, true, -1.0, true)
	# rivets aux quatre points cardinaux
	if tone != "empty":
		for a in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
			var p: Vector2 = c + a * r * 0.84
			draw_circle(p, 2.4 * k, Color("070504") * mod, true, -1.0, true)
			draw_circle(p, 1.6 * k, Color("8a7a62") * mod, true, -1.0, true)
	# cuvette centrale
	var well := Color("120d09") if tone == "empty" else (Color("3a1210") if tone == "attack" else Color("3a2f22"))
	draw_circle(c, r * 0.6, Color("070504") * mod, true, -1.0, true)
	draw_circle(c, r * 0.54, well * mod, true, -1.0, true)
	# contenu
	var inner := r * 1.08
	if tex != null and tone != "empty":
		var s := inner * 0.92
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1.25, 1.25, 1.25, dim))
	elif glyph != "":
		var font: Font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		var fs := int(r * (0.8 if tone == "empty" else 1.0))
		if tone == "empty":
			font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		var col2 := Color(0.78, 0.7, 0.59, 0.5 * dim) if tone == "empty" else (Color("f0c8b8") if tone == "attack" else Color("f5ecd8")) * mod
		var ts := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc := font.get_ascent(fs)
		var ds := font.get_descent(fs)
		draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + (asc - ds) * 0.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col2)
	# compte à rebours : disque sombre + secondes
	if cd_text != "":
		draw_circle(c, r * 0.98, Color("0a0503", 0.92 * dim), true, -1.0, true)
		var f2: Font = UiTheme.font(UiTheme.F_TITLE_BOLD)
		var fs2 := int(r * 0.9)
		var ts2 := f2.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		draw_string(f2, Vector2(c.x - ts2.x * 0.5, c.y + (f2.get_ascent(fs2) - f2.get_descent(fs2)) * 0.5), cd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color("e8b45c", dim))
