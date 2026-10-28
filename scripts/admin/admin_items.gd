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

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var lib: Array = cfg.get("itemLibrary", [])
	var narrow: bool = admin.size.x < 1000.0
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	host.add_child(gap)
	# ---- recherche, filtres de type, nouvel objet
	var bar := BoxContainer.new()
	bar.vertical = narrow
	bar.add_theme_constant_override("separation", 10)
	host.add_child(bar)
	var q := AdminChars.line_edit("", 240.0, 0.9, 12.0, 9.0, L.t("ui.atelier.i_search"))
	q.custom_minimum_size.y = 38
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(q)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(chips)
	for f in [["all", L.t("ui.atelier.i_all")]] + TYPES.map(func(t): return [t[0], L.t(str(t[1]))]):
		var fid: String = f[0]
		chips.add_child(Atelier.pill(str(f[1]), _ifilter == fid, func():
			_ifilter = fid
			admin.refresh_tab()))
	var add := Atelier.button("+ " + L.t("ui.atelier.i_new"), func(): _add(admin), true, false, 38.0)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(add)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	host.add_child(gap2)
	# ---- grille des objets + fiche
	var visible_items: Array = []
	for it in lib:
		if _ifilter == "all" or str(it.get("type", "")) == _ifilter:
			visible_items.append(it)
	var sel: Dictionary = {}
	for it in lib:
		if str(it.get("id", "")) == _isel:
			sel = it
	if sel.is_empty() or not visible_items.has(sel):
		sel = visible_items[0] if not visible_items.is_empty() else {}
		_isel = str(sel.get("id", ""))
	var body := BoxContainer.new()
	body.vertical = narrow
	body.add_theme_constant_override("separation", 18)
	host.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var grid := GridContainer.new()
	grid.columns = 1 if admin.size.x < 700.0 else (3 if admin.size.x > 1700.0 else 2)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(grid)
	var cards: Array = []
	for it in visible_items:
		var c := _card(it, str(it.get("id", "")) == _isel, func():
			Form.flush()
			_isel = str(it.get("id", ""))
			admin.refresh_tab())
		grid.add_child(c)
		cards.append([c, it])
	if visible_items.is_empty():
		left.add_child(Atelier.muted(L.t("ui.atelier.i_none"), 14))
	q.text_changed.connect(func(t: String):
		var w := IconPicker.normalize(t)
		for e in cards:
			e[0].visible = w == "" or IconPicker.normalize(str((e[1] as Dictionary).get("name", ""))).contains(w))
	if not sel.is_empty():
		body.add_child(_inspector(admin, sel, narrow))

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

## Carte d'un objet : pastille d'icône à la couleur de sa rareté, nom, palier et résumé.
static func _card(it: Dictionary, selected: bool, cb: Callable) -> Control:
	var col := Rarity.color(it)
	var p := Atelier.card(selected, 14, 14)
	p.custom_minimum_size = Vector2(0, 100)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var sw := PanelContainer.new()
	sw.custom_minimum_size = Vector2(40, 40)
	sw.add_theme_stylebox_override("panel", Atelier.box(Color(1, 1, 1, 0.04), col, 10, 0, 0))
	var ic := IconPicker.icon_control(str(it.get("icon", "")), 26.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_child(ic)
	top.add_child(sw)
	var n := Label.new()
	n.text = str(it.get("name", "?"))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.clip_text = true
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", Color("f4e6c6"))
	top.add_child(n)
	v.add_child(top)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	var tier := PanelContainer.new()
	tier.add_theme_stylebox_override("panel", Atelier.box(Color(0, 0, 0, 0), col, 10, 10, 2))
	var tl := Label.new()
	tl.text = L.t(str(Rarity.DEF[Rarity.of(it)].key))
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", col)
	tier.add_child(tl)
	bot.add_child(tier)
	bot.add_child(Atelier.muted(_type_label(str(it.get("type", "")))))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(spacer)
	bot.add_child(Atelier.muted(_summary(it)))
	v.add_child(bot)
	Atelier.clickable(p, cb)
	return p

## Fiche de l'objet choisi : icône, nom, type, rareté et capacités, caractéristiques propres au type, suppression.
static func _inspector(admin: Node, it: Dictionary, narrow: bool) -> Control:
	var panel := GameScreen.glass(22, 18)
	panel.custom_minimum_size = Vector2(0 if narrow else 380, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var save := func(): admin.save()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	var ib := IconPicker.button(admin.modals(), it, "icon", func():
		save.call()
		admin.refresh_tab(), 56.0)
	head.add_child(ib)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 6)
	head.add_child(hv)
	var name_edit := AdminChars.line_edit(str(it.get("name", "")), 0.0, 1.0, 10.0, 8.0)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String): it["name"] = t)
	hv.add_child(name_edit)
	var type_sel := AdminChars.select(TYPES.map(func(t): return [t[0], L.t(str(t[1]))]), it.get("type", ""), func(v):
		it["type"] = v
		save.call()
		admin.refresh_tab(), 0.0, 0.85, 10.0, 6.0, true)
	hv.add_child(type_sel)
	var gear: bool = ["weapon", "armor", "jewelry"].has(str(it.get("type", "")))
	if gear:
		col.add_child(_rarity(admin, it, save))
	col.add_child(_details(it, admin, false))
	var del := Atelier.button(L.t("ui.atelier.i_delete"), func(): _remove(admin, it), false, true, 38.0)
	col.add_child(del)
	Form.autosave(panel, save)
	return panel

