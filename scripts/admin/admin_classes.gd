class_name AdminClasses
extends RefCounted
## Écran « Classes et talents » (maquette « Classes ») : liste des classes à gauche (300 px), fiche à droite avec onglets soulignés
## (Général, Armes et sorts, Progression, Talents, Évolution). Portage de renderClassTable et de ses fonctions d'édition.

## Classe affichée dans la fiche (identifiant) et onglet courant ("general", "spells", "prog", "talents", "evo").
static var _csel := ""
static var _ctab := "general"

static func T(s: String) -> String:
	return AdminChars.T(s)

static func _max_sp() -> int:
	return int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))

## Enregistre puis reconstruit la page.
static func _rt(admin: Node) -> void:
	Ax.changed()
	admin.refresh_tab()

static func build(host: Control, admin: Node) -> void:
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
	if narrow:
		var page := Ax.scroll_page(host, admin, 16, 18, 16)
		page.add_child(_list(admin, cfg, classes, true))
		_sheet(page, admin, cfg, sel, true)
		return
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	host.add_child(root)
	root.add_child(_list(admin, cfg, classes, false))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(sc)
	admin.set("_scroll", sc)
	var col := Ax.vbox(20)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := Ax.margin(col, 36, 28, 36, 28)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(m)
	_sheet(col, admin, cfg, sel, false)

# ------------------------------------------------------------------ liste

## Liste des classes (de base, puis évoluées) avec le bouton « Nouvelle ».
static func _list(admin: Node, cfg: Dictionary, classes: Array, narrow: bool) -> Control:
	var s := Ax.sb(Color(0.063, 0.047, 0.031, 0.55), Ax.CLEAR, 0, 0, 16, 24)
	if not narrow:
		s.border_width_right = 1
		s.border_color = Ax.LINE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", s)
	if narrow:
		panel.add_theme_stylebox_override("panel", Ax.sb(Ax.CARD, Ax.LINE2, 16, 1, 16, 16))
	else:
		panel.custom_minimum_size.x = 300
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var outer := Ax.vbox(14)
	panel.add_child(outer)
	var top := Ax.hbox(8)
	top.add_child(Ax.margin(Ax.title(L.t("ui.atelier.c_classes"), 20), 4, 0, 0, 0))
	top.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(Ax.btn("+ " + L.t("ui.atelier.c_new"), func(): _add_modal(admin, cfg), "gold", 34.0, 12, 13))
	outer.add_child(top)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL if not narrow else Control.SIZE_FILL
	outer.add_child(sc)
	var col := Ax.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	for grp in [[L.t("admin.classes.classes_de_base"), true], [L.t("admin.classes.classes_evoluees"), false]]:
		var g := Ax.vbox(4)
		g.add_child(Ax.margin(Ax.kicker(AdminItems._plain(str(grp[0])), 11), 6, 0, 0, 4))
		var any := false
		for c in classes:
			if AdminUtil.is_base(c) == grp[1]:
				any = true
				g.add_child(_class_row(admin, c, str(c.get("id", "")) == _csel))
		if any:
			col.add_child(g)
	return panel

static func _class_row(admin: Node, c: Dictionary, on: bool) -> Control:
	var p := Ax.panel(Color(0.91, 0.706, 0.361, 0.12) if on else Ax.CLEAR, Ax.GOLD if on else Ax.CLEAR, 12, 10, 8)
	var h := Ax.hbox(12)
	p.add_child(h)
	var av := Ax.panel(Ax.GOLD if on else Color("241a0e"), Ax.CLEAR, 10, 0, 0, 0)
	av.custom_minimum_size = Vector2(36, 36)
	var ini := Ax.title(str(c.get("name", "?")).substr(0, 1).to_upper(), 16, Color("2a1a06") if on else Ax.MUTED)
	ini.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ini.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(ini)
	h.add_child(av)
	var v := Ax.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var n := Ax.lab(str(c.get("name", "")), 14, Ax.CREAM, 600)
	n.clip_text = true
	v.add_child(n)
	var meta: String
	if AdminUtil.is_base(c):
		meta = L.fa(L.t("ui.atelier.c_spells_n"), (c.get("allowedSpellIds", []) as Array).size())
	else:
		meta = L.fa(L.t("ui.atelier.c_depuis"), str(c.get("evolvesFrom", "")))
	var m := Ax.lab(meta, 12, Ax.MUTED)
	m.clip_text = true
	v.add_child(m)
	h.add_child(v)
	Ax.clickable(p, func():
		Ax.flush()
		_csel = str(c.get("id", ""))
		_ctab = "general"
		AdminClassTalents._open = ""
		admin.refresh_tab())
	return p

