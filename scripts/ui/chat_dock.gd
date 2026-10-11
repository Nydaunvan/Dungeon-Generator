extends CanvasLayer
## Tchat « moderne » (singleton `ChatDock`, présent partout : accueil, jeu, administration).
## Un bouton 💬 en bas à gauche (avec la bulle rouge des nouveaux messages). Le survol l'ouvre : on lit et on écrit tout de suite, sans
## fenêtre. Quand la souris le quitte, le panneau se replie (sauf pendant la saisie, un menu ouvert, une confirmation ou si on l'épingle).
## Canaux : « Général » et le salon de la langue du jeu sont obligatoires ; le joueur peut ajouter le salon de l'autre langue et des
## conversations privées, 5 canaux ouverts au plus. Notifications réglables canal par canal (voir ChatPrefs).

const GOLD := Color("ffd98a")
const BAD := Color("e08a7a")
const GOOD := Color("9cc79a")
const PANEL_W := 440.0
const PANEL_H := 380.0
const BTN := 46.0
const MARGIN := 10.0
const CLOSE_DELAY := 0.45
const CHARTER_KEYS := ["ui.chat.charte_1", "ui.chat.charte_2", "ui.chat.charte_3", "ui.chat.charte_4",
	"ui.chat.charte_5", "ui.chat.charte_6", "ui.chat.charte_7"]

var _root: Control
var _btn: Button
var _panel: PanelContainer
var _tabs: HFlowContainer
var _head: HBoxContainer
var _body: VBoxContainer
var _dialogs: CanvasLayer
var _pane: ChatPane
var _open := false
var _pinned := false
var _typing := false
var _hold := 0.0                  ## délai de grâce après une ouverture par menu : le temps que la souris arrive
var _outside := 0.0
var _view := "channel"
var _room := ""
var _tween: Tween
var _charter_ok_for := ""
var _dm_unread: Dictionary = {}
var _status: Label
var _gen := 0

func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.shared()
	add_child(_root)
	_dialogs = CanvasLayer.new()
	_dialogs.layer = 22
	_dialogs.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialogs)
	_build_button()
	_build_panel()
	Cloud.session_changed.connect(_on_session)
	ChatAlerts.changed.connect(_on_alerts)
	get_tree().root.size_changed.connect(_place)
	_place()

# ------------------------------------------------------------------ construction

func _build_button() -> void:
	_btn = Button.new()
	_btn.text = "💬"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.tooltip_text = L.t("ui.chatdock.tip")
	_btn.add_theme_font_size_override("font_size", 22)
	var st := ["normal", "hover", "pressed"]
	for i in st.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = [Color(0.06, 0.04, 0.02, 0.92), Color(0.16, 0.11, 0.05, 0.96), Color(0.24, 0.16, 0.06, 0.98)][i]
		sb.border_color = [UiTheme.BRONZE_DARK, UiTheme.GOLD, UiTheme.GOLD][i]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(BTN / 2.0))
		_btn.add_theme_stylebox_override(st[i], sb)
	_btn.pressed.connect(func(): _set_open(not _open, true))
	_root.add_child(_btn)
	NotifDot.attach(_btn, Callable(), false)

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.02, 0.96)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 12
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 4)
	_tabs.add_theme_constant_override("v_separation", 4)
	col.add_child(_tabs)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 4)
	col.add_child(_head)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	col.add_child(_body)

## Bouton en bas à gauche, panneau juste au-dessus ; le tout reste dans l'écran.
func _place() -> void:
	if _btn == null:
		return
	var vp := _root.get_viewport_rect().size
	_btn.position = Vector2(MARGIN, vp.y - BTN - MARGIN)
	_btn.size = Vector2(BTN, BTN)
	var w := minf(PANEL_W, vp.x - 2.0 * MARGIN)
	var h := minf(PANEL_H, vp.y - BTN - 3.0 * MARGIN - 8.0)
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.size = Vector2(w, h)
	_panel.position = Vector2(MARGIN, vp.y - BTN - 2.0 * MARGIN - h)

# ------------------------------------------------------------------ ouverture / repli

## Ouvre le panneau (menu « Tchat », bouton du hub) : il se replie dès que la souris l'a quitté.
func open_panel() -> void:
	_hold = 3.0
	_set_open(true, false)

func _set_open(on: bool, pin_by_click: bool) -> void:
	if on == _open:
		if on and pin_by_click:
			_pinned = true
		return
	_open = on
	_outside = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if on:
		_pinned = pin_by_click
		_panel.visible = true
		_panel.modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)
		_enter()
	else:
		_pinned = false
		_typing = false
		if _pane != null and is_instance_valid(_pane):
			_pane.stop()
			_pane.release_focus_inside()
		_gen += 1
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 0.0, 0.1)
		_tween.tween_callback(func(): _panel.visible = false)

