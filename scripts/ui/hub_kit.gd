class_name HubKit
extends RefCounted
## Petits éléments d'interface communs aux fenêtres du mode en ligne (cartes, pastilles, onglets, fiches, tableaux) : une seule apparence,
## dans le cadre habituel des fenêtres du jeu.

const CARD_BG := Color(0, 0, 0, 0.30)
const GOOD := Color("9cc79a")
const BAD := Color("e08a7a")
const WARN := Color("e0b87a")
const FIRE := Color("ff9a52")
const MEDALS := [Color("ffd24a"), Color("d8dde6"), Color("cd7f32")]

static func card(border: Color = UiTheme.BRONZE_DARK, bg: Color = CARD_BG, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 2
	sb.content_margin_bottom = pad - 2
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v

static func label(text: String, color: Color = UiTheme.PARCH, size: int = 14, bold: bool = false, wrap: bool = true, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align as HorizontalAlignment
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 80
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	return l

## Bouton principal ou secondaire, même apparence que les boutons du bas des fenêtres.
static func button(text: String, cb: Callable, primary: bool = false, min_h: float = 40.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, min_h)
	var st := IronBox.modal_styles(primary)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color("ffd88a") if primary else Color("e2d2b0"))
	b.add_theme_color_override("font_hover_color", Color("fff0c8") if primary else Color("f4e6c6"))
	b.add_theme_color_override("font_disabled_color", Color("7a6a50"))
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b

## Bouton plat à bascule (onglet, pastille) : fond sombre, liseré doré quand il est actif.
static func toggle(text: String, active: bool, cb: Callable, size: int = 14, pad_x: int = 12, pad_y: int = 6) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	style_toggle(b, pad_x, pad_y)
	b.pressed.connect(func():
		if cb.is_valid():
			cb.call())
	return b

static func style_toggle(b: Button, pad_x: int = 12, pad_y: int = 6) -> void:
	var states := {"normal": [Color(0, 0, 0, 0.30), UiTheme.BRONZE_DARK], "hover": [Color(0.2, 0.15, 0.08, 0.7), UiTheme.BRONZE],
		"pressed": [Color(0.32, 0.22, 0.08, 0.85), UiTheme.GOLD], "hover_pressed": [Color(0.36, 0.25, 0.1, 0.9), UiTheme.GOLD],
		"disabled": [Color(0, 0, 0, 0.2), Color(0.3, 0.25, 0.2, 0.5)]}
	for k in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[k][0]
		sb.border_color = states[k][1]
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(7)
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
		b.add_theme_stylebox_override(k, sb)
	b.add_theme_color_override("font_color", Color("e2d2b0"))
	b.add_theme_color_override("font_pressed_color", Color("ffd88a"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ffe6a8"))
	b.add_theme_color_override("font_hover_color", Color("f4e6c6"))
	b.add_theme_color_override("font_disabled_color", Color("7a6a50"))

static func progress(value: float, lo: float, hi: float, height: float = 10.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = lo
	bar.max_value = maxf(hi, lo + 1.0)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(int(height / 2.0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e0b04a")
	fill.set_corner_radius_all(int(height / 2.0))
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## Fiche « icône · titre · texte » en grille (1 ou 2 colonnes).
static func facts(parent: Control, rows: Array, columns: int) -> void:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	for r in rows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := label(str(r[0]), UiTheme.PARCH, 18, false, false, HORIZONTAL_ALIGNMENT_CENTER)
		ic.custom_minimum_size = Vector2(26, 0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		var v := vbox(0)
		v.add_child(label(str(r[1]), UiTheme.GOLD, 13, true))
		var tx := label(str(r[2]), UiTheme.PARCH, 13)
		if r.size() > 3 and r[3] is Color:
			tx.add_theme_color_override("font_color", r[3])
		v.add_child(tx)
		h.add_child(v)
		g.add_child(h)

static func rank_color(i: int) -> Color:
	return MEDALS[i] if i >= 0 and i < MEDALS.size() else UiTheme.PARCH

## Date du jour à Paris (« AAAA-MM-JJ »), comme le serveur : UTC+1, UTC+2 du dernier dimanche de mars au dernier dimanche d'octobre.
static func paris_date(unix: float) -> String:
	var year := int(Time.get_datetime_dict_from_unix_time(int(unix)).year)
	var on := _last_sunday_utc(year, 3)
	var off := _last_sunday_utc(year, 10)
	var offset := 7200 if unix >= on and unix < off else 3600
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + offset)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

static func _last_sunday_utc(year: int, month: int) -> int:
	var day := 31
	while day > 24:
		var t := Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 1, "minute": 0, "second": 0})
		if int(Time.get_datetime_dict_from_unix_time(t).weekday) == 0:
			return t
		day -= 1
	return 0

## Date ISO du serveur -> « jj/mm hh:mm » à l'heure de l'ordinateur.
static func short_date(v: Variant) -> String:
	return SuperAdminModal.date(v)