## Paliers de rareté (pastille de couleur + nom) puis, selon le palier, les capacités (liste + valeur en %).
static func _rarity(admin: Node, it: Dictionary, save: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var cap := Label.new()
	cap.text = L.t("ui.rarity.rarete").to_upper()
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", Color("9a8863"))
	v.add_child(cap)
	var cur := Rarity.of(it)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
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
			b.add_theme_stylebox_override(k, Atelier.box(Color(tc.r, tc.g, tc.b, 0.14) if on else Color("14100a"), tc if on else Color("3a2c18"), 9, 2, 4))
		b.add_theme_stylebox_override("hover", Atelier.box(Color(tc.r, tc.g, tc.b, 0.2), tc, 9, 2, 4))
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ds := StyleBoxFlat.new()
		ds.bg_color = tc
		ds.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", ds)
		inner.add_child(dot)
		var tl := Label.new()
		tl.text = L.t(str(Rarity.DEF[tid].key))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tl.add_theme_font_size_override("font_size", 10)
		tl.add_theme_color_override("font_color", Color("e2d2b0"))
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tl)
		b.add_child(inner)
		b.pressed.connect(func():
			AdminRarity._set_tier(it, tid)
			save.call()
			admin.refresh_tab())
		row.add_child(b)
	# capacités du palier
	if cur != "common":
		var perks: Array = it.get("perks", [])
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Atelier.box(Color(0.12, 0.086, 0.05, 0.85), Color("4a3920"), 12, 14, 12))
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 10)
		box.add_child(bv)
		var bc := Label.new()
		bc.text = L.t("rules.rarity.capacite").to_upper()
		bc.add_theme_font_size_override("font_size", 12)
		bc.add_theme_color_override("font_color", Color("9a8863"))
		bv.add_child(bc)
		for k in int(AdminRarity.SLOTS[cur]):
			var p: Dictionary = perks[k] if k < perks.size() else {"id": "crit", "value": 5}
			var slot := k
			var opts: Array = []
			for pid in Rarity.PERK_NAMES.keys():
				opts.append([pid, L.t(str(Rarity.PERK_NAMES[pid]))])
			bv.add_child(AdminChars.select(opts, str(p.id), func(x):
				AdminRarity._edit(it, slot, "id", str(x))
				save.call(), 0.0, 0.85, 10.0, 6.0, true))
			var sp := Form.setting(bv, L.t("rules.rarity.valeur_pct"), float(p.get("value", 5)), 1, 100, 1, NAN, " %")
			sp.value_changed.connect(func(x: float): AdminRarity._edit(it, slot, "value", int(x)))
		v.add_child(box)
	return v

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

## Champ numérique d'un objet : bornage `clampItemStat` puis la valeur bornée est renvoyée dans le champ.
static func _stat(it: Dictionary, key: String, w: float, tip: String, default_value: float = 0.0, or_default: bool = true) -> LineEdit:
	var o := {"w": w, "tip": tip, "or": or_default, "echo": true, "fix": func(v: float) -> float: return clamp_value(it, key, v)}
	if BOOST_FIELDS.has(key):
		o["lo"] = 0
		o["hi"] = 100
	return AdminCells.num(it, key, default_value, o)

static func _line() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

