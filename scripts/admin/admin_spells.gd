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

static func build(host: Control, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	var spells: Array = cfg.get("spells", [])
	var narrow: bool = admin.size.x < 1000.0
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
	# ---- colonne principale : titre, recherche + filtres, tableau
	var main := Ax.vbox(16)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var top := Ax.hbox(16)
	main.add_child(top)
	var t := Ax.title(Atelier.title_of("spells"), 28 if not narrow else 22)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	top.add_child(t)
	top.add_child(Ax.btn("+ " + L.t("ui.atelier.s_new"), func(): _add(admin), "gold", 40.0, 16, 13))
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 10)
	bar.add_theme_constant_override("v_separation", 8)
	main.add_child(bar)
	var q := Ax.field("", Callable(), 38.0, 13, L.t("ui.atelier.s_search"))
	q.custom_minimum_size.x = 240
	q.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_child(q)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	bar.add_child(chips)
	for f in [["all", "ui.atelier.i_all"], ["damage", "ui.atelier.s_damage"], ["heal", "ui.atelier.s_heal"], ["support", "ui.atelier.s_support"], ["zone", "ui.atelier.s_zone"]]:
		var fid: String = f[0]
		chips.add_child(Ax.pill(L.t(str(f[1])), _sfilter == fid, func():
			Ax.flush()
			_sfilter = fid
			admin.refresh_tab()))
	var compact: bool = admin.size.x < 1340.0
	var table := Ax.vbox(6)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not compact:
		table.add_child(_list_head())
	var rows: Array = []
	for s in shown:
		var r := _list_row(s, str(s.get("id", "")) == _ssel, compact, func():
			Ax.flush()
			_ssel = str(s.get("id", ""))
			admin.refresh_tab())
		table.add_child(r)
		rows.append([r, s])
	if shown.is_empty():
		table.add_child(Ax.lab(L.t("ui.atelier.s_none"), 14, Ax.MUTED))
	q.text_changed.connect(func(tx: String):
		var w := IconPicker.normalize(tx)
		for e in rows:
			e[0].visible = w == "" or IconPicker.normalize(str((e[1] as Dictionary).get("name", ""))).contains(w))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(table)
	main.add_child(sc)
	admin.track_scroll("spells", sc)
	var px := 16 if narrow else 32
	var wrapped := Ax.margin(main, px, 28 if not narrow else 18, px, 20)
	wrapped.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapped.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if narrow:
		# petit écran : la page entière défile, la fiche passe sous le tableau
		sc.size_flags_vertical = Control.SIZE_FILL
		sc.custom_minimum_size.y = 260
		if not sel.is_empty():
			var box := Ax.panel(Color(0.063, 0.047, 0.031, 0.7), Ax.LINE, 16, 18, 18)
			var col := Ax.vbox(14)
			box.add_child(col)
			main.add_child(box)
			_inspector(admin, sel, col)
		var page := ScrollContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page.add_child(wrapped)
		host.add_child(page)
		admin.set("_scroll", page)
		return
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	host.add_child(root)
	root.add_child(wrapped)
	if not sel.is_empty():
		_inspector(admin, sel, Ax.aside(root, 360.0))

const COLS := [44, 0, 120, 150, 90, 90, 90]

static func _list_head() -> Control:
	var h := Ax.hbox(12)
	var titles := ["", "common.nom", "ui.atelier.s_school", "admin.spells.mode", "ui.atelier.s_value", "common.endurance", "admin.spells.recharge"]
	for i in titles.size():
		var l := Ax.lab(L.t(str(titles[i])).to_upper().replace(" (S)", "") if titles[i] != "" else "", 11, Ax.DIM, 600)
		l.add_theme_font_override("font", Ax.inter(600, 1))
		l.clip_text = true
		if COLS[i] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.size_flags_stretch_ratio = 1.3
		else:
			l.custom_minimum_size = Vector2(COLS[i], 0)
		h.add_child(l)
	return Ax.margin(h, 14, 0, 14, 0)

static func _cell(text: String, w: float, color: Color = Ax.TEXT, weight: int = 400, size: int = 13) -> Label:
	var l := Ax.lab(text, size, color, weight)
	l.custom_minimum_size.x = w
	l.clip_text = true
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

