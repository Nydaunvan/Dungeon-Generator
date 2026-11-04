class_name OnlineArt
extends RefCounted
## Habillage « Atlas Noir » de l'écran du mode en ligne (onglet Jouer, grand écran) : bannière de velours des cinq modes, parchemin de la fiche,
## plaques de bronze des tuiles, ruban rouge du bouton de lancement, filet lumineux, boussole et rouleau.
## Les images sont dans assets/ui/online/ ; tout est dessiné en tranches (coins à l'échelle uniforme, parties unies étirées).

const T_HALL := preload("res://assets/ui/online/hall.jpg")
const T_RIBBON_CTA := preload("res://assets/ui/online/ribbon_cta.png")
const T_PLATE := preload("res://assets/ui/online/plate.png")
const T_MEDALLION := preload("res://assets/ui/online/medallion.png")
const T_FRAME := preload("res://assets/ui/online/frame_dark.png")

## Textes sur le décor sombre.
const TXT := Color("f6ead0")
const TXT_SOFT := Color("e0d0ac")
const TXT_ACCENT := Color("f0c45c")
const TXT_OK := Color("9cc79a")
const CREAM := Color("fff1d0")
const GOLD := Color("f0c45c")

const PLATE_CAPS := [110.0, 110.0]

## Ruban / plaque : bout gauche et bout droit à l'échelle de la hauteur, milieu étiré.
static func draw_caps(ci: CanvasItem, tex: Texture2D, r: Rect2, cap_l: float, cap_r: float, tint: Color = Color.WHITE) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var s := r.size.y / th
	var l := minf(cap_l * s, r.size.x * 0.5)
	var rr := minf(cap_r * s, r.size.x * 0.5)
	ci.draw_texture_rect_region(tex, Rect2(r.position, Vector2(l, r.size.y)), Rect2(0, 0, cap_l, th), tint)
	ci.draw_texture_rect_region(tex, Rect2(r.position.x + l, r.position.y, r.size.x - l - rr, r.size.y), Rect2(cap_l, 0, tw - cap_l - cap_r, th), tint)
	ci.draw_texture_rect_region(tex, Rect2(r.end.x - rr, r.position.y, rr, r.size.y), Rect2(tw - cap_r, 0, cap_r, th), tint)

## Plaque d'un mode (liste de gauche) : médaillon rond à filet d'or avec l'icône, nom et accroche ; le mode choisi est dans une plaque dorée lumineuse.
class ModeLine extends Button:
	var selected := false
	var hot := false
	var glyph: Texture2D
	var title := ""
	var tag := ""
	var status := ""
	var danger := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mouse_entered.connect(func():
			hot = true
			queue_redraw())
		mouse_exited.connect(func():
			hot = false
			queue_redraw())

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var gold := Color(0.94, 0.77, 0.36)
		var red := Color(0.88, 0.31, 0.18)
		var cr := h * 0.4
		var cx := h * 0.5 + 6.0
		var cy := h * 0.5
		if selected:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.2, 0.13, 0.05, 0.78)
			sb.border_color = Color(1.0, 0.8, 0.4, 0.95)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(int(h * 0.5))
			sb.shadow_color = Color(1.0, 0.62, 0.2, 0.38)
			sb.shadow_size = 12
			draw_style_box(sb, Rect2(4, 3, w - 8, h - 6))
		elif hot:
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0.94, 0.77, 0.36, 0.07)
			sb2.set_corner_radius_all(int(h * 0.5))
			draw_style_box(sb2, Rect2(4, 3, w - 8, h - 6))
		draw_circle(Vector2(cx, cy), cr, Color(0.07, 0.045, 0.025, 0.85), true, -1.0, true)
		var ring := (red if danger else gold)
		draw_arc(Vector2(cx, cy), cr, 0.0, TAU, 48, Color(ring.r, ring.g, ring.b, 1.0 if (selected or hot) else 0.7), 2.0 if selected else 1.5, true)
		if glyph != null:
			var q := cr * 1.15
			draw_texture_rect(glyph, Rect2(cx - q * 0.5, cy - q * 0.5, q, q), false)
		var f: Font = UiTheme.font(UiTheme.F_TITLE_BOLD if selected else UiTheme.F_TITLE)
		var f2: Font = UiTheme.font(UiTheme.F_BODY)
		var tx := cx + cr + 16.0
		var tw := w - tx - 18.0
		var sw := f2.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x if status != "" else 0.0
		var fs := int(clampf(h * 0.27, 12.0, 22.0))
		while fs > 11 and f.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw - (sw + 8.0 if status != "" else 0.0):
			fs -= 1
		var fs2 := int(clampf(h * 0.18, 11.0, 15.0))
		while fs2 > 9 and f2.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > tw:
			fs2 -= 1
		var tc := OnlineArt.CREAM if (selected or hot) else Color("d8c8a2")
		if danger and not selected:
			tc = Color("f0a58a")
		draw_string(f, Vector2(tx, h * 0.47), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, tw, fs, tc)
		draw_string(f2, Vector2(tx, h * 0.47 + fs2 * 1.4), tag, HORIZONTAL_ALIGNMENT_LEFT, tw, fs2, Color("e8dcc0") if selected else Color("b4a382"))
		if status != "":
			draw_string(f2, Vector2(w - sw - 18.0, h * 0.47), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, OnlineArt.GOLD if selected else Color("b4a382"))

