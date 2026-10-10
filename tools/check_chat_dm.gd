extends Node
## Messages privés et bulle rouge, avec un faux serveur : compteur de non-lus, onglet « Privés », liste des conversations, ouverture d'une
## conversation (lecture + marquage « lu »), envoi d'un message privé, bascule « accepter les privés », bulle rouge sur un bouton.
## Lancer : xvfb-run -a godot --path . res://tools/check_chat_dm.tscn --quit-after 900

var fails := 0
var calls: Array = []
var unread := {"dm": 2, "rooms": {"fr": 1}, "total": 3}
var read_marks: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"url": full_url, "body": body})
	if full_url.contains("chat_charte_etat"):
		return resp(200, {"version": 1, "accepted": 1})
	if full_url.contains("chat_unread"):
		return resp(200, unread)
	if full_url.contains("chat_conversations"):
		return resp(200, [{"player_id": "11111111-1111-1111-1111-111111111111", "pseudo": "Alice", "last_id": 9, "body": "Salut toi", "created_at": "2026-10-10T10:00:00+00:00", "mine": false, "unread": 2}])
	if full_url.contains("chat_fetch_dm"):
		return resp(200, [{"id": 9, "player_id": "11111111-1111-1111-1111-111111111111", "pseudo": "Alice", "body": "Salut toi", "created_at": "2026-10-10T10:00:00+00:00", "level": 3, "color": null}])
	if full_url.contains("chat_send_dm"):
		return resp(200, {"id": 10})
	if full_url.contains("chat_mark_read"):
		read_marks.append(body)
		unread = {"dm": 0, "rooms": {"fr": 1}, "total": 1}
		return resp(204)
	if full_url.contains("chat_dm_open"):
		return resp(200, true)
	if full_url.contains("chat_set_dm"):
		return resp(204)
	if full_url.contains("chat_fetch"):
		return resp(200, [])
	return resp(200, [])

func texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		texts(c, out)
	return out

func _ready() -> void:
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra"}
	var host := CanvasLayer.new()
	add_child(host)

	# --- compteur de non-lus et bulle rouge
	ChatAlerts.refresh()
	for i in 10:
		await get_tree().process_frame
	check("compteur de non-lus lu", ChatAlerts.total == 3 and ChatAlerts.dm == 2 and ChatAlerts.unread_room("fr") == 1)
	var btn := Button.new()
	host.add_child(btn)
	var dot := NotifDot.attach(btn)
	await get_tree().process_frame
	check("la bulle est visible quand il y a du nouveau", dot.visible)
	ChatAlerts.apply({"dm": 0, "rooms": {}, "total": 0})
	await get_tree().process_frame
	check("la bulle disparaît à zéro", not dot.visible)
	ChatAlerts.apply(unread)

	# --- fenêtre du tchat : onglet Privés
	var c := ChatModal.open(host)
	for i in 40:
		await get_tree().process_frame
	check("onglet Privés présent", texts(c._modal).any(func(t): return "Privés" in t))
	c._show_dms()
	for i in 40:
		await get_tree().process_frame
	var t: Array = texts(c._modal)
	check("conversation listée", t.any(func(x): return "Alice" in x and "Salut toi" in x))
	check("option accepter les privés", t.any(func(x): return "Accepter les messages privés" in x))
	# --- ouverture d'une conversation
	calls.clear()
	c._open_dm("11111111-1111-1111-1111-111111111111", "Alice")
	for i in 60:
		await get_tree().process_frame
	check("lecture de la conversation", calls.any(func(k): return str(k.url).ends_with("chat_fetch_dm") and str(k.body).contains("11111111-1111")))
	check("message affiché", texts(c._modal).any(func(x): return x == "Salut toi"))
	check("conversation marquée lue", read_marks.size() >= 1 and read_marks[0].contains("dm:11111111-1111-1111-1111-111111111111") and read_marks[0].contains("9"))
	check("compteur mis à jour après lecture", ChatAlerts.dm == 0)
	# --- envoi
	calls.clear()
	c._input.text = "Bonjour Alice"
	c._send()
	for i in 40:
		await get_tree().process_frame
	check("envoi par chat_send_dm", calls.any(func(k): return str(k.url).ends_with("chat_send_dm") and str(k.body).contains("p_to") and str(k.body).contains("Bonjour Alice")))
	check("pas d'envoi dans un salon public", not calls.any(func(k): return str(k.url).ends_with("/chat_send")))
	print("check_chat_dm : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
