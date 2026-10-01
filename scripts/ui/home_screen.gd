class_name HomeScreen
extends Control
## Page d'accueil : mur de pierre, arche, sceau « Donjon aléatoire », bannières de quête.
## Paysage : scène fixe 1280×800 mise à l'échelle. Portrait / petit écran : colonne défilante (comme le HTML).

signal action(name: String)
signal nav(name: String)

const SW := 1280.0
const SH := 800.0
const HOME := "res://assets/home/"

var _wall: TextureRect
var _header: AppHeader
var _title_label: Label
var _stage: Control
var _scroll: ScrollContainer
var _column: VBoxContainer
var _scene_bg: TextureRect
var _glow: TextureRect
var _chains: Array = []       # {node, delay}  (chaînes suspendues au-dessus de l'arche, oscillation de ±1,2° sur 5 s)
var _time := 0.0
var _embers: Embers
var _title_box: Control
var _tagline: Label
var _seal: Control
var _banners: Array = []      # {root, height}
var _tuto: Button
var _links: VBoxContainer
var _foot: PanelContainer
var _stacked := false
var _built := false

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()

# ------------------------------------------------------------------ construction

func _tex(name: String) -> Texture2D:
	return load(HOME + name) as Texture2D

func _label(text: String, size: int, color: Color, font_path: String = UiTheme.F_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.font(font_path))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build() -> void:
	_wall = TextureRect.new()
	_wall.texture = UiTheme.tex("bg_tile")
	_wall.stretch_mode = TextureRect.STRETCH_TILE
	_wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wall)

	_stage = Control.new()
	_stage.clip_contents = true
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_column.add_theme_constant_override("separation", 14)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_column)

	_scene_bg = TextureRect.new()
	_scene_bg.texture = _tex("home_bg.png")
	_scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(_scene_bg)
	# chaînes animées (à gauche : avec le crâne ; à droite : avec le crochet, décalée de 1,2 s)
	for spec in [["chain_left.png", 0.0, Vector2(452, 0), Vector2(40, 228)], ["chain_right.png", 1.2, Vector2(948, 0), Vector2(40, 281)]]:
		var ch := TextureRect.new()
		ch.texture = _tex(spec[0])
		ch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ch.stretch_mode = TextureRect.STRETCH_SCALE
		ch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(ch)
		_chains.append({"node": ch, "delay": spec[1], "pos": spec[2], "size": spec[3]})

	# lueur vacillante de la torche
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.62, 0.25, 0.55), Color(1.0, 0.45, 0.1, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_glow = TextureRect.new()
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_stage.add_child(_glow)
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "modulate:a", 0.85, 0.5).set_trans(Tween.TRANS_SINE)

	_embers = Embers.new()
	_stage.add_child(_embers)

	# en-tête
	_header = AppHeader.new()
	_header.set_home_mode(true)
	_header.nav.connect(func(n: String): nav.emit(n))
	_title_label = _header.title_label
	add_child(_header)

	# titre à lettrine
	_title_box = Control.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var full_title := tr("Éditeur de Donjon")
	var cap := _label(full_title.substr(0, 1), 108, Color("f1dfb8"), UiTheme.F_DISPLAY_BOLD)
	cap.name = "cap"
	var rest := _label(full_title.substr(1), 40, Color("f1dfb8"), UiTheme.F_DISPLAY)
	rest.name = "rest"
	for l in [cap, rest]:
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.35, 0.35))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.add_theme_constant_override("shadow_outline_size", 10)
		_title_box.add_child(l)
	_tagline = _label("Créez, Explorez, Survivez", 17, Color("cbb083"), UiTheme.F_BODY_ITALIC)

	_seal = _make_seal()
	_banners = [
		_make_banner("banner_create.png", "Créer votre propre donjon", "Concevoir votre expédition de A à Z", "create", 89.0),
		_make_banner("banner_origin.png", "Le Donjon d'Origine", "La démonstration officielle", "origin", 67.0),
		_make_banner("banner_saves.png", "Sauvegardes", "Reprendre vos 10 parties", "saves", 67.0),
	]
	_tuto = _link("Nouveau ici ? Suivre le tutoriel de création", "tutorial", 13)
	_links = VBoxContainer.new()
	_links.add_theme_constant_override("separation", 5)
	_links.add_child(_link("Charger un donjon depuis un code", "load-code", 13))
	_links.add_child(_link("Importer un fichier JSON", "import-json", 13))

	_foot = PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(20 / 255.0, 14 / 255.0, 7 / 255.0, 0.72)
	fs.border_color = Color(200 / 255.0, 166 / 255.0, 110 / 255.0, 0.35)
	fs.border_width_top = 1
	fs.set_content_margin_all(8)
	_foot.add_theme_stylebox_override("panel", fs)
	var fv := VBoxContainer.new()
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	fv.add_theme_constant_override("separation", 6)
	_foot.add_child(fv)
	var ver := _link(tr("Éditeur de Donjon") + " v1.29 · " + tr("portage Godot"), "changelog", 14)
	ver.alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(ver)
	var made := _label("Made by Claude & Nydaunvan", 13, Color("9c8659"), UiTheme.F_BODY_ITALIC)
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(made)
	_built = true

