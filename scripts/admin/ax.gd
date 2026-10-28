class_name Ax
extends RefCounted
## Kit de composants de l'atelier, calqué sur les maquettes validées (Design canvas « Atelier de création ») :
## mêmes couleurs, mêmes hauteurs, mêmes rayons, mêmes polices (Inter pour l'interface, Cinzel pour les titres).
## Aucune réutilisation des anciens champs du jeu : chaque composant est dessiné ici.

const GOLD := Color("e8b45c")
const GOLD_L := Color("ffd88a")
const CREAM := Color("f4e6c6")
const TEXT := Color("e2d2b0")
const MUTED := Color("b8a781")
const DIM := Color("9a8863")
const LINE := Color("3a2c18")
const LINE2 := Color("4a3920")
const LINE3 := Color("5a4526")
const FIELD := Color("14100a")
const TRACK := Color("2a2014")
const RED := Color("ff8a78")
const RED_LINE := Color("6b2a22")
const GREEN := Color("6fcf7f")
const BLUE := Color("6aa8ff")
const CARD := Color(0.102, 0.075, 0.043, 0.85)        # rgba(26,19,11,.85)
const CARD2 := Color(0.118, 0.086, 0.051, 0.8)        # rgba(30,22,13,.8)
const GHOST := Color(0.157, 0.118, 0.071, 0.7)        # rgba(40,30,18,.7)
const GOLD_BG := Color(0.91, 0.706, 0.361, 0.14)      # rgba(232,180,92,.14)
const GOLD_BG2 := Color(0.91, 0.706, 0.361, 0.1)
const CLEAR := Color(0, 0, 0, 0)

static var _fonts: Dictionary = {}
static var _grad: StyleBoxTexture = null
static var _knob_tex: Texture2D = null

# ------------------------------------------------------------------ polices

## Inter (variable) à la graisse demandée (400 / 500 / 600), avec l'emoji en repli.
static func inter(w: int = 400, spacing: int = 0) -> Font:
	var key := "i%d|%d" % [w, spacing]
	if not _fonts.has(key):
		var fv := FontVariation.new()
		var base: Font = load("res://assets/fonts/InterVariable.ttf") if ResourceLoader.exists("res://assets/fonts/InterVariable.ttf") else UiTheme.font(UiTheme.F_BODY)
		fv.base_font = base
		var tag := TextServerManager.get_primary_interface().name_to_tag("weight")
		fv.variation_opentype = {tag: w}
		fv.spacing_glyph = spacing
		if ResourceLoader.exists(UiTheme.F_EMOJI):
			fv.fallbacks = [load(UiTheme.F_EMOJI)]
		_fonts[key] = fv
	return _fonts[key]

static func cinzel(spacing: int = 0) -> Font:
	return GameWidgets.spaced(UiTheme.F_TITLE_BOLD, spacing) if spacing != 0 else UiTheme.font(UiTheme.F_TITLE_BOLD)

# ------------------------------------------------------------------ styles

