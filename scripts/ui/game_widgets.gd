class_name GameWidgets
extends RefCounted
## Éléments du style « jeu vidéo » (direction B) : anneau d'XP, onglets à filet lumineux, boutons-icônes, gemmes et lignes de la liste de modes,
## bouton de lancement incliné à reflet, tuiles d'information, affiches (mobile). Dessinés en code, aucune image.

const GOLD := Color("f0c45c")
const CREAM := Color("fff1d0")
const MUTED := Color("a8977a")
static var _fonts: Dictionary = {}

## Police avec espacement des lettres (les titres de la maquette sont en capitales espacées).
static func spaced(path: String, spacing: int) -> Font:
	var key := "%s|%d" % [path, spacing]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = UiTheme.font(path)
		fv.spacing_glyph = spacing
		_fonts[key] = fv
	return _fonts[key]

# ------------------------------------------------------------------ anneau d'XP

class Ring extends Control:
	var value := 0.0
	var text := ""
	var icon: Texture2D

	func _init(px: float = 72.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_state(v: float, t: String) -> void:
		value = v
		text = t
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var w := maxf(3.0, size.x * 0.07)
		var r := minf(size.x, size.y) * 0.5 - w
		draw_circle(c, r, Color("1a130b"))
		draw_arc(c, r, 0.0, TAU, 64, Color("3a2a18"), w, true)
		if value > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * clampf(value, 0.0, 1.0), 64, GOLD, w, true)
		if icon != null:
			var q := size.x * 0.4
			draw_texture_rect(icon, Rect2(c - Vector2(q, q) / 2.0, Vector2(q, q)), false)
		elif text != "":
			var f := UiTheme.font(UiTheme.F_TITLE_BOLD)
			var fs := int(size.x * 0.36)
			var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string(f, Vector2(c.x - sz.x / 2.0, c.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CREAM)

# ------------------------------------------------------------------ onglets

## Filet doré lumineux sous l'onglet actif (dégradé transparent → or → transparent, halo au-dessus).
class NavLine extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var g := Color("f6dc8a")
		var t := Color(g.r, g.g, g.b, 0.0)
		var half := w / 2.0
		draw_polygon(PackedVector2Array([Vector2(0, h - 3), Vector2(half, h - 3), Vector2(half, h), Vector2(0, h)]), PackedColorArray([t, g, g, t]))
		draw_polygon(PackedVector2Array([Vector2(half, h - 3), Vector2(w, h - 3), Vector2(w, h), Vector2(half, h)]), PackedColorArray([g, t, t, g]))
		var glow_a := Color(0.94, 0.77, 0.36, 0.32)
		var glow_t := Color(0.94, 0.77, 0.36, 0.0)
		draw_polygon(PackedVector2Array([Vector2(half * 0.3, h - 3), Vector2(w - half * 0.3, h - 3), Vector2(w - half * 0.3, h - 15), Vector2(half * 0.3, h - 15)]), PackedColorArray([glow_a, glow_a, glow_t, glow_t]))

## Onglet de la barre du haut (écran large) : capitales espacées, filet lumineux sous l'onglet actif. Pas d'icône.
static func nav_button(text: String, active: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", spaced(UiTheme.F_TITLE, 2))
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", MUTED)
	b.add_theme_color_override("font_hover_color", Color("d9c79b"))
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_hover_pressed_color", CREAM)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = 10
		sb.content_margin_bottom = 12
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		b.add_theme_stylebox_override(k, sb)
	var line := NavLine.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -18
	line.offset_left = -6
	line.offset_right = 6
	line.offset_bottom = 2
	line.visible = active
	b.add_child(line)
	b.toggled.connect(func(on: bool): line.visible = on)
	b.pressed.connect(func(): cb.call())
	return b

## Onglet de la barre du bas (mobile) : icône au-dessus d'un petit libellé en capitales.
static func tab_button(text: String, icon: String, active: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 56)
	b.icon = GameIcons.tex(icon, 44, Color.WHITE, 1.7)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 22)
	b.add_theme_constant_override("h_separation", 0)
	b.add_theme_font_override("font", spaced(UiTheme.F_TITLE, 1))
	b.add_theme_font_size_override("font_size", 10)
	for c in ["font_color", "icon_normal_color", "font_hover_color", "icon_hover_color"]:
		b.add_theme_color_override(c, MUTED)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("f6dc8a"))
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = 8
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(k, sb)
	b.pressed.connect(func(): cb.call())
	return b

