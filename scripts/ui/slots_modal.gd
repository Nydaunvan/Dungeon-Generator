class_name SlotsModal
extends RefCounted
## Fenêtre des 10 emplacements de sauvegarde : charger, sauvegarder / écraser, supprimer, exporter / importer un fichier.

## `snapshot` : () -> {"config", "save", "origin"} (vide hors partie). `on_load` reçoit {"config", "save", "origin"}.
static func open(host: Node, snapshot: Callable, on_load: Callable, on_saved: Callable = Callable()) -> Modal:
	var m := Modal.open_framed(host, "💾 Emplacements de sauvegarde", 560.0)
	var can_save := snapshot.is_valid()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	m.content.add_child(scroll)
	var status := AdminUtil.label("", 14, UiTheme.DIM)
	m.content.add_child(status)
	var fill := Callable()
	fill = func():
		for ch in list.get_children():
			ch.queue_free()
		for i in Saves.SLOTS:
			list.add_child(_row(i, can_save, snapshot, on_load, m, fill, status, on_saved))
	fill.call()
	var btns: Array = []
	if can_save:
		btns.append({"text": "Exporter (JSON)", "cb": func():
			var snap: Dictionary = snapshot.call()
			Files.save_text(host, "sauvegarde.json", Saves.export_text(snap.config, snap.save, snap.origin), func(t): status.text = t)})
	btns.append({"text": "Importer (JSON)", "cb": func():
		Files.pick_text(host, func(text: String):
			var data := Saves.parse_import(text)
			if data.is_empty() or data.save.is_empty():
				status.text = "Ce fichier ne contient pas de sauvegarde reconnue."
				return
			m.close()
			on_load.call(data))})
	btns.append({"text": "Fermer", "cb": func(): m.close()})
	m.set_buttons(btns)
	return m

static func _row(i: int, can_save: bool, snapshot: Callable, on_load: Callable, m: Modal, fill: Callable, status: Label, on_saved: Callable) -> Control:
	var sm := Saves.summary(i)
	var panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()    # .slot-row : fond rgba(255,255,255,.03), filet #5a4526, coins 8 px, padding 12/14
	rsb.bg_color = Color(1, 1, 1, 0.03)
	rsb.border_color = Color("5a4526")
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(8)
	rsb.content_margin_left = 14
	rsb.content_margin_right = 14
	rsb.content_margin_top = 12
	rsb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", rsb)
	if sm.is_empty():
		panel.modulate = Color(1, 1, 1, 0.6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if sm.is_empty():
		info.add_child(_title("Emplacement %d" % (i + 1)))
		info.add_child(_hint("Vide"))
	else:
		info.add_child(_title("Emplacement %d — %s" % [i + 1, sm.title]))
		var when := Time.get_datetime_string_from_unix_time(int(sm.savedAt / 1000.0), true) if sm.savedAt > 0 else ""
		for t in [Saves.origin_label(sm.origin), sm.party, when]:
			info.add_child(_hint(str(t)))
	var save_here := func():
		var snap: Dictionary = snapshot.call()
		if Saves.write_slot(i, snap.config, snap.save, snap.origin):
			status.text = "Partie sauvegardée dans l'emplacement %d." % (i + 1)
			if on_saved.is_valid():
				on_saved.call(i)
		else:
			status.text = "La sauvegarde a échoué."
		fill.call()
	if not sm.is_empty():
		var lb := Button.new()
		lb.text = "📂 Charger"
		lb.focus_mode = Control.FOCUS_NONE
		_style(lb, true)
		lb.pressed.connect(func():
			var d := Saves.read_slot(i)
			if d.is_empty() or not (d.get("save") is Dictionary):
				status.text = "Emplacement illisible."
				return
			m.close()
			on_load.call({"config": d.get("config", {}), "save": d.save, "origin": str(d.get("dungeonOrigin", "random"))}))
		row.add_child(lb)
	if sm.is_empty() and not can_save:
		row.add_child(_hint("—"))
	if can_save:
		var sb := Button.new()
		sb.text = "💾 Écraser" if not sm.is_empty() else "💾 Sauver ici"
		sb.focus_mode = Control.FOCUS_NONE
		_style(sb, sm.is_empty())
		sb.pressed.connect(save_here)
		row.add_child(sb)
	if not sm.is_empty():
		var db := Button.new()
		db.text = "🗑"
		db.focus_mode = Control.FOCUS_NONE
		_style(db, false, true)
		db.pressed.connect(func():
			Dialogs.confirm(m.get_parent(), "Supprimer", "Supprimer définitivement la sauvegarde de l'emplacement %d ?" % (i + 1), func():
				Saves.delete_slot(i)
				fill.call(), "Supprimer"))
		row.add_child(db)
	return panel

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