static func sb(bg: Color, line: Color = CLEAR, r: int = 10, bw: int = 1, px: int = 0, py: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = line
	s.set_border_width_all(bw if line.a > 0.0 else 0)
	s.set_corner_radius_all(r)
	s.content_margin_left = px
	s.content_margin_right = px
	s.content_margin_top = py
	s.content_margin_bottom = py
	return s

static func style_all(c: Control, st: StyleBox, names: Array = ["normal", "hover", "pressed", "focus", "disabled"]) -> void:
	for n in names:
		c.add_theme_stylebox_override(n, st)

## Fond dégradé des boutons principaux (or → bronze), arrondi, en 9 tranches.
static func _grad_box() -> StyleBoxTexture:
	if _grad == null:
		var n := 48
		var r := 10.0
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var top := GOLD
		var bot := Color("b97f2c")
		var edge := GOLD_L
		for y in n:
			for x in n:
				var cx := clampf(float(x) + 0.5, r, n - r)
				var cy := clampf(float(y) + 0.5, r, n - r)
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
				var a := clampf(r - d + 0.5, 0.0, 1.0)
				var col := top.lerp(bot, float(y) / float(n - 1))
				if d > r - 1.0 and a > 0.0:
					col = edge
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		var st := StyleBoxTexture.new()
		st.texture = ImageTexture.create_from_image(img)
		st.texture_margin_left = 12
		st.texture_margin_right = 12
		st.texture_margin_top = 12
		st.texture_margin_bottom = 12
		_grad = st
	return _grad

static func _lighter(c: Color, k: float = 0.12) -> Color:
	return Color(minf(c.r + k * 0.6, 1.0), minf(c.g + k * 0.6, 1.0), minf(c.b + k * 0.6, 1.0), minf(c.a + k * 0.25, 1.0))

# ------------------------------------------------------------------ texte

static func lab(text: String, size: int = 14, color: Color = TEXT, w: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", inter(w))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Texte qui passe à la ligne.
static func para(text: String, size: int = 13, color: Color = MUTED, w: int = 400) -> Label:
	var l := lab(text, size, color, w)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l

static func title(text: String, size: int = 30, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override("font", cinzel())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## Petit titre en capitales espacées (« NOM », « ÉCOLE »…).
static func kicker(text: String, size: int = 12, color: Color = DIM) -> Label:
	var l := lab(text.to_upper(), size, color, 600)
	l.add_theme_font_override("font", inter(600, 1))
	return l

## Intertitre de carte en Cinzel doré (« CARACTÉRISTIQUES »).
static func gold_cap(text: String, size: int = 14) -> Label:
	var l := title(text.to_upper(), size, GOLD)
	l.add_theme_font_override("font", cinzel(1))
	return l

static func ico(name: String, px: int = 18, color: Color = GOLD, stroke: float = 1.7) -> TextureRect:
	return GameIcons.rect(name, px, color, stroke)

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func grow(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func line(color: Color = LINE) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func vline(color: Color = LINE) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(1, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Conteneur à fond/bordure : renvoie le PanelContainer (ajoutez-y un seul enfant).
static func panel(bg: Color, line_c: Color = CLEAR, r: int = 12, px: int = 14, py: int = 14, bw: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, line_c, r, bw, px, py))
	return p

static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m

## Carte de page (maquettes des règles) : bordure #4a3920, rayon 16, titre Cinzel 17 + indication. Renvoie le corps.
static func card(parent: Control, title_text: String = "", hint: String = "", pad: int = 20, gap: int = 14, border: Color = LINE2, bg: Color = CARD) -> VBoxContainer:
	var p := panel(bg, border, 16, pad, pad)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.set_meta("panel_title", title_text)
	parent.add_child(p)
	var v := vbox(gap)
	p.add_child(v)
	if title_text != "":
		var h := vbox(2)
		h.add_child(title(title_text, 17))
		if hint != "":
			h.add_child(para(hint, 12, MUTED))
		v.add_child(h)
	v.set_meta("card", p)
	return v

# ------------------------------------------------------------------ boutons

## kind : "ghost" (sobre), "gold" (liseré or), "primary" (dégradé), "danger" (rouge), "flat" (transparent).
static func btn(text: String, cb: Callable = Callable(), kind: String = "ghost", h: float = 40.0, px: int = 16, size: int = 13, icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", inter(600 if kind in ["gold", "primary"] else 500))
	b.add_theme_font_size_override("font_size", size)
	var bg := GHOST
	var ln := LINE2
	var fg := TEXT
	match kind:
		"gold":
			bg = GOLD_BG
			ln = GOLD
			fg = GOLD_L
		"danger":
			bg = Color(0.314, 0.094, 0.071, 0.35)
			ln = RED_LINE
			fg = RED
		"flat":
			bg = CLEAR
			ln = CLEAR
		"primary":
			fg = Color("2a1a06")
	if kind == "primary":
		var g: StyleBoxTexture = _grad_box().duplicate()
		g.content_margin_left = px
		g.content_margin_right = px
		b.add_theme_stylebox_override("normal", g)
		b.add_theme_stylebox_override("focus", g)
		b.add_theme_stylebox_override("disabled", g)
		var gh: StyleBoxTexture = g.duplicate()
		gh.modulate_color = Color(1.12, 1.12, 1.12)
		b.add_theme_stylebox_override("hover", gh)
		b.add_theme_stylebox_override("pressed", gh)
	else:
		b.add_theme_stylebox_override("normal", sb(bg, ln, 10, 1, px, 0))
		b.add_theme_stylebox_override("focus", sb(bg, ln, 10, 1, px, 0))
		b.add_theme_stylebox_override("disabled", sb(bg, ln, 10, 1, px, 0))
		b.add_theme_stylebox_override("hover", sb(_lighter(bg) if bg.a > 0.0 else Color(1, 1, 1, 0.05), _lighter(ln, 0.2) if ln.a > 0.0 else CLEAR, 10, 1, px, 0))
		b.add_theme_stylebox_override("pressed", sb(_lighter(bg) if bg.a > 0.0 else Color(1, 1, 1, 0.05), _lighter(ln, 0.2) if ln.a > 0.0 else CLEAR, 10, 1, px, 0))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", DIM)
	if icon != "":
		b.icon = GameIcons.tex(icon, 40, fg, 2.0)
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_constant_override("h_separation", 8)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Bouton carré avec icône seule (retour, retirer…).
static func icon_btn(icon: String, cb: Callable, size: float = 36.0, color: Color = GOLD, kind: String = "ghost", tip: String = "") -> Button:
	var b := btn("", cb, kind, size, 0, 13)
	b.custom_minimum_size = Vector2(size, size)
	b.icon = GameIcons.tex(icon, 40, color, 1.9)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", int(size * 0.5))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	return b

## Pastille de filtre (hauteur 34, rayon 17).
static func pill(text: String, on: bool, cb: Callable = Callable(), tint: Color = GOLD, h: float = 34.0, size: int = 13, px: int = 13) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", size)
	b.set_meta("pill", {"tint": tint, "h": h, "px": px})
	pill_set(b, on)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

## Change l'état allumé / éteint d'une pastille.
static func pill_set(b: Button, on: bool) -> void:
	var m: Dictionary = b.get_meta("pill")
	var tint: Color = m.tint
	var h: float = m.h
	var px: int = m.px
	b.add_theme_font_override("font", inter(600 if on else 400))
	var bg := Color(tint.r, tint.g, tint.b, 0.14) if on else Color(0.118, 0.086, 0.051, 0.7)
	var ln := tint if on else LINE
	for k in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, sb(bg, ln, int(h / 2.0), 1, px, 0))
	b.add_theme_stylebox_override("hover", sb(_lighter(bg), ln if on else Color("6b5430"), int(h / 2.0), 1, px, 0))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, GOLD_L if on else MUTED)

## Onglets soulignés : `items` = [[id, libellé], …].
static func tabs(items: Array, current: String, cb: Callable, h: float = 42.0, size: int = 14, px: int = 18, accent: Color = GOLD) -> Control:
	var wrap := vbox(0)
	var row := hbox(4)
	wrap.add_child(row)
	for it in items:
		var id: String = it[0]
		var on := id == current
		var b := Button.new()
		b.text = str(it[1])
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(0, h)
		b.add_theme_font_override("font", inter(600 if on else 500))
		b.add_theme_font_size_override("font_size", size)
		for k in ["normal", "pressed", "focus", "hover"]:
			var s := sb(Color(1, 1, 1, 0.04) if (k == "hover" and not on) else CLEAR, CLEAR, 0, 0, px, 0)
			s.border_width_bottom = 2
			s.border_color = accent if on else CLEAR
			b.add_theme_stylebox_override(k, s)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, GOLD_L if on else MUTED)
		b.pressed.connect(func(): cb.call(id))
		row.add_child(b)
	var ln := line()
	ln.position.y = -1
	wrap.add_child(ln)
	wrap.add_theme_constant_override("separation", -1)
	return wrap

## Sélecteur segmenté (« Groupe de départ | Objets de base »).
static func seg(items: Array, current: String, cb: Callable) -> Control:
	var p := panel(FIELD, LINE, 12, 4, 4)
	var row := hbox(4)
	p.add_child(row)
	for it in items:
		var id: String = it[0]
		var on := id == current
		var b := Button.new()
		b.text = str(it[1])
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_override("font", inter(600 if on else 400))
		b.add_theme_font_size_override("font_size", 13)
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, sb(GOLD if on else CLEAR, CLEAR, 9, 0, 18, 0))
		b.add_theme_stylebox_override("hover", sb(GOLD if on else Color(1, 1, 1, 0.05), CLEAR, 9, 0, 18, 0))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color("2a1a06") if on else MUTED)
		b.pressed.connect(func(): cb.call(id))
		row.add_child(b)
	return p

