extends SceneTree
## Tchat des joueurs avec un faux serveur qui applique les mêmes codes d'erreur que le vrai : salons, affichage en texte brut,
## envoi (nettoyage, erreurs traduites, silence), mise à jour automatique, signalement, blocage, et onglet Tchat du super admin.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_chat.gd

var fails := 0
var calls: Array = []
var rooms := {"general": [], "fr": [], "en": []}
var next_id := 1
var send_error := ""
var send_hint = null
var blocked: Array = []
var is_admin := true
var reports: Array = [{"message_id": 7, "room": "fr", "body": "Un message limite", "created_at": "2026-10-10T15:00:00+00:00", "deleted": false,
	"player_id": "u-9", "pseudo": "Troll", "reports": 2, "last_report": "2026-10-10T15:30:00+00:00", "reasons": ["insulte"], "muted_until": null}]
var words := ["connard", "salaud"]

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	var body := "" if data == null else JSON.stringify(data)
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": body.to_utf8_buffer()}

func fail(msg: String, hint = null) -> Dictionary:
	return resp(400, {"code": "P0001", "message": msg, "details": null, "hint": hint})

func add_msg(room: String, pid: String, pseudo: String, body: String) -> void:
	rooms[room].append({"id": next_id, "player_id": pid, "pseudo": pseudo, "body": body, "created_at": "2026-10-10T16:00:00+00:00", "level": 3, "color": null})
	next_id += 1

func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"url": full_url, "body": body})
	var b: Variant = JSON.parse_string(body) if body != "" else {}
	if full_url.ends_with("/rpc/chat_fetch"):
		var after := int(b.get("p_after", 0))
		var out: Array = rooms[b.p_room].filter(func(m): return int(m.id) > after and not blocked.any(func(x): return x.player_id == m.player_id))
		return resp(200, out)
	if full_url.ends_with("/rpc/chat_send"):
		if send_error != "":
			return fail(send_error, send_hint)
		add_msg(b.p_room, "u-1", "Nyra", b.p_body)
		return resp(200, {"id": next_id - 1})
	if full_url.ends_with("/rpc/chat_report"):
		return resp(204)
	if full_url.ends_with("/rpc/chat_block"):
		blocked.append({"player_id": b.p_player, "pseudo": "Bob"})
		return resp(204)
	if full_url.ends_with("/rpc/chat_unblock"):
		blocked = blocked.filter(func(x): return x.player_id != b.p_player)
		return resp(204)
	if full_url.ends_with("/rpc/chat_blocked"):
		return resp(200, blocked)
	if full_url.ends_with("/rpc/is_super_admin"):
		return resp(200, is_admin)
	if full_url.contains("/rpc/admin_chat"):
		if not is_admin:
			return fail("acces_refuse")
		if full_url.ends_with("/admin_chat_stats"):
			return resp(200, {"messages_24h": 12, "authors_24h": 4, "messages_total": 80, "deleted_total": 2, "reports_pending": reports.size(), "mutes_active": 1, "blocks": 3, "words": words.size()})
		if full_url.ends_with("/admin_chat_reports"):
			return resp(200, reports)
		if full_url.ends_with("/admin_chat_delete") or full_url.ends_with("/admin_chat_dismiss"):
			reports = reports.filter(func(r): return int(r.message_id) != int(b.p_message_id))
			return resp(204)
		if full_url.ends_with("/admin_chat_mute"):
			return resp(204)
		if full_url.ends_with("/admin_chat_words"):
			return resp(200, words)
		if full_url.ends_with("/admin_chat_word_add"):
			if str(b.p_word).strip_edges() == "":
				return fail("mot_invalide")
			words.append(str(b.p_word).to_lower())
			return resp(204)
		if full_url.ends_with("/admin_chat_word_remove"):
			words.erase(str(b.p_word))
			return resp(204)
	return resp(404, {"message": "inconnu"})

func labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		labels(c, out)
	return out

func has_text(n: Node, part: String) -> bool:
	return labels(n).any(func(x): return str(x).contains(part))

