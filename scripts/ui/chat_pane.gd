class_name ChatPane
extends VBoxContainer
## Un canal du tchat : liste des messages qui se met à jour toute seule (interrogation du serveur tant que le canal est affiché),
## zone de saisie, signalement / blocage / message privé depuis le menu « ⋯ » d'un message. Messages affichés en texte brut.
## Les règles (longueur, débit, mots interdits, silence, blocages) sont appliquées par le serveur (voir Chat).

signal dm_requested(player_id: String, pseudo: String)
signal charter_needed
signal expired
signal blocked_someone
signal typing_changed(on: bool)

const GOLD := Color("ffd98a")
const BAD := Color("e08a7a")
const GOOD := Color("9cc79a")
const TEXT_SIZE := 13

static var poll_fast := 3.0
static var poll_slow := 10.0

var host: Node                 ## nœud qui reçoit les fenêtres de confirmation
var room := ""
var _gen := 0
var _last_id := 0
var _count := 0
var _marked := 0
var _sending := false
var _scroll: ScrollContainer
var _list: VBoxContainer
var _status: Label
var _input: LineEdit
var _send_btn: Button
var _empty_note: Label

func _label(text: String, color: Color = UiTheme.PARCH, size: int = TEXT_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func has_focus_inside() -> bool:
	return _input != null and is_instance_valid(_input) and _input.has_focus()

func release_focus_inside() -> void:
	if _input != null and is_instance_valid(_input):
		_input.release_focus()

func focus_input() -> void:
	if _input != null and is_instance_valid(_input):
		_input.grab_focus()

## Affiche un canal (recharge les derniers messages) et lance l'interrogation.
func show_room(r: String) -> void:
	stop()
	room = r
	for c in get_children():
		remove_child(c)
		c.queue_free()
	add_theme_constant_override("separation", 4)
	_last_id = 0
	_count = 0
	_marked = 0
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 140)
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 5)
	_scroll.add_child(_list)
	_empty_note = _note(L.t("ui.chat.loading"))
	_list.add_child(_empty_note)
	_status = _label("", BAD, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_input = LineEdit.new()
	_input.max_length = Chat.MAX_LEN
	_input.placeholder_text = L.t("ui.chat.dm_placeholder") if Chat.is_dm(r) else L.t("ui.chat.placeholder")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _send())
	_input.focus_entered.connect(func(): typing_changed.emit(true))
	_input.focus_exited.connect(func(): typing_changed.emit(false))
	h.add_child(_input)
	_send_btn = Button.new()
	_send_btn.text = L.t("ui.chat.send")
	_send_btn.focus_mode = Control.FOCUS_NONE
	_send_btn.pressed.connect(_send)
	h.add_child(_send_btn)
	add_child(h)
	_poll_loop(_gen)

func stop() -> void:
	_gen += 1

func _note(text: String) -> Label:
	var l := _label(text, UiTheme.DIM, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l

func _alive(mine: int) -> bool:
	return mine == _gen and is_inside_tree()

func _poll_loop(mine: int) -> void:
	var wait := poll_fast
	var first := true
	while _alive(mine):
		var r: Dictionary = await Chat.fetch(room, _last_id, 60 if first else 40)
		if not _alive(mine):
			return
		if r.ok and r.data is Array:
			if first and (r.data as Array).is_empty() and is_instance_valid(_empty_note):
				_empty_note.text = L.t("ui.chat.empty")
			_append(r.data)
			_mark_read()
			first = false
			wait = poll_fast if not (r.data as Array).is_empty() else minf(wait + 2.0, poll_slow)
			if is_instance_valid(_status) and _status.get_meta("poll_error", false):
				_status.text = ""
				_status.set_meta("poll_error", false)
		else:
			wait = poll_slow
			if is_instance_valid(_status):
				_status.text = str(r.get("message", ""))
				_status.add_theme_color_override("font_color", BAD)
				_status.set_meta("poll_error", true)
			if r.get("error_code", "") == "session_expired":
				expired.emit()
				return
			if r.get("error_code", "") == "charte_non_acceptee":
				charter_needed.emit()
				return
			if is_instance_valid(_empty_note) and first:
				_empty_note.text = L.t("ui.chat.unavailable")
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return
		await tree.create_timer(wait).timeout

func _append(msgs: Array) -> void:
	if msgs.is_empty() or _list == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	var at_end := bar.value >= bar.max_value - bar.page - 24.0 or _count == 0
	if is_instance_valid(_empty_note):
		_empty_note.queue_free()
		_empty_note = null
	for m in msgs:
		if not (m is Dictionary):
			continue
		var id := int((m as Dictionary).get("id", 0))
		if id <= _last_id:
			continue
		_last_id = id
		_list.add_child(_row(m))
		_count += 1
	while _count > Chat.KEEP and _list.get_child_count() > 0:
		_list.get_child(0).queue_free()
		_list.remove_child(_list.get_child(0))
		_count -= 1
	if at_end:
		_scroll_down.call_deferred()

func _scroll_down() -> void:
	if _scroll == null or not is_instance_valid(_scroll) or not _scroll.is_inside_tree():
		return
	await _scroll.get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

## Un message sur deux lignes (le panneau est étroit) : pseudo, niveau, heure et menu ; puis le texte.
func _row(m: Dictionary) -> Control:
	var mine := str(m.get("player_id", "")) == Cloud.user_id()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	var col := UiTheme.PARCH
	var cs := str(m.get("color", ""))
	if cs != "" and Color.html_is_valid(cs):
		col = Color.html(cs)
	var who := _label(str(m.get("pseudo", "?")), GOLD if mine else col, 13)
	who.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	head.add_child(who)
	var lvl := int(m.get("level", 0))
	if lvl >= 2:
		head.add_child(_label(L.t("ui.party_hud.nv") % lvl, UiTheme.DIM, 11))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_label(Chat.format_time(str(m.get("created_at", ""))), UiTheme.DIM, 11))
	if not mine:
		head.add_child(_menu(m))
	v.add_child(head)
	var txt := _label(str(m.get("body", "")))      # texte brut : jamais de balisage interprété
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.custom_minimum_size.x = 60
	v.add_child(txt)
	return v