## Étiquette arrondie (« Rage », « Boss », « 18 × 12 cases »).
static func chip(text: String, color: Color = TEXT, bg: Color = Color("241a0e"), line_c: Color = LINE, size: int = 12, r: int = 12, px: int = 10, py: int = 4) -> PanelContainer:
	var p := panel(bg, line_c, r, px, py)
	p.add_child(lab(text, size, color))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Clique n'importe où dans `c` (les enfants laissent passer la souris).
static func clickable(c: Control, cb: Callable) -> void:
	_ignore(c)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			cb.call())

static func _ignore(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control and not (ch is BaseButton or ch is LineEdit):
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore(ch)

# ------------------------------------------------------------------ champs

static func _field_styles(c: Control, h: float, r: int, px: int) -> void:
	c.add_theme_stylebox_override("normal", sb(FIELD, LINE2, r, 1, px, 0))
	c.add_theme_stylebox_override("focus", sb(FIELD, GOLD, r, 1, px, 0))
	c.add_theme_stylebox_override("read_only", sb(FIELD, LINE2, r, 1, px, 0))
	c.add_theme_stylebox_override("disabled", sb(FIELD, LINE, r, 1, px, 0))
	c.custom_minimum_size.y = h

## Champ texte (hauteur 40, bordure #4a3920). `on_commit(texte)` à la validation ou en quittant le champ.
static func field(text: String, on_commit: Callable = Callable(), h: float = 40.0, size: int = 14, placeholder: String = "", secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.secret = secret
	e.placeholder_text = placeholder
	e.context_menu_enabled = true
	e.add_theme_font_override("font", inter(400))
	e.add_theme_font_size_override("font_size", size)
	e.add_theme_color_override("font_color", CREAM)
	e.add_theme_color_override("font_placeholder_color", DIM)
	e.add_theme_color_override("caret_color", GOLD)
	e.add_theme_color_override("selection_color", Color(GOLD.r, GOLD.g, GOLD.b, 0.35))
	_field_styles(e, h, 10, 12)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_commit.is_valid():
		var last := {"v": text}
		var fire := func(_x = ""):
			if e.text != last.v:
				last.v = e.text
				on_commit.call(e.text)
		e.text_submitted.connect(fire)
		e.focus_exited.connect(fire)
	return e

static func area(text: String, placeholder: String = "", h: float = 130.0, read_only: bool = false, mono: bool = false) -> TextEdit:
	var e := TextEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.editable = not read_only
	e.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	e.custom_minimum_size.y = h
	e.add_theme_font_override("font", inter(400))
	e.add_theme_font_size_override("font_size", 12)
	e.add_theme_color_override("font_color", DIM if read_only else CREAM)
	e.add_theme_color_override("font_placeholder_color", DIM)
	e.add_theme_color_override("caret_color", GOLD)
	e.add_theme_stylebox_override("normal", sb(FIELD, LINE if read_only else LINE2, 10, 1, 14, 12))
	e.add_theme_stylebox_override("focus", sb(FIELD, GOLD, 10, 1, 14, 12))
	e.add_theme_stylebox_override("read_only", sb(FIELD, LINE, 10, 1, 14, 12))
	return e

static func fmt(v: float, step: float = 1.0) -> String:
	if step >= 1.0 or is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).rstrip("0").rstrip(".")

static func _num_of(t: String, fallback: float) -> float:
	var rx := RegEx.new()
	rx.compile("-?\\d+(?:[.,]\\d+)?")
	var m := rx.search(t)
	if m == null:
		return fallback
	return float(m.get_string().replace(",", "."))

## Champ numérique « − 12 + » (hauteur 36). `on_change(valeur)` à chaque modification validée. Renvoie le conteneur ;
## `get_meta("le")` donne le LineEdit, `get_meta("set").call(v)` change la valeur sans déclencher `on_change`.
static func stepper(value: float, lo: float, hi: float, step: float, on_change: Callable, h: float = 36.0, unit: String = "") -> PanelContainer:
	var p := panel(FIELD, LINE2, 9, 4, 0)
	p.custom_minimum_size.y = h
	var row := hbox(0)
	p.add_child(row)
	var le := LineEdit.new()
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_override("font", inter(600))
	le.add_theme_font_size_override("font_size", 14)
	le.add_theme_color_override("font_color", CREAM)
	le.add_theme_color_override("caret_color", GOLD)
	for k in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(k, sb(CLEAR, CLEAR, 4, 0, 2, 0))
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.size_flags_vertical = Control.SIZE_FILL
	var cur := {"v": clampf(value, lo, hi)}
	le.text = fmt(cur.v, step) + unit
	var setv := func(v: float, emit: bool):
		v = clampf(snappedf(v, step), lo, hi)
		cur.v = v
		le.text = fmt(v, step) + unit
		if emit and on_change.is_valid():
			on_change.call(v)
	var mk := func(sym: String, col: Color, d: float) -> Button:
		var b := Button.new()
		b.text = sym
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(32, 0)
		b.add_theme_font_override("font", inter(500))
		b.add_theme_font_size_override("font_size", 16)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, col)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		b.pressed.connect(func(): setv.call(cur.v + d * step, true))
		return b
	row.add_child(mk.call("−", MUTED, -1.0))
	row.add_child(le)
	row.add_child(mk.call("+", GOLD, 1.0))
	var commit := func(_x = ""):
		setv.call(_num_of(le.text, cur.v), true)
	le.text_submitted.connect(commit)
	le.focus_exited.connect(commit)
	le.focus_entered.connect(func(): le.text = fmt(cur.v, step))
	p.set_meta("le", le)
	p.set_meta("set", func(v: float): setv.call(v, false))
	return p

