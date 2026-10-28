class_name AdminClassTalents
extends RefCounted
## Section « 🌟 Talents » d'une carte de classe (onglet Classes) : un cadre par palier de niveau, deux options par palier
## (icône, noms/descriptions FR/EN, effets chiffrés). Portage de ensureClassTalentTrack / talentTracksHtml / talentEffectRowsHtml.

## [clé d'effet, libellé FR, libellé EN] (TALENT_EFFECT_DEFS de l'original).
const EFFECT_DEFS := [
	["bonusForce", "common.force", "Strength"], ["bonusDex", "common.dexterite", "Dexterity"], ["bonusCon", "common.constitution", "common.constitution"],
	["bonusInt", "common.intelligence", "common.intelligence"], ["bonusHp", "PV max", "Max HP"], ["bonusStamina", "common.endurance_max", "Max stamina"],
	["bonusAtkMin", "admin.class_talents.degats_min_arme", "Min damage (weapon)"], ["bonusAtkMax", "admin.class_talents.degats_max_arme", "Max damage (weapon)"],
	["bonusSpellDmg", "common.degats_soin_de_sort", "Spell power"], ["critChance", "admin.class_talents.chances_de_critique", "% Crit chance"],
	["lifestealPct", "admin.class_talents.vol_de_vie", "% Lifesteal"], ["resistPhys", "admin.class_talents.resistance_physique", "% Physical resistance"],
	["resistMagic", "admin.class_talents.resistance_magique", "% Magic resistance"],
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
			return L.t(str(d[2])) if Data.lang == "en" else L.t(str(d[1]))
	return key

## Option dont la fiche est ouverte (identifiant) : les deux autres options du palier restent en lecture.
static var _open := ""

## Valeur signée d'un effet : « +10 » / « −3 ».
static func _signed(v: Variant) -> String:
	var f := float(v)
	var t := Ax.fmt(absf(f), 1.0 if is_equal_approx(f, roundf(f)) else 0.1)
	return ("+" if f >= 0.0 else "−") + t

## Nom et description affichés dans la langue courante (l'autre langue se règle dans la fiche ouverte).
static func _name_of(o: Dictionary) -> String:
	var n := str(o.get("labelEn" if Data.lang == "en" else "labelFr", ""))
	return n if n != "" else str(o.get("labelFr", o.get("labelEn", "")))

static func _desc_of(o: Dictionary) -> String:
	var n := str(o.get("descEn" if Data.lang == "en" else "descFr", ""))
	return n if n != "" else str(o.get("descFr", o.get("descEn", "")))

## Onglet « Talents » (maquette « Classes ») : un palier par ligne — pastille de niveau, option A, « ou », option B.
static func section(parent: Control, admin: Node, cfg: Dictionary, cls: Dictionary) -> void:
	parent.add_child(Ax.para(AdminItems._plain(L.t("admin.class_talents.talents_choix_a_un_palier")), 13, Ax.MUTED))
	var tracks := ensure_track(cfg, str(cls.id))
	var evolve_at := int(cls.get("evolveLevel", 0))
	var evo_to: Array = cls.get("evolvesTo", [])
	var base_with_evo: bool = AdminUtil.is_base(cls) and evo_to.any(func(x): return x != null and x != "") and evolve_at != 0
	var narrow: bool = admin.size.x < 1000.0
	for lvl in levels():
		var track: Dictionary = {}
		for t in tracks:
			if int(t.get("level", 0)) == int(lvl):
				track = t
		if track.is_empty():
			continue
		var unreachable: bool = base_with_evo and int(lvl) > evolve_at
		var wrap := Ax.vbox(6)
		if unreachable:
			wrap.modulate.a = 0.45
		var row := BoxContainer.new()
		row.vertical = narrow
		row.add_theme_constant_override("separation", 12)
		wrap.add_child(row)
		var lv := Ax.panel(Ax.FIELD, Ax.LINE2, 14, 0, 10)
		lv.custom_minimum_size = Vector2(0 if narrow else 84, 0)
		var lc := Ax.vbox(2)
		lc.alignment = BoxContainer.ALIGNMENT_CENTER
		lv.add_child(lc)
		var k := Ax.kicker(L.t("ui.atelier.c_level"), 11)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lc.add_child(k)
		var n := Ax.title(str(int(lvl)), 28, Ax.GOLD_L)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lc.add_child(n)
		row.add_child(lv)
		var opts: Array = track.get("options", [])
		for i in opts.size():
			if i == 1:
				var ou := Ax.lab(L.t("ui.atelier.c_or"), 12, Ax.DIM)
				ou.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ou.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ou.custom_minimum_size.x = 40
				row.add_child(ou)
			row.add_child(_option_card(admin, opts[i], unreachable))
		if unreachable:
			wrap.add_child(Ax.lab(AdminItems._plain(L.fa(AdminChars.T(L.t("admin.class_talents.inaccessible_evolue_au_niveau")), [str(cls.get("name", "")), evolve_at])), 12, Ax.GOLD_L))
		parent.add_child(wrap)

## Carte d'une option : lecture (nom, texte, effets) ; ouverte, elle devient la fiche d'édition (icône, noms et textes FR/EN, effets chiffrés).
static func _option_card(admin: Node, o: Dictionary, locked: bool) -> Control:
	var oid := str(o.get("id", ""))
	var on := _open == oid and not locked
	var p := Ax.panel(Color(0.91, 0.706, 0.361, 0.1) if on else Ax.CARD2, Ax.GOLD if on else Ax.LINE2, 14, 14, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.0
	p.custom_minimum_size.x = 120
	var v := Ax.vbox(8)
	p.add_child(v)
	if not on:
		var h := Ax.hbox(10)
		var ic := IconPicker.icon_control(str(o.get("icon", "")), 24.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var nm := Ax.lab(_name_of(o), 14, Ax.CREAM, 600)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		h.add_child(nm)
		v.add_child(h)
		var d := _desc_of(o)
		if d != "":
			v.add_child(Ax.para(d, 12, Ax.MUTED))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		for key in (o.get("effects", {}) as Dictionary).keys():
			fl.add_child(Ax.chip("%s %s" % [_signed(o.effects[key]), effect_label(str(key))], Ax.GOLD_L, Color("241a0e"), Ax.CLEAR, 12, 8, 9, 3))
		v.add_child(fl)
		if not locked:
			Ax.clickable(p, func():
				Ax.flush()
				_open = oid
				admin.refresh_tab())
		return p
	# ---- fiche d'édition
	var top := Ax.hbox(10)
	top.add_child(IconPicker.button(admin.modals(), o, "icon", func():
		Ax.changed()
		admin.refresh_tab(), 40.0))
	var nf := Ax.text_field(o, "labelFr", 40.0, 14, L.t("admin.class_talents.nom_fr"))
	nf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nf)
	v.add_child(top)
	v.add_child(Ax.text_field(o, "descFr", 36.0, 13, "Desc. FR"))
	v.add_child(Ax.text_field(o, "labelEn", 36.0, 13, L.t("admin.class_talents.name_en")))
	v.add_child(Ax.text_field(o, "descEn", 36.0, 13, L.t("admin.class_talents.desc_en")))
	v.add_child(Ax.cap(L.t("ui.atelier.c_effects")))
	var fx: Dictionary = Form.sub(o, "effects")
	var used: Array = fx.keys()
	var defs: Array = []
	for d in EFFECT_DEFS:
		defs.append([d[0], effect_label(str(d[0]))])
	for k in used:
		var key2: String = str(k)
		var r := Ax.hbox(6)
		var sel := Ax.select(defs, key2, func(nk):
			if nk == key2:
				return
			if fx.has(nk):
				admin.refresh_tab()      # déjà utilisé sur une autre ligne : on réaffiche l'ancienne valeur
				return
			var val = fx[key2]
			fx.erase(key2)
			fx[nk] = val
			Ax.changed()
			admin.refresh_tab(), 34.0, 12)
		r.add_child(sel)
		var stp := Ax.stepper(float(fx[key2]), -999.0, 999.0, 1.0, func(x: float):
			fx[key2] = Ax.num_value(x)
			Ax.changed(), 34.0)
		stp.custom_minimum_size.x = 96
		r.add_child(stp)
		r.add_child(Ax.icon_btn("close", func():
			fx.erase(key2)
			Ax.changed()
			admin.refresh_tab(), 34.0, Ax.MUTED, "ghost", L.t("admin.class_talents.retirer_cet_effet")))
		v.add_child(r)
	if used.size() < EFFECT_DEFS.size():
		v.add_child(Ax.btn("+ " + L.t("ui.atelier.c_effect_add"), func():
			for d in EFFECT_DEFS:
				if not fx.has(d[0]):
					fx[d[0]] = 1
					break
			Ax.changed()
			admin.refresh_tab(), "ghost", 34.0, 12, 12))
	v.add_child(Ax.btn(L.t("common.fermer"), func():
		Ax.flush()
		_open = ""
		admin.refresh_tab(), "flat", 32.0, 12, 12))
	return p
