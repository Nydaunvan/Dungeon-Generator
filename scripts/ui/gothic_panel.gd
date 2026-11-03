class_name GothicPanel
extends PanelContainer
## Panneau « Gothic Atlas Noir » : fenêtre en arc brisé (lancette), pierre d'ardoise, bougies, brume, faisceaux et poussières dorées,
## traits d'atlas qui se tracent à l'encre à l'ouverture, filet doré dont une rune lumineuse fait le tour, compas du logo en emblème.
## Tout est dessiné par des shaders 2D (canvas_item) et des particules CPU : compatible GL Compatibility et export Web.
## `Settings.reduced_motion` : plus aucune animation continue (calques fixes seulement).

const LOGO := "res://assets/home/logo_atlas_noir.png"
const GOLD := Color("c8a24a")
const BRONZE := Color("a9793a")

var body: VBoxContainer
var title_label: Label
var arch: float = 130.0
var _shape := PackedVector2Array()
var _layers: Array[Control] = []
var _anim_layers: Array[Control] = []
var _border: Control
var _lines_mat: ShaderMaterial
var _stone_mat: ShaderMaterial
var _watermark: TextureRect
var _dust: CPUParticles2D
var _help: Button
var _overlay: Control      # calque libre au-dessus du contenu (le conteneur étire ses enfants directs, pas ceux-ci)
var _t := 0.0
var _rune_t := 0.0
var _animated := true

static func logo_compass() -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(LOGO)
	at.region = Rect2(435, 20, 670, 670)
	return at

func _init(title: String = "") -> void:
	_animated = not Settings.reduced_motion
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	clip_contents = true   # le filigrane qui tourne ne déborde jamais du cadre
	_layer("stone", {})
	_stone_mat = _layers[0].material
	_lines_mat = _layer("atlas_lines", {"aspect": 0.7}).material
	_layer("candle", {"center": Vector2(0.1, 0.99), "radius": 0.5, "strength": 0.5, "phase": 0.0}, true)
	_layer("candle", {"center": Vector2(0.9, 0.99), "radius": 0.45, "strength": 0.4, "phase": 2.1}, true)
	_layer("candle", {"center": Vector2(0.5, 0.0), "radius": 0.22, "strength": 0.22, "col": Color(0.55, 0.7, 1.0), "phase": 4.0}, true)
	_layer("rays", {"strength": 0.13, "col": Color(1.0, 0.82, 0.55)}, true)
	_layer("mist", {"strength": 0.22, "col": Color(0.55, 0.55, 0.6)}, true)
	# compas du logo en filigrane, lent tour sur lui-même (additif : le noir du logo disparaît)
	_watermark = TextureRect.new()
	_watermark.texture = logo_compass()
	_watermark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_watermark.stretch_mode = TextureRect.STRETCH_SCALE
	_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watermark.modulate = Color(1, 1, 1, 0.1)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_watermark.material = cm
	add_child(_watermark)
	if _animated:
		_dust = CPUParticles2D.new()
		_dust.amount = 36
		_dust.lifetime = 7.0
		_dust.preprocess = 7.0
		_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_dust.direction = Vector2(0.2, -1.0)
		_dust.spread = 25.0
		_dust.gravity = Vector2.ZERO
		_dust.initial_velocity_min = 4.0
		_dust.initial_velocity_max = 12.0
		_dust.scale_amount_min = 1.0
		_dust.scale_amount_max = 2.4
		_dust.color = Color(1.0, 0.86, 0.55, 0.5)
		var dm := CanvasItemMaterial.new()
		dm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_dust.material = dm
		add_child(_dust)
	_border = Control.new()
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.draw.connect(_draw_border)
	add_child(_border)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	margin.add_child(v)
	var emblem := TextureRect.new()
	emblem.texture = load(LOGO)       # logo entier (compas et titre), petit ; additif : le fond noir de l'image s'efface
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(0, 72)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var em := CanvasItemMaterial.new()
	em.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emblem.material = em
	v.add_child(emblem)
	title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fv := FontVariation.new()
	fv.base_font = UiTheme.font(UiTheme.F_TITLE_BOLD)
	fv.spacing_glyph = 1
	title_label.add_theme_font_override("font", fv)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("ffd88a"))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.visible = title != ""
	v.add_child(title_label)
	var sep := ColorRect.new()
	sep.color = BRONZE
	sep.custom_minimum_size = Vector2(0, 2)
	sep.visible = title != ""
	v.add_child(sep)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	v.add_child(body)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	set_process(_animated)

## Petit « ? » doré dans l'arc, à droite : ouvre l'explication de la fenêtre dans le guide.
func add_help_button(tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = "?"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(30, 30)
	for k in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0a0806", 0.9) if k == "normal" else Color("1b1610")
		sb.border_color = BRONZE if k == "normal" else Color("e5ae52")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(15)
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("ffd88a"))
	b.add_theme_color_override("font_hover_color", Color("fff0c8"))
	b.pressed.connect(cb)
	_overlay.add_child(b)
	_help = b
	_place_help()