## Libellé au-dessus d'un champ (12 px, #b8a781).
static func labeled(text: String, ctl: Control, gap: int = 4) -> VBoxContainer:
	var v := vbox(gap)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lab(text, 12, MUTED))
	v.add_child(ctl)
	return v

## Liste déroulante (hauteur 40, chevron doré). `options` = [[valeur, libellé], …].
static func select(options: Array, current: Variant, on_pick: Callable, h: float = 40.0, size: int = 14) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	o.add_theme_font_override("font", inter(400))
	o.add_theme_font_size_override("font_size", size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		o.add_theme_color_override(c, CREAM)
	o.add_theme_stylebox_override("normal", sb(FIELD, LINE2, 10, 1, 12, 0))
	o.add_theme_stylebox_override("hover", sb(FIELD, Color("6b5430"), 10, 1, 12, 0))
	o.add_theme_stylebox_override("pressed", sb(FIELD, GOLD, 10, 1, 12, 0))
	o.add_theme_stylebox_override("focus", sb(FIELD, GOLD, 10, 1, 12, 0))
	o.add_theme_stylebox_override("disabled", sb(FIELD, LINE, 10, 1, 12, 0))
	o.add_theme_icon_override("arrow", GameIcons.tex("chevdown", 32, GOLD, 2.0))
	o.add_theme_constant_override("arrow_margin", 4)
	o.add_theme_constant_override("icon_max_width", 16)
	o.custom_minimum_size.y = h
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pop := o.get_popup()
	pop.add_theme_font_override("font", inter(400))
	pop.add_theme_font_size_override("font_size", size)
	pop.add_theme_stylebox_override("panel", sb(Color("16100a"), LINE3, 12, 1, 6, 6))
	pop.add_theme_stylebox_override("hover", sb(GOLD_BG, CLEAR, 8, 0, 6, 4))
	pop.add_theme_color_override("font_color", TEXT)
	pop.add_theme_color_override("font_hover_color", GOLD_L)
	pop.add_theme_constant_override("v_separation", 6)
	var vals: Array = []
	var sel := 0
	for i in options.size():
		o.add_item(str(options[i][1]))
		vals.append(options[i][0])
		if options[i][0] == current:
			sel = i
	if options.size() > 0:
		o.select(sel)
	if on_pick.is_valid():
		o.item_selected.connect(func(i: int): on_pick.call(vals[i]))
	return o

static func switch(on: bool, cb: Callable) -> AxSwitch:
	var s := AxSwitch.new(on)
	if cb.is_valid():
		s.toggled.connect(cb)
	return s

# ------------------------------------------------------------------ curseur + valeur (pages de règles)

static func _knob() -> Texture2D:
	if _knob_tex == null:
		var n := 32                                    # dessiné en 32 px pour l'écran HiDPI, affiché à 16
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n * 0.5, n * 0.5))
				var a := clampf(n * 0.5 - d + 0.5, 0.0, 1.0)
				var col := GOLD_L if d < n * 0.5 - 4.0 else FIELD
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		_knob_tex = ImageTexture.create_from_image(img)
	return _knob_tex

