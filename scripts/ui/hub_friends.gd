class_name HubFriends
extends RefCounted
## Onglet « Amis » du mode en ligne : ajouter un ami par son pseudo, demandes reçues (accepter / refuser), mes amis (état en ligne,
## dernière connexion, message privé, retirer) et demandes envoyées (annuler). Les règles sont appliquées par le serveur (Friends).

var _body: VBoxContainer
var _stale: Callable                 ## renvoie true quand l'onglet n'est plus affiché ou la fenêtre fermée
var _refit: Callable
var _host: Node
var _on_close: Callable             ## ferme la fenêtre du hub (avant d'ouvrir le tchat)
var _on_count: Callable             ## reçoit le nombre de demandes reçues (pastille de l'onglet)
var _status: Label
var _input: LineEdit

static func build(body: VBoxContainer, host: Node, stale: Callable, refit: Callable, on_close: Callable, on_count: Callable) -> HubFriends:
	var f := HubFriends.new()
	f._body = body
	f._host = host
	f._stale = stale
	f._refit = refit
	f._on_close = on_close
	f._on_count = on_count
	f._load()
	return f

func _gone() -> bool:
	return _stale.call()

func _load() -> void:
	for ch in _body.get_children():
		ch.queue_free()
	var wait := HubKit.label(L.t("ui.hub.loading"), UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER)
	_body.add_child(wait)
	var r: Dictionary = await Friends.list()
	if _gone():
		return
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	if not r.ok or not (r.data is Dictionary):
		_body.add_child(HubKit.label(str(r.get("message", "")), HubKit.BAD, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var d: Dictionary = r.data
	_on_count.call((d.get("incoming", []) as Array).size())
	_render(d)
	_refit.call()

func _render(d: Dictionary) -> void:
	# --- ajouter un ami
	var add := HubKit.card()
	_body.add_child(add)
	var av := HubKit.vbox(6)
	add.add_child(av)
	av.add_child(HubKit.label(L.t("ui.friends.add_title"), UiTheme.GOLD, 15, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	av.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = L.t("ui.friends.add_hint")
	_input.max_length = 20
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _send())
	row.add_child(_input)
	row.add_child(HubKit.button(L.t("ui.friends.add_btn"), _send, true, 34))
	_status = HubKit.label("", UiTheme.DIM, 12)
	av.add_child(_status)
	var open := CheckBox.new()
	open.text = L.t("ui.friends.open")
	open.tooltip_text = L.t("ui.friends.open_tip")
	open.button_pressed = bool(d.get("requests_open", true))
	open.focus_mode = Control.FOCUS_NONE
	open.toggled.connect(func(on: bool):
		var r: Dictionary = await Friends.set_open(on)
		if _gone():
			return
		if not r.ok:
			_say(str(r.message), HubKit.BAD)
			open.set_pressed_no_signal(not on)
		else:
			_say(L.t("ui.friends.open_on") if on else L.t("ui.friends.open_off"), HubKit.GOOD))
	av.add_child(open)
	# --- demandes reçues
	var incoming: Array = d.get("incoming", [])
	if not incoming.is_empty():
		var card := _section(L.fa(L.t("ui.friends.incoming"), [incoming.size()]), HubKit.WARN)
		for x in incoming:
			var pid := str(x.get("player_id", ""))
			var h := _row(card, "%s  ·  %s" % [str(x.get("pseudo", "?")), L.fa(L.t("ui.friends.level"), [int(x.get("level", 1))])], UiTheme.PARCH)
			h.add_child(HubKit.button(L.t("ui.friends.accept"), func(): _act(func(): return await Friends.accept(pid), L.t("ui.friends.accepted")), true, 32))
			h.add_child(HubKit.button(L.t("ui.friends.decline"), func(): _act(func(): return await Friends.decline(pid), L.t("ui.friends.declined")), false, 32))
	# --- mes amis
	var friends: Array = d.get("friends", [])
	var online_n := friends.filter(func(x): return bool(x.get("online", false))).size()
	var fc := _section(L.fa(L.t("ui.friends.list"), [friends.size(), Friends.MAX_FRIENDS]) + (("  ·  " + L.fa(L.t("ui.friends.online_n"), [online_n])) if online_n > 0 else ""), UiTheme.GOLD)
	if friends.is_empty():
		fc.add_child(HubKit.label(L.t("ui.friends.none"), UiTheme.DIM, 13))
	for x in friends:
		var pid2 := str(x.get("player_id", ""))
		var pseudo := str(x.get("pseudo", "?"))
		var online := bool(x.get("online", false))
		var when := L.t("ui.friends.online") if online else (L.fa(L.t("ui.friends.last_login"), [SuperAdminModal.date(x.get("last_login"))]) if x.get("last_login") != null else L.t("ui.friends.never"))
		var h2 := _row(fc, "%s %s%s  ·  %s" % ["🟢" if online else "⚫", StaffBadges.mark(pid2) + " " if StaffBadges.mark(pid2) != "" else "", pseudo, L.fa(L.t("ui.friends.level"), [int(x.get("level", 1))])], HubKit.GOOD if online else UiTheme.PARCH)
		var wl := HubKit.label(when, HubKit.GOOD if online else UiTheme.DIM, 12, false, false, HORIZONTAL_ALIGNMENT_RIGHT)
		h2.add_child(wl)
		h2.add_child(HubKit.button("✉", func():
			_on_close.call()
			ChatDock.open_private(pid2, pseudo), false, 32))
		var mail: Button = h2.get_child(h2.get_child_count() - 1)
		mail.tooltip_text = L.t("ui.chat.write_private")
		mail.custom_minimum_size.x = 44
		h2.add_child(HubKit.button(L.t("ui.friends.remove"), func():
			Dialogs.confirm(_host, L.t("ui.friends.remove_title"), L.fa(L.t("ui.friends.remove_confirm"), [pseudo]),
				func(): _act(func(): return await Friends.remove(pid2), L.fa(L.t("ui.friends.removed"), [pseudo])), L.t("ui.friends.remove")), false, 32))
	# --- demandes envoyées
	var outgoing: Array = d.get("outgoing", [])
	if not outgoing.is_empty():
		var oc := _section(L.fa(L.t("ui.friends.outgoing"), [outgoing.size()]), UiTheme.DIM)
		for x in outgoing:
			var pid3 := str(x.get("player_id", ""))
			var h3 := _row(oc, "%s  ·  %s" % [str(x.get("pseudo", "?")), L.fa(L.t("ui.friends.sent_on"), [SuperAdminModal.date(x.get("at"))])], UiTheme.PARCH)
			h3.add_child(HubKit.button(L.t("ui.friends.cancel"), func(): _act(func(): return await Friends.cancel(pid3), L.t("ui.friends.cancelled")), false, 32))

func _section(title: String, color: Color) -> VBoxContainer:
	var card := HubKit.card()
	_body.add_child(card)
	var v := HubKit.vbox(6)
	card.add_child(v)
	v.add_child(HubKit.label(title, color, 15, true))
	return v

## Une ligne : texte à gauche (qui prend la place), boutons ajoutés ensuite à droite.
func _row(parent: Control, text: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := HubKit.label(text, color, 14)
	h.add_child(l)
	parent.add_child(h)
	return h

func _say(text: String, color: Color) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", color)

func _send() -> void:
	var pseudo := _input.text.strip_edges()
	if pseudo == "":
		return
	_input.editable = false
	var r: Dictionary = await Friends.request_pseudo(pseudo)
	if _gone():
		return
	if _input != null and is_instance_valid(_input):
		_input.editable = true
	if r.ok:
		_input.text = ""
		var accepted := str(r.data) == "accepted"
		await _load()
		_say(L.fa(L.t("ui.friends.now_friends") if accepted else L.t("ui.friends.sent"), [pseudo]), HubKit.GOOD)
	else:
		_say(str(r.message), HubKit.BAD)

## Lance une action puis recharge la liste ; en cas d'échec, le message du serveur s'affiche.
func _act(call: Callable, ok_text: String) -> void:
	var r: Dictionary = await call.call()
	if _gone():
		return
	if r.ok:
		await _load()
		_say(ok_text, HubKit.GOOD)
	else:
		_say(str(r.message), HubKit.BAD)