# ------------------------------------------------------------------ plaques, bouton, filet

## Tuile d'information (plaque de bronze) : même contrat que GameWidgets.info_tile (`value` en méta).
class PlateTile extends PanelContainer:
	var strong := false

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	func _draw() -> void:
		OnlineArt.draw_caps(self, OnlineArt.T_PLATE, Rect2(Vector2.ZERO, size), OnlineArt.PLATE_CAPS[0], OnlineArt.PLATE_CAPS[1], Color.WHITE if strong else Color(0.92, 0.9, 0.86))

static func tile(label: String, value: String, strong: bool, big: bool = true) -> PanelContainer:
	var p := PlateTile.new()
	p.strong = strong
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(120, 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 20)
	m.add_theme_constant_override("margin_top", 11)
	m.add_theme_constant_override("margin_bottom", 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var l := Label.new()
	l.text = label.to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_BODY, 2))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("b8a684"))
	v.add_child(l)
	var val := Label.new()
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	val.add_theme_font_size_override("font_size", (14 if strong else 15) if big else 15)
	val.add_theme_color_override("font_color", Color("f6dc8a") if strong else CREAM)
	v.add_child(val)
	p.set_meta("value", val)
	return p

## Bouton de lancement : ruban rouge à médaillon (l'icône des épées dans le médaillon), halo plus vif au survol.
class RibbonButton extends Button:
	var glyph: Texture2D
	var hot := false
	var down := false

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(k, StyleBoxEmpty.new())
		mouse_entered.connect(func():
			hot = true
			queue_redraw())
		mouse_exited.connect(func():
			hot = false
			queue_redraw())
		button_down.connect(func():
			down = true
			queue_redraw())
		button_up.connect(func():
			down = false
			queue_redraw())

	func _draw() -> void:
		var tint := Color.WHITE
		if disabled:
			tint = Color(0.5, 0.5, 0.5, 0.85)
		elif down:
			tint = Color(0.82, 0.82, 0.82)
		elif hot:
			tint = Color(1.18, 1.1, 1.05)
		OnlineArt.draw_caps(self, OnlineArt.T_RIBBON_CTA, Rect2(Vector2.ZERO, size), 300.0, 120.0, tint)
		var s := size.y / float(OnlineArt.T_RIBBON_CTA.get_height())
		var c := Vector2(158.0 * s, size.y * 0.506)
		if glyph != null:
			var q := size.y * 0.5
			draw_texture_rect(glyph, Rect2(c - Vector2(q, q) * 0.5, Vector2(q, q)), false, Color(1, 0.96, 0.86, 0.6 if disabled else 1.0))
		var f: Font = get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var x0 := 300.0 * s
		var tw := size.x - x0 - 120.0 * s
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, tw, fs)
		var col := Color("fff6dc") if not disabled else Color("8a7a60")
		draw_string(f, Vector2(x0 + (tw - ts.x) * 0.5, size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, col)

static func cta(text: String, cb: Callable) -> Button:
	var b := RibbonButton.new()
	b.text = text.to_upper()
	b.glyph = GameIcons.tex("swords", 64, Color("ffe9b8"), 2.0)
	var f := GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 2)
	var fs := 22
	while fs > 13 and f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 390.0:
		fs -= 1
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_font_override("font", f)
	var k := 58.0 / 241.0
	b.custom_minimum_size = Vector2(maxf(330.0, f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (300.0 + 120.0) * k + 36.0), 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b

## Cadre sombre des autres onglets (classements, récompenses…) : plaque de bronze à rivets, en neuf tranches.
static func frame_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = T_FRAME
	sb.texture_margin_left = 60
	sb.texture_margin_right = 60
	sb.texture_margin_top = 60
	sb.texture_margin_bottom = 60
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 38
	sb.content_margin_bottom = 34
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb
