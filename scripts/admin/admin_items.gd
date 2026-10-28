class_name AdminItems
extends RefCounted
## Onglet « Objets de base » : tableau de la bibliothèque d'objets (potions, armes, armures, bijoux, clés, parchemins, pièges).
## Reproduit `renderLibItemTable` / `libItemDetailsHtml` / `statBoostFieldsHtml` / `legendaryFieldsHtml` / `clampItemStat` /
## `editLibItem` / `addLibItem` / `removeLibItem` de l'original.

const TYPES := [["potion", "common.potion"], ["weapon", "common.arme"], ["armor", "common.armure"], ["jewelry", "common.bijou"], ["key", "common.cle"], ["scroll", "common.parchemin"], ["trap", "common.piege"]]
const LEVEL_TYPES := [["potion", "common.potion"], ["weapon", "common.arme"], ["armor", "common.armure"], ["jewelry", "common.bijou"], ["key", "common.cle"], ["scroll", "common.parchemin"], ["trap", "common.piege"], ["switch", "Interrupteur"], ["fountain", "common.fontaine"]]
const PERKS := [["lifesteal", "admin.items.vol_de_vie"], ["crit", "admin.items.critique"], ["thorns", "admin.items.renvoi"]]
## `LEGENDARY_PERKS` de l'original (icône + libellé FR), dans l'ordre de l'original.
const LEGENDARY_PERKS := [["lifesteal", "common.vol_de_vie"], ["crit", "common.critique"], ["thorns", "common.renvoi"]]
const STAT_FIELDS := ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg", "heal", "trapDmgMin", "trapDmgMax", "bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"]
const BOOST_FIELDS := ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"]

## Objet affiché dans la fiche (identifiant), filtre de type ("all" ou un type) et texte recherché.
static var _isel := ""
static var _ifilter := "all"

static func build(host: Control, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var lib: Array = cfg.get("itemLibrary", [])
	var narrow: bool = admin.size.x < 1000.0
	var shown: Array = []
	for it in lib:
		if _ifilter == "all" or str(it.get("type", "")) == _ifilter:
			shown.append(it)
	var sel: Dictionary = {}
	for it in lib:
		if str(it.get("id", "")) == _isel:
			sel = it
	if sel.is_empty() or not shown.has(sel):
		sel = shown[0] if not shown.is_empty() else {}
		_isel = str(sel.get("id", ""))
	var main := Ax.vbox(18)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 16)
	top.add_theme_constant_override("v_separation", 10)
	main.add_child(top)
	var t := Ax.title(Atelier.title_of("party"), 28 if not narrow else 22)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(t)
	var right := Ax.hbox(16)
	top.add_child(right)
	right.add_child(AtelierParty.switcher(admin))
	right.add_child(Ax.btn("+ " + L.t("ui.atelier.i_new"), func(): _add(admin), "gold", 40.0, 16, 13))
	var q := Ax.field("", Callable(), 38.0, 13, L.t("ui.atelier.i_search"))
	q.custom_minimum_size.x = 260
	q.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main.add_child(q)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	main.add_child(chips)
	for f in [["all", L.t("ui.atelier.i_all")]] + TYPES.map(func(x): return [x[0], L.t(str(x[1]))]):
		var fid: String = f[0]
		chips.add_child(Ax.pill(str(f[1]), _ifilter == fid, func():
			Ax.flush()
			_ifilter = fid
			admin.refresh_tab()))
	var grid := GridContainer.new()
	var main_w: float = admin.size.x - (0.0 if narrow else 280.0 + 380.0) - 64.0
	grid.columns = 1 if main_w < 430.0 else (2 if main_w < 700.0 else 3)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cards: Array = []
	for it in shown:
		var c := _card(it, str(it.get("id", "")) == _isel, func():
			Ax.flush()
			_isel = str(it.get("id", ""))
			admin.refresh_tab())
		grid.add_child(c)
		cards.append([c, it])
	if shown.is_empty():
		main.add_child(Ax.lab(L.t("ui.atelier.i_none"), 14, Ax.MUTED))
	q.text_changed.connect(func(tx: String):
		var w := IconPicker.normalize(tx)
		for e in cards:
			e[0].visible = w == "" or IconPicker.normalize(str((e[1] as Dictionary).get("name", ""))).contains(w))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	main.add_child(sc)
	admin.track_scroll("items", sc)
	var px := 16 if narrow else 32
	var wrapped := Ax.margin(main, px, 28 if not narrow else 18, px, 20)
	wrapped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapped.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if narrow:
		sc.size_flags_vertical = Control.SIZE_FILL
		sc.custom_minimum_size.y = 320
		if not sel.is_empty():
			var box := Ax.panel(Color(0.063, 0.047, 0.031, 0.7), Ax.LINE, 16, 18, 18)
			var col := Ax.vbox(16)
			box.add_child(col)
			main.add_child(box)
			_inspector(admin, sel, col)
		var page := ScrollContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page.add_child(wrapped)
		host.add_child(page)
		admin.set("_scroll", page)
		return
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	host.add_child(root)
	root.add_child(wrapped)
	if not sel.is_empty():
		_inspector(admin, sel, Ax.aside(root, 380.0, 16))

