class_name TrapPuzzleRunes
extends TrapPuzzle
## Runes : quatre glyphes s'embrasent dans un ordre, puis il faut les rejouer. Avec les variantes, la séquence se rejoue
## parfois À REBOURS, ou les runes CHANGENT DE PLACE avant qu'on réponde (il faut suivre les glyphes, pas les cases).
## Chaque erreur fait vaciller le sceau.

var length := 5
var twists := true
var _mode := "forward"            # forward | reverse | shuffle
var _glyphs: Array = []           # glyphe de chaque rune (indice de rune 0..3)
var _slot: Array = [0.0, 0.0, 0.0, 0.0]   # case occupée par chaque rune (animée pendant le mélange)
var _seq: Array = []
var _lit: Array = [0.0, 0.0, 0.0, 0.0]
var _hover := -1
var _pos := 0
var _input := false
var _wrong := -1
var _pulse := 0.0
var _ok := false

func begin() -> void:
	var idx := [0, 1, 2, 3, 4, 5]
	GameRng.shuffle("trap", idx)
	_glyphs = idx.slice(0, 4)
	for i in 4:
		_slot[i] = float(i)
	if twists:
		_mode = ["forward", "reverse", "shuffle"][GameRng.i("trap") % 3]
	_seq.clear()
	for i in length:
		var nx := GameRng.i("trap") % 4
		if i > 0 and nx == _seq[i - 1] and GameRng.f("trap") < 0.7:
			nx = (nx + 1 + GameRng.i("trap") % 3) % 4
		_seq.append(nx)
	_animated = true
	set_process(true)
	if _mode == "reverse":
		status.emit(L.t("ui.trap_puzzle.rune_observez_rebours"))
	else:
		status.emit(L.t("ui.trap_puzzle.rune_observez"))
	await wait(0.9)
	await _show_sequence(0.34, 0.5)
	if _mode == "shuffle":
		status.emit(L.t("ui.trap_puzzle.rune_melange"))
		await _shuffle()
	_ready_for_input()

func _ready_for_input() -> void:
	_pos = 0
	_input = true
	status.emit(L.t("ui.trap_puzzle.rune_a_rebours") if _mode == "reverse" else L.t("ui.trap_puzzle.rune_a_vous"))
	queue_redraw()

func _show_sequence(flash_t: float, gap: float) -> void:
	for i in _seq.size():
		if not alive():
			return
		_flash(_seq[i], flash_t)
		Sound.sfx("pickup")
		await wait(flash_t + gap)

