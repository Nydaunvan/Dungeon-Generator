class_name AtelierSearch
extends Control
## Recherche globale de l'atelier (Ctrl K) : réglages (libellés des pages de règles), sections, classes, sorts et objets.
## Un résultat ouvre la page concernée et fait clignoter le réglage trouvé.

const GOLD := Color("e8b45c")

## Index des réglages construit une fois par langue : [{"section", "panel", "label"}, …].
static var _index: Array = []
static var _index_lang := ""

var _admin: Node
var _edit: LineEdit
var _list: VBoxContainer
var _results: Array = []
var _sel := 0

static func open(admin: Node) -> void:
	var host: Node = admin.modals()
	for n in host.get_children():
		if n is AtelierSearch:
			return
	var s := AtelierSearch.new()
	s._admin = admin
	host.add_child(s)
	s._build()

# ------------------------------------------------------------------ index

static func _norm(t: String) -> String:
	var s := t.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["ä", "a"], ["î", "i"], ["ï", "i"], ["ô", "o"], ["ö", "o"], ["ù", "u"], ["û", "u"], ["ü", "u"], ["ç", "c"], ["œ", "oe"], ["'", " "], ["’", " "]]:
		s = s.replace(pair[0], pair[1])
	return s

## Construit (hors écran) chaque page de règles et relève le libellé de ses réglages, panneau par panneau.
static func _build_index(admin: Node) -> void:
	if _index_lang == Data.lang and not _index.is_empty():
		return
	_index.clear()
	_index_lang = Data.lang
	for page in AdminGeneral.PAGES:
		var host := VBoxContainer.new()
		AdminGeneral.build_page(host, admin, page)
		_collect(host, page, "")
		host.free()

static func _collect(n: Node, section: String, panel: String) -> void:
	for ch in n.get_children():
		var p := panel
		if ch.has_meta("panel_title"):
			p = str(ch.get_meta("panel_title"))
		elif ch.has_meta("setting"):
			_index.append({"section": section, "panel": panel, "label": str(ch.get_meta("setting"))})
		elif ch is CheckBox and (ch as CheckBox).text != "":
			_index.append({"section": section, "panel": panel, "label": (ch as CheckBox).text})
		_collect(ch, section, p)

# ------------------------------------------------------------------ fenêtre

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			queue_free())
	add_child(dim)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("16100a")
	sb.border_color = Color("5a4526")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 30
	box.add_theme_stylebox_override("panel", sb)
	add_child(box)
	var vw := get_viewport_rect().size
	var w := minf(680.0, vw.x - 24.0)
	box.position = Vector2((vw.x - w) / 2.0, minf(110.0, vw.y * 0.12))
	box.custom_minimum_size = Vector2(w, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	box.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 18)
	tm.add_theme_constant_override("margin_right", 18)
	tm.add_theme_constant_override("margin_top", 10)
	tm.add_theme_constant_override("margin_bottom", 10)
	tm.add_child(top)
	col.add_child(tm)
	top.add_child(GameIcons.rect("search", 20, GOLD, 1.8))
	_edit = LineEdit.new()
	_edit.placeholder_text = L.t("ui.atelier.search")
	_edit.custom_minimum_size = Vector2(0, 40)
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_theme_font_size_override("font_size", 17)
	var flat := StyleBoxEmpty.new()
	for k in ["normal", "focus", "read_only"]:
		_edit.add_theme_stylebox_override(k, flat)
	_edit.text_changed.connect(func(_t): _refresh())
	_edit.gui_input.connect(_edit_key)
	top.add_child(_edit)
	var esc := Label.new()
	esc.text = "Échap"
	esc.add_theme_font_size_override("font_size", 11)
	esc.add_theme_color_override("font_color", Color("a8977a"))
	top.add_child(esc)
	var line := ColorRect.new()
	line.color = Color("3a2c18")
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, minf(420.0, vw.y * 0.5))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	sc.add_child(_list)
	var foot := Label.new()
	foot.text = L.t("ui.atelier.search_hint")
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color("9a8863"))
	var fm := MarginContainer.new()
	fm.add_theme_constant_override("margin_left", 18)
	fm.add_theme_constant_override("margin_top", 8)
	fm.add_theme_constant_override("margin_bottom", 8)
	fm.add_child(foot)
	col.add_child(fm)
	_build_index(_admin)
	_edit.grab_focus()
	_refresh()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

