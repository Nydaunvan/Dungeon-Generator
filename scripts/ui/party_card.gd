class_name PartyCard
extends Control
## Carte de personnage « en dôme » de l'original : cadre bronze riveté, anneaux rentrants, ruban de classe à queue d'aronde,
## chaînes, avatar rond (anneau neutre, or si actif), nom / classe / niveau + coffre, barres PV / endurance / XP.
## Toutes les cotes viennent du CSS mesuré à 288 x 258 px ; elles sont mises à l'échelle avec la taille réelle de la carte.

signal pressed
signal chest_pressed
signal context

const BASE_W := 288.0
const BASE_H := 258.0

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
	chest.tooltip_text = "Inventaire de ce héros"
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

## px CSS d'origine -> px de conception, à l'échelle de la carte
func u(v: float) -> float:
	return UiMetrics.css(v * f)

func _dome_h() -> float:
	return u(99.0)

func _layout() -> void:
	f = clampf(minf(size.x / UiMetrics.css(BASE_W), size.y / UiMetrics.css(BASE_H)), 0.2, 2.2) if UiMetrics.css(BASE_W) > 0.0 else 1.0
	# f est un rapport de tailles de conception ; u() reconvertit en px CSS d'origine, il faut donc f relatif au CSS :
	var dome := _dome_h()
	var d := u(76.0)
	var cx := size.x * 0.5
	pic.size = Vector2(d, d)
	pic.position = Vector2(cx - d * 0.5, dome - u(7.0) - d)
	badge.add_theme_font_size_override("font_size", maxi(7, int(u(11.0))))
	badge.size = Vector2(minf(size.x * 0.8, u(120.0)), u(15.0))
	badge.position = Vector2(cx - badge.size.x * 0.5, pic.position.y + d - u(14.0))
	var pad := u(14.0)
	var w := size.x - pad * 2.0
	_put(name_lbl, pad, u(104.0), w, u(26.0), 23.4)
	_put(cls_lbl, pad, u(129.0), w, u(22.0), 17.5)
	# rangée icône de classe / niveau / coffre, centrée
	var ico := u(28.0)
	var ch := u(27.0)
	lvl_lbl.add_theme_font_size_override("font_size", maxi(7, int(u(18.0))))
	var lfont := lvl_lbl.get_theme_font("font")
	var lw := lfont.get_string_size(lvl_lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(7, int(u(18.0)))).x + 2.0
	var gap := u(8.0)
	var total := ico + gap + lw + gap * 0.5 + ch
	var x0 := cx - total * 0.5
	var ry := u(153.0)
	cls_ico.size = Vector2(ico, ico)
	cls_ico.position = Vector2(x0, ry + (u(26.0) - ico) * 0.5)
	lvl_lbl.size = Vector2(lw, u(26.0))
	lvl_lbl.position = Vector2(x0 + ico + gap, ry)
	chest.size = Vector2(ch, ch)
	chest.position = Vector2(x0 + ico + gap + lw + gap * 0.5, ry + (u(26.0) - ch) * 0.5)
	var bx := u(12.0)
	var bw := size.x - bx * 2.0
	_bar_at(hp, bx, u(183.0), bw, u(24.0), 15.5)
	_bar_at(sta, bx, u(210.0), bw, u(18.0), 11.5)
	_bar_at(xp, bx, u(232.0), bw, u(17.0), 11.0)
	_bar_at(gauge, bx, size.y - u(9.0), bw, u(5.0), 1.0)
	dead_lbl.size = Vector2(size.x, u(40.0))
	dead_lbl.position = Vector2(0, dome * 0.5 + u(10.0))
	dead_lbl.add_theme_font_size_override("font_size", maxi(9, int(u(28.0))))

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

