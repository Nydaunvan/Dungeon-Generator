class_name ShopModal
extends RefCounted
## Boutique (marchand ambulant du donjon ou marchand du village) : un étal en vitrine à gauche, la fiche de l'objet choisi à droite
## (bonus, comparaison avec l'équipement du personnage, quantité, achat / vente). La besace est toujours visible en mode « Vendre ».

const CATS := [["items", "common.equipement"], ["potions", "Potions"], ["keys", "ui.shop_modal.cles_et_parchemins"]]
const STAT_FIELDS := [["bonusHp", "common.pv"], ["bonusSpellDmg", "common.degats_de_sort"], ["bonusForce", "common.force"], ["bonusDex", "common.dexterite"],
		["bonusCon", "common.constitution"], ["bonusInt", "common.intelligence"], ["bonusSpeed", "common.vitesse"]]
const RED := Color("e06a5a")
const CARD_W := 104.0
const CARD_H := 118.0

## `offers` est modifié en place (les objets achetés disparaissent). `on_change` est appelé après chaque transaction.
static func open(host: Node, gs: GameState, offers: Array, village: bool, on_change: Callable = Callable()) -> Modal:
	var vp := host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	var m := Modal.open(host, L.t("ui.shop_modal.le_marchand") if village else L.t("ui.shop_modal.le_marchand_itinerant"), 960.0)
	var body_h := clampf(vp.y * 0.66 - 150.0, 250.0, 420.0)
	var greet := "ui.shop_modal.salut_village" if village else "ui.shop_modal.salut_%d" % (1 + randi() % 3)
	var st := {"tab": "buy", "cat": "items", "who": str(gs.active_char_id), "sel": "", "qty": {}, "msg": "", "ok": false, "greet": greet}
	var merchant_icon := "@icon:merchant" if village else "@icon:merchant_dungeon"

	# ---- en-tête : le marchand, sa phrase, l'or et la place restante dans la besace
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	m.content.add_child(head)
	head.add_child(_portrait(merchant_icon, village))
	var head_txt := VBoxContainer.new()
	head_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_txt.alignment = BoxContainer.ALIGNMENT_CENTER
	head_txt.add_theme_constant_override("separation", 4)
	head.add_child(head_txt)
	var speech := AdminUtil.label("", 15, UiTheme.DIM)
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	head_txt.add_child(speech)
	var gold := AdminUtil.label("", 20, UiTheme.GOLD)
	head_txt.add_child(gold)
	var bag_info := AdminUtil.label("", 13, UiTheme.DIM)
	head_txt.add_child(bag_info)

	# ---- rangée de commandes : Acheter / Vendre et catégories
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	m.content.add_child(bar)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 6)
	bar.add_child(tab_bar)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(18, 0)
	bar.add_child(sp)
	var cat_bar := HBoxContainer.new()
	cat_bar.add_theme_constant_override("separation", 6)
	bar.add_child(cat_bar)

	# ---- corps : étal (grille défilante) + fiche de l'objet
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	m.content.add_child(main)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, body_h)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shelf := PanelContainer.new()
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_theme_stylebox_override("panel", _shelf_box())
	shelf.add_child(scroll)
	main.add_child(shelf)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(grid)
	scroll.add_child(pad)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(330, body_h)
	detail_panel.add_theme_stylebox_override("panel", _shelf_box())
	main.add_child(detail_panel)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	var dpad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		dpad.add_theme_constant_override("margin_" + side, 10)
	dpad.add_child(detail)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dpad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(dpad)
	detail_panel.add_child(dscroll)

	var ctl := {"fn": Callable()}
	var refresh := func(): ctl.fn.call()   # (une lambda copie les variables locales : on passe par ctl pour le rappel récursif)
	var done := func(err: String, ok_text: String):
		st.msg = err if err != "" else ok_text
		st.ok = err == ""
		if err == "" and on_change.is_valid():
			on_change.call()
		refresh.call()

	ctl.fn = func():
		var buy: bool = st.tab == "buy"
		gold.text = L.fa(L.t("ui.shop_modal.pieces_or"), gs.gold)
		speech.text = L.t(str(st.greet)) if buy else L.t("ui.shop_modal.salut_vente")
		bag_info.text = _bag_text(gs)
		for box in [tab_bar, cat_bar, grid, detail]:
			for ch in box.get_children():
				box.remove_child(ch)
				ch.queue_free()
		# Acheter / Vendre
		var tg := ButtonGroup.new()
		for t in [["buy", L.t("ui.shop_modal.acheter")], ["sell", L.t("ui.shop_modal.vendre")]]:
			var b := Button.new()
			b.text = t[1]
			b.toggle_mode = true
			b.button_group = tg
			b.button_pressed = st.tab == t[0]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(104, 34)
			var tid: String = t[0]
			b.pressed.connect(func():
				st.tab = tid
				st.sel = ""
				st.msg = ""
				refresh.call())
			tab_bar.add_child(b)
		# catégories avec leur effectif
		var src: Array = offers if buy else gs.inventory
		var cg := ButtonGroup.new()
		for c in CATS:
			var b := Button.new()
			var n := _groups(src, str(c[0])).size()
			var nm: String = L.t("common.parchemins") if (village and c[0] == "keys") else L.t(str(c[1]))
			b.text = "%s (%d)" % [nm, n]
			b.toggle_mode = true
			b.button_group = cg
			b.button_pressed = st.cat == c[0]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 34)
			var cat_id: String = c[0]
			b.pressed.connect(func():
				st.cat = cat_id
				st.sel = ""
				st.msg = ""
				refresh.call())
			cat_bar.add_child(b)
		# étal
		var groups := _groups(src, str(st.cat))
		var cur: Dictionary = {}
		for g in groups:
			if _gkey(g, buy) == str(st.sel):
				cur = g
		if cur.is_empty() and not groups.is_empty():
			cur = groups[0]
			st.sel = _gkey(cur, buy)
		grid.columns = clampi(int((shelf.size.x if shelf.size.x > 200 else 560.0) / (CARD_W + 8.0)), 3, 6)
		if groups.is_empty():
			var e := AdminUtil.label(L.t("ui.shop_modal.le_marchand_n_a_plus") if buy else L.t("ui.shop_modal.votre_besace_est_vide"), 14, UiTheme.DIM)
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			e.custom_minimum_size = Vector2(220, 0)
			grid.add_child(e)
		for g in groups:
			grid.add_child(_card(g, buy, str(st.sel) == _gkey(g, buy), func():
				st.sel = _gkey(g, buy)
				st.msg = ""
				refresh.call()))
		_fill_detail(detail, gs, offers, st, cur, buy, village, done, refresh)
		m.call_deferred("_fit")
	refresh.call()
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): Flows.input("shop", ["close"])}])
	Flows.open("shop", m, func(a: Variant):
		var arr: Array = a
		if str(arr[0]) == "close":
			Flows.close("shop")
			if is_instance_valid(m) and not m.is_queued_for_deletion():
				m.close()
			return
		var buy_b := str(arr[0]) == "buy"
		var res := transact(gs, offers, buy_b, arr[1])
		if st.has("gk"):
			st.qty.erase(st.gk)
			st.erase("gk")
		st.sel = ""
		var ok_text := ""
		if int(res.bought) > 0:
			ok_text = L.fa(L.t("ui.shop_modal.achat_ok") if buy_b else L.t("ui.shop_modal.vente_ok"), [int(res.bought), L.c(str(res.name))])
		done.call(str(res.err) if int(res.bought) == 0 else "", ok_text),
		["close"],
		func(a: Variant):
			if not (a is Array) or (a as Array).is_empty():
				return false
			match str((a as Array)[0]):
				"close": return true
				"buy": return (a as Array).size() > 1 and valid_take(gs, offers, true, (a as Array)[1])
				"sell": return (a as Array).size() > 1 and valid_take(gs, offers, false, (a as Array)[1])
			return false)
	# la largeur de la grille n'est connue qu'après la mise en page : on la recalcule une fois
	m.call_deferred("_fit")
	host.get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			refresh.call())
	return m

