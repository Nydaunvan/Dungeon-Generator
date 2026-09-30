class_name StatsModal
extends RefCounted
## Statistiques de la partie : vue d'ensemble, personnages (graphiques) et bestiaire.

static func open(host: Node, gs: GameState) -> Modal:
	var m := Modal.open(host, "📊 Statistiques", 720.0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	m.content.add_child(tabs)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(body)
	var show := func(tab: String):
		for ch in body.get_children():
			ch.queue_free()
		match tab:
			"overview": _overview(body, gs)
			"chars": _chars(body, gs)
			_: _bestiary(body, gs)
		m.call_deferred("_fit")
	var group := ButtonGroup.new()
	for t in [["overview", "Vue d'ensemble"], ["chars", "Personnages"], ["bestiary", "📖 Bestiaire"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = t[0] == "overview"
		var id: String = t[0]
		b.pressed.connect(func(): show.call(id))
		tabs.add_child(b)
	show.call("overview")
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])
	return m

static func _title(parent: Control, text: String) -> void:
	parent.add_child(AdminUtil.label(text, 16, UiTheme.GOLD))

static func _grid(parent: Control, cells: Array) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in cells:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 6)
		row.add_child(AdminUtil.label("%s %s" % [c[0], c[1]], 14, UiTheme.DIM))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(AdminUtil.label(str(c[2]), 14, UiTheme.PARCH))
		g.add_child(row)
	parent.add_child(g)

static func _overview(p: Control, gs: GameState) -> void:
	var s := gs.stats
	var alive := gs.alive_party().size()
	var total := 0
	var best := 0
	for c in gs.party:
		total += int(c.level)
		best = maxi(best, int(c.level))
	var avg := int(round(float(total) / maxf(1.0, gs.party.size())))
	_title(p, "🗺️ Expédition en cours")
	_grid(p, [["⚔️", "Expédition", "n°%d" % maxi(1, gs.run_number)], ["🏰", "Donjon", str(gs.cfg.get("title", ""))],
		["📍", "Niveau", "%d / %d" % [gs.level_index + 1, (gs.cfg.get("levels", []) as Array).size()]], ["💚", "Survivants", "%d / %d" % [alive, gs.party.size()]]])
	_title(p, "👥 Groupe")
	for c in gs.party:
		var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(IconPicker.icon_control(str(c.get("icon", "")), 30.0))
		var info := AdminUtil.label("%s — %s, niv. %d" % [c.name, cls.get("name", ""), int(c.level)], 14, UiTheme.PARCH)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		row.add_child(AdminUtil.label("%d/%d PV" % [int(c.hp), int(c.maxHp)], 14, Color("e06a5a") if int(c.hp) <= 0 else UiTheme.HP_GREEN))
		p.add_child(row)
	_title(p, "⚔️ Combat")
	_grid(p, [["👹", "Monstres vaincus", int(s.get("monstersKilled", 0))], ["👑", "Boss vaincus", int(s.get("bossesKilled", 0))],
		["⚠️", "Pièges déclenchés", int(s.get("trapsTriggered", 0))], ["✨", "Sorts lancés", int(s.get("spellsCast", 0))]])
	_title(p, "💰 Richesses")
	_grid(p, [["💰", "Or actuel", gs.gold], ["💎", "Or gagné au total", int(s.get("goldEarnedTotal", 0))],
		["🛒", "Objets achetés", int(s.get("itemsBought", 0))], ["🏷️", "Objets vendus", int(s.get("itemsSold", 0))]])
	_title(p, "⭐ Progression")
	_grid(p, [["📈", "Niveau moyen", avg], ["🏆", "Meilleur niveau", best], ["🌟", "XP totale gagnée", int(s.get("xpEarnedTotal", 0))],
		["🏰", "Donjons terminés", int(s.get("dungeonsCompleted", 0))], ["🎁", "Objets trouvés", int(s.get("itemsFound", 0))],
		["🧪", "Potions utilisées", int(s.get("potionsUsed", 0))], ["⛲", "Fontaines utilisées", int(s.get("fountainsUsed", 0))]])

static func _per(gs: GameState, id) -> Dictionary:
	var d := {"actions": 0, "damageDealt": 0, "damageTaken": 0, "healingDone": 0, "kills": 0, "knockdowns": 0, "spellsCast": 0}
	d.merge((gs.stats.get("perChar", {}) as Dictionary).get(str(id), {}), true)
	return d

