class_name TrapPuzzleWires
extends TrapPuzzle
## Fils : un faisceau de fils colorés entre deux bornes, et des indices gravés qui désignent le bon. Un coup de cisaille.

const COLORS := {"red": Color("d8402e"), "blue": Color("3f86e0"), "yellow": Color("e6bf2c"), "green": Color("4fb04a"),
	"violet": Color("9a5bd0"), "white": Color("e8e2d2")}

var count := 4
var _data: Dictionary
var _clue: Label
var _cut := {}
var _wrong := {}
var _hover := -1
var _reveal := -1
var _pulse := 0.0
var _open := true

func begin() -> void:
	_data = TrapRules.make_wires(count)
	_clue = Label.new()
	_clue.position = Vector2(10, 0)
	_clue.size = Vector2(size.x - 20, 126)
	_clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clue.add_theme_font_size_override("font_size", 13)
	_clue.add_theme_font_override("font", load(UiTheme.F_BODY_ITALIC))
	_clue.add_theme_color_override("font_color", Color("e8dcc0"))
	_clue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clue.text = _clue_text()
	_clue.visible_ratio = 0.0
	add_child(_clue)
	var t := create_tween()
	t.tween_property(_clue, "visible_ratio", 1.0, 1.2)
	_animated = true
	set_process(true)
	status.emit(L.t("ui.trap_puzzle.fils_choisissez") + "  " + errors_left_text())

func _cn(c: String) -> String:
	return L.t("ui.trap_puzzle.color_%s" % c)

func _clue_text() -> String:
	var out: Array = []
	for c in _data.clues:
		var k := str(c.k)
		var a := str(c.a)
		var line := L.t("ui.trap_puzzle.clue_%s" % k)
		match k:
			"not_color", "not_next", "gap", "below_color", "above_color":
				line = line % _cn(a)
			"pos_nth":
				line = line % a
			"between":
				var p := a.split("|")
				line = line % [_cn(p[0]), _cn(p[1])]
		out.append("• " + line)
	return "\n".join(out)

func _update(d: float) -> void:
	_pulse += d
	for k in _wrong.keys():
		_wrong[k] = float(_wrong[k]) - d
		if _wrong[k] <= 0.0:
			_wrong.erase(k)

func _y(i: int) -> float:
	var n: int = _data.colors.size()
	var top := 146.0
	var bot := size.y - 16.0
	return top + (bot - top) * (float(i) / float(n - 1)) if n > 1 else top

func _pts(i: int, cutgap := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var y0 := _y(i)
	for k in 25:
		var t := float(k) / 24.0
		var x := lerpf(48.0, size.x - 48.0, t)
		var y := y0 + sin(t * PI) * (7.0 if i % 2 == 0 else -7.0) + sin(t * TAU * 1.5 + i) * 2.0
		pts.append(Vector2(x, y))
	return pts

func _gui_input(ev: InputEvent) -> void:
	if done or not _open:
		return
	if ev is InputEventMouseMotion:
		var h := _hit(ev.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var h2 := _hit(ev.position)
		if h2 >= 0 and not _cut.has(h2):
			submit(h2)

func _hit(p: Vector2) -> int:
	var best := -1
	var bd := 9.0
	for i in _data.colors.size():
		if _cut.has(i):
			continue
		for q in _pts(i):
			var d := q.distance_to(p)
			if d < bd:
				bd = d
				best = i
	return best

func accepts() -> bool:
	return _open and not done

func inject(i: int) -> void:
	if i >= 0 and i < _data.colors.size() and not _cut.has(i):
		_snip(i)

func _snip(i: int) -> void:
	_open = false
	var mid := _pts(i)[12]
	var col: Color = COLORS[_data.colors[i]]
	if i == _data.target:
		_cut[i] = true
		burst(mid, col, 22, 120.0)
		burst(mid, Color("ffd88a"), 10, 80.0)
		Sound.sfx("door_locked")
		Sound.sfx_later(0.12, "pickup")
		status.emit(L.t("ui.trap_puzzle.fils_coupe"))
		await wait(1.0)
		finish(true)
	else:
		_cut[i] = true
		_wrong[i] = 0.6
		burst(mid, Color("ff5a5a"), 22, 130.0)
		Sound.sfx("hit")
		var over := misstep()
		hurt.emit(over)
		status.emit(L.t("ui.trap_puzzle.fils_faux") + "  " + errors_left_text())
		await wait(0.8)
		if over:
			_reveal = _data.target
			status.emit(L.t("ui.trap_puzzle.fils_etincelle"))
			await wait(0.9)
			finish(false)
			return
		_open = true

func _draw() -> void:
	if _data.is_empty():
		return
	var w := size.x
	# bornes (boîtier de cuivre rivé)
	for side in 2:
		var x := 8.0 if side == 0 else w - 44.0
		var rc := Rect2(x, 130.0, 36.0, size.y - 130.0 + 2.0)
		draw_rect(rc, Color("2a1f14"))
		draw_rect(rc, Color("8a6a3a"), false, 2.0)
		for k in 4:
			draw_circle(Vector2(x + 18.0, rc.position.y + 14.0 + k * (rc.size.y - 28.0) / 3.0), 2.5, Color("b08a4a"))
	for i in _data.colors.size():
		var col: Color = COLORS[_data.colors[i]]
		var pts := _pts(i)
		var alive_w := not _cut.has(i)
		var hot: bool = alive_w and (_hover == i)
		if _wrong.has(i):
			col = Color("ff5a5a")
		if _reveal == i:
			col = Color("ffd88a").lerp(Color("ffffff"), 0.5 + 0.5 * sin(_pulse * 12.0))
		if alive_w:
			draw_polyline(pts, Color(0, 0, 0, 0.7), 10.0, true)
			if hot:
				draw_polyline(pts, Color(col.r, col.g, col.b, 0.3), 14.0, true)
			draw_polyline(pts, col, 7.0, true)
			draw_polyline(pts, Color(1, 1, 1, 0.35), 1.5, true)
		else:
			# fil tranché : deux moitiés qui pendent
			var a := PackedVector2Array()
			var b := PackedVector2Array()
			for k in 25:
				var t := float(k) / 24.0
				var q := pts[k]
				if t < 0.46:
					a.append(q + Vector2(0, pow(t / 0.46, 2.0) * 10.0))
				elif t > 0.54:
					b.append(q + Vector2(0, pow((1.0 - t) / 0.46, 2.0) * 10.0))
			draw_polyline(a, Color(0, 0, 0, 0.6), 8.0, true)
			draw_polyline(a, Color(col.r, col.g, col.b, 0.7), 5.0, true)
			draw_polyline(b, Color(0, 0, 0, 0.6), 8.0, true)
			draw_polyline(b, Color(col.r, col.g, col.b, 0.7), 5.0, true)
	if _open and _hover >= 0 and not done:
		draw_string(_fonts_b, Vector2(w * 0.5 - 40.0, 140.0), L.t("ui.trap_puzzle.fils_couper"), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, Color("ffd88a"))
	draw_sparks()
