class_name IconPicker
extends RefCounted
## Sélecteur d'icônes (emoji ou icônes illustrées) et de portraits pour l'administration — `openIconPicker`,
## `renderIconPickerGrid` et `openPortraitPicker` de l'original. Le catalogue illustré vient de `ICON_CATALOG`
## (data/game_constants.json), dans l'ordre de l'original, jamais d'un parcours de dossier.

const PORTRAIT_CLASSES := [["Guerrier", "guerrier"], ["Mage", "mage"], ["Roublard", "roublard"], ["Archer", "archer"], ["Barde", "barde"], ["Prêtre", "pretre"]]

const SWATCH_BG := Color("1c1610")
const BORDER := Color("5a4526")
const GOLD_DIM := Color("a9793a")
const GOLD_BRIGHT := Color("ffd88a")

## Onglet mémorisé d'une ouverture à l'autre (`iconPickerTab`) : « emoji » par défaut.
static var _tab: String = "emoji"
static var _catalog: Array = []
static var _styles: Dictionary = {}

# ------------------------------------------------------------------ styles

## Boîte des boutons-icônes : fond #1c1610, filet #5a4526, rayon 6 ; `hover` : filet or sombre (+ halo pour les pastilles) ;
## `on` : portrait courant (filet or vif + halo de 2 px).
static func swatch_box(kind: String = "normal") -> StyleBoxFlat:
	if _styles.has(kind):
		return _styles[kind]
	var s := StyleBoxFlat.new()
	s.bg_color = SWATCH_BG
	s.border_color = BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	match kind:
		"hover":
			s.border_color = GOLD_DIM
		"glow":
			s.border_color = GOLD_DIM
			s.shadow_color = Color(0.91, 0.71, 0.36, 0.35)
			s.shadow_size = 8
		"on":
			s.border_color = GOLD_BRIGHT
			s.shadow_color = Color(0.91, 0.71, 0.36, 0.5)
			s.shadow_size = 2
	_styles[kind] = s
	return s

static func _style_button(btn: Button, hover_kind: String = "hover") -> void:
	btn.add_theme_stylebox_override("normal", swatch_box("normal"))
	btn.add_theme_stylebox_override("hover", swatch_box(hover_kind))
	btn.add_theme_stylebox_override("pressed", swatch_box(hover_kind))
	btn.add_theme_stylebox_override("focus", swatch_box("normal"))
	btn.add_theme_stylebox_override("disabled", swatch_box("normal"))

# ------------------------------------------------------------------ affichage d'une icône

## Applique une icône (« @icon:xxx » ou emoji) à un bouton-icône (`.icon-pick-btn`, 38×38 par défaut).
## Icône illustrée inconnue : « ❓ » ; icône vide : rien.
static func apply(btn: Button, icon: String, size: float = 38.0) -> void:
	btn.custom_minimum_size = Vector2(UiMetrics.css(size), UiMetrics.css(size))
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_button(btn)
	var tex: Texture2D = IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	btn.icon = tex
	if tex != null:
		btn.text = ""
	elif icon.begins_with("@icon:"):
		btn.text = "❓"
	else:
		btn.text = icon
	btn.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.3) * size / 38.0))
	btn.add_theme_constant_override("icon_max_width", int(UiMetrics.css(size * 0.75)))

