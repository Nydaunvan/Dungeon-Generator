class_name FloatingTip
extends CanvasLayer
## Infobulle de l'original (.floating-tip / .tip-item::after) : fiche sombre à filet or doublé d'un contour, posée AU-DESSUS
## de l'élément survolé (centrée, 10 px d'écart), repliée en dessous s'il n'y a pas la place, toujours dans l'écran.
## Elle lit le `tooltip_text` du contrôle survolé (ou du premier parent qui en a un) ; l'infobulle native est désactivée.

var _panel: PanelContainer
var _halo: Panel
var _label: Label
var _target: Control = null
var _text: String = ""
var _rect_key: Rect2 = Rect2()

func _init() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS

## Fond de l'infobulle : ombre portée, contour #3a2a12 décalé de 2 px, filet or, dégradé radial sombre.
class TipBox extends StyleBox:
	func _init() -> void:
		content_margin_left = 12.0
		content_margin_right = 12.0
		content_margin_top = 9.0
		content_margin_bottom = 9.0
	func _rr(ci: RID, rect: Rect2, radius: float, col: Color) -> void:
		var p := PackedVector2Array()
		var rr := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
		for c in [[rect.end - Vector2(rr, rr), 0.0], [Vector2(rect.position.x + rr, rect.end.y - rr), PI * 0.5], [rect.position + Vector2(rr, rr), PI], [Vector2(rect.end.x - rr, rect.position.y + rr), PI * 1.5]]:
			for i in 6:
				var a: float = c[1] + float(i) / 5.0 * PI * 0.5
				p.append(c[0] + Vector2(cos(a), sin(a)) * rr)
		RenderingServer.canvas_item_add_polygon(ci, p, PackedColorArray([col]))
	func _draw(ci: RID, rect: Rect2) -> void:
		for i in 7:   # ombre douce (0 8px 22px rgba(0,0,0,.7))
			var e := 4.0 + i * 2.6
			_rr(ci, Rect2(rect.position + Vector2(-e, -e + 6.0), rect.size + Vector2(e, e) * 2.0), 6.0 + e, Color(0, 0, 0, 0.085))
		_rr(ci, rect.grow(3.0), 7.0, Color("3a2a12"))
		_rr(ci, rect.grow(2.0), 6.0, Color("120c06"))
		_rr(ci, rect, 4.0, Color("e8b45c"))
		var inner := rect.grow(-1.0)
		var n := 12
		for i in n:
			var t := float(i) / float(n - 1)
			var c := Color("241a0f").lerp(Color("120c06"), clampf(t / 0.85, 0.0, 1.0))
			RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + 1.0, inner.position.y + inner.size.y * i / n, inner.size.x - 2.0, inner.size.y / n + 0.6), c)
	func _get_minimum_size() -> Vector2:
		return Vector2(24.0, 18.0)

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", TipBox.new())
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("font_color", Color("efe1c2"))
	_panel.add_child(_label)
	add_child(_panel)
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec", 9999.0)

func _tip_owner(c: Control) -> Control:
	var n: Node = c
	while n is Control:
		if (n as Control).tooltip_text != "":
			return n as Control
		n = n.get_parent()
	return null

func _process(_d: float) -> void:
	var vp := get_viewport()
	var hov: Control = vp.gui_get_hovered_control() if vp != null else null
	var owner_c: Control = _tip_owner(hov) if hov != null else null
	if owner_c == null or not owner_c.is_visible_in_tree() or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_hide()
		return
	var rk: Rect2 = owner_c.get_meta("tip_rect", Rect2())
	if owner_c == _target and owner_c.tooltip_text == _text and rk == _rect_key:
		return
	_target = owner_c
	_text = owner_c.tooltip_text
	_rect_key = rk
	_show(owner_c)

func _hide() -> void:
	_target = null
	_text = ""
	if _panel != null:
		_panel.visible = false

func _show(c: Control) -> void:
	var fs := int(round(UiMetrics.rem(0.7)))
	var font := UiTheme.font(UiTheme.F_BODY)
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", fs)
	_label.add_theme_constant_override("line_spacing", int(round(1.55 * fs - font.get_height(fs))))
	_label.text = _text
	var maxw := UiMetrics.css(215.0) - 24.0
	# largeur : celle du texte le plus long, plafonnée à 215 px
	var natural := 0.0
	for line in _text.split("\n"):
		natural = maxf(natural, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	_label.custom_minimum_size = Vector2(minf(natural + 2.0, maxw), 0)
	_panel.reset_size()
	_panel.visible = true
	_panel.modulate.a = 0.0
	await get_tree().process_frame
	if _target != c or not is_instance_valid(c):
		return
	_panel.reset_size()
	var r := c.get_global_rect()
	if c.has_meta("tip_rect"):
		r = c.get_meta("tip_rect")      # zone précise (case de la mini-carte, par exemple)
	var view := get_viewport().get_visible_rect().size
	var sz := _panel.size
	var top := r.position.y - sz.y - 10.0
	if top < 4.0:
		top = r.end.y + 10.0
	var left := clampf(r.position.x + r.size.x * 0.5 - sz.x * 0.5, 4.0, maxf(4.0, view.x - sz.x - 4.0))
	top = minf(top, view.y - sz.y - 4.0)
	_panel.position = Vector2(left, top)
	_panel.modulate.a = 1.0
