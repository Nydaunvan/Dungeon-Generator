class_name TalentModals
extends RefCounted
## Fenêtres des talents et de l'évolution de classe : choix au passage de niveau, Maître des Talents du village.

## Présente le premier choix en attente (talent ou évolution) s'il n'y a pas de fenêtre ouverte. `on_change` est appelé après chaque choix.
static func process_queue(host: Node, gs: GameState, on_change: Callable) -> void:
	if gs.choice_queue.is_empty():
		return
	for n in host.get_tree().get_nodes_in_group("modal"):
		if not n.is_queued_for_deletion():
			return
	var q: Dictionary = gs.choice_queue.pop_front()
	var c := gs.char_by_id(str(q.char_id))
	if c.is_empty():
		process_queue(host, gs, on_change)
		return
	var done := func():
		on_change.call()
		process_queue(host, gs, on_change)
	if q.kind == "evolve":
		_evolution(host, gs, c, done)
	else:
		var track := Talents.track_at(gs.cfg, str(c.classId), int(q.level))
		if track.is_empty() or (c.get("talents", []) as Array).any(func(t): return int(t.level) == int(q.level)):
			process_queue(host, gs, on_change)
			return
		_talent(host, gs, c, track, done)

static func _talent(host: Node, gs: GameState, c: Dictionary, track: Dictionary, done: Callable) -> void:
	var m := Modal.open(host, "🌟 Nouveau talent", 440.0)
	m.esc_closes = false
	m.add_text("%s atteint le niveau %d ! Choisissez un talent :" % [c.name, int(track.level)])
	for o in track.options:
		var oid := str(o.id)
		var b := m.add_button("%s %s\n%s" % [o.get("icon", ""), o.get("labelFr", ""), o.get("descFr", Talents.effect_label(o.get("effects", {})))], func():
			m.close()
			Talents.choose(gs, c, int(track.level), oid)
			if int(c.hp) > int(c.maxHp):
				c["hp"] = c.maxHp
			done.call())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
	m.set_buttons([])

static func _evolution(host: Node, gs: GameState, c: Dictionary, done: Callable) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.classId))
	var m := Modal.open(host, "⭐ Évolution de classe", 440.0)
	m.esc_closes = false
	m.add_text("%s a atteint le niveau requis pour évoluer. Choisissez une voie :" % c.name)
	for cid in cls.get("evolvesTo", []):
		var oc := Characters.class_def(gs.cfg, str(cid))
		if oc.is_empty():
			continue
		var id := str(cid)
		var b := m.add_button("%s %s\n%s" % [oc.get("icon", ""), oc.get("name", ""), oc.get("descFr", "")], func():
			m.close()
			Talents.evolve(gs, c, id)
			done.call())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
	m.set_buttons([])

# ------------------------------------------------------------------ Maître des Talents (village)

static func master(host: Node, gs: GameState, on_change: Callable) -> Modal:
	var m := Modal.open(host, "Le Maître des Talents", 640.0)
	var st := {"who": str(gs.party[0].id) if not gs.party.is_empty() else ""}
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var tabs := AdminUtil.flow(m.content)
	m.content.add_child(body)
	var render := Callable()
	render = func():
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
				render.call())
			tabs.add_child(tb)
		var c := gs.char_by_id(str(st.who))
		if c.is_empty():
			return
		body.add_child(_hint("Le Maître des Talents affiche tous les paliers de talent de ce personnage : à débloquer plus tard (grisé), à choisir pour la première fois (gratuit), ou déjà choisi (peut être changé pour l'autre option, contre une somme conséquente)."))
		body.add_child(AdminUtil.label("💰 Or disponible : %d" % gs.gold, 15, UiTheme.GOLD))
		body.add_child(AdminUtil.label("%s %s — Nv.%d" % [c.get("icon", ""), c.name, int(c.level)], 17, UiTheme.GOLD))
		var trs := Talents.tracks(gs.cfg, str(c.classId))
		if trs.is_empty():
			body.add_child(_hint("Cette classe ne dispose d'aucun talent configuré."))
			return
		var chosen := {}
		for t in c.get("talents", []):
			chosen[int(t.level)] = t
		for track in trs:
			var lv := int(track.level)
			var row := VBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			if int(c.level) < lv:
				row.add_child(AdminUtil.label("Nv.%d — 🔒 Verrouillé (débloqué à ce niveau de personnage)" % lv, 14, UiTheme.DIM))
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
						render.call())
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
						render.call())
					row.add_child(rb)
			body.add_child(row)
			body.add_child(HSeparator.new())
	render.call()
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])
	return m

static func _hint(text: String) -> Label:
	var l := AdminUtil.label(text, 13, UiTheme.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
