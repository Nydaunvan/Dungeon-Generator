class_name MonsterInfoModal
extends RefCounted
## Fiche du monstre affronté : caractéristiques, PV de chaque membre du groupe, rage et statuts actifs.

static func open(host: Node, def: Dictionary, st: Dictionary) -> Modal:
	var title := "%s %s" % [def.get("icon", "") if not str(def.get("icon", "")).begins_with("@icon:") else "", def.get("name", "Monstre")]
	var m := Modal.open(host, title.strip_edges(), 420.0)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(IconPicker.icon_control(str(def.get("icon", "")), 64.0))
	m.content.add_child(head)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	for c in [[L.t("ui.monster_info_modal.force"), int(def.get("force", 8))], [L.t("ui.monster_info_modal.dexterite"), int(def.get("dex", 8))], ["🛡️ Constitution", int(def.get("con", 8))],
			[L.t("ui.monster_info_modal.degats"), "%d–%d" % [int(st.atkMin), int(st.atkMax)]], [L.t("ui.monster_info_modal.resist_physique"), "%d%%" % int(def.get("resistPhys", 0))],
			[L.t("ui.monster_info_modal.resist_magique"), "%d%%" % int(def.get("resistMagic", 0))]]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := AdminUtil.label(str(c[0]), 14, UiTheme.DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(AdminUtil.label(str(c[1]), 14, UiTheme.PARCH))
		g.add_child(row)
	m.content.add_child(g)
	var members: Array = st.members if (bool(def.get("isGroup", false)) and st.has("members")) else [st]
	for i in members.size():
		var mem: Dictionary = members[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if members.size() > 1:
			var nm := AdminUtil.label(L.fa(L.t("ui.monster_info_modal.membre"), ["👹" if mem.alive else "💀", i + 1]), 13, UiTheme.PARCH)
			nm.custom_minimum_size = Vector2(96, 0)
			row.add_child(nm)
		var bar := ProgressBar.new()
		bar.max_value = maxf(1.0, float(mem.maxHp))
		bar.value = maxf(0.0, float(mem.hp))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("c2453b")
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.45)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		var txt := L.fa(L.t("ui.monster_info_modal.pv"), [ceili(float(mem.hp)), ceili(float(mem.maxHp))]) if mem.alive else L.t("ui.monster_info_modal.vaincu")
		var hp := AdminUtil.label(txt, 13, UiTheme.PARCH)
		hp.custom_minimum_size = Vector2(84, 0)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(hp)
		m.content.add_child(row)
	if bool(def.get("isBoss", false)):
		var t := L.fa(L.t("ui.monster_info_modal.entre_en_rage_sous_pv"), [int(def.get("enrageThreshold", 50)), int(def.get("enrageBonusPct", 0))])
		if st.get("enraged", false):
			t += L.t("ui.monster_info_modal.actuellement_enrage")
		m.add_text(t, UiTheme.DIM, 13)
	var badges: Array = []
	for e in Statuses.active(st):
		var sd := Statuses.def(str(e.type))
		badges.append("%s %s (%d)" % [sd.get("icon", "✨"), sd.get("label", e.type), int(e.remaining)])
	if not badges.is_empty():
		m.add_text("  ".join(badges), Color("ffd88a"), 14)
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m