## Bouton-icône nu (tchat, compte, aide, retour) de la barre du haut.
static func icon_button(icon: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.icon = GameIcons.tex(icon, 52, Color.WHITE, 1.6)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 24)
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_color_override("icon_normal_color", Color("d9c79b"))
	b.add_theme_color_override("icon_hover_color", CREAM)
	b.add_theme_color_override("icon_pressed_color", GOLD)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.pressed.connect(func(): cb.call())
	return b

# ------------------------------------------------------------------ liste des modes

## Fond d'une ligne de la liste : dégradé doré vers la droite et barre lumineuse à gauche quand elle est choisie.
class TileBg extends Control:
	var on := false
	var hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not on and not hover:
			return
		var w := size.x
		var h := size.y
		var a := 0.28 if on else 0.1
		var c0 := Color(0.94, 0.77, 0.36, a)
		var c1 := Color(0.94, 0.77, 0.36, 0.04 if on else 0.01)
		var c2 := Color(0.94, 0.77, 0.36, 0.0)
		var x1 := w * 0.85
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(0, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(x1, 0), Vector2(w, 0), Vector2(w, h), Vector2(x1, h)]), PackedColorArray([c1, c2, c2, c1]))
		if on:
			for i in 4:
				var g := Color(0.94, 0.77, 0.36, 0.1 - i * 0.022)
				draw_rect(Rect2(-i * 3.0, 10.0 - i * 2.0, 4.0 + i * 6.0, h - 20.0 + i * 4.0), g)
			draw_polygon(PackedVector2Array([Vector2(0, 10), Vector2(4, 10), Vector2(4, h - 10), Vector2(0, h - 10)]), PackedColorArray([Color("f6dc8a"), Color("f6dc8a"), Color("b98a2e"), Color("b98a2e")]))

## Gemme : losange à liseré doré portant l'icône du mode (le mode choisi a un fond bronze).
class Gem extends Control:
	var tex: Texture2D
	var border := Color(0.94, 0.77, 0.36, 0.45)
	var lit := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(60, 60)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		if lit:
			draw_polygon(pts, PackedColorArray([Color("6a4c22"), Color("46321a"), Color("2a1e11"), Color("46321a")]))
		else:
			draw_polygon(pts, PackedColorArray([Color(0.08, 0.055, 0.03, 0.7), Color(0.08, 0.055, 0.03, 0.7), Color(0.08, 0.055, 0.03, 0.7), Color(0.08, 0.055, 0.03, 0.7)]))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, GOLD if lit else border, 1.5, true)
		if tex != null:
			var q := 22.0
			draw_texture_rect(tex, Rect2(c - Vector2(q, q) / 2.0, Vector2(q, q)), false)

# ------------------------------------------------------------------ bouton de lancement

## Fond du bouton de lancement : parallélogramme bronze à liseré d'or, halo qui pulse, reflet qui traverse.
class CtaFx extends Control:
	var btn: Button
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var s := minf(14.0, h * 0.2)
		var pts := PackedVector2Array([Vector2(s, 0), Vector2(w, 0), Vector2(w - s, h), Vector2(0, h)])
		var off: bool = btn != null and btn.disabled
		var hov: bool = btn != null and btn.is_hovered() and not off
		var top := Color("2e2a22") if off else (Color("a87631") if hov else Color("8a6128"))
		var bot := Color("221e17") if off else (Color("5c3f1b") if hov else Color("4a3216"))
		if not off:
			var pulse := 0.5 + 0.5 * sin(_t * TAU / 2.4)
			var closed_g := pts.duplicate()
			closed_g.append(pts[0])
			for i in 5:
				draw_polyline(closed_g, Color(0.94, 0.77, 0.36, (0.16 + 0.16 * pulse) * (1.0 - i / 5.0)), 4.0 + i * 5.0, true)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color("5a5040") if off else GOLD, 2.0, true)
		if not off:
			var ph := fposmod(_t, 3.4) / 3.4
			if ph < 0.6:
				var x := lerpf(-60.0, w + 30.0, ph / 0.6)
				var x0 := clampf(x, s, w - s)
				var x1 := clampf(x + 30.0, s, w - s)
				var x2 := clampf(x + 60.0, s, w - s)
				var cw := Color(1, 1, 1, 0.42)
				var ct := Color(1, 1, 1, 0.0)
				if x1 > x0:
					draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]), PackedColorArray([ct, cw, cw, ct]))
				if x2 > x1:
					draw_polygon(PackedVector2Array([Vector2(x1, 0), Vector2(x2, 0), Vector2(x2, h), Vector2(x1, h)]), PackedColorArray([cw, ct, ct, cw]))