## Petit contrôle d'affichage d'une icône (image ou emoji), non cliquable.
static func icon_control(icon: String, size: float = 36.0) -> Control:
	var tex: Texture2D = IconResolver.texture(icon) if icon.begins_with("@icon:") else null
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(size, size)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var l := Label.new()
	l.text = "❓" if icon.begins_with("@icon:") else icon
	l.custom_minimum_size = Vector2(size, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Bouton-icône qui ouvre le sélecteur ; `target[key]` reçoit le choix, `changed` est ensuite appelé.
static func button(host: Node, target: Dictionary, key: String, changed: Callable = Callable(), size: float = 38.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply(b, str(target.get(key, "")), size)
	b.pressed.connect(func():
		open(host, str(target.get(key, "")), func(v: String):
			target[key] = v
			apply(b, v, size)
			if changed.is_valid():
				changed.call()))
	return b

# ------------------------------------------------------------------ catalogue illustré

## Recherche sans accents ni majuscules (`normalizeSearch`).
static func normalize(s: String) -> String:
	var t := s.to_lower()
	for pair in [["àâäá", "a"], ["çč", "c"], ["éèêë", "e"], ["îïí", "i"], ["ôöó", "o"], ["ùûüú", "u"], ["ÿý", "y"], ["ñ", "n"], ["œ", "oe"], ["æ", "ae"]]:
		for ch in str(pair[0]):
			t = t.replace(ch, str(pair[1]))
	return t

## Catalogue dans l'ordre d'affichage de l'original : catégories du spec (hors « Monstres » et « Boss », ajoutées en dernier
## car leurs vignettes sont chargées après), « Planche d'objets » (spr_N), « Monstres (planche) », puis Monstres et Boss.
## Renvoie [[catégorie, [[id, libellé], …]], …].
static func catalog() -> Array:
	if not _catalog.is_empty():
		return _catalog
	var consts: Dictionary = Data.constants
	var light: Array = []
	var heavy: Array = []
	for c in consts.get("ICON_CATALOG", []):
		var l: Array = []
		var h: Array = []
		for e in c[1]:
			if (e as Array).size() > 2:
				h.append([e[0], e[1]])
			else:
				l.append([e[0], e[1]])
		if not l.is_empty():
			light.append([c[0], l])
		if not h.is_empty():
			heavy.append([c[0], h])
	var out: Array = light
	var labels: Dictionary = consts.get("ITEM_SPRITE_LABELS", {})
	var keys: Array = labels.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var spr: Array = []
	for k in keys:
		spr.append(["spr_" + str(k), str(labels[k])])
	if not spr.is_empty():
		out.append(["Planche d'objets", spr])
	var mlabels: Dictionary = consts.get("MONSTER_SPRITE_LABELS", {})
	var mons: Array = []
	for i in IconResolver.NEW_MONSTER_IDS.size():
		mons.append([IconResolver.NEW_MONSTER_IDS[i], str(mlabels.get(str(i), IconResolver.NEW_MONSTER_IDS[i]))])
	out.append(["Monstres (planche)", mons])
	out.append_array(heavy)
	_catalog = out
	return out

# ------------------------------------------------------------------ grille auto-ajustée (`repeat(auto-fill, minmax(…, 1fr))`)

class AutoGrid extends Container:
	signal laid_out(height: float)
	var min_cell: float = 52.0
	var gap: float = 6.0
	var pad: float = 4.0
	## true : la cellule remplit sa colonne et reste carrée (portraits) ; false : la pastille garde sa taille, alignée à gauche.
	var fill_cells: bool = false
	var _last_h: float = -1.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			_layout()

	func _layout() -> void:
		var w := size.x - 2.0 * pad
		if w <= 0.0:
			return
		var n := maxi(1, int(floor((w + gap) / (min_cell + gap))))
		var cw := (w - float(n - 1) * gap) / float(n)
		var y := pad
		var col := 0
		var row_h := 0.0
		for ch in get_children():
			if not (ch is Control) or not (ch as Control).visible:
				continue
			var c := ch as Control
			if c.has_meta("full"):
				if col > 0:
					y += row_h + gap
					col = 0
					row_h = 0.0
				var hh := c.get_combined_minimum_size().y
				fit_child_in_rect(c, Rect2(pad, y, w, hh))
				y += hh + gap
				continue
			var ms := c.get_combined_minimum_size()
			var cs := Vector2(cw, cw) if fill_cells else ms
			fit_child_in_rect(c, Rect2(pad + float(col) * (cw + gap), y, cs.x, cs.y))
			row_h = maxf(row_h, cs.y)
			col += 1
			if col >= n:
				y += row_h + gap
				col = 0
				row_h = 0.0
		if col > 0:
			y += row_h + gap
		var total := maxf(0.0, y - gap) + pad
		if not is_equal_approx(total, _last_h):
			_last_h = total
			custom_minimum_size.y = total
			laid_out.emit(total)

static func _tab_button(text: String, on: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.78)))
	b.custom_minimum_size = Vector2(0, UiMetrics.css(34.0))
	_mark_tab(b, on)
	return b

