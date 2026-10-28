class_name AtelierSide
extends PanelContainer
## Navigation de l'atelier (maquette « Nav ») : retour + ATELIER, recherche Ctrl K, sections groupées (Créer / Règles du jeu /
## Projet), puis en bas l'état de la session et le bouton « Tester la partie ».

signal picked(id: String)
signal search_pressed
signal back_pressed

## [titre du groupe (clé de langue, "" = sans titre), [[id de section, clé de langue, icône], …]]
const GROUPS := [
	["", [["home", "ui.atelier.nav_home", "atelier"]]],
	["ui.atelier.g_create", [["levels", "ui.atelier.nav_levels", "map"], ["party", "ui.atelier.nav_party", "friends"],
		["classes", "ui.atelier.nav_classes", "swords"], ["spells", "ui.atelier.nav_spells", "spell"]]],
	["ui.atelier.g_rules", [["combat", "ui.atelier.nav_combat", "shield"], ["progress", "ui.atelier.nav_progress", "trend"],
		["explore", "ui.atelier.nav_explore", "compass"], ["traps", "ui.atelier.nav_traps", "warn"]]],
	["ui.atelier.g_project", [["identity", "ui.atelier.nav_identity", "idcard"], ["share", "ui.atelier.nav_share", "link"]]],
]

var buttons: Dictionary = {}          ## id de section → Button
var banner: VBoxContainer
var banner_text: Label
var btn_play: Button
var btn_resume: Button
var dirty_label: Label
var _counts: Dictionary = {}          ## id → Label (nombre à droite de l'entrée)
var _group := ButtonGroup.new()

func _init() -> void:
	add_theme_stylebox_override("panel", Ax.sb(Color(0.055, 0.039, 0.024, 0.96), Ax.LINE, 0, 0, 14, 20))
	(get_theme_stylebox("panel") as StyleBoxFlat).border_width_right = 1
	custom_minimum_size = Vector2(280, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := Ax.vbox(14)
	add_child(col)
	# retour + titre
	var top := Ax.hbox(10)
	top.add_child(Ax.margin(Ax.icon_btn("back", func(): back_pressed.emit(), 36.0, Ax.GOLD, "ghost", L.t("admin.main.retour_au_jeu")), 6, 0, 0, 0))
	var t := Label.new()
	t.text = L.t("ui.atelier.title")
	t.add_theme_font_override("font", Ax.cinzel(2))
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Ax.GOLD_L)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(t)
	col.add_child(top)
	col.add_child(_search_field())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var list := Ax.vbox(14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for g in GROUPS:
		var box := Ax.vbox(3)
		list.add_child(box)
		if str(g[0]) != "":
			var h := Ax.kicker(L.t(str(g[0])), 11)
			h.add_theme_font_override("font", Ax.inter(600, 1))
			box.add_child(Ax.margin(h, 10, 0, 0, 4))
		for it in g[1]:
			box.add_child(_item(str(it[0]), L.t(str(it[1])), str(it[2])))
	col.add_child(_footer())

## Faux champ de recherche (ouvre la recherche globale).
func _search_field() -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = L.t("ui.atelier.search_short")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = GameIcons.tex("search", 32, Ax.MUTED, 1.8)
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_override("font", Ax.inter(400))
	b.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Ax.MUTED)
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := Ax.sb(Ax.FIELD, Ax.LINE if k != "hover" else Color("6b5430"), 10, 1, 12, 0)
		s.content_margin_right = 74
		b.add_theme_stylebox_override(k, s)
	b.custom_minimum_size = Vector2(0, 40)
	b.clip_text = true
	var key := Ax.panel(Color(0, 0, 0, 0), Ax.LINE, 5, 6, 1)
	key.add_child(Ax.lab("Ctrl K", 11, Ax.MUTED))
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	key.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	key.grow_vertical = Control.GROW_DIRECTION_BOTH
	key.offset_right = -10
	b.add_child(key)
	b.pressed.connect(func(): search_pressed.emit())
	return b

func _item(id: String, text: String, icon: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _group
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.icon = GameIcons.tex(icon, 40, Color.WHITE, 1.7)
	b.add_theme_constant_override("icon_max_width", 19)
	b.add_theme_constant_override("h_separation", 12)
	b.add_theme_font_override("font", Ax.inter(500))
	b.add_theme_font_size_override("font_size", 14)
	for c in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		b.add_theme_color_override(c, Ax.TEXT)
	for c in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(c, Ax.GOLD_L)
	b.add_theme_stylebox_override("normal", Ax.sb(Ax.CLEAR, Ax.CLEAR, 10, 0, 10, 0))
	b.add_theme_stylebox_override("hover", Ax.sb(Color(1, 1, 1, 0.04), Ax.CLEAR, 10, 0, 10, 0))
	var on := Ax.sb(Ax.GOLD_BG, Ax.GOLD, 10, 1, 10, 0)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", Ax.sb(Ax.CLEAR, Ax.CLEAR, 10, 0, 10, 0))
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): picked.emit(id))
	buttons[id] = b
	var n := Ax.lab("", 12, Ax.MUTED)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	n.grow_vertical = Control.GROW_DIRECTION_BOTH
	n.offset_right = -10
	b.add_child(n)
	_counts[id] = n
	return b

## Pied du menu : sections modifiées, bouton principal (tester / reprendre).
func _footer() -> Control:
	var wrap := Ax.vbox(10)
	wrap.add_child(Ax.line())
	var st := Ax.hbox(8)
	var dot := Ax.panel(Ax.GOLD, Ax.CLEAR, 4, 0, 0, 0)
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_child(Ax.margin(dot, 6, 0, 0, 0))
	dirty_label = Ax.lab("", 12, Ax.MUTED)
	dirty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dirty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(dirty_label)
	wrap.add_child(st)
	banner = Ax.vbox(8)
	wrap.add_child(banner)
	banner_text = Ax.para("", 12, Ax.MUTED)
	banner.add_child(banner_text)
	btn_play = Ax.btn("", Callable(), "primary", 44.0, 12, 13, "play")
	btn_resume = Ax.btn("", Callable(), "ghost", 44.0, 12, 13)
	banner.add_child(btn_play)
	banner.add_child(btn_resume)
	return wrap

## Nombre de sections modifiées depuis l'ouverture de l'atelier.
func set_dirty(n: int) -> void:
	if dirty_label != null:
		dirty_label.text = L.fa(L.t("ui.atelier.dirty_n"), n) if n > 0 else L.t("ui.atelier.dirty_none")

## Coche la section courante (sans déclencher le signal).
func select(id: String) -> void:
	for k in buttons:
		(buttons[k] as Button).set_pressed_no_signal(k == id)

## Nombre à droite d'une entrée (ex. nombre de niveaux).
func set_count(id: String, text: String) -> void:
	if _counts.has(id):
		(_counts[id] as Label).text = text
