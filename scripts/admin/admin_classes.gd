class_name AdminClasses
extends RefCounted
## Onglet « Classes » : un seul panneau, deux groupes (classes de base / évoluées), une carte par classe (armes et sorts
## autorisés, progression, talents, évolution). Portage de renderClassTable et de ses fonctions d'édition.

## Classe affichée dans la fiche (identifiant) et onglet courant ("general", "spells", "prog", "talents", "evo").
static var _csel := ""
static var _ctab := "general"

static func T(s: String) -> String:
	return AdminChars.T(s)

static func _max_sp() -> int:
	return int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))

## Enregistre puis reconstruit la page.
static func _rt(admin: Node) -> void:
	admin.save()
	admin.refresh_tab()

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var classes: Array = cfg.get("classes", [])
	# normalisation de TOUTES les classes (renderClassTable) : progression, évolutions, listes autorisées
	for cls in classes:
		cls["spellProgression"] = cls.get("spellProgression", [])
		cls["allowedWeaponTypes"] = cls.get("allowedWeaponTypes", [])
		cls["allowedSpellIds"] = cls.get("allowedSpellIds", [])
		var to = cls.get("evolvesTo")
		if not (to is Array):
			to = [null, null]
		while (to as Array).size() < 2:
			(to as Array).append(null)
		cls["evolvesTo"] = to
	# talents : un palier pour CHAQUE classe avant de dessiner (sinon Talents.source perdrait ceux des autres classes)
	AdminClassTalents.ensure_all(cfg)
	if classes.is_empty():
		return
	var sel: Dictionary = {}
	for c in classes:
		if str(c.get("id", "")) == _csel:
			sel = c
	if sel.is_empty():
		sel = classes[0]
		_csel = str(sel.get("id", ""))
	var narrow: bool = admin.size.x < 1000.0
	var body := BoxContainer.new()
	body.vertical = narrow
	body.add_theme_constant_override("separation", 20)
	host.add_child(body)
	body.add_child(_list(admin, cfg, classes, narrow))
	body.add_child(_sheet(admin, cfg, sel))

## Liste des classes (de base, puis évoluées) avec le bouton « Nouvelle ».
static func _list(admin: Node, cfg: Dictionary, classes: Array, narrow: bool) -> Control:
	var panel := GameScreen.glass(14, 16)
	panel.custom_minimum_size = Vector2(0 if narrow else 280, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var top := HBoxContainer.new()
	var t := Label.new()
	t.text = L.t("ui.atelier.c_classes")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color("f4e6c6"))
	top.add_child(t)
	top.add_child(Atelier.button("+ " + L.t("ui.atelier.c_new"), func(): _add_modal(admin, cfg), true, false, 34.0))
	col.add_child(top)
	for grp in [[L.t("admin.classes.classes_de_base"), true], [L.t("admin.classes.classes_evoluees"), false]]:
		var g := VBoxContainer.new()
		g.add_theme_constant_override("separation", 4)
		var h := Label.new()
		h.text = str(grp[0]).to_upper()
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", Color("9a8863"))
		g.add_child(h)
		var any := false
		for c in classes:
			if AdminUtil.is_base(c) == grp[1]:
				any = true
				g.add_child(_class_row(admin, c, str(c.get("id", "")) == _csel))
		if any:
			col.add_child(g)
	return panel