static func _list_row(s: Dictionary, selected: bool, compact: bool, cb: Callable) -> Control:
	var col := _school_color(s)
	var p := Ax.panel(Color(0.91, 0.706, 0.361, 0.1) if selected else Color(0.102, 0.075, 0.043, 0.8), Ax.GOLD if selected else Color("2a2014"), 12, 14, 0)
	p.custom_minimum_size.y = 52
	var h := Ax.hbox(12)
	p.add_child(h)
	var sw := Ax.panel(Color(1, 1, 1, 0.04), col, 9, 0, 0)
	sw.custom_minimum_size = Vector2(36, 36)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := IconPicker.icon_control(str(s.get("icon", "")), 22.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.add_child(ic)
	var sw_wrap := HBoxContainer.new()
	sw_wrap.custom_minimum_size = Vector2(44, 36)
	sw_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw_wrap.add_child(sw)
	h.add_child(sw_wrap)
	var n := _cell(str(s.get("name", "?")), 40.0, Ax.CREAM, 600, 14)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_stretch_ratio = 1.3
	h.add_child(n)
	var tier := HBoxContainer.new()
	tier.custom_minimum_size = Vector2(120, 0)
	tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tier.add_child(Ax.chip(_school_name(s), col, Ax.CLEAR, col, 12, 10, 10, 3))
	h.add_child(tier)
	var mode := str(s.get("mode", "damage")) if str(s.get("mode", "")) != "" else "damage"
	var cd := int(s.get("cooldownSec", 0))
	if compact:
		h.add_child(_cell(_value(s), 70.0, Ax.GOLD_L, 600))
	else:
		h.add_child(_cell(_mode_label(mode), 150.0))
		h.add_child(_cell(_value(s), 90.0, Ax.GOLD_L, 600))
		h.add_child(_cell(str(int(s.get("staminaCost", 0))), 90.0))
		h.add_child(_cell(("%d s" % cd) if cd > 0 else "—", 90.0))
	Ax.clickable(p, cb)
	return p

## Fiche du sort choisi (volet de droite) : icône, nom, mode, valeurs, statut, effet visuel, suppression.
static func _inspector(admin: Node, s: Dictionary, col: Control) -> void:
	var refresh := func():
		Ax.flush()
		admin.refresh_tab()
	var head := Ax.hbox(14)
	col.add_child(head)
	head.add_child(IconPicker.button(admin.modals(), s, "icon", func():
		Ax.changed()
		refresh.call(), 52.0))
	var hv := Ax.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hv)
	var name_edit := Ax.text_field(s, "name", 36.0, 20, "", func(tx: String): admin.note(tx))
	name_edit.add_theme_font_override("font", Ax.cinzel())
	name_edit.add_theme_color_override("font_color", Ax.CREAM)
	name_edit.add_theme_stylebox_override("normal", Ax.sb(Ax.CLEAR, Ax.CLEAR, 6, 0, 6, 0))
	name_edit.add_theme_stylebox_override("focus", Ax.sb(Ax.FIELD, Ax.GOLD, 8, 1, 6, 0))
	hv.add_child(name_edit)
	var mode := str(s.get("mode", "damage"))
	if mode == "":
		mode = "damage"
	hv.add_child(Ax.lab("%s · %s" % [_school_name(s), _mode_label(mode)], 12, Ax.MUTED))
	col.add_child(_group(L.t("admin.spells.mode"), Ax.select(MODES.map(func(m): return [m[0], L.t(str(m[1]))]), mode, func(v):
		s["mode"] = v
		Ax.changed()
		refresh.call())))
	var g := Ax.grid2(col)
	_stats(g, s, mode)
	var ult := bool(s.get("ultimate", false))
	if not ult:
		g.add_child(Ax.num(s, "staminaCost", 15, 0, 50, L.t("common.endurance")))
		g.add_child(Ax.num(s, "cooldownSec", 6, 0, 60, L.t("admin.spells.recharge")))
	if mode == "damage":
		g.add_child(Ax.num(s, "spellLifestealPct", 0, 0, 100, L.t("admin.spells.vol_de_vie").lstrip("🩸 ")))
		Ax.switch_row(col, L.t("admin.spells.ignore_resist"), bool(s.get("ignoreAllResist", false)), func(on: bool):
			s["ignoreAllResist"] = on
			Ax.changed(), L.t("admin.spells.degats_vrais_ignore_toute_resistance"))
		col.add_child(_group(L.t("admin.spells.effet_de_statut"), _status(s, refresh)))
	Ax.switch_row(col, L.t("admin.spells.ultime"), ult, func(on: bool):
		s["ultimate"] = on
		if on:
			s["staminaCost"] = 0
			s["cooldownSec"] = 0
		Ax.changed()
		refresh.call(), L.t("admin.spells.ultime_aide"))
	if ult:
		_ultimate_block(col, s, refresh)
	_style_block(col, s, admin, refresh)
	col.add_child(Ax.spacer())
	col.add_child(Ax.btn(L.t("ui.atelier.s_delete"), func(): _remove(admin, s), "danger", 38.0))

