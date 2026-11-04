class_name OnlineArt
extends RefCounted
## Habillage « Atlas Noir » de l'écran du mode en ligne (onglet Jouer, grand écran) : bannière de velours des cinq modes, parchemin de la fiche,
## plaques de bronze des tuiles, ruban rouge du bouton de lancement, filet lumineux, boussole et rouleau.
## Les images sont dans assets/ui/online/ ; tout est dessiné en tranches (coins à l'échelle uniforme, parties unies étirées).

const T_BANNER := preload("res://assets/ui/online/banner.png")
const T_PARCH := preload("res://assets/ui/online/parchment.png")
const T_RIBBON_ACTIVE := preload("res://assets/ui/online/ribbon_active.png")
const T_RIBBON_CTA := preload("res://assets/ui/online/ribbon_cta.png")
const T_PLATE := preload("res://assets/ui/online/plate.png")
const T_DIVIDER := preload("res://assets/ui/online/divider.png")
const T_COMPASS := preload("res://assets/ui/online/compass.png")
const T_SCROLL := preload("res://assets/ui/online/scroll.png")
const T_MEDALLION := preload("res://assets/ui/online/medallion.png")
const T_FRAME := preload("res://assets/ui/online/frame_dark.png")

## Encres sur le parchemin.
const INK := Color("24170b")
const INK_SOFT := Color("4a3520")
const INK_RED := Color("7c2a14")
const CREAM := Color("fff1d0")
const GOLD := Color("f0c45c")

## Emplacements des cinq modes sur la bannière (fractions de l'image rognée : x0, x1 ; puis y0, y1 de chaque plaque).
const SLOT_X := [0.1715, 0.8335]
const SLOT_Y := [[0.155, 0.258], [0.282, 0.388], [0.411, 0.514], [0.540, 0.640], [0.667, 0.770]]
const BANNER_ASPECT := 640.0 / 967.0

## Repères (pixels de l'image source) : bouts des rubans, marges du parchemin, des plaques.
const RIBBON_CAPS := {"cta": [300.0, 120.0], "active": [300.0, 140.0]}
const PLATE_CAPS := [110.0, 110.0]
const PARCH_M := [540.0, 330.0, 500.0, 420.0]      # gauche, haut, droite, bas : coins conservés (château, boussole, montagnes, navire)

# ------------------------------------------------------------------ dessin en tranches

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

## Neuf tranches : les quatre coins gardent leur forme (échelle uniforme `s`), les bords et le centre s'étirent.
static func draw_nine(ci: CanvasItem, tex: Texture2D, r: Rect2, m: Array, s: float, tint: Color = Color.WHITE) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var ml := minf(float(m[0]) * s, r.size.x * 0.45)
	var mt := minf(float(m[1]) * s, r.size.y * 0.45)
	var mr := minf(float(m[2]) * s, r.size.x * 0.45)
	var mb := minf(float(m[3]) * s, r.size.y * 0.45)
	var xs := [r.position.x, r.position.x + ml, r.end.x - mr, r.end.x]
	var ys := [r.position.y, r.position.y + mt, r.end.y - mb, r.end.y]
	var sx := [0.0, float(m[0]), tw - float(m[2]), tw]
	var sy := [0.0, float(m[1]), th - float(m[3]), th]
	for j in 3:
		for i in 3:
			var d := Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j])
			var sr := Rect2(sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j])
			if d.size.x > 0.0 and d.size.y > 0.0:
				ci.draw_texture_rect_region(tex, d, sr, tint)

# ------------------------------------------------------------------ bannière des modes

## Bannière de velours : l'image garde ses proportions, calée à gauche ; les rangées de modes se posent sur ses cinq plaques.
class ModeBanner extends Control:
	var rows: Array = []

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		clip_contents = false

	func _get_minimum_size() -> Vector2:
		return Vector2(roundf(size.y * OnlineArt.BANNER_ASPECT), 0.0)

	func art_rect() -> Rect2:
		var h := size.y
		return Rect2(0, 0, h * OnlineArt.BANNER_ASPECT, h)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			update_minimum_size()
			_layout()

	func add_row(c: Control) -> void:
		rows.append(c)
		add_child(c)
		_layout()

	func _layout() -> void:
		var a := art_rect()
		for i in mini(rows.size(), OnlineArt.SLOT_Y.size()):
			var c: Control = rows[i]
			var y0: float = OnlineArt.SLOT_Y[i][0]
			var y1: float = OnlineArt.SLOT_Y[i][1]
			c.position = Vector2(a.size.x * OnlineArt.SLOT_X[0], a.size.y * y0)
			c.size = Vector2(a.size.x * (OnlineArt.SLOT_X[1] - OnlineArt.SLOT_X[0]), a.size.y * (y1 - y0))

	func _draw() -> void:
		draw_texture_rect(OnlineArt.T_BANNER, art_rect(), false)