func _popup_visible() -> bool:
	for p in _panel.find_children("*", "PopupMenu", true, false):
		if (p as PopupMenu).visible:
			return true
	return false

func _dialog_open() -> bool:
	return _dialogs.get_child_count() > 0

func _process(delta: float) -> void:
	if _btn == null:
		return
	var mouse := _root.get_viewport().get_mouse_position()
	var over_btn := _btn.get_global_rect().has_point(mouse)
	if not _open:
		if over_btn and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and get_tree().get_nodes_in_group("modal").is_empty():
			_set_open(true, false)
		return
	var over_panel := _panel.get_global_rect().grow(6.0).has_point(mouse)
	_hold = maxf(0.0, _hold - delta)
	if over_btn or over_panel or _pinned or _typing or _hold > 0.0 or _dialog_open() or _popup_visible():
		_outside = 0.0
		return
	_outside += delta
	if _outside >= CLOSE_DELAY:
		_set_open(false, false)

func _unhandled_key_input(event: InputEvent) -> void:
	if _open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _dialog_open():
		get_viewport().set_input_as_handled()
		_set_open(false, false)

func _input(event: InputEvent) -> void:
	# Échap dans la zone de saisie : on rend le clavier au jeu et le panneau se replie.
	if _open and _typing and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_set_open(false, false)

# ------------------------------------------------------------------ contenu

func _on_session() -> void:
	ChatPrefs.reset()
	if _open:
		_enter()

func _on_alerts() -> void:
	if _open:
		_refresh_dm_unread()

