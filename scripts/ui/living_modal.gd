class_name LivingModal
extends RefCounted
## Fiche d'une compétence vivante (Atlas Noir) : identité, affinité, tempérament, souvenirs, évolutions (choix définitif), liens, humeur.
## Ouverte depuis la fenêtre « Groupe » (onglet « Vie des compétences » et bouton 🕯 des cartes de sorts). Lecture seule si le système est inactif.

var gs: GameState
var char_id: String
var skill_id: String
var modal: Modal
var on_change: Callable = Callable()

static func open(host: Node, state: GameState, cid: String, sid: String, changed: Callable = Callable()) -> LivingModal:
	var m := LivingModal.new()
	m.gs = state
	m.char_id = cid
	m.skill_id = sid
	m.on_change = changed
	var prof := LivingCatalog.profile(state.cfg, sid)
	m.modal = GothicModal.open(host, L.t("ui.living.title"), 560)
	(m.modal as GothicModal).help_topic = "vivantes"
	m.modal.set_buttons([{"text": L.t("ui.living.close"), "cb": func(): m.modal.close()}])
	if prof.is_empty():
		m.modal.add_text("?", UiTheme.DIM)
		return m
	m._render()
	return m

func _clear() -> void:
	for n in modal.content.get_children():
		n.queue_free()

