extends Control
## Maquettes de fenêtres « gothic Atlas Noir » avec effets Godot (shaders canvas_item, particules, tweens) : godot --path . res://tools/proto_ui_gothic.tscn -- style=a|b|c out=/chemin/nom [frames=14]
## Écrit <out>_NN.png (images espacées dans le temps, pour animer). Maquette de proposition : jamais chargée par le jeu.

const W := 540.0
const H := 780.0
const ARCH := 150.0
var style := "a"
var panel: Control
var shape: PackedVector2Array
var fx: Array = []        # [ShaderMaterial]
var _t := 0.0
var _rune_t := 0.0
var _border: Control
var _reveal_mat: ShaderMaterial

func _lancet() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := ARCH
	var steps := 28
	for i in steps + 1:       # côté gauche : ressaut vertical puis courbe jusqu'à la clé
		var u := float(i) / float(steps)
		var p0 := Vector2(0, s)
		var p1 := Vector2(0, s * 0.42)
		var p2 := Vector2(W * 0.33, s * 0.40)
		var p3 := Vector2(W * 0.5, 0)
		var q := p0 * pow(1 - u, 3) + p1 * 3 * pow(1 - u, 2) * u + p2 * 3 * (1 - u) * u * u + p3 * pow(u, 3)
		pts.append(q)
	for i in range(steps - 1, -1, -1):
		pts.append(Vector2(W - pts[i].x, pts[i].y))
	var c := 18.0      # pieds : angles coupés
	pts.append(Vector2(W, H - c))
	pts.append(Vector2(W - c, H))
	pts.append(Vector2(c, H))
	pts.append(Vector2(0, H - c))
	return pts

func _uvs(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x / W, p.y / H))
	return out

## Calque dessiné dans la forme de la fenêtre avec un shader.
func _layer(shader: String, params: Dictionary = {}, rect: Rect2 = Rect2(0, 0, W, H), clip_to_shape: bool = true) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ui/%s.gdshader" % shader)
	for k in params:
		m.set_shader_parameter(k, params[k])
	c.material = m
	var origin := rect.position
	c.draw.connect(func():
		if clip_to_shape and rect.size == Vector2(W, H):
			c.draw_polygon(shape, PackedColorArray([Color.WHITE]), _uvs(shape))
		else:
			c.draw_rect(Rect2(Vector2.ZERO, rect.size), Color.WHITE)
		)
	panel.add_child(c)
	fx.append(m)
	return c

func _font(bold: bool = false) -> Font:
	return UiTheme.font(UiTheme.F_TITLE_BOLD if bold else UiTheme.F_BODY)

func _label(parent: Control, text: String, size: int, col: Color, font_path: String = UiTheme.F_BODY, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _bar(parent: Control, name: String, v: float, col: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := _label(h, name, 14, Color("b9a880"))
	l.custom_minimum_size = Vector2(120, 0)
	var back := Control.new()
	back.custom_minimum_size = Vector2(0, 14)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.draw.connect(func():
		back.draw_rect(Rect2(Vector2.ZERO, back.size), Color(0, 0, 0, 0.55))
		back.draw_rect(Rect2(Vector2(1, 1), Vector2((back.size.x - 2) * v, back.size.y - 2)), col)
		back.draw_rect(Rect2(Vector2(1, 1), Vector2((back.size.x - 2) * v, 3)), Color(1, 1, 1, 0.22))
		back.draw_rect(Rect2(Vector2.ZERO, back.size), Color("5a4630"), false, 1.0))
	h.add_child(back)
	var r := _label(h, "%d" % int(v * 100.0), 14, Color("f5ecd8"), UiTheme.F_BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	r.custom_minimum_size = Vector2(34, 0)
	parent.add_child(h)

func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	var st := IronBox.modal_styles(true)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	b.add_theme_color_override("font_color", Color("ffd88a"))
	parent.add_child(b)
	# effet de survol : léger gonflement et halo (tween), démonstration par un survol simulé
	b.mouse_entered.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2(1.02, 1.02), 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "modulate", Color(1.25, 1.12, 0.9), 0.12))
	b.mouse_exited.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12)
		tw.tween_property(b, "modulate", Color.WHITE, 0.12))
	return b

