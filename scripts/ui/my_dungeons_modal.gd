class_name MyDungeonsModal
extends RefCounted
## « Mes donjons » : l'espace personnel. Chaque donjon créé est enregistré automatiquement (appareil + compte). On peut l'ouvrir dans
## l'éditeur, le renommer, le dupliquer, le publier dans la galerie, en tirer un code ou le supprimer.

var _host: Node
var _modal: Modal
var _list: VBoxContainer
var _status: Label

static func open(host: Node) -> MyDungeonsModal:
	var s := MyDungeonsModal.new()
	s._host = host
	s._modal = Modal.open(host, L.t("ui.mydun.title"), 640.0)
	s._modal.fit_ratio = 0.8
	s._build()
	s._sync()
	return s

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _flash(text: String, color: Color = UiTheme.DIM) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", color)

func _build() -> void:
	var c := _modal.content
	_modal.add_text(L.t("ui.mydun.intro"), UiTheme.DIM, 13, true)
	_status = HubKit.label("", UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER)
	c.add_child(_status)
	_list = HubKit.vbox(10)
	c.add_child(_list)
	var specs: Array = []
	if Cloud.is_configured():
		specs.append({"text": L.t("ui.mydun.gallery_btn"), "primary": true, "cb": func(): GalleryModal.open(_host)})
	specs.append({"text": L.t("common.fermer"), "cb": func(): _modal.close()})
	_modal.set_buttons(specs, false, true)
	_refresh()

func _sync() -> void:
	if not Cloud.is_configured():
		return
	if not MyDungeons.online():
		_flash(L.t("ui.mydun.need_account"))
		return
	_flash(L.t("ui.mydun.syncing"))
	var r: Dictionary = await MyDungeons.sync()
	if not _alive():
		return
	if r.ok:
		_flash(L.fa(L.t("ui.mydun.pulled"), int(r.get("pulled", 0))) if int(r.get("pulled", 0)) > 0 else L.t("ui.mydun.synced"), HubKit.GOOD)
		_refresh()
	else:
		_flash(str(r.get("message", "")), HubKit.WARN)