## Plaque d'un mode sur la bannière : le mode choisi s'allume dans un ruban rouge ; les autres restent dans l'ombre du velours.
class ModeRow extends Button:
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
		if selected:
			OnlineArt.draw_caps(self, OnlineArt.T_RIBBON_ACTIVE, Rect2(-w * 0.03, -h * 0.06, w * 1.06, h * 1.12), 300.0, 140.0)
		elif hot:
			draw_rect(Rect2(w * 0.1, h * 0.1, w * 0.9, h * 0.8), Color(0.94, 0.77, 0.36, 0.08), true)
		var cx := w * 0.138
		var cy := h * 0.51
		var q := h * 0.5
		if not selected:
			var r := h * 0.4
			var pts := PackedVector2Array([Vector2(cx, cy - r), Vector2(cx + r, cy), Vector2(cx, cy + r), Vector2(cx - r, cy), Vector2(cx, cy - r)])
			var col := Color(0.88, 0.31, 0.18, 0.75) if danger else Color(0.94, 0.77, 0.36, 0.55 if not hot else 0.9)
			draw_polyline(pts, col, 1.5, true)
		if glyph != null:
			draw_texture_rect(glyph, Rect2(cx - q * 0.5, cy - q * 0.5, q, q), false, Color.WHITE if selected or hot else Color(1, 1, 1, 0.85))
		var f: Font = UiTheme.font(UiTheme.F_TITLE_BOLD if selected else UiTheme.F_TITLE)
		var f2: Font = UiTheme.font(UiTheme.F_BODY)
		var fs2 := int(clampf(h * 0.2, 9.0, 14.0))
		var tx := w * 0.265
		var tw := w - tx - w * 0.07
		var sw := f2.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x if status != "" else 0.0
		var fs := int(clampf(h * 0.3, 10.0, 22.0))
		while fs > 9 and f.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > tw - (sw + 6.0 if status != "" else 0.0):
			fs -= 1
		while fs2 > 8 and f2.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x > tw:
			fs2 -= 1
		var tc := OnlineArt.CREAM if selected else Color("cdbb94")
		if danger and not selected:
			tc = Color("e69a80")
		draw_string(f, Vector2(tx, h * 0.46), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, tw, fs, tc)
		draw_string(f2, Vector2(tx, h * 0.46 + fs2 * 1.35), tag, HORIZONTAL_ALIGNMENT_LEFT, tw, fs2, Color("efe1c2") if selected else Color("a8977a"))
		if status != "":
			draw_string(f2, Vector2(w - sw - w * 0.07, h * 0.46), status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, OnlineArt.GOLD if selected else Color("a8977a"))

# ------------------------------------------------------------------ parchemin

## Parchemin de la fiche du mode : image en neuf tranches, boussole d'angle et rouleau posés par-dessus. Le contenu s'inscrit dans `inner`.
class ParchmentStage extends Control:
	var inner: MarginContainer
	var _scale := 0.5

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		clip_contents = false
		inner = MarginContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(inner)
		resized.connect(_relayout)

	func _relayout() -> void:
		_scale = clampf(minf(size.x * 0.8 / (OnlineArt.PARCH_M[0] + OnlineArt.PARCH_M[2]), size.y * 0.8 / (OnlineArt.PARCH_M[1] + OnlineArt.PARCH_M[3])), 0.2, 0.7)
		inner.add_theme_constant_override("margin_left", int(size.x * 0.17))
		inner.add_theme_constant_override("margin_right", int(size.x * 0.1))
		inner.add_theme_constant_override("margin_top", int(size.y * 0.125))
		inner.add_theme_constant_override("margin_bottom", int(size.y * 0.085))
		queue_redraw()

	func _draw() -> void:
		OnlineArt.draw_nine(self, OnlineArt.T_PARCH, Rect2(Vector2.ZERO, size), OnlineArt.PARCH_M, _scale)

## Décor par-dessus le parchemin (ne reçoit aucun clic) : boussole en bas à droite, rouleau en bas à gauche.
class Props extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var ch := clampf(size.y * 0.3, 70.0, 190.0)
		var cw := ch * float(OnlineArt.T_COMPASS.get_width()) / float(OnlineArt.T_COMPASS.get_height())
		draw_texture_rect(OnlineArt.T_COMPASS, Rect2(size.x - cw * 0.9, size.y - ch, cw, ch), false)
		var sh := ch * 0.55
		var sw := sh * float(OnlineArt.T_SCROLL.get_width()) / float(OnlineArt.T_SCROLL.get_height())
		draw_texture_rect(OnlineArt.T_SCROLL, Rect2(-sw * 0.1, size.y - sh, sw, sh), false)

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
	p.custom_minimum_size = Vector2(150, 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 26)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 7)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var l := Label.new()
	l.text = label.to_upper()
	l.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_BODY, 2))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("b8a684"))
	v.add_child(l)
	var val := Label.new()
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	val.add_theme_font_size_override("font_size", (14 if strong else 16) if big else 15)
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
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b

## Lien souligné à l'encre (sur le parchemin).
static func ink_link(text: String, cb: Callable) -> LinkButton:
	var b := LinkButton.new()
	b.text = text
	b.underline = LinkButton.UNDERLINE_MODE_ALWAYS
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK_RED)
	b.add_theme_color_override("font_pressed_color", INK_RED)
	b.pressed.connect(func(): cb.call())
	return b

## Filet lumineux doré (séparateur sous le titre).
static func divider(width: float = 360.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = T_DIVIDER
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(width, maxf(10.0, width * float(T_DIVIDER.get_height()) / float(T_DIVIDER.get_width())))
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return t

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
