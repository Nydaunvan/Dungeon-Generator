class_name SlotsModal
extends RefCounted
## Fenêtre des 10 emplacements de sauvegarde : charger, sauvegarder / écraser, supprimer (l'export / import de fichier est dans le menu 💾).

## `snapshot` : () -> {"config", "save", "origin"} (vide hors partie). `on_load` reçoit {"config", "save", "origin", "log"}.
## `opts` (facultatif) : "log" (Callable(texte) : ajoute une ligne au journal de la partie), "status" (Callable(texte) : état du menu 💾),
## "current_origin" (provenance de la partie en cours, pour « · différent du contexte actuel »).
static func open(host: Node, snapshot: Callable, on_load: Callable, on_saved: Callable = Callable(), opts: Dictionary = {}) -> Modal:
	var vp: Vector2 = host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	var m := Modal.open_framed(host, L.t("common.emplacements_de_sauvegarde"), clampf(vp.x * 0.94, 320.0, 880.0))
	m.fit_ratio = 0.84
	var can_save := snapshot.is_valid()
	var wide := vp.x >= 760.0
	var list := GridContainer.new()
	list.columns = 2 if wide else 1
	list.add_theme_constant_override("h_separation", 10)
	list.add_theme_constant_override("v_separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(list)
	var state := {"busy": false}
	var fill := Callable()
	fill = func():
		for ch in list.get_children():
			ch.queue_free()
		for i in Saves.SLOTS:
			list.add_child(_row(i, can_save, snapshot, on_load, m, fill, on_saved, opts, list, state))
	fill.call()
	return m

static func _say(opts: Dictionary, key: String, text: String) -> void:
	var cb: Callable = opts.get(key, Callable())
	if cb.is_valid():
		cb.call(text)

static func _row(i: int, can_save: bool, snapshot: Callable, on_load: Callable, m: Modal, fill: Callable, on_saved: Callable, opts: Dictionary, list: Control, state: Dictionary) -> Control:
	var sm := Saves.summary(i)
	var panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()    # .slot-row : fond rgba(255,255,255,.03), filet #5a4526, coins 8 px, padding 12/14
	rsb.bg_color = Color(1, 1, 1, 0.03)
	rsb.border_color = Color("5a4526")
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(8)
	rsb.content_margin_left = 12
	rsb.content_margin_right = 12
	rsb.content_margin_top = 9
	rsb.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", rsb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sm.is_empty():
		panel.modulate = Color(1, 1, 1, 0.6)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	outer.add_child(row)
	if sm.is_empty():
		info.add_child(_title(L.fa(L.t("common.emplacement"), (i + 1))))
		info.add_child(_hint(L.t("ui.slots_modal.vide")))
	else:
		info.add_child(_title(L.fa(L.t("ui.slots_modal.emplacement"), [i + 1, sm.title])))
		var origin_text := Saves.origin_label(sm.origin)
		var cur := str(opts.get("current_origin", ""))
		if cur != "" and cur != str(sm.origin):
			origin_text += L.t("ui.slots_modal.different_du_contexte_actuel")
		info.add_child(_hint("%s · %s" % [origin_text, sm.party]))
		info.add_child(_hint(Saves.local_date(float(sm.savedAt))))
	var save_here := func():
		if bool(state.busy):
			return
		state.busy = true
		_save_with_feedback(i, snapshot, m, fill, on_saved, opts, list, state)
	if not sm.is_empty():
		var lb := Button.new()
		lb.text = L.t("ui.slots_modal.charger")
		lb.focus_mode = Control.FOCUS_NONE
		_style(lb, true)
		lb.pressed.connect(func():
			var d := Saves.read_slot(i)
			if d.is_empty() or not (d.get("save") is Dictionary):
				if (opts.get("log", Callable()) as Callable).is_valid():
					_say(opts, "log", L.t("ui.slots_modal.erreur_lors_du_chargement_de"))
				else:
					Form.alert(m.get_parent(), L.t("ui.slots_modal.erreur_lors_du_chargement_de"))
				return
			m.close()
			var ranked_save: bool = str((d.save as Dictionary).get("run_seed", "")) != ""
			on_load.call({"config": d.get("config", {}), "save": d.save, "origin": str(d.get("dungeonOrigin", "random")),
				"log": L.fa(L.t("ui.slots_modal.partie_chargee_depuis_l_emplacement"), (i + 1))})
			# partie classée : la sauvegarde est une pause à usage unique (pas de retour en arrière en rechargeant)
			if ranked_save:
				Saves.delete_slot(i))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lb)
	if sm.is_empty() and not can_save:
		row.add_child(_hint("—"))
	if can_save:
		var sb := Button.new()
		sb.text = L.t("ui.slots_modal.ecraser") if not sm.is_empty() else L.t("ui.slots_modal.sauver_ici")
		sb.focus_mode = Control.FOCUS_NONE
		_style(sb, sm.is_empty())
		sb.pressed.connect(save_here)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sb)
	if not sm.is_empty():
		var db := Button.new()
		db.text = "🗑"
		db.focus_mode = Control.FOCUS_NONE
		_style(db, false, true)
		db.pressed.connect(func():
			Dialogs.confirm(m.get_parent(), "", L.fa(L.t("ui.slots_modal.supprimer_definitivement_la_sauvegarde"), (i + 1)), func():
				Saves.delete_slot(i)
				fill.call()))
		row.add_child(db)
	return panel

