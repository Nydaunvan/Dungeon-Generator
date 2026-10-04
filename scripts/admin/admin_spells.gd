class_name AdminSpells
extends RefCounted
## Onglet « Sorts / Capacités » : tableau des sorts (icône, nom, style, mode, valeurs, statut, vol de vie, endurance, recharge).
## Reproduit `renderSpellTable` / `spellStatsHtml` / `statusEffectHtml` / `editSpell` / `addSpell` / `removeSpell` de l'original.

const MODES := [
	["damage", "admin.spells.degats_sur_ennemi"],
	["damageGroup", "common.degats_de_zone_tout_le"],
	["healSingle", "admin.spells.soin_individuel"],
	["healParty", "common.soin_de_groupe"],
	["staminaRestoreSingle", "admin.spells.restauration_endurance_sur_allie"],
	["shieldSingle", "admin.spells.bouclier_sur_allie"],
	["dispelSingle", "admin.spells.dissipation_retire_les_statuts"],
	["sleepGroup", "admin.spells.sommeil_ralentissement_sur_le"],
	["partyUtility", "admin.spells.soutien_de_groupe_instantane"],
	["selfBuff", "admin.spells.buff_sur_soi_instantane"],
]

const HEADERS := ["common.icone", "common.nom", "admin.spells.style_animation", "admin.spells.mode", "admin.spells.valeurs", "admin.spells.effet_de_statut", "admin.spells.vol_de_vie", "common.endurance", "admin.spells.recharge", ""]
const MIN_W := [40, 76, 88, 88, 112, 90, 62, 80, 80, 34]
## Part de l'espace libre reçue par les colonnes Nom / Style / Mode (proportions du tableau HTML : 155 / 156 / 238).
const STRETCH := {1: 1.55, 2: 1.56, 3: 2.38}

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var p := Form.panel(host, L.t("admin.spells.sorts_capacites_speciales"))
	Form.hint(p, L.t("admin.spells.utilisable_par_n_importe_quelle"))
	Form.hint(p, L.t("admin.spells.un_personnage_ne_peut_jamais"))
	var grid := AdminTable.create(p, HEADERS, MIN_W)
	AdminCells.wrap_headers(grid, HEADERS.size())
	for col in STRETCH:
		var hd := grid.get_child(col) as Control
		hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.size_flags_stretch_ratio = STRETCH[col]
	(grid.get_child(6) as Control).tooltip_text = L.t("admin.spells.vol_de_vie_immediat")
	(grid.get_child(6) as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for s in cfg.get("spells", []):
		_row(grid, admin, s)
	Form.hint(p, L.t("admin.spells.le_temps_de_recharge_limite"))
	var status_ref := [null]
	AdminCells.actions(p, [
		{"text": L.t("admin.spells.ajouter_un_sort"), "cb": func(): _add(admin)},
		{"text": L.t("common.enregistrer_la_configuration"), "primary": true, "cb": func(): admin.confirm_save(status_ref[0])},
	])
	status_ref[0] = AdminCells.status_label(p)

static func _row(grid: GridContainer, admin: Node, s: Dictionary) -> void:
	var refresh := func(): admin.refresh_tab()
	# icône
	AdminTable.cell(grid, IconPicker.button(admin.modals(), s, "icon", Callable(), 38.0))
	# nom
	AdminTable.cell(grid, _stretch(AdminCells.text(s, "name", "", Callable(), 80.0), 1))
	# style (le premier est affiché si le sort n'en a pas, comme un <select> HTML)
	var styles: Array = []
	for st in Data.constants.get("SPELL_STYLES", []):
		styles.append([st.id, st.label])
	AdminTable.cell(grid, _stretch(AdminCells.option(styles, s.get("style", ""), func(v): s["style"] = v, 90.0), 2))
	# mode
	var mode := str(s.get("mode", "damage"))
	if mode == "":
		mode = "damage"
	AdminTable.cell(grid, _stretch(AdminCells.option(MODES, mode, func(v):
		s["mode"] = v
		refresh.call(), 90.0), 3))
	# valeurs
	AdminTable.cell(grid, _stats(s, mode))
	# statut / vol de vie (mode « damage » uniquement)
	if mode == "damage":
		AdminTable.cell(grid, _status(s, refresh))
		AdminTable.cell(grid, AdminCells.num(s, "spellLifestealPct", 0, {"or": true, "lo": 0, "hi": 100,
				"tip": L.t("admin.spells.vol_de_vie_immediat_des")}))
	else:
		AdminTable.cell(grid, Control.new())
		AdminTable.cell(grid, Control.new())
	# endurance / recharge : seuls champs bornés (0..50 et 0..60)
	AdminTable.cell(grid, AdminCells.num(s, "staminaCost", 15, {"lo": 0, "hi": 50, "tip": L.t("admin.spells.cout_en_endurance"),
			"fix": func(v: float) -> float: return maxf(0.0, minf(50.0, v))}))
	AdminTable.cell(grid, AdminCells.num(s, "cooldownSec", 6, {"lo": 0, "hi": 60, "tip": L.t("admin.spells.temps_de_recharge_secondes"),
			"fix": func(v: float) -> float: return maxf(0.0, minf(60.0, v))}))
	AdminTable.cell(grid, AdminCells.trash(func(): _remove(admin, s)))

static func _stretch(c: Control, col: int) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = STRETCH[col]
	return c

## Colonne « Valeurs » selon le mode (`spellStatsHtml`).
static func _stats(s: Dictionary, mode: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.add_child(h)
	match mode:
		"damage", "damageGroup":
			_pair(h, s, "dmgMin", "dmgMax", L.t("common.degats_min"), L.t("common.degats_max"))
			v.add_child(AdminCells.check(L.t("admin.spells.ignore_resist"), bool(s.get("ignoreAllResist", false)),
					func(on: bool): s["ignoreAllResist"] = on, 0.65,
					L.t("admin.spells.degats_vrais_ignore_toute_resistance")))
		"staminaRestoreSingle":
			_pair(h, s, "staminaMin", "staminaMax", L.t("admin.spells.endurance_restauree_min"), L.t("admin.spells.endurance_restauree_max"))
		"shieldSingle":
			_pair(h, s, "shieldMin", "shieldMax", L.t("admin.spells.bouclier_min"), L.t("admin.spells.bouclier_max"))
		"partyUtility":
			h.add_child(AdminCells.num(s, "cooldownReductionSec", 0, {"w": 48, "or": true,
					"tip": L.t("admin.spells.reduction_du_temps_de_recharge")}))
			h.add_child(AdminCells.inline("sec."))
			h.add_child(AdminCells.inline(L.t("admin.spells.vigueur"), true, 0.74, true))
		"dispelSingle", "sleepGroup", "selfBuff":
			h.add_child(AdminCells.inline("—", true, 0.74, true))
		_:
			_pair(h, s, "healMin", "healMax", L.t("admin.spells.soin_min"), L.t("admin.spells.soin_max"))
	return v

static func _pair(h: Control, s: Dictionary, k1: String, k2: String, t1: String, t2: String) -> void:
	h.add_child(AdminCells.num(s, k1, 0, {"w": 48, "or": true, "tip": t1}))
	h.add_child(AdminCells.inline("-"))
	h.add_child(AdminCells.num(s, k2, 0, {"w": 48, "or": true, "tip": t2}))

## Colonne « Effet de statut » (`statusEffectHtml`) : liste + chance / durée / dégâts par tour.
static func _status(s: Dictionary, refresh: Callable) -> Control:
	var defs: Dictionary = Data.constants.get("STATUS_DEFS", {})
	var opts: Array = [["", L.t("common.aucun")]]
	for id in defs:
		opts.append([id, "%s %s" % [defs[id].get("icon", ""), defs[id].get("label", id)]])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var sel := AdminCells.option(opts, s.get("statusEffect", ""), func(v):
		s["statusEffect"] = v
		refresh.call(), 85.0, "", 0.6)
	box.add_child(sel)
	var cur := str(s.get("statusEffect", ""))
	if cur != "" and defs.has(cur):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 3)
		r.add_child(AdminCells.num(s, "statusChance", 30, {"w": 38, "lo": 0, "hi": 100, "tip": L.t("admin.spells.chance")}))
		r.add_child(AdminCells.num(s, "statusDuration", 3, {"w": 34, "lo": 1, "hi": 10, "tip": L.t("admin.spells.duree_tours")}))
		if bool(defs[cur].get("dot", false)):
			r.add_child(AdminCells.num(s, "statusPower", 3, {"w": 34, "lo": 1, "hi": 20, "tip": L.t("admin.spells.degats_par_tour")}))
		box.add_child(r)
	return box

static func _add(admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	if not (cfg.get("spells") is Array):
		cfg["spells"] = []
	(cfg.spells as Array).append({"id": AdminUtil.new_id("spell"), "name": L.t("admin.spells.nouveau_sort"), "icon": "✨", "style": "arcane", "mode": "damage", "dmgMin": 3, "dmgMax": 7, "healMin": 5, "healMax": 10, "staminaCost": 15, "cooldownSec": 6})
	admin.refresh_tab()

## `removeSpell` : confirmation sans titre, puis retrait du sort des classes (sorts autorisés) et des personnages (sorts connus).
## Amélioration par rapport à l'original : on retire aussi les entrées de `spellProgression` qui pointaient vers ce sort.
static func _remove(admin: Node, s: Dictionary) -> void:
	var go := func():
		var cfg: Dictionary = Data.admin_config()
		(cfg.spells as Array).erase(s)
		var sid = s.get("id")
		for c in cfg.get("classes", []):
			if c.get("allowedSpellIds") is Array:
				c["allowedSpellIds"] = (c.allowedSpellIds as Array).filter(func(x): return x != sid)
			if c.get("spellProgression") is Array:
				c["spellProgression"] = (c.spellProgression as Array).filter(func(p): return p.get("spellId") != sid)
		for p in cfg.get("party", []):
			p["spellsKnown"] = (p.get("spellsKnown", []) as Array).filter(func(x): return x != sid)
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "", L.fa(L.t("admin.spells.supprimer_le_sort_capacite"), s.get("name", "")), go)
