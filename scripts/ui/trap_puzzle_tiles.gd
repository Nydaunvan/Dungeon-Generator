class_name TrapPuzzleTiles
extends TrapPuzzle
## Dalles piégées : un chemin sûr s'illumine un instant, puis il faut le traverser de mémoire, dalle voisine après dalle voisine.
## Une mauvaise dalle déclenche une fléchette.

const COLS := 5
var rows := 5
var twists := true
var _mirror := false
var _path: Array = []
var _lit: Dictionary = {}       # "r,c" -> intensité 0..1 (révélation)
var _good: Dictionary = {}      # dalles franchies
var _bad: Dictionary = {}       # dalles qui ont tiré
var _cur := 0
var _input := false
var _hover := Vector2i(-1, -1)
var _dart := {}
var _pulse := 0.0
var _tok := Vector2.ZERO
var _tok_on := false

func begin() -> void:
	_path = TrapRules.make_tiles(rows, COLS)
	_mirror = twists and GameRng.f("trap") < 0.5
	_animated = true
	set_process(true)
	status.emit(L.t("ui.trap_puzzle.dalles_miroir") if _mirror else L.t("ui.trap_puzzle.dalles_observez"))
	await wait(0.6)
	for r in rows:
		if not alive():
			return
		_set_lit(r, _show_col(r), 1.0)
		Sound.sfx("pickup")
		await wait(0.34)
	await wait(0.7)
	for r in rows:
		_set_lit(r, _show_col(r), 0.0, 0.4)
	await wait(0.5)
	_input = true
	_tok = Vector2(size.x * 0.5, size.y - 4.0)
	_tok_on = true
	status.emit(L.t("ui.trap_puzzle.dalles_avancez") + "  " + errors_left_text())

## Colonne montrée pendant la révélation : dans le miroir, la vraie dalle est à l'opposé.
func _show_col(r: int) -> int:
	return COLS - 1 - int(_path[r]) if _mirror else int(_path[r])

func _set_lit(r: int, c: int, to: float, dur: float = 0.18) -> void:
	var key := "%d,%d" % [r, c]
	var from: float = _lit.get(key, 0.0)
	var t := create_tween()
	t.tween_method(func(v: float): _lit[key] = v, from, to, dur)

func _tile_h() -> float:
	return minf(46.0, (size.y - 30.0 - (rows - 1) * 6.0) / float(rows))

func _rc(r: int, c: int) -> Rect2:
	var th := _tile_h()
	var w := 62.0
	var gap := 7.0
	var x0 := (size.x - (COLS * w + (COLS - 1) * gap)) * 0.5
	var y_bottom := size.y - 14.0
	return Rect2(x0 + c * (w + gap), y_bottom - (r + 1) * th - r * 6.0, w, th)

func _update(d: float) -> void:
	_pulse += d
	if not _dart.is_empty():
		_dart.t += d
		if _dart.t > 0.5:
			_dart = {}
	if _tok_on:
		var tgt: Vector2 = _rc(_cur - 1, _path[_cur - 1]).get_center() if _cur > 0 else Vector2(size.x * 0.5, size.y - 4.0)
		_tok = _tok.lerp(tgt, minf(1.0, d * 9.0))

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _at(ev.position)
		if h != _hover:
			_hover = h
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _input and not done:
		var h2 := _at(ev.position)
		if h2.x == _cur:
			submit(h2.y)

func _at(p: Vector2) -> Vector2i:
	for r in rows:
		for c in COLS:
			if _rc(r, c).has_point(p):
				return Vector2i(r, c)
	return Vector2i(-1, -1)

func accepts() -> bool:
	return _input and not done

func inject(c: int) -> void:
	if c >= 0 and c < COLS:
		_step(c)

