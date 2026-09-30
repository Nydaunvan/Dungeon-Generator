class_name SlotsModal
extends RefCounted
## Fenêtre des 10 emplacements de sauvegarde : charger, sauvegarder / écraser, supprimer, exporter / importer un fichier.

## `snapshot` : () -> {"config", "save", "origin"} (vide hors partie). `on_load` reçoit {"config", "save", "origin"}.
static func open(host: Node, snapshot: Callable, on_load: Callable, on_saved: Callable = Callable()) -> Modal:
	var m := Modal.open(host, "Sauvegardes", 640.0)
	var can_save := snapshot.is_valid()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if sm.is_empty():
		info.add_child(AdminUtil.label("Emplacement %d" % (i + 1), 16, UiTheme.GOLD))
		info.add_child(AdminUtil.label("Vide", 13, UiTheme.DIM))
	else:
		info.add_child(AdminUtil.label("Emplacement %d — %s" % [i + 1, sm.title], 16, UiTheme.GOLD))
		var when := Time.get_datetime_string_from_unix_time(int(sm.savedAt / 1000.0), true) if sm.savedAt > 0 else ""
		for t in [Saves.origin_label(sm.origin), sm.party, when]:
			var l := AdminUtil.label(str(t), 13, UiTheme.DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(l)
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
		lb.pressed.connect(func():
			var d := Saves.read_slot(i)
			if d.is_empty() or not (d.get("save") is Dictionary):
				status.text = "Emplacement illisible."
				return
			m.close()
			on_load.call({"config": d.get("config", {}), "save": d.save, "origin": str(d.get("dungeonOrigin", "random"))}))
		row.add_child(lb)
	if can_save:
		var sb := Button.new()
		sb.text = "💾 Écraser" if not sm.is_empty() else "💾 Sauver ici"
		sb.focus_mode = Control.FOCUS_NONE
		sb.pressed.connect(save_here)
		row.add_child(sb)
	if not sm.is_empty():
		var db := Button.new()
		db.text = "🗑"
		db.focus_mode = Control.FOCUS_NONE
		db.pressed.connect(func():
			Dialogs.confirm(m.get_parent(), "Supprimer", "Supprimer définitivement la sauvegarde de l'emplacement %d ?" % (i + 1), func():
				Saves.delete_slot(i)
				fill.call(), "Supprimer"))
		row.add_child(db)
	return panel
