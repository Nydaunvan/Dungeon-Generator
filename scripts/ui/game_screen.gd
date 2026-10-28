class_name GameScreen
extends Control
## Écran « jeu vidéo » plein cadre (direction B) : couloir de donjon peint en fond, deux torches qui vacillent, braises, vignette,
## barre du haut (joueur · navigation · actions), corps et barre d'aide des touches en bas.
## Même interface que `Modal` pour le contenu (`content`, `set_buttons`, `close`, `closed`, `esc_closes`, groupe « modal »),
## ce qui permet de convertir une fenêtre sans toucher à sa logique. Fenêtres converties : voir docs/TECHNIQUE.md.

signal closed

const INK := Color("0b0704")
const GOLD := Color("f0c45c")
const GOLD_DEEP := Color("e2b04a")
const TEXT := Color("efe3c8")
const MUTED := Color("a8977a")
const GLASS := Color(0.133, 0.094, 0.055, 0.62)
const GLASS_LINE := Color(0.941, 0.769, 0.361, 0.28)

## Barre du haut : `player_box` (à gauche), `nav_box` (onglets), `actions_box` (boutons ronds à droite).
var player_box: Control
var nav_box: HBoxContainer
var actions_box: HBoxContainer
var content: VBoxContainer
var esc_closes: bool = true
var fit_ratio: float = 0.74
## Appelé pour chaque touche non gérée par l'écran : (event: InputEventKey) -> bool (true = traitée).
var key_handler: Callable = Callable()
var narrow: bool = false

var _body_scroll: ScrollContainer
var _hint_left: HBoxContainer
var _hint_right: HBoxContainer
var _torches: Array = []
var _t := 0.0
var _embers: Embers
var _back_cb: Callable = Callable()

static func open(host: Node, narrow_layout: bool = false) -> GameScreen:
	var s := GameScreen.new()
	s.narrow = narrow_layout
	s._build()
	host.add_child(s)
	return s

func _build() -> void:
	add_to_group("modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.shared()
	var base := ColorRect.new()
	base.color = INK
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	var back := _Backdrop.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	for side in [0.07, 0.93]:
		var g := TextureRect.new()
		g.texture = _glow_texture()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_left = side
		g.anchor_right = side
		g.anchor_top = 0.38
		g.anchor_bottom = 0.38
		var half := 150.0 if narrow else 260.0
		g.offset_left = -half
		g.offset_right = half
		g.offset_top = -half
		g.offset_bottom = half
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		add_child(g)
		_torches.append(g)
	_embers = Embers.new()
	_embers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_embers)
	# vignette + voiles de lisibilité (maquette B : ellipse sombre, voile à gauche, haut et bas assombris)
	add_child(_veil(_vignette_texture(), Control.PRESET_FULL_RECT, 0.0))
	if not narrow:
		add_child(_veil(_linear_texture([Color(0.024, 0.016, 0.008, 0.88), Color(0.024, 0.016, 0.008, 0.55), Color(0.024, 0.016, 0.008, 0.1), Color(0.024, 0.016, 0.008, 0.0)], [0.0, 0.36, 0.62, 1.0], true), Control.PRESET_FULL_RECT, 0.0))
	add_child(_veil(_linear_texture([Color(0.02, 0.012, 0.008, 0.93), Color(0.02, 0.012, 0.008, 0.0)], [0.0, 1.0], false), Control.PRESET_TOP_WIDE, 130.0 if not narrow else 110.0))
	add_child(_veil(_linear_texture([Color(0.02, 0.012, 0.008, 0.0), Color(0.02, 0.012, 0.008, 0.9 if not narrow else 0.88), Color(0.02, 0.012, 0.008, 0.96)], [0.0, 0.4, 1.0], false), Control.PRESET_BOTTOM_WIDE, 110.0 if not narrow else 420.0))

	var edge := 14 if narrow else 40
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 14 if narrow else 24)
	margin.add_theme_constant_override("margin_bottom", 0 if narrow else 20)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8 if narrow else 14)
	margin.add_child(col)

	# barre du haut : joueur · navigation (écran large) · actions
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_left", edge)
	top.add_theme_constant_override("margin_right", edge)
	col.add_child(top)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12 if narrow else 22)
	top.add_child(row1)
	var pb := VBoxContainer.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
	player_box = pb
	row1.add_child(pb)
	nav_box = HBoxContainer.new()
	actions_box = HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 6)
	if narrow:
		nav_box.add_theme_constant_override("separation", 0)
		nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_child(actions_box)
	else:
		nav_box.add_theme_constant_override("separation", 40)
		var navwrap := CenterContainer.new()
		navwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navwrap.add_child(nav_box)
		row1.add_child(navwrap)
		row1.add_child(actions_box)

	# corps : défile s'il manque de place ; `set_body_inset` règle la marge de gauche (0 = liste collée au bord)
	_body_margin = MarginContainer.new()
	_body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_margin.add_theme_constant_override("margin_left", edge)
	_body_margin.add_theme_constant_override("margin_right", edge)
	col.add_child(_body_margin)
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_margin.add_child(_body_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	_body_scroll.add_child(content)

	# bas : barre d'onglets (mobile) ou barre d'aide des touches (écran large)
	if narrow:
		var bar := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.031, 0.02, 0.012, 0.94)
		bsb.border_width_top = 1
		bsb.border_color = Color(0.94, 0.77, 0.36, 0.25)
		bar.add_theme_stylebox_override("panel", bsb)
		bar.custom_minimum_size = Vector2(0, 64)
		bar.add_child(nav_box)
		col.add_child(bar)
		_hint_left = HBoxContainer.new()
		_hint_right = HBoxContainer.new()
	else:
		var hint_m := MarginContainer.new()
		hint_m.add_theme_constant_override("margin_left", edge)
		hint_m.add_theme_constant_override("margin_right", edge)
		col.add_child(hint_m)
		var hint := HBoxContainer.new()
		hint.add_theme_constant_override("separation", 22)
		hint_m.add_child(hint)
		var pad := Control.new()          # laisse la place au bouton flottant du tchat, en bas à gauche
		pad.custom_minimum_size = Vector2(40, 0)
		hint.add_child(pad)
		_hint_left = HBoxContainer.new()
		_hint_left.add_theme_constant_override("separation", 22)
		_hint_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.add_child(_hint_left)
		_hint_right = HBoxContainer.new()
		_hint_right.add_theme_constant_override("separation", 26)
		hint.add_child(_hint_right)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)

