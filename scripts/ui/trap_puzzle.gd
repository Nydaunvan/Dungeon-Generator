class_name TrapPuzzle
extends Control
## Base des puzzles de piège : erreurs permises, signaux de fin, étincelles communes et tracé des runes.
## Chaque puzzle (runes, fils, énigme, dalles) hérite de cette classe et appelle `finish(ok)` quand il est résolu.

signal finished(success: bool)
signal status(text: String)
signal hurt(strong: bool)       # une erreur : la fenêtre tremble (et rougit si c'est la dernière)

const SIZE_PX := Vector2(400, 258)
const RUNES := [
	[[Vector2(0, -1), Vector2(0, 1)], [Vector2(0, -0.45), Vector2(0.62, -1)], [Vector2(0, 0.1), Vector2(0.62, -0.45)]],
	[[Vector2(-0.45, -1), Vector2(-0.45, 1)], [Vector2(-0.45, -0.6), Vector2(0.5, 0), Vector2(-0.45, 0.6)]],
	[[Vector2(-0.4, -1), Vector2(-0.4, 1)], [Vector2(-0.4, -1), Vector2(0.5, -0.5), Vector2(-0.4, 0.05)], [Vector2(-0.4, 0.05), Vector2(0.5, 1)]],
	[[Vector2(0, -1), Vector2(0.7, -0.3), Vector2(0, 0.3), Vector2(-0.7, -0.3), Vector2(0, -1)], [Vector2(0, 0.3), Vector2(-0.6, 1)], [Vector2(0, 0.3), Vector2(0.6, 1)]],
	[[Vector2(0.4, -1), Vector2(-0.4, -0.25), Vector2(0.4, 0.25), Vector2(-0.4, 1)]],
	[[Vector2(0, 1), Vector2(0, -1)], [Vector2(0, -0.15), Vector2(-0.7, -1)], [Vector2(0, -0.15), Vector2(0.7, -1)]],
]
const RUNE_COLORS := [Color("ffd88a"), Color("ff9a52"), Color("6fd0e8"), Color("9be07a"), Color("c49cff"), Color("ff6a6a")]

var allowed := 1
var errors := 0
var done := false
var _font: Font
var _fonts_b: Font
var _sparks: Array = []
var _animated := false

static func make(kind: String, s: Dictionary) -> TrapPuzzle:
	var p: TrapPuzzle
	match kind:
		"rune":
			p = TrapPuzzleRunes.new()
			p.allowed = int(s.puzzleRuneErrors)
			p.set("length", clampi(int(s.puzzleRuneLen), 3, 8))
		"wires":
			p = TrapPuzzleWires.new()
			p.allowed = int(s.puzzleWireErrors)
			p.set("count", clampi(int(s.puzzleWireCount), 3, 6))
		"riddle":
			p = TrapPuzzleRiddle.new()
			p.allowed = int(s.puzzleRiddleErrors)
		_:
			p = TrapPuzzleTiles.new()
			p.allowed = int(s.puzzleTilesErrors)
			p.set("rows", clampi(int(s.puzzleTilesRows), 3, 6))
	return p

func _init() -> void:
	custom_minimum_size = SIZE_PX
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	_font = load(UiTheme.F_BODY)
	_fonts_b = load(UiTheme.F_BODY_BOLD)
	set_process(false)

## À surcharger : démarre le puzzle (appelé quand la fenêtre est prête).
func begin() -> void:
	pass

func finish(ok: bool) -> void:
	if done:
		return
	done = true
	finished.emit(ok)

func misstep() -> bool:
	errors += 1
	return errors > allowed

func errors_left_text() -> String:
	var left := allowed - errors
	return L.fa(L.t("ui.trap_puzzle.erreurs_permises"), maxi(0, left))

func wait(sec: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(sec).timeout

func alive() -> bool:
	return is_inside_tree() and not done

# ------------------------------------------------------------------ étincelles

func burst(at: Vector2, col: Color, n: int = 14, speed: float = 90.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * (0.3 + randf())
		_sparks.append({"p": at, "v": v, "t": 0.0, "life": 0.5 + randf() * 0.6, "c": col, "s": 1.5 + randf() * 2.0})
	set_process(true)

func _process(d: float) -> void:
	var keep: Array = []
	for s in _sparks:
		s.t += d
		if s.t < s.life:
			s.p += s.v * d
			s.v = (s.v as Vector2) * 0.96 + Vector2(0, 40.0 * d)
			keep.append(s)
	_sparks = keep
	_update(d)
	queue_redraw()
	if _sparks.is_empty() and not _animated:
		set_process(false)

## À surcharger : animation continue (halo qui respire…). `_animated` = vrai tant que le puzzle en a besoin.
func _update(_d: float) -> void:
	pass

func draw_sparks() -> void:
	for s in _sparks:
		var k: float = 1.0 - float(s.t) / float(s.life)
		var c: Color = s.c
		draw_circle(s.p, float(s.s) * (0.6 + k), Color(c.r, c.g, c.b, k))

# ------------------------------------------------------------------ dessin

## Tracé d'une rune (halo large et transparent, puis trait net).
func draw_rune(idx: int, c: Vector2, r: float, col: Color, glow: float = 0.0, width: float = 3.0) -> void:
	for st in RUNES[idx % RUNES.size()]:
		var pts := PackedVector2Array()
		for p in st:
			pts.append(c + (p as Vector2) * r)
		if glow > 0.01:
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.22 * glow), width + 9.0 * glow, true)
			draw_polyline(pts, Color(col.r, col.g, col.b, 0.35 * glow), width + 4.0 * glow, true)
		draw_polyline(pts, col, width, true)

## Dalle de pierre (fond, biseau, fissures légères).
func draw_slab(rc: Rect2, tint: Color, seed_i: int = 0) -> void:
	draw_rect(rc, tint)
	draw_rect(rc, Color(1, 1, 1, 0.07), false, 1.0)
	draw_line(rc.position + Vector2(1, 1), rc.position + Vector2(rc.size.x - 1, 1), Color(1, 1, 1, 0.12), 1.0)
	draw_line(rc.position + Vector2(1, rc.size.y - 1), rc.end - Vector2(1, 1), Color(0, 0, 0, 0.35), 2.0)
	var h := absi(seed_i * 7919) % 100
	var a := rc.position + Vector2(rc.size.x * (0.2 + h * 0.004), 0)
	draw_polyline(PackedVector2Array([a, a + Vector2(rc.size.x * 0.1, rc.size.y * 0.3), a + Vector2(-rc.size.x * 0.05, rc.size.y * 0.55)]), Color(0, 0, 0, 0.28), 1.0)