func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _label(text: String, color: Color = UiTheme.PARCH, size: int = 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _note(text: String, color: Color = UiTheme.DIM) -> Label:
	var l := _label(text, color, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 60
	return l

func _small_button(text: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	return b

func _reset_body() -> void:
	_gen += 1
	if _pane != null and is_instance_valid(_pane):
		_pane.stop()
	_pane = null
	_status = null
	_clear(_body)

## Point d'entrée à chaque ouverture : compte, charte, puis le dernier canal consulté.
func _enter() -> void:
	_rebuild_tabs()
	if not Cloud.is_configured():
		_reset_body()
		_body.add_child(_note(L.t("ui.cloud.err.not_configured")))
		return
	if not Cloud.is_signed_in():
		_view = "account"
		_reset_body()
		_rebuild_tabs()
		_body.add_child(_note(L.t("ui.chat.need_account")))
		var b := _small_button(L.t("ui.chat.open_account"), func(): AccountModal.open(_dialogs))
		b.custom_minimum_size.y = 34
		_body.add_child(b)
		return
	var uid := Cloud.user_id()
	if _charter_ok_for != uid:
		_view = "charter"
		_reset_body()
		_rebuild_tabs()
		_body.add_child(_note(L.t("ui.chat.loading")))
		var mine := _gen
		var r: Dictionary = await Chat.charter_state()
		if mine != _gen:
			return
		if not r.ok or not (r.data is Dictionary):
			_reset_body()
			_body.add_child(_note(str(r.get("message", L.t("ui.chat.unavailable"))), BAD))
			return
		var version := int(r.data.get("version", 1))
		if int(r.data.get("accepted", 0)) < version:
			_show_charter(version, int(r.data.get("accepted", 0)) > 0)
			return
		_charter_ok_for = uid
	_refresh_dm_unread()
	_show_channel(ChatPrefs.last())

func _show_charter(version: int, renewed: bool) -> void:
	_view = "charter"
	_reset_body()
	_rebuild_tabs()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	_body.add_child(sc)
	v.add_child(_label(L.t("ui.chat.charte_title"), GOLD, 15))
	v.add_child(_note(L.t("ui.chat.charte_updated") if renewed else L.t("ui.chat.charte_intro")))
	for k in CHARTER_KEYS:
		var l := _label("•  " + L.t(k), UiTheme.PARCH, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 60
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(l)
	_status = _label("", BAD, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ok := _small_button(L.t("ui.chat.charte_accept"), func(): _accept(version))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ok)
	h.add_child(_small_button(L.t("ui.chat.charte_refuse"), func(): _set_open(false, false)))
	_body.add_child(h)

func _accept(version: int) -> void:
	var r: Dictionary = await Chat.accept_charter(version)
	if r.ok:
		_charter_ok_for = Cloud.user_id()
		_show_channel(ChatPrefs.last())
	elif r.get("error_code", "") == "charte_obsolete":
		_charter_ok_for = ""
		_enter()
	elif _status != null and is_instance_valid(_status):
		_status.text = str(r.message)

## Rangée d'onglets : un par canal ouvert (avec sa bulle), « ＋ » pour en ajouter, ⚙ pour les réglages.
func _rebuild_tabs() -> void:
	_clear(_tabs)
	_clear(_head)
	if not Cloud.is_signed_in():
		return
	for r in ChatPrefs.active():
		var room: String = r
		var b := Button.new()
		b.text = ("🔕 " if ChatPrefs.is_muted(room) else "") + ChatPrefs.name_of(room)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = _view == "channel" and room == _room
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): _show_channel(room))
		_tabs.add_child(b)
		NotifDot.attach(b, func(): return _unread_of(room), true)
	var add := _small_button("＋", func(): _show_add(), L.t("ui.chatdock.add_tip"))
	add.add_theme_font_size_override("font_size", 14)
	_tabs.add_child(add)
	var cog := _small_button("⚙", func(): _show_settings(), L.t("ui.chatdock.settings_tip"))
	_tabs.add_child(cog)
	var pin := _small_button("📌" if not _pinned else "📍", func():
		_pinned = not _pinned
		_rebuild_tabs(), L.t("ui.chatdock.pin_tip"))
	pin.toggle_mode = false
	_tabs.add_child(pin)
	# ligne du canal courant : nom, notifications, fermeture
	if _view == "channel" and _room != "":
		var nm := _label(ChatPrefs.name_of(_room), GOLD, 14)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		_head.add_child(nm)
		var muted := ChatPrefs.is_muted(_room)
		_head.add_child(_small_button("🔕" if muted else "🔔", func():
			ChatPrefs.set_muted(_room, not ChatPrefs.is_muted(_room))
			ChatAlerts.changed.emit()
			_rebuild_tabs(), L.t("ui.chatdock.bell_off") if not muted else L.t("ui.chatdock.bell_on")))
		if not ChatPrefs.is_mandatory(_room):
			_head.add_child(_small_button("✕", func(): _close_channel(_room), L.t("ui.chatdock.close_channel")))

func _unread_of(room: String) -> int:
	if _view == "channel" and room == _room:
		return 0
	if ChatPrefs.is_muted(room):
		return 0
	if Chat.is_dm(room):
		return int(_dm_unread.get(room, 0))
	return ChatAlerts.unread_room(room)

func _refresh_dm_unread() -> void:
	if not Cloud.is_signed_in():
		return
	var r: Dictionary = await Chat.conversations()
	if not r.ok or not (r.data is Array):
		return
	_dm_unread = {}
	for c in r.data:
		var room := Chat.dm_room(str(c.get("player_id", "")))
		_dm_unread[room] = int(c.get("unread", 0))
		ChatPrefs.remember_name(room, str(c.get("pseudo", "")))

func _show_channel(room: String) -> void:
	_view = "channel"
	_room = room
	ChatPrefs.set_last(room)
	_reset_body()
	_rebuild_tabs()
	_pane = ChatPane.new()
	_pane.host = _dialogs
	_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pane.dm_requested.connect(_open_dm)
	_pane.charter_needed.connect(func():
		_charter_ok_for = ""
		_enter())
	_pane.blocked_someone.connect(func(): _show_channel(_room))
	_pane.typing_changed.connect(func(on: bool): _typing = on)
	_body.add_child(_pane)
	_pane.show_room(room)

func _close_channel(room: String) -> void:
	ChatPrefs.remove(room)
	ChatAlerts.changed.emit()
	_show_channel(ChatPrefs.active()[0])

func _open_dm(player_id: String, pseudo: String) -> void:
	var room := Chat.dm_room(player_id)
	if not ChatPrefs.add(room, pseudo):
		if _pane != null and is_instance_valid(_pane):
			_pane._say(L.t("ui.chatdock.full"), BAD)
		return
	ChatPrefs.remember_name(room, pseudo)
	_show_channel(room)

# ------------------------------------------------------------------ ajouter un canal

func _show_add() -> void:
	_view = "add"
	_reset_body()
	_rebuild_tabs()
	_body.add_child(_label(L.fa(L.t("ui.chatdock.add_title"), [ChatPrefs.active().size(), ChatPrefs.MAX_CHANNELS]), GOLD, 14))
	_status = _label("", BAD, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	sc.add_child(box)
	_body.add_child(sc)
	_body.add_child(_status)
	# salon de l'autre langue
	var other := "fr" if ChatPrefs.mandatory().has("en") else "en"
	if not ChatPrefs.is_active(other):
		box.add_child(_add_row("💬 " + Chat.room_name(other), L.t("ui.chatdock.other_lang"), other, ""))
	box.add_child(_label(L.t("ui.chatdock.privates"), UiTheme.DIM, 12))
	var hold := _note(L.t("ui.chat.loading"))
	box.add_child(hold)
	var mine := _gen
	var r: Dictionary = await Chat.conversations()
	if mine != _gen:
		return
	hold.queue_free()
	if not r.ok or not (r.data is Array):
		box.add_child(_note(str(r.get("message", L.t("ui.chat.unavailable"))), BAD))
		return
	var n := 0
	for c in r.data:
		var room := Chat.dm_room(str(c.get("player_id", "")))
		if ChatPrefs.is_active(room):
			continue
		n += 1
		var unread := int(c.get("unread", 0))
		box.add_child(_add_row("✉ " + str(c.get("pseudo", "?")), (L.fa(L.t("ui.chatdock.unread"), unread) if unread > 0 else str(c.get("body", "")).left(50)), room, str(c.get("pseudo", "?"))))
	if n == 0:
		box.add_child(_note(L.t("ui.chat.dm_none")))
	box.add_child(_note(L.t("ui.chatdock.dm_hint")))

func _add_row(title: String, sub: String, room: String, pseudo: String) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 42)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "%s\n%s" % [title, sub]
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func():
		if not ChatPrefs.add(room, pseudo):
			if _status != null and is_instance_valid(_status):
				_status.text = L.t("ui.chatdock.full")
			return
		_show_channel(room))
	return b

# ------------------------------------------------------------------ réglages

func _show_settings() -> void:
	_view = "settings"
	_reset_body()
	_rebuild_tabs()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	sc.add_child(v)
	_body.add_child(sc)
	v.add_child(_label(L.t("ui.chatdock.notif_title"), GOLD, 14))
	v.add_child(_note(L.t("ui.chatdock.notif_desc")))
	for r in ChatPrefs.active():
		var room: String = r
		var cb := CheckButton.new()
		cb.text = ChatPrefs.name_of(room) + ("  " + L.t("ui.chatdock.mandatory") if ChatPrefs.is_mandatory(room) else "")
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = not ChatPrefs.is_muted(room)
		cb.add_theme_font_size_override("font_size", 13)
		cb.toggled.connect(func(on: bool):
			ChatPrefs.set_muted(room, not on)
			ChatAlerts.changed.emit())
		v.add_child(cb)
	v.add_child(HSeparator.new())
	var dm := CheckButton.new()
	dm.text = L.t("ui.chat.dm_accept")
	dm.focus_mode = Control.FOCUS_NONE
	dm.button_pressed = true
	dm.add_theme_font_size_override("font_size", 13)
	v.add_child(dm)
	_status = _label("", BAD, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var mine := _gen
	var o: Dictionary = await Chat.dm_open()
	if mine != _gen:
		return
	if o.ok and o.data is bool:
		dm.set_pressed_no_signal(bool(o.data))
	dm.toggled.connect(func(on: bool):
		var u: Dictionary = await Chat.set_dm_open(on)
		if mine == _gen and _status != null and is_instance_valid(_status):
			_status.text = (L.t("ui.chat.dm_open_on") if on else L.t("ui.chat.dm_open_off")) if u.ok else str(u.message)
			_status.add_theme_color_override("font_color", GOOD if u.ok else BAD))
	v.add_child(_small_button(L.t("ui.chat.blocked_btn"), func(): _show_blocked()))
	v.add_child(_small_button(L.t("ui.help.how"), func(): DocModal.guide(_dialogs, "tchat")))
	v.add_child(_small_button("‹ " + L.t("ui.chat.back"), func(): _show_channel(ChatPrefs.last())))

func _show_blocked() -> void:
	_view = "blocked"
	_reset_body()
	_rebuild_tabs()
	_body.add_child(_label(L.t("ui.chat.blocked_title"), GOLD, 14))
	_body.add_child(_note(L.t("ui.chat.blocked_desc")))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	_body.add_child(sc)
	_status = _label("", BAD, 12)
	_body.add_child(_status)
	_body.add_child(_small_button("‹ " + L.t("ui.chat.back"), func(): _show_settings()))
	_fill_blocked(box, _gen)

func _fill_blocked(box: VBoxContainer, mine: int) -> void:
	var r: Dictionary = await Chat.blocked()
	if mine != _gen:
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		box.add_child(_note(str(r.get("message", "")), BAD))
		return
	if (r.data as Array).is_empty():
		box.add_child(_note(L.t("ui.chat.blocked_none")))
		return
	for p in r.data:
		var h := HBoxContainer.new()
		var n := _label(str(p.get("pseudo", "?")))
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var pid := str(p.get("player_id", ""))
		var b := _small_button(L.t("ui.chat.unblock"), func(): pass)
		b.pressed.connect(func():
			b.disabled = true
			var u: Dictionary = await Chat.unblock(pid)
			if mine == _gen:
				if u.ok:
					_fill_blocked(box, mine)
				elif _status != null and is_instance_valid(_status):
					_status.text = str(u.message))
		h.add_child(b)
		box.add_child(h)
