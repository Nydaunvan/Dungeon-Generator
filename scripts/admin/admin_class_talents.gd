class_name AdminClassTalents
extends RefCounted
## Section « 🌟 Talents » d'une carte de classe (onglet Classes) : un cadre par palier de niveau, deux options par palier
## (icône, noms/descriptions FR/EN, effets chiffrés). Portage de ensureClassTalentTrack / talentTracksHtml / talentEffectRowsHtml.

## [clé d'effet, libellé FR, libellé EN] (TALENT_EFFECT_DEFS de l'original).
const EFFECT_DEFS := [
	["bonusForce", "Force", "Strength"], ["bonusDex", "Dextérité", "Dexterity"], ["bonusCon", "Constitution", "Constitution"],
	["bonusInt", "Intelligence", "Intelligence"], ["bonusHp", "PV max", "Max HP"], ["bonusStamina", "Endurance max", "Max stamina"],
	["bonusAtkMin", "Dégâts min (arme)", "Min damage (weapon)"], ["bonusAtkMax", "Dégâts max (arme)", "Max damage (weapon)"],
	["bonusSpellDmg", "Dégâts/soin de sort", "Spell power"], ["critChance", "% Chances de critique", "% Crit chance"],
	["lifestealPct", "% Vol de vie", "% Lifesteal"], ["resistPhys", "% Résistance physique", "% Physical resistance"],
	["resistMagic", "% Résistance magique", "% Magic resistance"],
]

static func levels() -> Array:
	return Data.constants.get("TALENT_LEVELS", [5, 10, 15, 20, 25])

## `ensureClassTalentTrack` : crée (depuis les talents par défaut ou un squelette « Talent A/B ») les paliers de la classe.
static func ensure_track(cfg: Dictionary, cls_id: String) -> Array:
	if not (cfg.get("classTalents") is Dictionary):
		cfg["classTalents"] = {}
	var all: Dictionary = cfg.classTalents
	if not all.has(cls_id):
		if Data.class_talents.has(cls_id):
			all[cls_id] = (Data.class_talents[cls_id] as Array).duplicate(true)
		else:
			var arr: Array = []
			for lvl in levels():
				var opts: Array = []
				for k in ["A", "B"]:
					opts.append({"id": "%s_lv%d_%s" % [cls_id, int(lvl), k], "icon": "⭐", "labelFr": "Talent " + k, "labelEn": "Talent " + k, "descFr": "", "descEn": "", "effects": {}})
				arr.append({"level": int(lvl), "options": opts})
			all[cls_id] = arr
	return all[cls_id]

## Garantit un palier pour CHAQUE classe : sans cela `Talents.source` (qui préfère cfg.classTalents s'il n'est pas vide)
## ferait disparaître les talents des classes absentes du dictionnaire.
static func ensure_all(cfg: Dictionary) -> void:
	for cls in cfg.get("classes", []):
		ensure_track(cfg, str(cls.get("id", "")))

static func effect_label(key: String) -> String:
	for d in EFFECT_DEFS:
		if d[0] == key:
			return str(d[2]) if Data.lang == "en" else str(d[1])
	return key