var _body_margin: MarginContainer

## Marge de gauche du corps (0 : la liste des modes touche le bord de l'écran, comme sur la maquette).
func set_body_inset(left: int) -> void:
	_body_margin.add_theme_constant_override("margin_left", left)

static func _veil(tex: Texture2D, preset: int, height: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(preset)
	if height > 0.0:
		if preset == Control.PRESET_TOP_WIDE:
			r.offset_bottom = height
		else:
			r.offset_top = -height
	return r

static func _linear_texture(colors: Array, offsets: Array, horizontal: bool) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	t.width = 256
	t.height = 256
	return t

func _process(delta: float) -> void:
	_t += delta
	var i := 0
	for g in _torches:
		var f := 0.78 + 0.16 * sin(_t * 7.3 + i * 2.1) + 0.06 * sin(_t * 17.0 + i)
		(g as TextureRect).modulate = Color(1, 1, 1, clampf(f, 0.5, 1.0))
		i += 1
	if _embers != null:
		_embers.k = maxf(size.y, 1.0) / 800.0

# ------------------------------------------------------------------ barre d'aide

## Raccourci affiché en bas : touche (« Échap »), libellé. `side` : "left" ou "right". `cb` rend le raccourci cliquable.
func add_hint(key: Variant, text: String, side: String = "right", cb: Callable = Callable()) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var keys: Array = key if key is Array else [key]
	for kk in keys:
		h.add_child(_keycap(str(kk)))
	var tl := Label.new()
	tl.text = text
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", Color("cdbf9e"))
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tl)
	return _place_hint(h, side, cb)

func _place_hint(h: HBoxContainer, side: String, cb: Callable) -> Control:
	if cb.is_valid():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = h.get_combined_minimum_size()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		b.pressed.connect(func(): cb.call())
		(_hint_left if side == "left" else _hint_right).add_child(b)
		return b
	(_hint_left if side == "left" else _hint_right).add_child(h)
	return h

static func _keycap(key: String) -> Control:
	var cap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a130b")
	sb.border_color = Color("8a6f3a")
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", sb)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kl := Label.new()
	kl.text = key
	kl.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	kl.add_theme_font_size_override("font_size", 12)
	kl.add_theme_color_override("font_color", Color("f1deb0"))
	cap.add_child(kl)
	return cap

func clear_hints(side: String = "right") -> void:
	var p := _hint_left if side == "left" else _hint_right
	for ch in p.get_children():
		p.remove_child(ch)
		ch.queue_free()

## Compatible `Modal.set_buttons` : le premier bouton devient l'aide « Échap · <texte> » en bas à gauche (cliquable).
func set_buttons(specs: Array, _row: bool = false, _stack: bool = false) -> void:
	clear_hints("left")
	if specs.is_empty():
		return
	_back_cb = specs[0].get("cb", Callable())
	add_hint(L.t("ui.screen.key_esc"), str(specs[0].get("text", "")), "left", func():
		if _back_cb.is_valid():
			_back_cb.call())

