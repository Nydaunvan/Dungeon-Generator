class_name GuideBook
extends Node
## Guide de l'aventurier présenté comme un livre : sommaire par chapitres à gauche (repliables), une page à la fois à droite,
## pages calculées d'après la taille de l'écran (pas d'ascenseur), « Page x / y », flèches du clavier, recherche, reprise à la dernière page lue.
## Les textes viennent de data/lang/help.<langue>.json (un sujet = un fichier de texte BBCode) ; les chapitres regroupent les sujets.

const CHAPTERS := [
	{"key": "ui.guide.ch1", "ids": ["demarrage", "accueil", "deplacement", "commandes"]},
	{"key": "ui.guide.ch2", "ids": ["combat", "vitesse", "sorts", "statuts"]},
	{"key": "ui.guide.ch3", "ids": ["equipement", "progression", "formules"]},
	{"key": "ui.guide.ch4", "ids": ["boutique", "village", "monstres", "bestiaire", "fontaines", "pieges"]},
	{"key": "ui.guide.ch5", "ids": ["sauvegarde", "son", "parametres"]},
	{"key": "ui.guide.ch6", "ids": ["compte", "defis", "recompenses", "tchat"]},
	{"key": "ui.guide.ch7", "ids": ["editeur", "versions", "admin_en_ligne"]},
]
const TUTORIAL_CHAPTERS := [
	{"key": "ui.guide.tch1", "ids": ["intro", "general", "chars", "classes", "spells", "items"]},
	{"key": "ui.guide.tch2", "ids": ["levels", "test"]},
]
const MEMO_PATH := "user://guide.cfg"
const FONT_SIZE := 15
const GOLD := Color("e8b45c")

var modal: Modal
var data_name := "help"
var chapters: Array = CHAPTERS
var _memo := MEMO_PATH
var topics: Array = []            ## [{id, label, text, chapter}]
var pages: Array = []             ## [{topic, text}] dans l'ordre du livre
var first_page: Dictionary = {}   ## id du sujet -> numéro de la première page
var page_no := 0
var _host: Node
var _width := 900.0
var _page_w := 520.0
var _page_h := 380.0
var _narrow := false
var _toc_open := false
var _open_chapter := 0
var _query := ""
var _gen := 0
var _toc_box: VBoxContainer
var _toc_card: Control
var _page_card: Control
var _page_head: Label
var _page_text: RichTextLabel
var _prev: Button
var _next: Button
var _counter: Label
var _search: LineEdit
var _ready_pages := false

## `kind` : "help" (guide de l'aventurier) ou "tutorial" (tutoriel de création de l'éditeur).
static func open(host: Node, start_id: String = "", kind: String = "help") -> GuideBook:
	var g := GuideBook.new()
	if kind == "tutorial":
		g.data_name = "tutorial"
		g.chapters = TUTORIAL_CHAPTERS
		g._memo = "user://tutorial.cfg"
	g._host = host
	var vp: Vector2 = host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	g._width = clampf(vp.x * 0.96, 320.0, 1040.0)
	g._narrow = g._width < 700.0
	g.modal = Modal.open_framed(host, L.t("common.tutoriel_de_creation") if kind == "tutorial" else L.t("ui.doc_modal.guide_de_l_aventurier"), g._width)
	g.modal.fit_ratio = 0.9
	g.modal.add_child(g)
	g._page_h = clampf(vp.y * 0.9 - 190.0, 190.0, 720.0)
	g._page_w = g._width - (0.0 if g._narrow else 262.0) - 90.0
	g._build()
	g._start(start_id)
	return g

# ------------------------------------------------------------------ construction

func _build() -> void:
	var c := modal.content
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	c.add_child(bar)
	if _narrow:
		var tb := HubKit.button(L.t("ui.guide.toc"), func(): _show_toc(not _toc_open), false, 34)
		bar.add_child(tb)
	_search = LineEdit.new()
	_search.placeholder_text = L.t("ui.guide.search")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.y = 34
	_search.text_changed.connect(_on_search)
	bar.add_child(_search)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	c.add_child(body)
	# sommaire
	_toc_card = HubKit.card(UiTheme.BRONZE_DARK, HubKit.CARD_BG, 8)
	_toc_card.custom_minimum_size = Vector2(0 if _narrow else 252.0, 0)
	_toc_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow else Control.SIZE_SHRINK_BEGIN
	body.add_child(_toc_card)
	_toc_box = HubKit.vbox(2)
	_toc_card.add_child(_toc_box)
	# page
	_page_card = HubKit.card(Color("7a5a2c"), Color(0.07, 0.05, 0.03, 0.55), 14)
	_page_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_page_card)
	var pv := HubKit.vbox(6)
	_page_card.add_child(pv)
	_page_head = HubKit.label("", UiTheme.DIM, 12, false, false)
	pv.add_child(_page_head)
	_page_text = _rich()
	_page_text.scroll_active = false
	_page_text.clip_contents = true
	_page_text.custom_minimum_size = Vector2(0, _page_h)
	pv.add_child(_page_text)
	# pied de page
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	c.add_child(foot)
	_prev = HubKit.button(L.t("ui.guide.prev"), func(): go_page(page_no - 1), false, 38)
	_prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_prev)
	_counter = HubKit.label("", UiTheme.GOLD, 14, true, false, HORIZONTAL_ALIGNMENT_CENTER)
	_counter.custom_minimum_size.x = 130
	foot.add_child(_counter)
	_next = HubKit.button(L.t("ui.guide.next"), func(): go_page(page_no + 1), true, 38)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_next)
	modal.set_buttons([])
	_show_toc(not _narrow)

