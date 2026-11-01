class_name LogPanel
extends Control
## Carnet : journal de partie (suit GameState.log_lines) sur un parchemin dessiné dans le rectangle du panneau — rien ne le dépasse (marge d'ombre,
## bords irréguliers et coins roulés sont calculés dedans, et le contrôle rogne son contenu). Titre « JOURNAL DES ÉVÉNEMENTS » écrit sur le papier.
## Les nouveaux événements s'écrivent caractère par caractère (RichTextLabel.visible_characters) ; l'historique complet reste dans le texte, dans l'ordre.
## Une file d'attente absorbe les rafales : plus il y a de retard, plus l'écriture accélère, jusqu'à tout afficher d'un coup. Purement visuel :
## ne touche ni à la journalisation, ni au jeu, ni aux sauvegardes.

signal history_pressed

const INK := "#2f2112"
const INK_HIT := "#8a1c12"
const INK_GOLD := "#85600f"
const TITLE_COL := Color("3b2a15")
const MS_PER_CHAR := 0.020         # 20 ms par caractère (15 à 25 demandés)
const BACKLOG_FAST := 90           # au-delà de ce retard (en caractères), l'écriture accélère
const BACKLOG_INSTANT := 520       # au-delà, tout s'affiche d'un coup

var text: RichTextLabel
var _poly := PackedVector2Array()
var _nrm := PackedVector2Array()
var _fibers: Array = []
var _m := 8.0                      # marge intérieure réservée aux bords irréguliers et à l'ombre
var _title_h := 0.0
var _title_y := 0.0                # ligne de base du titre
var _rule_y := 0.0                 # filet décoratif sous le titre : la zone du titre s'arrête ici, le texte commence plus bas
var _hist: Button
var _paper: NoiseTexture2D
var _stain: NoiseTexture2D
var _shown := 0
var _target := 0
var _acc := 0.0
var _gold_re := RegEx.new()
var _mottle: NoiseTexture2D
var _vs: VScrollBar                # barre du RichTextLabel : sans largeur ni dessin propre, c'est LogPanel qui dessine le curseur dans la marge
var _goal := 0.0                   # position de défilement visée (molette fluide)
var _smoothing := false
var _bar_a := 0.0                  # opacité du curseur de défilement (0 = masqué)
var _bar_hot := 0.0                # temps restant d'affichage renforcé après un défilement
var _drag := false
var _follow := true               # true : le journal suit les nouveaux événements
var _self_set := false
var _stick_frames := 0             # quelques images de suivi après un ajout : la mise en page du RichTextLabel arrive en différé
var _bar_style: StyleBoxFlat
var _gutter := Rect2()             # couloir du curseur, dans la marge droite
const SPACER_PX := 3               # écart vertical entre deux événements (px de police)

