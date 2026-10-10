class_name LeaveModal
extends RefCounted
## Boîte « Quitter la partie » : un en-tête court puis des cartes d'options côte à côte (une colonne sur petit écran), chacune avec son
## icône, ce qu'elle entraîne et son bouton. Sert à la partie libre comme à la partie classée.

## `header` : [[texte, couleur, taille], …]. `options` : [{"icon", "title", "desc", "btn", "primary", "danger", "cb", "extra"}] ;
## `extra` (Callable(VBoxContainer)) ajoute du contenu à la carte (ex. code à partager) ; sans `btn`, pas de bouton.
static func open(host: Node, title: String, header: Array, options: Array, stay_text: String) -> Modal:
	var vp: Vector2 = host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	var width := clampf(vp.x * 0.94, 320.0, 780.0)
	var m := Modal.open(host, title, width)
	m.fit_ratio = 0.84
	for h in header:
		var l := m.add_text(str(h[0]), h[1], int(h[2]), true)
		l.custom_minimum_size.x = 0
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cols := 1
	if width >= 600.0:
		cols = mini(options.size(), 3) if options.size() != 4 else 2
	var grid := GridContainer.new()
	grid.columns = maxi(cols, 1)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(grid)
	for o in options:
		grid.add_child(_card(o, m, cols == 1))
	m.set_buttons([{"text": stay_text, "primary": false, "cb": func(): m.close()}])
	return m

static func _card(o: Dictionary, m: Modal, compact: bool) -> Control:
	var danger := bool(o.get("danger", false))
	var border: Color = Color("b04a3a") if danger else (UiTheme.GOLD if bool(o.get("primary", false)) else UiTheme.BRONZE_DARK)
	var card := HubKit.card(border, HubKit.CARD_BG, 12)
	var v := HubKit.vbox(6)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var ic := HubKit.label(str(o.get("icon", "")), UiTheme.PARCH, 26, false, false, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_child(ic)
	head.add_child(HubKit.label(str(o.get("title", "")), Color("ff9c8a") if danger else UiTheme.GOLD, 16, true))
	var d := HubKit.label(str(o.get("desc", "")), UiTheme.DIM if not danger else Color("e0b0a0"), 13)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	if o.has("extra"):
		(o.extra as Callable).call(v)
	if o.has("btn"):
		var cb: Callable = o.get("cb", Callable())
		v.add_child(HubKit.button(str(o.btn), func():
			m.close()
			if cb.is_valid():
				cb.call(), bool(o.get("primary", false)), 38))
	return card