## Retire l'émoji qui précède un libellé (« ✨ Légendaire » → « Légendaire »).
static func _plain(t: String) -> String:
	var rx := RegEx.new()
	rx.compile("^[^\\p{L}]+")
	return rx.sub(t, "").strip_edges()

static func _type_label(t: String) -> String:
	for x in TYPES:
		if x[0] == t:
			return L.t(str(x[1]))
	return t

## Résumé d'une ligne affiché sur la carte d'un objet.
static func _summary(it: Dictionary) -> String:
	var lo := int(it.get("bonusAtkMin", 0))
	var hi := int(it.get("bonusAtkMax", 0))
	match str(it.get("type", "")):
		"potion":
			return "+%d %s" % [int(it.get("heal", 0)), L.t("common.pv")] if int(it.get("heal", 0)) > 0 else "+%d %s" % [int(it.get("staminaRestore", 0)), L.t("common.end")]
		"weapon":
			return "%d – %d" % [lo, hi]
		"armor", "jewelry":
			var parts: Array = []
			if int(it.get("bonusHp", 0)) > 0:
				parts.append("%s +%d" % [L.t("common.pv"), int(it.get("bonusHp", 0))])
			if hi > 0:
				parts.append("%s %d – %d" % [L.t("common.atq"), lo, hi])
			if int(it.get("bonusSpellDmg", 0)) > 0:
				parts.append("%s +%d" % [L.t("common.sort"), int(it.get("bonusSpellDmg", 0))])
			return " · ".join(parts)
		"trap":
			return "%d – %d" % [int(it.get("trapDmgMin", 1)), int(it.get("trapDmgMax", 4))]
		"scroll":
			return str(AdminChars.spell_by_id(Data.admin_config(), str(it.get("spellId", ""))).get("name", ""))
	return ""