func _step(c: int) -> void:
	var r := _cur
	var key := "%d,%d" % [r, c]
	if _bad.has(key) or _good.has(key):
		return
	_input = false
	if c == _path[r]:
		_good[key] = true
		_set_lit(r, c, 1.0, 0.15)
		burst(_rc(r, c).get_center(), Color("9be07a"), 10, 70.0)
		Sound.sfx("pickup")
		_cur += 1
		if _cur >= rows:
			Sound.sfx("level_up")
			status.emit(L.t("ui.trap_puzzle.dalles_traversee"))
			await wait(0.9)
			finish(true)
			return
		_input = true
		return
	_bad[key] = true
	var rc := _rc(r, c)
	_dart = {"y": rc.get_center().y, "to": rc.get_center().x, "dir": -1.0 if c >= COLS / 2 else 1.0, "t": 0.0}
	Sound.sfx("hit")
	burst(rc.get_center(), Color("ff5a5a"), 18, 130.0)
	var over := misstep()
	hurt.emit(over)
	status.emit(L.t("ui.trap_puzzle.dalles_fleche") + "  " + errors_left_text())
	await wait(0.7)
	if over:
		for rr in rows:
			_set_lit(rr, _path[rr], 1.0, 0.3)
		status.emit(L.t("ui.trap_puzzle.dalles_chemin"))
		await wait(1.1)
		finish(false)
		return
	_input = true

func _draw() -> void:
	for r in rows:
		for c in COLS:
			var rc := _rc(r, c)
			var key := "%d,%d" % [r, c]
			var lit: float = _lit.get(key, 0.0)
			var tint := Color(0.17, 0.14, 0.11)
			var reachable := _input and r == _cur
			if _good.has(key):
				tint = Color(0.15, 0.3, 0.12)
			elif _bad.has(key):
				tint = Color(0.38, 0.09, 0.07)
			draw_slab(rc, tint, r * 5 + c)
			if reachable and _hover == Vector2i(r, c) and not _bad.has(key):
				draw_rect(rc.grow(-1), Color(1, 0.85, 0.5, 0.16))
			if lit > 0.01:
				var gc := Color("9be07a") if _good.has(key) else Color("ffd88a")
				draw_rect(rc.grow(3), Color(gc.r, gc.g, gc.b, 0.22 * lit))
				draw_rect(rc, Color(gc.r, gc.g, gc.b, 0.4 * lit))
				draw_rune(3, rc.get_center(), minf(rc.size.y * 0.33, 14.0), Color(1, 0.95, 0.75, lit), lit, 2.0)
			if _bad.has(key):
				draw_line(rc.position + rc.size * 0.25, rc.end - rc.size * 0.25, Color("ff6a5a"), 3.0)
				draw_line(rc.position + Vector2(rc.size.x * 0.75, rc.size.y * 0.25), rc.position + Vector2(rc.size.x * 0.25, rc.size.y * 0.75), Color("ff6a5a"), 3.0)
	# rangée courante : flèches de progression
	if _input and _cur < rows:
		var y := _rc(_cur, 0).get_center().y
		var a := 0.45 + 0.3 * sin(_pulse * 5.0)
		draw_string(_fonts_b, Vector2(6, y + 5), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.5, a))
		draw_string(_fonts_b, Vector2(size.x - 20, y + 5), "◀", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.5, a))
	# pion de l'équipe
	if _tok_on:
		draw_circle(_tok + Vector2(0, 2), 9.0, Color(0, 0, 0, 0.5))
		draw_circle(_tok, 8.0, Color("ffd88a"))
		draw_arc(_tok, 8.0, 0.0, TAU, 20, Color("8a6a3a"), 2.0)
	# fléchette
	if not _dart.is_empty():
		var k: float = clampf(float(_dart.t) / 0.16, 0.0, 1.0)
		var from_x := -10.0 if float(_dart.dir) > 0.0 else size.x + 10.0
		var x := lerpf(from_x, float(_dart.to), k)
		var tail := x - float(_dart.dir) * 26.0
		draw_line(Vector2(tail, _dart.y), Vector2(x, _dart.y), Color("c8c0b0"), 2.0)
		draw_circle(Vector2(x, _dart.y), 2.5, Color("ff6a5a"))
	draw_sparks()
