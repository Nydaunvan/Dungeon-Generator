class_name HomeScreen
extends Control
## Page d'accueil « Atlas Noir » : fond de caverne, logo à gauche, trois grands boutons + panneau Outils à droite, pied de page.
## Paysage : scène de 1672×940 (maquette) mise à l'échelle sous l'en-tête. Portrait / petit écran : colonne défilante.

signal action(name: String)
signal nav(name: String)

const SW := 1672.0
const SH := 940.0
const FLAME_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float intensity = 1.0;
uniform float seed = 0.0;
uniform float speed = 1.0;
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + 11.7; a *= 0.5; } return v; }
void fragment() {
	float h = 1.0 - UV.y;                       // 0 = base, 1 = pointe
	float x = (UV.x - 0.5) * 2.0;
	float t = TIME * speed * 1.7 + seed * 17.0;
	float n = fbm(vec2(x * 1.6 + seed, h * 2.6 - t * 1.25));
	float n2 = fbm(vec2(x * 3.1 - seed, h * 4.8 - t * 2.1));
	float sway = (n - 0.5) * 0.9 * h * h + sin(t * 0.9 + seed * 5.0) * 0.12 * h;
	float xx = x + sway;
	float width = (0.62 * pow(1.0 - h, 0.55) + 0.05) * smoothstep(0.0, 0.08, h) ;
	float body = 1.0 - smoothstep(width * 0.25, width, abs(xx));
	float cut = smoothstep(0.55 + 0.4 * n2, 1.05, h + (n2 - 0.5) * 0.4);   // la pointe se déchire
	float d = clamp(body * (1.0 - cut) * (0.55 + 0.9 * n2), 0.0, 1.0);
	float core = pow(clamp(1.0 - abs(xx) / (width * 0.55 + 0.001), 0.0, 1.0), 1.6) * (1.0 - h * 0.9) * d;
	vec3 col = mix(vec3(0.85, 0.10, 0.02), vec3(1.0, 0.50, 0.08), smoothstep(0.1, 0.6, d));
	col = mix(col, vec3(1.0, 0.86, 0.45), smoothstep(0.35, 0.9, core));
	col = mix(col, vec3(1.0, 0.97, 0.85), smoothstep(0.75, 1.0, core) * 0.8);
	float flick = 0.88 + 0.12 * sin(t * 7.0 + seed * 9.0) * sin(t * 3.1 + seed);
	COLOR = vec4(col * d * intensity * flick, d);
}
"""
const TOP := 66.0          # hauteur de la barre d'en-tête dans la maquette (la scène commence sous l'en-tête réel)
const HOME := "res://assets/home/"

var _wall: ColorRect
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
var _logo: TextureRect
var _rule: Control            # filet à losange sous le logo
var _tagline: Label
var _btn_main: HomeMenuButton    # « Nouvelle Expédition » (« Expédition en ligne » une fois connecté)
var _btn_origin: HomeMenuButton
var _btn_saves: HomeMenuButton
var _tools: HomeToolsPanel
var _flames: Array = []       # {node, u, v, w, h} : flammes animées posées sur les torches / bougies du fond (coordonnées relatives à l'image)
var _foot_line: TextureRect
var _foot_ver: Button
var _foot_made: Button
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
	_wall = ColorRect.new()
	_wall.color = Color("07090a")
	_wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wall)
	# fond de caverne : occupe toute la page (derrière l'en-tête, la scène et la colonne), recadré au centre sans déformation
	_scene_bg = TextureRect.new()
	_scene_bg.texture = _tex("home_bg.png")
	_scene_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scene_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_scene_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_scene_bg)

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

	# chaînes animées (à gauche : avec le crâne ; à droite : avec le crochet, décalée de 1,2 s)
	for spec in [["chain_left.png", 0.0, Vector2(727, 0), Vector2(126, 378)], ["chain_right.png", 1.2, Vector2(1405, 0), Vector2(80, 459)]]:
		var ch := TextureRect.new()
		ch.texture = _tex(spec[0])
		ch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ch.stretch_mode = TextureRect.STRETCH_SCALE
		ch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC    # mipmaps : plus de scintillement du grain pendant l'oscillation
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
	add_child(_glow)
	move_child(_glow, _scene_bg.get_index() + 1)
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_glow, "modulate:a", 0.85, 0.5).set_trans(Tween.TRANS_SINE)

	_embers = Embers.new()
	_stage.add_child(_embers)
	_make_flames()

	# en-tête
	_header = AppHeader.new()
	_header.set_home_mode(true)
	_header.nav.connect(func(n: String): nav.emit(n))
	_title_label = _header.title_label
	add_child(_header)

	# logo (boussole + « ATLAS NOIR » + « CARTOGRAPHIE DES PROFONDEURS »)
	_logo = TextureRect.new()
	_logo.texture = _tex("logo_atlas_noir.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule = Control.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(func():
		var c := _rule.size * 0.5
		var half := _rule.size.x * 0.5
		var col := Atlas.COPPER
		_rule.draw_line(Vector2(0, c.y), Vector2(c.x - 14.0 * _rule.size.y, c.y), Color(col, 0.0), 1.0)
		for i in 24:
			var x0 := lerpf(0.0, c.x - 16.0 * _rule.size.y * 0.1, i / 24.0)
			var x1 := lerpf(0.0, c.x - 16.0 * _rule.size.y * 0.1, (i + 1) / 24.0)
			_rule.draw_line(Vector2(x0, c.y), Vector2(x1, c.y), Color(col, i / 24.0 * 0.9), 1.0)
			_rule.draw_line(Vector2(_rule.size.x - x0, c.y), Vector2(_rule.size.x - x1, c.y), Color(col, i / 24.0 * 0.9), 1.0)
		Atlas.draw_diamond(_rule, c, _rule.size.y * 0.32, Atlas.AMBER)
		Atlas.draw_diamond(_rule, c, _rule.size.y * 0.14, Color("0c0a08")))
	_rule.resized.connect(_rule.queue_redraw)
	_tagline = _label(L.t("ui.home_screen.tagline"), 22, Color("d8c196"), UiTheme.F_BODY_ITALIC)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_btn_main = _menu_button("", "", "compass", "random", true)
	_btn_origin = _menu_button(L.t("ui.home_screen.donjon_origine"), L.t("ui.home_screen.la_demonstration_officielle"), "map", "origin", false)
	_btn_saves = _menu_button(L.t("ui.home_screen.archives"), L.t("ui.home_screen.parties_sauvegardees"), "book", "saves", false)
	_make_friend_dot()
	_refresh_seal_texts()
	if not Cloud.session_changed.is_connected(_refresh_seal_texts):
		Cloud.session_changed.connect(_refresh_seal_texts)       # connexion / déconnexion / restauration de session : le texte suit

	_tools = HomeToolsPanel.new()
	_tools.label = L.t("ui.home_screen.outils")
	for spec in [[L.t("ui.home_screen.editeur_de_donjon_court"), "tools", "create"], [L.t("common.importer_un_fichier_json"), "upload", "import-json"], [L.t("ui.home_screen.charger_un_code"), "download", "load-code"], [L.t("ui.home_screen.tutoriel_de_creation"), "help", "tutorial"]]:
		var tb := HomeMenuButton.new()
		tb.title = spec[0]
		tb.icon_name = spec[1]
		var act: String = spec[2]
		tb.pressed.connect(func(): action.emit(act))
		_tools.add_tool(tb)

	# pied de page : filet à encoches + version (journal des modifications) + crédits
	_foot_line = TextureRect.new()
	_foot_line.texture = _tex("line_notch.png")
	_foot_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foot_line.stretch_mode = TextureRect.STRETCH_SCALE
	_foot_line.flip_v = true
	_foot_line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_foot_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot_ver = _link((L.t("common.editeur_de_donjon") + " " + AppVersion.label()).to_upper(), "changelog", 14)
	_foot_made = _link("MADE BY CLAUDE & NYDAUNVAN", "credits", 14)
	_foot_made.alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

## Flammes animées (shader additif) : torche et bougie de gauche, torche de droite. Positions relatives à l'image de fond (u, v = pied de la flamme).
func _make_flames() -> void:
	var sh := Shader.new()
	sh.code = FLAME_SHADER
	var idx := _scene_bg.get_index() + 1
	for spec in [[0.0965, 0.250, 0.046, 0.165, 1.0, 0.1], [0.1320, 0.7100, 0.020, 0.085, 0.9, 0.5], [0.9547, 0.618, 0.011, 0.034, 0.8, 0.9]]:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("intensity", spec[4])
		m.set_shader_parameter("seed", spec[5])
		r.material = m
		add_child(r)
		move_child(r, idx)
		idx += 1
		_flames.append({"node": r, "u": spec[0], "v": spec[1], "w": spec[2], "h": spec[3]})

## Place les flammes d'après la position de l'image de fond (recadrée « cover » sur toute la page).
func _layout_flames() -> void:
	var tex := _scene_bg.texture
	if tex == null or _flames.is_empty():
		return
	var ts := tex.get_size()
	var sc := maxf(size.x / ts.x, size.y / ts.y)
	var org := (size - ts * sc) * 0.5
	var gs := 0.2 * ts.x * sc
	_glow.size = Vector2(gs, gs)
	_glow.position = org + Vector2(0.0965 * ts.x * sc, 0.2 * ts.y * sc) - _glow.size * 0.5
	for f in _flames:
		var n: ColorRect = f.node
		var fw: float = float(f.w) * ts.x * sc
		var fh: float = float(f.h) * ts.y * sc
		n.size = Vector2(fw, fh)
		n.position = org + Vector2(float(f.u) * ts.x * sc - fw * 0.5, float(f.v) * ts.y * sc - fh)

func _menu_button(title: String, sub: String, icon: String, act: String, primary: bool) -> HomeMenuButton:
	var b := HomeMenuButton.new()
	b.title = title
	b.sub = sub
	b.icon_name = icon
	b.primary = primary
	b.pressed.connect(func(): action.emit(act))
	return b

## Texte du bouton principal : « Nouvelle Expédition » hors ligne, « Expédition en ligne / classée ou libre » une fois connecté.
func _refresh_seal_texts() -> void:
	_load_friend_requests()
	if _btn_main == null:
		return
	var online := Cloud.is_signed_in()
	_btn_main.title = L.t("ui.home_screen.expedition_en_ligne") if online else L.t("ui.home_screen.nouvelle_expedition")
	_btn_main.sub = L.t("ui.home_screen.classee_ou_libre") if online else L.t("ui.home_screen.commencer_une_nouvelle_aventure")

# ------------------------------------------------------------------ mise en page

func _move(n: Control, parent: Node) -> void:
	if n.get_parent() == parent:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	parent.add_child(n)

func _layout() -> void:
	if not _built:
		return
	var w := size.x
	var h := size.y
	_layout_flames()
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
	if stacked != _stacked or _btn_main.get_parent() == null:
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
	var order := [_logo, _rule, _tagline, _btn_main, _btn_origin, _btn_saves, _tools, _foot_line, _foot_ver, _foot_made]
	for n in order:
		_move(n, host)
	if _stacked:
		for i in order.size():
			_column.move_child(order[i], i)

func _layout_stage(area: Rect2) -> void:
	var k := minf(area.size.x / SW, area.size.y / (SH - TOP))
	var sz := Vector2(SW, SH) * k
	# origine de la scène : x centré, y tel que y=TOP de la maquette tombe juste sous l'en-tête
	var off := Vector2((area.size.x - sz.x) * 0.5, -TOP * k + (area.size.y - (SH - TOP) * k) * 0.5)
	_stage.position = area.position
	_stage.size = area.size
	for c in _chains:
		var cn: TextureRect = c.node
		cn.position = off + (c.pos as Vector2) * k
		cn.size = (c.size as Vector2) * k
		cn.pivot_offset = Vector2(cn.size.x * 0.5, 0.0)
	_embers.position = off
	_embers.size = sz
	_embers.k = k
	var at := func(n: Control, x: float, y: float, ww: float, hh: float) -> void:
		n.custom_minimum_size = Vector2.ZERO
		n.size_flags_horizontal = Control.SIZE_FILL
		n.position = off + Vector2(x, y) * k
		n.size = Vector2(ww, hh) * k
	at.call(_logo, 190, 120, 560, 373)
	at.call(_rule, 250, 493, 440, 20)
	_tagline.add_theme_font_size_override("font_size", int(roundf(24.0 * k)))
	at.call(_tagline, 190, 520, 560, 34)
	at.call(_btn_main, 876, 237, 529, 120)
	at.call(_btn_origin, 876, 383, 529, 105)
	at.call(_btn_saves, 876, 517, 529, 105)
	at.call(_tools, 876, 655, 529, HomeToolsPanel.design_height(4))
	at.call(_foot_line, 11, 824, 1650, 120)
	var fsz := int(roundf(15.0 * k))
	_foot_ver.add_theme_font_size_override("font_size", fsz)
	_foot_made.add_theme_font_size_override("font_size", fsz)
	at.call(_foot_ver, 60, 896, 700, 28)
	at.call(_foot_made, 912, 896, 700, 28)
	_scroll.position = Vector2.ZERO

func _layout_stacked(area: Rect2) -> void:
	_scroll.position = area.position
	_scroll.size = area.size
	var cw := minf(area.size.x - 32.0, 460.0)
	_column.custom_minimum_size = Vector2(0, 0)   # la largeur suit celle du défilement (barre verticale comprise) : jamais de débordement
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fit := func(n: Control, ww: float, hh: float) -> void:
		n.custom_minimum_size = Vector2(ww, hh)
		n.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fit.call(_logo, cw, cw * 373.0 / 560.0)
	fit.call(_rule, cw * 0.7, 18)
	_tagline.add_theme_font_size_override("font_size", 17)
	fit.call(_tagline, cw, 30)
	fit.call(_btn_main, cw, cw * 120.0 / 529.0)
	fit.call(_btn_origin, cw, cw * 105.0 / 529.0)
	fit.call(_btn_saves, cw, cw * 105.0 / 529.0)
	fit.call(_tools, cw, cw * HomeToolsPanel.design_height(4) / 529.0)
	fit.call(_foot_line, cw, 28)
	_foot_line.stretch_mode = TextureRect.STRETCH_SCALE
	for f in [_foot_ver, _foot_made]:
		f.add_theme_font_size_override("font_size", 13)
		f.alignment = HORIZONTAL_ALIGNMENT_CENTER
		fit.call(f, cw, 28)

## Point rouge clignotant sur le bouton principal tant que des demandes d'amis attendent (posé sur le bord du disque, en haut à droite).
var _friend_requests := 0
var _friend_dot: NotifDot = null

func _make_friend_dot() -> void:
	_friend_dot = NotifDot.attach(_btn_main, func(): return _friend_requests, false)
	_friend_dot.anchor_left = 1.0
	_friend_dot.anchor_right = 1.0
	_friend_dot.anchor_top = 0.0
	_friend_dot.anchor_bottom = 0.0
	_friend_dot.offset_left = -10.0
	_friend_dot.offset_right = 10.0
	_friend_dot.offset_top = -10.0
	_friend_dot.offset_bottom = 10.0
	_friend_dot.z_index = 5
	var blink := _friend_dot.create_tween().set_loops()
	blink.tween_property(_friend_dot, "modulate:a", 0.15, 0.55)
	blink.tween_property(_friend_dot, "modulate:a", 1.0, 0.55)

func _load_friend_requests() -> void:
	if _friend_dot == null:
		return
	if not Cloud.is_signed_in():
		_friend_requests = 0
		_friend_dot._update()
		return
	var r: Dictionary = await Friends.pending_count()
	if is_inside_tree() and r.get("ok", false) and (r.data is int or r.data is float):
		_friend_requests = int(r.data)
		_friend_dot._update()