func setup(gs: GameState) -> void:
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 30)
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_gold_re.compile("(?i)\\bxp\\b|pièces? d.or|\\bgold\\b|\\bor\\b")
	_paper = _noise_tex(0.016, 4, 3, [[0.0, Color("d8c79c")], [0.5, Color("e6d8b2")], [1.0, Color("f0e5c6")]])
	_mottle = _noise_tex(0.011, 3, 9, [[0.0, Color(0.36, 0.24, 0.09, 0.2)], [0.45, Color(0.36, 0.24, 0.09, 0.0)], [0.7, Color(1.0, 0.97, 0.85, 0.0)], [1.0, Color(1.0, 0.97, 0.85, 0.22)]])
	_stain = _noise_tex(0.006, 3, 5, [[0.0, Color(0.45, 0.30, 0.12, 0.0)], [0.55, Color(0.45, 0.30, 0.12, 0.0)], [1.0, Color(0.42, 0.27, 0.10, 0.34)]])
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_following = false      # suivi géré ici : il s'arrête quand le joueur remonte et reprend quand il revient en bas
	text.scroll_following_visible_characters = false
	text.clip_contents = true
	text.fit_content = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE      # la molette et le curseur sont gérés ici (défilement fluide, barre discrète)
	text.add_theme_font_override("normal_font", Atlas.font(Atlas.F_BODY_MED))
	text.add_theme_font_override("bold_font", Atlas.font(Atlas.F_BODY_BOLD))
	text.add_theme_color_override("default_color", Color(INK))
	# ≈ 14 px en paysage (0,78 rem), un peu moins en portrait où l'échelle est déjà relevée
	text.add_theme_font_size_override("normal_font_size", int(UiMetrics.rem(0.7 if UiMetrics.portrait else 0.78)))
	text.add_theme_font_size_override("bold_font_size", int(UiMetrics.rem(0.7 if UiMetrics.portrait else 0.78)))
	add_child(text)
	_vs = text.get_v_scroll_bar()
	_vs.custom_minimum_size.x = 0.0
	_vs.modulate = Color(1, 1, 1, 0)
	for n in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		_vs.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	_vs.value_changed.connect(func(_v: float):
		if not _self_set:
			_bar_hot = 1.4
		queue_redraw()
		_wake())
	_vs.changed.connect(func():
		_stick()
		queue_redraw()
		_wake())
	_bar_style = StyleBoxFlat.new()
	_bar_style.set_corner_radius_all(2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hist = Button.new()
	_hist.icon = Atlas.icon("scroll", 16, Color("5a4020"), 1.7)
	_hist.flat = true
	_hist.focus_mode = Control.FOCUS_NONE
	_hist.tooltip_text = L.t("ui.game_layout.historique_complet_du_journal")
	_hist.pressed.connect(func(): history_pressed.emit())
	add_child(_hist)
	for l in gs.log_lines:
		_add_line(l, false, true)
	_shown = _target
	_apply_visible()
	gs.log_added.connect(func(line: String, hit: bool): _add_line(line, hit, false))
	set_process(false)
	_rebuild()

static func _noise_tex(freq: float, octaves: int, seed_: int, stops: Array) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 256
	t.height = 256
	t.seamless = true
	t.color_ramp = g
	return t

# ------------------------------------------------------------------ événements et écriture progressive

func _line_style(line: String, hit: bool) -> Array:
	if hit:
		return [INK_HIT, INK_HIT, true]
	if _gold_re.search(line) != null:
		return [INK_GOLD, INK_GOLD, false]
	return [INK, INK, false]

func _add_line(line: String, hit: bool, instant: bool) -> void:
	var st := _line_style(line, hit)
	var safe := line.replace("[", "[lb]")
	var body := "[color=%s]%s[/color]" % [st[1], safe]
	if st[2]:
		body = "[b]%s[/b]" % body
	var gap := "[font_size=%d]\n[/font_size]" % SPACER_PX if text.get_total_character_count() > 0 else ""      # très léger écart entre deux événements
	text.append_text("%s[color=%s]✦[/color]  %s\n" % [gap, st[0], body])
	_target = text.get_total_character_count()
	if instant or not is_visible_in_tree() or _target - _shown > BACKLOG_INSTANT:      # panneau caché ou rafale trop longue : tout apparaît d'un coup
		_shown = _target
		_apply_visible()
	else:
		set_process(true)

func _wake() -> void:
	_stick_frames = 4
	if is_inside_tree():
		set_process(true)

func _apply_visible() -> void:
	text.visible_characters = -1 if _shown >= _target else _shown

func _process(dt: float) -> void:
	var busy := false
	var backlog := _target - _shown
	if backlog > 0:
		if backlog > BACKLOG_INSTANT or not is_visible_in_tree():
			_shown = _target
		else:
			_acc += dt
			var n := int(_acc / MS_PER_CHAR)
			_acc -= float(n) * MS_PER_CHAR
			_shown = mini(_target, _shown + n * (1 + backlog / BACKLOG_FAST))      # file d'attente : retard important, écriture plus rapide
		_apply_visible()
		busy = _shown < _target
	if _smoothing:      # molette fluide : on rejoint la position visée en douceur
		var nv := lerpf(_vs.value, _goal, 1.0 - exp(-dt * 16.0))
		if absf(nv - _goal) < 0.6:
			nv = _goal
			_smoothing = false
			_follow = _goal >= _max_scroll() - 2.0
		_vs.value = nv
		busy = busy or _smoothing
	_bar_hot = maxf(0.0, _bar_hot - dt)
	var want := 0.0
	if _can_scroll():
		want = 0.95 if (_bar_hot > 0.0 or _drag) else 0.4
	if not is_equal_approx(_bar_a, want):
		_bar_a = move_toward(_bar_a, want, dt * 2.5)
		queue_redraw()
		busy = true
	busy = busy or _bar_hot > 0.0
	if _stick_frames > 0:
		_stick_frames -= 1
		_stick()
		busy = true
	if not busy:
		set_process(false)

## Suivi du bas du journal tant que le joueur n'a pas remonté.
func _stick() -> void:
	if _follow and not _smoothing and not _drag and _vs.value < _max_scroll() - 0.5:
		_self_set = true
		_vs.value = _max_scroll()
		_self_set = false

func _can_scroll() -> bool:
	return _vs != null and _vs.max_value - _vs.page > 2.0

func _max_scroll() -> float:
	return maxf(0.0, _vs.max_value - _vs.page)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var dir := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			var step := float(text.get_theme_font_size("normal_font_size")) * 2.8 * maxf(mb.factor, 1.0)
			_goal = clampf((_goal if _smoothing else _vs.value) + dir * step, 0.0, _max_scroll())
			_smoothing = true
			if dir < 0.0:
				_follow = false      # le joueur remonte : on ne le ramène pas en bas
			_bar_hot = 1.4
			_wake()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _can_scroll() and mb.position.x >= _gutter.position.x - 4.0 and _gutter.has_point(Vector2(_gutter.position.x + 1.0, mb.position.y)):
				_drag = true
				_drag_to(mb.position.y)
				accept_event()
			elif not mb.pressed and _drag:
				_drag = false
				_wake()
				accept_event()
	elif e is InputEventMouseMotion and _drag:
		_drag_to((e as InputEventMouseMotion).position.y)
		accept_event()

func _drag_to(y: float) -> void:
	_smoothing = false
	_vs.value = clampf((y - _gutter.position.y) / maxf(1.0, _gutter.size.y), 0.0, 1.0) * _max_scroll()
	_goal = _vs.value
	_follow = _vs.value >= _max_scroll() - 2.0
	_bar_hot = 1.4
	_wake()

# ------------------------------------------------------------------ dessin du parchemin

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()

## Contour irrégulier du papier (à `_m` du bord, déformé d'au plus 30 % de `_m`), normales intérieures, fibres, puis place du titre et du texte.
func _rebuild() -> void:
	var s := size
	if s.x < 40.0 or s.y < 40.0 or text == null:
		_poly = PackedVector2Array()
		return
	_m = clampf(minf(s.x, s.y) * 0.05, 6.0, 14.0)
	var a := _m * 0.3
	var nz := FastNoiseLite.new()
	nz.seed = 11
	nz.frequency = 0.05
	_poly = PackedVector2Array()
	_nrm = PackedVector2Array()
	var x0 := _m
	var y0 := _m
	var x1 := s.x - _m
	var y1 := s.y - _m
	for edge in [[Vector2(x0, y0), Vector2(x1, y0), Vector2(0, 1)], [Vector2(x1, y0), Vector2(x1, y1), Vector2(-1, 0)],
			[Vector2(x1, y1), Vector2(x0, y1), Vector2(0, -1)], [Vector2(x0, y1), Vector2(x0, y0), Vector2(1, 0)]]:
		var p0: Vector2 = edge[0]
		var p1: Vector2 = edge[1]
		var n: Vector2 = edge[2]
		var steps := maxi(4, roundi(p0.distance_to(p1) / 9.0))
		for i in steps:
			var p := p0.lerp(p1, float(i) / float(steps))
			_poly.append(p + n * nz.get_noise_2d(p.x, p.y) * a)
			_nrm.append(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_fibers.clear()
	var k := _m / 8.0
	for i in 110:
		var c := Vector2(rng.randf_range(x0 + a + 3.0, x1 - a - 3.0), rng.randf_range(y0 + a + 3.0, y1 - a - 3.0))
		var ang := rng.randf() * TAU
		var d := Vector2(cos(ang), sin(ang)) * rng.randf_range(5.0, 16.0) * k
		_fibers.append([c, c + d, rng.randf_range(0.05, 0.12)])
	# zone du titre (fixe, hors défilement) : marge en haut, titre centré, filet décoratif, puis un vrai blanc avant le premier événement
	var tw := s.x - 2.0 * (_m + 12.0)
	_title_h = clampf(s.y * 0.075, 9.0, UiMetrics.rem(0.8))
	var f := Atlas.title_font(true, 1)
	while _title_h > 8.0 and f.get_string_size(_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(_title_h)).x > tw * 0.8:
		_title_h -= 1.0
	_title_y = _m + a + maxf(s.y * 0.03, 6.0) + _title_h
	_rule_y = _title_y + _title_h * 0.55
	var top := _rule_y + maxf(s.y * 0.035, 7.0)
	var xm := maxf(_m * 2.9, _m + a + 14.0)      # marge gauche : laisse la place du symbole et reste hors des coins roulés
	var ym := _m + a + maxf(s.y * 0.04, 7.0)    # marge basse : la dernière ligne ne touche pas le bord irrégulier
	text.position = Vector2(xm, top)
	text.size = Vector2(maxf(10.0, s.x - 2.0 * xm), maxf(10.0, s.y - top - ym))
	var gx := s.x - xm + (xm - _m - a - 4.0 * k) * 0.5 - 1.5      # couloir du curseur : au milieu de la marge droite
	_gutter = Rect2(gx, top + 2.0, 3.0, maxf(10.0, s.y - top - ym - 4.0))
	_hist.size = Vector2(22, 22)
	_hist.position = Vector2(s.x - _m - a - 24.0, _m + a + 2.0)
	_hist.visible = s.x > 150.0
	queue_redraw()

func _title() -> String:
	return L.t("ui.atlas.journal").to_upper()

func _inset(d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _poly.size():
		out.append(_poly[i] + _nrm[i] * d)
	return out

func _tex_poly(pts: PackedVector2Array, tint: Color, tex: Texture2D, scale_px: float = 300.0) -> void:
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for p in pts:
		cols.append(tint.lerp(tint.darkened(0.1), clampf(p.y / maxf(1.0, size.y), 0.0, 1.0)))      # papier un peu plus sombre vers le bas
		uvs.append(p / scale_px)
	draw_polygon(pts, cols, uvs, tex)

func _draw() -> void:
	if _poly.size() < 8:
		return
	var k := _m / 8.0
	var off := Vector2(_m * 0.32, _m * 0.38)
	var sh := PackedVector2Array()
	for p in _poly:
		sh.append(p + off)
	draw_colored_polygon(sh, Color(0.05, 0.03, 0.01, 0.42))      # ombre portée : à l'intérieur du rectangle (déformation + décalage < marge)
	_tex_poly(_poly, Color(0.66, 0.5, 0.3), _paper)             # bord vieilli, plus brun
	_tex_poly(_inset(1.6 * k), Color(0.82, 0.68, 0.46), _paper)
	var inner := _inset(3.6 * k)
	_tex_poly(inner, Color(1, 1, 1), _paper)
	_tex_poly(inner, Color(1, 1, 1, 0.7), _stain, 420.0)        # taches de vieillissement
	_tex_poly(inner, Color(1, 1, 1, 0.85), _mottle, 520.0)      # nuages clairs et sombres : le centre du papier n'est plus uniforme
	for f in _fibers:
		draw_line(f[0], f[1], Color(0.4, 0.28, 0.12, f[2]), 1.0, true)
	_corners(k)
	_title_draw(k)
	_bar_draw()

## Curseur de défilement : filet bronze dans la marge droite, sans fond ni cadre, visible seulement quand le journal dépasse.
func _bar_draw() -> void:
	if _bar_a <= 0.01 or not _can_scroll():
		return
	var h := _gutter.size.y
	var th := clampf(h * _vs.page / maxf(1.0, _vs.max_value), 16.0, h)
	var ty := _gutter.position.y + (h - th) * (_vs.value / maxf(1.0, _max_scroll()))
	draw_line(Vector2(_gutter.position.x + 1.5, _gutter.position.y), Vector2(_gutter.position.x + 1.5, _gutter.end.y), Color(0.35, 0.24, 0.1, 0.16 * _bar_a), 1.0)
	_bar_style.bg_color = Color(0.42, 0.28, 0.1, 0.9 * _bar_a)
	draw_style_box(_bar_style, Rect2(_gutter.position.x, ty, 3.0, th))

func _corners(k: float) -> void:
	var c := _m * 2.1
	var a := _m * 0.3
	var pts := [[Vector2(_m + a, _m + a), Vector2(1, 1)], [Vector2(size.x - _m - a, _m + a), Vector2(-1, 1)],
			[Vector2(size.x - _m - a, size.y - _m - a), Vector2(-1, -1)], [Vector2(_m + a, size.y - _m - a), Vector2(1, -1)]]
	for e in pts:
		var p: Vector2 = e[0]
		var d: Vector2 = e[1]
		var u := Vector2(d.x, 0)
		var v := Vector2(0, d.y)
		var tri := PackedVector2Array([p + v * c, p + u * c, p + (u + v) * c * 0.6])
		var shadow := PackedVector2Array([p + v * c * 1.02 + u * 2.0, p + u * c * 1.02 + v * 2.0, p + (u + v) * c * 0.62 + (u + v) * 1.5])
		draw_colored_polygon(shadow, Color(0.3, 0.2, 0.08, 0.3))
		draw_colored_polygon(tri, Color(0.94, 0.88, 0.7))      # pli : revers du papier, plus clair
		draw_polyline(PackedVector2Array([p + v * c, p + (u + v) * c * 0.6, p + u * c]), Color(0.36, 0.25, 0.1, 0.55), 1.0, true)

func _title_draw(k: float) -> void:
	var f := Atlas.title_font(true, 1)
	var fs := int(_title_h)
	var t := _title()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := _title_y
	var cx := size.x * 0.5
	draw_string(f, Vector2(cx - w * 0.5, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TITLE_COL)
	# filet à l'encre sous le titre, qui s'estompe vers les bords, avec un losange au centre
	var ry := _rule_y
	var half := minf(size.x * 0.5 - _m - 14.0, w * 0.5 + 40.0)
	for i in 12:
		var t0 := float(i) / 12.0
		var t1 := float(i + 1) / 12.0
		var al := 0.65 * (1.0 - t0 * 0.85)
		draw_line(Vector2(cx - half * t1, ry), Vector2(cx - half * t0, ry), Color(0.33, 0.22, 0.1, al), 1.0, true)
		draw_line(Vector2(cx + half * t0, ry), Vector2(cx + half * t1, ry), Color(0.33, 0.22, 0.1, al), 1.0, true)
	var dm := 3.0 * maxf(k, 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, ry - dm), Vector2(cx + dm, ry), Vector2(cx, ry + dm), Vector2(cx - dm, ry)]), Color(0.52, 0.12, 0.08))
