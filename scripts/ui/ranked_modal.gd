class_name RankedModal
extends RefCounted
## « Parties classées » : un classement par difficulté (parties vérifiées par rejeu uniquement) et le lancement d'une partie classée.

const TOP := 10

var _host: Node
var _modal: Modal
var _diff := "normal"
var _gen := 0
var _board_box: VBoxContainer
var _tabs: Dictionary = {}

static func open(host: Node) -> RankedModal:
	var r := RankedModal.new()
	r._host = host
	r._modal = Modal.open(host, L.t("ui.ranked.title"), 620.0)
	r._build()
	return r

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _build() -> void:
	var c := _modal.content
	_modal.add_text(L.t("ui.ranked.desc"), UiTheme.DIM, 13, true)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(tabs)
	for d in RankedRun.DIFFICULTIES:
		var b := Button.new()
		b.text = L.t(ChallengesModal.DIFF_KEYS[d])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = d == _diff
		b.pressed.connect(func():
			_diff = d
			_sync_tabs()
			_load_board())
		tabs.add_child(b)
		_tabs[d] = b
	_board_box = VBoxContainer.new()
	_board_box.add_theme_constant_override("separation", 4)
	c.add_child(_board_box)
	var specs: Array = []
	if Cloud.is_signed_in():
		specs.append({"text": L.t("ui.ranked.play"), "primary": true, "cb": _ask})
	else:
		specs.append({"text": L.t("ui.challenges.login"), "primary": true, "cb": func(): AccountModal.open(_host)})
	specs.append({"text": L.t("common.fermer"), "cb": func(): _modal.close()})
	_modal.set_buttons(specs)
	_load_board()

func _sync_tabs() -> void:
	for d in _tabs:
		(_tabs[d] as Button).button_pressed = d == _diff

func _ask() -> void:
	Dialogs.confirm(_host, L.t("ui.ranked.play"), L.fa(L.t("ui.ranked.confirm"), L.t(ChallengesModal.DIFF_KEYS[_diff])), _start, L.t("ui.challenges.hc_go"), L.t("common.annuler"))

func _start() -> void:
	var r: Dictionary = await RankedRun.launch(_diff)
	if not r.ok and is_instance_valid(_host):
		Form.alert(_host, str(r.get("message", "")))

func _load_board() -> void:
	_gen += 1
	var mine := _gen
	for ch in _board_box.get_children():
		_board_box.remove_child(ch)
		ch.queue_free()
	var wait := Label.new()
	wait.text = L.t("ui.challenges.loading_board")
	wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait.add_theme_color_override("font_color", UiTheme.DIM)
	_board_box.add_child(wait)
	var r: Dictionary = await RankedRun.board(_diff)
	if mine != _gen or not _alive():
		return
	_board_box.remove_child(wait)
	wait.queue_free()
	if not r.ok:
		_note(str(r.message), Color("e08a7a"))
		return
	var rows: Array = r.data if r.data is Array else []
	if rows.is_empty():
		_note(L.t("ui.ranked.empty"), UiTheme.DIM)
		return
	for i in mini(rows.size(), TOP):
		var row: Dictionary = rows[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var rk := Label.new()
		rk.text = str(i + 1)
		rk.custom_minimum_size = Vector2(32, 0)
		rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(rk)
		var title := Cosmetics.loc(row, "title") if row.get("title_fr") != null else ""
		h.add_child(Cosmetics.name_plate(str(row.get("pseudo", "?")) + " ✔", title, str(row.get("frame", "")) if row.get("frame") != null else "", row.get("color"), 15, int(row.get("level", 0))))
		var sc := Label.new()
		sc.text = L.fa(L.t("ui.ranked.levels"), int(row.get("score", 0)))
		sc.custom_minimum_size = Vector2(90, 0)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(sc)
		var tm := Label.new()
		tm.text = Challenges.format_time(int(row.get("seconds", -1)))
		tm.custom_minimum_size = Vector2(64, 0)
		tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(tm)
		_board_box.add_child(h)
	_note(L.t("ui.challenges.hc_verified_note"), UiTheme.DIM)
	_modal.call_deferred("_fit")

func _note(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	_board_box.add_child(l)
	_modal.call_deferred("_fit")
