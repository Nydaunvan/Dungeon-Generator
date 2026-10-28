class_name AtelierHome
extends RefCounted
## Accueil de l'atelier : « Que veux-tu créer ? », reprise là où l'on s'est arrêté, trois portes (Créer / Régler / Partager),
## modifications récentes et contrôles du donjon.

const CREAM := Color("f4e6c6")
const MUTED := Color("a8977a")
const GOLD := Color("e8b45c")

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var narrow: bool = admin.size.x < 1000.0
	# ---- titre + reprise
	var head := BoxContainer.new()
	head.vertical = narrow
	head.add_theme_constant_override("separation", 14)
	host.add_child(head)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", 4)
	head.add_child(tcol)
	var k := Label.new()
	k.text = str(cfg.get("title", "")).to_upper()
	k.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE, 2))
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color("9a8863"))
	tcol.add_child(k)
	var h := Label.new()
	h.text = L.t("ui.atelier.home_h")
	h.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	h.add_theme_font_size_override("font_size", 32 if not narrow else 26)
	h.add_theme_color_override("font_color", CREAM)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(h)
	var last := Atelier.last_section()
	if last != "":
		head.add_child(_resume(admin, last))
	# ---- trois portes
	var doors := GridContainer.new()
	doors.columns = 1 if narrow else 3
	doors.add_theme_constant_override("h_separation", 20)
	doors.add_theme_constant_override("v_separation", 14)
	host.add_child(doors)
	var n_levels := (cfg.get("levels", []) as Array).size()
	doors.add_child(_door(admin, "levels", "map", L.t("ui.atelier.door_create"), L.t("ui.atelier.door_create_d"), [
		L.fa(L.t("ui.atelier.chip_levels"), n_levels),
		L.fa(L.t("ui.atelier.chip_heroes"), (cfg.get("party", []) as Array).size()),
		L.fa(L.t("ui.atelier.chip_classes"), (cfg.get("classes", []) as Array).size()),
		L.fa(L.t("ui.atelier.chip_spells"), (cfg.get("spells", []) as Array).size()),
		L.fa(L.t("ui.atelier.chip_items"), (cfg.get("itemLibrary", []) as Array).size())]))
	doors.add_child(_door(admin, "combat", "sliders", L.t("ui.atelier.door_rules"), L.t("ui.atelier.door_rules_d"), [
		L.t("ui.atelier.nav_combat"), L.t("ui.atelier.nav_progress"), L.t("ui.atelier.nav_explore"), L.t("ui.atelier.nav_traps")]))
	doors.add_child(_door(admin, "share", "link", L.t("ui.atelier.door_share"), L.t("ui.atelier.door_share_d"), [
		L.t("ui.atelier.chip_code"), L.t("ui.atelier.chip_json")]))
	# ---- récents + contrôles
	var low := GridContainer.new()
	low.columns = 1 if narrow else 2
	low.add_theme_constant_override("h_separation", 20)
	low.add_theme_constant_override("v_separation", 14)
	host.add_child(low)
	low.add_child(_recent_card(admin))
	low.add_child(_checks_card())

static func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	return l

static func _title(text: String) -> Label:
	var l := _label(text, 14, GOLD, true)
	l.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 2))
	return l

## Rend un conteneur cliquable (clic gauche) avec le curseur en main.
static func _clickable(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			cb.call())

static func _ignore_mouse(n: Node) -> void:
	for ch in n.get_children():
		if ch is Control:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(ch)

static func _resume(admin: Node, id: String) -> Control:
	var p := GameScreen.glass(12, 14)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(7)
	badge.add_theme_stylebox_override("panel", sb)
	badge.add_child(GameIcons.rect(_icon_of(id), 22, Color("2a1a06"), 2.0))
	h.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.add_child(_label(L.t("ui.atelier.resume"), 12, MUTED))
	col.add_child(_label(Atelier.title_of(id), 15, CREAM))
	h.add_child(col)
	h.add_child(GameIcons.rect("chevron", 18, GOLD, 2.0))
	_ignore_mouse(p)
	_clickable(p, func(): admin.go(id))
	return p

static func _icon_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return str(it[2])
	return "atelier"

static func _door(admin: Node, target: String, icon: String, title: String, text: String, chips: Array) -> Control:
	var p := GameScreen.glass(22, 18)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.71, 0.36, 0.14)
	sb.border_color = Color(0.91, 0.71, 0.36, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(11)
	badge.add_theme_stylebox_override("panel", sb)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_child(GameIcons.rect(icon, 26, GOLD, 1.7))
	col.add_child(badge)
	col.add_child(_label(title, 20, CREAM, true))
	var d := _label(text, 13, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(160, 0)
	col.add_child(d)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)
	for c in chips:
		flow.add_child(_chip(str(c)))
	_ignore_mouse(p)
	_clickable(p, func(): admin.go(target))
	return p

static func _chip(text: String) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("241a0e")
	sb.border_color = Color("3a2c18")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(_label(text, 12, Color("e2d2b0")))
	return pc

static func _recent_card(admin: Node) -> Control:
	var p := GameScreen.glass(20, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	p.add_child(col)
	col.add_child(_title(L.t("ui.atelier.recent")))
	var list: Array = Atelier.recent()
	if list.is_empty():
		var e := _label(L.t("ui.atelier.recent_empty"), 13, MUTED)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(e)
	for r in list:
		var id := str(r.get("section", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size = Vector2(0, 40)
		var ic := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("241a0e")
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		ic.add_theme_stylebox_override("panel", sb)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.add_child(GameIcons.rect(_icon_of(id), 18, GOLD, 1.7))
		row.add_child(ic)
		var t := _label(Atelier.title_of(id), 14, CREAM)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		var w := _label(Atelier.ago(float(r.get("ts", 0))), 12, Color("9a8863"))
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(w)
		_ignore_mouse(row)
		_clickable(row, func(): admin.go(id))
		col.add_child(row)
	return p

static func _checks_card() -> Control:
	var p := GameScreen.glass(20, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	p.add_child(col)
	col.add_child(_title(L.t("ui.atelier.checks")))
	var colors := {"ok": Color("6fcf7f"), "warn": Color("e8b45c"), "bad": Color("e0584a")}
	for c in Atelier.checks():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var dot := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[str(c.state)]
		sb.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 6)
		m.add_child(dot)
		row.add_child(m)
		var tc := VBoxContainer.new()
		tc.add_theme_constant_override("separation", 1)
		tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tc.add_child(_label(str(c.title), 14, CREAM))
		var d := _label(str(c.text), 12, MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tc.add_child(d)
		row.add_child(tc)
		col.add_child(row)
	return p
