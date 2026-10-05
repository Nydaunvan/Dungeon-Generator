class_name TrapPuzzleRiddle
extends TrapPuzzle
## Énigmes : une inscription sur une tablette de pierre, éclairée par deux bougies ; quatre réponses, une seule juste.
## Plusieurs énigmes s'enchaînent (réglable) et les erreurs permises valent pour l'ensemble.

const COUNT := 12
var rounds := 2
var _round := 0
var _order: Array = []
var _q: Label
var _btns: Array = []
var _pulse := 0.0
var _locked := false
var _right_text := ""
var _tablet_h := 104.0

func begin() -> void:
	_order = range(1, COUNT + 1)
	_order.shuffle()
	_animated = true
	set_process(true)
	_next_round()

func _next_round() -> void:
	for c in get_children():
		c.queue_free()
	_btns.clear()
	_locked = false
	var n: int = _order[_round]
	var base := "ui.trap_puzzle.riddle_%d_" % n
	var answers: Array = [[L.t(base + "a"), true], [L.t(base + "b"), false], [L.t(base + "c"), false], [L.t(base + "d"), false]]
	answers.shuffle()
	_right_text = L.t(base + "a")
	_q = Label.new()
	_q.position = Vector2(26, 14)
	_q.size = Vector2(size.x - 52, _tablet_h - 12)
	_q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_q.add_theme_font_size_override("font_size", 15)
	_q.add_theme_font_override("font", load(UiTheme.F_BODY_ITALIC))
	_q.add_theme_color_override("font_color", Color("f0e2c0"))
	_q.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_q.text = L.t(base + "q")
	_q.visible_ratio = 0.0
	add_child(_q)
	var t := create_tween()
	t.tween_property(_q, "visible_ratio", 1.0, 0.04 * float(_q.text.length()) + 0.3)
	for i in 4:
		var b := Button.new()
		b.text = str(answers[i][0])
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(30, _tablet_h + 14 + i * 33)
		b.size = Vector2(size.x - 60, 29)
		var st := IronBox.button_styles()
		for k in st:
			b.add_theme_stylebox_override(k, st[k])
		b.modulate.a = 0.0
		var ok: bool = answers[i][1]
		b.pressed.connect(func(): _answer(b, ok))
		add_child(b)
		TrapModal.fit_button(b, 14, 10)
		_btns.append(b)
		t.parallel().tween_property(b, "modulate:a", 1.0, 0.3).set_delay(0.8 + i * 0.2)
	status.emit(L.fa(L.t("ui.trap_puzzle.enigme_n"), [_round + 1, rounds]) + "  ·  " + errors_left_text())

func _update(d: float) -> void:
	_pulse += d

func _answer(b: Button, ok: bool) -> void:
	if done or _locked:
		return
	_locked = true
	if ok:
		b.add_theme_color_override("font_color", Color("b8e08a"))
		b.add_theme_color_override("font_hover_color", Color("b8e08a"))
		Sound.sfx("pickup")
		burst(b.position + b.size * 0.5, Color("9be07a"), 24, 120.0)
		for o in _btns:
			if o != b:
				(o as Button).disabled = true
		_round += 1
		if _round >= rounds:
			status.emit(L.t("ui.trap_puzzle.enigme_juste"))
			Sound.sfx("level_up")
			await wait(1.0)
			finish(true)
			return
		status.emit(L.t("ui.trap_puzzle.enigme_suivante"))
		await wait(1.0)
		if alive():
			_next_round()
		return
	b.disabled = true
	b.add_theme_color_override("font_disabled_color", Color("ff7a6a"))
	b.modulate = Color(1, 0.6, 0.55)
	Sound.sfx("hit")
	burst(Vector2(size.x * 0.5, 10), Color("c8b8a0"), 18, 80.0)
	var over := misstep()
	hurt.emit(over)
	status.emit(L.t("ui.trap_puzzle.enigme_faux") + "  ·  " + errors_left_text())
	await wait(0.6)
	if over:
		for o in _btns:
			(o as Button).disabled = true
			if (o as Button).text == _right_text:
				(o as Button).add_theme_color_override("font_disabled_color", Color("b8e08a"))
		await wait(0.8)
		finish(false)
		return
	_locked = false

func _draw() -> void:
	var rc := Rect2(14, 6, size.x - 28, _tablet_h)
	draw_rect(rc, Color("2c241b"))
	draw_rect(rc, Color("8a6a3a"), false, 2.0)
	draw_rect(rc.grow(-6), Color(0, 0, 0, 0.25), false, 1.0)
	for k in 4:
		var y := rc.position.y + 14.0 + k * 24.0
		draw_line(Vector2(rc.position.x + 6, y), Vector2(rc.end.x - 6, y), Color(1, 1, 1, 0.025), 1.0)
	for side in 2:
		var x := 6.0 if side == 0 else size.x - 6.0
		var fl := 1.0 + sin(_pulse * 9.0 + side * 2.0) * 0.12 + sin(_pulse * 15.0) * 0.06
		draw_circle(Vector2(x, 58.0), 38.0, Color(1.0, 0.55, 0.2, 0.06 * fl))
		draw_circle(Vector2(x, 58.0), 22.0, Color(1.0, 0.6, 0.25, 0.09 * fl))
		draw_rect(Rect2(x - 3, 62, 6, 26), Color("d8c8a0"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, 46.0 - 6.0 * fl), Vector2(x + 4, 58), Vector2(x, 63), Vector2(x - 4, 58)]), Color(1.0, 0.7, 0.25))
	draw_sparks()
