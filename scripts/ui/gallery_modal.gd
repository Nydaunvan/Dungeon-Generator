class_name GalleryModal
extends RefCounted
## Galerie de la communauté : donjons publiés par les joueurs. Recherche par titre, tri (récents / populaires), téléchargement dans
## « Mes donjons » et signalement.

var _host: Node
var _modal: Modal
var _list: VBoxContainer
var _status: Label
var _more: Button
var _search: LineEdit
var _sort := "recent"
var _offset := 0
var _gen := 0
var _toggles: Dictionary = {}

static func open(host: Node) -> GalleryModal:
	var s := GalleryModal.new()
	s._host = host
	s._modal = Modal.open(host, L.t("ui.gallery.title"), 640.0)
	s._modal.fit_ratio = 0.8
	s._build()
	s._load(true)
	return s

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _flash(text: String, color: Color = UiTheme.DIM) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", color)

func _build() -> void:
	var c := _modal.content
	_modal.add_text(L.t("ui.gallery.intro"), UiTheme.DIM, 13, true)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_search = LineEdit.new()
	_search.max_length = 40
	_search.placeholder_text = L.t("ui.gallery.search_hint")
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_t): _load(true))
	h.add_child(_search)
	var sb := HubKit.button(L.t("ui.gallery.search"), func(): _load(true), true, 34)
	sb.custom_minimum_size.x = 120
	h.add_child(sb)
	c.add_child(h)
	var tg := HBoxContainer.new()
	tg.add_theme_constant_override("separation", 6)
	for s in [["recent", L.t("ui.gallery.sort_recent")], ["popular", L.t("ui.gallery.sort_popular")]]:
		var key: String = s[0]
		var b := HubKit.toggle(s[1], key == _sort, func():
			_sort = key
			_sync_toggles()
			_load(true), 13, 10, 5)
		_toggles[key] = b
		tg.add_child(b)
	c.add_child(tg)
	_status = HubKit.label("", UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER)
	c.add_child(_status)
	_list = HubKit.vbox(10)
	c.add_child(_list)
	_more = HubKit.button(L.t("ui.gallery.more"), func(): _load(false), false, 36)
	_more.visible = false
	c.add_child(_more)
	_modal.set_buttons([{"text": L.t("common.fermer"), "cb": func(): _modal.close()}])

func _sync_toggles() -> void:
	for k in _toggles:
		var b: Button = _toggles[k]
		b.set_pressed_no_signal(k == _sort)
		HubKit.style_toggle(b, 10, 5)

func _load(reset: bool) -> void:
	if reset:
		_offset = 0
		for ch in _list.get_children():
			_list.remove_child(ch)
			ch.queue_free()
	_gen += 1
	var mine := _gen
	_more.visible = false
	_flash(L.t("ui.gallery.loading"))
	var r: Dictionary = await MyDungeons.gallery(_search.text, _sort, _offset)
	if mine != _gen or not _alive():
		return
	if not r.ok or not (r.data is Array):
		_flash(str(r.get("message", "")), HubKit.BAD)
		return
	var rows: Array = r.data
	_flash("" if not rows.is_empty() or _offset > 0 else L.t("ui.gallery.none"))
	for row in rows:
		_list.add_child(_card(row))
	_offset += rows.size()
	_more.visible = rows.size() >= MyDungeons.GALLERY_PAGE
	_modal.call_deferred("_fit")

func _card(row: Dictionary) -> Control:
	var card := HubKit.card(UiTheme.BRONZE_DARK, HubKit.CARD_BG, 12)
	var v := HubKit.vbox(6)
	card.add_child(v)
	v.add_child(HubKit.label(str(row.get("title", "")), UiTheme.GOLD, 17, true))
	var mine := str(row.get("owner_id", "")) == Cloud.user_id() and Cloud.is_signed_in()
	var by := L.fa(L.t("ui.gallery.by"), str(row.get("pseudo", "?"))) + (" " + L.t("ui.gallery.yours") if mine else "")
	v.add_child(HubKit.label("%s · %s · %s" % [by, L.fa(L.t("ui.gallery.downloads"), int(row.get("downloads", 0))), HubKit.short_date(row.get("created_at"))], UiTheme.DIM, 12))
	var desc := str(row.get("description", ""))
	if desc != "":
		v.add_child(HubKit.label(desc.left(240), UiTheme.PARCH, 13))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var id := str(row.id)
	var dl: Button = HubKit.button(L.t("ui.gallery.get"), func(): pass, true, 36)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.pressed.connect(func():
		dl.disabled = true
		var r: Dictionary = await MyDungeons.download(id)
		if not _alive():
			return
		if r.ok:
			dl.text = L.t("ui.gallery.added")
			_flash(L.t("ui.gallery.added_long"), HubKit.GOOD)
		else:
			dl.disabled = false
			_flash(str(r.get("message", "")), HubKit.BAD))
	h.add_child(dl)
	if not mine:
		var rp := HubKit.button("🚩", func(): _report(id), false, 36)
		rp.tooltip_text = L.t("ui.gallery.report")
		h.add_child(rp)
	return card

func _report(id: String) -> void:
	if not MyDungeons.online():
		Form.alert(_host, L.t("ui.gallery.report_need_account"))
		return
	var m := Modal.open(_host, L.t("ui.gallery.report"), 440.0)
	m.add_text(L.t("ui.gallery.report_text"), UiTheme.PARCH, 14, true)
	var e := LineEdit.new()
	e.max_length = 300
	e.placeholder_text = L.t("ui.gallery.report_hint")
	m.content.add_child(e)
	var st := HubKit.label("", UiTheme.DIM, 13)
	m.content.add_child(st)
	var go := func():
		if e.text.strip_edges().length() < 3:
			st.text = L.t("ui.gallery.report_short")
			return
		var r: Dictionary = await MyDungeons.report(id, e.text)
		if not is_instance_valid(m):
			return
		if r.ok or int(r.get("status", 0)) == 409:
			m.close()
			if _alive():
				_flash(L.t("ui.gallery.reported"), HubKit.GOOD)
		else:
			st.text = str(r.get("message", ""))
	e.text_submitted.connect(func(_t): go.call())
	m.set_buttons([{"text": L.t("ui.gallery.report_send"), "primary": true, "cb": go}, {"text": L.t("common.annuler"), "cb": func(): m.close()}])