## Sauvegarde avec retour visuel : sablier pendant l'écriture, puis confirmation « Sauvegarde effectuée » avant de continuer.
static func _save_with_feedback(i: int, snapshot: Callable, m: Modal, fill: Callable, on_saved: Callable, opts: Dictionary, list: Control, state: Dictionary) -> void:
	list.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 190)
	m.content.add_child(box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 110)
	box.add_child(holder)
	var hg := LoadingScreen.Hourglass.new()
	hg.scale = Vector2.ONE * 1.2
	holder.add_child(hg)
	holder.resized.connect(func(): hg.position = Vector2((holder.size.x - 56.0 * 1.2) * 0.5, 6.0))
	var msg := HubKit.label(L.fa(L.t("ui.slots_modal.sauvegarde_en_cours"), i + 1), UiTheme.PARCH, 18, true, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(msg)
	m.call_deferred("_fit")
	var tree := m.get_tree()
	await tree.create_timer(0.7).timeout       # le sablier reste visible un instant, même si l'écriture est immédiate
	if not is_instance_valid(m):
		return
	var snap: Dictionary = snapshot.call()
	var t := Time.get_time_dict_from_system()
	var ok := Saves.write_slot(i, snap.config, snap.save, snap.origin)
	hg.queue_free()
	if ok:
		_say(opts, "log", L.fa(L.t("ui.slots_modal.partie_sauvegardee_dans_l_emplacement"), (i + 1)))
		_say(opts, "status", L.fa(L.t("ui.slots_modal.sauvegarde_a_02d_02d_02d"), [t.hour, t.minute, t.second]))
		msg.text = L.fa(L.t("ui.slots_modal.sauvegarde_effectuee"), i + 1)
		msg.add_theme_color_override("font_color", HubKit.GOOD)
		var tick := HubKit.label("💾", HubKit.GOOD, 54, false, false, HORIZONTAL_ALIGNMENT_CENTER)
		holder.add_child(tick)
		tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		UiFx.pop_in(tick, 0.2)
		await tree.create_timer(1.1).timeout
	else:
		_say(opts, "log", L.t("ui.slots_modal.la_sauvegarde_a_echoue"))
		_say(opts, "status", L.t("ui.slots_modal.echec_de_la_sauvegarde"))
		msg.text = L.t("ui.slots_modal.la_sauvegarde_a_echoue")
		msg.add_theme_color_override("font_color", HubKit.BAD)
		await tree.create_timer(1.6).timeout
	if not is_instance_valid(m):
		return
	state.busy = false
	if ok and on_saved.is_valid():
		m.close()
		on_saved.call(i)
		return
	box.queue_free()
	list.visible = true
	fill.call()
	m.call_deferred("_fit")

static func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	l.add_theme_color_override("font_color", Color("ffd88a"))
	return l

static func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.75)))
	l.add_theme_color_override("font_color", UiTheme.DIM)
	return l

## Boutons de ligne : dégradé brun, filet or (primary) ou rouge (suppression), coins 6 px.
static func _style(b: Button, primary: bool, danger: bool = false) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var hot: bool = st == "hover"
		sb.bg_color = Color("3a2b18") if not hot else Color("4e3a1f")
		if danger:
			sb.bg_color = Color("3a1612") if not hot else Color("55201a")
		sb.border_color = Color("c9a15a") if primary else (Color("b04a3a") if danger else Color("8a6a36"))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
