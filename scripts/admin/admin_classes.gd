class_name AdminClasses
extends RefCounted
## Onglet « Classes » : un seul panneau, deux groupes (classes de base / évoluées), une carte par classe (armes et sorts
## autorisés, progression, talents, évolution). Portage de renderClassTable et de ses fonctions d'édition.

## Cartes de la dernière construction (identifiant → nœud), pour faire défiler jusqu'à une classe nouvellement créée.
static var _cards: Dictionary = {}

static func T(s: String) -> String:
	return AdminChars.T(s)

static func _max_sp() -> int:
	return int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))

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
	_cards.clear()
	var head := Form.panel(host, "Classes")
	Form.hint(head, "Chaque classe détermine les types d'armes et les sorts qu'un personnage de cette classe peut utiliser.")
	var status := AdminChars.status_label()
	AdminChars.actions_row(head, [
		AdminChars.action_btn("+ Ajouter une classe", func(): _add_modal(admin, cfg)),
		AdminChars.action_btn("💾 Enregistrer la configuration par défaut", func(): admin.confirm_save(status), true)])
	head.add_child(status)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", int(AdminChars.cpx(12.0)))
	head.add_child(cards)
	var base_group := _group(cards, "⭐ Classes de base", true)
	var adv_group := _group(cards, "🔶 Classes évoluées", false)
	for cls in classes:
		var is_base := AdminUtil.is_base(cls)
		_card(base_group if is_base else adv_group, admin, cfg, cls, is_base, status)

static func _group(parent: Control, title: String, first: bool) -> VBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", int(AdminChars.cpx(6.0)))
	parent.add_child(m)
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", int(AdminChars.cpx(10.0)))
	m.add_child(g)
	var t := MarginContainer.new()
	t.add_theme_constant_override("margin_top", 0 if first else int(AdminChars.cpx(14.0)))
	t.add_theme_constant_override("margin_bottom", int(AdminChars.cpx(2.0)))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", int(AdminChars.cpx(5.0)))
	t.add_child(tv)
	var l := Label.new()
	l.text = title.to_upper()
	var fv := FontVariation.new()
	fv.base_font = UiTheme.font("res://assets/fonts/Spectral-Bold.ttf")
	fv.spacing_glyph = int(roundf(AdminChars.cpx(0.06 * 0.82 * 18.0)))
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", AdminChars.fpx(0.82))
	l.add_theme_color_override("font_color", AdminChars.GOLD_BRIGHT)
	tv.add_child(l)
	var line := ColorRect.new()
	line.color = AdminChars.GOLD_DIM
	line.custom_minimum_size.y = maxf(1.0, AdminChars.cpx(1.0))
	tv.add_child(line)
	g.add_child(t)
	return g

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
	r.text = T("🔗 Hérite aussi de %s : %s") % ["[b]%s[/b]" % esc.call(base_name), esc.call(", ".join(items))]
	m.add_child(r)
	parent.add_child(m)

