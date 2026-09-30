class_name AdminClasses
extends RefCounted
## Onglet « Classes » : armes et sorts autorisés, progression, talents, évolutions.

const TALENT_EFFECTS := [
	["bonusForce", "Force"], ["bonusDex", "Dextérité"], ["bonusCon", "Constitution"], ["bonusInt", "Intelligence"],
	["bonusHp", "PV max"], ["bonusStamina", "Endurance max"], ["bonusAtkMin", "Dégâts min (arme)"], ["bonusAtkMax", "Dégâts max (arme)"],
	["bonusSpellDmg", "Dégâts/soin de sort"], ["critChance", "% Chances de critique"], ["lifestealPct", "% Vol de vie"],
	["resistPhys", "% Résistance physique"], ["resistMagic", "% Résistance magique"],
]

static var _talents_open: Dictionary = {}

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.config
	var head := Form.panel(host, "Classes")
	Form.hint(head, "Les classes de base (Guerrier, Archer, Roublard, Mage, Prêtre, Barde) évoluent en classes évoluées, qui dépendent d'une classe de base. Armes autorisées, sorts autorisés, progression par niveau et talents se règlent ici.")
	Form.buttons(head, [["Ajouter une classe", func(): _add_modal(admin)], ["Enregistrer", admin.save]])
	var classes: Array = cfg.get("classes", [])
	for cls in classes:
		cls["spellProgression"] = cls.get("spellProgression", [])
		cls["allowedWeaponTypes"] = cls.get("allowedWeaponTypes", [])
		cls["allowedSpellIds"] = cls.get("allowedSpellIds", [])
	head.add_child(AdminUtil.label("Classes de base", 16, UiTheme.GOLD))
	for cls in classes:
		if AdminUtil.is_base(cls):
			_card(host, admin, cls)
	var adv := Form.panel(host, "Classes évoluées")
	adv.add_child(AdminUtil.label("Chacune dépend d'une classe de base dont elle hérite les armes.", 13, UiTheme.DIM))
	for cls in classes:
		if not AdminUtil.is_base(cls):
			_card(host, admin, cls)