## Curseur doré (piste 6 px #2a2014, remplissage or, pouce rond #ffd88a cerclé #14100a).
static func slider(value: float, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.scrollable = false
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(0, 20)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := sb(TRACK, CLEAR, 3, 0, 0, 3)
	var fill := sb(Color("d9a444"), CLEAR, 3, 0, 0, 3)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var k := _knob()
	for n in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(n, k)
	s.add_theme_constant_override("center_grabber", 0)
	return s

## Ligne de réglage des pages de règles : libellé + « par défaut », curseur 140 px, case de valeur 62 px (bordure or si modifiée).
## `on_change(valeur)` est appelé à chaque modification ; la valeur affichée est bornée et arrondie au pas.
static func setting(parent: Control, label: String, value: float, lo: float, hi: float, step: float, def: float, unit: String, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size.y = 40
	row.set_meta("setting", label)
	var left := vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := para(label, 13, CREAM, 500)
	left.add_child(name_l)
	var def_l := lab("", 12, DIM)
	if not is_nan(def):
		left.add_child(def_l)
	row.add_child(left)
	var sl := slider(value, lo, hi, step)
	sl.custom_minimum_size.x = 140
	row.add_child(sl)
	var box := panel(FIELD, LINE2, 8, 0, 0)
	box.custom_minimum_size = Vector2(62, 34)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var le := LineEdit.new()
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_override("font", inter(600))
	le.add_theme_font_size_override("font_size", 13)
	le.add_theme_color_override("caret_color", GOLD)
	for k in ["normal", "focus", "read_only"]:
		le.add_theme_stylebox_override(k, sb(CLEAR, CLEAR, 4, 0, 2, 0))
	box.add_child(le)
	row.add_child(box)
	var cur := {"v": value}
	var refresh := func():
		var mod := not is_nan(def) and not is_equal_approx(cur.v, def)
		le.text = fmt(cur.v, step) + unit
		le.add_theme_color_override("font_color", GOLD_L if mod else TEXT)
		box.add_theme_stylebox_override("panel", sb(FIELD, GOLD if mod else LINE2, 8, 1, 0, 0))
		def_l.text = (L.fa(L.t("ui.atelier.default_value"), fmt(def, step) + unit) if mod else L.t("ui.atelier.default_plain")) if not is_nan(def) else ""
		def_l.add_theme_color_override("font_color", GOLD if mod else DIM)
	refresh.call()
	var apply := func(v: float):
		v = clampf(snappedf(v, step), lo, hi)
		cur.v = v
		sl.set_value_no_signal(v)
		refresh.call()
		if on_change.is_valid():
			on_change.call(v)
	sl.value_changed.connect(func(v: float): apply.call(v))
	var commit := func(_x = ""):
		apply.call(_num_of(le.text, cur.v))
	le.text_submitted.connect(commit)
	le.focus_exited.connect(commit)
	le.focus_entered.connect(func(): le.text = fmt(cur.v, step))
	parent.add_child(row)
	return row

## Ligne d'interrupteur (« Régénération active »).
static func switch_row(parent: Control, label: String, on: bool, cb: Callable, detail: String = "") -> Control:
	var p := panel(Color(0.118, 0.086, 0.051, 0.9), LINE2, 12, 14, 12)
	p.set_meta("setting", label)
	var h := hbox(14)
	p.add_child(h)
	h.add_child(switch(on, cb))
	var v := vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(para(label, 14, CREAM, 600))
	if detail != "":
		v.add_child(para(detail, 12, MUTED))
	h.add_child(v)
	parent.add_child(p)
	return p

# ------------------------------------------------------------------ fond de page

## Fond radial (maquettes : radial-gradient(1200px 700px at 60% 0%, #241a10, #0f0b07 60%, #0a0705)).
static func backdrop() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color("241a10"), Color("0f0b07"), Color("0a0705")])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.6, 0.0)
	t.fill_to = Vector2(1.43, 0.0)
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r