## Bouton de lancement de la maquette : « LANCER LE DÉFI » en capitales espacées, chevrons à droite.
static func cta_button(text: String, cb: Callable, narrow: bool) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0 if narrow else 380, 58 if narrow else 70)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_BEGIN
	b.icon = GameIcons.tex("chevrons", 56, Color.WHITE, 2.2)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_constant_override("icon_max_width", 22 if narrow else 26)
	b.add_theme_constant_override("h_separation", 12)
	var n := text.length()
	var fs := 24 if n <= 22 else (20 if n <= 30 else 16)     # les libellés longs rétrécissent au lieu de pousser la mise en page
	b.add_theme_font_size_override("font_size", mini(fs, 19) if narrow else fs)
	b.add_theme_font_override("font", spaced(UiTheme.F_TITLE_BOLD, 3 if n <= 30 else 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("fff6dc"))
	b.add_theme_color_override("font_disabled_color", Color("8a7a60"))
	b.add_theme_color_override("icon_disabled_color", Color("8a7a60"))
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		b.add_theme_stylebox_override(k, sb)
	var fx := CtaFx.new()
	fx.btn = b
	fx.show_behind_parent = true
	b.add_child(fx)
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b

# ------------------------------------------------------------------ tuiles et liens

## Tuile d'information : petit libellé en capitales espacées, valeur en grand. La valeur est dans le meta « value » (Label).
static func info_tile(label: String, value: String, strong: bool, narrow: bool, value_color: Color = CREAM) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.078, 0.055, 0.031, 0.7)
	sb.border_color = Color(0.94, 0.77, 0.36, 0.6 if strong else 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12 if narrow else 18
	sb.content_margin_right = 12 if narrow else 18
	sb.content_margin_top = 10 if narrow else 14
	sb.content_margin_bottom = 10 if narrow else 14
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not narrow:
		p.custom_minimum_size.x = 200
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var l := Label.new()
	l.text = label.to_upper()
	l.add_theme_font_override("font", spaced(UiTheme.F_BODY, 2))
	l.add_theme_font_size_override("font_size", 11 if narrow else 12)
	l.add_theme_color_override("font_color", MUTED)
	v.add_child(l)
	var val := Label.new()
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	val.add_theme_font_size_override("font_size", (15 if strong else 19) if narrow else (20 if strong else 28))
	val.add_theme_color_override("font_color", Color("f6dc8a") if strong else value_color)
	v.add_child(val)
	p.set_meta("value", val)
	return p

## Lien souligné doré (« Règles du défi », « Voir le classement »).
static func link(text: String, cb: Callable) -> LinkButton:
	var b := LinkButton.new()
	b.text = text
	b.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", GOLD)
	b.add_theme_color_override("font_hover_color", Color("ffe6a8"))
	b.add_theme_color_override("font_pressed_color", Color("ffe6a8"))
	b.pressed.connect(func(): cb.call())
	return b

## Affiche (mobile, rangée « Autres modes ») : dégradé de la couleur du mode, icône en haut, nom en bas.
class PosterBg extends Control:
	var top := Color.WHITE
	var bottom := Color.BLACK
	var border := Color(0.94, 0.77, 0.36, 0.3)
	var tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]), PackedColorArray([top, top, bottom, bottom]))
		draw_rect(r, border, false, 1.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(10, 12), Vector2(34, 34)), false)

static func poster(name_text: String, icon: String, icon_color: Color, top: Color, bottom: Color, border: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 150)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	var bg := PosterBg.new()
	bg.top = top
	bg.bottom = bottom
	bg.border = border
	bg.tex = GameIcons.tex(icon, 68, icon_color, 1.3)
	b.add_child(bg)
	var l := Label.new()
	l.text = name_text.to_upper()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", spaced(UiTheme.F_TITLE_BOLD, 1))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", CREAM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_left = 10
	l.offset_right = -8
	l.offset_bottom = -10
	l.offset_top = -50
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	b.add_child(l)
	b.pressed.connect(func(): cb.call())
	return b