func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", UiTheme.PARCH)
	r.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	r.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	r.add_theme_font_size_override("italics_font_size", FONT_SIZE)
	r.add_theme_font_size_override("bold_italics_font_size", FONT_SIZE)
	r.add_theme_font_size_override("mono_font_size", FONT_SIZE)
	return r

# ------------------------------------------------------------------ données et pagination

func _load_topics() -> void:
	topics.clear()
	var raw: Array = DocModal.load_data(data_name)
	var seen := {}
	for ci in chapters.size():
		for id in chapters[ci].ids:
			for t in raw:
				if str(t.id) == id and not seen.has(id):
					seen[id] = true
					topics.append({"id": id, "label": str(t.label), "text": str(t.text), "chapter": ci})
	for t in raw:                       # sujet absent des chapitres : rangé à la fin du dernier
		if not seen.has(str(t.id)):
			topics.append({"id": str(t.id), "label": str(t.label), "text": str(t.text), "chapter": chapters.size() - 1})

## Découpe tous les sujets en pages qui tiennent dans la hauteur disponible (mesure ligne par ligne avec le même rendu que la page).
func _paginate() -> void:
	var meter := _rich()
	meter.fit_content = true
	meter.scroll_active = false
	meter.size = Vector2(_page_w, 10)
	meter.custom_minimum_size = Vector2(_page_w, 0)
	meter.modulate.a = 0.0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(meter)
	var budget := _page_h * 0.97 - 6.0
	var gen := _gen
	pages.clear()
	first_page.clear()
	var blank_h := _measure(meter, "A")
	var n := 0
	for ti in topics.size():
		var t: Dictionary = topics[ti]
		first_page[t.id] = pages.size()
		var lines: PackedStringArray = str(t.text).split("\n")
		var cur: Array = []
		var used := 0.0
		var i := 0
		while i < lines.size():
			var ln: String = lines[i]
			var h := blank_h if ln.strip_edges() == "" else _measure(meter, ln)
			n += 1
			if n % 60 == 0:
				await get_tree().process_frame
				if gen != _gen or not is_instance_valid(meter):
					return
			if used + h > budget and not cur.is_empty():
				# ne finit pas une page sur un intitulé : il passe avec son paragraphe
				var carry: Array = []
				while cur.size() > 1 and _is_heading(str(cur[cur.size() - 1])) :
					carry.push_front(cur.pop_back())
				_push(ti, cur)
				cur = carry
				used = 0.0
				for cl in cur:
					used += blank_h if str(cl).strip_edges() == "" else _measure(meter, str(cl))
			if cur.is_empty() and ln.strip_edges() == "":
				i += 1
				continue
			cur.append(ln)
			used += h
			i += 1
		_push(ti, cur)
	meter.queue_free()

func _is_heading(line: String) -> bool:
	var s := line.strip_edges()
	return s.begins_with("[b]") and s.ends_with("[/b]") or s.begins_with("[font_size=") or s.ends_with(":[/b]")

func _push(ti: int, lines: Array) -> void:
	while not lines.is_empty() and str(lines[lines.size() - 1]).strip_edges() == "":
		lines.pop_back()
	if lines.is_empty():
		return
	pages.append({"topic": ti, "text": "\n".join(lines)})

func _measure(meter: RichTextLabel, line: String) -> float:
	meter.text = line
	return float(meter.get_content_height())

# ------------------------------------------------------------------ navigation

func _start(start_id: String) -> void:
	_load_topics()
	_page_text.text = L.t("ui.guide.preparing")
	_fill_toc()
	await get_tree().process_frame
	await _paginate()
	if not is_instance_valid(modal) or pages.is_empty():
		return
	_ready_pages = true
	var target := 0
	if start_id != "" and first_page.has(start_id):
		target = int(first_page[start_id])
	elif start_id == "":
		target = _recall()
	go_page(target)
	modal.call_deferred("_fit")

