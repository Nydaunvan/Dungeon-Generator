class_name AtelierSide
extends PanelContainer
## Menu latéral de l'atelier (direction B) : titre, recherche, sections groupées (Créer / Règles du jeu / Projet), puis en bas l'état
## de la partie (bannière « Tester la partie / Reprendre ») et le tutoriel. Remplace l'ancienne rangée d'onglets plats.

signal picked(id: String)
signal search_pressed

## [titre du groupe (clé de langue, "" = sans titre), [[id de section, clé de langue, icône], …]]
const GROUPS := [
	["", [["home", "ui.atelier.nav_home", "atelier"]]],
	["ui.atelier.g_create", [["levels", "ui.atelier.nav_levels", "map"], ["party", "ui.atelier.nav_party", "friends"],
		["classes", "ui.atelier.nav_classes", "swords"], ["spells", "ui.atelier.nav_spells", "spell"]]],
	["ui.atelier.g_rules", [["combat", "ui.atelier.nav_combat", "shield"], ["progress", "ui.atelier.nav_progress", "trend"],
		["explore", "ui.atelier.nav_explore", "compass"], ["traps", "ui.atelier.nav_traps", "warn"]]],
	["ui.atelier.g_project", [["identity", "ui.atelier.nav_identity", "idcard"], ["share", "ui.atelier.nav_share", "link"]]],
]

const GOLD := Color("f0c45c")
const TEXT := Color("e2d2b0")
const MUTED := Color("a8977a")

var buttons: Dictionary = {}          ## id de section → Button
var banner: VBoxContainer
var banner_text: Label
var btn_play: Button
var btn_resume: Button
var _counts: Dictionary = {}          ## id → Label (pastille de nombre)
var _group := ButtonGroup.new()

func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.04, 0.024, 0.9)
	sb.border_color = Color(0.941, 0.769, 0.361, 0.2)
	sb.border_width_right = 1
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(UiMetrics.css(268.0), 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := Label.new()
	title.text = L.t("ui.atelier.title")
	title.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 3))
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("ffd88a"))
	col.add_child(title)
	col.add_child(_search_field())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	sc.add_child(list)
	for g in GROUPS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		list.add_child(box)
		if str(g[0]) != "":
			var h := Label.new()
			h.text = L.t(str(g[0]))
			h.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE, 2))
			h.add_theme_font_size_override("font_size", 11)
			h.add_theme_color_override("font_color", Color("9a8863"))
			h.add_theme_constant_override("line_spacing", 0)
			var hm := MarginContainer.new()
			hm.add_theme_constant_override("margin_left", 10)
			hm.add_theme_constant_override("margin_bottom", 4)
			hm.add_child(h)
			box.add_child(hm)
		for it in g[1]:
			box.add_child(_item(str(it[0]), L.t(str(it[1])), str(it[2])))
	col.add_child(_footer())

## Faux champ de recherche (ouvre la recherche globale).
func _search_field() -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = L.t("ui.atelier.search_short")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = GameIcons.tex("search", 32, MUTED, 1.8)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, MUTED)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, _box(Color("14100a"), Color("3a2c18") if k != "hover" else Color("6b5430"), 10, 12, 9))
	b.custom_minimum_size = Vector2(0, 40)
	b.clip_text = true
	for k in ["normal", "hover", "pressed", "focus"]:
		(b.get_theme_stylebox(k) as StyleBoxFlat).content_margin_right = 62
	var key := Label.new()
	key.text = "Ctrl K"
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", MUTED)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	key.offset_right = -12
	b.add_child(key)
	b.pressed.connect(func(): search_pressed.emit())
	return b

static func _box(bg: Color, line: Color, radius: int, px: int, py: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = px
	sb.content_margin_right = px
	sb.content_margin_top = py
	sb.content_margin_bottom = py
	return sb

func _item(id: String, text: String, icon: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = GameIcons.tex(icon, 40, Color.WHITE, 1.7)
	b.add_theme_constant_override("icon_max_width", 19)
	b.add_theme_constant_override("h_separation", 12)
	b.add_theme_font_size_override("font_size", 14)
	for c in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(c, TEXT)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("ffd88a"))
	var clear := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", _box(clear, clear, 10, 10, 9))
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.04), clear, 10, 10, 9))
	var on := _box(Color(0.91, 0.71, 0.36, 0.14), Color("e8b45c"), 10, 10, 9)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", _box(clear, clear, 10, 10, 9))
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): picked.emit(id))
	buttons[id] = b
	var n := Label.new()
	n.add_theme_font_size_override("font_size", 12)
	n.add_theme_color_override("font_color", MUTED)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	n.grow_vertical = Control.GROW_DIRECTION_BOTH
	n.offset_right = -12
	b.add_child(n)
	_counts[id] = n
	return b

## Pied du menu : explication de l'état de la partie, bouton principal (tester / reprendre), reprise et tutoriel.
func _footer() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	var line := ColorRect.new()
	line.color = Color("3a2c18")
	line.custom_minimum_size = Vector2(0, 1)
	wrap.add_child(line)
	banner = VBoxContainer.new()
	banner.add_theme_constant_override("separation", 8)
	wrap.add_child(banner)
	banner_text = Label.new()
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_text.add_theme_font_size_override("font_size", 12)
	banner_text.add_theme_color_override("font_color", MUTED)
	banner.add_child(banner_text)
	btn_play = _action_button("", true)
	btn_play.icon = GameIcons.tex("play", 40, Color("2a1a06"), 2.0)
	btn_resume = _action_button("", false)
	banner.add_child(btn_play)
	banner.add_child(btn_resume)
	return wrap

func _action_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_font_size_override("font_size", 13)
	if primary:
		b.add_theme_color_override("font_color", Color("2a1a06"))
		b.add_theme_color_override("font_hover_color", Color("2a1a06"))
		b.add_theme_color_override("font_pressed_color", Color("2a1a06"))
		b.add_theme_color_override("icon_normal_color", Color("2a1a06"))
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, _box(Color("d9a444"), Color("ffd88a"), 10, 12, 8))
		b.add_theme_stylebox_override("hover", _box(Color("e8b45c"), Color("ffe6aa"), 10, 12, 8))
	else:
		b.add_theme_color_override("font_color", TEXT)
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, _box(Color(0.16, 0.12, 0.07, 0.7), Color("4a3920"), 10, 12, 8))
		b.add_theme_stylebox_override("hover", _box(Color(0.22, 0.16, 0.09, 0.8), Color("6b5430"), 10, 12, 8))
	return b

## Coche la section courante (sans déclencher le signal).
func select(id: String) -> void:
	for k in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)

## Pastille de nombre à droite d'une entrée (ex. nombre de niveaux).
func set_count(id: String, text: String) -> void:
	if _counts.has(id):
		(_counts[id] as Label).text = text
