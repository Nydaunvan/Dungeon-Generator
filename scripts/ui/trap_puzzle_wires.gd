class_name TrapPuzzleWires
extends TrapPuzzle
## Cordes : un faisceau de cordes torsadées colorées entre deux bornes, et des indices gravés qui désignent la bonne. Un coup de cisaille.
## Chaque corde est dessinée en torons (ombre, âme sombre, fût coloré, brins obliques, reflet, bague de laiton aux deux bouts) ;
## une corde coupée pend en deux moitiés dont les bouts s'effilochent. La géométrie est calculée une fois, le dessin la réutilise.

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
var _ropes: Array = []        # géométrie de chaque corde (points denses + brins), calculée une fois
var _halves: Dictionary = {}  # corde coupée -> {"a": géométrie, "b": géométrie, "fray": segments}

func begin() -> void:
	_data = TrapRules.make_wires(count)
	_ropes.clear()
	for i in _data.colors.size():
		_ropes.append(_build(_dense(i), i))
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

## Écart vertical entre deux cordes voisines.
func _spacing() -> float:
	var n: int = _data.colors.size()
	return ((size.y - 16.0) - 146.0) / float(maxi(1, n - 1))

## Demi-épaisseur d'une corde : plus fine quand elles sont nombreuses, pour qu'elles ne se chevauchent pas.
func _hw() -> float:
	return clampf(_spacing() * 0.23, 3.4, 5.0)

func _pt(i: int, t: float) -> Vector2:
	var amp := clampf(_spacing() * 0.25, 3.0, 7.0)
	var x := lerpf(48.0, size.x - 48.0, t)
	var y := _y(i) + sin(t * PI) * (amp if i % 2 == 0 else -amp) + sin(t * TAU * 1.5 + i) * 1.6
	return Vector2(x, y)

## 25 points : détection du clic et position de la cisaille.
func _pts(i: int, _cutgap := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 25:
		pts.append(_pt(i, float(k) / 24.0))
	return pts

## Points serrés (un tous les ~3 px) : le dessin des torons en a besoin.
func _dense(i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(24, int((size.x - 96.0) / 3.0))
	for k in n + 1:
		pts.append(_pt(i, float(k) / float(n)))
	return pts

## Torons d'une corde : traits obliques clairs et sombres, régulièrement espacés, et quelques fibres qui dépassent.
func _build(pts: PackedVector2Array, seed_i: int) -> Dictionary:
	var hw := _hw()
	var light := PackedVector2Array()
	var dark := PackedVector2Array()
	var fib := PackedVector2Array()
	var n := pts.size()
	var k := 1
	while k < n - 1:
		var tg := (pts[k + 1] - pts[k - 1]).normalized()
		var nm := Vector2(-tg.y, tg.x)
		var p := pts[k]
		light.append(p - nm * hw - tg * hw * 0.75)
		light.append(p + nm * hw + tg * hw * 0.75)
		var q := p + tg * 2.4
		dark.append(q - nm * hw - tg * hw * 0.75)
		dark.append(q + nm * hw + tg * hw * 0.75)
		if (k * 37 + seed_i * 11) % 9 == 0:
			var sg := 1.0 if (k + seed_i) % 2 == 0 else -1.0
			fib.append(p + nm * hw * sg)
			fib.append(p + nm * (hw + 2.2) * sg + tg * 2.0)
		k += 2
	return {"pts": pts, "light": light, "dark": dark, "fib": fib}

## Une corde dessinée à partir de sa géométrie ; `a` règle l'opacité (une corde coupée est un peu éteinte).
func _draw_rope(g: Dictionary, col: Color, a: float, glow: bool) -> void:
	var pts: PackedVector2Array = g.pts
	var hw := _hw()
	var shadow := PackedVector2Array()
	var hl := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(0, 2.0))
		hl.append(q + Vector2(0, -hw * 0.45))
	draw_polyline(shadow, Color(0, 0, 0, 0.5 * a), hw * 2.0 + 3.0, true)
	if glow:
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.3), hw * 2.0 + 8.0, true)
	draw_polyline(pts, Color(col.darkened(0.45), a), hw * 2.0 + 1.0, true)
	draw_polyline(pts, Color(col.darkened(0.12), a), hw * 2.0 - 2.0, true)
	draw_multiline(g.dark, Color(col.darkened(0.6), 0.75 * a), 1.3)
	draw_multiline(g.light, Color(col.lightened(0.38), 0.8 * a), 1.9)
	draw_polyline(hl, Color(1, 1, 1, 0.2 * a), 1.5, true)
	draw_multiline(g.fib, Color(col.lightened(0.5), 0.55 * a), 1.0)

