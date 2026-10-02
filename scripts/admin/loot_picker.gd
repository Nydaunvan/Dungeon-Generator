class_name LootPicker
extends RefCounted
## Sélecteur de butin de l'original (`openLootPicker`, `#lootPickerOverlay`) : titre « 🎁 Choisir un butin », champ de recherche,
## liste défilante (280 px max) avec la ligne « — Aucun — » puis TOUS les objets du niveau (décors inclus) filtrés par nom, bouton « Fermer ».

static func open(host: Node, items: Array, on_pick: Callable) -> Modal:
	var m := Modal.open(host, "🎁 Choisir un butin", 340.0)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher un objet..."
	m.content.add_child(search)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color("5a4526")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	m.content.add_child(frame)
	var pick := func(id: String):
		on_pick.call(id)
		m.close()
	var fill := func(filter: String):
		for ch in list.get_children():
			list.remove_child(ch)
			ch.queue_free()
		var f := filter.strip_edges().to_lower()
		list.add_child(_row(null, "— Aucun —", func(): pick.call("")))
		var n := 0
		for it in items:
			if f != "" and not str(it.get("name", "")).to_lower().contains(f):
				continue
			n += 1
			var iid: String = str(it.id)
			list.add_child(_row(it, str(it.get("name", "")), func(): pick.call(iid)))
		if n == 0 and f != "":
			var h := Form.hint(list, "Aucun objet ne correspond.")
			h.add_theme_constant_override("line_spacing", 0)
	search.text_changed.connect(func(t: String): fill.call(t))
	fill.call("")
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])
	search.call_deferred("grab_focus")
	return m

static func _row(it, text: String, cb: Callable) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.border_color = Color("5a4526")
	n.border_width_bottom = 1
	n.content_margin_left = 10
	n.content_margin_right = 10
	n.content_margin_top = 8
	n.content_margin_bottom = 8
	var h := n.duplicate()
	h.bg_color = Color(1, 1, 1, 0.05)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UiTheme.PARCH)
	b.add_theme_color_override("font_hover_color", UiTheme.PARCH)
	b.text = text
	if it != null:
		var icon := str(it.get("icon", ""))
		if icon.begins_with("@icon:"):
			var tex: Texture2D = IconResolver.texture(icon)
			if tex != null:
				b.icon = tex
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 18)
				b.add_theme_constant_override("h_separation", 6)
			else:
				b.text = "❓ " + text
		elif icon != "":
			b.text = icon + " " + text
	b.pressed.connect(cb)
	return b