func _refresh() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	var items := MyDungeons.list()
	if items.is_empty():
		_list.add_child(HubKit.label(L.t("ui.mydun.empty"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
	for m in items:
		_list.add_child(_card(m))
	_modal.call_deferred("_fit")

func _sync_text(m: Dictionary) -> String:
	if str(m.get("cloud_id", "")) != "" and not bool(m.get("dirty", false)):
		return L.t("ui.mydun.state_synced")
	if MyDungeons.online():
		return L.t("ui.mydun.state_sending")
	return L.t("ui.mydun.state_local")

func _card(m: Dictionary) -> Control:
	var id := str(m.id)
	var pub := bool(m.get("public", false))
	var card := HubKit.card(HubKit.GOOD if pub else UiTheme.BRONZE_DARK, HubKit.CARD_BG, 12)
	var v := HubKit.vbox(6)
	card.add_child(v)
	v.add_child(HubKit.label(str(m.get("title", "")), UiTheme.GOLD, 17, true))
	var parts: Array = [HubKit.paris_date(float(m.get("updated", 0))), L.fa(L.t("ui.mydun.n_levels"), int(m.get("levels", 0))), _sync_text(m)]
	if pub:
		parts.append(L.t("ui.mydun.state_public"))
	v.add_child(HubKit.label(" · ".join(parts), UiTheme.DIM, 12))
	var desc := str(m.get("desc", ""))
	if desc != "":
		v.add_child(HubKit.label(desc.left(200), UiTheme.PARCH, 13))
	v.add_child(HubKit.button(L.t("ui.mydun.open"), func(): _open(id), true, 38))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	v.add_child(row)
	for spec in [
		[L.t("ui.mydun.rename"), L.t("ui.mydun.rename"), func(): _rename(id)],
		[L.t("ui.mydun.duplicate"), L.t("ui.mydun.duplicate"), func(): _duplicate(id)],
		[L.t("ui.mydun.unpublish_short") if pub else L.t("ui.mydun.publish_short"), L.t("ui.mydun.unpublish") if pub else L.t("ui.mydun.publish"), func(): _unpublish(id) if pub else _publish(id)],
		[L.t("ui.mydun.code_short"), L.t("ui.mydun.code"), func(): _code(id)],
		[L.t("ui.mydun.delete"), L.t("ui.mydun.delete"), func(): _delete(id)],
	]:
		var b := HubKit.button(str(spec[0]), spec[2], false, 32)
		b.custom_minimum_size.x = 98
		b.add_theme_font_size_override("font_size", 13)
		b.tooltip_text = str(spec[1])
		row.add_child(b)
	return card

func _open(id: String) -> void:
	_modal.close()
	if not Data.open_my_dungeon(id):
		Form.alert(_host, L.t("ui.mydun.broken"))

func _rename(id: String) -> void:
	var m := Modal.open(_host, L.t("ui.mydun.rename"), 420.0)
	var e := LineEdit.new()
	e.max_length = MyDungeons.MAX_TITLE
	e.text = str(MyDungeons.meta(id).get("title", ""))
	m.content.add_child(e)
	var go := func():
		MyDungeons.rename(id, e.text)
		m.close()
		if _alive():
			_refresh()
	e.text_submitted.connect(func(_t): go.call())
	m.set_buttons([{"text": L.t("common.confirmer"), "primary": true, "cb": go}, {"text": L.t("common.annuler"), "cb": func(): m.close()}])
	e.call_deferred("grab_focus")

func _duplicate(id: String) -> void:
	MyDungeons.duplicate(id)
	_refresh()

func _publish(id: String) -> void:
	if not MyDungeons.online():
		Form.alert(_host, L.t("ui.mydun.need_account"))
		return
	var m := Modal.open(_host, L.t("ui.mydun.publish_title"), 480.0)
	m.add_text(L.t("ui.mydun.publish_text"), UiTheme.PARCH, 14, true)
	var d := TextEdit.new()
	d.placeholder_text = L.t("ui.mydun.publish_desc_hint")
	d.custom_minimum_size = Vector2(0, 90)
	d.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	d.text = str(MyDungeons.meta(id).get("desc", ""))
	m.content.add_child(d)
	var st := HubKit.label("", UiTheme.DIM, 13)
	m.content.add_child(st)
	var go := func():
		st.text = L.t("ui.mydun.syncing")
		var r: Dictionary = await MyDungeons.set_public(id, true, d.text)
		if not is_instance_valid(m):
			return
		if r.ok:
			m.close()
			if _alive():
				_flash(L.t("ui.mydun.published"), HubKit.GOOD)
				_refresh()
		else:
			st.text = str(r.get("message", ""))
			st.add_theme_color_override("font_color", HubKit.BAD)
	m.set_buttons([{"text": L.t("ui.mydun.publish"), "primary": true, "cb": go}, {"text": L.t("common.annuler"), "cb": func(): m.close()}])

func _unpublish(id: String) -> void:
	Dialogs.confirm(_host, L.t("ui.mydun.unpublish"), L.t("ui.mydun.unpublish_text"), func():
		_flash(L.t("ui.mydun.syncing"))
		var r: Dictionary = await MyDungeons.set_public(id, false)
		if _alive():
			_flash(L.t("ui.mydun.unpublished") if r.ok else str(r.get("message", "")), HubKit.GOOD if r.ok else HubKit.BAD)
			_refresh())

func _code(id: String) -> void:
	var cfg := MyDungeons.load_config(id)
	var m := Modal.open(_host, L.t("ui.mydun.code"), 520.0)
	var out := Form.code_area(m.content, "", true, 110.0)
	var st := Form.status_label(m.content)
	m.set_buttons([{"text": L.t("common.fermer"), "cb": func(): m.close()}])
	Form.generate_code(cfg, out, st)

func _delete(id: String) -> void:
	Dialogs.confirm(_host, L.t("ui.mydun.delete"), L.fa(L.t("ui.mydun.delete_text"), str(MyDungeons.meta(id).get("title", ""))), func():
		var r: Dictionary = await MyDungeons.delete(id)
		if _alive():
			if not r.ok:
				_flash(str(r.get("message", "")), HubKit.BAD)
			_refresh(), L.t("ui.mydun.delete"))