## Lien texte discret (survol : lueur dorée).
func _link(text: String, act: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("cbb083"))
	b.add_theme_color_override("font_hover_color", Color("f6e4bd"))
	b.add_theme_color_override("font_pressed_color", Color("f6e4bd"))
	b.pressed.connect(func(): action.emit(act))
	return b

func _make_seal() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.focus_mode = Control.FOCUS_NONE
	var pic := TextureRect.new()
	pic.texture = _tex("seal.png")
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pic)
	var t := _label("Donjon\naléatoire", 24, Color("f2ddc4"), UiTheme.F_DISPLAY_BOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.anchor_left = 0.08
	t.anchor_right = 0.92
	t.anchor_top = 127.0 / 280.0
	t.anchor_bottom = 187.0 / 280.0
	root.add_child(t)
	var s := _label("jamais deux fois pareil", 13, Color("e6d6b2"), UiTheme.F_DISPLAY)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.anchor_left = 0.08
	s.anchor_right = 0.92
	s.anchor_top = 191.0 / 280.0
	s.anchor_bottom = 209.0 / 280.0
	s.add_theme_color_override("font_shadow_color", Color(0.1, 0.03, 0.02, 0.9))
	s.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(s)
	var dice := DiceRoller.new()
	dice.name = "dice"
	dice.anchor_left = 0.5
	dice.anchor_right = 0.5
	root.add_child(dice)
	root.resized.connect(func():
		root.pivot_offset = root.size * 0.5
		var f := root.size.x / 280.0
		pic.offset_left = -16.0 * f
		pic.offset_top = -12.0 * f
		pic.offset_right = 16.0 * f
		pic.offset_bottom = 32.0 * f
		var fs := int(round(24.0 * f))
		t.add_theme_font_size_override("font_size", fs)
		t.add_theme_constant_override("line_spacing", int(round(1.25 * fs - UiTheme.font(UiTheme.F_DISPLAY_BOLD).get_height(fs))))
		s.add_theme_font_size_override("font_size", int(round(13.0 * f)))
		var dw := 74.0 * f * 1.0
		dice.size = Vector2(dw, dw * 46.0 / 74.0)
		dice.position = Vector2((root.size.x - dw) * 0.5, root.size.y * (94.0 / 280.0) - dice.size.y * 0.5))
	root.mouse_entered.connect(func():
		dice.roll()
		create_tween().tween_property(root, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	root.mouse_exited.connect(func():
		create_tween().tween_property(root, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	root.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_seal_roll(root)
			root.get_node("dice").roll()
			action.emit("random"))
	return root

## Petit « lancer » du sceau au clic (les dés du HTML roulent au survol).
func _seal_roll(root: Control) -> void:
	var tw := create_tween()
	tw.tween_property(root, "rotation", deg_to_rad(4.0), 0.07)
	tw.tween_property(root, "rotation", deg_to_rad(-3.0), 0.09)
	tw.tween_property(root, "rotation", 0.0, 0.08)

func _make_banner(tex_name: String, title: String, sub: String, act: String, base_h: float) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var vis := Control.new()
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vis)
	var pic := TextureRect.new()
	pic.texture = _tex(tex_name)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.add_child(pic)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.anchor_left = 60.0 / 300.0
	box.anchor_right = 262.0 / 300.0
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	vis.add_child(box)
	var tl := _label(title, 19, Color("f1dfb8"), UiTheme.F_DISPLAY)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sl := _label(sub, 12, Color("c2ab7e"), UiTheme.F_BODY)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tl)
	box.add_child(sl)
	root.resized.connect(func():
		var f := root.size.x / 300.0
		pic.offset_left = -12.0 * f
		pic.offset_top = -8.0 * f
		pic.offset_right = 12.0 * f
		pic.offset_bottom = 8.0 * f
		tl.add_theme_font_size_override("font_size", int(round(19.0 * f)))
		sl.add_theme_font_size_override("font_size", int(round(12.0 * f))))
	root.mouse_entered.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(vis, "position:x", -6.0 * root.size.x / 300.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(vis, "modulate", Color(1.12, 1.1, 1.08), 0.15))
	root.mouse_exited.connect(func():
		var tw := create_tween().set_parallel(true)
		tw.tween_property(vis, "position:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(vis, "modulate", Color.WHITE, 0.15))
	root.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			action.emit(act))
	return {"root": root, "height": base_h}

# ------------------------------------------------------------------ mise en page

func _move(n: Control, parent: Node) -> void:
	if n.get_parent() == parent:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	parent.add_child(n)

## Lettrine « É » + « diteur de Donjon » alignés sur la même ligne de base. Renvoie la taille du bloc.
func _place_title(cap_size: int, rest_size: int, width: float, centered: bool) -> Vector2:
	var font := UiTheme.font(UiTheme.F_DISPLAY_BOLD)
	var font_r := UiTheme.font(UiTheme.F_DISPLAY)
	var cap: Label = _title_box.get_node("cap")
	var rest: Label = _title_box.get_node("rest")
	cap.add_theme_font_size_override("font_size", cap_size)
	rest.add_theme_font_size_override("font_size", rest_size)
	var cap_w := font.get_string_size(cap.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cap_size).x
	var rest_w := font_r.get_string_size(rest.text, HORIZONTAL_ALIGNMENT_LEFT, -1, rest_size).x + 16.0 * 0.01 * rest_size
	var gap := 4.0
	var x0 := maxf(0.0, (width - (cap_w + gap + rest_w)) * 0.5) if centered else 0.0
	var asc_c := font.get_ascent(cap_size)
	var asc_r := font_r.get_ascent(rest_size)
	cap.position = Vector2(x0, 0)
	cap.size = Vector2(cap_w + 2, font.get_height(cap_size))
	rest.position = Vector2(x0 + cap_w + gap, asc_c - asc_r)
	rest.size = Vector2(rest_w + 2, font_r.get_height(rest_size))
	return Vector2(x0 + cap_w + gap + rest_w, asc_c + font.get_descent(cap_size))

func _layout() -> void:
	if not _built:
		return
	var w := size.x
	var h := size.y
	UiMetrics.update(self)
	var mx := UiMetrics.css(30.0 if not UiMetrics.portrait else 6.0)
	var hh := UiMetrics.css(92.0 if not UiMetrics.portrait else 60.0)
	_header.rescale()
	_header.position = Vector2(mx, UiMetrics.css(12.0))
	_header.custom_minimum_size = Vector2(w - mx * 2.0, hh)
	_header.size = Vector2(w - mx * 2.0, hh)
	hh = maxf(hh, _header.get_combined_minimum_size().y) + UiMetrics.css(12.0)
	var area := Rect2(0, hh, w, h - hh)
	var stacked := w < 900.0 or area.size.y < 560.0 or h > w
	if stacked != _stacked or _seal.get_parent() == null:
		_stacked = stacked
		_reparent_all()
	_stage.visible = not stacked
	_scroll.visible = stacked
	if stacked:
		_layout_stacked(area)
	else:
		_layout_stage(area)

func _process(delta: float) -> void:
	_time += delta
	for c in _chains:
		var t := maxf(0.0, _time - float(c.delay))
		(c.node as Control).rotation = deg_to_rad(-1.2 * cos(t * TAU / 5.0))

func _reparent_all() -> void:
	var host: Node = _column if _stacked else _stage
	for n in [_title_box, _tagline, _seal, _banners[0].root, _tuto, _banners[1].root, _banners[2].root, _links, _foot]:
		_move(n, host)
	if _stacked:
		# ordre du HTML empilé : titre, sceau, bannières, liens, pied de page
		var order := [_title_box, _tagline, _seal, _banners[0].root, _tuto, _banners[1].root, _banners[2].root, _links, _foot]
		for i in order.size():
			_column.move_child(order[i], i)

func _layout_stage(area: Rect2) -> void:
	var k := minf(area.size.x / SW, area.size.y / SH)
	var sz := Vector2(SW, SH) * k
	var origin := area.position + (area.size - sz) * 0.5
	# la scène occupe tout l'espace sous l'en-tête ; le mur de fond déborde autour de la scène
	_stage.position = area.position
	_stage.size = area.size
	var off := origin - area.position
	_scene_bg.position = off
	_scene_bg.size = sz
	for c in _chains:
		var cn: TextureRect = c.node
		cn.position = off + (c.pos as Vector2) * k
		cn.size = (c.size as Vector2) * k
		cn.pivot_offset = Vector2(cn.size.x * 0.5, 0.0)
	_embers.position = off
	_embers.size = sz
	_embers.k = k
	_glow.position = off + Vector2(-110, 260) * k
	_glow.size = Vector2(420, 420) * k
	for n in [_seal, _banners[0].root, _banners[1].root, _banners[2].root, _links, _foot, _title_box, _tuto]:
		n.custom_minimum_size = Vector2.ZERO
		n.size_flags_horizontal = Control.SIZE_FILL
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for b in _links.get_children():
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var at := func(n: Control, x: float, y: float, ww: float, hh: float) -> void:
		n.position = off + Vector2(x, y) * k
		n.size = Vector2(ww, hh) * k
	_title_box.position = off + Vector2(88, 58) * k
	var tsz := _place_title(int(108.0 * k), int(40.0 * k), 0.0, false)
	_title_box.size = tsz
	_tagline.position = off + Vector2(92, 58) * k + Vector2(0, tsz.y - 26.0 * k)
	_tagline.add_theme_font_size_override("font_size", int(17.0 * k))
	at.call(_seal, 190, 230, 280, 280)
	at.call(_banners[0].root, 580, 300, 300, 89)
	at.call(_tuto, 606, 396, 300, 18)
	_tuto.add_theme_font_size_override("font_size", int(13.0 * k))
	at.call(_banners[1].root, 580, 440, 300, 67)
	at.call(_banners[2].root, 580, 580, 300, 67)
	at.call(_links, 596, 662, 260, 40)
	for b in _links.get_children():
		b.add_theme_font_size_override("font_size", int(13.0 * k))
	at.call(_foot, 0, 704, 1280, 96)
	_scroll.position = Vector2.ZERO

func _layout_stacked(area: Rect2) -> void:
	_scroll.position = area.position
	_scroll.size = area.size
	var cw := minf(area.size.x - 32.0, 420.0)
	_column.custom_minimum_size = Vector2(area.size.x, 0)
	var tsz := _place_title(76, 30, cw, true)
	_title_box.custom_minimum_size = Vector2(cw, tsz.y)
	_title_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tagline.add_theme_font_size_override("font_size", 16)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sd := minf(area.size.x * 0.64, 300.0)
	_seal.custom_minimum_size = Vector2(sd, sd)
	_seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for b in _banners:
		b.root.custom_minimum_size = Vector2(cw, cw * b.height / 300.0)
		b.root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tuto.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tuto.add_theme_font_size_override("font_size", 14)
	_links.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for b in _links.get_children():
		b.add_theme_font_size_override("font_size", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.custom_minimum_size = Vector2(area.size.x, 90)
	_foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