func _title(text: String, first: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	if not first:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		modal.content.add_child(gap)
	modal.content.add_child(l)
	var line := ColorRect.new()
	line.color = UiTheme.BRONZE_DARK
	line.custom_minimum_size = Vector2(0, 1)
	modal.content.add_child(line)

func _text(text: String, color: Color = UiTheme.PARCH, size: int = 14, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if italic:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal.content.add_child(l)
	return l

func _bar(label: String, value: float, maxv: float, color: Color, right: String = "", bold: bool = false) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", UiTheme.GOLD if bold else UiTheme.DIM)
	h.add_child(l)
	var back := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = UiTheme.BRONZE_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	back.add_theme_stylebox_override("panel", sb)
	back.custom_minimum_size = Vector2(0, 12)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(0, 8)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_child(fill)
	back.resized.connect(func(): fill.custom_minimum_size.x = maxf(0.0, (back.size.x - 4.0) * clampf(value / maxv, 0.0, 1.0)))
	h.add_child(back)
	var r := Label.new()
	r.text = right
	r.custom_minimum_size = Vector2(54, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 13)
	r.add_theme_color_override("font_color", UiTheme.PARCH)
	h.add_child(r)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(10, 0)      # le chiffre ne touche pas la barre de défilement
	h.add_child(sp)
	modal.content.add_child(h)

func _render() -> void:
	_clear()
	var d := LivingSkills.describe(gs, char_id, skill_id)
	var prof: Dictionary = d.profile
	var c := gs.char_by_id(char_id)
	var on := LivingSkills.active(gs)
	# identité
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var icon := str(prof.get("icon", ""))
	var tex := IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	elif icon != "":
		var il := Label.new()
		il.text = icon
		il.add_theme_font_size_override("font_size", 30)
		h.add_child(il)
	var v := VBoxContainer.new()
	var nm := Label.new()
	nm.text = str(prof.name)
	nm.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", UiTheme.GOLD)
	v.add_child(nm)
	var sub := Label.new()
	sub.text = "%s · %s" % [str(c.get("name", "")), L.t("ui.living.uses") % int(d.uses)]
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", UiTheme.DIM)
	v.add_child(sub)
	h.add_child(v)
	modal.content.add_child(h)
	if not on:
		_text(L.t("ui.living.off_note"), Color("e0a070"), 13, true)
	# affinité
	_title(L.fa(L.t("ui.living.affinity"), str(c.get("name", ""))))
	_bar(L.t("ui.living.tier_%d" % int(d.tier)), float(d.affinity), 100.0, UiTheme.STA_CYAN, "%d" % int(d.affinity), true)
	modal.content.add_child(LivingViz.timeline(float(d.affinity)))
	# tempérament
	_title(L.t("ui.living.temperament"))
	var tr_: Dictionary = d.traits
	for t in LivingCatalog.TRAITS:
		if tr_.has(t):
			_bar(L.t("ui.living.trait_%s" % t), float(tr_[t]), 100.0, UiTheme.GOLD if t == str(d.dominant) else UiTheme.BRONZE_LIGHT, str(tr_[t]), t == str(d.dominant))
	if str(d.dominant) != "":
		_text(L.fa(L.t("ui.living.dominant"), L.t("ui.living.trait_%s" % str(d.dominant))), UiTheme.PARCH, 13, true)
	if bool(d.mood):
		_text("⚡ " + L.t("ui.living.mood_note"), Color("e0a070"), 13, true)
		var cost := LivingSkills.appease_cost(gs, c)
		var b := modal.add_button(L.fa(L.t("ui.living.appease"), cost), func():
			var err := LivingSkills.appease(gs, char_id, skill_id)
			if err != "":
				modal.add_text(err, Color("e07a6a"), 13)
			else:
				_changed()
				_render(), not on or int(tr_.get("ins", 0)) < 20 or gs.gold < cost)
		b.tooltip_text = L.t("ui.living.appease_hint")
	# souvenirs
	_title(L.t("ui.living.memories"))
	if (d.memories as Array).is_empty():
		_text(L.t("ui.living.no_memories"), UiTheme.DIM, 13, true)
	for m in d.memories:
		_text("• " + LivingSkills.memory_text(gs, m), UiTheme.PARCH, 13)
	# évolutions
	_title(L.t("ui.living.evolutions"))
	modal.content.add_child(LivingViz.tree(str(prof.name), tex, d))
	var awake: Array = []
	for k in [str(d.evolved), str(d.get("evolved2", ""))]:
		if k != "":
			awake.append(k)
	for k in awake:
		_text("✦ " + L.fa(L.t("ui.living.evo_current"), L.t("ui.living.k_%s_n" % k)), UiTheme.GOLD, 14)
		_text(L.t("ui.living.k_%s_d" % k), UiTheme.PARCH, 13)
		_text(L.fa(L.t("ui.living.detail"), L.t("ui.living.k_%s_x" % k)), UiTheme.GOLD, 12, true)
	if not awake.is_empty():
		_text(L.t("ui.living.cap_note"), UiTheme.DIM, 12, true)
	if awake.size() == 1 and (d.available as Array).is_empty():
		_text(L.t("ui.living.evo_second_hint"), UiTheme.DIM, 13, true)      # la seconde évolution attend le palier « liée » (50) et un autre tempérament marqué
	if awake.size() < 2:
		if (d.available as Array).is_empty() and awake.is_empty():
			_text(L.t("ui.living.evo_none"), UiTheme.DIM, 13, true)
		for br in prof.branches:
			var kind := str(br.kind)
			if awake.has(kind):
				continue
			var open_: bool = (d.available as Array).has(kind)
			_text(("✦ " if open_ else "· ") + L.t("ui.living.k_%s_n" % kind) + "  (" + L.t("ui.living.trait_%s" % str(br.trait)) + ")", UiTheme.GOLD if open_ else UiTheme.DIM, 14)
			_text(L.t("ui.living.k_%s_d" % kind), UiTheme.PARCH if open_ else UiTheme.DIM, 13)
			_text(L.fa(L.t("ui.living.detail"), L.t("ui.living.k_%s_x" % kind)), UiTheme.DIM, 12, true)
			if open_:
				modal.add_button(L.t("ui.living.evo_choose") + " : " + L.t("ui.living.k_%s_n" % kind), func():
					var err := LivingSkills.evolve(gs, char_id, skill_id, kind)
					if err != "":
						modal.add_text(err, Color("e07a6a"), 13)
					else:
						_changed()
						_render(), not on)
		if not (d.available as Array).is_empty():
			_text(L.t("ui.living.evo_warn"), Color("e0a070"), 12, true)
	# geste signature (palier « fusionnelle »)
	_title(L.t("ui.living.sig_title"))
	if int(d.tier) >= LivingSkills.SIG_TIER:
		_text("✦ " + L.t("ui.living.sig_d_%s" % str(prof.family)), UiTheme.GOLD, 13)
		_text(L.fa(L.t("ui.living.detail"), L.t("ui.living.sig_x_%s" % str(prof.family))), UiTheme.GOLD, 12, true)
		_text(L.t("ui.living.sig_once"), UiTheme.DIM, 12, true)
	else:
		_text(L.t("ui.living.sig_locked"), UiTheme.DIM, 13, true)
		_text(L.t("ui.living.sig_d_%s" % str(prof.family)), UiTheme.DIM, 12, true)
		_text(L.fa(L.t("ui.living.detail"), L.t("ui.living.sig_x_%s" % str(prof.family))), UiTheme.DIM, 12, true)
	# liens
	_title(L.t("ui.living.relations"))
	if not (d.relations as Array).is_empty():
		var links: Array = []
		for r in d.relations:
			var kp := str(r.with).split("|")
			links.append({"name": "%s (%s)" % [LivingCatalog.profile(gs.cfg, kp[1]).get("name", kp[1]), str(gs.char_by_id(kp[0]).get("name", kp[0]))], "type": str(r.type), "level": int(r.level)})
		modal.content.add_child(LivingViz.web(str(prof.name), links))
	if (d.relations as Array).is_empty():
		_text(L.t("ui.living.no_relations"), UiTheme.DIM, 13, true)
	for r in d.relations:
		_text("• %s — %s, %s" % [LivingSkills.key_name(gs, str(r.with)), L.t("ui.living.rel_%s" % str(r.type)), L.t("ui.living.rel_level") % int(r.level)], UiTheme.PARCH, 13)
		_text("   " + L.t("ui.living.reld_%s" % str(r.type)), UiTheme.DIM, 12, true)
	# lore
	var n := int(LivingSkills.state(gs).fr)
	if n > 0:
		_title(L.fa(L.t("ui.living.lore_title"), n))
		for i in LivingSkills.lore_unlocked(gs):
			_text("✧ " + L.t("ui.living.lore_%d" % (i + 1)), UiTheme.DIM, 12, true)
	modal.call_deferred("_fit")

func _changed() -> void:
	if on_change.is_valid():
		on_change.call()