func find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var r := find_button(c, text)
		if r != null:
			return r
	return null

func settle(frames: int = 30) -> void:
	for i in frames:
		await process_frame

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func count(part: String) -> int:
	return calls.filter(func(c): return str(c.url).ends_with(part)).size()

func _init() -> void:
	await process_frame
	var Cloud = root.get_node("Cloud")
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud._clear_session()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var CM: GDScript = load("res://scripts/ui/chat_modal.gd")
	var CH: GDScript = load("res://scripts/core/chat.gd")
	var SM: GDScript = load("res://scripts/ui/super_admin_modal.gd")
	CM.poll_fast = 0.15
	CM.poll_slow = 0.3

	# --- sans compte : rien n'est demandé au serveur
	var c0 = CM.open(host)
	await settle()
	check("hors connexion : invitation à se connecter", has_text(c0._modal, "réservé aux joueurs connectés") and has_text(c0._modal, "Mon compte"))
	check("hors connexion : aucun appel", calls.is_empty())
	c0._modal.close()

	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra", "email": "a@b.fr"}
	add_msg("fr", "u-2", "Bob", "Salut [b]tout[/b] le monde")
	add_msg("fr", "u-1", "Nyra", "Bonjour")
	add_msg("en", "u-2", "Bob", "Hello")

	# --- salon par défaut (langue du jeu) et affichage en texte brut
	var c = CM.open(host)
	await settle()
	await wait(0.2)
	check("salon Français chargé", calls.any(func(x): return str(x.url).ends_with("/rpc/chat_fetch") and str(x.body).contains("\"p_room\":\"fr\"")))
	check("messages affichés", has_text(c._modal, "Bonjour") and has_text(c._modal, "Bob (3) :"))
	check("balisage non interprété (texte brut)", has_text(c._modal, "Salut [b]tout[/b] le monde"))
	check("onglets des trois salons", has_text(c._modal, "Général") and has_text(c._modal, "Français") and has_text(c._modal, "English"))
	check("pas de menu sur ses propres messages", c._list.get_child(1).get_child_count() == 3 and c._list.get_child(0).get_child_count() == 4)

	# --- envoi
	calls.clear()
	c._input.text = "  Salut   à\ttous ​ "
	c._send()
	await wait(0.3)
	var sent: Array = calls.filter(func(x): return str(x.url).ends_with("/rpc/chat_send"))
	check("envoi : texte nettoyé", sent.size() == 1 and JSON.parse_string(sent[0].body).p_body == "Salut à tous")
	check("envoi : le message apparaît et la zone est vidée", has_text(c._modal, "Salut à tous") and c._input.text == "")
	var n_before := count("/rpc/chat_send")
	c._input.text = "   "
	c._send()
	await settle()
	check("message vide : rien envoyé", count("/rpc/chat_send") == n_before)

	# --- erreurs du serveur traduites
	for pair in [["chat_trop_rapide", "Doucement"], ["message_repete", "déjà"], ["message_refuse", "interdits"], ["message_trop_long", "trop long"]]:
		send_error = pair[0]
		c._input.text = "test"
		c._send()
		await wait(0.15)
		check("erreur %s affichée" % pair[0], has_text(c._modal, pair[1]) and c._input.text == "test")
	send_error = "chat_mute"
	send_hint = "2026-10-11 16:00:00+00"
	c._input.text = "test"
	c._send()
	await wait(0.15)
	check("silence : fin indiquée", has_text(c._modal, "réduit au silence jusqu'à"))
	send_error = ""
	send_hint = null
	check("nettoyage identique au serveur", CH.clean("a" + String.chr(0x202E) + "b" + String.chr(1) + "c  d") == "abc d" and CH.clean("x".repeat(400)).length() == 300)

	# --- mise à jour automatique : un message d'un autre joueur arrive sans rien faire
	add_msg("fr", "u-3", "Cléo", "Coucou du serveur")
	await wait(0.6)
	check("nouveau message reçu automatiquement", has_text(c._modal, "Coucou du serveur"))
	var polls: Array = calls.filter(func(x): return str(x.url).ends_with("/rpc/chat_fetch") and str(x.body).contains("\"p_after\":"))
	check("interrogation avec le dernier numéro connu", JSON.parse_string(polls[polls.size() - 1].body).p_after >= 4)
	var before: int = c._count
	await wait(0.5)
	check("pas de doublons à l'écran", c._count == before)

	# --- changement de salon
	calls.clear()
	c._show_room("en")
	await wait(0.3)
	check("salon English : messages du bon salon", has_text(c._modal, "Hello") and not has_text(c._modal, "Coucou du serveur"))
	check("salon English : bon appel", calls.any(func(x): return str(x.body).contains("\"p_room\":\"en\"")))

	# --- signalement et blocage
	calls.clear()
	c._report(3)
	await settle()
	check("signalement envoyé", calls.any(func(x): return str(x.url).ends_with("/rpc/chat_report") and str(x.body).contains("\"p_message_id\":3")) and has_text(c._modal, "Message signalé"))
	c._show_room("fr")
	await wait(0.3)
	c._do_block("u-2", "Bob")
	await wait(0.5)
	check("blocage : appel serveur", blocked.size() == 1 and blocked[0].player_id == "u-2")
	check("blocage : ses messages disparaissent", not has_text(c._modal, "Salut [b]tout[/b] le monde") and has_text(c._modal, "Bonjour"))
	c._show_blocked()
	await wait(0.2)
	check("liste des joueurs bloqués", has_text(c._modal, "Bob") and has_text(c._modal, "Débloquer"))
	find_button(c._modal, "Débloquer").pressed.emit()
	await wait(0.3)
	check("déblocage", blocked.is_empty() and has_text(c._modal, "Tu n'as bloqué personne."))
	c._modal.close()
	await settle()
	calls.clear()
	await wait(0.6)
	check("fenêtre fermée : plus aucune interrogation", calls.is_empty())

	# --- super admin : onglet Tchat
	var sm = SM.open(host)
	await settle()
	sm._show("chat")
	await wait(0.3)
	check("admin : statistiques", has_text(sm._modal, "Messages (24 h)") and has_text(sm._modal, "12") and has_text(sm._modal, "Activité du tchat"))
	check("admin : message signalé", has_text(sm._modal, "Un message limite") and has_text(sm._modal, "Troll") and has_text(sm._modal, "insulte"))
	check("admin : mots interdits", has_text(sm._modal, "connard ✕") and has_text(sm._modal, "Mots interdits (2)"))
	calls.clear()
	find_button(sm._modal, "Couper 24 h").pressed.emit()
	await wait(0.4)
	var mc: Array = calls.filter(func(x): return str(x.url).ends_with("/rpc/admin_chat_mute"))
	check("admin : coupure 24 h", mc.size() == 1 and JSON.parse_string(mc[0].body).p_minutes == 1440 and JSON.parse_string(mc[0].body).p_player == "u-9")
	find_button(sm._modal, "Supprimer").pressed.emit()
	await wait(0.4)
	check("admin : suppression puis liste mise à jour", count("/rpc/admin_chat_delete") == 1 and has_text(sm._modal, "Aucun signalement en attente."))
	var e: LineEdit = null
	for l in sm._modal.find_children("*", "LineEdit", true, false):
		e = l
	e.text = "Vilain"
	find_button(sm._modal, "Ajouter").pressed.emit()
	await wait(0.4)
	check("admin : mot ajouté", words.has("vilain") and has_text(sm._modal, "vilain ✕"))
	find_button(sm._modal, "salaud ✕").pressed.emit()
	await wait(0.4)
	check("admin : mot retiré", not words.has("salaud"))
	is_admin = false
	sm._show("chat")
	await wait(0.3)
	check("rôle retiré : refus affiché", has_text(sm._modal, "Accès refusé"))
	sm._modal.close()

	Cloud._clear_session()
	Cloud._transport = Callable()
	print("check_chat : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