func _place_help() -> void:
	if _help != null:
		_help.position = Vector2(size.x - 56.0, arch * 0.5 + 8.0)

func _layer(shader: String, params: Dictionary, animated: bool = false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ui/%s.gdshader" % shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	c.material = m
	c.draw.connect(func():
		if _shape.size() > 2:
			var uv := PackedVector2Array()
			for p in _shape:
				uv.append(Vector2(p.x / maxf(size.x, 1.0), p.y / maxf(size.y, 1.0)))
			c.draw_polygon(_shape, PackedColorArray([Color.WHITE]), uv))
	if animated and not _animated:
		c.visible = false
	add_child(c)
	_layers.append(c)
	return c

## Contour en lancette : épaules verticales puis ogive jusqu'à la clé, pieds à pans coupés.
func _make_shape() -> void:
	var w := size.x
	var h := size.y
	arch = clampf(w * 0.24, 70.0, 150.0)
	var pts := PackedVector2Array()
	var steps := 26
	for i in steps + 1:
		var u := float(i) / float(steps)
		var p0 := Vector2(0, arch)
		var p1 := Vector2(0, arch * 0.42)
		var p2 := Vector2(w * 0.33, arch * 0.4)
		var p3 := Vector2(w * 0.5, 0)
		pts.append(p0 * pow(1 - u, 3) + p1 * 3 * pow(1 - u, 2) * u + p2 * 3 * (1 - u) * u * u + p3 * pow(u, 3))
	for i in range(steps - 1, -1, -1):
		pts.append(Vector2(w - pts[i].x, pts[i].y))
	var c := 16.0
	pts.append(Vector2(w, h - c))
	pts.append(Vector2(w - c, h))
	pts.append(Vector2(c, h))
	pts.append(Vector2(0, h - c))
	_shape = pts

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	_make_shape()
	for l in _layers:
		l.position = Vector2.ZERO
		l.size = size
		l.queue_redraw()
	_border.position = Vector2.ZERO
	_border.size = size
	_lines_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_stone_mat.set_shader_parameter("blocks", Vector2(roundf(size.x / 108.0), roundf(size.y / 70.0)))
	var wm := minf(size.x * 0.9, size.y * 0.7)
	_watermark.size = Vector2(wm, wm)
	_watermark.position = Vector2((size.x - wm) * 0.5, arch * 0.55 + (size.y - arch * 0.55 - wm) * 0.5)
	_watermark.pivot_offset = _watermark.size * 0.5
	if _dust != null:
		_dust.position = size * Vector2(0.5, 0.55)
		_dust.emission_rect_extents = Vector2(size.x * 0.42, size.y * 0.38)
	_place_help()
	_border.queue_redraw()

func _draw_border() -> void:
	if _shape.size() < 3:
		return
	var closed := _shape.duplicate()
	closed.append(_shape[0])
	_border.draw_polyline(closed, Color(0, 0, 0, 0.9), 6.5, true)
	_border.draw_polyline(closed, BRONZE, 2.5, true)
	# second filet intérieur (meneau)
	var c := Vector2(size.x * 0.5, size.y * 0.55)
	var inner := PackedVector2Array()
	for p in closed:
		inner.append(c + (p - c) * Vector2(1.0 - 14.0 / size.x, 1.0 - 14.0 / size.y))
	_border.draw_polyline(inner, BRONZE.darkened(0.45), 1.5, true)
	# clous : clé de l'arc et pieds
	for p in [Vector2(size.x * 0.5, 12), Vector2(12, size.y - 26), Vector2(size.x - 12, size.y - 26)]:
		var d := PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
		_border.draw_colored_polygon(d, GOLD)
	# rune lumineuse qui court le long du contour
	if _animated:
		var n := closed.size()
		var run := int(n * 0.12)
		var start := int(_rune_t * float(n)) % n
		for i in run:
			var a := closed[(start + i) % n]
			var b := closed[(start + i + 1) % n]
			var k: float = 1.0 - absf(float(i) / float(run) * 2.0 - 1.0)
			_border.draw_line(a, b, Color(1.0, 0.86, 0.5, 0.15 * k), 9.0 * k + 2.0, true)
			_border.draw_line(a, b, Color(1.0, 0.95, 0.75, 0.9 * k), 2.0, true)

func _process(dt: float) -> void:
	_t += dt
	_rune_t = fmod(_rune_t + dt * 0.14, 1.0)
	_border.queue_redraw()
	_watermark.rotation = _t * 0.035
	var rev := clampf(_t / 1.6, 0.0, 1.0)
	_lines_mat.set_shader_parameter("reveal", rev)
	var mp := get_local_mouse_position() / maxf(size.x, 1.0) - Vector2(0.5, 0.5)
	_lines_mat.set_shader_parameter("parallax", Vector2(sin(_t * 0.5), cos(_t * 0.4)) * 0.5 + mp.clamp(Vector2(-1, -1), Vector2(1, 1)))

func _ready() -> void:
	if not _animated:
		_lines_mat.set_shader_parameter("reveal", 1.0)