static func _block(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for ch in n.get_children():
		_block(ch)

static func _rich(bb: String, rem: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 120.0
	r.add_theme_font_size_override("normal_font_size", AdminChars.fpx(rem))
	r.add_theme_font_size_override("bold_font_size", AdminChars.fpx(rem))
	r.add_theme_color_override("default_color", AdminChars.GOLD_DIM)
	r.text = bb
	return r

## Dessine la section (libellé + un cadre par palier) dans `parent` (la carte de la classe).
static func section(parent: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(AdminChars.cpx(6.0)))
	parent.add_child(box)
	box.add_child(AdminChars.csection_label("🌟 Talents (choix à un palier de niveau, un par personnage de cette classe)"))
	var tracks := ensure_track(cfg, str(cls.id))
	var evolve_at := int(cls.get("evolveLevel", 0))
	var evo_to: Array = cls.get("evolvesTo", [])
	var base_with_evo: bool = AdminUtil.is_base(cls) and evo_to.any(func(x): return x != null and x != "") and evolve_at != 0
	for lvl in levels():
		var track: Dictionary = {}
		for t in tracks:
			if int(t.get("level", 0)) == int(lvl):
				track = t
		if track.is_empty():
			continue
		var unreachable: bool = base_with_evo and int(lvl) > evolve_at
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = AdminChars.BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = AdminChars.cpx(8.0)
		sb.content_margin_right = AdminChars.cpx(8.0)
		sb.content_margin_top = AdminChars.cpx(6.0)
		sb.content_margin_bottom = AdminChars.cpx(6.0)
		frame.add_theme_stylebox_override("panel", sb)
		if unreachable:
			frame.modulate.a = 0.4
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", int(AdminChars.cpx(3.0)))
		frame.add_child(v)
		var title := AdminChars.T("Niveau %d") % int(lvl)
		var bb := "[color=#a9793a]%s[/color]" % title
		if unreachable:
			var warn := AdminChars.T("— ⚠️ inaccessible : %s évolue au niveau %d, seuls les talents de la classe évoluée compteront à partir de là") % [str(cls.get("name", "")), evolve_at]
			bb += " [color=#ffd88a]%s[/color]" % warn.replace("[", "[lb]")
		v.add_child(_rich(bb, 0.68))
		var opts_box := VBoxContainer.new()
		opts_box.add_theme_constant_override("separation", int(AdminChars.cpx(4.0)))
		v.add_child(opts_box)
		for o in track.get("options", []):
			_option_row(opts_box, admin, o)
		if unreachable:
			_block(opts_box)
		box.add_child(frame)

static func _option_row(parent: Control, admin: Node, o: Dictionary) -> void:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = AdminChars.cpx(6.0)
	sb.content_margin_right = AdminChars.cpx(6.0)
	sb.content_margin_top = AdminChars.cpx(4.0)
	sb.content_margin_bottom = AdminChars.cpx(4.0)
	row.add_theme_stylebox_override("panel", sb)
	parent.add_child(row)
	var f := AdminChars.flow(row, 4.0, 4.0)
	f.add_child(AdminChars.icon_btn(admin, o, "icon", admin.refresh_tab))
	for spec in [["Nom FR", "labelFr", 80.0, 0.66], ["Name EN", "labelEn", 80.0, 0.66], ["Desc. FR", "descFr", 100.0, 0.62], ["Desc. EN", "descEn", 100.0, 0.62]]:
		var key: String = spec[1]
		var e := AdminChars.line_edit(str(o.get(key, "")), float(spec[2]), float(spec[3]), 4.0, 2.0, str(spec[0]))
		e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		e.text_changed.connect(func(t: String): o[key] = t)
		f.add_child(e)
	var fx: Dictionary = Form.sub(o, "effects")
	var used: Array = fx.keys()
	var defs: Array = []
	for d in EFFECT_DEFS:
		defs.append([d[0], effect_label(str(d[0]))])
	for k in used:
		var key2: String = str(k)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(AdminChars.cpx(2.0)))
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var others: Array = used.filter(func(u): return u != k)
		var on_key := func(nk):
			if nk == key2:
				return
			if fx.has(nk):
				admin.refresh_tab()   # déjà utilisé sur une autre ligne : on réaffiche l'ancienne valeur
				return
			var val = fx[key2]
			fx.erase(key2)
			fx[nk] = val
			admin.refresh_tab()
		h.add_child(AdminChars.select(defs, key2, on_key, 90.0, 0.62, 2.0, 2.0, false, others))
		var on_val := func(val):
			fx[key2] = val
			return val
		h.add_child(AdminChars.num_edit(fx[key2], 42.0, 0.65, on_val, 2.0, 2.0, false, "Valeur libre, positive ou négative"))
		var del := AdminChars.small_btn("🗑", 0.65, 4.0, 1.0, "Retirer cet effet")
		del.pressed.connect(func():
			fx.erase(key2)
			admin.refresh_tab())
		h.add_child(del)
		f.add_child(h)
	if used.size() < EFFECT_DEFS.size():
		var plus := AdminChars.small_btn("+", 0.65, 6.0, 2.0, "Ajouter un effet")
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(func():
			for d in EFFECT_DEFS:
				if not fx.has(d[0]):
					fx[d[0]] = 1
					break
			admin.refresh_tab())
		f.add_child(plus)
