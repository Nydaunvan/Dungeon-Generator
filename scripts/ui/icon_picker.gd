class_name IconPicker
extends RefCounted
## Sélecteur d'icônes (images du jeu ou emojis) et de portraits, pour l'administration.

const PORTRAIT_CLASSES := [["Guerrier", "guerrier"], ["Mage", "mage"], ["Roublard", "roublard"], ["Archer", "archer"], ["Barde", "barde"], ["Prêtre", "pretre"]]

## Applique une icône (« @icon:xxx » ou emoji) à un bouton.
static func apply(btn: Button, icon: String, size: float = 40.0) -> void:
	btn.custom_minimum_size = Vector2(size + 12.0, size + 8.0)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	var tex: Texture2D = IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	btn.icon = tex
	btn.text = "" if tex != null else (icon if icon != "" else "—")
	btn.add_theme_font_size_override("font_size", int(size * 0.62))
	btn.add_theme_constant_override("icon_max_width", int(size))

## Bouton-icône qui ouvre le sélecteur ; `target[key]` reçoit le choix, `changed` est ensuite appelé.
static func button(host: Node, target: Dictionary, key: String, changed: Callable = Callable(), size: float = 40.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Choisir une icône"
	apply(b, str(target.get(key, "")), size)
	b.pressed.connect(func():
		open(host, str(target.get(key, "")), func(v: String):
			target[key] = v
			apply(b, v, size)
			if changed.is_valid():
				changed.call()))
	return b

static func _image_ids() -> Array:
	var seen := {}
	var out: Array = []
	var labels: Dictionary = Data.constants.get("ITEM_SPRITE_LABELS", {})
	for id in Data.constants.get("ITEM_SPRITE_LEGACY", {}):
		seen[id] = true
		out.append([str(id), str(id).replace("_", " ")])
	for id in Data.constants.get("REMAKE_MAP", {}):
		if not seen.has(id):
			seen[id] = true
			out.append([str(id), str(id).replace("_", " ")])
	var d := DirAccess.open("res://assets/icons")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".webp") or f.ends_with(".webp.import"):
				var id := f.get_basename().get_basename() if f.ends_with(".import") else f.get_basename()
				if not seen.has(id):
					seen[id] = true
					out.append([id, id.replace("_", " ")])
	for n in labels:
		var id := "spr_" + str(n)
		if not seen.has(id):
			seen[id] = true
			out.append([id, str(labels[n])])
	return out

static func open(host: Node, current: String, on_pick: Callable) -> Modal:
	var m := Modal.open(host, "Choisir une icône", 560.0)
	var state := {"tab": "image" if current.begins_with("@icon:") or current == "" else "emoji", "q": ""}
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher…"
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.custom_minimum_size = Vector2(500, 0)
	var images := _image_ids()
	var emojis: Array = Data.constants.get("ICON_LIBRARY", [])
	var pick := func(v: String):
		on_pick.call(v)
		m.close()
	var fill := Callable()
	fill = func():
		for ch in grid.get_children():
			ch.queue_free()
		var q := str(state.q).strip_edges().to_lower()
		var n := 0
		if state.tab == "image":
			for it in images:
				if q != "" and not (str(it[0]).to_lower().contains(q) or str(it[1]).to_lower().contains(q)):
					continue
				var v := "@icon:" + str(it[0])
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.tooltip_text = str(it[1])
				apply(b, v, 44.0)
				b.pressed.connect(func(): pick.call(v))
				grid.add_child(b)
				n += 1
		else:
			for it in emojis:
				if q != "" and not (str(it.get("n", "")).to_lower().contains(q)):
					continue
				var v := str(it.get("i", ""))
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.tooltip_text = str(it.get("n", ""))
				apply(b, v, 40.0)
				b.pressed.connect(func(): pick.call(v))
				grid.add_child(b)
				n += 1
		if n == 0:
			var l := Label.new()
			l.text = "Aucune icône ne correspond."
			grid.add_child(l)
	var group := ButtonGroup.new()
	for t in [["image", "Images du jeu"], ["emoji", "Emojis"]]:
		var tb := Button.new()
		tb.text = t[1]
		tb.toggle_mode = true
		tb.button_group = group
		tb.focus_mode = Control.FOCUS_NONE
		tb.button_pressed = state.tab == t[0]
		var id: String = t[0]
		tb.pressed.connect(func():
			state.tab = id
			fill.call())
		tabs.add_child(tb)
	search.text_changed.connect(func(t: String):
		state.q = t
		fill.call())
	m.content.add_child(tabs)
	m.content.add_child(search)
	m.content.add_child(grid)
	fill.call()
	var btns: Array = [{"text": "Fermer", "cb": func(): m.close()}]
	m.set_buttons(btns)
	return m

## Sélecteur de portraits (images assets/portraits) ; `on_pick` reçoit le chemin ou "" (portrait par défaut de la classe).
static func open_portrait(host: Node, current: String, on_pick: Callable) -> Modal:
	var m := Modal.open(host, "Choisir un portrait", 560.0)
	var pick := func(v: String):
		on_pick.call(v)
		m.close()
	for pc in PORTRAIT_CLASSES:
		m.add_text(str(pc[0]), UiTheme.GOLD, 16)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.custom_minimum_size = Vector2(500, 0)
		var i := 0
		while ResourceLoader.exists("res://assets/portraits/%s_%d.webp" % [pc[1], i]):
			var path := "res://assets/portraits/%s_%d.webp" % [pc[1], i]
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.icon = load(path)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 72)
			b.custom_minimum_size = Vector2(84, 84)
			if path == current:
				b.disabled = true
			b.pressed.connect(func(): pick.call(path))
			grid.add_child(b)
			i += 1
		m.content.add_child(grid)
	m.set_buttons([{"text": "Portrait par défaut", "cb": func(): pick.call("")}, {"text": "Fermer", "cb": func(): m.close()}])
	return m