func _edit_key(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	match e.keycode:
		KEY_DOWN:
			_move(1)
			_edit.accept_event()
		KEY_UP:
			_move(-1)
			_edit.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			_pick(_sel)
			_edit.accept_event()
		KEY_ESCAPE:
			queue_free()
			_edit.accept_event()

func _move(d: int) -> void:
	if _results.is_empty():
		return
	_sel = posmod(_sel + d, _results.size())
	_draw_list()

## Recalcule les résultats pour le texte saisi.
func _refresh() -> void:
	var words := _norm(_edit.text).split(" ", false)
	_results.clear()
	if words.is_empty():
		# sans saisie : les sections
		for g in AtelierSide.GROUPS:
			for it in g[1]:
				_results.append({"cat": "ui.atelier.cat_sections", "label": L.t(str(it[1])), "path": Atelier.kicker_of(str(it[0])), "section": str(it[0])})
	else:
		for e in _index:
			if _match(words, str(e.label) + " " + str(e.panel)):
				_results.append({"cat": "ui.atelier.cat_rules", "label": e.label, "path": "%s › %s" % [Atelier.title_of(str(e.section)), e.panel], "section": e.section, "find": e.label})
		for g in AtelierSide.GROUPS:
			for it in g[1]:
				if _match(words, L.t(str(it[1]))):
					_results.append({"cat": "ui.atelier.cat_sections", "label": L.t(str(it[1])), "path": Atelier.kicker_of(str(it[0])), "section": str(it[0])})
		var cfg: Dictionary = Data.admin_config()
		for c in cfg.get("classes", []):
			if _match(words, str(c.get("name", ""))):
				_results.append({"cat": "ui.atelier.cat_classes", "label": str(c.get("name", "")), "path": Atelier.title_of("classes"), "section": "classes"})
		for s in cfg.get("spells", []):
			if _match(words, str(s.get("name", ""))):
				_results.append({"cat": "ui.atelier.cat_spells", "label": str(s.get("name", "")), "path": Atelier.title_of("spells"), "section": "spells"})
		for o in cfg.get("itemLibrary", []):
			if _match(words, str(o.get("name", ""))):
				_results.append({"cat": "ui.atelier.cat_items", "label": str(o.get("name", "")), "path": Atelier.title_of("party") + " › " + L.t("ui.atelier.tab_items"), "section": "party", "sub": "items"})
	if _results.size() > 40:
		_results.resize(40)
	_sel = 0
	_draw_list()

static func _match(words: PackedStringArray, text: String) -> bool:
	var t := _norm(text)
	for w in words:
		if not t.contains(w):
			return false
	return true

func _draw_list() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	if _results.is_empty():
		var l := Label.new()
		l.text = L.t("ui.atelier.search_none")
		l.add_theme_color_override("font_color", Color("a8977a"))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		m.add_child(l)
		_list.add_child(m)
		return
	var last_cat := ""
	for i in _results.size():
		var r: Dictionary = _results[i]
		if str(r.cat) != last_cat:
			last_cat = str(r.cat)
			var h := Label.new()
			h.text = L.t(last_cat)
			h.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE, 2))
			h.add_theme_font_size_override("font_size", 11)
			h.add_theme_color_override("font_color", Color("9a8863"))
			var hm := MarginContainer.new()
			hm.add_theme_constant_override("margin_left", 20)
			hm.add_theme_constant_override("margin_top", 10)
			hm.add_theme_constant_override("margin_bottom", 2)
			hm.add_child(h)
			_list.add_child(hm)
		_list.add_child(_row(i, r))

func _row(i: int, r: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	var on := i == _sel
	for k in ["normal", "pressed", "focus", "hover"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.bg_color = Color(0.91, 0.71, 0.36, 0.12) if (on or k == "hover") else Color(0, 0, 0, 0)
		sb.border_color = GOLD
		sb.set_border_width_all(1 if on else 0)
		b.add_theme_stylebox_override(k, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.offset_left = 14
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.text = str(r.label)
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color("f4e6c6"))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.clip_text = true
	v.add_child(t)
	var p := Label.new()
	p.text = str(r.path)
	p.add_theme_font_size_override("font_size", 12)
	p.add_theme_color_override("font_color", Color("a8977a"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(p)
	b.add_child(v)
	b.pressed.connect(func(): _pick(i))
	return b

func _pick(i: int) -> void:
	if i < 0 or i >= _results.size():
		return
	var r: Dictionary = _results[i]
	if str(r.get("sub", "")) != "":
		AtelierParty.sub = str(r.sub)
	elif str(r.section) == "party":
		AtelierParty.sub = "party"
	var admin := _admin
	queue_free()
	admin.go(str(r.section))
	if r.has("find"):
		await admin.get_tree().process_frame
		await admin.get_tree().process_frame
		_flash(admin, str(r.find))

## Fait défiler jusqu'au réglage trouvé et le fait clignoter en doré.
static func _flash(admin: Node, text: String) -> void:
	var node: Control = _find(admin._content_host, text)
	if node == null:
		return
	admin._scroll.ensure_control_visible(node)
	var tw := node.create_tween()
	for k in 3:
		tw.tween_property(node, "modulate", Color(1.6, 1.3, 0.6), 0.18)
		tw.tween_property(node, "modulate", Color.WHITE, 0.18)

static func _find(n: Node, text: String) -> Control:
	for ch in n.get_children():
		if ch.has_meta("setting") and str(ch.get_meta("setting")) == text:
			return ch as Control
		if ch is CheckBox and (ch as CheckBox).text == text:
			return ch as Control
		var f := _find(ch, text)
		if f != null:
			return f
	return null