# ------------------------------------------------------------------ fiche

## Fiche de la classe choisie : en-tête, onglets, contenu de l'onglet.
static func _sheet(col: Control, admin: Node, cfg: Dictionary, cls: Dictionary, narrow: bool) -> void:
	var is_base := AdminUtil.is_base(cls)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 18)
	head.add_theme_constant_override("v_separation", 12)
	col.add_child(head)
	var hl := Ax.hbox(18)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	hl.add_child(IconPicker.button(admin.modals(), cls, "icon", func(): _rt(admin), 64.0))
	var hv := Ax.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hl.add_child(hv)
	hv.add_child(Ax.title(str(cls.get("name", "")), 30 if not narrow else 24))
	var sub: String
	if is_base:
		sub = L.t("ui.atelier.c_base")
		var evo := _evo_names(cfg, cls)
		if evo != "":
			sub += " · " + L.fa(L.t("ui.atelier.c_evolves"), [evo, int(cls.get("evolveLevel", 0))])
	else:
		sub = L.fa(L.t("ui.atelier.c_advanced"), str(cls.get("evolvesFrom", "")))
	hv.add_child(Ax.lab(sub, 13, Ax.MUTED))
	var hb := Ax.hbox(10)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(Ax.btn(L.t("ui.atelier.c_dup"), func(): _duplicate(admin, cfg, cls), "ghost", 40.0))
	hb.add_child(Ax.btn(L.t("ui.atelier.c_delete"), func(): _remove(admin, cfg, cls), "danger", 40.0))
	head.add_child(hb)
	col.add_child(Ax.tabs([["general", L.t("ui.atelier.c_t_general")], ["spells", L.t("ui.atelier.c_t_spells")], ["prog", L.t("ui.atelier.c_t_prog")],
		["talents", L.t("ui.atelier.c_t_talents")], ["evo", L.t("ui.atelier.c_t_evo")]], _ctab, func(id: String):
			Ax.flush()
			_ctab = id
			admin.refresh_tab(), 42.0, 14, 18))
	var b := Ax.vbox(14)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(b)
	match _ctab:
		"spells": _tab_spells(b, admin, cfg, cls)
		"prog": _progression(b, admin, cfg, cls)
		"talents": AdminClassTalents.section(b, admin, cfg, cls)
		"evo": _tab_evo(b, admin, cfg, cls, is_base)
		_: _tab_general(b, admin, cls, is_base)

## Noms des deux évolutions d'une classe de base (« Paladin ou Berserker »).
static func _evo_names(cfg: Dictionary, cls: Dictionary) -> String:
	var names: Array = []
	for id in cls.get("evolvesTo", []):
		if id != null and str(id) != "":
			var c := AdminChars.class_by_id(cfg, str(id))
			if c.get("id", "") != "":
				names.append(str(c.name))
	return L.t("ui.atelier.c_or_sep").join(names)

## Carte de contenu d'un onglet.
static func _card(parent: Control, title_text: String, hint: String = "") -> VBoxContainer:
	return Ax.card(parent, title_text, hint, 20, 14)

static func _tab_general(b: Control, admin: Node, cls: Dictionary, is_base: bool) -> void:
	var c := _card(b, L.t("ui.atelier.c_g_name"))
	var g := Ax.grid2(c, 16)
	if is_base:
		var opts: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			opts.append([n, n])
		g.add_child(Ax.labeled(L.t("common.nom"), Ax.select(opts, cls.get("name", ""), func(v):
			cls["name"] = v
			_rt(admin))))
	else:
		var e := Ax.field(str(cls.get("name", "")), Callable(), 40.0)
		e.text_changed.connect(func(t: String):
			cls["name"] = t
			Ax.changed())
		AdminChars.on_commit(e, func(_t: String): _rt(admin))
		g.add_child(Ax.labeled(L.t("common.nom"), e))
	g.add_child(Ax.num(cls, "baseSpeed", 10, 1, 40, L.t("admin.classes.vitesse")))
	c.add_child(Ax.para(L.t("admin.classes.vitesse_aide"), 12, Ax.MUTED))

