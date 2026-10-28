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

## Sort affiché dans la fiche (identifiant) et filtre de la liste ("all", "damage", "heal", "support", "zone").
static var _ssel := ""
static var _sfilter := "all"

const FILTERS := {
	"damage": ["damage", "damageGroup"],
	"heal": ["healSingle", "healParty"],
	"support": ["staminaRestoreSingle", "shieldSingle", "dispelSingle", "partyUtility", "selfBuff", "sleepGroup"],
	"zone": ["damageGroup", "healParty", "sleepGroup"],
}
const SCHOOL := {"fire": "ff8a4a", "ice": "7fc4ff", "nature": "6fcf7f", "holy": "ffd88a", "shadow": "b98aff", "physical": "c9bfae", "arcane": "8ab4ff", "bard": "f08fd0"}

static func _school_color(s: Dictionary) -> Color:
	return Color(str(SCHOOL.get(str(s.get("style", "arcane")), "e8b45c")))

static func _school_name(s: Dictionary) -> String:
	for st in Data.constants.get("SPELL_STYLES", []):
		if st.id == s.get("style", "arcane"):
			var t := str(st.label)
			var sp := t.find(" ")
			return L.c(t.substr(sp + 1) if sp > 0 and sp < 4 else t)
	return ""

static func _mode_label(mode: String) -> String:
	for m in MODES:
		if m[0] == mode:
			return L.t(str(m[1]))
	return mode

## Valeur résumée d'un sort selon son mode.
static func _value(s: Dictionary) -> String:
	var pairs := {"damage": ["dmgMin", "dmgMax"], "damageGroup": ["dmgMin", "dmgMax"], "healSingle": ["healMin", "healMax"], "healParty": ["healMin", "healMax"],
		"staminaRestoreSingle": ["staminaMin", "staminaMax"], "shieldSingle": ["shieldMin", "shieldMax"]}
	var mode := str(s.get("mode", "damage")) if str(s.get("mode", "")) != "" else "damage"
	if pairs.has(mode):
		var lo := int(s.get(pairs[mode][0], 0))
		var hi := int(s.get(pairs[mode][1], 0))
		return str(lo) if lo == hi else "%d – %d" % [lo, hi]
	return "—"

static func build(host: VBoxContainer, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var spells: Array = cfg.get("spells", [])
	var narrow: bool = admin.size.x < 1000.0
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	host.add_child(gap)
	Form.hint(host, L.t("admin.spells.utilisable_par_n_importe_quelle"))
	Form.hint(host, L.t("admin.spells.un_personnage_ne_peut_jamais"))
	# ---- recherche, filtres, nouveau sort
	var bar := BoxContainer.new()
	bar.vertical = narrow
	bar.add_theme_constant_override("separation", 10)
	host.add_child(bar)
	var q := AdminChars.line_edit("", 240.0, 0.9, 12.0, 9.0, L.t("ui.atelier.s_search"))
	q.custom_minimum_size.y = 38
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(q)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(chips)
	for f in [["all", "ui.atelier.i_all"], ["damage", "ui.atelier.s_damage"], ["heal", "ui.atelier.s_heal"], ["support", "ui.atelier.s_support"], ["zone", "ui.atelier.s_zone"]]:
		var fid: String = f[0]
		chips.add_child(Atelier.pill(L.t(str(f[1])), _sfilter == fid, func():
			_sfilter = fid
			admin.refresh_tab()))
	var add := Atelier.button("+ " + L.t("ui.atelier.s_new"), func(): _add(admin), true, false, 38.0)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(add)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	host.add_child(gap2)
	# ---- liste + fiche
	var shown: Array = []
	for s in spells:
		var mode := str(s.get("mode", "damage")) if str(s.get("mode", "")) != "" else "damage"
		if _sfilter == "all" or (FILTERS[_sfilter] as Array).has(mode):
			shown.append(s)
	var sel: Dictionary = {}
	for s in spells:
		if str(s.get("id", "")) == _ssel:
			sel = s
	if sel.is_empty() or not shown.has(sel):
		sel = shown[0] if not shown.is_empty() else {}
		_ssel = str(sel.get("id", ""))
	var body := BoxContainer.new()
	body.vertical = narrow
	body.add_theme_constant_override("separation", 18)
	host.add_child(body)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	body.add_child(list)
	var compact: bool = admin.size.x < 1700.0
	if not compact:
		list.add_child(_list_head())
	var rows: Array = []
	for s in shown:
		var r := _list_row(s, str(s.get("id", "")) == _ssel, compact, func():
			Form.flush()
			_ssel = str(s.get("id", ""))
			admin.refresh_tab())
		list.add_child(r)
		rows.append([r, s])
	if shown.is_empty():
		list.add_child(Atelier.muted(L.t("ui.atelier.s_none"), 14))
	q.text_changed.connect(func(t: String):
		var w := IconPicker.normalize(t)
		for e in rows:
			e[0].visible = w == "" or IconPicker.normalize(str((e[1] as Dictionary).get("name", ""))).contains(w))
	if not sel.is_empty():
		body.add_child(_inspector(admin, sel, narrow))
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 8)
	host.add_child(gap3)
	Form.hint(host, L.t("admin.spells.le_temps_de_recharge_limite"))
	Form.hint(host, L.t("admin.spells.effets_hint"))

