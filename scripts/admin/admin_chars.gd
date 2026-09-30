class_name AdminChars
extends RefCounted
## Onglet « Personnages » : groupe de départ (portrait, icône, nom, classe, statistiques, équipement, sorts connus).

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.config
	var save: Callable = admin.save
	# nettoyage : sorts connus non autorisés par la classe ou appris automatiquement plus tard
	for p in cfg.get("party", []):
		var cls := Data.class_by_id(str(p.get("classId", "")))
		var allowed: Array = AdminUtil.eff_spells(cls)
		var keep: Array = []
		for sid in p.get("spellsKnown", []):
			if allowed.has(sid) and AdminUtil.locked_level(cls, str(sid)) == 0:
				keep.append(sid)
		p["spellsKnown"] = keep
	var intro := Form.panel(host, "Personnages de départ")
	Form.hint(intro, "Le groupe qui démarre l'aventure. Les sorts marqués d'un cadenas s'apprennent automatiquement à un niveau donné (progression de la classe) et ne peuvent pas être attribués au départ. Maximum %d sorts par personnage." % int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6)))
	Form.buttons(intro, [["Enregistrer", save]])
	for idx in (cfg.get("party", []) as Array).size():
		_card(host, admin, idx)

static func _card(host: VBoxContainer, admin: Node, idx: int) -> void:
	var cfg: Dictionary = Data.config
	var c: Dictionary = cfg.party[idx]
	var body := Form.panel(host, "%s" % c.get("name", "Personnage"))
	var top := AdminUtil.flow(body)
	# portrait
	var pb := Button.new()
	pb.focus_mode = Control.FOCUS_NONE
	pb.tooltip_text = "Portrait"
	_set_portrait(pb, c)
	pb.pressed.connect(func():
		IconPicker.open_portrait(admin.modals(), str(c.get("portrait", "")), func(v: String):
			if v == "":
				c.erase("portrait")
			else:
				c["portrait"] = v
			_set_portrait(pb, c)))
	AdminUtil.chip(top, "Portrait", pb)
	AdminUtil.chip(top, "Icône", IconPicker.button(admin.modals(), c, "icon"))
	var name_edit := LineEdit.new()
	name_edit.text = str(c.get("name", ""))
	name_edit.custom_minimum_size = Vector2(170, 0)
	name_edit.text_changed.connect(func(t: String): c["name"] = t)
	AdminUtil.chip(top, "Nom", name_edit)
	# classe (classes de base ; la classe évoluée actuelle reste listée)
	var opts: Array = []
	var cur := Data.class_by_id(str(c.get("classId", "")))
	if not cur.is_empty() and not AdminUtil.is_base(cur):
		opts.append([cur.id, "%s (évoluée en jeu)" % cur.name])
	for cl in cfg.classes:
		if AdminUtil.is_base(cl):
			opts.append([cl.id, cl.name])
	var on_class := func(v):
		c["classId"] = v
		var allowed: Array = AdminUtil.eff_spells(Data.class_by_id(str(v)))
		var keep: Array = []
		for sid in c.get("spellsKnown", []):
			if allowed.has(sid):
				keep.append(sid)
		c["spellsKnown"] = keep
		admin.refresh_tab()
	AdminUtil.chip(top, "Classe", AdminUtil.dropdown(opts, c.get("classId", ""), on_class, 200.0))

	var stats := AdminUtil.flow(body)
	var preview := AdminUtil.label("", 14, UiTheme.DIM)
	var upd := func():
		var hp := 10 + int(c.get("con", 10)) * 3
		var amin := int(floor(int(c.get("force", 10)) / 3.0))
		var amax := amin + 2 + int(floor(int(c.get("dex", 10)) / 4.0))
		preview.text = "Niv. 1 : PV %d · Attaque %d-%d" % [hp, amin, amax]
	for st in [["Force", "force"], ["Dextérité", "dex"], ["Constitution", "con"], ["Intelligence", "int"]]:
		AdminUtil.chip(stats, st[0], AdminUtil.mini_number(c, st[1], 1, 100, 10, upd))
	AdminUtil.chip(stats, "Endurance max", AdminUtil.mini_number(c, "maxStamina", 1, 205, 100))
	stats.add_child(preview)
	upd.call()

	# équipement de départ
	body.add_child(AdminUtil.label("Équipement de départ", 14, UiTheme.GOLD))
	var eq := AdminUtil.flow(body)
	var se := Form.sub(c, "startEquipment")
	var weapons := AdminUtil.eff_weapons(cur)
	for slot in Data.constants.get("SLOT_TYPES", []):
		var sid: String = slot.id
		var options: Array = [["", "— aucun —"]]
		for it in cfg.get("itemLibrary", []):
			var ok := false
			if sid == "weapon":
				ok = it.get("type") == "weapon" and weapons.has(it.get("weaponType"))
			elif sid == "accessory":
				ok = it.get("type") == "jewelry"
			else:
				ok = it.get("type") == "armor" and it.get("slot") == sid
			if ok:
				options.append([it.id, AdminUtil.item_label(it)])
		AdminUtil.chip(eq, str(slot.label), AdminUtil.dropdown(options, se.get(sid, ""), func(v): se[sid] = v, 190.0))

	# sorts connus
	body.add_child(AdminUtil.label("Sorts et compétences connus au départ", 14, UiTheme.GOLD))
	var spells_flow := AdminUtil.flow(body)
	var eff: Array = AdminUtil.eff_spells(cur)
	if eff.is_empty():
		spells_flow.add_child(AdminUtil.label("Cette classe n'a aucun sort autorisé.", 13, UiTheme.DIM))
	var max_sp := int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))
	for sid in eff:
		var s := Data.spell_by_id(str(sid))
		if s.is_empty():
			continue
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		var lock := AdminUtil.locked_level(cur, str(sid))
		if lock > 0:
			cb.text = "🔒 %s (niv. %d)" % [AdminUtil.spell_label(s), lock]
			cb.disabled = true
			cb.modulate.a = 0.55
			cb.tooltip_text = "S'apprend automatiquement au niveau %d (progression de la classe)." % lock
		else:
			cb.text = AdminUtil.spell_label(s)
			cb.button_pressed = (c.get("spellsKnown", []) as Array).has(sid)
			var spell_id: String = str(sid)
			cb.toggled.connect(func(on: bool):
				var known: Array = c.get("spellsKnown", [])
				if on:
					if known.size() >= max_sp:
						cb.set_pressed_no_signal(false)
						admin.say("%s : %d compétences maximum par personnage." % [c.get("name", ""), max_sp])
						return
					if not known.has(spell_id):
						known.append(spell_id)
				else:
					known.erase(spell_id)
				c["spellsKnown"] = known)
		spells_flow.add_child(cb)

static func _set_portrait(b: Button, c: Dictionary) -> void:
	var path := IconResolver.portrait_path(c, Data.config)
	b.icon = load(path) if path != "" else null
	b.expand_icon = true
	b.custom_minimum_size = Vector2(72, 72)
	b.add_theme_constant_override("icon_max_width", 64)