## Carte d'un objet (maquette) : pastille d'icône à la couleur de sa rareté, nom, palier et résumé.
static func _card(it: Dictionary, selected: bool, cb: Callable) -> Control:
	var col := Rarity.color(it)
	var p := Ax.panel(Color(0.91, 0.706, 0.361, 0.1) if selected else Ax.CARD, Ax.GOLD if selected else Ax.LINE, 14, 14, 14)
	p.custom_minimum_size = Vector2(0, 116)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ax.vbox(0)
	p.add_child(v)
	var top := Ax.hbox(10)
	var sw := Ax.panel(Color(1, 1, 1, 0.04), col, 10, 0, 0)
	sw.custom_minimum_size = Vector2(40, 40)
	var ic := IconPicker.icon_control(str(it.get("icon", "")), 26.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_child(ic)
	top.add_child(sw)
	var n := Ax.lab(str(it.get("name", "?")), 14, Ax.CREAM, 600)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.clip_text = true
	top.add_child(n)
	v.add_child(top)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var bot := Ax.hbox(8)
	bot.add_child(Ax.chip(_plain(L.t(str(Rarity.DEF[Rarity.of(it)].key))), col, Ax.CLEAR, col, 12, 10, 10, 3))
	var s2 := Control.new()
	s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(s2)
	var sm := Ax.lab(_summary(it), 12, Ax.MUTED)
	bot.add_child(sm)
	v.add_child(bot)
	Ax.clickable(p, cb)
	return p

## Fiche de l'objet choisi : icône, nom, type, rareté et capacité, caractéristiques propres au type, suppression.
static func _inspector(admin: Node, it: Dictionary, col: Control) -> void:
	var refresh := func():
		Ax.changed()
		admin.refresh_tab()
	var head := Ax.hbox(14)
	col.add_child(head)
	head.add_child(IconPicker.button(admin.modals(), it, "icon", refresh, 56.0))
	var hv := Ax.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	var name_edit := Ax.text_field(it, "name", 36.0, 20, "", func(tx: String): admin.note(tx))
	name_edit.add_theme_font_override("font", Ax.cinzel())
	name_edit.add_theme_color_override("font_color", Ax.CREAM)
	name_edit.add_theme_stylebox_override("normal", Ax.sb(Ax.CLEAR, Ax.CLEAR, 6, 0, 6, 0))
	name_edit.add_theme_stylebox_override("focus", Ax.sb(Ax.FIELD, Ax.GOLD, 8, 1, 6, 0))
	hv.add_child(name_edit)
	hv.add_child(Ax.lab(_type_label(str(it.get("type", ""))), 12, Ax.MUTED))
	var typ := Ax.vbox(6)
	typ.add_child(Ax.cap(L.t("ui.atelier.i_type")))
	typ.add_child(Ax.select(TYPES.map(func(t): return [t[0], L.t(str(t[1]))]), it.get("type", ""), func(v):
		it["type"] = v
		refresh.call(), 40.0))
	col.add_child(typ)
	var kind := str(it.get("type", ""))
	if ["weapon", "armor", "jewelry"].has(kind):
		_rarity(col, it, refresh)
	var g := Ax.grid2(col)
	_details(col, g, it, admin)
	col.add_child(Ax.spacer())
	col.add_child(Ax.btn(L.t("ui.atelier.i_delete"), func(): _remove(admin, it), "danger", 38.0))

## Paliers de rareté (pastille + nom) puis, selon le palier, la ou les capacités (choix + valeur en %).
static func _rarity(col: Control, it: Dictionary, refresh: Callable) -> void:
	# objet légendaire d'avant les raretés : ses capacités deviennent explicites dès qu'on le modifie ici
	if not (it.get("perks") is Array) and not Rarity.perks_of(it).is_empty():
		it["perks"] = Rarity.perks_of(it).duplicate(true)
	var cur := Rarity.of(it)
	var v := Ax.vbox(8)
	v.add_child(Ax.cap(L.t("ui.rarity.rarete")))
	var row := Ax.hbox(4)
	v.add_child(row)
	for id in Rarity.ORDER:
		var tid: String = id
		var tc := Rarity.tier_color(tid)
		var on := tid == cur
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = L.t(str(Rarity.DEF[tid].key))
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, Ax.sb(Color(tc.r, tc.g, tc.b, 0.14) if on else Ax.FIELD, tc if on else Ax.LINE, 9, 1, 4, 0))
		b.add_theme_stylebox_override("hover", Ax.sb(Color(tc.r, tc.g, tc.b, 0.2), tc, 9, 1, 4, 0))
		var inner := Ax.vbox(4)
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := Ax.panel(tc, Ax.CLEAR, 5, 0, 0, 0)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(dot)
		var name_s := _plain(L.t(str(Rarity.DEF[tid].key)))
		var tl := Ax.lab(name_s if name_s.length() <= 9 else name_s.substr(0, 5).strip_edges() + ".", 11, Ax.TEXT)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tl)
		b.add_child(inner)
		b.pressed.connect(func():
			AdminRarity._set_tier(it, tid)
			refresh.call())
		row.add_child(b)
	var slots: int = int(AdminRarity.SLOTS[cur])
	v.add_child(Ax.lab("%s : %s" % [_plain(L.t(str(Rarity.DEF[cur].key))), L.t("ui.atelier.i_perks_%d" % slots)], 12, Ax.MUTED))
	col.add_child(v)
	if cur == "common":
		return
	var perks: Array = it.get("perks", [])
	for k in slots:
		var p: Dictionary = perks[k] if k < perks.size() else {"id": "crit", "value": 5}
		var slot := k
		var box := Ax.panel(Ax.CARD2, Ax.LINE2, 12, 14, 12)
		var bv := Ax.vbox(10)
		box.add_child(bv)
		bv.add_child(Ax.cap(L.t("rules.rarity.capacite")))
		var gp := GridContainer.new()
		gp.columns = 3
		gp.add_theme_constant_override("h_separation", 6)
		gp.add_theme_constant_override("v_separation", 6)
		bv.add_child(gp)
		var tint := Color("ff9a4a")
		for pid in Rarity.PERK_NAMES.keys():
			var perk_id: String = pid
			gp.add_child(Ax.choice(L.t(str(Rarity.PERK_NAMES[pid])), perk_id == str(p.id), func():
				AdminRarity._edit(it, slot, "id", perk_id)
				refresh.call(), tint))
		var vr := Ax.hbox(8)
		vr.add_child(Ax.lab(L.t("rules.rarity.valeur_pct").replace(" (%)", ""), 13, Ax.TEXT))
		vr.add_child(Ax.spacer())
		var vl := Ax.lab("%d %%" % int(p.get("value", 5)), 13, Ax.GOLD_L, 600)
		vr.add_child(vl)
		bv.add_child(vr)
		var sl := Ax.slider(float(p.get("value", 5)), 1, 100, 1)
		sl.value_changed.connect(func(x: float):
			AdminRarity._edit(it, slot, "value", int(x))
			vl.text = "%d %%" % int(x)
			Ax.changed())
		bv.add_child(sl)
		col.add_child(box)

