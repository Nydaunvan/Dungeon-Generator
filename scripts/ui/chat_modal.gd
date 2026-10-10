class_name ChatModal
extends RefCounted
## Fenêtre du tchat des joueurs : trois salons (Général, Français, English), liste des messages qui se met à jour toute seule,
## zone de saisie, signalement et blocage d'un joueur. Réservée aux comptes connectés (lecture comme écriture).
## Les messages sont affichés en texte brut (jamais interprétés) ; les règles sont appliquées par le serveur (voir Chat).

const GOLD := Color("ffd98a")
const BAD := Color("e08a7a")
const GOOD := Color("9cc79a")
const TEXT_SIZE := 14
const CHARTER_KEYS := ["ui.chat.charte_1", "ui.chat.charte_2", "ui.chat.charte_3", "ui.chat.charte_4",
	"ui.chat.charte_5", "ui.chat.charte_6", "ui.chat.charte_7"]

## Délais d'interrogation du serveur (secondes) : rapide tant que ça bouge, de plus en plus lent quand le salon est calme.
static var poll_fast := 3.0
static var poll_slow := 10.0

var _host: Node
var _modal: Modal
var _room := ""
var _view := "room"             ## « room » ou « blocked »
var _gen := 0                   ## change à chaque changement de salon ou de vue : les réponses en retard sont ignorées
var _last_id := 0
var _count := 0
var _tab_buttons: Dictionary = {}
var _body: VBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _status: Label
var _input: LineEdit
var _send_btn: Button
var _sending := false
var _empty_note: Label