static func _card(parent: Control, admin: Node, cfg: Dictionary, cls: Dictionary, is_base: bool, status: Label) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.02)
	sb.border_color = AdminChars.GOLD_DIM if is_base else AdminChars.BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = AdminChars.cpx(12.0)
	sb.content_margin_right = AdminChars.cpx(12.0)
	sb.content_margin_top = AdminChars.cpx(10.0)
	sb.content_margin_bottom = AdminChars.cpx(10.0)
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	_cards[str(cls.get("id", ""))] = card
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", int(AdminChars.cpx(8.0)))
	card.add_child(b)

	# en-tête : icône, nom, 🗑
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", int(AdminChars.cpx(8.0)))
	b.add_child(hdr)
	hdr.add_child(AdminChars.icon_btn(admin, cls, "icon", admin.refresh_tab))
	if is_base:
		var opts: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			opts.append([n, n])
		var on_name := func(v):
			cls["name"] = v
			admin.refresh_tab()
		var sel := AdminChars.select(opts, cls.get("name", ""), on_name, 100.0, 0.85, 9.0, 7.0, true)
		sel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr.add_child(sel)
	else:
		var e := AdminChars.line_edit(str(cls.get("name", "")), 100.0, 0.85, 9.0, 7.0)
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		e.text_changed.connect(func(t: String): cls["name"] = t)
		AdminChars.on_commit(e, func(_t: String): admin.refresh_tab())
		hdr.add_child(e)
	var rm := AdminChars.small_btn("🗑", 0.8, 6.0, 10.0)
	rm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rm.pressed.connect(func(): _remove(admin, cfg, cls))
	hdr.add_child(rm)

	# classe évoluée : dépendance
	if not is_base:
		var dm := MarginContainer.new()
		dm.add_theme_constant_override("margin_top", int(AdminChars.cpx(2.0)))
		dm.add_theme_constant_override("margin_bottom", int(AdminChars.cpx(8.0)))
		var dh := HBoxContainer.new()
		dh.add_theme_constant_override("separation", int(AdminChars.cpx(6.0)))
		dm.add_child(dh)
		var dl := Label.new()
		dl.text = "🔗 Dépend de la classe de base :"
		dl.add_theme_font_size_override("font_size", AdminChars.fpx(0.72))
		dh.add_child(dl)
		var dep: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			dep.append([n, n])
		var on_dep := func(v):
			cls["evolvesFrom"] = v
			admin.refresh_tab()
		dh.add_child(AdminChars.select(dep, cls.get("evolvesFrom", ""), on_dep, 60.0, 0.8, 6.0, 10.0, true))
		b.add_child(dm)

	var base := AdminChars.base_of(cfg, cls)

	# armes autorisées
	var ws := _section(b, "Armes autorisées")
	var wf := AdminChars.flow(ws, 16.0, 5.0)
	for w in AdminUtil.weapon_types():
		var wid: String = w.id
		var on_w := func(on: bool):
			var arr: Array = cls.allowedWeaponTypes
			if on and not arr.has(wid):
				arr.append(wid)
			elif not on:
				arr.erase(wid)
		wf.add_child(AdminChars.chk(str(w.label), 0.74, (cls.allowedWeaponTypes as Array).has(wid), on_w))
	if not base.is_empty() and not (base.get("allowedWeaponTypes", []) as Array).is_empty():
		var names: Array = []
		for wid in base.allowedWeaponTypes:
			names.append(AdminUtil.weapon_label(str(wid)))
		_inherit_note(ws, str(base.name), names)

	# sorts autorisés
	var max_sp := _max_sp()
	var ss := _section(b, "Sorts autorisés (via attribution manuelle ou parchemin)")
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		ss.add_child(AdminChars.dim_hint("Aucun sort défini."))
	else:
		var sf := AdminChars.flow(ss, 16.0, 5.0)
		for s in spells:
			var sid: String = s.id
			var cb := AdminChars.chk(AdminUtil.spell_label(s), 0.74, (cls.allowedSpellIds as Array).has(sid), Callable())
			cb.toggled.connect(func(on: bool):
				var arr: Array = cls.allowedSpellIds
				if on:
					if arr.size() >= max_sp:
						cb.set_pressed_no_signal(false)
						status.text = T("❌ %s : %d sorts/capacités maximum autorisés par classe (plafond fixe, jamais dépassable — un personnage ne peut de toute façon jamais en connaître plus).") % [str(cls.get("name", "")), max_sp]
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

	# progression automatique par niveau
	_progression(b, admin, cfg, cls)

	# talents (toujours visibles)
	AdminClassTalents.section(b, admin, cfg, cls)

	# évolution (classes de base)
	if is_base:
		_evolution(b, admin, cfg, cls)

static func _progression(b: VBoxContainer, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var ps := _section(b, "Progression automatique par niveau")
	var prog: Array = cls.spellProgression
	if prog.is_empty():
		ps.add_child(AdminChars.dim_hint("Aucune progression définie — les sorts autorisés restent à attribuer manuellement ou via parchemin."))
	else:
		var pf := AdminChars.flow(ps, 19.0, 9.0)
		for i in prog.size():
			var p: Dictionary = prog[i]
			var s2 := AdminChars.spell_by_id(cfg, str(p.get("spellId", "")))
			var pidx := i
			pf.add_child(_chip(T("Niv.%s → %s") % [AdminChars.num_text(p.get("level", 1)), AdminUtil.spell_label(s2) if not s2.is_empty() else "?"], func():
				prog.remove_at(pidx)
				admin.refresh_tab()))
	var row := AdminChars.flow(null, 6.0, 6.0)
	var mt := MarginContainer.new()
	mt.add_theme_constant_override("margin_top", int(AdminChars.cpx(6.0)))
	mt.add_child(row)
	ps.add_child(mt)
	var lvl_edit := AdminChars.line_edit("3", 56.0, 0.85, 9.0, 7.0)
	lvl_edit.tooltip_text = "Niveau"
	lvl_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lvl_edit)
	var spell_opts: Array = []
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		spell_opts.append(["", "— Aucun sort défini —"])
	for s in spells:
		spell_opts.append([s.id, AdminUtil.spell_label(s)])
	var spell_sel := AdminChars.select(spell_opts, "", func(_v): pass, 120.0, 0.85, 9.0, 7.0, true)
	spell_sel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(spell_sel)
	var add := Button.new()
	add.text = "+ Ajouter"
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
				AdminChars.alert(admin, T("Cette classe apprend déjà ce sort à ce niveau précis."))
				return
		var allowed: Array = cls.allowedSpellIds
		if not allowed.has(sid2):
			if allowed.size() >= _max_sp():
				AdminChars.alert(admin, T("Impossible : %s a déjà atteint son maximum de %d sorts/capacités autorisés. Retirez-en un avant d'ajouter celui-ci à la progression.") % [str(cls.get("name", "")), _max_sp()])
				return
			allowed.append(sid2)
		prog.append({"level": level_v, "spellId": sid2})
		_stable_sort(prog)
		admin.refresh_tab())
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
	var es := _section(b, "Évolution de classe")
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", int(AdminChars.cpx(8.0)))
	var fl := Label.new()
	fl.text = "Niveau requis"
	fl.custom_minimum_size.x = AdminChars.cpx(140.0)
	fl.add_theme_font_size_override("font_size", AdminChars.fpx(0.75))
	fl.add_theme_color_override("font_color", AdminChars.PDIM)
	fr.add_child(fl)
	var on_lvl := func(v):
		cls["evolveLevel"] = int(float(v))
		admin.refresh_tab()
		return null
	var ne := AdminChars.num_edit(cls.get("evolveLevel", 0), 70.0, 0.85, on_lvl, 9.0, 7.0, true)
	ne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(ne)
	var frm := MarginContainer.new()
	frm.add_theme_constant_override("margin_bottom", int(AdminChars.cpx(10.0)))
	frm.add_child(fr)
	es.add_child(frm)
	var to: Array = cls.evolvesTo
	var cand: Array = [["", "— aucune —"]]
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
	l.text = "\nVoies d’évolution : classes évoluées dont la dépendance pointe vers cette classe de base."
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
		AdminChars.alert(admin, T("Il doit rester au moins une classe."))
		return
	var go := func():
		classes.erase(cls)
		var fallback: String = str(classes[0].id)
		for p in cfg.get("party", []):
			if p.get("classId") == cls.get("id"):
				p["classId"] = fallback
				p["spellsKnown"] = []
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "", "Supprimer la classe %s ?" % str(cls.get("name", "")), go)