## `clampItemStat` de l'original : bornage selon le champ, sans troncature (les décimales sont acceptées).
static func clamp_value(it: Dictionary, field: String, value: float) -> float:
	if ["heal", "trapDmgMin", "trapDmgMax"].has(field):
		return maxf(1.0, value)
	if (field == "bonusAtkMin" or field == "bonusAtkMax") and it.get("type") == "weapon":
		return maxf(1.0, value)
	if BOOST_FIELDS.has(field):
		return maxf(0.0, minf(100.0, value))
	if ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg"].has(field):
		return maxf(0.0, value)
	return value

## Champ numérique d'un objet, borné comme `clampItemStat`.
static func _stat(g: Control, it: Dictionary, key: String, label: String, def: float = 0.0) -> void:
	var lo := clamp_value(it, key, -1.0e9)
	var hi := 100.0 if BOOST_FIELDS.has(key) else 9999.0
	g.add_child(Ax.num(it, key, def, lo, hi, label))

## Caractéristiques selon le type (`libItemDetailsHtml`).
static func _details(col: Control, g: GridContainer, it: Dictionary, admin: Node) -> void:
	match str(it.get("type", "")):
		"potion":
			_stat(g, it, "heal", L.t("common.soin"), 5.0)
			_stat(g, it, "staminaRestore", L.t("common.endurance"))
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			_before(g, Ax.labeled(L.t("ui.atelier.i_weapon_type"), Ax.select(wt, it.get("weaponType", ""), func(x):
				it["weaponType"] = x
				Ax.changed())))
			_stat(g, it, "bonusAtkMin", L.t("common.degats_min"))
			_stat(g, it, "bonusAtkMax", L.t("common.degats_max"))
			_boosts(g, it)
		"armor":
			var slots: Array = []
			for sl in Data.constants.get("SLOT_TYPES", []):
				if sl.id != "weapon" and sl.id != "accessory":
					slots.append([sl.id, sl.label])
			_before(g, Ax.labeled(L.t("admin.items.emplacement"), Ax.select(slots, it.get("slot", ""), func(x):
				it["slot"] = x
				Ax.changed())))
			_gear(g, it)
			_boosts(g, it)
		"jewelry":
			_gear(g, it)
			_boosts(g, it)
		"trap":
			_stat(g, it, "trapDmgMin", L.t("common.degats_min"), 1.0)
			_stat(g, it, "trapDmgMax", L.t("common.degats_max"), 4.0)
			Ax.switch_row(col, L.t("admin.items.permanent_pointes"), bool(it.get("permanent", false)), func(on: bool):
				it["permanent"] = on
				Ax.changed())
		"key":
			col.add_child(Ax.para(L.t("admin.items.se_lie_a_une_porte"), 13, Ax.MUTED))
		"scroll":
			var cfg: Dictionary = Data.admin_config()
			var so: Array = []
			for s in cfg.get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			if so.is_empty():
				so.append(["", L.t("common.aucun_sort_defini_2")])
			_before(g, Ax.labeled(L.t("admin.items.sort_enseigne"), Ax.select(so, it.get("spellId", ""), func(x):
				it["spellId"] = x
				Ax.changed()
				admin.refresh_tab())))
			var sid := str(it.get("spellId", ""))
			var names: Array = []
			for c in cfg.get("classes", []):
				if sid != "" and (c.get("allowedSpellIds", []) as Array).has(sid):
					names.append(str(c.get("name", "")))
			_before(g, Ax.para(L.t("admin.items.classes_compatibles") + (", ".join(names) if not names.is_empty() else "—"), 12, Ax.MUTED))