func _fit() -> void:
	pass

## Mobile : flèche de retour en tête des actions (pas de barre d'aide des touches à l'écran).
func add_back_button() -> void:
	if not narrow:
		return
	actions_box.add_child(GameWidgets.icon_button("back", L.t("ui.screen.back"), func():
		if _back_cb.is_valid():
			_back_cb.call()
		else:
			close()))

func close() -> void:
	closed.emit()
	queue_free()

# ------------------------------------------------------------------ clavier

func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	var top: Node = null
	for n in get_tree().get_nodes_in_group("modal"):
		if not n.is_queued_for_deletion():
			top = n
	if top != self:
		return
	if esc_closes and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _back_cb.is_valid():
			_back_cb.call()
		else:
			close()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and key_handler.is_valid():
		var f := get_viewport().gui_get_focus_owner()
		if f is LineEdit or f is TextEdit:
			return
		if bool(key_handler.call(event)):
			get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ éléments partagés

## Panneau de verre : fond brun translucide, liseré doré léger.
static func glass(pad: int = 16, radius: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.border_color = GLASS_LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	p.add_theme_stylebox_override("panel", sb)
	return p

static func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.62, 0.22, 0.55), Color(0.85, 0.36, 0.08, 0.22), Color(0.5, 0.18, 0.02, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	return t

static func _vignette_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.02, 0.01, 0.0, 0.78)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.55, 0.45)
	t.fill_to = Vector2(1.15, 1.0)
	t.width = 256
	t.height = 256
	return t

## Couloir de donjon en perspective (murs, sol dallé, plafond, porte lumineuse au fond).
class _Backdrop extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 2.0 or h < 2.0:
			return
		var bw := w * 0.15
		var bh := h * 0.24
		var cx := w * 0.5
		var cy := h * 0.47
		var btl := Vector2(cx - bw, cy - bh)
		var btr := Vector2(cx + bw, cy - bh)
		var bbl := Vector2(cx - bw, cy + bh)
		var bbr := Vector2(cx + bw, cy + bh)
		var tl := Vector2(0, 0)
		var tr := Vector2(w, 0)
		var bl := Vector2(0, h)
		var br := Vector2(w, h)
		draw_colored_polygon(PackedVector2Array([tl, tr, btr, btl]), Color("22170e"))
		draw_colored_polygon(PackedVector2Array([bl, br, bbr, bbl]), Color("2c2013"))
		draw_colored_polygon(PackedVector2Array([tl, btl, bbl, bl]), Color("35271a"))
		draw_colored_polygon(PackedVector2Array([tr, btr, bbr, br]), Color("35271a"))
		draw_colored_polygon(PackedVector2Array([btl, btr, bbr, bbl]), Color("0e0905"))
		var line := Color(0.0, 0.0, 0.0, 0.5)
		# dalles du sol
		for i in range(1, 9):
			var k := pow(float(i) / 9.0, 1.7)
			var y := lerpf(cy + bh, h, k)
			var xl := lerpf(cx - bw, 0.0, k)
			var xr := lerpf(cx + bw, w, k)
			draw_line(Vector2(xl, y), Vector2(xr, y), line, 1.5)
		for j in range(-3, 4):
			var fx := float(j) / 3.0
			draw_line(Vector2(cx + bw * fx, cy + bh), Vector2(cx + w * 0.62 * fx, h), line, 1.5)
		# assises des murs
		for i in range(1, 7):
			var k := pow(float(i) / 7.0, 1.6)
			draw_line(Vector2(lerpf(cx - bw, 0.0, k), lerpf(cy - bh, 0.0, k)), Vector2(lerpf(cx - bw, 0.0, k), lerpf(cy + bh, h, k)), Color(0, 0, 0, 0.35), 1.5)
			draw_line(Vector2(lerpf(cx + bw, w, k), lerpf(cy - bh, 0.0, k)), Vector2(lerpf(cx + bw, w, k), lerpf(cy + bh, h, k)), Color(0, 0, 0, 0.35), 1.5)
		# porte du fond et sa lueur
		var dw := bw * 0.5
		var dtop := cy - bh * 0.45
		draw_colored_polygon(PackedVector2Array([Vector2(cx - dw, cy + bh), Vector2(cx - dw, dtop + dw * 0.5), Vector2(cx, dtop - dw * 0.15), Vector2(cx + dw, dtop + dw * 0.5), Vector2(cx + dw, cy + bh)]), Color("070402"))
		for i in 6:
			draw_circle(Vector2(cx, cy + bh * 0.5), bw * (1.6 - i * 0.22), Color(1.0, 0.55, 0.15, 0.025 + 0.012 * i))
