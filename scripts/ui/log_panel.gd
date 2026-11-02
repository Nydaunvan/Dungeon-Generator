class_name LogPanel
extends Control
## Carnet : journal de partie (suit GameState.log_lines) sur le parchemin `assets/ui/journal_parchment.png` (fond graphique SEUL : le titre, les messages et la barre de
## défilement sont dessinés ici). L'image est découpée en 5 × 3 tranches : les coins, le rubis et l'ornement du bas gardent leur forme (échelle uniforme),
## seules les parties unies (bords, papier, filet) s'étirent, donc le rectangle du panneau ne change jamais. Rien ne le dépasse (le contrôle rogne son contenu).
## Titre « JOURNAL DES ÉVÉNEMENTS » au-dessus du filet et du rubis. Cliquer sur le rubis ouvre l'historique complet.
## Les nouveaux événements s'écrivent caractère par caractère (RichTextLabel.visible_characters) ; l'historique complet reste dans le texte, dans l'ordre.
## Une file d'attente absorbe les rafales : plus il y a de retard, plus l'écriture accélère, jusqu'à tout afficher d'un coup. Purement visuel :
## ne touche ni à la journalisation, ni au jeu, ni aux sauvegardes.

signal history_pressed

const INK := "#34271C"             # texte normal
const INK_HIT := "#74231B"         # dégâts et pièges (assombri : #8D3028 manquait de contraste sur le papier)
const INK_GOLD := "#5F3F07"        # XP et récompenses (assombri : #936719 virait au clair, contraste 2,6 contre 5,3 maintenant)
const TITLE_COL := Color("38271B")
const TEX := preload("res://assets/ui/journal_parchment.png")
## Dimensions et repères de l'image (pixels de la source, 1437 × 1094).
const SW := 1437.0
const SH := 1094.0
const XS := [0.0, 240.0, 650.0, 790.0, 1197.0, 1437.0]      # colonnes : coin | bord étirable | rubis | bord étirable | coin
const YS := [0.0, 240.0, 854.0, 1094.0]                        # lignes : haut (filet et rubis) | milieu | bas (ornement)
const FIXED_X := [true, false, true, false, true]               # colonnes à l'échelle uniforme (les autres s'étirent)
const FIXED_Y := [true, false, true]
const TXT_L := 168.0               # zone du texte, en pixels de la source : sous le filet et le rubis, dans le papier clair
const TXT_R := 1212.0
const TXT_T := 238.0
const TXT_B := 930.0
const BAR_X := 1262.0              # axe de la barre de défilement : marge droite du papier, entre le texte et le cadre doré
const BAR_T := 244.0
const BAR_B := 846.0
const TITLE_TOP := 96.0            # le titre tient entre le cadre du haut et le sommet du rubis
const TITLE_BASE := 142.0
const TITLE_X0 := 262.0            # largeur disponible du titre, entre les ornements d'angle
const TITLE_X1 := 1175.0
const RUBY := Rect2(660.0, 146.0, 120.0, 74.0)                 # rubis et ses pointes (zone cliquable : historique)
const MS_PER_CHAR_DEFAULT := 0.020
const BACKLOG_FAST := 90           # au-delà de ce retard (en caractères), l'écriture accélère
const BACKLOG_INSTANT := 520       # au-delà, tout s'affiche d'un coup

var text: RichTextLabel
var ms_per_char := MS_PER_CHAR_DEFAULT      # secondes par caractère (15 à 25 ms demandés), réglable
var _m := 0.0                      # échelle uniforme de l'image (pixels d'écran par pixel de la source)
var _pieces: Array = []            # [source Rect2, destination Rect2] des 15 tranches
var _title_h := 0.0
var _title_y := 0.0                # ligne de base du titre
var _rule_y := 0.0                 # filet décoratif de l'image : le texte commence plus bas
var _ruby := Rect2()               # rubis (clic : historique complet)
var _ruby_btn: Button
var _ruby_hot := false
var _shown := 0
var _target := 0
var _acc := 0.0
var _gold_re := RegEx.new()
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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC      # l'image (1437 px) s'affiche environ 5 fois plus petite : mipmaps
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
	_ruby_btn = Button.new()      # zone cliquable transparente sur le rubis
	_ruby_btn.flat = true
	_ruby_btn.focus_mode = Control.FOCUS_NONE
	_ruby_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_ruby_btn.tooltip_text = L.t("ui.game_layout.historique_complet_du_journal")
	for n in ["normal", "hover", "pressed", "focus", "disabled"]:
		_ruby_btn.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	_ruby_btn.pressed.connect(func(): history_pressed.emit())
	_ruby_btn.mouse_entered.connect(func():
		_ruby_hot = true
		queue_redraw())
	_ruby_btn.mouse_exited.connect(func():
		_ruby_hot = false
		queue_redraw())
	add_child(_ruby_btn)
	for l in gs.log_lines:
		_add_line(l, false, true)
	_shown = _target
	_apply_visible()
	gs.log_added.connect(func(line: String, hit: bool): _add_line(line, hit, false))
	set_process(false)
	_rebuild()

# ------------------------------------------------------------------ événements et écriture progressive