## Place `ctl` juste avant la grille de caractéristiques et le renvoie (pour l'ajouter à la fiche à la bonne position).
static func _before(g: Control, ctl: Control) -> Control:
	var col := g.get_parent()
	if col != null:
		col.add_child(ctl)
		col.move_child(ctl, g.get_index())
		return ctl
	return ctl

static func _gear(g: Control, it: Dictionary) -> void:
	_stat(g, it, "bonusHp", L.t("common.bonus_pv"))
	_stat(g, it, "bonusSpellDmg", L.t("common.bonus_degats_de_sort"))
	_stat(g, it, "bonusAtkMin", L.t("common.bonus_attaque_min"))
	_stat(g, it, "bonusAtkMax", L.t("common.bonus_attaque_max"))

static func _boosts(g: Control, it: Dictionary) -> void:
	_stat(g, it, "bonusForce", L.t("common.bonus_force"))
	_stat(g, it, "bonusDex", L.t("common.bonus_dexterite"))
	_stat(g, it, "bonusCon", L.t("common.bonus_constitution"))
	_stat(g, it, "bonusInt", L.t("common.bonus_intelligence"))
	_stat(g, it, "bonusSpeed", L.t("common.bonus_vitesse_initiative"))


## --- API historique (onglet « Niveaux » : fiche d'objet placé dans un niveau) ---

## Nombre borné selon le champ (mêmes règles que le HTML).
static func clamp_stat(it: Dictionary, field: String, value: float) -> int:
	var v := int(value)
	if ["heal", "trapDmgMin", "trapDmgMax"].has(field):
		return maxi(1, v)
	if (field == "bonusAtkMin" or field == "bonusAtkMax") and it.get("type") == "weapon":
		return maxi(1, v)
	if ["bonusForce", "bonusDex", "bonusCon", "bonusInt", "bonusSpeed"].has(field):
		return clampi(v, 0, 100)
	return maxi(0, v)