static func _mark_tab(b: Button, on: bool) -> void:
	if on:
		var st := IronBox.modal_styles(true)
		for k in st:
			b.add_theme_stylebox_override(k, st[k])
		b.add_theme_color_override("font_color", GOLD_BRIGHT)
		b.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	else:
		for k in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.remove_theme_stylebox_override(k)
		b.remove_theme_color_override("font_color")
		b.remove_theme_color_override("font_hover_color")

## En-tête de catégorie `.ip-cathdr` : capitales 0,68 rem, or sombre, filet #5a4526 dessous, 8 px au-dessus.
static func _category_header(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(UiMetrics.css(8.0)))
	m.set_meta("full", true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiMetrics.css(3.0)))
	m.add_child(v)
	var l := Label.new()
	l.text = text.to_upper()
	var fv := FontVariation.new()
	fv.base_font = UiTheme.font(UiTheme.F_BODY)
	fv.spacing_glyph = 1
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.68)))
	l.add_theme_color_override("font_color", GOLD_DIM)
	v.add_child(l)
	var line := ColorRect.new()
	line.color = BORDER
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	return m

static func _swatch(icon_value: String, tip: String, size_emoji: bool, on_pick: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(UiMetrics.css(48.0), UiMetrics.css(48.0))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_button(b, "glow")
	b.add_theme_constant_override("icon_max_width", int(UiMetrics.css(48.0 * 0.82)))
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.4)))
	if size_emoji:
		b.text = icon_value
	else:
		var tex := IconResolver.texture(icon_value)
		if tex != null:
			b.icon = tex
		else:
			b.text = "❓"
	b.pressed.connect(func(): on_pick.call(icon_value))
	return b

## Ouvre le sélecteur ; `on_pick` reçoit l'emoji ou « @icon:id ».
static func open(host: Node, current: String, on_pick: Callable) -> Modal:
	var m := Modal.open(host, "", 540.0)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
	var b_emoji := _tab_button("Emoji", _tab == "emoji")
	var b_custom := _tab_button("Icônes illustrées", _tab == "custom")
	tabs.add_child(b_emoji)
	tabs.add_child(b_custom)
	m.content.add_child(tabs)
	var search := LineEdit.new()
	search.placeholder_text = "Rechercher (ex : épée, boss, potion...)"
	search.visible = _tab == "custom"
	search.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	var sbox := AdminCells.field_box()
	sbox.content_margin_left = 9
	sbox.content_margin_right = 9
	sbox.content_margin_top = 7
	sbox.content_margin_bottom = 7
	search.add_theme_stylebox_override("normal", sbox)
	var sfocus := AdminCells.field_box(true)
	sfocus.content_margin_left = 9
	sfocus.content_margin_right = 9
	sfocus.content_margin_top = 7
	sfocus.content_margin_bottom = 7
	search.add_theme_stylebox_override("focus", sfocus)
	m.content.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(scroll)
	var grid := AutoGrid.new()
	grid.min_cell = UiMetrics.css(52.0)
	grid.gap = UiMetrics.css(6.0)
	grid.pad = UiMetrics.css(4.0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var cap := UiMetrics.css(400.0)
	grid.laid_out.connect(func(h: float):
		scroll.custom_minimum_size.y = minf(h, cap)
		m._fit())
	var pick := func(v: String):
		on_pick.call(v)
		m.close()
	var render := Callable()
	render = func():
		for ch in grid.get_children():
			grid.remove_child(ch)
			ch.queue_free()
		if _tab == "emoji":
			for e in Data.constants.get("ICON_LIBRARY", []):
				grid.add_child(_swatch(str(e.get("i", "")), str(e.get("n", "")), true, pick))
		else:
			var q := normalize(search.text)
			var any := false
			for c in catalog():
				var cat: String = c[0]
				var shown: Array = []
				for e in c[1]:
					if q != "" and normalize(str(e[1])).find(q) < 0 and normalize(cat).find(q) < 0:
						continue
					shown.append(e)
				if shown.is_empty():
					continue
				any = true
				grid.add_child(_category_header(cat))
				for e in shown:
					grid.add_child(_swatch("@icon:" + str(e[0]), str(e[1]), false, pick))
			if not any:
				var none := Label.new()
				none.text = "Aucun résultat."
				none.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.74)))
				none.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
				none.add_theme_color_override("font_color", UiTheme.DIM)
				none.set_meta("full", true)
				var mm := MarginContainer.new()
				mm.add_theme_constant_override("margin_left", 8)
				mm.add_theme_constant_override("margin_top", 8)
				mm.add_child(none)
				mm.set_meta("full", true)
				grid.add_child(mm)
		scroll.scroll_vertical = 0
		grid.queue_sort()
	var switch_tab := func(t: String):
		_tab = t
		_mark_tab(b_emoji, t == "emoji")
		_mark_tab(b_custom, t == "custom")
		search.visible = t == "custom"
		render.call()
	b_emoji.pressed.connect(func(): switch_tab.call("emoji"))
	b_custom.pressed.connect(func(): switch_tab.call("custom"))
	search.text_changed.connect(func(_t: String): render.call())
	render.call()
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close(), "primary": false}])
	return m