static func _bars(p: Control, gs: GameState, field: String, color: Color) -> void:
	var mx := 1
	for c in gs.party:
		mx = maxi(mx, int(_per(gs, c.id)[field]))
	for c in gs.party:
		var v := int(_per(gs, c.id)[field])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nm := AdminUtil.label(str(c.name), 13, UiTheme.PARCH)
		nm.custom_minimum_size = Vector2(110, 0)
		row.add_child(nm)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = mx
		bar.value = v
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		bar.add_theme_stylebox_override("fill", fill)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.4)
		bar.add_theme_stylebox_override("background", bg)
		row.add_child(bar)
		var val := AdminUtil.label(str(v), 13, UiTheme.GOLD)
		val.custom_minimum_size = Vector2(44, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		p.add_child(row)

static func _chars(p: Control, gs: GameState) -> void:
	var active := false
	for c in gs.party:
		if int(_per(gs, c.id).actions) > 0:
			active = true
	if active:
		var most: Dictionary = gs.party[0]
		var least: Dictionary = gs.party[0]
		for c in gs.party:
			if int(_per(gs, c.id).actions) > int(_per(gs, most.id).actions):
				most = c
			if int(_per(gs, c.id).actions) < int(_per(gs, least.id).actions):
				least = c
		p.add_child(AdminUtil.label("🏆 Le plus actif : %s — %d action(s)" % [most.name, int(_per(gs, most.id).actions)], 14, UiTheme.GOLD))
		p.add_child(AdminUtil.label("😴 Le plus délaissé : %s — %d action(s)" % [least.name, int(_per(gs, least.id).actions)], 14, UiTheme.DIM))
	_title(p, "📊 Actions par personnage")
	_bars(p, gs, "actions", Color("c9963a"))
	_title(p, "⚔️ Dégâts infligés par personnage")
	_bars(p, gs, "damageDealt", Color("c2453b"))
	for c in gs.party:
		var s := _per(gs, c.id)
		var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
		var eq := 0
		for slot in ["weapon", "head", "body", "hands", "feet", "accessory"]:
			if (c.get("equipment", {}) as Dictionary).get(slot) is Dictionary:
				eq += 1
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(IconPicker.icon_control(str(c.get("icon", "")), 36.0))
		head.add_child(AdminUtil.label("%s — %s, niveau %d   ⭐ XP %d/%d" % [c.name, cls.get("name", ""), int(c.level), int(c.xp), int(c.xpToNext)], 15, UiTheme.GOLD))
		p.add_child(head)
		_grid(p, [["🎯", "Actions", s.actions], ["💥", "Dégâts infligés", s.damageDealt], ["🩸", "Dégâts subis", s.damageTaken],
			["💚", "Soins prodigués", s.healingDone], ["☠️", "Monstres achevés", s.kills], ["✨", "Sorts lancés", s.spellsCast],
			["💫", "Fois à terre", s.knockdowns], ["🎒", "Équipement", "%d/5" % eq]])

static func _bestiary(p: Control, gs: GameState) -> void:
	var entries: Array = gs.bestiary.values()
	if entries.is_empty():
		p.add_child(AdminUtil.label("Aucun monstre vaincu pour le moment. Le bestiaire se complète au fur et à mesure de vos victoires.", 14, UiTheme.DIM))
		return
	entries.sort_custom(func(a, b): return int(a.killCount) > int(b.killCount))
	_title(p, "📖 Bestiaire — %d %s" % [entries.size(), "espèces découvertes" if entries.size() > 1 else "espèce découverte"])
	for e in entries:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(IconPicker.icon_control(str(e.get("icon", "")), 40.0))
		head.add_child(AdminUtil.label("%s%s   Vaincu × %d" % [e.name, "  [BOSS]" if e.get("isBoss", false) else "", int(e.killCount)], 15, UiTheme.GOLD if e.get("isBoss", false) else UiTheme.PARCH))
		p.add_child(head)
		var cells: Array = [["💪", "For", int(e.force)], ["🎯", "Dex", int(e.dex)], ["🛡️", "Con", int(e.con)], ["❤️", "PV", int(round(float(e.maxHp)))],
			["⚔️", "Dégâts", "%d – %d" % [int(e.atkMin), int(e.atkMax)]], ["🛡️", "Rés. phys.", "%d%%" % int(e.resistPhys)], ["✨", "Rés. mag.", "%d%%" % int(e.resistMagic)],
			["⏱️", "Vitesse d'attaque", "%.1fs" % float(e.attackSpeed)], ["🚶", "Zone", int(e.patrolRadius)], ["⭐", "XP", int(e.xpReward)], ["💰", "Or", int(e.goldReward)]]
		if int(e.get("enrageThreshold", 0)) > 0:
			cells.append(["😡", "Seuil rage", "%d%%" % int(e.enrageThreshold)])
		_grid(p, cells)
		if str(e.get("abilitySpellId", "")) != "":
			var sp := Data.spell_by_id(str(e.abilitySpellId))
			if not sp.is_empty():
				p.add_child(AdminUtil.label("Capacité : %s %s (%d%%)" % [sp.get("icon", ""), sp.get("name", ""), int(e.abilityChance)], 13, UiTheme.DIM))
