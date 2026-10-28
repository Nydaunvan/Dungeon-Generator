class_name AtelierHome
extends RefCounted
## Accueil de l'atelier (maquette « Atelier ») : « Que veux-tu créer ? », reprise là où l'on s'est arrêté, trois portes
## (Créer / Régler / Partager), modifications récentes et contrôles du donjon.

static func build(host: Control, admin: Node) -> void:
	var page := Ax.scroll_page(host, admin, 44, 36, 28)
	var cfg: Dictionary = Data.admin_config()
	var narrow: bool = admin.size.x < 1000.0
	# ---- titre + reprise
	var head := BoxContainer.new()
	head.vertical = narrow
	head.add_theme_constant_override("separation", 24)
	page.add_child(head)
	var tcol := Ax.vbox(6)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	tcol.add_child(Ax.kicker(str(cfg.get("title", "")), 12))
	var h := Ax.title(L.t("ui.atelier.home_h"), 34 if not narrow else 26)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(h)
	var last := Atelier.last_section()
	if last != "":
		var rs := _resume(admin, last)
		rs.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(rs)
	# ---- trois portes
	var doors := GridContainer.new()
	doors.columns = 1 if narrow else 3
	doors.add_theme_constant_override("h_separation", 20)
	doors.add_theme_constant_override("v_separation", 16)
	page.add_child(doors)
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
	low.add_theme_constant_override("v_separation", 16)
	page.add_child(low)
	var rc := _recent_card(admin)
	var ck := _checks_card()
	if not narrow:
		rc.size_flags_stretch_ratio = 1.4
		ck.size_flags_stretch_ratio = 1.0
	low.add_child(rc)
	low.add_child(ck)

static func _icon_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return str(it[2])
	return "atelier"

static func _resume(admin: Node, id: String) -> Control:
	var p := Ax.panel(Color(0.118, 0.086, 0.051, 0.85), Ax.LINE3, 14, 20, 0)
	p.custom_minimum_size.y = 56
	var h := Ax.hbox(14)
	p.add_child(h)
	var badge := Ax.panel(Ax.GOLD, Ax.CLEAR, 9, 7, 7, 0)
	badge.custom_minimum_size = Vector2(36, 36)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(Ax.ico(_icon_of(id), 22, Color("2a1a06"), 2.0))
	h.add_child(badge)
	var col := Ax.vbox(2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(Ax.lab(L.t("ui.atelier.resume"), 12, Ax.MUTED))
	col.add_child(Ax.lab(Atelier.title_of(id), 14, Ax.CREAM, 600))
	h.add_child(col)
	var chev := Ax.ico("chevron", 18, Ax.GOLD, 2.0)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chev)
	Ax.clickable(p, func(): admin.go(id))
	return p

static func _door(admin: Node, target: String, icon: String, title: String, text: String, chips: Array) -> Control:
	var p := Ax.panel(Color(0.137, 0.1, 0.059, 0.92), Ax.LINE3, 18, 22, 22)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Ax.vbox(14)
	p.add_child(col)
	var badge := Ax.panel(Ax.GOLD_BG, Color(0.91, 0.706, 0.361, 0.4), 12, 11, 11)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_child(Ax.ico(icon, 26, Ax.GOLD, 1.7))
	col.add_child(badge)
	col.add_child(Ax.title(title, 20))
	var d := Ax.para(text, 13, Ax.MUTED)
	d.add_theme_constant_override("line_spacing", 4)
	col.add_child(d)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)
	for c in chips:
		flow.add_child(Ax.chip(str(c), Ax.TEXT))
	Ax.clickable(p, func(): admin.go(target))
	return p

static func _section(title_text: String) -> VBoxContainer:
	var p := Ax.panel(Color(0.086, 0.063, 0.039, 0.8), Ax.LINE, 16, 20, 20)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_FILL
	var col := Ax.vbox(12)
	p.add_child(col)
	col.add_child(Ax.gold_cap(title_text))
	col.set_meta("panel", p)
	return col

static func _recent_card(admin: Node) -> Control:
	var col := _section(L.t("ui.atelier.recent"))
	var list: Array = Atelier.recent()
	if list.is_empty():
		col.add_child(Ax.para(L.t("ui.atelier.recent_empty"), 13, Ax.MUTED))
	for r in list:
		var id := str(r.get("section", ""))
		var row := Ax.panel(Ax.CLEAR, Ax.CLEAR, 0, 0, 0, 0)
		row.custom_minimum_size.y = 48
		var inner := Ax.vbox(0)
		row.add_child(inner)
		var h := Ax.hbox(14)
		h.custom_minimum_size.y = 47
		inner.add_child(h)
		var ic := Ax.panel(Color("241a0e"), Ax.CLEAR, 8, 7, 7, 0)
		ic.custom_minimum_size = Vector2(32, 32)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.add_child(Ax.ico(_icon_of(id), 18, Ax.GOLD, 1.7))
		h.add_child(ic)
		var what := str(r.get("what", ""))
		var t := Ax.lab(what if what != "" else Atelier.title_of(id), 14, Ax.CREAM, 500)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.clip_text = true
		h.add_child(t)
		var wh := Ax.lab(Atelier.title_of(id), 12, Ax.MUTED)
		wh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(wh)
		var w := Ax.lab(Atelier.ago(float(r.get("ts", 0))), 12, Ax.DIM)
		w.custom_minimum_size.x = 70
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(w)
		inner.add_child(Ax.line(Color("2a2014")))
		Ax.clickable(row, func(): admin.go(id))
		col.add_child(row)
	return col.get_meta("panel")

static func _checks_card() -> Control:
	var col := _section(L.t("ui.atelier.checks"))
	var colors := {"ok": Ax.GREEN, "warn": Ax.GOLD, "bad": Color("e0584a")}
	for c in Atelier.checks():
		var row := Ax.hbox(12)
		var dot := Ax.panel(colors[str(c.state)], Ax.CLEAR, 5, 5, 5, 0)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(Ax.margin(dot, 0, 5, 0, 0))
		var tc := Ax.vbox(2)
		tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tc.add_child(Ax.para(str(c.title), 14, Ax.CREAM, 500))
		tc.add_child(Ax.para(str(c.text), 12, Ax.MUTED))
		row.add_child(tc)
		col.add_child(row)
	return col.get_meta("panel")