const COLS := [44, 0, 110, 150, 80, 90, 90]

static func _list_head() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size = Vector2(0, 20)
	var titles := ["", "common.nom", "ui.atelier.s_school", "admin.spells.mode", "ui.atelier.s_value", "common.endurance", "admin.spells.recharge"]
	for i in titles.size():
		var l := Label.new()
		l.text = L.t(str(titles[i])).to_upper() if titles[i] != "" else ""
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("9a8863"))
		l.clip_text = true
		if COLS[i] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(COLS[i], 0)
		h.add_child(l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_child(h)
	return m

static func _list_row(s: Dictionary, selected: bool, narrow: bool, cb: Callable) -> Control:
	var col := _school_color(s)
	var p := Atelier.card(selected, 10, 12)
	p.custom_minimum_size = Vector2(0, 52)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var sw := PanelContainer.new()
	sw.custom_minimum_size = Vector2(44, 36)
	sw.add_theme_stylebox_override("panel", Atelier.box(Color(1, 1, 1, 0.04), col, 9, 0, 0))
	var ic := IconPicker.icon_control(str(s.get("icon", "")), 22.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_child(ic)
	sw.custom_minimum_size = Vector2(36, 36)
	h.add_child(sw)
	var n := Label.new()
	n.text = str(s.get("name", "?"))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.clip_text = true
	n.add_theme_font_size_override("font_size", 14)
	n.add_theme_color_override("font_color", Color("f4e6c6"))
	h.add_child(n)
	var tier := HBoxContainer.new()
	tier.custom_minimum_size = Vector2(0 if narrow else 110, 0)
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tw := tier
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Atelier.box(Color(0, 0, 0, 0), col, 10, 10, 2))
	var tl := Label.new()
	tl.text = _school_name(s)
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", col)
	chip.add_child(tl)
	tw.add_child(chip)
	h.add_child(tier)
	var v := Label.new()
	v.text = _value(s)
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", Color("ffd88a"))
	v.custom_minimum_size = Vector2(70, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if narrow:
		h.add_child(v)
	if not narrow:
		var mode := str(s.get("mode", "damage")) if str(s.get("mode", "")) != "" else "damage"
		var cd := int(s.get("cooldownSec", 0))
		for e in [[_mode_label(mode), 150, Color("e2d2b0")], [_value(s), 80, Color("ffd88a")], [str(int(s.get("staminaCost", 0))), 90, Color("e2d2b0")], [("%d s" % cd) if cd > 0 else "—", 90, Color("e2d2b0")]]:
			var l := Label.new()
			l.text = str(e[0])
			l.custom_minimum_size = Vector2(e[1], 0)
			l.clip_text = true
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_color", e[2])
			h.add_child(l)
	Atelier.clickable(p, cb)
	return p

static func _cap(text: String) -> Label:
	var c := Label.new()
	c.text = text.to_upper()
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", Color("9a8863"))
	return c

## Fiche du sort choisi : icône, nom, école, mode, valeurs, endurance / recharge, statut, effet visuel, suppression.
static func _inspector(admin: Node, s: Dictionary, narrow: bool) -> Control:
	var panel := GameScreen.glass(22, 18)
	panel.custom_minimum_size = Vector2(0 if narrow else 380, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var save := func(): admin.save()
	var refresh := func():
		save.call()
		admin.refresh_tab()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	head.add_child(IconPicker.button(admin.modals(), s, "icon", refresh, 52.0))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 6)
	head.add_child(hv)
	var name_edit := AdminChars.line_edit(str(s.get("name", "")), 0.0, 1.0, 10.0, 8.0)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String): s["name"] = t)
	hv.add_child(name_edit)
	var mode := str(s.get("mode", "damage"))
	if mode == "":
		mode = "damage"
	col.add_child(_cap(L.t("admin.spells.mode")))
	col.add_child(AdminChars.select(MODES.map(func(m): return [m[0], L.t(str(m[1]))]), mode, func(v):
		s["mode"] = v
		refresh.call(), 0.0, 0.85, 10.0, 7.0, true))
	col.add_child(_cap(L.t("admin.spells.valeurs")))
	col.add_child(_stats(s, mode))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	f.add_child(AdminCells.inline(L.t("common.endurance"), true, 0.74))
	f.add_child(AdminCells.num(s, "staminaCost", 15, {"w": 44, "lo": 0, "hi": 50, "tip": L.t("admin.spells.cout_en_endurance"),
		"fix": func(v: float) -> float: return maxf(0.0, minf(50.0, v))}))
	f.add_child(AdminCells.inline(L.t("admin.spells.recharge"), true, 0.74))
	f.add_child(AdminCells.num(s, "cooldownSec", 6, {"w": 44, "lo": 0, "hi": 60, "tip": L.t("admin.spells.temps_de_recharge_secondes"),
		"fix": func(v: float) -> float: return maxf(0.0, minf(60.0, v))}))
	if mode == "damage":
		f.add_child(AdminCells.inline(L.t("admin.spells.vol_de_vie"), true, 0.74))
		f.add_child(AdminCells.num(s, "spellLifestealPct", 0, {"w": 44, "or": true, "lo": 0, "hi": 100, "tip": L.t("admin.spells.vol_de_vie_immediat_des")}))
	col.add_child(f)
	if mode == "damage":
		col.add_child(_cap(L.t("admin.spells.effet_de_statut")))
		col.add_child(_status(s, refresh))
	col.add_child(_cap(L.t("admin.spells.style_animation")))
	col.add_child(_style_cell(s, admin, refresh))
	var del := Atelier.button(L.t("ui.atelier.s_delete"), func(): _remove(admin, s), false, true, 38.0)
	col.add_child(del)
	Form.autosave(panel, save)
	return panel