static func open(host: Node) -> ChatModal:
	var c := ChatModal.new()
	c._host = host
	c._modal = Modal.open(host, L.t("ui.chat.title"), 680.0)
	c._build()
	return c

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _label(text: String, color: Color = UiTheme.PARCH, size: int = TEXT_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _note(parent: Control, text: String, color: Color = UiTheme.DIM) -> Label:
	var l := _label(text, color, 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _build() -> void:
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_modal.content.add_child(_body)
	if not Cloud.is_signed_in():
		_note(_body, L.t("ui.chat.need_account"))
		_modal.set_buttons([
			{"text": L.t("ui.chat.open_account"), "primary": true, "cb": func():
				var h := _host
				_modal.close()
				AccountModal.open(h)},
			{"text": L.t("common.fermer"), "cb": func(): _modal.close()},
		])
		return
	_room = Chat.default_room()
	_start()

## Charte d'abord : tant que la version courante n'est pas acceptée, ni lecture ni écriture (le serveur refuse aussi).
func _start() -> void:
	_reset_body()
	_note(_body, L.t("ui.chat.loading"))
	_modal.set_buttons([{"text": L.t("common.fermer"), "cb": func(): _modal.close()}])
	var mine := _gen
	var r: Dictionary = await Chat.charter_state()
	if mine != _gen or not _alive():
		return
	if not r.ok or not (r.data is Dictionary):
		_reset_body()
		_note(_body, str(r.get("message", L.t("ui.chat.unavailable"))), BAD)
		return
	var version := int(r.data.get("version", 1))
	if int(r.data.get("accepted", 0)) >= version:
		_show_room(_room)
	else:
		_show_charter(version, int(r.data.get("accepted", 0)) > 0)

func _show_charter(version: int, renewed: bool) -> void:
	_view = "charter"
	_reset_body()
	_body.add_child(_label(L.t("ui.chat.charte_title"), GOLD, 17))
	_note(_body, L.t("ui.chat.charte_updated") if renewed else L.t("ui.chat.charte_intro"))
	for k in CHARTER_KEYS:
		var l := _label("•  " + L.t(k))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		_body.add_child(l)
	_note(_body, L.t("ui.chat.charte_footer"))
	_status = _label("", BAD, 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)
	_modal.set_buttons([
		{"text": L.t("ui.chat.charte_accept"), "primary": true, "cb": func(): _accept(version)},
		{"text": L.t("ui.chat.charte_refuse"), "cb": func(): _modal.close()},
	])
	_modal.call_deferred("_fit")

func _accept(version: int) -> void:
	var mine := _gen
	var r: Dictionary = await Chat.accept_charter(version)
	if mine != _gen or not _alive():
		return
	if r.ok:
		_show_room(_room)
	elif r.get("error_code", "") == "charte_obsolete":
		_start()         # la charte a changé entre-temps : on la réaffiche
	else:
		_say(str(r.message), BAD)

func _buttons() -> void:
	_modal.set_buttons([
		{"text": L.t("ui.chat.blocked_btn"), "cb": func(): _show_blocked()},
		{"text": L.t("common.fermer"), "primary": true, "cb": func(): _modal.close()},
	], true)

func _reset_body() -> void:
	_gen += 1
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_list = null
	_status = null
	_input = null
	_send_btn = null
	_scroll = null
	_empty_note = null
	_tab_buttons.clear()

# ------------------------------------------------------------------ salon

func _show_room(room: String) -> void:
	_view = "room"
	_room = room
	_reset_body()
	_last_id = 0
	_count = 0
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	_body.add_child(tabs)
	for r in Chat.ROOMS:
		var b := Button.new()
		b.text = Chat.room_name(r)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = r == room
		b.pressed.connect(func(): _show_room(r))
		tabs.add_child(b)
		_tab_buttons[r] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 300)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_empty_note = _note(_list, L.t("ui.chat.loading"))
	_status = _label("", BAD, 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 18
	_body.add_child(_status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_input = LineEdit.new()
	_input.max_length = Chat.MAX_LEN
	_input.placeholder_text = L.t("ui.chat.placeholder")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _send())
	h.add_child(_input)
	_send_btn = Button.new()
	_send_btn.text = L.t("ui.chat.send")
	_send_btn.focus_mode = Control.FOCUS_NONE
	_send_btn.pressed.connect(_send)
	h.add_child(_send_btn)
	_body.add_child(h)
	_note(_body, L.t("ui.chat.rules"))
	_buttons()
	_modal.call_deferred("_fit")
	_poll_loop(_gen)

## Interroge le serveur tant que le salon est affiché ; `mine` change dès qu'on change de salon ou de vue, ou qu'on ferme.
func _poll_loop(mine: int) -> void:
	var wait := poll_fast
	var first := true
	while mine == _gen and _alive():
		var r: Dictionary = await Chat.fetch(_room, _last_id, 60 if first else 40)
		if mine != _gen or not _alive():
			return
		if r.ok and r.data is Array:
			if first and (r.data as Array).is_empty() and is_instance_valid(_empty_note):
				_empty_note.text = L.t("ui.chat.empty")
			_append(r.data)
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
				return
			if r.get("error_code", "") == "charte_non_acceptee":
				_start()         # la charte a changé : à relire avant de continuer
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
	_modal.call_deferred("_fit")
	if at_end:
		_scroll_down.call_deferred()

func _scroll_down() -> void:
	if not _alive() or _scroll == null or not is_instance_valid(_scroll):
		return
	await _scroll.get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _row(m: Dictionary) -> Control:
	var mine := str(m.get("player_id", "")) == Cloud.user_id()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := _label(Chat.format_time(str(m.get("created_at", ""))), UiTheme.DIM, 12)
	t.custom_minimum_size.x = 44
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(t)
	var col := UiTheme.PARCH
	var cs := str(m.get("color", ""))
	if cs != "" and Color.html_is_valid(cs):
		col = Color.html(cs)
	var lvl := int(m.get("level", 0))
	var who := _label("%s%s :" % [str(m.get("pseudo", "?")), (" (%d)" % lvl) if lvl > 0 else ""], GOLD if mine else col)
	who.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(who)
	var txt := _label(str(m.get("body", "")))      # texte brut : jamais de balisage interprété
	txt.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(txt)
	if not mine:
		var mb := MenuButton.new()
		mb.text = "⋯"
		mb.flat = true
		mb.focus_mode = Control.FOCUS_NONE
		mb.tooltip_text = L.t("ui.chat.menu_tip")
		mb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var pm := mb.get_popup()
		pm.add_item(L.t("ui.chat.report"), 0)
		pm.add_item(L.t("ui.chat.block"), 1)
		var mid := int(m.get("id", 0))
		var pid := str(m.get("player_id", ""))
		var pseudo := str(m.get("pseudo", ""))
		pm.id_pressed.connect(func(i: int):
			if i == 0:
				_report(mid)
			else:
				_ask_block(pid, pseudo))
		h.add_child(mb)
	return h

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
	var r: Dictionary = await Chat.send(_room, text)
	_sending = false
	if mine != _gen or not _alive():
		return
	_send_btn.disabled = false
	if not r.ok:
		_say(str(r.message), BAD)
		return
	_input.text = ""
	_say("")
	_input.grab_focus()
	var r2: Dictionary = await Chat.fetch(_room, _last_id, 40)       # le message apparaît tout de suite, sans attendre le prochain tour
	if mine == _gen and _alive() and r2.ok and r2.data is Array:
		_append(r2.data)

func _report(message_id: int) -> void:
	var r: Dictionary = await Chat.report(message_id)
	if not _alive():
		return
	_say(L.t("ui.chat.reported") if r.ok else str(r.message), GOOD if r.ok else BAD)

func _ask_block(player_id: String, pseudo: String) -> void:
	Dialogs.confirm(_host, L.t("ui.chat.block_title"), L.t("ui.chat.block_confirm") % pseudo, func(): _do_block(player_id, pseudo), L.t("ui.chat.block"))

func _do_block(player_id: String, pseudo: String) -> void:
	var r: Dictionary = await Chat.block(player_id)
	if not _alive():
		return
	if r.ok:
		_show_room(_room)      # le salon est rechargé sans les messages du joueur bloqué
		_say(L.t("ui.chat.blocked_done") % pseudo, GOOD)
	else:
		_say(str(r.message), BAD)

# ------------------------------------------------------------------ joueurs bloqués

func _show_blocked() -> void:
	_view = "blocked"
	_reset_body()
	_body.add_child(_label(L.t("ui.chat.blocked_title"), GOLD, 16))
	_note(_body, L.t("ui.chat.blocked_desc"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_body.add_child(box)
	_status = _label("", BAD, 13)
	_body.add_child(_status)
	_modal.set_buttons([{"text": L.t("ui.chat.back"), "primary": true, "cb": func(): _show_room(_room)}])
	_fill_blocked(box, _gen)

func _fill_blocked(box: VBoxContainer, mine: int) -> void:
	var r: Dictionary = await Chat.blocked()
	if mine != _gen or not _alive():
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	if not r.ok or not (r.data is Array):
		_note(box, str(r.get("message", "")), BAD)
		return
	if (r.data as Array).is_empty():
		_note(box, L.t("ui.chat.blocked_none"))
		return
	for p in r.data:
		var h := HBoxContainer.new()
		var n := _label(str(p.get("pseudo", "?")))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var b := Button.new()
		b.text = L.t("ui.chat.unblock")
		b.focus_mode = Control.FOCUS_NONE
		var pid := str(p.get("player_id", ""))
		b.pressed.connect(func():
			b.disabled = true
			var u: Dictionary = await Chat.unblock(pid)
			if mine == _gen and _alive():
				if u.ok:
					_fill_blocked(box, mine)
				else:
					_say(str(u.message), BAD))
		h.add_child(b)
		box.add_child(h)
	_modal.call_deferred("_fit")
