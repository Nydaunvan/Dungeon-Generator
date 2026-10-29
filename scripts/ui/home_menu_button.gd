class_name HomeMenuButton
extends Control
## Bouton de la page d'accueil « Atlas Noir » : médaillon à icône, titre en capitales fines, sous-titre, flèche.
## `primary` : version mise en avant (filet ambre double, halo, repère losange à gauche) ; `compact` : petit bouton d'outil (icône + texte).
## Les dimensions se règlent sur la hauteur du contrôle (`u`), donc le bouton suit l'échelle de la scène.

signal pressed

var title: String = "":
	set(v):
		title = v
		queue_redraw()
var sub: String = "":
	set(v):
		sub = v
		queue_redraw()
var icon_name: String = ""
var primary: bool = false
var compact: bool = false

var _hover: bool = false
var _down: bool = false
var _slide: float = 0.0         # 0 → 1 : la flèche avance au survol

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func():
		_down = false
		_set_hover(false))

func _set_hover(on: bool) -> void:
	_hover = on
	create_tween().tween_method(func(v: float):
		_slide = v
		queue_redraw(), _slide, 1.0 if on else 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		queue_redraw()
	else:
		var was := _down
		_down = false
		queue_redraw()
		if was and Rect2(Vector2.ZERO, size).has_point(mb.position):
			pressed.emit()
	accept_event()

func _draw() -> void:
	var h := size.y
	var u := h / (50.0 if compact else (120.0 if primary else 105.0))
	var hot := _hover or primary
	var amber := Atlas.AMBER
	var copper := Atlas.COPPER
	var border: Color = amber if hot else copper
	var top := Color("17130e", 0.86)
	var bot := Color("0c0a08", 0.9)
	if _hover:
		top = top.lightened(0.06)
		bot = bot.lightened(0.06)
	if _down:
		top = top.darkened(0.2)
		bot = bot.darkened(0.2)
	var r := Rect2(Vector2.ZERO, size)
	var cut := (6.0 if compact else 10.0) * u
	var corners := Vector4(0, 1, 0, 1)
	if primary:
		# halo ambre autour du cadre principal
		for i in 4:
			var g := r.grow((i + 1) * 2.2 * u)
			var line := Atlas.chamfer(g, cut + (i + 1) * 2.2 * u, corners)
			line.append(line[0])
			draw_polyline(line, Color(amber, 0.16 - i * 0.035), 2.0 * u, true)
	Atlas.draw_box(self, r, top, bot, Color(border, 1.0 if hot else 0.8), (1.8 if primary else 1.2) * u, cut, corners)
	if primary:
		var inner := Atlas.chamfer(r.grow(-6.0 * u), cut * 0.7, corners)
		inner.append(inner[0])
		draw_polyline(inner, Color(amber, 0.45), 1.0 * u, true)
		Atlas.draw_diamond(self, Vector2(0.0, h * 0.5), 6.0 * u, amber)
		Atlas.draw_diamond(self, Vector2(0.0, h * 0.5), 3.0 * u, Color("17130e"))
	var ivory := Color("f1dfb8") if hot else Atlas.IVORY
	if compact:
		var px := int(roundf(22.0 * u))
		if icon_name != "" and GameIcons.has(icon_name):
			var tex := GameIcons.tex(icon_name, px, ivory, 1.5)
			draw_texture(tex, Vector2(14.0 * u, (h - px) * 0.5))
		var f := Atlas.font(Atlas.F_BODY)
		var fs := int(roundf(15.0 * u))
		var x := 56.0 * u
		draw_string(f, Vector2(x, h * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 8.0 * u, fs, ivory)
		return
	# médaillon à icône
	var rad := (36.0 if primary else 34.0) * u
	var c := Vector2(29.0 * u + rad, h * 0.5)
	draw_circle(c, rad, Color("0a0806", 0.92), true, -1.0, true)
	draw_arc(c, rad, 0.0, TAU, 64, Color(amber if hot else copper, 0.95), 1.3 * u, true)
	draw_arc(c, rad - 4.0 * u, 0.0, TAU, 64, Color(Atlas.COPPER_DIM, 0.8), 1.0 * u, true)
	if icon_name != "" and GameIcons.has(icon_name):
		var ip := int(roundf(rad * 1.15))
		draw_texture(GameIcons.tex(icon_name, ip, ivory, 1.6), c - Vector2(ip, ip) * 0.5)
	# textes
	var tx := c.x + rad + 30.0 * u
	var tfs := int(roundf((26.0 if primary else 25.0) * u))
	var sfs := int(roundf(16.0 * u))
	var tf := Atlas.title_font(false, int(roundf(2.5 * u)))
	var sf := Atlas.font(Atlas.F_BODY)
	var th := tf.get_height(tfs)
	var sh := sf.get_height(sfs)
	var gap := 5.0 * u
	var y0 := (h - (th + gap + sh)) * 0.5
	var avail := size.x - tx - 56.0 * u
	draw_string(tf, Vector2(tx, y0 + tf.get_ascent(tfs)), title, HORIZONTAL_ALIGNMENT_LEFT, avail, tfs, ivory)
	draw_string(sf, Vector2(tx, y0 + th + gap + sf.get_ascent(sfs)), sub, HORIZONTAL_ALIGNMENT_LEFT, avail, sfs, Color(Atlas.IVORY_DIM, 0.95))
	# flèche à droite (avance de quelques pixels au survol)
	var ax := size.x - 40.0 * u + 5.0 * u * _slide
	var ay := h * 0.5
	var acol := amber if hot else ivory
	draw_line(Vector2(ax - 10.0 * u, ay), Vector2(ax + 10.0 * u, ay), acol, 1.5 * u, true)
	draw_polyline(PackedVector2Array([Vector2(ax + 4.0 * u, ay - 6.0 * u), Vector2(ax + 10.0 * u, ay), Vector2(ax + 4.0 * u, ay + 6.0 * u)]), acol, 1.5 * u, true)
