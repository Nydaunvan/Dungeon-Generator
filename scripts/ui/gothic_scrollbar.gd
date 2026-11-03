class_name GothicScrollBar
extends Control
## Ascenseur « bronze ancien » des fenêtres gothiques, le même que celui du carnet : rail brun à filet d'or vieilli, pointes en losange,
## curseur sculpté avec reflet. Il se lie à un ScrollContainer (dont la barre native est masquée), se glisse à la souris, se clique
## sur le rail, et ne s'affiche que si le contenu dépasse (il s'estompe au repos).

var scroll: ScrollContainer
var _bar: VScrollBar
var _drag := false
var _drag_dy := 0.0
var _alpha := 0.0
var _hover := false

static func attach(sc: ScrollContainer) -> GothicScrollBar:
	var b := GothicScrollBar.new()
	b.scroll = sc
	return b

func _init() -> void:
	custom_minimum_size = Vector2(16, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)

func _ready() -> void:
	_bar = scroll.get_v_scroll_bar()
	_bar.custom_minimum_size.x = 0.0
	_bar.modulate = Color(1, 1, 1, 0)
	for n in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed", "increment", "decrement", "increment_highlight", "decrement_highlight", "increment_pressed", "decrement_pressed"]:
		_bar.add_theme_stylebox_override(n, StyleBoxEmpty.new())
	_bar.changed.connect(queue_redraw)
	_bar.value_changed.connect(func(_v: float): queue_redraw())
	set_process(true)

func _can_scroll() -> bool:
	return _bar != null and _bar.max_value - _bar.page > 2.0

func _max_scroll() -> float:
	return maxf(0.0, _bar.max_value - _bar.page)

func _process(dt: float) -> void:
	var target := 1.0 if (_can_scroll() and (_hover or _drag)) else (0.55 if _can_scroll() else 0.0)
	var na := move_toward(_alpha, target, dt * 4.0)
	if absf(na - _alpha) > 0.001:
		_alpha = na
		queue_redraw()

func _rail() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 4.0, 10.0), Vector2(8.0, maxf(1.0, size.y - 20.0)))

func _thumb() -> Rect2:
	var r := _rail()
	var th := clampf(r.size.y * _bar.page / maxf(1.0, _bar.max_value), minf(26.0, r.size.y), r.size.y)
	var ty := r.position.y + (r.size.y - th) * (_bar.value / maxf(1.0, _max_scroll()))
	return Rect2(Vector2(r.position.x, ty), Vector2(r.size.x, th))

func _gui_input(ev: InputEvent) -> void:
	if not _can_scroll():
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var t := _thumb()
			if t.grow(4.0).has_point(mb.position):
				_drag = true
				_drag_dy = mb.position.y - t.position.y
			else:
				_set_from_y(mb.position.y - _thumb().size.y * 0.5)
				_drag = true
				_drag_dy = _thumb().size.y * 0.5
		else:
			_drag = false
		accept_event()
	elif mb != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		scroll.scroll_vertical += (-60 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 60)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		_set_from_y((ev as InputEventMouseMotion).position.y - _drag_dy)
		accept_event()

func _set_from_y(y: float) -> void:
	var r := _rail()
	var th := _thumb().size.y
	var k := clampf((y - r.position.y) / maxf(1.0, r.size.y - th), 0.0, 1.0)
	scroll.scroll_vertical = int(k * _max_scroll())

func _draw() -> void:
	if _alpha <= 0.01 or not _can_scroll():
		return
	var a := clampf(_alpha, 0.0, 1.0)
	var r := _rail()
	var cx := r.get_center().x
	var top := r.position.y
	var bot := r.end.y
	draw_line(Vector2(cx, top), Vector2(cx, bot), Color(0.22, 0.14, 0.06, 0.85 * a), 5.0, true)          # rail
	draw_line(Vector2(cx - 1.8, top), Vector2(cx - 1.8, bot), Color(0.85, 0.66, 0.3, 0.45 * a), 1.2, true)   # filet d'or vieilli
	for yy in [top - 4.0, bot + 4.0]:      # pointes en losange aux deux bouts
		var d := 7.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx, yy - d), Vector2(cx + d * 0.75, yy), Vector2(cx, yy + d), Vector2(cx - d * 0.75, yy)]), Color(0.5, 0.34, 0.13, a))
	var t := _thumb()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.bg_color = Color(0.5, 0.34, 0.14, a) if not _drag else Color(0.62, 0.44, 0.18, a)
	sb.border_color = Color(0.17, 0.1, 0.04, a)
	sb.set_border_width_all(1)
	draw_style_box(sb, t.grow_individual(3.0, 0.0, 3.0, 0.0))
	var tw := t.size.x + 6.0
	var x0 := t.position.x - 3.0
	draw_line(Vector2(x0 + tw * 0.28, t.position.y + 3.0), Vector2(x0 + tw * 0.28, t.end.y - 3.0), Color(0.93, 0.76, 0.4, 0.75 * a), 1.2, true)   # reflet
	draw_line(Vector2(x0 + tw * 0.78, t.position.y + 3.0), Vector2(x0 + tw * 0.78, t.end.y - 3.0), Color(0.24, 0.14, 0.05, 0.55 * a), 1.0, true)   # ombre
	if t.size.y >= 26.0:      # losange sculpté au centre du curseur
		var c := t.get_center()
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4.5), c + Vector2(3.4, 0), c + Vector2(0, 4.5), c + Vector2(-3.4, 0)]), Color(0.9, 0.72, 0.36, a))