func _line_style(line: String, hit: bool) -> Array:
	if hit:
		return [INK_HIT, INK_HIT, true]
	if _gold_re.search(line) != null:
		return [INK_GOLD, INK_GOLD, false]
	return [INK, INK, false]

var _icon_re: RegEx

## Une ligne du journal : ✦, puis le texte ; chaque « @icon:identifiant » (icônes illustrées de sorts, talents, classes…) devient une petite image
## dans la ligne (ou, sans illustration, l'emoji de repli), au lieu du texte brut.
func _add_line(line: String, hit: bool, instant: bool) -> void:
	var st := _line_style(line, hit)
	if _icon_re == null:
		_icon_re = RegEx.new()
		_icon_re.compile("@icon:[A-Za-z0-9_\\-]+")
	var gap := "[font_size=%d]\n[/font_size]" % SPACER_PX if text.get_total_character_count() > 0 else ""      # très léger écart entre deux événements
	text.append_text("%s[color=%s]✦[/color]  " % [gap, st[0]])
	var fs := text.get_theme_font_size("normal_font_size")
	var pos := 0
	for m in _icon_re.search_all(line):
		_add_segment(line.substr(pos, m.get_start() - pos), st)
		var tok := m.get_string()
		var tex := IconResolver.texture(tok)
		if tex != null and tex.get_height() > 0:
			var hpx := int(float(fs) * 1.35)
			text.add_image(tex, int(float(hpx) * float(tex.get_width()) / float(tex.get_height())), hpx, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		else:
			_add_segment(AdminUtil.icon_text_fallback(tok), st)
		pos = m.get_end()
	_add_segment(line.substr(pos), st)
	text.append_text("\n")
	_target = text.get_total_character_count()
	_follow = true      # chaque nouvel événement ramène le journal tout en bas, même si le joueur était remonté dans l'historique
	_smoothing = false
	if instant or not is_visible_in_tree() or _target - _shown > BACKLOG_INSTANT:      # panneau caché ou rafale trop longue : tout apparaît d'un coup
		_shown = _target
		_apply_visible()
	else:
		set_process(true)
	if not instant:
		_wake()      # suivi du bas pendant que la ligne s'écrit

func _add_segment(seg: String, st: Array) -> void:
	if seg == "":
		return
	var body := "[color=%s]%s[/color]" % [st[1], seg.replace("[", "[lb]")]
	if st[2]:
		body = "[b]%s[/b]" % body
	text.append_text(body)

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
			var n := int(_acc / ms_per_char)
			_acc -= float(n) * ms_per_char
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

## Correspondance entre un repère de la source et l'écran : les colonnes et lignes « fixes » gardent l'échelle uniforme `_m`, les autres absorbent le reste.
func _map(src: float, edges: Array, fixed: Array, total_dst: float, k: float, sstretch: float) -> float:
	var acc := 0.0
	for i in fixed.size():
		var a: float = edges[i]
		var b: float = edges[i + 1]
		var sc: float = k if fixed[i] else sstretch
		if src <= b:
			return acc + (src - a) * sc
		acc += (b - a) * sc
	return total_dst

## Découpe l'image en 5 × 3 tranches, place le titre, le texte, la barre de défilement et la zone cliquable du rubis.
func _rebuild() -> void:
	var s := size
	if s.x < 60.0 or s.y < 60.0 or text == null:
		_pieces.clear()
		return
	var k := minf(s.x / SW, s.y / SH)
	_m = k
	var fx := 0.0      # largeur source des colonnes étirables / hauteur des lignes étirables
	for i in FIXED_X.size():
		if not FIXED_X[i]:
			fx += XS[i + 1] - XS[i]
	var fy := 0.0
	for i in FIXED_Y.size():
		if not FIXED_Y[i]:
			fy += YS[i + 1] - YS[i]
	var fixed_w := SW - fx
	var fixed_h := SH - fy
	var sx := (s.x - fixed_w * k) / fx
	var sy := (s.y - fixed_h * k) / fy
	_pieces.clear()
	for j in 3:
		for i in 5:
			var src := Rect2(XS[i], YS[j], XS[i + 1] - XS[i], YS[j + 1] - YS[j])
			var x0 := _map(XS[i], XS, FIXED_X, s.x, k, sx)
			var x1 := _map(XS[i + 1], XS, FIXED_X, s.x, k, sx)
			var y0 := _map(YS[j], YS, FIXED_Y, s.y, k, sy)
			var y1 := _map(YS[j + 1], YS, FIXED_Y, s.y, k, sy)
			# léger recouvrement des tranches voisines : pas de fil clair entre deux morceaux
			_pieces.append([src, Rect2(x0, y0, x1 - x0 + (0.5 if i < 4 else 0.0), y1 - y0 + (0.5 if j < 2 else 0.0))])
	var mx := func(v: float) -> float: return _map(v, XS, FIXED_X, s.x, k, sx)
	var my := func(v: float) -> float: return _map(v, YS, FIXED_Y, s.y, k, sy)
	# titre : tient entre le cadre du haut et le sommet du rubis, dans la largeur laissée libre entre les ornements d'angle
	var tw: float = mx.call(TITLE_X1) - mx.call(TITLE_X0)
	_title_y = my.call(TITLE_BASE)
	_title_h = floorf((my.call(TITLE_BASE) - my.call(TITLE_TOP)) / 0.74)
	var f := Atlas.title_font(true, 1)
	while _title_h > 7.0 and f.get_string_size(_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(_title_h)).x > tw:
		_title_h -= 1.0
	_rule_y = my.call(183.0)
	var tl: float = mx.call(TXT_L)
	var tt: float = my.call(TXT_T)
	text.position = Vector2(tl, tt)
	text.size = Vector2(maxf(10.0, mx.call(TXT_R) - tl), maxf(10.0, my.call(TXT_B) - tt))
	var bx: float = mx.call(BAR_X)
	var bt: float = my.call(BAR_T)
	_gutter = Rect2(bx - maxf(2.0, 20.0 * k), bt, maxf(4.0, 40.0 * k), maxf(10.0, my.call(BAR_B) - bt))
	var r0 := Vector2(mx.call(RUBY.position.x), my.call(RUBY.position.y))
	_ruby = Rect2(r0, Vector2(mx.call(RUBY.end.x), my.call(RUBY.end.y)) - r0)
	_ruby_btn.position = _ruby.position
	_ruby_btn.size = _ruby.size
	queue_redraw()

func _title() -> String:
	return L.t("ui.atlas.journal").to_upper()

func _draw() -> void:
	if _pieces.is_empty():
		return
	for pc in _pieces:
		draw_texture_rect_region(TEX, pc[1], pc[0])
	if _ruby_hot:      # le rubis s'allume au survol : on peut cliquer dessus pour ouvrir l'historique
		var c := _ruby.get_center() + Vector2(0.0, _ruby.size.y * 0.1)
		for i in 5:
			draw_circle(c, _ruby.size.y * (0.55 - 0.08 * i), Color(1.0, 0.35, 0.2, 0.07))
	_title_draw()
	_bar_draw()

func _title_draw() -> void:
	var f := Atlas.title_font(true, 1)
	var fs := int(_title_h)
	var t := _title()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(size.x * 0.5 - w * 0.5, _title_y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TITLE_COL)

## Barre de défilement : fine pièce de bronze ancien (rail brun à filet doré, pointes en losange, curseur sculpté), dans la marge droite du papier.
## Elle ne se dessine que si le journal dépasse, ne recouvre jamais le texte et ne dépend pas de l'image.
func _bar_draw() -> void:
	if _bar_a <= 0.01 or not _can_scroll():
		return
	var a := clampf(_bar_a + 0.25, 0.0, 1.0)
	var cx := _gutter.get_center().x
	var top := _gutter.position.y
	var h := _gutter.size.y
	var u := maxf(_m * 4.0, 0.9)      # unité : épaisseur du rail
	draw_line(Vector2(cx, top), Vector2(cx, top + h), Color(0.22, 0.14, 0.06, 0.8 * a), u * 1.5, true)      # rail
	draw_line(Vector2(cx - u * 0.45, top), Vector2(cx - u * 0.45, top + h), Color(0.85, 0.66, 0.3, 0.45 * a), maxf(1.0, u * 0.4), true)      # filet d'or vieilli
	for yy in [top - u, top + h + u]:      # pointes en losange aux deux bouts du rail
		var d := u * 2.1
		draw_colored_polygon(PackedVector2Array([Vector2(cx, yy - d), Vector2(cx + d * 0.75, yy), Vector2(cx, yy + d), Vector2(cx - d * 0.75, yy)]), Color(0.5, 0.34, 0.13, a))
	var th := clampf(h * _vs.page / maxf(1.0, _vs.max_value), minf(22.0, h), h)
	var ty := top + (h - th) * (_vs.value / maxf(1.0, _max_scroll()))
	var tw := maxf(5.0, u * 3.4)
	var r := Rect2(cx - tw * 0.5, ty, tw, th)
	_bar_style.set_corner_radius_all(int(maxf(2.0, tw * 0.4)))
	_bar_style.bg_color = Color(0.5, 0.34, 0.14, a)
	_bar_style.border_color = Color(0.17, 0.1, 0.04, a)
	_bar_style.set_border_width_all(1)
	draw_style_box(_bar_style, r)
	draw_line(Vector2(r.position.x + tw * 0.28, r.position.y + 2.0), Vector2(r.position.x + tw * 0.28, r.end.y - 2.0), Color(0.93, 0.76, 0.4, 0.75 * a), maxf(1.0, tw * 0.16), true)      # reflet
	draw_line(Vector2(r.position.x + tw * 0.76, r.position.y + 2.0), Vector2(r.position.x + tw * 0.76, r.end.y - 2.0), Color(0.24, 0.14, 0.05, 0.55 * a), maxf(1.0, tw * 0.14), true)      # ombre
	if th >= 20.0:      # petit losange sculpté au centre du curseur
		var c := r.get_center()
		var d := tw * 0.42
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d * 0.7, 0), c + Vector2(0, d), c + Vector2(-d * 0.7, 0)]), Color(0.9, 0.72, 0.36, a))