static func _class_row(admin: Node, c: Dictionary, on: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Atelier.box(Color(0.91, 0.71, 0.36, 0.12) if on else Color(0, 0, 0, 0), Color("e8b45c") if on else Color(0, 0, 0, 0), 12, 10, 8))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(36, 36)
	av.add_theme_stylebox_override("panel", Atelier.box(Color("241a0e"), Color(0, 0, 0, 0), 10, 0, 0, 0))
	var ic := IconPicker.icon_control(str(c.get("icon", "")), 24.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	av.add_child(ic)
	h.add_child(av)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := Label.new()
	n.text = str(c.get("name", ""))
	n.clip_text = true
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", Color("f4e6c6"))
	v.add_child(n)
	var meta: String
	if AdminUtil.is_base(c):
		meta = L.fa(L.t("ui.atelier.c_spells_n"), (c.get("allowedSpellIds", []) as Array).size())
	else:
		meta = L.fa(L.t("ui.atelier.c_depuis"), str(c.get("evolvesFrom", "")))
	v.add_child(Atelier.muted(meta))
	h.add_child(v)
	Atelier.ignore_mouse(p)
	Atelier.clickable(p, func():
		Form.flush()
		_csel = str(c.get("id", ""))
		_ctab = "general"
		_rt(admin))
	return p

## Fiche de la classe choisie : en-tête, onglets, contenu de l'onglet.
static func _sheet(admin: Node, cfg: Dictionary, cls: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 16)
	var is_base := AdminUtil.is_base(cls)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	head.add_child(IconPicker.button(admin.modals(), cls, "icon", func(): _rt(admin), 64.0))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	var nm := Label.new()
	nm.text = str(cls.get("name", ""))
	nm.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	nm.add_theme_font_size_override("font_size", 28)
	nm.add_theme_color_override("font_color", Color("f4e6c6"))
	hv.add_child(nm)
	var sub: String
	if is_base:
		sub = L.t("ui.atelier.c_base")
	else:
		sub = L.fa(L.t("ui.atelier.c_advanced"), str(cls.get("evolvesFrom", "")))
	hv.add_child(Atelier.muted(sub, 13))
	var rm := Atelier.button(L.t("ui.atelier.c_delete"), func(): _remove(admin, cfg, cls), false, true, 40.0)
	rm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rm)
	col.add_child(Atelier.tabs([["general", L.t("ui.atelier.c_t_general")], ["spells", L.t("ui.atelier.c_t_spells")], ["prog", L.t("ui.atelier.c_t_prog")],
		["talents", L.t("ui.atelier.c_t_talents")], ["evo", L.t("ui.atelier.c_t_evo")]], _ctab, func(id: String):
			Form.flush()
			_ctab = id
			_rt(admin)))
	var card := GameScreen.glass(22, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(card)
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", int(AdminChars.cpx(12.0)))
	card.add_child(b)
	match _ctab:
		"spells": _tab_spells(b, admin, cfg, cls)
		"prog": _progression(b, admin, cfg, cls)
		"talents": AdminClassTalents.section(b, admin, cfg, cls)
		"evo": _tab_evo(b, admin, cfg, cls, is_base)
		_: _tab_general(b, admin, cls, is_base)
	Form.autosave(card, func(): admin.save())
	return col

static func _tab_general(b: VBoxContainer, admin: Node, cls: Dictionary, is_base: bool) -> void:
	var gs := _section(b, L.t("ui.atelier.c_t_general"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 24)
	row.add_theme_constant_override("v_separation", 14)
	gs.add_child(row)
	if is_base:
		var opts: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			opts.append([n, n])
		var on_name := func(v):
			cls["name"] = v
			_rt(admin)
		AdminChars._field(row, L.t("common.nom"), AdminChars.select(opts, cls.get("name", ""), on_name, 200.0, 0.9, 9.0, 7.0))
	else:
		var e := AdminChars.line_edit(str(cls.get("name", "")), 200.0, 0.9, 9.0, 7.0)
		e.text_changed.connect(func(t: String): cls["name"] = t)
		AdminChars.on_commit(e, func(_t: String): _rt(admin))
		AdminChars._field(row, L.t("common.nom"), e)
	var on_speed := func(v):
		cls["baseSpeed"] = int(clampf(roundf(float(v)), 1.0, 40.0))
		return cls["baseSpeed"]
	AdminChars._field(row, L.t("admin.classes.vitesse"), AdminChars.num_edit(cls.get("baseSpeed", 10), 70.0, 0.9, on_speed, 9.0, 7.0, false, L.t("admin.classes.vitesse_aide")))
	gs.add_child(AdminChars.dim_hint(L.t("admin.classes.vitesse_aide")))

## Armes et sorts autorisés.
static func _tab_spells(b: VBoxContainer, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var base := AdminChars.base_of(cfg, cls)
	var ws := _section(b, L.t("admin.classes.armes_autorisees"))
	var wf := AdminChars.flow(ws, 16.0, 5.0)
	for w in AdminUtil.weapon_types():
		var wid: String = w.id
		var on_w := func(on: bool):
			var arr: Array = cls.allowedWeaponTypes
			if on and not arr.has(wid):
				arr.append(wid)
			elif not on:
				arr.erase(wid)
		wf.add_child(AdminChars.chk(str(w.label), 0.8, (cls.allowedWeaponTypes as Array).has(wid), on_w))
	if not base.is_empty() and not (base.get("allowedWeaponTypes", []) as Array).is_empty():
		var names: Array = []
		for wid in base.allowedWeaponTypes:
			names.append(AdminUtil.weapon_label(str(wid)))
		_inherit_note(ws, str(base.name), names)
	var max_sp := _max_sp()
	var ss := _section(b, L.t("admin.classes.sorts_autorises_via_attribution"))
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		ss.add_child(AdminChars.dim_hint(L.t("common.aucun_sort_defini")))
	else:
		var sf := AdminChars.flow(ss, 16.0, 5.0)
		for s in spells:
			var sid: String = s.id
			var cb := AdminChars.chk(AdminUtil.spell_label(s), 0.8, (cls.allowedSpellIds as Array).has(sid), Callable())
			cb.toggled.connect(func(on: bool):
				var arr: Array = cls.allowedSpellIds
				if on:
					if arr.size() >= max_sp:
						cb.set_pressed_no_signal(false)
						admin.say(L.fa(T(L.t("admin.classes.sorts_capacites_maximum_autorises")), [str(cls.get("name", "")), max_sp]))
						return
					if not arr.has(sid):
						arr.append(sid)
				else:
					arr.erase(sid)
					for p in cfg.get("party", []):
						if p.get("classId") == cls.get("id"):
							(p.get("spellsKnown", []) as Array).erase(sid))
			sf.add_child(cb)
	if not base.is_empty() and not (base.get("allowedSpellIds", []) as Array).is_empty():
		var names2: Array = []
		for sid in base.allowedSpellIds:
			var sp := AdminChars.spell_by_id(cfg, str(sid))
			names2.append(AdminUtil.spell_label(sp) if not sp.is_empty() else str(sid))
		_inherit_note(ss, str(base.name), names2)

## Évolution : classe de base = niveau requis et deux voies ; classe évoluée = classe dont elle dépend.
static func _tab_evo(b: VBoxContainer, admin: Node, cfg: Dictionary, cls: Dictionary, is_base: bool) -> void:
	if is_base:
		_evolution(b, admin, cfg, cls)
		return
	var ds := _section(b, L.t("admin.classes.depend_de_la_classe_de"))
	var dep: Array = []
	for n in AdminUtil.BASE_ARCHETYPES:
		dep.append([n, n])
	var on_dep := func(v):
		cls["evolvesFrom"] = v
		_rt(admin)
	var r := HBoxContainer.new()
	r.add_child(AdminChars.select(dep, cls.get("evolvesFrom", ""), on_dep, 200.0, 0.9, 9.0, 7.0))
	ds.add_child(r)
	ds.add_child(AdminChars.dim_hint(L.t("admin.classes.une_classe_evoluee_n_est")))

static func _section(parent: Control, label: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	parent.add_child(v)
	v.add_child(AdminChars.csection_label(label))
	return v

## Note « 🔗 Hérite aussi de **base** : … » (hint italique, nom de la base en gras).
static func _inherit_note(parent: Control, base_name: String, items: Array) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(AdminChars.cpx(5.0)))
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 120.0
	var sz := AdminChars.fpx(0.74)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(k, sz)
	r.add_theme_font_override("normal_font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	r.add_theme_font_override("bold_font", UiTheme.font("res://assets/fonts/Spectral-BoldItalic.ttf"))
	r.add_theme_color_override("default_color", AdminChars.PDIM)
	var esc := func(s: String) -> String: return s.replace("[", "[lb]")
	r.text = L.fa(T(L.t("admin.classes.herite_aussi_de")), ["[b]%s[/b]" % esc.call(L.c(base_name)), esc.call(", ".join(items.map(func(x): return L.c(str(x)))))])
	m.add_child(r)
	parent.add_child(m)

static func _progression(b: VBoxContainer, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var ps := _section(b, L.t("admin.classes.progression_automatique_par_niveau"))
	var prog: Array = cls.spellProgression
	if prog.is_empty():
		ps.add_child(AdminChars.dim_hint(L.t("admin.classes.aucune_progression_definie_les")))
	else:
		var pf := AdminChars.flow(ps, 19.0, 9.0)
		for i in prog.size():
			var p: Dictionary = prog[i]
			var s2 := AdminChars.spell_by_id(cfg, str(p.get("spellId", "")))
			var pidx := i
			pf.add_child(_chip(L.fa(T(L.t("admin.classes.niv")), [AdminChars.num_text(p.get("level", 1)), AdminUtil.spell_label(s2) if not s2.is_empty() else "?"]), func():
				prog.remove_at(pidx)
				_rt(admin)))
	var row := AdminChars.flow(null, 6.0, 6.0)
	var mt := MarginContainer.new()
	mt.add_theme_constant_override("margin_top", int(AdminChars.cpx(6.0)))
	mt.add_child(row)
	ps.add_child(mt)
	var lvl_edit := AdminChars.line_edit("3", 56.0, 0.85, 9.0, 7.0)
	lvl_edit.tooltip_text = L.t("common.niveau_2")
	lvl_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lvl_edit)
	var spell_opts: Array = []
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		spell_opts.append(["", L.t("common.aucun_sort_defini_2")])
	for s in spells:
		spell_opts.append([s.id, AdminUtil.spell_label(s)])
	var spell_sel := AdminChars.select(spell_opts, "", func(_v): pass, 120.0, 0.85, 9.0, 7.0, true)
	spell_sel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(spell_sel)
	var add := Button.new()
	add.text = L.t("admin.classes.ajouter")
	add.focus_mode = Control.FOCUS_NONE
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add.pressed.connect(func():
		var n = AdminChars.parse_num(lvl_edit.text)
		var level: float = maxf(1.0, float(n) if float(n) != 0.0 else 1.0)
		var level_v: Variant = int(level) if is_equal_approx(level, roundf(level)) else level
		var sid2 := str(spell_opts[spell_sel.selected][0]) if spell_sel.selected >= 0 else ""
		if sid2 == "":
			return
		for q in prog:
			if is_equal_approx(float(q.level), level) and q.spellId == sid2:
				AdminChars.alert(admin, T(L.t("admin.classes.cette_classe_apprend_deja_ce")))
				return
		var allowed: Array = cls.allowedSpellIds
		if not allowed.has(sid2):
			if allowed.size() >= _max_sp():
				AdminChars.alert(admin, L.fa(T(L.t("admin.classes.impossible_a_deja_atteint_son")), [str(cls.get("name", "")), _max_sp()]))
				return
			allowed.append(sid2)
		prog.append({"level": level_v, "spellId": sid2})
		_stable_sort(prog)
		_rt(admin))
	row.add_child(add)

## Tri par niveau STABLE (clé secondaire = ordre d'insertion), comme `Array.prototype.sort` de JS.
static func _stable_sort(prog: Array) -> void:
	var tmp: Array = []
	for i in prog.size():
		tmp.append([prog[i], i])
	tmp.sort_custom(func(a, b):
		var la := float(a[0].level)
		var lb := float(b[0].level)
		if is_equal_approx(la, lb):
			return a[1] < b[1]
		return la < lb)
	prog.clear()
	for t in tmp:
		prog.append(t[0])

## Pastille « .tag-chip » : texte + croix (rouge au survol).
static func _chip(text: String, on_remove: Callable) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c1610")
	sb.border_color = AdminChars.BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = AdminChars.cpx(9.0)
	sb.content_margin_right = AdminChars.cpx(4.0)
	sb.content_margin_top = AdminChars.cpx(2.0)
	sb.content_margin_bottom = AdminChars.cpx(2.0)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(AdminChars.cpx(4.0)))
	p.add_child(h)
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", AdminChars.fpx(0.68))
	h.add_child(l)
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_size_override("font_size", AdminChars.fpx(0.85))
	x.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	x.add_theme_color_override("font_color", AdminChars.PDIM)
	x.add_theme_color_override("font_hover_color", Color("c23b3b"))
	x.add_theme_color_override("font_pressed_color", Color("c23b3b"))
	var e := StyleBoxEmpty.new()
	e.content_margin_left = AdminChars.cpx(4.0)
	e.content_margin_right = AdminChars.cpx(4.0)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		x.add_theme_stylebox_override(st, e)
	x.pressed.connect(on_remove)
	h.add_child(x)
	return p

static func _evolution(b: VBoxContainer, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var es := _section(b, L.t("admin.classes.evolution_de_classe"))
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", int(AdminChars.cpx(8.0)))
	var fl := Label.new()
	fl.text = L.t("admin.classes.niveau_requis")
	fl.custom_minimum_size.x = AdminChars.cpx(140.0)
	fl.add_theme_font_size_override("font_size", AdminChars.fpx(0.75))
	fl.add_theme_color_override("font_color", AdminChars.PDIM)
	fr.add_child(fl)
	var on_lvl := func(v):
		cls["evolveLevel"] = int(float(v))
		_rt(admin)
		return null
	var ne := AdminChars.num_edit(cls.get("evolveLevel", 0), 70.0, 0.85, on_lvl, 9.0, 7.0, true)
	ne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(ne)
	var frm := MarginContainer.new()
	frm.add_theme_constant_override("margin_bottom", int(AdminChars.cpx(10.0)))
	frm.add_child(fr)
	es.add_child(frm)
	var to: Array = cls.evolvesTo
	var cand: Array = [["", L.t("common.aucune")]]
	for c in cfg.get("classes", []):
		if c.get("id") != cls.get("id") and not AdminUtil.is_base(c) and str(c.get("evolvesFrom", "")) == str(cls.get("name", "")):
			cand.append([c.id, "%s %s" % [AdminUtil.icon_text_fallback(str(c.get("icon", ""))), c.name]])
	var ef := AdminChars.flow(es, 8.0, 8.0)
	for slot in 2:
		var sl := slot
		var on_evo := func(v): to[sl] = v if v != "" else null
		var cur = to[sl] if to[sl] != null else ""
		ef.add_child(AdminChars.select(cand, cur, on_evo, 0.0, 0.85, 9.0, 7.0, false, [], true))
	es.add_child(_evo_hint())

static func _evo_hint() -> Control:
	var l := Label.new()
	l.text = L.t("admin.classes.voies_evolution_classes_evoluees")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120.0
	l.add_theme_font_size_override("font_size", AdminChars.fpx(0.74))
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.add_theme_color_override("font_color", AdminChars.PDIM)
	return l

static func _remove(admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var classes: Array = cfg.classes
	if classes.size() <= 1:
		AdminChars.alert(admin, T(L.t("admin.classes.il_doit_rester_au_moins")))
		return
	var go := func():
		classes.erase(cls)
		var fallback: String = str(classes[0].id)
		for p in cfg.get("party", []):
			if p.get("classId") == cls.get("id"):
				p["classId"] = fallback
				p["spellsKnown"] = []
		_rt(admin)
	Dialogs.confirm(admin.modals(), "", L.fa(L.t("admin.classes.supprimer_la_classe"), str(cls.get("name", ""))), go)

## Fenêtre « Nouvelle classe » (type, dépendance), puis création et défilement jusqu'à la nouvelle carte.
static func _add_modal(admin: Node, cfg: Dictionary) -> void:
	var m := Modal.open(admin.modals(), L.t("admin.classes.nouvelle_classe"), 380.0)
	var st := {"type": "base", "dep": "Guerrier"}
	var frow := func(label: String, field: Control) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(AdminChars.cpx(8.0)))
		var l := Label.new()
		l.text = label
		l.custom_minimum_size.x = AdminChars.cpx(100.0)
		l.add_theme_font_size_override("font_size", AdminChars.fpx(0.75))
		l.add_theme_color_override("font_color", AdminChars.PDIM)
		h.add_child(l)
		h.add_child(field)
		m.content.add_child(h)
		return h
	var dep_opts: Array = []
	for n in AdminUtil.BASE_ARCHETYPES:
		dep_opts.append([n, n])
	var rows := {}
	var on_type := func(v):
		st.type = v
		rows.dep.visible = v == "advanced"
		m.call_deferred("_fit")
		admin.get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(m):
				m._fit())
	frow.call(L.t("admin.classes.type"), AdminChars.select([["base", L.t("admin.classes.classe_de_base")], ["advanced", L.t("admin.classes.classe_evoluee")]], "base", on_type, 100.0, 0.85, 9.0, 7.0, true))
	rows["dep"] = frow.call(L.t("admin.classes.depend_de"), AdminChars.select(dep_opts, "Guerrier", func(v): st.dep = v, 100.0, 0.85, 9.0, 7.0, true))
	rows.dep.visible = false
	var mh := AdminChars.dim_hint(L.t("admin.classes.une_classe_evoluee_n_est"))
	mh.custom_minimum_size.x = 280.0
	m.content.add_child(mh)
	var go := func():
		var cls: Dictionary
		var parent_icon := "@icon:misc_shield"       # une nouvelle classe reçoit toujours une icône en image : celle de la classe dont elle dépend
		for pc in cfg.classes:
			if str(pc.get("name", "")) == str(st.dep) or str(pc.get("id", "")) == str(st.dep):
				if SaveMigrations.class_icon_ok(str(pc.get("icon", ""))):
					parent_icon = str(pc.icon)
		if st.type == "base":
			cls = {"id": AdminUtil.new_id("class"), "name": "Guerrier", "icon": "@icon:misc_shield", "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": [], "evolvesTo": [null, null], "evolveLevel": 5}
		else:
			cls = {"id": AdminUtil.new_id("class"), "name": L.t("admin.classes.nouvelle_evolution"), "icon": parent_icon, "evolvesFrom": st.dep, "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": []}
		cfg.classes.append(cls)
		_csel = str(cls.id)
		_ctab = "general"
		m.close()
		_rt(admin)
	m.set_buttons([{"text": L.t("common.annuler"), "primary": false, "cb": func(): m.close()}, {"text": L.t("admin.classes.creer"), "primary": true, "cb": go}])
	# la hauteur du corps défilant est calculée avant que le texte du hint soit mis en page : on la refait un instant après
	admin.get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(m):
			m._fit())