func _menu(m: Dictionary) -> MenuButton:
	var mb := MenuButton.new()
	mb.text = "⋯"
	mb.flat = true
	mb.focus_mode = Control.FOCUS_NONE
	mb.tooltip_text = L.t("ui.chat.menu_tip")
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 0
	empty.content_margin_bottom = 0
	empty.content_margin_left = 4
	empty.content_margin_right = 4
	for sn in ["normal", "hover", "pressed", "focus", "disabled"]:
		mb.add_theme_stylebox_override(sn, empty)
	var pm := mb.get_popup()
	pm.add_item(L.t("ui.chat.report"), 0)
	pm.add_item(L.t("ui.chat.block"), 1)
	if not Chat.is_dm(room):
		pm.add_item("✉ " + L.t("ui.chat.write_private"), 2)
	var mid := int(m.get("id", 0))
	var pid := str(m.get("player_id", ""))
	var pseudo := str(m.get("pseudo", ""))
	pm.id_pressed.connect(func(i: int):
		if i == 0:
			_report(mid)
		elif i == 1:
			_ask_block(pid, pseudo)
		else:
			dm_requested.emit(pid, pseudo))
	return mb

func _say(text: String, color: Color = UiTheme.DIM) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", color)
		_status.set_meta("poll_error", false)

func _send() -> void:
	if _sending or _input == null or not is_instance_valid(_input):
		return
	var text := Chat.clean(_input.text)
	if text == "":
		return
	_sending = true
	_send_btn.disabled = true
	var mine := _gen
	var r: Dictionary = await Chat.send(room, text)
	_sending = false
	if not _alive(mine):
		return
	_send_btn.disabled = false
	if not r.ok:
		_say(str(r.message), BAD)
		return
	_input.text = ""
	_say("")
	_input.grab_focus()
	var r2: Dictionary = await Chat.fetch(room, _last_id, 40)       # le message apparaît tout de suite
	if _alive(mine) and r2.ok and r2.data is Array:
		_append(r2.data)
		_mark_read()

## La vue est lue jusqu'au dernier message reçu : la bulle rouge s'efface.
func _mark_read() -> void:
	if _last_id <= _marked or room == "":
		return
	_marked = _last_id
	var r: Dictionary = await Chat.mark_read(room, _last_id)
	if r.ok:
		ChatAlerts.refresh()

func _report(message_id: int) -> void:
	var r: Dictionary = await Chat.report(message_id)
	_say(L.t("ui.chat.reported") if r.ok else str(r.message), GOOD if r.ok else BAD)

func _ask_block(player_id: String, pseudo: String) -> void:
	Dialogs.confirm(host if host != null else self, L.t("ui.chat.block_title"), L.t("ui.chat.block_confirm") % pseudo,
		func(): _do_block(player_id, pseudo), L.t("ui.chat.block"))

func _do_block(player_id: String, pseudo: String) -> void:
	var r: Dictionary = await Chat.block(player_id)
	if not is_inside_tree():
		return
	if r.ok:
		blocked_someone.emit()          # le canal est rechargé sans les messages du joueur bloqué
	else:
		_say(str(r.message), BAD)