## Réglages d'une technique ultime : description, son emprunté, effets annexes (sacrifice, soins, bouclier, relève, exécution, frappes multiples, or)
## et statuts sur le groupe / le lanceur / les monstres. Voir Combat._ultimate_extras.
const ULT_NUMS := [["hits", 1, 1, 10, "admin.spells.ult_hits", ""], ["selfDmgPct", 0, 0, 90, "admin.spells.ult_selfdmg", " %"],
	["selfHealPct", 0, 0, 100, "admin.spells.ult_selfheal", " %"], ["drainPct", 0, 0, 100, "admin.spells.ult_drain", " %"],
	["shieldParty", 0, 0, 200, "admin.spells.ult_shield", ""], ["healPartyPct", 0, 0, 100, "admin.spells.ult_healparty", " %"],
	["revivePct", 0, 0, 100, "admin.spells.ult_revive", " %"], ["executePct", 0, 0, 100, "admin.spells.ult_execute", " %"],
	["bonusGold", 0, 0, 500, "admin.spells.ult_gold", ""]]

static func _ultimate_block(col: Control, s: Dictionary, refresh: Callable) -> void:
	col.add_child(_group(L.t("admin.spells.ult_titre"), Ax.para(L.t("admin.spells.ult_resume"), 12, Ax.MUTED)))
	col.add_child(Ax.labeled(L.t("admin.spells.ult_desc_fr"), Ax.text_field(s, "descFr", 36.0, 13)))
	col.add_child(Ax.labeled(L.t("admin.spells.ult_desc_en"), Ax.text_field(s, "descEn", 36.0, 13)))
	var snd: Array = [["", L.t("common.aucun")]]
	for sid in Sound.SPELL_SOUND_IDS:
		snd.append([sid, sid])
	col.add_child(Ax.labeled(L.t("admin.spells.ult_son"), Ax.select(snd, str(s.get("soundFrom", "")), func(v):
		s["soundFrom"] = str(v)
		Ax.changed(), 36.0, 13)))
	var g := Ax.grid2(col)
	for n in ULT_NUMS:
		g.add_child(Ax.num(s, str(n[0]), float(n[1]), float(n[2]), float(n[3]), L.t(str(n[4])), 1.0, str(n[5])))
	var defs: Dictionary = Data.constants.get("STATUS_DEFS", {})
	var opts: Array = [["", L.t("common.aucun")]]
	for id in defs:
		opts.append([id, "%s %s" % [defs[id].get("icon", ""), defs[id].get("label", id)]])
	for k in [["partyStatuses", "admin.spells.ult_st_party"], ["selfStatuses", "admin.spells.ult_st_self"], ["extraStatuses", "admin.spells.ult_st_monsters"]]:
		var key: String = k[0]
		var arr: Array = s.get(key, [])
		var first: Dictionary = arr[0] if not arr.is_empty() else {}
		var row := Ax.hbox(8)
		row.add_child(Ax.labeled(L.t(str(k[1])), Ax.select(opts, str(first.get("effect", "")), func(v):
			var list: Array = s.get(key, [])
			if str(v) == "":
				if not list.is_empty():
					list.remove_at(0)
			elif list.is_empty():
				list.append({"effect": str(v), "duration": 3, "chance": 100})
			else:
				list[0]["effect"] = str(v)
			s[key] = list
			Ax.changed()
			refresh.call(), 36.0, 13)))
		if not first.is_empty():
			row.add_child(Ax.num(first, "duration", 3, 1, 10, L.t("admin.spells.duree_tours")))
		col.add_child(row)

static func _group(title_text: String, ctl: Control) -> VBoxContainer:
	var v := Ax.vbox(6)
	v.add_child(Ax.cap(title_text))
	v.add_child(ctl)
	return v