static func _card(host: VBoxContainer, admin: Node, cls: Dictionary) -> void:
	var cfg: Dictionary = Data.config
	var is_base := AdminUtil.is_base(cls)
	var b := Form.panel(host, str(cls.get("name", "Classe")))
	var top := AdminUtil.flow(b)
	top.add_child(IconPicker.button(admin.modals(), cls, "icon", admin.refresh_tab))
	if is_base:
		var opts: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			opts.append([n, n])
		var on_name := func(v):
			cls["name"] = v
			admin.refresh_tab()
		top.add_child(AdminUtil.dropdown(opts, cls.get("name", ""), on_name, 200.0))
	else:
		var e := LineEdit.new()
		e.text = str(cls.get("name", ""))
		e.custom_minimum_size = Vector2(200, 0)
		e.text_submitted.connect(func(t: String):
			cls["name"] = t
			admin.refresh_tab())
		e.focus_exited.connect(func(): cls["name"] = e.text)
		top.add_child(e)
		var dep: Array = []
		for n in AdminUtil.BASE_ARCHETYPES:
			dep.append([n, n])
		var on_dep := func(v):
			cls["evolvesFrom"] = v
			admin.refresh_tab()
		AdminUtil.chip(top, "Dépend de", AdminUtil.dropdown(dep, cls.get("evolvesFrom", "Guerrier"), on_dep, 160.0))
	var rm := Button.new()
	rm.text = "Supprimer"
	rm.focus_mode = Control.FOCUS_NONE
	rm.pressed.connect(func(): _remove(admin, cls))
	top.add_child(rm)

	# armes
	b.add_child(AdminUtil.label("Armes autorisées", 14, UiTheme.GOLD))
	var wf := AdminUtil.flow(b)
	for w in AdminUtil.weapon_types():
		var wid: String = w.id
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = str(w.label)
		cb.button_pressed = (cls.allowedWeaponTypes as Array).has(wid)
		cb.toggled.connect(func(on: bool):
			var arr: Array = cls.allowedWeaponTypes
			if on and not arr.has(wid):
				arr.append(wid)
			elif not on:
				arr.erase(wid))
		wf.add_child(cb)
	var base := AdminUtil.base_of(cls)
	if not base.is_empty() and not (base.get("allowedWeaponTypes", []) as Array).is_empty():
		var names: Array = []
		for wid in base.allowedWeaponTypes:
			names.append(AdminUtil.weapon_label(str(wid)))
		Form.hint(b, "Hérite aussi de %s : %s" % [base.name, ", ".join(names)])

	# sorts autorisés
	var max_sp := int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))
	b.add_child(AdminUtil.label("Sorts autorisés (attribution manuelle ou parchemin) — %d maximum" % max_sp, 14, UiTheme.GOLD))
	var sf := AdminUtil.flow(b)
	for s in cfg.get("spells", []):
		var sid: String = s.id
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.text = AdminUtil.spell_label(s)
		cb.button_pressed = (cls.allowedSpellIds as Array).has(sid)
		cb.toggled.connect(func(on: bool):
			var arr: Array = cls.allowedSpellIds
			if on:
				if arr.size() >= max_sp:
					cb.set_pressed_no_signal(false)
					admin.say("%s : %d sorts/capacités maximum par classe." % [cls.name, max_sp])
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
			var sp := Data.spell_by_id(str(sid))
			names2.append(AdminUtil.spell_label(sp) if not sp.is_empty() else str(sid))
		Form.hint(b, "Hérite aussi de %s : %s" % [base.name, ", ".join(names2)])

	# progression
	b.add_child(AdminUtil.label("Progression automatique par niveau", 14, UiTheme.GOLD))
	var prog: Array = cls.spellProgression
	if prog.is_empty():
		Form.hint(b, "Aucune progression définie : les sorts autorisés restent à attribuer manuellement ou via parchemin.")
	var pf := AdminUtil.flow(b)
	for i in prog.size():
		var p: Dictionary = prog[i]
		var s2 := Data.spell_by_id(str(p.get("spellId", "")))
		var chip := Button.new()
		chip.focus_mode = Control.FOCUS_NONE
		chip.text = "Niv. %d → %s ✕" % [int(p.level), AdminUtil.spell_label(s2) if not s2.is_empty() else "?"]
		var pidx := i
		chip.pressed.connect(func():
			prog.remove_at(pidx)
			admin.refresh_tab())
		pf.add_child(chip)
	var add_row := AdminUtil.flow(b)
	var draft := {"level": 3, "spellId": ""}
	var spell_opts: Array = []
	for s in cfg.get("spells", []):
		spell_opts.append([s.id, AdminUtil.spell_label(s)])
	if not spell_opts.is_empty():
		draft.spellId = spell_opts[0][0]
	AdminUtil.chip(add_row, "Niveau", AdminUtil.mini_number(draft, "level", 1, 60, 3))
	var on_spell := func(v): draft.spellId = v
	add_row.add_child(AdminUtil.dropdown(spell_opts, draft.spellId, on_spell, 240.0))
	var add := Button.new()
	add.text = "+ Ajouter"
	add.focus_mode = Control.FOCUS_NONE
	add.pressed.connect(func():
		var sid2 := str(draft.spellId)
		if sid2 == "":
			return
		for q in prog:
			if int(q.level) == int(draft.level) and q.spellId == sid2:
				admin.say("Cette classe apprend déjà ce sort à ce niveau.")
				return
		var allowed: Array = cls.allowedSpellIds
		if not allowed.has(sid2):
			if allowed.size() >= max_sp:
				admin.say("%s a déjà %d sorts autorisés : retirez-en un avant d'en ajouter à la progression." % [cls.name, max_sp])
				return
			allowed.append(sid2)
		prog.append({"level": int(draft.level), "spellId": sid2})
		prog.sort_custom(func(x, y): return int(x.level) < int(y.level))
		admin.refresh_tab())
	add_row.add_child(add)

	# évolution
	if is_base:
		b.add_child(AdminUtil.label("Évolution de classe", 14, UiTheme.GOLD))
		var ev := AdminUtil.flow(b)
		AdminUtil.chip(ev, "Niveau requis", AdminUtil.mini_number(cls, "evolveLevel", 1, 60, 5, admin.refresh_tab))
		var to: Array = cls.get("evolvesTo", [null, null])
		while to.size() < 2:
			to.append(null)
		cls["evolvesTo"] = to
		var cand: Array = [["", "— aucune —"]]
		for c in cfg.classes:
			if not AdminUtil.is_base(c) and str(c.get("evolvesFrom", "")) == str(cls.name):
				cand.append([c.id, "%s %s" % [c.get("icon", "") if AdminUtil.is_emoji_icon(str(c.get("icon", ""))) else "", c.name]])
		for slot in 2:
			var sl := slot
			var on_evo := func(v): to[sl] = v if v != "" else null
			ev.add_child(AdminUtil.dropdown(cand, to[sl] if to[sl] != null else "", on_evo, 220.0))
		Form.hint(b, "Voies d'évolution : classes évoluées dont la dépendance pointe vers cette classe de base.")

	# talents
	var open: bool = bool(_talents_open.get(cls.id, false))
	var tog := Button.new()
	tog.text = ("▾ Talents" if open else "▸ Talents") + " (un choix par palier)"
	tog.focus_mode = Control.FOCUS_NONE
	tog.pressed.connect(func():
		_talents_open[cls.id] = not open
		admin.refresh_tab())
	b.add_child(tog)
	if open:
		_talents(b, admin, cls)

static func _track(cls_id: String) -> Array:
	var cfg: Dictionary = Data.config
	if not (cfg.get("classTalents") is Dictionary):
		cfg["classTalents"] = {}
	var all: Dictionary = cfg.classTalents
	if not all.has(cls_id):
		if Data.class_talents.has(cls_id):
			all[cls_id] = Data.class_talents[cls_id].duplicate(true)
		else:
			var arr: Array = []
			for lvl in Data.constants.get("TALENT_LEVELS", [5, 10, 15, 20, 25]):
				var opts: Array = []
				for k in ["A", "B"]:
					opts.append({"id": "%s_lv%d_%s" % [cls_id, int(lvl), k], "icon": "⭐", "labelFr": "Talent " + k, "labelEn": "Talent " + k, "descFr": "", "descEn": "", "effects": {}})
				arr.append({"level": int(lvl), "options": opts})
			all[cls_id] = arr
	return all[cls_id]

static func _talents(b: VBoxContainer, admin: Node, cls: Dictionary) -> void:
	var tracks := _track(str(cls.id))
	var evolve_at := int(cls.get("evolveLevel", 0))
	var warn_unreachable: bool = AdminUtil.is_base(cls) and evolve_at > 0 and (cls.get("evolvesTo", []) as Array).any(func(x): return x != null and x != "")
	for tr in tracks:
		var lvl := int(tr.level)
		var unreachable: bool = warn_unreachable and lvl > evolve_at
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		if unreachable:
			box.modulate.a = 0.45
		box.add_child(AdminUtil.label("Niveau %d%s" % [lvl, ("  — inaccessible : %s évolue au niveau %d, seuls les talents de la classe évoluée comptent ensuite" % [cls.name, evolve_at]) if unreachable else ""], 14, UiTheme.GOLD if not unreachable else UiTheme.DIM))
		for opt in tr.options:
			var o: Dictionary = opt
			var line := AdminUtil.flow(box)
			line.add_child(IconPicker.button(admin.modals(), o, "icon", admin.refresh_tab, 32.0))
			for f in [["Nom FR", "labelFr", 150.0], ["Name EN", "labelEn", 150.0], ["Desc. FR", "descFr", 230.0], ["Desc. EN", "descEn", 230.0]]:
				var e := LineEdit.new()
				e.placeholder_text = f[0]
				e.text = str(o.get(f[1], ""))
				e.custom_minimum_size = Vector2(f[2], 0)
				var key: String = f[1]
				e.text_changed.connect(func(t: String): o[key] = t)
				line.add_child(e)
			var fx: Dictionary = Form.sub(o, "effects")
			var used: Array = fx.keys()
			for k in used:
				var key2: String = k
				var eo := OptionButton.new()
				eo.focus_mode = Control.FOCUS_NONE
				var sel := 0
				for i in TALENT_EFFECTS.size():
					eo.add_item(TALENT_EFFECTS[i][1])
					if TALENT_EFFECTS[i][0] == key2:
						sel = i
					elif fx.has(TALENT_EFFECTS[i][0]):
						eo.set_item_disabled(i, true)
				eo.select(sel)
				eo.item_selected.connect(func(i: int):
					var nk: String = TALENT_EFFECTS[i][0]
					if nk == key2 or fx.has(nk):
						return
					var val = fx[key2]
					fx.erase(key2)
					fx[nk] = val
					admin.refresh_tab())
				line.add_child(eo)
				var sp := SpinBox.new()
				sp.min_value = -999
				sp.max_value = 999
				sp.step = 1
				sp.value = float(fx[key2])
				sp.custom_minimum_size = Vector2(90, 0)
				sp.value_changed.connect(func(v: float): fx[key2] = int(v))
				line.add_child(sp)
				var del := Button.new()
				del.text = "✕"
				del.focus_mode = Control.FOCUS_NONE
				del.pressed.connect(func():
					fx.erase(key2)
					admin.refresh_tab())
				line.add_child(del)
			if used.size() < TALENT_EFFECTS.size():
				var plus := Button.new()
				plus.text = "+ effet"
				plus.focus_mode = Control.FOCUS_NONE
				plus.pressed.connect(func():
					for d in TALENT_EFFECTS:
						if not fx.has(d[0]):
							fx[d[0]] = 1
							break
					admin.refresh_tab())
				line.add_child(plus)
		b.add_child(box)

static func _remove(admin: Node, cls: Dictionary) -> void:
	var classes: Array = Data.config.classes
	if classes.size() <= 1:
		Dialogs.notice(admin.modals(), "Suppression impossible", "Il doit rester au moins une classe.")
		return
	var go := func():
		classes.erase(cls)
		var fallback: String = str(classes[0].id)
		for p in Data.config.get("party", []):
			if p.get("classId") == cls.get("id"):
				p["classId"] = fallback
				p["spellsKnown"] = []
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "Supprimer la classe", "Supprimer la classe %s ?" % cls.name, go, "Supprimer")

