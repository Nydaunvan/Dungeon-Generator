class_name RewardsModal
extends RefCounted
## « Mes récompenses » : niveau de compte et expérience, badges gagnés, et choix du titre, du cadre et de la couleur du pseudo
## (affichés dans les classements). Sans effet sur la partie.

var _modal: Modal
var _gen := 0
var _cat: Array = []
var _owned: Dictionary = {}        # badge_id -> true
var _sel := {"title": "", "frame": "", "color": ""}
var _preview_box: VBoxContainer
var _status: Label

static func open(host: Node) -> RewardsModal:
	var r := RewardsModal.new()
	r._modal = Modal.open(host, L.t("ui.rewards.title"), 600.0)
	r._modal.set_buttons([{"text": L.t("common.fermer"), "cb": func(): r._modal.close()}])
	r._load()
	return r

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _clear() -> void:
	for c in _modal.content.get_children():
		_modal.content.remove_child(c)
		c.queue_free()

func _load() -> void:
	_gen += 1
	var mine := _gen
	_clear()
	if not Cloud.is_configured() or not Cloud.is_signed_in():
		_modal.add_text(L.t("ui.rewards.need_account"), UiTheme.DIM, 14, true)
		return
	_modal.add_text(L.t("ui.challenges.loading"), UiTheme.DIM, 14, true)
	var cat: Dictionary = await RankedRun.badges()
	var mb: Dictionary = await RankedRun.my_badges()
	var xp: Dictionary = await RankedRun.my_xp()
	var eq: Dictionary = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/player_cosmetics?player_id=eq.%s&select=title_badge,frame_badge,color_badge" % Cloud.user_id())
	if mine != _gen or not _alive():
		return
	_clear()
	if not cat.ok:
		_modal.add_text(str(cat.message), Color("e08a7a"), 14)
		return
	_cat = cat.data
	_owned = {}
	if mb.ok:
		for b in mb.data:
			_owned[str(b.badge_id)] = true
	var total_xp := 0
	if xp.ok and xp.data is Array and not (xp.data as Array).is_empty():
		total_xp = int(xp.data[0].get("xp", 0))
	if eq.ok and eq.data is Array and not (eq.data as Array).is_empty():
		var e: Dictionary = eq.data[0]
		_sel = {"title": str(e.get("title_badge", "")) if e.get("title_badge") != null else "",
			"frame": str(e.get("frame_badge", "")) if e.get("frame_badge") != null else "",
			"color": str(e.get("color_badge", "")) if e.get("color_badge") != null else ""}
	_build(total_xp)

func _build(total_xp: int) -> void:
	var c := _modal.content
	var level := Cosmetics.level_of(total_xp)
	var lo := Cosmetics.xp_for_level(level)
	var hi := Cosmetics.xp_for_level(level + 1)
	_modal.add_text(L.fa(L.t("ui.rewards.level"), [level, total_xp]), UiTheme.GOLD, 20)
	var bar := ProgressBar.new()
	bar.min_value = lo
	bar.max_value = hi
	bar.value = total_xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e0b04a")
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	c.add_child(bar)
	_modal.add_text(L.fa(L.t("ui.rewards.next"), [hi - total_xp, level + 1]), UiTheme.DIM, 12, true)

	_preview_box = VBoxContainer.new()
	c.add_child(_preview_box)
	_modal.add_text(L.t("ui.rewards.equip_hint"), UiTheme.DIM, 13, true)
	_picker("title", L.t("ui.rewards.pick_title"), func(b: Dictionary): return b.get("title_fr") != null)
	_picker("frame", L.t("ui.rewards.pick_frame"), func(b: Dictionary): return b.get("frame") != null)
	_picker("color", L.t("ui.rewards.pick_color"), func(b: Dictionary): return b.get("color") != null)
	var save := Button.new()
	save.text = L.t("ui.rewards.equip")
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_equip)
	c.add_child(save)
	_status = Form.status_label(c)
	_refresh_preview()

	var owned_n := 0
	for b in _cat:
		if _owned.has(str(b.id)):
			owned_n += 1
	_modal.add_text(L.fa(L.t("ui.rewards.collection"), [owned_n, _cat.size()]), UiTheme.GOLD, 17)
	for b in _cat:
		c.add_child(_badge_row(b))
	_modal.call_deferred("_fit")

func _picker(kind: String, label: String, offers: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(240, 0)
	ob.add_item(L.t("ui.rewards.none"))
	ob.set_item_metadata(0, "")
	var cur := 0
	for b in _cat:
		if _owned.has(str(b.id)) and offers.call(b):
			var shown := str(b.icon) + " " + (Cosmetics.loc(b, "title") if kind == "title" else Cosmetics.loc(b, "label"))
			ob.add_item(shown)
			ob.set_item_metadata(ob.item_count - 1, str(b.id))
			if str(b.id) == _sel[kind]:
				cur = ob.item_count - 1
	ob.select(cur)
	ob.item_selected.connect(func(i: int):
		_sel[kind] = str(ob.get_item_metadata(i))
		_refresh_preview())
	row.add_child(ob)
	_modal.content.add_child(row)

func _badge_by_id(id: String) -> Dictionary:
	for b in _cat:
		if str(b.id) == id:
			return b
	return {}

func _refresh_preview() -> void:
	if _preview_box == null or not is_instance_valid(_preview_box):
		return
	for ch in _preview_box.get_children():
		_preview_box.remove_child(ch)
		ch.queue_free()
	var t := _badge_by_id(_sel.title)
	var f := _badge_by_id(_sel.frame)
	var co := _badge_by_id(_sel.color)
	var plate := Cosmetics.name_plate(Cloud.pseudo(), Cosmetics.loc(t, "title") if not t.is_empty() else "", str(f.get("frame", "")) if not f.is_empty() else "",
		co.get("color") if not co.is_empty() else null, 20)
	_preview_box.add_child(plate)

func _badge_row(b: Dictionary) -> Control:
	var have := _owned.has(str(b.id))
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Cosmetics.RARITY_COLORS[clampi(int(b.get("rarity", 1)) - 1, 0, 4)] if have else Color(1, 1, 1, 0.12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.modulate = Color.WHITE if have else Color(1, 1, 1, 0.45)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := Label.new()
	ic.text = str(b.icon)
	ic.add_theme_font_size_override("font_size", 28)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := Label.new()
	n.text = Cosmetics.loc(b, "label")
	n.add_theme_font_size_override("font_size", 15)
	n.add_theme_color_override("font_color", UiTheme.GOLD if have else UiTheme.PARCH)
	v.add_child(n)
	var d := Label.new()
	d.text = Cosmetics.loc(b, "desc")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", UiTheme.DIM)
	v.add_child(d)
	var gives: Array = []
	if b.get("title_fr") != null:
		gives.append(L.fa(L.t("ui.rewards.gives_title"), Cosmetics.loc(b, "title")))
	if b.get("frame") != null:
		gives.append(L.fa(L.t("ui.rewards.gives_frame"), str(b.frame)))
	if b.get("color") != null:
		gives.append(L.t("ui.rewards.gives_color"))
	if not gives.is_empty():
		var g := Label.new()
		g.text = " · ".join(gives)
		g.add_theme_font_size_override("font_size", 12)
		g.add_theme_color_override("font_color", Color("e0b87a"))
		v.add_child(g)
	return p

func _equip() -> void:
	var r: Dictionary = await RankedRun.equip(_sel.title, _sel.frame, _sel.color)
	if not _alive() or _status == null or not is_instance_valid(_status):
		return
	_status.text = L.t("ui.rewards.equipped") if r.ok else str(r.message)
