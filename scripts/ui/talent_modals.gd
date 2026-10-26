class_name TalentModals
extends RefCounted
## Fenêtres des talents et de l'évolution de classe : choix au passage de niveau, Maître des Talents du village.

## Présente le premier choix en attente (talent ou évolution) s'il n'y a pas de fenêtre ouverte. `on_change` est appelé après chaque choix.
static func process_queue(host: Node, gs: GameState, on_change: Callable) -> void:
	if gs.choice_queue.is_empty():
		return
	if Flows.is_open("talent") or Flows.is_open("evolve"):
		return
	for n in host.get_tree().get_nodes_in_group("modal"):
		if not n.is_queued_for_deletion():
			return
	var done := func():
		on_change.call()
		process_queue(host, gs, on_change)
	# premier choix en attente qui a encore un sens (un choix périmé reste dans la file : il ne change rien et ne bloque personne)
	for q in gs.choice_queue:
		var c := gs.char_by_id(str(q.char_id))
		if c.is_empty():
			continue
		if q.kind == "evolve":
			_evolution(host, gs, c, q, done)
			return
		var track := Talents.track_at(gs.cfg, str(c.classId), int(q.level))
		if track.is_empty() or (c.get("talents", []) as Array).any(func(t): return int(t.level) == int(q.level)):
			continue
		_talent(host, gs, c, track, q, done)
		return

static func _talent(host: Node, gs: GameState, c: Dictionary, track: Dictionary, q: Dictionary, done: Callable) -> void:
	var m := Modal.open(host, L.t("ui.talent_modals.nouveau_talent"), 440.0)
	m.esc_closes = false
	m.add_text(L.fa(L.t("ui.talent_modals.atteint_le_niveau_choisissez"), [c.name, int(track.level)]))
	for o in track.options:
		var oid := str(o.id)
		var tdesc := str(o.get("descFr", Talents.effect_label(o.get("effects", {}))))
		_choice_button(m, str(o.get("icon", "")), str(o.get("labelFr", "")), tdesc, 40.0, func():
			Flows.choose("talent", oid))
	m.set_buttons([])
	Flows.open("talent", m, func(oid: Variant):
		gs.choice_queue.erase(q)
		Talents.choose(gs, c, int(track.level), str(oid))
		if int(c.hp) > int(c.maxHp):
			c["hp"] = c.maxHp
		done.call())

## Bouton de choix : icône à gauche (image réelle « @icon:… » ou, à défaut, emoji devant le titre), titre et description qui passent à la ligne.
## Le texte n'est pas celui du bouton : un bouton à icône réduit celle-ci à rien quand le texte est long (Mage-Archer, Berserker…), donc l'icône et les
## textes sont des enfants posés dans le bouton, dont la hauteur suit leur contenu.
static func _choice_button(m: Modal, ico: String, title: String, desc: String, icon_px: float, cb: Callable) -> Button:
	var b := m.add_button("", cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, maxf(56.0, icon_px + 16.0))
	var tex := IconResolver.texture(ico)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	b.add_child(row)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(icon_px, icon_px)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var t := Label.new()
	t.text = title if tex != null else "%s %s" % [ico, title]
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color("e8b45c"))
	col.add_child(t)
	var d := Label.new()
	d.text = desc
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(220, 0)
	d.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	d.add_theme_font_size_override("font_size", 14)
	d.add_theme_color_override("font_color", Color("d9c8a0"))
	col.add_child(d)
	# hauteur du bouton = contenu ; recalculée chaque fois que le contenu change de hauteur (largeur connue, texte qui passe à la ligne)
	var fit := func():
		var want := maxf(maxf(56.0, icon_px + 16.0), col.get_combined_minimum_size().y + 16.0)
		if absf(b.custom_minimum_size.y - want) > 1.0:
			b.custom_minimum_size.y = want
	col.minimum_size_changed.connect(fit)
	d.minimum_size_changed.connect(fit)
	b.resized.connect(fit)
	return b

static func _evolution(host: Node, gs: GameState, c: Dictionary, q: Dictionary, done: Callable) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.classId))
	var m := Modal.open(host, L.t("ui.talent_modals.evolution_de_classe"), 520.0)
	m.esc_closes = false
	m.add_text(L.fa(L.t("ui.talent_modals.a_atteint_le_niveau_requis"), c.name))
	for cid in cls.get("evolvesTo", []):
		var oc := Characters.class_def(gs.cfg, str(cid))
		if oc.is_empty():
			continue
		var id := str(cid)
		_choice_button(m, str(oc.get("icon", "")), str(oc.get("name", "")), str(oc.get("descFr", "")), 48.0, func():
			Flows.choose("evolve", id))
	m.set_buttons([])
	Flows.open("evolve", m, func(cid_chosen: Variant):
		gs.choice_queue.erase(q)
		Talents.evolve(gs, c, str(cid_chosen))
		done.call())