## Armes et sorts autorisés.
static func _tab_spells(b: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var base := AdminChars.base_of(cfg, cls)
	var wc := _card(b, L.t("admin.classes.armes_autorisees"))
	var wf := HFlowContainer.new()
	wf.add_theme_constant_override("h_separation", 8)
	wf.add_theme_constant_override("v_separation", 8)
	wc.add_child(wf)
	for w in AdminUtil.weapon_types():
		var wid: String = w.id
		var on: bool = (cls.allowedWeaponTypes as Array).has(wid)
		var pill := Ax.pill(str(w.label), on, Callable(), Ax.GOLD, 34.0, 13, 13)
		pill.pressed.connect(func():
			var arr: Array = cls.allowedWeaponTypes
			if arr.has(wid):
				arr.erase(wid)
			else:
				arr.append(wid)
			Ax.pill_set(pill, arr.has(wid))
			Ax.changed())
		wf.add_child(pill)
	if not base.is_empty() and not (base.get("allowedWeaponTypes", []) as Array).is_empty():
		var names: Array = []
		for wid in base.allowedWeaponTypes:
			names.append(AdminUtil.weapon_label(str(wid)))
		wc.add_child(_inherit_note(str(base.name), names))
	var max_sp := _max_sp()
	var sc := _card(b, L.t("admin.classes.sorts_autorises_via_attribution"))
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		sc.add_child(Ax.para(L.t("common.aucun_sort_defini"), 13, Ax.MUTED))
	else:
		var counter := Ax.lab(L.fa(L.t("ui.atelier.c_inherit_n"), [(cls.allowedSpellIds as Array).size(), max_sp]), 12, Ax.GOLD_L, 600)
		sc.add_child(counter)
		sc.move_child(counter, 1)
		var sf := HFlowContainer.new()
		sf.add_theme_constant_override("h_separation", 8)
		sf.add_theme_constant_override("v_separation", 8)
		sc.add_child(sf)
		for s in spells:
			if bool(s.get("ultimate", false)):
				continue          # les techniques ultimes ont leur propre carte (« Technique ultime »)
			var sid: String = s.id
			var pill := Ax.pill(AdminUtil.spell_label(s), (cls.allowedSpellIds as Array).has(sid), Callable(), Ax.GOLD, 34.0, 13, 13)
			pill.pressed.connect(func():
				var arr: Array = cls.allowedSpellIds
				if arr.has(sid):
					arr.erase(sid)
					for p in cfg.get("party", []):
						if p.get("classId") == cls.get("id"):
							(p.get("spellsKnown", []) as Array).erase(sid)
				else:
					if arr.size() >= max_sp:
						AdminChars.alert(admin, L.fa(T(L.t("admin.classes.sorts_capacites_maximum_autorises")), [str(cls.get("name", "")), max_sp]))
						return
					arr.append(sid)
				Ax.pill_set(pill, arr.has(sid))
				counter.text = L.fa(L.t("ui.atelier.c_inherit_n"), [arr.size(), max_sp])
				Ax.changed())
			sf.add_child(pill)
	_ultimate_card(b, admin, cfg, cls)
	if not base.is_empty() and not (base.get("allowedSpellIds", []) as Array).is_empty():
		var names2: Array = []
		for sid in base.allowedSpellIds:
			var sp := AdminChars.spell_by_id(cfg, str(sid))
			names2.append(AdminUtil.spell_label(sp) if not sp.is_empty() else str(sid))
		sc.add_child(_inherit_note(str(base.name), names2))

## Carte « Technique ultime (7e sort) » : choix du sort ultime de la classe (réservé aux sorts marqués « technique ultime » dans l'onglet Sorts).
static func _ultimate_card(b: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var uc := _card(b, L.t("admin.classes.ultime_titre"))
	var opts: Array = [["", L.t("common.aucun")]]
	for s in cfg.get("spells", []):
		if bool(s.get("ultimate", false)):
			opts.append([str(s.id), AdminUtil.spell_label(s)])
	uc.add_child(Ax.para(L.t("admin.classes.ultime_aide"), 12, Ax.MUTED))
	uc.add_child(Ax.select(opts, str(cls.get("ultimateSpellId", "")), func(v):
		cls["ultimateSpellId"] = str(v)
		Ax.changed(), 40.0, 14))

## Note « 🔗 Hérite aussi de **base** : … » (nom de la base en gras).
static func _inherit_note(base_name: String, items: Array) -> Control:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 120.0
	for k in ["normal_font_size", "bold_font_size"]:
		r.add_theme_font_size_override(k, 12)
	r.add_theme_font_override("normal_font", Ax.inter(400))
	r.add_theme_font_override("bold_font", Ax.inter(600))
	r.add_theme_color_override("default_color", Ax.MUTED)
	var esc := func(s: String) -> String: return s.replace("[", "[lb]")
	r.text = L.fa(T(L.t("admin.classes.herite_aussi_de")), ["[b]%s[/b]" % esc.call(L.c(base_name)), esc.call(", ".join(items.map(func(x): return L.c(str(x)))))])
	return r

## Évolution : classe de base = niveau requis et deux voies ; classe évoluée = classe dont elle dépend.
static func _tab_evo(b: Control, admin: Node, cfg: Dictionary, cls: Dictionary, is_base: bool) -> void:
	if is_base:
		_evolution(b, admin, cfg, cls)
		return
	var c := _card(b, L.t("admin.classes.depend_de_la_classe_de"), L.t("admin.classes.une_classe_evoluee_n_est"))
	var dep: Array = []
	for n in AdminUtil.BASE_ARCHETYPES:
		dep.append([n, n])
	var sel := Ax.select(dep, cls.get("evolvesFrom", ""), func(v):
		cls["evolvesFrom"] = v
		_rt(admin))
	sel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sel.custom_minimum_size.x = 260
	c.add_child(sel)

static func _progression(b: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var c := _card(b, L.t("admin.classes.progression_automatique_par_niveau"), L.t("ui.atelier.c_prog_hint"))
	var prog: Array = cls.spellProgression
	if prog.is_empty():
		c.add_child(Ax.para(L.t("admin.classes.aucune_progression_definie_les"), 13, Ax.MUTED))
	else:
		var pf := HFlowContainer.new()
		pf.add_theme_constant_override("h_separation", 8)
		pf.add_theme_constant_override("v_separation", 8)
		c.add_child(pf)
		for i in prog.size():
			var p: Dictionary = prog[i]
			var s2 := AdminChars.spell_by_id(cfg, str(p.get("spellId", "")))
			var pidx := i
			pf.add_child(_chip(L.fa(T(L.t("admin.classes.niv")), [AdminChars.num_text(p.get("level", 1)), AdminUtil.spell_label(s2) if not s2.is_empty() else "?"]), func():
				prog.remove_at(pidx)
				_rt(admin)))
	c.add_child(Ax.line())
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	c.add_child(row)
	var st := {"lvl": 3.0, "spell": ""}
	var lvl := Ax.stepper(3.0, 1.0, 99.0, 1.0, func(v: float): st.lvl = v, 40.0)
	lvl.tooltip_text = L.t("common.niveau_2")
	lvl.custom_minimum_size.x = 110
	row.add_child(lvl)
	var spell_opts: Array = []
	var spells: Array = cfg.get("spells", [])
	if spells.is_empty():
		spell_opts.append(["", L.t("common.aucun_sort_defini_2")])
	for s in spells:
		if not bool(s.get("ultimate", false)):
			spell_opts.append([s.id, AdminUtil.spell_label(s)])
	st.spell = str(spell_opts[0][0])
	var spell_sel := Ax.select(spell_opts, st.spell, func(v): st.spell = str(v))
	spell_sel.custom_minimum_size.x = 220
	row.add_child(spell_sel)
	row.add_child(Ax.btn(L.t("admin.classes.ajouter"), func():
		var level: float = maxf(1.0, float(st.lvl))
		var level_v: Variant = Ax.num_value(level)
		var sid2 := str(st.spell)
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
		_rt(admin), "gold", 40.0))

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

## Pastille « Niv. 3 · Sort » avec sa croix.
static func _chip(text: String, on_remove: Callable) -> Control:
	var h := Ax.hbox(6)
	h.add_child(Ax.lab(text, 13, Ax.TEXT))
	var x := Ax.icon_btn("close", on_remove, 22.0, Ax.MUTED, "flat")
	h.add_child(x)
	var p := Ax.panel(Color("241a0e"), Ax.LINE2, 14, 12, 5)
	p.add_child(h)
	return p

static func _evolution(b: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var c := _card(b, L.t("admin.classes.evolution_de_classe"), L.t("admin.classes.voies_evolution_classes_evoluees"))
	var g := Ax.grid2(c, 16)
	g.add_child(Ax.labeled(L.t("admin.classes.niveau_requis"), Ax.stepper(float(cls.get("evolveLevel", 0)), 0.0, 99.0, 1.0, func(v: float):
		cls["evolveLevel"] = int(v)
		Ax.changed()
		admin.refresh_tab(), 40.0)))
	var to: Array = cls.evolvesTo
	var cand: Array = [["", L.t("common.aucune")]]
	for cc in cfg.get("classes", []):
		if cc.get("id") != cls.get("id") and not AdminUtil.is_base(cc) and str(cc.get("evolvesFrom", "")) == str(cls.get("name", "")):
			cand.append([cc.id, "%s %s" % [AdminUtil.icon_text_fallback(str(cc.get("icon", ""))), cc.name]])
	for slot in 2:
		var sl := slot
		var cur = to[sl] if to[sl] != null else ""
		g.add_child(Ax.labeled(L.fa(L.t("ui.atelier.c_way"), sl + 1), Ax.select(cand, cur, func(v):
			to[sl] = v if v != "" else null
			Ax.changed())))

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
		_csel = ""
		_rt(admin)
	Dialogs.confirm(admin.modals(), "", L.fa(L.t("admin.classes.supprimer_la_classe"), str(cls.get("name", ""))), go)

## Copie la classe (nouvel identifiant, « (copie) » ajouté au nom d'une classe évoluée) avec sa progression et ses talents.
static func _duplicate(admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var cp: Dictionary = cls.duplicate(true)
	cp["id"] = AdminUtil.new_id("class")
	if not AdminUtil.is_base(cls):
		cp["name"] = L.fa(L.t("ui.atelier.c_copy"), str(cls.get("name", "")))
	cp["evolvesTo"] = [null, null]
	cfg.classes.append(cp)
	var all: Dictionary = cfg.get("classTalents", {})
	if all.has(str(cls.get("id", ""))):
		var tr: Array = (all[str(cls.id)] as Array).duplicate(true)
		for t in tr:
			for o in t.get("options", []):
				o["id"] = "%s_lv%d_%s" % [cp.id, int(t.get("level", 0)), "A" if (t.options as Array).find(o) == 0 else "B"]
		all[str(cp.id)] = tr
	_csel = str(cp.id)
	_ctab = "general"
	_rt(admin)

## Fenêtre « Nouvelle classe » (type, dépendance), puis création.
static func _add_modal(admin: Node, cfg: Dictionary) -> void:
	var m := AxModal.open(admin.modals(), L.t("admin.classes.nouvelle_classe"), "", 400.0)
	var st := {"type": "base", "dep": "Guerrier"}
	var dep_opts: Array = []
	for n in AdminUtil.BASE_ARCHETYPES:
		dep_opts.append([n, n])
	var dep_row := Ax.labeled(L.t("admin.classes.depend_de"), Ax.select(dep_opts, "Guerrier", func(v): st.dep = v))
	dep_row.visible = false
	m.body.add_child(Ax.labeled(L.t("admin.classes.type"), Ax.select([["base", L.t("admin.classes.classe_de_base")], ["advanced", L.t("admin.classes.classe_evoluee")]], "base", func(v):
		st.type = v
		dep_row.visible = v == "advanced")))
	m.body.add_child(dep_row)
	m.body.add_child(Ax.para(L.t("admin.classes.une_classe_evoluee_n_est"), 12, Ax.MUTED))
	m.set_buttons([{"text": L.t("common.annuler")}, {"text": L.t("admin.classes.creer"), "primary": true, "cb": func():
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
		_rt(admin)}])
