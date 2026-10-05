class_name PartyCard
extends Control
## Carte de personnage compacte (bandeau horizontal) : cadre bronze à anneaux, liseré de classe, avatar rond (anneau neutre,
## or si actif), nom / classe, niveau + coffre, barres PV / endurance, fine barre d'XP et jauge de tour.
## Les détails (stats, XP exacte, statuts, équipement) sont dans l'infobulle au survol (`tooltip_text`).
## Cotes en px CSS pour une carte de 88 px de haut ; elles suivent la hauteur réelle.

signal pressed
signal chest_pressed
signal context

const BASE_H := 88.0

var char_id: String = ""
var accent: Color = Color("a33")
var active: bool = false
var targetable: bool = false
var dead: bool = false
var ring_override: Color = Color(0, 0, 0, 0)    # anneau teinté par un statut (sinon neutre / or)
var f: float = 1.0

var pic: TextureRect
var badge: Label
var name_lbl: Label
var cls_lbl: Label
var lvl_lbl: Label
var cls_ico: TextureRect
var chest: Button
var hp: TextBar
var sta: TextBar
var xp: TextBar
var gauge: TextBar
var dead_lbl: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	clip_contents = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(40, 40)
	pic = TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.material = UiTheme.circle_material()
	add_child(pic)
	badge = Label.new()
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	badge.add_theme_stylebox_override("normal", UiTheme.box(Color(0.05, 0.03, 0.02, 0.85), Color("6b4a24"), 1, 6))
	add_child(badge)
	name_lbl = _label(UiTheme.F_TITLE_BOLD, Color("f5ecd8"))
	cls_lbl = _label(UiTheme.F_BODY_ITALIC, Color("a9793a"))
	lvl_lbl = _label(UiTheme.F_BODY_BOLD, Color("f5ecd8"))
	cls_ico = TextureRect.new()
	cls_ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cls_ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cls_ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cls_ico)
	chest = Button.new()
	chest.flat = true
	chest.focus_mode = Control.FOCUS_NONE
	chest.icon = UiTheme.tex("chest")
	chest.expand_icon = true
	chest.tooltip_text = L.t("ui.party_card.inventaire_de_ce_heros")
	chest.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		chest.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	chest.add_theme_color_override("icon_hover_color", Color(1.25, 1.15, 0.95))
	chest.pressed.connect(func(): chest_pressed.emit())
	add_child(chest)
	hp = _bar(UiTheme.HP_GREEN)
	sta = _bar(UiTheme.STA_CYAN)
	xp = _bar(Color("4a90c2"))
	gauge = _bar(UiTheme.GOLD)
	dead_lbl = _label(UiTheme.F_TITLE_BOLD, Color.WHITE)
	dead_lbl.text = "Mort"
	dead_lbl.visible = false
	dead_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	dead_lbl.add_theme_constant_override("outline_size", 4)

func _label(font_path: String, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.font(font_path))
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _bar(col: Color) -> TextBar:
	var b := TextBar.new(col, 10, 10)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			context.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()

## px CSS (carte de 88 px de haut) -> px de conception, à l'échelle de la carte
func u(v: float) -> float:
	return UiMetrics.css(v * f)

func _layout() -> void:
	f = clampf(size.y / UiMetrics.css(BASE_H), 0.4, 2.4) if UiMetrics.css(BASE_H) > 0.0 else 1.0
	var d := u(62.0)
	pic.size = Vector2(d, d)
	pic.position = Vector2(u(13.0), (size.y - d) * 0.5)
	var x0 := u(86.0)
	var right := size.x - u(11.0)
	# pastille de statut : à cheval sur le bas de l'avatar
	badge.add_theme_font_size_override("font_size", maxi(7, int(u(10.5))))
	badge.size = Vector2(minf(u(92.0), size.x * 0.42), u(14.0))
	badge.position = Vector2(pic.position.x + d * 0.5 - badge.size.x * 0.5, pic.position.y + d - u(9.0))
	# rangée haute à droite : icône de classe, niveau, coffre
	var ico := u(18.0)
	var ch := u(21.0)
	lvl_lbl.add_theme_font_size_override("font_size", maxi(7, int(u(14.0))))
	var lfont := lvl_lbl.get_theme_font("font")
	var lw := lfont.get_string_size(lvl_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(7, int(u(14.0)))).x + 2.0
	var gap := u(4.0)
	var ry := u(7.0)
	chest.size = Vector2(ch, ch)
	chest.position = Vector2(right - ch, ry + (u(19.0) - ch) * 0.5)
	lvl_lbl.size = Vector2(lw, u(19.0))
	lvl_lbl.position = Vector2(chest.position.x - gap - lw, ry)
	cls_ico.size = Vector2(ico, ico)
	cls_ico.position = Vector2(lvl_lbl.position.x - gap - ico, ry + (u(19.0) - ico) * 0.5)
	var name_w := maxf(10.0, cls_ico.position.x - x0 - gap)
	_put(name_lbl, x0, ry, name_w, u(19.0), 16.5)
	_put(cls_lbl, x0, u(26.0), name_w, u(13.0), 11.5)
	for l in [name_lbl, cls_lbl]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bw := right - x0
	_bar_at(hp, x0, u(44.0), bw, u(18.0), 13.0)
	_bar_at(sta, x0, u(64.0), bw, u(12.0), 10.5)
	_bar_at(xp, x0, u(77.0), bw, u(3.0), 1.0)
	_bar_at(gauge, x0, u(80.5), bw, u(3.0), 1.0)
	dead_lbl.size = Vector2(size.x, u(30.0))
	dead_lbl.position = Vector2(0, (size.y - u(30.0)) * 0.5)
	dead_lbl.add_theme_font_size_override("font_size", maxi(9, int(u(22.0))))