## En-tête de page : kicker + titre Cinzel.
static func head(kicker_text: String, title_text: String, size: int = 30) -> VBoxContainer:
	var v := vbox(4)
	if kicker_text != "":
		v.add_child(kicker(kicker_text))
	v.add_child(title(title_text, size))
	return v

## Page à défilement (règles, accueil, projet) : renvoie la colonne de contenu, dans un ScrollContainer plein cadre.
static func scroll_page(host: Control, admin: Node, px: int = 40, py: int = 28, gap: int = 20) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var narrow: bool = admin.size.x < 860.0
	var pxx := 16 if narrow else px
	m.add_theme_constant_override("margin_left", pxx)
	m.add_theme_constant_override("margin_right", pxx)
	m.add_theme_constant_override("margin_top", py)
	m.add_theme_constant_override("margin_bottom", py)
	sc.add_child(m)
	var v := vbox(gap)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(v)
	admin.set("_scroll", sc)
	return v

# ------------------------------------------------------------------ enregistrement automatique

static var _timer: Timer = null
static var _act: Callable = Callable()

## À appeler une fois par page : `act` (en général admin.save) sera exécuté 0,5 s après la dernière modification.
static func bind(host: Node, act: Callable) -> void:
	_act = act
	if _timer == null or not is_instance_valid(_timer):
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.wait_time = 0.5
		host.add_child(_timer)
		_timer.timeout.connect(func():
			if _act.is_valid():
				_act.call())

## Une modification vient d'être faite dans la configuration : enregistrement différé.
static func changed() -> void:
	if _timer != null and is_instance_valid(_timer):
		_timer.start()

## Exécute tout de suite l'enregistrement en attente (avant de quitter ou de reconstruire une page).
static func flush() -> void:
	if _timer != null and is_instance_valid(_timer) and not _timer.is_stopped():
		_timer.stop()
		if _act.is_valid():
			_act.call()