# ------------------------------------------------------------------ portraits

## Sélecteur de portraits (images assets/portraits) ; `on_pick` reçoit le chemin, ou "" pour « Aucun portrait (icône de classe) ».
## Cliquer sur le fond ferme la fenêtre ; le portrait courant est cerclé d'or vif avec un halo.
static func open_portrait(host: Node, current: String, on_pick: Callable) -> Modal:
	var m := Modal.open(host, "Choisir un portrait", 520.0)
	if m.panel.title_label != null:
		m.panel.title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var pick := func(v: String):
		on_pick.call(v)
		m.close()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.content.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	scroll.add_child(col)
	for pc in PORTRAIT_CLASSES:
		var cl := Label.new()
		cl.text = str(pc[0])
		var fv := FontVariation.new()
		fv.base_font = UiTheme.font(UiTheme.F_BODY)
		fv.spacing_glyph = 1
		cl.add_theme_font_override("font", fv)
		cl.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
		cl.add_theme_color_override("font_color", UiTheme.GOLD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var lm := MarginContainer.new()
		lm.add_theme_constant_override("margin_top", int(UiMetrics.css(8.0)))
		lm.add_theme_constant_override("margin_bottom", int(UiMetrics.css(4.0)))
		lm.add_theme_constant_override("margin_left", int(UiMetrics.css(4.0)))
		lm.add_child(cl)
		col.add_child(lm)
		var grid := AutoGrid.new()
		grid.min_cell = UiMetrics.css(64.0)
		grid.gap = UiMetrics.css(6.0)
		grid.pad = UiMetrics.css(4.0)
		grid.fill_cells = true
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(grid)
		var i := 0
		while ResourceLoader.exists("res://assets/portraits/%s_%d.webp" % [pc[1], i]):
			var path := "res://assets/portraits/%s_%d.webp" % [pc[1], i]
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(UiMetrics.css(64.0), UiMetrics.css(64.0))
			_style_button(b, "hover")
			if path == current:
				for k in ["normal", "hover", "pressed", "focus"]:
					b.add_theme_stylebox_override(k, swatch_box("on"))
			var t := TextureRect.new()
			t.texture = load(path)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			t.offset_left = 2
			t.offset_top = 2
			t.offset_right = -2
			t.offset_bottom = -2
			b.add_child(t)
			b.pressed.connect(func(): pick.call(path))
			grid.add_child(b)
			i += 1
	var cap := get_viewport_cap(host)
	var fit_scroll := func():
		scroll.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, cap)
		m._fit()
	for g in col.get_children():
		if g is AutoGrid:
			(g as AutoGrid).laid_out.connect(func(_h: float): fit_scroll.call_deferred())
	m.set_buttons([
		{"text": "Aucun portrait (icône de classe)", "cb": func(): pick.call(""), "primary": false},
		{"text": "Fermer", "cb": func(): m.close(), "primary": false}])
	m.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			m.close())
	return m

## 58 vh : hauteur maximale de la grille de portraits.
static func get_viewport_cap(host: Node) -> float:
	var vp := host.get_viewport().get_visible_rect().size if host != null and host.is_inside_tree() else Vector2(1280, 720)
	return vp.y * 0.58
