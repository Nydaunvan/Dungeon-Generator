class_name PartyTip
extends PanelContainer
## Fiche de survol d'un personnage, aux couleurs du jeu : portrait, nom, classe et niveau ; jauges PV / endurance / XP ;
## attaque et vitesse ; caractéristiques ; statuts (pastilles colorées) ; équipement (icône + emplacement + objet).

static var _inst: PartyTip
static var _layer: CanvasLayer
static var _for_id: String = ""

const GOLD := Color("e8b45c")
const DIM := Color("b9a880")
const PARCH := Color("f5ecd8")
const STAT_COLORS := {"force": Color("e0785a"), "dex": Color("8fcf6a"), "con": Color("e8b45c"), "int": Color("6fb7e8")}

var _box: VBoxContainer

static func _inst_for(host: Control) -> PartyTip:
	if _inst == null or not is_instance_valid(_inst):
		_inst = PartyTip.new()
		_inst.name = "PartyTip"
		_inst.visible = false
		_inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst.add_theme_stylebox_override("panel", FloatingTip.TipBox.new())
		_inst._box = VBoxContainer.new()
		_inst._box.add_theme_constant_override("separation", 6)
		_inst._box.custom_minimum_size = Vector2(270, 0)
		_inst.add_child(_inst._box)
		_layer = CanvasLayer.new()
		_layer.name = "PartyTipLayer"
		_layer.layer = 210
		_layer.add_child(_inst)
		host.get_tree().root.add_child(_layer)
	return _inst

static func _lbl(text: String, size: int, col: Color, font: String = UiTheme.F_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", UiTheme.font(font))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color("5a4630")
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func _gauge(label: String, fill: Color, v: float, mx: float, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(label, 12, DIM, UiTheme.F_BODY_BOLD)
	l.custom_minimum_size = Vector2(34, 0)
	h.add_child(l)
	var b := TextBar.new(fill, 15, 11)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 15)
	b.max_value = maxf(1.0, mx)
	b.value = v
	b._label.text = text
	h.add_child(b)
	return h

static func _chip(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.9), col, 1, 9)
	sb.shadow_size = 0
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_lbl(text, 12, col.lightened(0.35), UiTheme.F_BODY_BOLD))
	return p

## Construit la fiche pour le personnage `c` et l'affiche au-dessus de `card`.
static func show_for(card: Control, gs: GameState, c: Dictionary) -> void:
	var t := _inst_for(card)
	_for_id = str(c.id)
	var b := t._box
	for ch in b.get_children():
		b.remove_child(ch)
		ch.queue_free()
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	# --- en-tête : portrait, nom, classe · niveau
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pp := IconResolver.portrait_path(c, gs.cfg)
	var img: Texture2D = load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", "")))
	head.add_child(UiTheme.portrait(img, GOLD, 52.0))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_lbl(str(c.name), 20, GOLD, UiTheme.F_TITLE_BOLD))
	tv.add_child(_lbl("%s  ·  %s" % [L.c(str(cls.get("name", ""))), L.fa(L.t("ui.party_hud.nv"), int(c.level))], 13, DIM, UiTheme.F_BODY_ITALIC))
	head.add_child(tv)
	b.add_child(head)
	b.add_child(_rule())
	# --- jauges
	b.add_child(_gauge(L.t("common.pv"), UiTheme.HP_GREEN, float(c.hp), float(c.maxHp), "%d / %d" % [int(c.hp), int(c.maxHp)]))
	b.add_child(_gauge(L.t("ui.party_tip.end"), UiTheme.STA_CYAN, float(c.stamina), float(c.maxStamina), "%d / %d" % [int(c.stamina), int(c.maxStamina)]))
	b.add_child(_gauge("XP", Color("4a90c2"), float(c.get("xp", 0)), float(c.get("xpToNext", 1)), "%d / %d" % [int(c.get("xp", 0)), int(c.get("xpToNext", 1))]))
	b.add_child(_rule())
	# --- combat : attaque, vitesse
	var fight := HBoxContainer.new()
	fight.add_theme_constant_override("separation", 6)
	fight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var al := _lbl(L.t("ui.party_tip.attaque"), 13, DIM)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight.add_child(al)
	fight.add_child(_lbl("%d – %d" % [int(c.get("atkMin", 0)), int(c.get("atkMax", 0))], 14, PARCH, UiTheme.F_BODY_BOLD))
	var vl := _lbl(L.t("common.vitesse"), 13, DIM)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fight.add_child(vl)
	fight.add_child(_lbl(str(int(c.get("effSpeed", 0))), 14, PARCH, UiTheme.F_BODY_BOLD))
	b.add_child(fight)
	# --- caractéristiques
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in [["force", L.t("common.for"), "effForce"], ["dex", "Dex", "effDex"], ["con", "Con", "effCon"], ["int", "Int", "effInt"]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", -2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := _lbl(str(int(c.get(s[2], 0))), 18, STAT_COLORS[s[0]], UiTheme.F_TITLE_BOLD)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var k := _lbl(str(s[1]), 11, DIM)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(v)
		cell.add_child(k)
		stats.add_child(cell)
	b.add_child(stats)
	# --- statuts
	var effs: Array = Statuses.active(c) if int(c.hp) > 0 else []
	if not effs.is_empty():
		b.add_child(_rule())
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 4)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for e in effs:
			var col := Color(str(PartyHud.STATUS_COLORS.get(str(e.type), "ffd88a")))
			fl.add_child(_chip("%s %s · %s" % [Statuses.def(str(e.type)).get("icon", ""), L.c(str(Statuses.def(str(e.type)).get("label", e.type))), L.fa(L.t("ui.party_tip.tours"), int(e.remaining))], col))
		b.add_child(fl)
	# --- équipement
	var eq_rows: Array = []
	for slot in Characters.SLOTS:
		var it = c.get("equipment", {}).get(slot)
		if it is Dictionary:
			eq_rows.append([slot, it])
	b.add_child(_rule())
	if eq_rows.is_empty():
		b.add_child(_lbl(L.t("ui.party_tip.aucun_equipement"), 12, DIM, UiTheme.F_BODY_ITALIC))
	for r in eq_rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(IconPicker.icon_control(str(r[1].get("icon", "")), 24.0))
		var sl := _lbl(L.c(str(Inventory.SLOT_LABELS.get(r[0], r[0]))), 12, DIM)
		sl.custom_minimum_size = Vector2(52, 0)
		row.add_child(sl)
		var nl := _lbl(L.c(str(r[1].get("name", "?"))), 13, GOLD if bool(r[1].get("legendary", false)) else PARCH)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		row.add_child(nl)
		b.add_child(row)
	t.size = Vector2.ZERO
	t.visible = true
	await card.get_tree().process_frame
	if not is_instance_valid(t) or not is_instance_valid(card) or not t.visible:
		return
	var rc := card.get_global_rect()
	var vs := card.get_viewport().get_visible_rect().size
	var x := clampf(rc.position.x + rc.size.x * 0.5 - t.size.x * 0.5, 6.0, maxf(6.0, vs.x - t.size.x - 6.0))
	var y := rc.position.y - t.size.y - 12.0
	if y < 6.0:
		y = rc.end.y + 12.0
	t.position = Vector2(x, y)

static func current_id() -> String:
	return _for_id if _inst != null and is_instance_valid(_inst) and _inst.visible else ""

static func hide_tip() -> void:
	_for_id = ""
	if _inst != null and is_instance_valid(_inst):
		_inst.visible = false