func _content() -> void:
	var m := MarginContainer.new()
	m.position = Vector2(34, ARCH * 0.62 if style != "b" else ARCH + 6.0)
	m.size = Vector2(W - 68.0, H - 60.0 - m.position.y)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var title_col := Color("ffd88a")
	_label(v, "COMPÉTENCE VIVANTE", 22, title_col, UiTheme.F_TITLE_BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var sep := ColorRect.new()
	sep.color = Color("a9793a")
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	_label(v, "Lumière Sacrée", 26, Color("e8b45c"), UiTheme.F_TITLE_BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(v, "Thane · Attachée · 38", 15, Color("b9a880"), UiTheme.F_BODY_ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	_bar(v, "Affinité", 0.38, Color("35b8c8"))
	_bar(v, "Agressivité", 0.23, Color("a88a5c"))
	_bar(v, "Prudence", 0.24, Color("a88a5c"))
	_bar(v, "Instabilité", 0.59, Color("e8b45c"))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap2)
	_label(v, "ÉVOLUTIONS", 15, Color("e8b45c"), UiTheme.F_TITLE)
	_label(v, "✦ Témérité — frappe plus fort tant que le porteur tient debout, mais lui coûte quelques PV.", 14, Color("f5ecd8"))
	_label(v, "· Acharnement — plus forte contre une cible blessée de moitié.", 14, Color("8f7f60"))
	_label(v, "· Précision — perce mieux les résistances d'une cible unique.", 14, Color("8f7f60"))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_button(v, "ÉVEILLER : TÉMÉRITÉ")
	_button(v, "FERMER").modulate = Color(1, 1, 1, 0.9)

func _border_static(col: Color, w: float) -> void:
	_border = Control.new()
	_border.size = Vector2(W, H)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.draw.connect(func():
		var closed := shape.duplicate()
		closed.append(shape[0])
		_border.draw_polyline(closed, Color(0, 0, 0, 0.9), w + 4.0, true)
		_border.draw_polyline(closed, col, w, true)
		# second filet intérieur (meneau) : le contour réduit vers le centre
		var inner := PackedVector2Array()
		var c := Vector2(W * 0.5, H * 0.55)
		for p in closed:
			inner.append(c + (p - c) * Vector2(1.0 - 16.0 / W, 1.0 - 16.0 / H))
		_border.draw_polyline(inner, col.darkened(0.45), 1.5, true)
		# lueur de rune qui court le long du contour
		var n := closed.size()
		var run := int(n * 0.12)
		var start := int(_rune_t * float(n)) % n
		for i in run:
			var a := closed[(start + i) % n]
			var b := closed[(start + i + 1) % n]
			var k: float = 1.0 - absf(float(i) / float(run) * 2.0 - 1.0)
			_border.draw_line(a, b, Color(1.0, 0.86, 0.5, 0.15 * k), 9.0 * k + 2.0, true)
			_border.draw_line(a, b, Color(1.0, 0.95, 0.75, 0.9 * k), 2.0, true))
	panel.add_child(_border)
	# clous et pierres d'angle
	for p in [Vector2(14, H - 28), Vector2(W - 14, H - 28), Vector2(W * 0.5, 14)]:
		var s := ColorRect.new()
		s.color = Color("c8a24a")
		s.size = Vector2(8, 8)
		s.position = p - Vector2(4, 4)
		s.rotation = PI * 0.25
		s.pivot_offset = Vector2(4, 4)
		panel.add_child(s)

func _build() -> void:
	panel = Control.new()
	panel.size = Vector2(W, H)
	panel.position = (get_viewport_rect().size - Vector2(W, H)) * 0.5
	panel.pivot_offset = Vector2(W * 0.5, H)
	add_child(panel)
	shape = _lancet()
	match style:
		"a":
			_layer("stone")
			_layer("mist", {"strength": 0.32})
			_layer("candle", {"center": Vector2(0.14, 0.97), "radius": 0.55, "strength": 0.55, "phase": 0.0})
			_layer("candle", {"center": Vector2(0.88, 0.97), "radius": 0.5, "strength": 0.45, "phase": 2.1})
			_layer("candle", {"center": Vector2(0.5, 0.02), "radius": 0.25, "strength": 0.3, "col": Color(0.55, 0.7, 1.0), "phase": 4.0})
			_border_static(Color("a9793a"), 2.5)
		"b":
			_layer("stone", {"base_a": Color(0.05, 0.06, 0.09), "base_b": Color(0.11, 0.13, 0.18), "vignette": 0.9})
			var rose := Control.new()
			rose.position = Vector2(W * 0.5 - 62.0, 24.0)
			rose.size = Vector2(124, 124)
			var rm := ShaderMaterial.new()
			rm.shader = load("res://assets/shaders/ui/rose.gdshader")
			rose.material = rm
			rose.draw.connect(func(): rose.draw_rect(Rect2(Vector2.ZERO, rose.size), Color.WHITE))
			panel.add_child(rose)
			fx.append(rm)
			_layer("rays", {"strength": 0.3})
			_layer("candle", {"center": Vector2(0.5, 0.08), "radius": 0.45, "strength": 0.35, "col": Color(0.9, 0.6, 0.3), "phase": 1.0})
			var dust := CPUParticles2D.new()
			dust.position = Vector2(W * 0.5, H * 0.55)
			dust.amount = 48
			dust.lifetime = 7.0
			dust.preprocess = 7.0
			dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			dust.emission_rect_extents = Vector2(W * 0.45, H * 0.4)
			dust.direction = Vector2(0.2, -1.0)
			dust.spread = 25.0
			dust.gravity = Vector2.ZERO
			dust.initial_velocity_min = 4.0
			dust.initial_velocity_max = 12.0
			dust.scale_amount_min = 1.0
			dust.scale_amount_max = 2.6
			dust.color = Color(1.0, 0.86, 0.55, 0.55)
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			dust.material = cm
			panel.add_child(dust)
			_border_static(Color("c8a24a"), 2.0)
		"c":
			var l := _layer("chart", {"aspect": W / H})
			_reveal_mat = l.material
			_layer("candle", {"center": Vector2(0.5, 1.0), "radius": 0.7, "strength": 0.28, "phase": 0.5})
			_border_static(Color("8f6a3a"), 2.0)
			# sceau de cire
			var seal := Control.new()
			seal.position = Vector2(W - 78.0, 18.0)
			seal.size = Vector2(52, 52)
			seal.draw.connect(func():
				seal.draw_circle(Vector2(26, 26), 24.0, Color("5a0f12"))
				seal.draw_circle(Vector2(26, 26), 19.0, Color("7a1a1c"))
				seal.draw_arc(Vector2(26, 26), 14.0, 0, TAU, 24, Color("a83a36"), 1.5)
				seal.draw_string(UiTheme.font(UiTheme.F_TITLE_BOLD), Vector2(14, 33), "AN", HORIZONTAL_ALIGNMENT_CENTER, 24.0, 17, Color("d9a09a")))
			panel.add_child(seal)
	_content()
	# ouverture : la fenêtre se déploie depuis le bas, avec un éclair de lumière froide
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.94, 0.9)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(dt: float) -> void:
	_t += dt
	_rune_t = fmod(_rune_t + dt * 0.14, 1.0)
	if _border != null:
		_border.queue_redraw()
	if _reveal_mat != null:
		_reveal_mat.set_shader_parameter("reveal", clampf(_t / 1.8, 0.0, 1.0))
		var mp := (get_viewport().get_mouse_position() / get_viewport_rect().size - Vector2(0.5, 0.5))
		_reveal_mat.set_shader_parameter("parallax", Vector2(sin(_t * 0.5), cos(_t * 0.4)) * 0.6 + mp)

func _ready() -> void:
	var a := {"style": "a", "out": "/tmp/proto", "frames": "14", "w": "1280", "h": "900"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	style = str(a.style)
	get_window().size = Vector2i(int(a.w), int(a.h))
	await get_tree().process_frame
	var bg := ColorRect.new()
	bg.color = Color("0b0a09")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build()
	for i in int(a.frames):
		await get_tree().create_timer(0.2).timeout
		get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [a.out, i])
	get_tree().quit()
