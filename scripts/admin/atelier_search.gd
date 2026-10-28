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

## Construit (hors écran) chaque page de règles et relève le libellé de ses réglages, carte par carte.
static func _build_index(admin: Node) -> void:
	if _index_lang == Data.lang and not _index.is_empty():
		return
	_index.clear()
	_index_lang = Data.lang
	# la construction d'une page touche à quelques états partagés : on les remet tels quels ensuite
	var keep_scroll = admin.get("_scroll")
	var keep_status = admin.get("admin_status")
	var keep_reg: Array = AdminGeneral.reg.duplicate()
	var keep_cnt = AdminGeneral._count_lbl
	var keep_prev: Array = AdminGeneral._preview.duplicate()
	for page in AdminGeneral.PAGES:
		if page == "identity" or page == "share":
			continue
		var host := Control.new()
		AdminGeneral.build_page(host, admin, page)
		_collect(host, page, "")
		host.free()
	admin.set("_scroll", keep_scroll)
	admin.set("admin_status", keep_status)
	AdminGeneral.reg = keep_reg
	AdminGeneral._count_lbl = keep_cnt
	AdminGeneral._preview = keep_prev

static func _collect(n: Node, section: String, panel: String) -> void:
	for ch in n.get_children():
		var p := panel
		if ch.has_meta("panel_title"):
			p = str(ch.get_meta("panel_title"))
		if ch.has_meta("setting"):
			_index.append({"section": section, "panel": p, "label": str(ch.get_meta("setting")), "val": _value_of(ch)})
		_collect(ch, section, p)

## Valeur affichée d'une ligne de réglage (texte du premier champ qu'elle contient).
static func _value_of(n: Node) -> String:
	for ch in n.get_children():
		if ch is LineEdit:
			return (ch as LineEdit).text
		var v := _value_of(ch)
		if v != "":
			return v
	return ""

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
	var box := Ax.panel(Color("16100a"), Ax.LINE3, 18, 0, 0)
	var bs := box.get_theme_stylebox("panel") as StyleBoxFlat
	bs.shadow_color = Color(0, 0, 0, 0.7)
	bs.shadow_size = 30
	bs.set_content_margin_all(0)
	box.clip_contents = true
	add_child(box)
	var vw := get_viewport_rect().size
	var w := minf(680.0, vw.x - 24.0)
	box.position = Vector2((vw.x - w) / 2.0, minf(110.0, vw.y * 0.12))
	box.custom_minimum_size = Vector2(w, 0)
	var col := Ax.vbox(0)
	box.add_child(col)
	var top := Ax.hbox(12)
	col.add_child(Ax.margin(top, 18, 10, 18, 10))
	top.add_child(Ax.ico("search", 20, Ax.GOLD, 1.8))
	_edit = LineEdit.new()
	_edit.placeholder_text = L.t("ui.atelier.search")
	_edit.custom_minimum_size = Vector2(0, 40)
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_theme_font_override("font", Ax.inter(400))
	_edit.add_theme_font_size_override("font_size", 17)
	_edit.add_theme_color_override("font_color", Ax.CREAM)
	_edit.add_theme_color_override("font_placeholder_color", Ax.DIM)
	_edit.add_theme_color_override("caret_color", Ax.GOLD)
	var flat := StyleBoxEmpty.new()
	for k in ["normal", "focus", "read_only"]:
		_edit.add_theme_stylebox_override(k, flat)
	_edit.text_changed.connect(func(_t): _refresh())
	_edit.gui_input.connect(_edit_key)
	top.add_child(_edit)
	top.add_child(Ax.chip("Échap", Ax.MUTED, Ax.CLEAR, Ax.LINE, 11, 5, 7, 3))
	col.add_child(Ax.line())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, minf(420.0, vw.y * 0.5))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = Ax.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(Ax.margin(_list, 8, 8, 8, 8))
	_list.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Ax.line())
	var foot := Ax.hbox(18)
	foot.add_child(Ax.lab(L.t("ui.atelier.search_nav"), 12, Ax.DIM))
	foot.add_child(Ax.lab(L.t("ui.atelier.search_open"), 12, Ax.DIM))
	col.add_child(Ax.margin(foot, 18, 10, 18, 10))
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
				_results.append({"cat": "ui.atelier.cat_rules", "label": e.label, "path": "%s › %s" % [Atelier.title_of(str(e.section)), e.panel], "section": e.section, "find": e.label, "val": e.get("val", "")})
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
		_list.add_child(Ax.margin(Ax.lab(L.t("ui.atelier.search_none"), 14, Ax.MUTED), 12, 14, 12, 14))
		return
	var last_cat := ""
	for i in _results.size():
		var r: Dictionary = _results[i]
		if str(r.cat) != last_cat:
			last_cat = str(r.cat)
			_list.add_child(Ax.margin(Ax.kicker(L.t(last_cat), 11), 12, 8, 12, 4))
		_list.add_child(_row(i, r))

func _row(i: int, r: Dictionary) -> Control:
	var on := i == _sel
	var p := Ax.panel(Ax.GOLD_BG if on else Ax.CLEAR, Ax.GOLD if on else Ax.CLEAR, 10, 12, 10)
	var h := Ax.hbox(12)
	p.add_child(h)
	var v := Ax.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Ax.lab(str(r.label), 14, Ax.CREAM, 500)
	t.clip_text = true
	v.add_child(t)
	v.add_child(Ax.lab(str(r.path), 12, Ax.MUTED))
	h.add_child(v)
	if str(r.get("val", "")) != "":
		var val := Ax.lab(str(r.val), 14, Ax.GOLD_L, 600)
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(val)
	Ax.clickable(p, func(): _pick(i))
	p.mouse_entered.connect(func():
		if _sel != i:
			_sel = i
			_draw_list())
	return p

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
	if admin._scroll != null and is_instance_valid(admin._scroll):
		admin._scroll.ensure_control_visible(node)
	var tw := node.create_tween()
	for k in 3:
		tw.tween_property(node, "modulate", Color(1.6, 1.3, 0.6), 0.18)
		tw.tween_property(node, "modulate", Color.WHITE, 0.18)

static func _find(n: Node, text: String) -> Control:
	for ch in n.get_children():
		if ch.has_meta("setting") and str(ch.get_meta("setting")) == text:
			return ch as Control
		var f := _find(ch, text)
		if f != null:
			return f
	return null