static func _num(parent: Control, label: String, it: Dictionary, key: String, hi: float = 9999.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(84, 0)
	s.value = float(it.get(key, 0))
	s.value_changed.connect(func(v: float): it[key] = clamp_stat(it, key, v))
	AdminUtil.chip(parent, label, s)
	return s

## Champs propres au type de l'objet (partagés avec l'éditeur de niveaux).
static func fields(parent: Control, it: Dictionary, admin: Node, lvl: Dictionary = {}) -> void:
	var f := AdminUtil.flow(parent)
	match str(it.get("type", "potion")):
		"potion":
			_num(f, L.t("admin.items.soin_pv"), it, "heal")
			_num(f, L.t("common.endurance"), it, "staminaRestore")
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			var on_w := func(v): it["weaponType"] = v
			AdminUtil.chip(f, "Type d'arme", AdminUtil.dropdown(wt, it.get("weaponType", "sword"), on_w, 170.0))
			_num(f, L.t("common.attaque_min"), it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
		"armor":
			var slots: Array = []
			for sl in Data.constants.get("SLOT_TYPES", []):
				if sl.id != "weapon" and sl.id != "accessory":
					slots.append([sl.id, sl.label])
			var on_slot := func(v): it["slot"] = v
			AdminUtil.chip(f, L.t("admin.items.emplacement"), AdminUtil.dropdown(slots, it.get("slot", "body"), on_slot, 150.0))
			_num(f, L.t("common.pv"), it, "bonusHp")
			_num(f, L.t("common.attaque_min"), it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_num(f, L.t("common.sort"), it, "bonusSpellDmg")
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
		"jewelry":
			_num(f, L.t("common.pv"), it, "bonusHp")
			_num(f, L.t("common.attaque_min"), it, "bonusAtkMin")
			_num(f, "max", it, "bonusAtkMax")
			_num(f, L.t("common.sort"), it, "bonusSpellDmg")
			_legacy_boosts(parent, it)
			_legacy_legendary(parent, it, admin)
		"trap":
			_num(f, L.t("common.degats_min"), it, "trapDmgMin")
			_num(f, "max", it, "trapDmgMax")
			var cb := CheckBox.new()
			cb.text = L.t("admin.items.permanent_pointes")
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = bool(it.get("permanent", false))
			cb.toggled.connect(func(on: bool): it["permanent"] = on)
			f.add_child(cb)
		"key":
			if lvl.is_empty():
				f.add_child(AdminUtil.label(L.t("admin.items.se_lie_a_une_porte_2"), 13, UiTheme.DIM))
			else:
				var on_door := func(v): it["opensDoorId"] = v
				AdminUtil.chip(f, "Ouvre", AdminUtil.dropdown(door_options(lvl), it.get("opensDoorId", ""), on_door, 200.0))
		"switch":
			var on_d := func(v): it["switchOpensDoorId"] = v
			AdminUtil.chip(f, L.t("admin.items.ouvre_la_porte"), AdminUtil.dropdown(door_options(lvl), it.get("switchOpensDoorId", ""), on_d, 190.0))
			var mons: Array = [["", L.t("admin.items.aucun")]]
			for m in lvl.get("monsters", []):
				mons.append([m.id, str(m.get("name", "?"))])
			var on_m := func(v): it["switchRevealMonsterId"] = v
			AdminUtil.chip(f, L.t("admin.items.revele_le_monstre"), AdminUtil.dropdown(mons, it.get("switchRevealMonsterId", ""), on_m, 200.0))
			var its: Array = [["", L.t("admin.items.aucun")]]
			for o in lvl.get("items", []):
				if o.id != it.id and str(o.get("type", "")) != "decor":
					its.append([o.id, str(o.get("name", "?"))])
			var on_i := func(v): it["switchRevealItemId"] = v
			AdminUtil.chip(f, L.t("admin.items.revele_l_objet"), AdminUtil.dropdown(its, it.get("switchRevealItemId", ""), on_i, 200.0))
			var msg := LineEdit.new()
			msg.placeholder_text = L.t("common.message_affiche")
			msg.text = str(it.get("message", ""))
			msg.custom_minimum_size = Vector2(260, 0)
			msg.text_changed.connect(func(t: String): it["message"] = t)
			AdminUtil.chip(f, "Message", msg)
		"fountain":
			f.add_child(AdminUtil.label(L.t("admin.items.restaure_pv_et_endurance_du"), 13, UiTheme.DIM))
		"scroll":
			var so: Array = []
			for s in Data.admin_config().get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			var on_sp := func(v):
				it["spellId"] = v
				if admin != null:
					admin.refresh_tab()
			AdminUtil.chip(f, L.t("admin.items.sort_enseigne"), AdminUtil.dropdown(so, it.get("spellId", ""), on_sp, 260.0))
			var names: Array = []
			for c in AdminUtil.classes_allowing(str(it.get("spellId", ""))):
				names.append(c.name)
			Form.hint(parent, L.t("admin.items.classes_compatibles") + (", ".join(names) if not names.is_empty() else "aucune"))

static func door_options(lvl: Dictionary) -> Array:
	var out: Array = [["", L.t("common.aucune")]]
	for d in lvl.get("doors", []):
		out.append([d.id, L.fa(L.t("common.porte"), [int(d.x), int(d.y)])])
	return out

static func _legacy_boosts(parent: Control, it: Dictionary) -> void:
	var f := AdminUtil.flow(parent)
	for x in [[L.t("common.force"), "bonusForce"], ["Dex", "bonusDex"], ["Con", "bonusCon"], ["Int", "bonusInt"], [L.t("common.vitesse"), "bonusSpeed"]]:
		_num(f, x[0], it, x[1], 100.0)

static func _legacy_legendary(parent: Control, it: Dictionary, admin: Node) -> void:
	AdminRarity.build(parent, it, func():
		if admin != null:
			admin.refresh_tab())

static func _add(admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	if not (cfg.get("itemLibrary") is Array):
		cfg["itemLibrary"] = []
	var nid := AdminUtil.new_id("lib")
	(cfg.itemLibrary as Array).append({"id": nid, "name": L.t("common.nouvel_objet"), "icon": "💎", "type": "potion", "heal": 5})
	_ifilter = "all"
	_isel = nid
	admin.save()
	admin.refresh_tab()

## `removeLibItem` : confirmation sans titre, puis l'objet disparaît de la bibliothèque et de l'équipement de départ des personnages.
static func _remove(admin: Node, it: Dictionary) -> void:
	var go := func():
		var cfg: Dictionary = Data.admin_config()
		(cfg.itemLibrary as Array).erase(it)
		for p in cfg.get("party", []):
			var se = p.get("startEquipment")
			if se is Dictionary:
				for slot in se.keys():
					if se[slot] == it.id:
						se[slot] = ""
		_isel = ""
		admin.save()
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "", L.fa(L.t("admin.items.supprimer_de_la_bibliotheque"), it.get("name", "")), go)