# ------------------------------------------------------------------ Maître des Talents (village)

static func master(host: Node, gs: GameState, on_change: Callable) -> Modal:
	var m := Modal.open(host, L.t("ui.talent_modals.le_maitre_des_talents"), 640.0)
	var st := {"who": str(gs.party[0].id) if not gs.party.is_empty() else ""}
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var tabs := AdminUtil.flow(m.content)
	m.content.add_child(body)
	var rf := {}      # une fonction anonyme ne peut pas se rappeler elle-même (variable capturée par copie, vide) : on passe par ce dictionnaire
	var render := Callable()
	rf["f"] = func():
		for ch in tabs.get_children():
			ch.queue_free()
		for ch in body.get_children():
			ch.queue_free()
		for c in gs.party:
			var cid := str(c.id)
			var tb := Button.new()
			tb.text = "%s %s" % [c.get("icon", ""), c.name]
			tb.toggle_mode = true
			tb.button_pressed = cid == st.who
			tb.focus_mode = Control.FOCUS_NONE
			tb.pressed.connect(func():
				st.who = cid
				rf.f.call())
			tabs.add_child(tb)
		var c := gs.char_by_id(str(st.who))
		if c.is_empty():
			return
		body.add_child(_hint(L.t("ui.talent_modals.le_maitre_des_talents_affiche")))
		body.add_child(AdminUtil.label("💰 Or disponible : %d" % gs.gold, 15, UiTheme.GOLD))
		body.add_child(AdminUtil.label("%s %s — Nv.%d" % [c.get("icon", ""), c.name, int(c.level)], 17, UiTheme.GOLD))
		var trs := Talents.tracks(gs.cfg, str(c.classId))
		if trs.is_empty():
			body.add_child(_hint(L.t("ui.talent_modals.cette_classe_ne_dispose_aucun")))
			return
		var chosen := {}
		for t in c.get("talents", []):
			chosen[int(t.level)] = t
		for track in trs:
			var lv := int(track.level)
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			if int(c.level) < lv:
				row.add_child(AdminUtil.label(L.fa(L.t("ui.talent_modals.nv_verrouille_debloque_a_ce"), lv), 14, UiTheme.DIM))
			elif not chosen.has(lv):
				row.add_child(AdminUtil.label("Nv.%d — Choix disponible" % lv, 15, UiTheme.PARCH))
				var fl := AdminUtil.flow(row)
				for o in track.options:
					var oid := str(o.id)
					var ob := Button.new()
					ob.text = "%s %s" % [o.get("icon", ""), o.get("labelFr", "")]
					ob.tooltip_text = str(o.get("descFr", ""))
					ob.focus_mode = Control.FOCUS_NONE
					ob.pressed.connect(func():
						Talents.choose(gs, c, lv, oid)
						if int(c.hp) > int(c.maxHp):
							c["hp"] = c.maxHp
						on_change.call()
						rf.f.call())
					fl.add_child(ob)
			else:
				var cur := Talents.find_option(gs.cfg, str(chosen[lv].id))
				var other: Dictionary = {}
				for o in track.options:
					if str(o.id) != str(chosen[lv].id):
						other = o
				row.add_child(AdminUtil.label("Nv.%d — %s %s" % [lv, cur.get("icon", ""), cur.get("labelFr", "")], 15, UiTheme.PARCH))
				row.add_child(_hint(str(cur.get("descFr", ""))))
				if not other.is_empty():
					var cost := Talents.respec_cost(gs.cfg, lv)
					var rb := Button.new()
					rb.text = "🔄 %s %s — 💰%d" % [other.get("icon", ""), other.get("labelFr", ""), cost]
					rb.tooltip_text = str(other.get("descFr", ""))
					rb.disabled = gs.gold < cost
					rb.focus_mode = Control.FOCUS_NONE
					var oid2 := str(other.id)
					rb.pressed.connect(func():
						Talents.respec(gs, c, lv, oid2)
						on_change.call()
						rf.f.call())
					row.add_child(rb)
			body.add_child(row)
			body.add_child(HSeparator.new())
	render = rf.f
	render.call()
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	return m

static func _hint(text: String) -> Label:
	var l := AdminUtil.label(text, 13, UiTheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
