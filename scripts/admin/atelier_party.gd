class_name AtelierParty
extends RefCounted
## Section « Groupe et objets » : les héros de départ et la bibliothèque d'objets de base, réunis sous un même titre
## avec un sélecteur à deux sous-onglets.

## Sous-onglet affiché : "party" (groupe de départ) ou "items" (objets de base).
static var sub := "party"

static func build(host: VBoxContainer, admin: Node) -> void:
	var row := Atelier.page_header(host, "party")
	row.add_child(_switch(admin))
	if sub == "items":
		AdminItems.build(host, admin)
	else:
		AdminChars.build(host, admin)

## Sélecteur segmenté (deux boutons dans un cadre sombre).
static func _switch(admin: Node) -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("14100a")
	sb.border_color = Color("3a2c18")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	frame.add_child(h)
	for t in [["party", L.t("ui.atelier.tab_party")], ["items", L.t("ui.atelier.tab_items")]]:
		var id: String = t[0]
		var b := Button.new()
		b.text = str(t[1])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 13)
		var on := sub == id
		var clear := Color(0, 0, 0, 0)
		for k in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.set_corner_radius_all(9)
			s.content_margin_left = 18
			s.content_margin_right = 18
			s.bg_color = Color("e8b45c") if on else (Color(1, 1, 1, 0.05) if k == "hover" else clear)
			b.add_theme_stylebox_override(k, s)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color("2a1a06") if on else Color("b8a781"))
		b.pressed.connect(func():
			if sub != id:
				sub = id
				admin.refresh_tab())
		h.add_child(b)
	return frame