## Style (école) puis effet visuel (pastilles) ; teinte et intensité pour un effet avancé ; aperçu.
static func _style_block(col: Control, s: Dictionary, admin: Node, refresh: Callable) -> void:
	var styles: Array = []
	for st in Data.constants.get("SPELL_STYLES", []):
		styles.append([st.id, st.label])
	col.add_child(_group(L.t("admin.spells.style_animation"), Ax.select(styles, s.get("style", ""), func(v):
		s["style"] = v
		s["fx"] = ""
		Ax.changed()
		refresh.call())))
	var style := str(s.get("style", "arcane"))
	if style == "":
		style = "arcane"
	var mode := str(s.get("mode", "damage"))
	if mode == "":
		mode = "damage"
	var fxs := SpellFxLibrary.options(style, mode)
	if fxs.size() <= 1:
		return
	var cur := SpellFxLibrary.resolve(s)
	var v := Ax.vbox(6)
	var cap := Ax.cap(L.t("ui.atelier.s_fx"))
	cap.tooltip_text = L.t("admin.spells.effets_hint")
	cap.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(cap)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for f in fxs:
		var fid = f[0]
		var b := Ax.pill(str(f[1]), fid == cur, func():
			s["fx"] = fid
			Ax.changed()
			refresh.call(), Ax.GOLD, 36.0, 13, 12)
		b.tooltip_text = L.t("admin.spells.effet_tip")
		fl.add_child(b)
	v.add_child(fl)
	col.add_child(v)
	if cur != SpellFxLibrary.CLASSIC:
		var g := Ax.grid2(col)
		var tints: Array = []
		for t in SpellFxLibrary.TINTS:
			tints.append([t[0], L.t(str(t[1]))])
		g.add_child(Ax.labeled(L.t("admin.spells.teinte"), Ax.select(tints, str(s.get("fxTint", "")), func(x):
			s["fxTint"] = x
			Ax.changed(), 36.0, 13)))
		var powers: Array = []
		for pw in SpellFxLibrary.POWERS:
			powers.append([pw[0], L.t(str(pw[1]))])
		g.add_child(Ax.labeled(L.t("admin.spells.intensite"), Ax.select(powers, float(s.get("fxPower", 1.0)), func(x):
			s["fxPower"] = float(x)
			Ax.changed(), 36.0, 13)))
	col.add_child(Ax.btn(L.t("admin.spells.apercu"), func(): SpellFxPreview.open(admin.modals(), s), "ghost", 36.0, 14, 13))

## Cases « valeurs » selon le mode (`spellStatsHtml`) : placées dans la grille de la fiche.
static func _stats(g: Control, s: Dictionary, mode: String) -> void:
	match mode:
		"damage", "damageGroup":
			g.add_child(Ax.num(s, "dmgMin", 0, 0, 999, L.t("common.degats_min")))
			g.add_child(Ax.num(s, "dmgMax", 0, 0, 999, L.t("common.degats_max")))
		"staminaRestoreSingle":
			g.add_child(Ax.num(s, "staminaMin", 0, 0, 999, L.t("admin.spells.endurance_restauree_min")))
			g.add_child(Ax.num(s, "staminaMax", 0, 0, 999, L.t("admin.spells.endurance_restauree_max")))
		"shieldSingle":
			g.add_child(Ax.num(s, "shieldMin", 0, 0, 999, L.t("admin.spells.bouclier_min")))
			g.add_child(Ax.num(s, "shieldMax", 0, 0, 999, L.t("admin.spells.bouclier_max")))
		"partyUtility":
			g.add_child(Ax.num(s, "cooldownReductionSec", 0, 0, 999, L.t("admin.spells.reduction_du_temps_de_recharge"), 1.0, " s"))
		"dispelSingle", "sleepGroup", "selfBuff":
			pass
		_:
			g.add_child(Ax.num(s, "healMin", 0, 0, 999, L.t("admin.spells.soin_min")))
			g.add_child(Ax.num(s, "healMax", 0, 0, 999, L.t("admin.spells.soin_max")))

## Statut infligé (`statusEffectHtml`) : liste puis chance / durée / dégâts par tour.
static func _status(s: Dictionary, refresh: Callable) -> Control:
	var defs: Dictionary = Data.constants.get("STATUS_DEFS", {})
	var opts: Array = [["", L.t("common.aucun")]]
	for id in defs:
		opts.append([id, "%s %s" % [defs[id].get("icon", ""), defs[id].get("label", id)]])
	var box := Ax.vbox(8)
	box.add_child(Ax.select(opts, s.get("statusEffect", ""), func(v):
		s["statusEffect"] = v
		Ax.changed()
		refresh.call(), 44.0))
	var cur := str(s.get("statusEffect", ""))
	if cur != "" and defs.has(cur):
		var r := Ax.hbox(8)
		r.add_child(Ax.num(s, "statusChance", 30, 0, 100, L.t("admin.spells.chance"), 1.0, " %"))
		r.add_child(Ax.num(s, "statusDuration", 3, 1, 10, L.t("admin.spells.duree_tours")))
		if bool(defs[cur].get("dot", false)):
			r.add_child(Ax.num(s, "statusPower", 3, 1, 20, L.t("admin.spells.degats_par_tour")))
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