## Bague de laiton qui serre le bout d'une corde contre sa borne.
func _draw_ferrule(p: Vector2, left: bool) -> void:
	var hw := _hw()
	var rc := Rect2(p.x - (7.0 if left else -1.0), p.y - hw - 2.0, 8.0, hw * 2.0 + 4.0)
	draw_rect(rc, Color("b08a4a"))
	draw_rect(rc, Color("3a2a14"), false, 1.5)
	draw_line(rc.position + Vector2(1.5, 2.0), rc.position + Vector2(1.5, rc.size.y - 2.0), Color(1, 0.95, 0.7, 0.55), 1.5)
	draw_line(rc.position + Vector2(rc.size.x * 0.5, 1.0), rc.position + Vector2(rc.size.x * 0.5, rc.size.y - 1.0), Color(0, 0, 0, 0.25), 1.0)

## Corde coupée : deux moitiés qui pendent de part et d'autre de la cisaille, bouts effilochés.
func _make_halves(i: int) -> Dictionary:
	var dense: PackedVector2Array = _ropes[i].pts
	var n := dense.size()
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for k in n:
		var t := float(k) / float(n - 1)
		var q := dense[k]
		if t < 0.46:
			a.append(q + Vector2(0, pow(t / 0.46, 2.0) * 10.0))
		elif t > 0.54:
			b.append(q + Vector2(0, pow((1.0 - t) / 0.46, 2.0) * 10.0))
	var fray := PackedVector2Array()
	var hw := _hw()
	for side in 2:
		var arr: PackedVector2Array = a if side == 0 else b
		var e: Vector2 = arr[arr.size() - 1] if side == 0 else arr[0]
		var nb: Vector2 = arr[arr.size() - 2] if side == 0 else arr[1]
		var tg := (e - nb).normalized()
		var nm := Vector2(-tg.y, tg.x)
		for f in 9:
			var off := (float(f) - 4.0) / 4.0
			var ln := 3.0 + float((f * 5 + i * 3) % 5)
			fray.append(e + nm * off * hw * 0.8)
			fray.append(e + nm * off * (hw * 0.8 + 2.5) + tg * ln)
	return {"a": _build(a, i), "b": _build(b, i + 7), "fray": fray, "ea": a[a.size() - 1], "eb": b[0]}

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
	_halves[i] = _make_halves(i)
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
		var alive_w := not _cut.has(i)
		var hot: bool = alive_w and (_hover == i)
		if _wrong.has(i):
			col = Color("ff5a5a")
		if _reveal == i:
			col = Color("ffd88a").lerp(Color("ffffff"), 0.5 + 0.5 * sin(_pulse * 12.0))
		var p0: Vector2 = _ropes[i].pts[0]
		var p1: Vector2 = _ropes[i].pts[_ropes[i].pts.size() - 1]
		if alive_w:
			_draw_rope(_ropes[i], col, 1.0, hot)
		elif _halves.has(i):
			var h: Dictionary = _halves[i]
			_draw_rope(h.a, col, 0.85, false)
			_draw_rope(h.b, col, 0.85, false)
			# bouts effilochés : coupe claire au centre, fibres qui s'écartent
			var tan_c := col.lerp(Color("d8c8a0"), 0.6)
			draw_multiline(h.fray, Color(tan_c, 0.85), 1.2)
			draw_circle(h.ea, _hw() * 0.8, tan_c)
			draw_circle(h.ea, _hw() * 0.4, col.darkened(0.4))
			draw_circle(h.eb, _hw() * 0.8, tan_c)
			draw_circle(h.eb, _hw() * 0.4, col.darkened(0.4))
		_draw_ferrule(p0, true)
		_draw_ferrule(p1, false)
	if _open and _hover >= 0 and not done:
		draw_string(_fonts_b, Vector2(w * 0.5 - 40.0, 140.0), L.t("ui.trap_puzzle.fils_couper"), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, Color("ffd88a"))
	draw_sparks()