func _shape(r: Rect2, inset: float, rtop_y: float, rbot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 := r.position.x + inset
	var x1 := r.end.x - inset
	var y0 := r.position.y + inset
	var y1 := r.end.y - inset
	var rx := (x1 - x0) * 0.5
	var ry := maxf(1.0, rtop_y - inset)
	var cx := (x0 + x1) * 0.5
	var rb := maxf(1.0, rbot - inset)
	var n := 40
	for i in n + 1:
		var a := PI - PI * float(i) / float(n)
		pts.append(Vector2(cx + rx * cos(a), y0 + ry - ry * sin(a)))
	for i in 7:
		var a2 := float(i) / 6.0 * PI * 0.5
		pts.append(Vector2(x1 - rb + rb * cos(a2), y1 - rb + rb * sin(a2)))
	for i in 7:
		var a3 := PI * 0.5 + float(i) / 6.0 * PI * 0.5
		pts.append(Vector2(x0 + rb + rb * cos(a3), y1 - rb + rb * sin(a3)))
	return pts

func _stroke(pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	draw_polyline(p, col, w, true)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var ryt := u(44.0)
	var rbt := u(6.0)
	var bw := maxf(1.0, u(3.0))
	# ombre portée + lueur de la carte active
	if active:
		for g in [[10.0, 0.10], [6.0, 0.16], [3.0, 0.28]]:
			_stroke(_shape(r, -g[0] * 0.3 * f, ryt + g[0] * 0.3, rbt), Color(0.91, 0.71, 0.36, g[1]), u(g[0]))
	var outer := _shape(r, 0.0, ryt, rbt)
	draw_colored_polygon(outer, Color("070504"))
	var face := _shape(r, bw, ryt, rbt)
	# dégradé vertical #1d1610 -> #0a0705
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
	# anneaux rentrants : 2 px #5a4630 (or si actif), 3 px #1a140e, 1 px #070504
	var t1 := maxf(1.0, u(2.0))
	var t2 := maxf(1.0, u(3.0))
	var t3 := maxf(1.0, u(1.0))
	_stroke(_shape(r, bw + t1 * 0.5, ryt, rbt), Color("e8b45c") if active else (Color("a9793a") if targetable else Color("5a4630")), t1)
	_stroke(_shape(r, bw + t1 + t2 * 0.5, ryt, rbt), Color("1a140e"), t2)
	_stroke(_shape(r, bw + t1 + t2 + t3 * 0.5, ryt, rbt), Color("070504"), t3)
	# séparateur haut du cartouche (border-top 2 px #070504 + reflet 1 px #3a2e21)
	var dome := _dome_h()
	var sep_h := maxf(1.0, u(2.0))
	draw_rect(Rect2(bw, dome, size.x - bw * 2.0, sep_h), Color("070504"))
	draw_rect(Rect2(bw, dome + sep_h, size.x - bw * 2.0, maxf(1.0, u(1.0))), Color("3a2e21"))
	# cartouche : voile sombre qui s'estompe
	for i in 6:
		draw_rect(Rect2(bw, dome + sep_h + u(1.0) + i * u(9.0), size.x - bw * 2.0, u(9.0)), Color(0, 0, 0, 0.4 * (1.0 - i / 6.0) * 0.6))
	# chaînes : à 13 % et 87 % (haut -17 px, 9 x 26 px) puis chaîne centrale au-dessus de l'avatar
	var cw := u(9.0)
	var chain := UiMetrics.tex("chain", Vector2(cw / UiMetrics.css(1.0), cw / UiMetrics.css(1.0) * 1.5))
	var ch_h := u(26.0)
	for x in [size.x * 0.13, size.x * 0.87 - cw]:
		_tile_v(chain, Vector2(x, -u(17.0)), Vector2(cw, ch_h))
	var cw2 := u(8.0)
	var chain2 := UiMetrics.tex("chain", Vector2(cw2 / UiMetrics.css(1.0), cw2 / UiMetrics.css(1.0) * 1.5))
	var ay := pic.position.y
	_tile_v(chain2, Vector2(size.x * 0.5 - cw2 * 0.5, ay - u(4.0) - u(40.0)), Vector2(cw2, u(40.0)))
	# anneau de l'avatar : 2 px #070504, 2 px bronze (or si actif), 1 px #070504
	var c := pic.position + pic.size * 0.5
	var rad := pic.size.x * 0.5
	var ring_col: Color = ring_override if ring_override.a > 0.0 else (Color("e8b45c") if active else Color("5a4630"))
	draw_circle(c, rad + u(5.0), Color("070504"))
	draw_circle(c, rad + u(4.0), ring_col)
	draw_circle(c, rad + u(2.0), Color("070504"))
	if active:
		for g in [[12.0, 0.10], [8.0, 0.16], [5.0, 0.26]]:
			draw_arc(c, rad + u(5.0) + u(g[0]) * 0.5, 0.0, TAU, 48, Color(0.91, 0.71, 0.36, g[1]), u(g[0]))
	draw_circle(c, rad, Color("0c0906"))
	# ruban de classe (54 % de large, 18 px, queue d'aronde) — dessiné avant l'image : l'avatar ne le recouvre pas
	var rw := size.x * 0.54
	var rh := u(18.0)
	var rx0 := size.x * 0.5 - rw * 0.5
	var ry0 := -u(9.0)
	var poly := PackedVector2Array([Vector2(rx0, ry0), Vector2(rx0 + rw, ry0), Vector2(rx0 + rw * 0.92, ry0 + rh * 0.5), Vector2(rx0 + rw, ry0 + rh), Vector2(rx0, ry0 + rh), Vector2(rx0 + rw * 0.08, ry0 + rh * 0.5)])
	var shadow := PackedVector2Array()
	for p in poly:
		shadow.append(p + Vector2(0, u(2.0)))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.6))
	var rc := PackedColorArray()
	for p in poly:
		var t := clampf((p.y - ry0) / rh, 0.0, 1.0)
		var col := accent.lerp(Color.WHITE, 0.18 * (1.0 - t)).lerp(Color.BLACK, 0.3 * t)
		rc.append(col)
	draw_polygon(poly, rc)
	var font := UiTheme.font(UiTheme.F_BODY)
	var fs := maxi(6, int(u(12.6)))
	var gs_ := font.get_string_size("⚔", HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(size.x * 0.5 - gs_.x * 0.5, ry0 + rh * 0.5 + gs_.y * 0.3), "⚔", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f0d9b0"))
	if dead:
		draw_colored_polygon(face, Color(0.55, 0.08, 0.08, 0.6))

func _tile_v(tex: Texture2D, pos: Vector2, sz: Vector2) -> void:
	var th := tex.get_height() / UiMetrics.s
	var y := pos.y + sz.y
	while y > pos.y:
		var h := minf(th, y - pos.y)
		draw_texture_rect_region(tex, Rect2(pos.x, y - h, sz.x, h), Rect2(0, tex.get_height() - h * UiMetrics.s, tex.get_width(), h * UiMetrics.s))
		y -= th