# ------------------------------------------------------------------ éléments visuels

static func _shelf_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("120d09")
	s.border_color = Color("3a2c1c")
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s

static func _card_box(selected: bool, hover: bool, legendary: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("2a2016") if selected else (Color("221a12") if hover else Color("1c1610"))
	s.border_color = UiTheme.GOLD if selected else (UiTheme.BRONZE_LIGHT if hover else (Color("c9962f") if legendary else Color("5a4526")))
	s.set_border_width_all(2 if (selected or legendary) else 1)
	s.set_corner_radius_all(6)
	if selected:
		s.shadow_color = Color(0.91, 0.71, 0.36, 0.45)
		s.shadow_size = 5
	return s

## Portrait du marchand : le haut de son sprite, dans un cadre.
static func _portrait(icon: String, village: bool) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(104, 112)
	var sb := _shelf_box()
	sb.border_color = UiTheme.BRONZE
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.clip_contents = true
	var tex: Texture2D = IconResolver.texture("@icon:merchant_portrait" if not village else icon)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(t)
	return frame

static func _gkey(g: Dictionary, buy: bool) -> String:
	var rep: Dictionary = g.rep
	return ("buy:" if buy else "sell:") + str(g.key if g.key != "" else rep.get("id", rep.get("uid", g.idxs[0])))

## Vignette d'un objet sur l'étal : icône, nom, prix, pile.
static func _card(g: Dictionary, buy: bool, selected: bool, on_pick: Callable) -> Button:
	var rep: Dictionary = g.rep
	var count: int = g.idxs.size()
	var leg: bool = bool(rep.get("legendary", false))
	var b := Button.new()
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.add_theme_stylebox_override("normal", _card_box(selected, false, leg))
	b.add_theme_stylebox_override("hover", _card_box(selected, true, leg))
	b.add_theme_stylebox_override("pressed", _card_box(true, true, leg))
	b.add_theme_stylebox_override("focus", _card_box(selected, false, leg))
	b.pressed.connect(on_pick)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := IconPicker.icon_control(str(rep.get("icon", "")), 52.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm := AdminUtil.label(L.c(str(rep.get("name", "?"))), 12, UiTheme.GOLD if leg else UiTheme.PARCH)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var unit := int(rep.get("price", 0)) if buy else Shop.sell_price(rep)
	var pr := AdminUtil.label("%d or" % unit if str(rep.get("type", "")) != "key" or buy else "—", 13, UiTheme.GOLD)
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pr)
	if count > 1:
		var badge := AdminUtil.label("×%d" % count, 12, UiTheme.PARCH)
		badge.add_theme_stylebox_override("normal", UiTheme.box(Color("120d09"), UiTheme.BRONZE, 1, 8))
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	return b

static func _bag_text(gs: GameState) -> String:
	var parts: Array = []
	for c in CATS:
		var nm := L.t("common.parchemins") if c[0] == "keys" else L.t(str(c[1]))
		parts.append("%s %d/%d" % [nm, Inventory.tab_count(gs, str(c[0])), Inventory.MAX_PER_TAB])
	return L.t("ui.shop_modal.besace_label") + "  ·  ".join(parts)

# ------------------------------------------------------------------ fiche de l'objet

static func _type_line(it: Dictionary) -> String:
	match str(it.get("type", "")):
		"weapon":
			var wt := str(it.get("weaponType", ""))
			return L.t("common.arme") + (" · " + L.c(AdminUtil.weapon_label(wt)) if wt != "" else "")
		"armor":
			return L.c(str(Inventory.SLOT_LABELS.get(str(it.get("slot", "body")), "Torse")))
		"jewelry":
			return L.t("common.bijou")
		"potion":
			return "Potions"
		"scroll":
			return L.t("ui.shop_modal.parchemin")
		"key":
			return L.t("ui.shop_modal.cle")
	return ""

static func _stat_rows(it: Dictionary) -> Dictionary:
	var d := {}
	var a0 := int(it.get("bonusAtkMin", 0))
	var a1 := int(it.get("bonusAtkMax", 0))
	if a0 != 0 or a1 != 0:
		d["atk"] = [a0, a1]
	for f in STAT_FIELDS:
		if int(it.get(f[0], 0)) != 0:
			d[f[0]] = int(it[f[0]])
	return d

static func _num(v: float) -> String:
	var r := snappedf(v, 0.1)
	return str(int(r)) if is_equal_approx(r, floorf(r)) else "%.1f" % r

static func _row(parent: Control, label: String, value: String, delta: float, show_delta: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := AdminUtil.label(label, 14, UiTheme.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(AdminUtil.label(value, 14, UiTheme.PARCH))
	if show_delta:
		var txt := "  ="
		var col := UiTheme.DIM
		if delta > 0.001:
			txt = "▲ +" + _num(delta)
			col = UiTheme.HP_GREEN
		elif delta < -0.001:
			txt = "▼ −" + _num(-delta)
			col = RED
		var dl := AdminUtil.label(txt, 13, col)
		dl.custom_minimum_size = Vector2(58, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(dl)
	parent.add_child(h)

static func _fill_detail(box: VBoxContainer, gs: GameState, offers: Array, st: Dictionary, g: Dictionary, buy: bool, village: bool, done: Callable, refresh: Callable) -> void:
	if g.is_empty():
		var l := AdminUtil.label(L.t("ui.shop_modal.choisir_objet"), 14, UiTheme.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
		if str(st.msg) != "":
			_msg(box, st)
		return
	var rep: Dictionary = g.rep
	var idxs: Array = g.idxs
	var count := idxs.size()
	var leg: bool = bool(rep.get("legendary", false))
	var gk := _gkey(g, buy)
	var qty := clampi(int(st.qty.get(gk, 1)), 1, count)
	st.qty[gk] = qty
	var unit := int(rep.get("price", 0)) if buy else Shop.sell_price(rep)
	var is_key: bool = (not buy) and str(rep.get("type", "")) == "key"

	# titre
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(IconPicker.icon_control(str(rep.get("icon", "")), 60.0))
	var tt := VBoxContainer.new()
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := AdminUtil.label(("✨ " if leg else "") + L.c(str(rep.get("name", "?"))), 17, UiTheme.GOLD if leg else UiTheme.PARCH)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	tt.add_child(nm)
	tt.add_child(AdminUtil.label(_type_line(rep), 13, UiTheme.DIM))
	top.add_child(tt)
	box.add_child(top)
	box.add_child(HSeparator.new())

	# compare-t-on avec un équipement ?
	var slot := Inventory.slot_of(rep)
	var who := gs.char_by_id(str(st.who))
	var eq: Dictionary = {}
	if slot != "" and not who.is_empty():
		var ev = who.get("equipment", {}).get(slot)
		eq = ev if ev is Dictionary else {}
	var compare := slot != ""
	if compare:
		var wb := AdminUtil.flow(box)
		wb.add_theme_constant_override("h_separation", 5)
		wb.add_child(AdminUtil.label(L.t("ui.shop_modal.comparer_avec"), 12, UiTheme.DIM))
		var wg := ButtonGroup.new()
		for c in gs.party:
			var b := Button.new()
			b.text = str(c.name)
			b.toggle_mode = true
			b.button_group = wg
			b.button_pressed = str(c.id) == str(st.who)
			b.focus_mode = Control.FOCUS_NONE
			var cid: String = str(c.id)
			b.pressed.connect(func():
				st.who = cid
				refresh.call())
			wb.add_child(b)

	# bonus
	var mine := _stat_rows(rep)
	var theirs := _stat_rows(eq)
	var shown := 0
	if mine.has("atk") or theirs.has("atk"):
		var m_a: Array = mine.get("atk", [0, 0])
		var e_a: Array = theirs.get("atk", [0, 0])
		_row(box, L.t("ui.shop_modal.attaque"), "+%d / +%d" % [m_a[0], m_a[1]] if mine.has("atk") else "—",
				(m_a[0] + m_a[1]) * 0.5 - (e_a[0] + e_a[1]) * 0.5, compare)
		shown += 1
	for f in STAT_FIELDS:
		if mine.has(f[0]) or theirs.has(f[0]):
			var mv := int(mine.get(f[0], 0))
			var ev2 := int(theirs.get(f[0], 0))
			_row(box, L.t(str(f[1])), "%+d" % mv if mine.has(f[0]) else "—", float(mv - ev2), compare)
			shown += 1
	if int(rep.get("heal", 0)) > 0:
		_row(box, L.t("ui.shop_modal.soin"), L.fa(L.t("ui.shop_modal.pv_rendus"), int(rep.heal)), 0.0, false)
		shown += 1
	if int(rep.get("staminaRestore", 0)) > 0:
		_row(box, L.t("ui.shop_modal.endurance"), "+%d" % int(rep.staminaRestore), 0.0, false)
		shown += 1
	if str(rep.get("type", "")) == "scroll":
		for sp in gs.cfg.get("spells", []):
			if sp.get("id") == rep.get("spellId"):
				var sl := AdminUtil.label(L.fa(L.t("rules.inventory.lance_usage_unique_sans_cout"), sp.name), 14, UiTheme.PARCH)
				sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(sl)
				shown += 1
	if str(rep.get("type", "")) == "key":
		var kl := AdminUtil.label(L.t("rules.inventory.ouvre_une_porte_verrouillee"), 14, UiTheme.PARCH)
		kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(kl)
		shown += 1
	if shown == 0:
		box.add_child(AdminUtil.label(L.t("rules.shop.aucun_bonus"), 14, UiTheme.DIM))
	if compare:
		var el := AdminUtil.label(L.fa(L.t("ui.shop_modal.n_a_rien_equipe_a"), who.name) if eq.is_empty() else L.fa(L.t("ui.shop_modal.equipe_sur"), [who.name, L.c(str(eq.get("name", "?")))]), 12, UiTheme.DIM)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(el)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(fill)
	box.add_child(HSeparator.new())

	# quantité
	if count > 1 and not is_key:
		var qh := HBoxContainer.new()
		qh.add_theme_constant_override("separation", 8)
		var ql := AdminUtil.label(L.t("ui.shop_modal.quantite"), 14, UiTheme.DIM)
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qh.add_child(ql)
		for d in [-1, 1]:
			if d == 1:
				var q := AdminUtil.label("%d / %d" % [qty, count], 15)
				q.custom_minimum_size = Vector2(54, 0)
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				qh.add_child(q)
			var sb := Button.new()
			sb.text = "−" if d < 0 else "+"
			sb.focus_mode = Control.FOCUS_NONE
			sb.custom_minimum_size = Vector2(34, 30)
			var dd: int = d
			sb.pressed.connect(func():
				st.qty[gk] = clampi(qty + dd, 1, count)
				refresh.call())
			qh.add_child(sb)
		var mx := Button.new()
		mx.text = "Max"
		mx.focus_mode = Control.FOCUS_NONE
		mx.custom_minimum_size = Vector2(44, 30)
		mx.pressed.connect(func():
			var cap := count
			if buy and unit > 0:
				cap = clampi(gs.gold / unit, 1, count)
			st.qty[gk] = cap
			refresh.call())
		qh.add_child(mx)
		box.add_child(qh)

	if is_key:
		var kk := AdminUtil.label(L.t("ui.shop_modal.ne_peut_pas_etre_vendue"), 14, UiTheme.DIM)
		kk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(kk)
		if str(st.msg) != "":
			_msg(box, st)
		return

	var total := unit * qty
	var ph := HBoxContainer.new()
	var pl := AdminUtil.label(L.t("ui.shop_modal.prix") if buy else L.t("ui.shop_modal.revente"), 14, UiTheme.DIM)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	ph.add_child(AdminUtil.label("%d or" % total, 18, UiTheme.GOLD))
	box.add_child(ph)

	# raison d'un achat impossible
	var reason := ""
	if buy:
		if gs.gold < total:
			reason = L.fa(L.t("ui.shop_modal.manque_or"), total - gs.gold)
		elif not Inventory.has_space(gs, rep):
			reason = L.fa(L.t("ui.shop_modal.besace_pleine"), L.t(str(Inventory.TAB_LABELS.get(Inventory.tab_of(rep), ""))))
	var act := Button.new()
	act.text = L.t("ui.shop_modal.acheter") if buy else L.t("ui.shop_modal.vendre")
	act.focus_mode = Control.FOCUS_NONE
	act.custom_minimum_size = Vector2(0, 40)
	act.disabled = reason != ""
	var take: Array = idxs.slice(0, qty)
	act.pressed.connect(func():
		st["gk"] = gk         # (présentation : quantité à remettre à zéro après la transaction)
		if not Flows.input("shop", ["buy" if buy else "sell", take.duplicate()]):
			st.erase("gk"))
	box.add_child(act)
	if reason != "":
		var rl := AdminUtil.label(reason, 13, RED)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(rl)
	elif not buy:
		var il := AdminUtil.label(L.t("ui.shop_modal.revente_info"), 12, UiTheme.DIM)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(il)
	if str(st.msg) != "":
		_msg(box, st)

## Transaction de la boutique (achat ou vente d'un lot d'objets) : toute la logique est ici, l'interface ne fait que l'afficher.
## Renvoie {err, bought, paid, name}.
static func transact(gs: GameState, offers: Array, buy: bool, take_in: Array) -> Dictionary:
	var take: Array = take_in.duplicate()
	take.sort()
	take.reverse()   # indices décroissants : les retraits ne décalent pas les suivants
	var err := ""
	var bought := 0
	var paid := 0
	var rep_name := str(offers[int(take[0])].get("name", "")) if buy else str(gs.inventory[int(take[0])].get("name", ""))
	for ix in take:
		var unit_p := int(offers[int(ix)].get("price", 0)) if buy else Shop.sell_price(gs.inventory[int(ix)])
		err = Shop.buy(gs, offers, int(ix), true) if buy else Shop.sell(gs, int(ix), true)
		if err != "":
			if buy and err.contains("plein"):
				gs.add_log(err.trim_suffix(".") + L.t("ui.shop_modal.impossible_acheter_davantage"))
			break
		bought += 1
		paid += unit_p
	if bought > 0:
		gs.add_log(L.fa(L.t("ui.shop_modal.pour_pieces_or"), [L.t("ui.shop_modal.le_groupe_achete") if buy else L.t("ui.shop_modal.le_groupe_vend"), "%d× " % bought if bought > 1 else "", rep_name, paid]))
		Sound.coins()
	return {"err": err, "bought": bought, "paid": paid, "name": rep_name}

## Une transaction est-elle bien formée ? (indices entiers, distincts, existants ; jamais une clé à la vente)
static func valid_take(gs: GameState, offers: Array, buy: bool, take: Variant) -> bool:
	if not (take is Array) or (take as Array).is_empty():
		return false
	var seen := {}
	for ix in take:
		if typeof(ix) != TYPE_INT or seen.has(ix) or ix < 0:
			return false
		seen[ix] = true
		if buy and ix >= offers.size():
			return false
		if not buy and (ix >= gs.inventory.size() or str(gs.inventory[ix].get("type", "")) == "key"):
			return false
	return true

static func _msg(box: Control, st: Dictionary) -> void:
	var l := AdminUtil.label(str(st.msg), 13, UiTheme.HP_GREEN if st.ok else RED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)

## Regroupe les objets empilables (potions simples, parchemins identiques) ; renvoie [{rep, idxs, key}].
static func _groups(items: Array, cat: String) -> Array:
	var out: Array = []
	var by_key := {}
	for i in items.size():
		var it: Dictionary = items[i]
		if Inventory.tab_of(it) != cat:
			continue
		var k := Inventory.stack_key(it)
		if k == "":
			out.append({"rep": it, "idxs": [i], "key": ""})
		elif by_key.has(k):
			by_key[k].idxs.append(i)
		else:
			var g := {"rep": it, "idxs": [i], "key": k}
			by_key[k] = g
			out.append(g)
	return out
