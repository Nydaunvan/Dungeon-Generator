class_name UiTheme
extends RefCounted
## Habillage « donjon » : bronze rivé sur fond sombre, polices Cinzel (titres) et Spectral (texte).

const BG := Color("120d09")
const BG2 := Color("1c150e")
const BRONZE := Color("7a6242")
const BRONZE_DARK := Color("3a2c1c")
const BRONZE_LIGHT := Color("a88a5c")
const GOLD := Color("e8b45c")
const PARCH := Color("f5ecd8")
const DIM := Color("b9a880")
const HP_GREEN := Color("7ab648")
const STA_CYAN := Color("35b8c8")
const RED := Color("c0392b")

const F_BODY := "res://assets/fonts/Spectral-Regular.ttf"
const F_BODY_BOLD := "res://assets/fonts/Spectral-SemiBold.ttf"
const F_BODY_ITALIC := "res://assets/fonts/Spectral-Italic.ttf"
const F_TITLE := "res://assets/fonts/Cinzel-SemiBold.ttf"
const F_TITLE_BOLD := "res://assets/fonts/Cinzel-Bold.ttf"

static var _fonts: Dictionary = {}
static var _circle: ShaderMaterial = null

static func font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) if ResourceLoader.exists(path) else null
	return _fonts[path]

static func box(bg: Color, border: Color = BRONZE, border_w: int = 3, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.85)   # liseré noir extérieur, comme le cadre du HTML
	s.shadow_size = 2
	s.set_content_margin_all(6)
	return s

const UI := "res://assets/ui/"
static var _tex: Dictionary = {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := UI + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]

## Boîte à 9 découpes à partir d'une texture générée (assets/ui). `m` = marges de découpe (g, h, d, b).
static func tbox(name: String, m: Array, content: Array = [], draw_center: bool = true) -> StyleBox:
	var t := tex(name)
	if t == null:
		return box(BG, BRONZE, 3, 6)   # repli si la texture n'est pas encore importée
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = m[0]
	s.texture_margin_top = m[1]
	s.texture_margin_right = m[2]
	s.texture_margin_bottom = m[3]
	s.draw_center = draw_center
	if content.size() == 4:
		s.content_margin_left = content[0]
		s.content_margin_top = content[1]
		s.content_margin_right = content[2]
		s.content_margin_bottom = content[3]
	return s

static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font(F_BODY)
	th.default_font_size = 16
	for t in ["Label", "Button", "RichTextLabel"]:
		th.set_color("font_color", t, PARCH)
	th.set_color("default_color", "RichTextLabel", PARCH)
	th.set_font("bold_font", "RichTextLabel", font(F_BODY_BOLD))
	th.set_font("italics_font", "RichTextLabel", font(F_BODY_ITALIC))
	th.set_color("font_outline_color", "Label", Color.BLACK)
	# boutons : plaques de bronze
	var cm := [10, 5, 10, 5]
	th.set_stylebox("normal", "Button", tbox("btn_n", [10, 10, 10, 10], cm))
	th.set_stylebox("hover", "Button", tbox("btn_h", [10, 10, 10, 10], cm))
	th.set_stylebox("pressed", "Button", tbox("btn_p", [10, 10, 10, 10], cm))
	th.set_stylebox("disabled", "Button", tbox("btn_d", [10, 10, 10, 10], cm))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font("font", "Button", font(F_TITLE))
	th.set_font_size("font_size", "Button", 14)
	th.set_color("font_hover_color", "Button", GOLD)
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_color("font_disabled_color", "Button", DIM)
	th.set_stylebox("panel", "PanelContainer", tbox("frame_panel", [12, 12, 12, 12], [14, 12, 14, 12]))
	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_stylebox("tab_selected", "TabContainer", tbox("btn_h", [10, 10, 10, 10], [12, 5, 12, 5]))
	th.set_stylebox("tab_unselected", "TabContainer", tbox("btn_n", [10, 10, 10, 10], [12, 5, 12, 5]))
	th.set_stylebox("tab_hovered", "TabContainer", tbox("btn_h", [10, 10, 10, 10], [12, 5, 12, 5]))
	th.set_font("font", "TabContainer", font(F_TITLE))
	th.set_font_size("font_size", "TabContainer", 13)
	th.set_color("font_selected_color", "TabContainer", GOLD)
	th.set_color("font_unselected_color", "TabContainer", DIM)
	th.set_color("font_hovered_color", "TabContainer", GOLD)
	return th

## Bouton rond façon « rivet » (attaque, sorts).
static func round_button_style(ring: Color, fill: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = ring
	s.set_border_width_all(3)
	s.set_corner_radius_all(200)
	s.shadow_color = Color(0, 0, 0, 0.85)
	s.shadow_size = 3
	return s

## Matériau qui découpe une texture en disque (portraits ronds).
static func circle_material() -> ShaderMaterial:
	if _circle == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = vec4(c.rgb, c.a * step(distance(UV, vec2(0.5)), 0.5)); }"
		_circle = ShaderMaterial.new()
		_circle.shader = sh
	return _circle

## Portrait rond dans un anneau. Redimensionner via custom_minimum_size du contrôle renvoyé.
static func portrait(img: Texture2D, ring: Color = BRONZE, size: float = 64.0) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(size, size)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_panel := Panel.new()
	ring_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0d0906")
	sb.border_color = ring
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(500)
	ring_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(ring_panel)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 4
	pic.offset_top = 4
	pic.offset_right = -4
	pic.offset_bottom = -4
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = img
	pic.material = circle_material()
	root.add_child(pic)
	root.set_meta("ring_style", sb)
	return root

static func class_color(class_name_fr: String) -> Color:
	match class_name_fr.to_lower():
		"guerrier": return Color("a83a2a")
		"archer": return Color("4f8a3a")
		"prêtre", "pretre": return Color("b8963a")
		"mage": return Color("6a3fa0")
		"roublard": return Color("6a6a70")
		"barde": return Color("3f6aa8")
	return BRONZE