## Colonne « Style (animation) » : le style (école du sort, qui décide aussi de la logique de combat) et, dessous, l'effet visuel.
## Changer de style remet l'effet par défaut du nouveau style. La teinte et l'intensité n'apparaissent que pour un effet avancé.
static func _style_cell(s: Dictionary, admin: Node, refresh: Callable) -> Control:
	var styles: Array = []
	for st in Data.constants.get("SPELL_STYLES", []):
		styles.append([st.id, st.label])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var style_opt := AdminCells.option(styles, s.get("style", ""), func(v):
		s["style"] = v
		s["fx"] = ""
		refresh.call(), 90.0)
	style_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(style_opt)
	var style := str(s.get("style", "arcane"))
	if style == "":
		style = "arcane"
	var mode := str(s.get("mode", "damage"))
	if mode == "":
		mode = "damage"
	var fxs := SpellFxLibrary.options(style, mode)
	if fxs.size() <= 1:
		return box     # ce style n'a pas encore d'effet avancé : seul l'effet d'origine existe
	var cur := SpellFxLibrary.resolve(s)
	var fx_opt := AdminCells.option(fxs, cur, func(v):
		s["fx"] = v
		refresh.call(), 90.0, L.t("admin.spells.effet_tip"))
	fx_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(fx_opt)
	if cur != SpellFxLibrary.CLASSIC:
		var tints: Array = []
		for t in SpellFxLibrary.TINTS:
			tints.append([t[0], L.t(str(t[1]))])
		var tint_opt := AdminCells.option(tints, str(s.get("fxTint", "")), func(v): s["fxTint"] = v, 90.0, L.t("admin.spells.teinte"))
		tint_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(tint_opt)
		var powers: Array = []
		for p in SpellFxLibrary.POWERS:
			powers.append([p[0], L.t(str(p[1]))])
		var power_opt := AdminCells.option(powers, float(s.get("fxPower", 1.0)), func(v): s["fxPower"] = float(v), 90.0, L.t("admin.spells.intensite"))
		power_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(power_opt)
	var preview := Button.new()
	preview.text = L.t("admin.spells.apercu")
	preview.focus_mode = Control.FOCUS_NONE
	preview.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
	preview.pressed.connect(func(): SpellFxPreview.open(admin.modals(), s))
	box.add_child(preview)
	return box

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
	var nid := AdminUtil.new_id("spell")
	_sfilter = "all"
	_ssel = nid
	(cfg.spells as Array).append({"id": nid, "name": L.t("admin.spells.nouveau_sort"), "icon": "✨", "style": "arcane", "mode": "damage", "fx": "", "fxTint": "", "fxPower": 1.0, "dmgMin": 3, "dmgMax": 7, "healMin": 5, "healMax": 10, "staminaCost": 15, "cooldownSec": 6})
	admin.save()
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
		_ssel = ""
		admin.save()
		admin.refresh_tab()
	Dialogs.confirm(admin.modals(), "", L.fa(L.t("admin.spells.supprimer_le_sort_capacite"), s.get("name", "")), go)