func go_page(n: int) -> void:
	if not _ready_pages:
		return
	page_no = clampi(n, 0, pages.size() - 1)
	var p: Dictionary = pages[page_no]
	var t: Dictionary = topics[int(p.topic)]
	_open_chapter = int(t.chapter)
	_page_head.text = "%s  ·  %s" % [L.fa(L.t("ui.guide.chapter"), int(t.chapter) + 1) + " — " + L.t(chapters[int(t.chapter)].key), str(t.label)]
	_page_text.text = str(p.text)
	_page_text.scroll_to_line(0)
	_counter.text = L.fa(L.t("ui.guide.page"), [page_no + 1, pages.size()])
	_prev.disabled = page_no <= 0
	_next.disabled = page_no >= pages.size() - 1
	_query = ""
	if _search.text != "":
		_search.text = ""
	_fill_toc()
	if _narrow:
		_show_toc(false)
	_remember()

func goto_topic(id: String) -> void:
	if first_page.has(id):
		go_page(int(first_page[id]))

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or _search.has_focus() or modal == null or modal.is_queued_for_deletion():
		return
	var top: Node = null
	for nd in get_tree().get_nodes_in_group("modal"):
		if not nd.is_queued_for_deletion():
			top = nd
	if top != modal:
		return
	match (e as InputEventKey).keycode:
		KEY_RIGHT, KEY_PAGEDOWN:
			get_viewport().set_input_as_handled()
			go_page(page_no + 1)
		KEY_LEFT, KEY_PAGEUP:
			get_viewport().set_input_as_handled()
			go_page(page_no - 1)

func _show_toc(v: bool) -> void:
	_toc_open = v
	if _narrow:
		_toc_card.visible = v
		_page_card.visible = not v
		_prev.get_parent().visible = not v
	else:
		_toc_card.visible = true
	modal.call_deferred("_fit")

# ------------------------------------------------------------------ sommaire et recherche

func _fill_toc() -> void:
	for ch in _toc_box.get_children():
		ch.queue_free()
	if _query != "":
		_fill_results()
		return
	for ci in chapters.size():
		var open := ci == _open_chapter
		var head := HubKit.toggle("%s  %s %d · %s" % ["▾" if open else "▸", L.t("ui.guide.chapter_short"), ci + 1, L.t(chapters[ci].key)], open, func():
			_open_chapter = ci
			_fill_toc(), 13, 8, 5)
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_toc_box.add_child(head)
		if not open:
			continue
		for ti in topics.size():
			if int(topics[ti].chapter) != ci:
				continue
			_toc_box.add_child(_toc_row(ti))

func _toc_row(ti: int) -> Control:
	var t: Dictionary = topics[ti]
	var cur: bool = _ready_pages and int(pages[page_no].topic) == ti
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var b := Button.new()
	b.text = str(t.label)
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", UiTheme.GOLD if cur else Color("e2d2b0"))
	b.add_theme_color_override("font_hover_color", Color("fff0c8"))
	b.pressed.connect(func(): goto_topic(str(t.id)))
	row.add_child(b)
	if first_page.has(t.id):
		row.add_child(HubKit.label("p. %d" % (int(first_page[t.id]) + 1), UiTheme.DIM, 11, false, false))
	return row

func _plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[/?[a-z_]+[^\\]]*\\]")
	return re.sub(s, "", true).to_lower()

func _on_search(q: String) -> void:
	_query = q.strip_edges().to_lower()
	if _narrow and _query != "":
		_show_toc(true)
	_fill_toc()

func _fill_results() -> void:
	var found := 0
	for ti in topics.size():
		var t: Dictionary = topics[ti]
		if not (_query in _plain(str(t.text)) or _query in str(t.label).to_lower()):
			continue
		found += 1
		# page du sujet qui contient le mot
		var pg := int(first_page.get(t.id, 0))
		for pi in pages.size():
			if int(pages[pi].topic) == ti and _query in _plain(str(pages[pi].text)):
				pg = pi
				break
		var b := Button.new()
		b.text = "%s  (p. %d)" % [str(t.label), pg + 1]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func(): go_page(pg))
		_toc_box.add_child(b)
	if found == 0:
		_toc_box.add_child(HubKit.label(L.t("ui.guide.none"), UiTheme.DIM, 13))

# ------------------------------------------------------------------ mémoire de la dernière page

func _remember() -> void:
	var cf := ConfigFile.new()
	cf.set_value("guide", "topic", str(topics[int(pages[page_no].topic)].id))
	cf.set_value("guide", "offset", page_no - int(first_page[topics[int(pages[page_no].topic)].id]))
	cf.save(_memo)

func _recall() -> int:
	var cf := ConfigFile.new()
	if cf.load(_memo) != OK:
		return 0
	var id := str(cf.get_value("guide", "topic", ""))
	if not first_page.has(id):
		return 0
	return mini(int(first_page[id]) + int(cf.get_value("guide", "offset", 0)), pages.size() - 1)