## Fenêtre « Nouvelle classe » (type, dépendance), puis création et défilement jusqu'à la nouvelle carte.
static func _add_modal(admin: Node, cfg: Dictionary) -> void:
	var m := Modal.open(admin.modals(), "Nouvelle classe", 380.0)
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
	frow.call("Type", AdminChars.select([["base", "Classe de base"], ["advanced", "Classe évoluée"]], "base", on_type, 100.0, 0.85, 9.0, 7.0, true))
	rows["dep"] = frow.call("Dépend de", AdminChars.select(dep_opts, "Guerrier", func(v): st.dep = v, 100.0, 0.85, 9.0, 7.0, true))
	rows.dep.visible = false
	var mh := AdminChars.dim_hint("Une classe évoluée n'est accessible qu'en évoluant depuis la classe de base choisie ici.")
	mh.custom_minimum_size.x = 280.0
	m.content.add_child(mh)
	var go := func():
		var cls: Dictionary
		if st.type == "base":
			cls = {"id": AdminUtil.new_id("class"), "name": "Guerrier", "icon": "🧝", "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": [], "evolvesTo": [null, null], "evolveLevel": 5}
		else:
			cls = {"id": AdminUtil.new_id("class"), "name": "Nouvelle évolution", "icon": "🧝", "evolvesFrom": st.dep, "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": []}
		cfg.classes.append(cls)
		m.close()
		await admin.refresh_tab()
		await admin.get_tree().create_timer(0.06).timeout
		var card = _cards.get(str(cls.id))
		if card != null and is_instance_valid(card) and admin._scroll != null:
			var sc: ScrollContainer = admin._scroll
			var want: float = card.global_position.y + card.size.y * 0.5 - (sc.global_position.y + sc.size.y * 0.5)
			sc.scroll_vertical = int(sc.scroll_vertical + want)
	m.set_buttons([{"text": "Annuler", "primary": false, "cb": func(): m.close()}, {"text": "Créer", "primary": true, "cb": go}])
	# la hauteur du corps défilant est calculée avant que le texte du hint soit mis en page : on la refait un instant après
	admin.get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(m):
			m._fit())