## Colonne « Détails » selon le type (`libItemDetailsHtml`).
static func _details(it: Dictionary, admin: Node, with_rarity: bool = true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var refresh := func(): admin.refresh_tab()
	match str(it.get("type", "")):
		"potion":
			var f := _line()
			f.add_child(_stat(it, "heal", 48, L.t("common.soin")))
			f.add_child(AdminCells.inline(L.t("admin.items.pv_soin")))
			var e := AdminCells.num(it, "staminaRestore", 0, {"w": 48, "or": true, "tip": L.t("common.endurance")})
			f.add_child(e)
			f.add_child(AdminCells.inline(L.t("common.end")))
			v.add_child(f)
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			var sel := AdminCells.option(wt, it.get("weaponType", ""), func(x): it["weaponType"] = x)
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			var f := _line()
			f.add_child(_stat(it, "bonusAtkMin", 36, ""))
			f.add_child(AdminCells.inline("-"))
			f.add_child(_stat(it, "bonusAtkMax", 36, ""))
			v.add_child(f)
			_boosts(v, it)
			if with_rarity:
				_legendary(v, it, refresh)
		"armor":
			var slots: Array = []
			for sl in Data.constants.get("SLOT_TYPES", []):
				if sl.id != "weapon" and sl.id != "accessory":
					slots.append([sl.id, sl.label])
			var sel := AdminCells.option(slots, it.get("slot", ""), func(x): it["slot"] = x)
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			_gear_line(v, it, L.t("common.bonus_pv_tank"), L.t("common.bonus_attaque_min_guerrier_archer"), L.t("common.bonus_attaque_max"), L.t("common.bonus_degats_de_sort_mage"))
			_boosts(v, it)
			if with_rarity:
				_legendary(v, it, refresh)
		"jewelry":
			_gear_line(v, it, L.t("common.bonus_pv"), L.t("common.bonus_attaque_min"), L.t("common.bonus_attaque_max"), L.t("common.bonus_degats_de_sort"))
			_boosts(v, it)
			if with_rarity:
				_legendary(v, it, refresh)
		"trap":
			var f := _line()
			f.add_child(_stat(it, "trapDmgMin", 36, "", 1.0))
			f.add_child(AdminCells.inline("-"))
			f.add_child(_stat(it, "trapDmgMax", 36, "", 4.0))
			f.add_child(AdminCells.inline(L.t("admin.items.degats")))
			var cb := AdminCells.check(L.t("admin.items.permanent_pointes"), bool(it.get("permanent", false)), func(on: bool): it["permanent"] = on)
			f.add_child(cb)
			v.add_child(f)
		"key":
			v.add_child(AdminCells.inline(L.t("admin.items.se_lie_a_une_porte"), true, 0.74, true))
		"scroll":
			var cfg: Dictionary = Data.admin_config()
			var so: Array = []
			for s in cfg.get("spells", []):
				so.append([s.id, AdminUtil.spell_label(s)])
			if so.is_empty():
				so.append(["", L.t("common.aucun_sort_defini_2")])
			var sel := AdminCells.option(so, it.get("spellId", ""), func(x):
				it["spellId"] = x
				refresh.call())
			sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			v.add_child(sel)
			var sid := str(it.get("spellId", ""))
			var txt := "—"
			if sid != "":
				var names: Array = []
				for c in cfg.get("classes", []):
					if (c.get("allowedSpellIds", []) as Array).has(sid):
						names.append(str(c.get("name", "")))
				txt = ", ".join(names) if not names.is_empty() else "aucune"
			v.add_child(AdminCells.inline(L.t("admin.items.classes_compatibles") + txt, true, 0.74, true))
		_:
			v.add_child(AdminCells.inline("—", true, 0.7))
	return v

## PV / Atq min-max / Sort (armures et bijoux).
static func _gear_line(v: Control, it: Dictionary, t_hp: String, t_min: String, t_max: String, t_sp: String) -> void:
	var f := _line()
	f.add_child(_stat(it, "bonusHp", 34, t_hp))
	f.add_child(AdminCells.inline(L.t("common.pv")))
	f.add_child(_stat(it, "bonusAtkMin", 30, t_min))
	f.add_child(AdminCells.inline("-"))
	f.add_child(_stat(it, "bonusAtkMax", 30, t_max))
	f.add_child(AdminCells.inline(L.t("common.atq")))
	f.add_child(_stat(it, "bonusSpellDmg", 30, t_sp))
	f.add_child(AdminCells.inline(L.t("common.sort")))
	v.add_child(f)

## `statBoostFieldsHtml` : For / Dex / Con / Int / Vit sur une ligne (libellés 0,62 rem, grisés).
static func _boosts(v: Control, it: Dictionary) -> void:
	var f := _line()
	for x in [[L.t("common.for"), "bonusForce", L.t("common.bonus_force")], ["Dex", "bonusDex", L.t("common.bonus_dexterite")], ["Con", "bonusCon", L.t("common.bonus_constitution")],
			["Int", "bonusInt", L.t("common.bonus_intelligence")], ["Vit", "bonusSpeed", L.t("common.bonus_vitesse_initiative")]]:
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		pair.add_child(AdminCells.inline(x[0], true, 0.62))
		pair.add_child(_stat(it, x[1], 26, x[2]))
		f.add_child(pair)
	v.add_child(f)

## `legendaryFieldsHtml` : filet pointillé, case « ✨ Légendaire » ; si cochée : bonus (liste) + valeur en %. Comme l'original, le
## bonus n'est mémorisé que lorsqu'on le choisit dans la liste (la coche seule ne l'écrit pas).
static func _legendary(v: Control, it: Dictionary, refresh: Callable) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, UiMetrics.css(3.0))
	v.add_child(sp)
	AdminCells.dash_line(v)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, UiMetrics.css(3.0))
	v.add_child(sp2)
	AdminRarity.build(v, it, refresh)


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
