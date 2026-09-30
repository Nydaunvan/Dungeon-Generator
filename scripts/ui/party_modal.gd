class_name PartyModal
extends RefCounted
## Fenêtre « Groupe » : un onglet par personnage, puis Statistiques ou Sorts / Capacités (port de openPartyModal).

const GOLD_DIM := Color("a9793a")
const HP_GREEN := Color("7ab648")

var gs: GameState
var modal: Modal
var char_id: String
var cat: String = "stats"
var _char_row: HBoxContainer
var _cat_row: HBoxContainer

static func open(host: Node, state: GameState, id: String) -> PartyModal:
	var p := PartyModal.new()
	p.gs = state
	p.char_id = id if not state.char_by_id(id).is_empty() else str(state.party[0].id)
	p.modal = Modal.open(host, "🎒 Groupe", 620)
	p.modal.panel.body.add_child(p._tabs_holder())
	p.modal.panel.body.move_child(p.modal.panel.body.get_child(p.modal.panel.body.get_child_count() - 1), 0)
	p.modal.set_buttons([{"text": "Fermer", "cb": func(): p.modal.close()}])
	p._render()
	return p

func _tabs_holder() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_char_row = HBoxContainer.new()
	_char_row.add_theme_constant_override("separation", 6)
	v.add_child(_char_row)
	_cat_row = HBoxContainer.new()
	_cat_row.add_theme_constant_override("separation", 4)
	v.add_child(_cat_row)
	return v

func _pill(text: String, on: bool, cb: Callable, tex: Texture2D = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD_DIM if on else Color(0.08, 0.06, 0.04, 0.5)
	sb.border_color = UiTheme.GOLD if on else Color("4a3a24")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var ink := Color("1a1108")
	b.add_theme_color_override("font_color", ink if on else UiTheme.DIM)
	b.add_theme_color_override("font_hover_color", ink if on else UiTheme.GOLD)
	b.pressed.connect(cb)
	return b

func _tab(text: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3d3022") if on else Color("241b12")
	sb.border_color = Color("5a4630") if on else Color("3a2c1c")
	sb.set_border_width_all(2)
	sb.border_width_bottom = 0
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.DIM)
	b.add_theme_color_override("font_hover_color", UiTheme.GOLD)
	b.pressed.connect(cb)
	return b

func _render() -> void:
	for n in _char_row.get_children():
		n.queue_free()
	for n in _cat_row.get_children():
		n.queue_free()
	for c in gs.party:
		var id: String = str(c.id)
		_char_row.add_child(_pill(str(c.name), id == char_id, func():
			char_id = id
			_render(), IconResolver.texture(str(c.get("icon", "")))))
	_cat_row.add_child(_tab("📊 Statistiques", cat == "stats", func():
		cat = "stats"
		_render()))
	_cat_row.add_child(_tab("✨ Sorts / Capacités", cat == "spells", func():
		cat = "spells"
		_render()))
	var content := modal.content
	for n in content.get_children():
		n.queue_free()
	var c := gs.char_by_id(char_id)
	if c.is_empty():
		return
	if cat == "stats":
		_stats(content, c)
	else:
		_spells(content, c)
	modal.call_deferred("_fit")

# ------------------------------------------------------------------ statistiques

func _section(parent: Control, text: String, first: bool = false) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 0 if first else 12)
	m.add_child(l)
	parent.add_child(m)
	var line := ColorRect.new()
	line.color = Color(0.66, 0.47, 0.23, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)