func _put(l: Label, x: float, y: float, w: float, h: float, fs: float) -> void:
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.add_theme_font_size_override("font_size", maxi(7, int(u(fs))))

func _bar_at(b: TextBar, x: float, y: float, w: float, h: float, fs: float) -> void:
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.custom_minimum_size = Vector2(0, h)
	b.set_font_size(maxi(1, int(u(fs))))

# ------------------------------------------------------------------ dessin

## Rectangle à coins arrondis, rétréci de `inset`.
func _rr(r: Rect2, inset: float, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x + inset
	var x1 := r.end.x - inset
	var y0 := r.position.y + inset
	var y1 := r.end.y - inset
	var rr := maxf(1.0, rad - inset)
	for c in [[Vector2(x1 - rr, y1 - rr), 0.0], [Vector2(x0 + rr, y1 - rr), PI * 0.5], [Vector2(x0 + rr, y0 + rr), PI], [Vector2(x1 - rr, y0 + rr), PI * 1.5]]:
		for i in 8:
			var a: float = c[1] + float(i) / 7.0 * PI * 0.5
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rr)
	return pts

func _stroke(pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	draw_polyline(p, col, w, true)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rad := u(10.0)
	var bw := maxf(1.0, u(1.5))
	if active:
		for g in [[10.0, 0.10], [6.0, 0.16], [3.0, 0.28]]:
			_stroke(_rr(r, -g[0] * 0.3 * f, rad + g[0] * 0.3), Color(0.91, 0.71, 0.36, g[1]), u(g[0]))
	var outer := _rr(r, 0.0, rad)
	draw_colored_polygon(outer, Color("070504"))
	var face := _rr(r, bw, rad)
	var cols := PackedColorArray()
	for p in face:
		cols.append(Color("1d1610").lerp(Color("0a0705"), clampf(p.y / size.y, 0.0, 1.0)))
	draw_polygon(face, cols)
	var grime := load("res://assets/ui/orig/grime_hd.png") as Texture2D
	if grime != null:
		var uv := PackedVector2Array()
		for p in face:
			uv.append(p / Vector2(grime.get_size()) * UiMetrics.s)
		var gc := PackedColorArray()
		gc.resize(face.size())
		gc.fill(Color(1, 1, 1, 0.9))
		draw_polygon(face, gc, uv, grime)
	var t1 := maxf(1.0, u(2.0))
	var t3 := maxf(1.0, u(1.0))
	_stroke(_rr(r, bw + t1 * 0.5, rad), Color("e8b45c") if active else (Color("a9793a") if targetable else Color("5a4630")), t1)
	_stroke(_rr(r, bw + t1 + t3 * 0.5, rad), Color("070504"), t3)
	# liseré de classe, à gauche
	var sx := bw + t1 + t3 + u(2.0)
	draw_rect(Rect2(sx, u(13.0), maxf(2.0, u(3.0)), size.y - u(26.0)), accent)
	# avatar : anneau neutre, or si actif, teinté par un statut
	var c := pic.position + pic.size * 0.5
	var ar := pic.size.x * 0.5
	var ring_col: Color = ring_override if ring_override.a > 0.0 else (Color("e8b45c") if active else Color("5a4630"))
	draw_circle(c, ar + u(3.5), Color("070504"))
	draw_circle(c, ar + u(2.5), ring_col)
	draw_circle(c, ar + u(1.0), Color("070504"))
	if active:
		for g in [[7.0, 0.10], [5.0, 0.16], [3.0, 0.26]]:
			draw_arc(c, ar + u(3.5) + u(g[0]) * 0.5, 0.0, TAU, 40, Color(0.91, 0.71, 0.36, g[1]), u(g[0]))
	draw_circle(c, ar, Color("0c0906"))
	if dead:
		draw_colored_polygon(face, Color(0.55, 0.08, 0.08, 0.6))