static func _add_modal(admin: Node) -> void:
	var m := Modal.open(admin.modals(), "Ajouter une classe", 440.0)
	var st := {"type": "base", "dep": "Guerrier"}
	m.content.add_child(AdminUtil.dropdown([["base", "Classe de base"], ["advanced", "Classe évoluée"]], "base", func(v): st.type = v))
	var deps: Array = []
	for n in AdminUtil.BASE_ARCHETYPES:
		deps.append([n, n])
	m.add_text("Pour une classe évoluée : classe de base dont elle dépend", UiTheme.DIM, 13)
	m.content.add_child(AdminUtil.dropdown(deps, "Guerrier", func(v): st.dep = v))
	var go := func():
		var cls: Dictionary
		if st.type == "base":
			cls = {"id": AdminUtil.new_id("class"), "name": "Guerrier", "icon": "🧝", "baseSpeed": 8, "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": [], "evolvesTo": [null, null], "evolveLevel": 5}
		else:
			cls = {"id": AdminUtil.new_id("class"), "name": "Nouvelle évolution", "icon": "🧝", "baseSpeed": 8, "evolvesFrom": st.dep, "allowedWeaponTypes": [], "allowedSpellIds": [], "spellProgression": []}
		Data.config.classes.append(cls)
		m.close()
		admin.refresh_tab()
	m.set_buttons([{"text": "Ajouter", "cb": go}, {"text": "Annuler", "cb": func(): m.close()}])