## Mélange animé : chaque rune glisse vers une nouvelle case.
func _shuffle() -> void:
	var perm := [0, 1, 2, 3]
	GameRng.shuffle("trap", perm)
	var tries := 0
	while tries < 8 and (perm[0] == 0 and perm[1] == 1 and perm[2] == 2 and perm[3] == 3):
		GameRng.shuffle("trap", perm)
		tries += 1
	var from: Array = _slot.duplicate()
	var t := create_tween()
	t.tween_method(func(k: float):
		for i in 4:
			_slot[i] = lerpf(from[i], float(perm[i]), k)
		queue_redraw(), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	Sound.sfx("blocked")
	await wait(1.2)

func _flash(i: int, dur: float) -> void:
	var t := create_tween()
	t.tween_method(func(v: float):
		_lit[i] = v
		queue_redraw(), 0.0, 1.0, 0.1)
	t.tween_interval(maxf(0.01, dur - 0.1))
	t.tween_method(func(v: float):
		_lit[i] = v
		queue_redraw(), 1.0, 0.0, 0.25)
	burst(_pad_rect(i).get_center(), TrapPuzzle.RUNE_COLORS[_glyphs[i]], 10, 70.0)

func _pad_rect(i: int) -> Rect2:
	var w := 78.0
	var gap := 14.0
	var total := w * 4.0 + gap * 3.0
	var x0 := (size.x - total) * 0.5
	var sl: float = _slot[i]
	var lift := sin(fmod(sl, 1.0) * PI) * -10.0 if absf(sl - roundf(sl)) > 0.001 else 0.0
	return Rect2(x0 + sl * (w + gap), 78.0 + lift, w, w)

func _update(d: float) -> void:
	_pulse += d

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := -1
		for i in 4:
			if _pad_rect(i).has_point(ev.position):
				h = i
		if h != _hover:
			_hover = h
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _input and not done:
		for i in 4:
			if _pad_rect(i).has_point(ev.position):
				submit(i)
				return

func accepts() -> bool:
	return _input and not done

func inject(i: int) -> void:
	if i >= 0 and i < 4:
		_press(i)

func _expected() -> int:
	return _seq[_seq.size() - 1 - _pos] if _mode == "reverse" else _seq[_pos]

func _press(i: int) -> void:
	_input = false
	_flash(i, 0.22)
	if i == _expected():
		Sound.sfx("pickup")
		_pos += 1
		if _pos >= _seq.size():
			_ok = true
			status.emit(L.t("ui.trap_puzzle.rune_sceau_brise"))
			Sound.sfx("level_up")
			for k in 4:
				burst(_pad_rect(k).get_center(), TrapPuzzle.RUNE_COLORS[_glyphs[k]], 16, 110.0)
			await wait(0.9)
			finish(true)
			return
		_input = true
		return
	_wrong = i
	Sound.sfx("hit")
	var over := misstep()
	hurt.emit(over)
	burst(_pad_rect(i).get_center(), Color("ff5a5a"), 18, 120.0)
	status.emit(L.t("ui.trap_puzzle.rune_faux") + "  ·  " + errors_left_text())
	await wait(0.7)
	_wrong = -1
	if over:
		finish(false)
		return
	# nouvelle présentation de la séquence (les runes retrouvent leur place d'origine avant une nouvelle série)
	status.emit(L.t("ui.trap_puzzle.rune_observez_rebours") if _mode == "reverse" else L.t("ui.trap_puzzle.rune_observez"))
	for k in 4:
		_slot[k] = float(k)
	await _show_sequence(0.3, 0.42)
	if _mode == "shuffle":
		await _shuffle()
	_ready_for_input()

func _draw() -> void:
	var cx := size.x * 0.5
	var ring_c := Color("e8b45c") if not _ok else Color("9be07a")
	for k in 3:
		draw_arc(Vector2(cx, 118.0), 150.0 - k * 9.0, 0.0, TAU, 72, Color(ring_c.r, ring_c.g, ring_c.b, 0.10 + 0.05 * sin(_pulse * 2.0 + k)), 1.5, true)
	var dot_w := 16.0
	var dx := cx - (_seq.size() * dot_w) * 0.5 + dot_w * 0.5
	for i in _seq.size():
		var filled := i < _pos
		draw_circle(Vector2(dx + i * dot_w, 32.0), 4.5, Color("ffd88a") if filled else Color(0.35, 0.28, 0.2, 0.9))
		draw_arc(Vector2(dx + i * dot_w, 32.0), 4.5, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0)
	if _mode == "reverse":
		draw_string(_fonts_b, Vector2(cx - 60.0, 208.0), "◀  ◀  ◀", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 14, Color(1, 0.85, 0.5, 0.5 + 0.3 * sin(_pulse * 4.0)))
	elif _mode == "shuffle":
		draw_string(_fonts_b, Vector2(cx - 60.0, 208.0), "⇄", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 16, Color(1, 0.85, 0.5, 0.5 + 0.3 * sin(_pulse * 4.0)))
	for i in 4:
		var rc := _pad_rect(i)
		var lit: float = _lit[i]
		var col: Color = TrapPuzzle.RUNE_COLORS[_glyphs[i]]
		var bad := _wrong == i
		var tint := Color(0.17, 0.14, 0.11)
		if bad:
			tint = Color(0.38, 0.1, 0.08)
		draw_slab(rc, tint, i + 3)
		if lit > 0.01 or (_hover == i and _input):
			var a := maxf(lit, 0.25 if _hover == i else 0.0)
			draw_rect(rc.grow(2), Color(col.r, col.g, col.b, 0.28 * a), true)
		var base := Color(col.r * 0.62, col.g * 0.62, col.b * 0.62, 0.95)
		var c := base.lerp(col, lit)
		if bad:
			c = Color("ff5a5a")
		draw_rune(_glyphs[i], rc.get_center(), 24.0, c, lit, 3.0)
	draw_sparks()