func _stat_cell(icon: String, label: String, base: String, eff: String = "") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := Label.new()
	ic.text = icon
	h.add_child(ic)
	var lb := Label.new()
	lb.text = label
	lb.add_theme_color_override("font_color", UiTheme.DIM)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lb)
	var v := RichTextLabel.new()
	v.bbcode_enabled = true
	v.fit_content = true
	v.scroll_active = false
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.custom_minimum_size = Vector2(90, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.text = "[right][b]%s[/b]%s[/right]" % [base, (" [color=#e8b45c]→ %s[/color]" % eff) if eff != "" else ""]
	h.add_child(v)
	return h

func _bar_row(parent: Control, label: String, val: float, mx: float, text: String, fill: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_color_override("font_color", UiTheme.DIM)
	h.add_child(l)
	var b := TextBar.new(fill, 20, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	b.set_values(val, mx, text)
	b.value = val
	parent.add_child(h)

func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g

func _stats(p: Control, c: Dictionary) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	var port := UiTheme.portrait(load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", ""))), UiTheme.BRONZE_LIGHT, 64)
	head.add_child(port)
	var t := VBoxContainer.new()
	var nm := Label.new()
	nm.text = str(c.name)
	nm.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", UiTheme.GOLD)
	t.add_child(nm)
	var cl := Label.new()
	cl.text = "%s — niveau %d" % [cls.get("name", ""), int(c.level)]
	cl.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	cl.add_theme_color_override("font_color", Color("b8843e"))
	t.add_child(cl)
	head.add_child(t)
	p.add_child(head)
	_section(p, "Statistiques principales")
	var g := _grid(p)
	for row in [["💪", "Force", "force", "effForce"], ["🎯", "Dextérité", "dex", "effDex"], ["🛡️", "Constitution", "con", "effCon"], ["✨", "Intelligence", "int", "effInt"]]:
		var base := int(c.get(row[2], 0))
		var eff := int(c.get(row[3], base))
		g.add_child(_stat_cell(row[0], row[1], str(base), str(eff) if eff != base else ""))
	_section(p, "Combat")
	_bar_row(p, "❤️ Points de vie", float(c.hp), float(c.maxHp), "%d/%d" % [int(c.hp), int(c.maxHp)], HP_GREEN)
	_bar_row(p, "⚡ Endurance", float(c.get("stamina", 0)), float(c.get("maxStamina", 100)), "%d/%d" % [roundi(float(c.get("stamina", 0))), int(c.get("maxStamina", 100))], Color("5fbfa8"))
	var g2 := _grid(p)
	g2.add_child(_stat_cell("⚔️", "Attaque", "%d – %d" % [int(c.atkMin), int(c.atkMax)]))
	if int(c.get("bonusSpellDmg", 0)) > 0:
		g2.add_child(_stat_cell("🔮", "Bonus sort", "+%d" % int(c.bonusSpellDmg)))
	_section(p, "Progression")
	_bar_row(p, "⭐ Expérience", float(c.get("xp", 0)), float(c.get("xpToNext", 1)), "%d/%d" % [int(c.get("xp", 0)), int(c.get("xpToNext", 1))], Color("4a8fc0"))

# ------------------------------------------------------------------ sorts

func _source_label(p: Control, icon: String, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := IconResolver.texture(icon)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.custom_minimum_size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", GOLD_DIM)
	h.add_child(l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(h)
	p.add_child(m)

func _spell_card(p: Control, sid: String, known: bool) -> void:
	var sp: Dictionary = {}
	for s in gs.cfg.get("spells", []):
		if s.get("id") == sid:
			sp = s
			break
	if sp.is_empty():
		return
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.border_color = Color("5a4630")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	if not known:
		card.modulate = Color(0.6, 0.58, 0.55, 0.5)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var icon := str(sp.get("icon", "✨"))
	var tex := IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(30, 30)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	else:
		var il := Label.new()
		il.text = icon
		il.add_theme_font_size_override("font_size", 22)
		h.add_child(il)
	var name_l := Label.new()
	name_l.text = str(sp.get("name", ""))
	name_l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", UiTheme.GOLD if known else UiTheme.DIM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var badge := Label.new()
	badge.text = "Acquis" if known else "Non acquis"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", HP_GREEN if known else UiTheme.DIM)
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(0, 0, 0, 0)
	bb.border_color = HP_GREEN if known else Color("5a4630")
	bb.set_border_width_all(1)
	bb.set_corner_radius_all(10)
	bb.content_margin_left = 8
	bb.content_margin_right = 8
	bb.content_margin_top = 1
	bb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", bb)
	h.add_child(badge)
	var meta := RichTextLabel.new()
	meta.bbcode_enabled = true
	meta.fit_content = true
	meta.scroll_active = false
	meta.add_theme_font_size_override("normal_font_size", 13)
	meta.add_theme_font_size_override("bold_font_size", 13)
	meta.add_theme_color_override("default_color", UiTheme.DIM)
	meta.text = _meta(sp)
	v.add_child(meta)
	p.add_child(card)

func _meta(sp: Dictionary) -> String:
	var mode := str(sp.get("mode", "damage"))
	var type_l := "Dégâts"
	match mode:
		"healSingle": type_l = "Soin sur un allié"
		"healParty": type_l = "Soin de groupe"
		"staminaRestoreSingle": type_l = "Restauration d'endurance sur un allié"
		"damageGroup": type_l = "Dégâts de zone"
		"shieldSingle": type_l = "Bouclier sur un allié"
		"dispelSingle": type_l = "Purification d'un allié"
		"sleepGroup": type_l = "Sommeil de l'ennemi engagé"
		"selfBuff": type_l = "Amélioration du lanceur"
		"partyUtility": type_l = "Soutien de groupe"
	var value := ""
	if mode == "healSingle" or mode == "healParty":
		value = "[b]Soin[/b] : %d – %d PV" % [int(sp.get("healMin", 0)), int(sp.get("healMax", 0))]
	elif mode == "staminaRestoreSingle":
		value = "[b]Endurance restaurée[/b] : %d – %d" % [int(sp.get("staminaMin", 0)), int(sp.get("staminaMax", 0))]
	elif mode == "shieldSingle":
		value = "[b]Bouclier[/b] : %d – %d" % [int(sp.get("shieldMin", 0)), int(sp.get("shieldMax", 0))]
	elif mode == "damage" or mode == "damageGroup":
		value = "[b]Dégâts[/b] : %d – %d" % [int(sp.get("dmgMin", 0)), int(sp.get("dmgMax", 0))]
		if mode == "damageGroup":
			value += " (par cible, groupe entier touché)"
		if bool(sp.get("ignoreAllResist", false)):
			value += " (ignore toute résistance)"
	var out := "[b]Type[/b] : %s" % type_l
	if value != "":
		out += "\n" + value
	var se := str(sp.get("statusEffect", ""))
	if se != "" and not Statuses.def(se).is_empty():
		var sd := Statuses.def(se)
		var pw := " · %d/tour" % int(sp.statusPower) if int(sp.get("statusPower", 0)) > 0 else ""
		out += "\n[b]Effet[/b] : %s %s (%d%% · %d tour(s)%s)" % [sd.get("icon", ""), sd.get("label", se), int(sp.get("statusChance", 0)), int(sp.get("statusDuration", 0)), pw]
	out += "\n[b]Endurance[/b] : %d — [b]Recharge[/b] : %ds" % [int(sp.get("staminaCost", 15)), int(sp.get("cooldownSec", 6))]
	return out

func _base_class(cls: Dictionary) -> Dictionary:
	var ev := str(cls.get("evolvesFrom", ""))
	if ev == "":
		return {}
	for k in gs.cfg.get("classes", []):
		if str(k.get("name", "")) == ev and str(k.get("evolvesFrom", "")) == "":
			return k
	return {}

func _spells(p: Control, c: Dictionary) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var known: Array = c.get("spellsKnown", [])
	var base := _base_class(cls)
	var groups: Array = []
	if not base.is_empty():
		groups.append([base, str(base.get("name", ""))])
		groups.append([cls, "%s (évolution)" % cls.get("name", "")])
	else:
		groups.append([cls, ""])
	for g in groups:
		var k: Dictionary = g[0]
		if g[1] != "":
			_source_label(p, str(k.get("icon", "")), g[1])
		var ids: Array = k.get("allowedSpellIds", [])
		if ids.is_empty():
			var none := Label.new()
			none.text = "Aucun sort défini."
			none.add_theme_color_override("font_color", UiTheme.DIM)
			p.add_child(none)
		for sid in ids:
			_spell_card(p, str(sid), known.has(sid))
