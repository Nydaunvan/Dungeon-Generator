extends SceneTree
## Onglet « Amis » du mode en ligne, sans réseau : faux serveur à état (demandes, acceptation, refus, annulation, retrait, demandes fermées).
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/check_friends.gd

var fails := 0
var friends: Array = [{"player_id": "p-bob", "pseudo": "Bob", "level": 3, "online": true, "last_login": "2026-10-16T19:00:00+00:00", "since": "2026-10-10T10:00:00+00:00"},
	{"player_id": "p-dan", "pseudo": "Dan", "level": 1, "online": false, "last_login": null, "since": "2026-10-11T10:00:00+00:00"}]
var incoming: Array = [{"player_id": "p-eve", "pseudo": "Eve", "level": 2, "at": "2026-10-16T18:00:00+00:00"}]
var outgoing: Array = []
var requests_open := true
var calls: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print(("OK  : " if cond else "ÉCHEC : ") + label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func err(code: String) -> Dictionary:
	return resp(400, {"message": code})

func take(arr: Array, pid: String) -> Variant:
	for i in arr.size():
		if arr[i].player_id == pid:
			return arr.pop_at(i)
	return null

func fake(_m: int, u: String, _h: PackedStringArray, body: String) -> Dictionary:
	var name := u.get_slice("/rpc/", 1)
	var b: Dictionary = JSON.parse_string(body) if body != "" else {}
	calls.append(name)
	match name:
		"friend_list":
			return resp(200, {"requests_open": requests_open, "friends": friends, "incoming": incoming, "outgoing": outgoing})
		"friend_pending_count":
			return resp(200, incoming.size())
		"friend_request_pseudo":
			var ps := str(b.p_pseudo)
			if ps.to_lower() == "moi":
				return err("pas_soi_meme")
			if ps.to_lower() == "zed":
				return err("joueur_inconnu")
			if ps.to_lower() == "fermé":
				return err("demandes_fermees")
			if friends.any(func(x): return str(x.pseudo).to_lower() == ps.to_lower()):
				return err("deja_ami")
			outgoing.append({"player_id": "p-" + ps.to_lower(), "pseudo": ps, "level": 1, "at": "2026-10-16T20:00:00+00:00"})
			return resp(200, "sent")
		"friend_accept":
			var x = take(incoming, str(b.p_player))
			if x == null:
				return err("demande_introuvable")
			x["online"] = false
			x["last_login"] = null
			x["since"] = "2026-10-16T20:00:00+00:00"
			friends.append(x)
			return resp(204)
		"friend_decline":
			return resp(204) if take(incoming, str(b.p_player)) != null else err("demande_introuvable")
		"friend_cancel":
			return resp(204) if take(outgoing, str(b.p_player)) != null else err("demande_introuvable")
		"friend_remove":
			take(friends, str(b.p_player))
			return resp(204)
		"friend_set_open":
			requests_open = bool(b.p_open)
			return resp(204)
	return resp(404, {"message": "inconnu"})

func texts(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		texts(c, out)
	return out

func btn(n: Node, t: String) -> Button:
	if n is Button and not (n is CheckBox) and (n as Button).text.begins_with(t) and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var r := btn(c, t)
		if r != null:
			return r
	return null

func has(n: Node, t: String) -> bool:
	return texts(n).any(func(x): return str(x).contains(t))

func settle(s: float = 0.7) -> void:
	await create_timer(s).timeout

func _init() -> void:
	root.size = Vector2i(1280, 900)
	await process_frame
	var Cloud = root.get_node("Cloud")
	Cloud._transport = Callable(self, "fake")
	Cloud._presence_timer.stop()
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "me", "expires_at": 9999999999.0, "pseudo": "Nyra"}
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var hub = load("res://scripts/ui/online_hub.gd").open(host, Callable(), "friends")
	await settle(1.2)
	var m = hub._modal
	check("l'onglet Amis existe et s'ouvre", hub._tab_buttons.has("friends"))
	check("liste : amis affichés avec leur état", has(m, "🟢 Bob") and has(m, "⚫ Dan") and has(m, "Mes amis (2/100)") and has(m, "1 en ligne"))
	check("liste : Bob en ligne, Dan jamais vu", has(m, "En ligne") and has(m, "Pas encore vu"))
	check("demande reçue affichée avec ses boutons", has(m, "Demandes reçues (1)") and has(m, "Eve") and btn(m, "Accepter") != null and btn(m, "Refuser") != null)
	check("pastille de l'onglet : demandes reçues", str(hub._tab_buttons.friends.text).contains("(1)"))

	# accepter
	btn(m, "Accepter").pressed.emit()
	await settle()
	check("accepter : Eve devient amie, la demande disparaît", has(m, "⚫ Eve") and has(m, "Mes amis (3/100)") and not has(m, "Demandes reçues"))
	check("accepter : message de confirmation", has(m, "Demande acceptée"))
	check("accepter : la pastille s'efface", not str(hub._tab_buttons.friends.text).contains("("))

	# ajouter un ami
	var fr = hub._friends
	fr._input.text = "Zed"
	fr._send()
	await settle()
	check("ajout d'un inconnu : message d'erreur du serveur", has(m, "Joueur introuvable") or has(m, "joueur") or fr._status.text != "")
	var msg_unknown: String = fr._status.text
	fr = hub._friends
	fr._input.text = "Fred"
	fr._send()
	await settle()
	check("ajout : demande envoyée, visible dans « Demandes envoyées »", has(m, "Demandes envoyées (1)") and has(m, "Fred") and has(m, "Demande d'ami envoyée à Fred."))
	fr = hub._friends
	fr._input.text = "Bob"
	fr._send()
	await settle()
	check("ajout d'un ami déjà ami : refusé avec le message du serveur", fr._status.text != "" and fr._status.text != msg_unknown or has(m, "déjà amis"))
	check("ajout d'un ami déjà ami : message traduit", has(m, "Vous êtes déjà amis."))
	fr = hub._friends
	fr._input.text = "moi"
	fr._send()
	await settle()
	check("s'ajouter soi-même : refusé", has(m, "Vous ne pouvez pas vous ajouter vous-même."))

	# annuler
	btn(m, "Annuler").pressed.emit()
	await settle()
	check("annuler la demande envoyée", not has(m, "Demandes envoyées") and has(m, "Demande annulée."))

	# retirer un ami (avec confirmation)
	var before := friends.size()
	var rm: Button = null
	for c in m.find_children("*", "Button", true, false):
		if (c as Button).text == "Retirer" and (c as Button).is_visible_in_tree():
			rm = c
			break
	rm.pressed.emit()
	await settle(0.5)
	var conf := btn(root, "Retirer")
	check("retirer : une confirmation est demandée", friends.size() == before)
	for c in root.find_children("*", "Button", true, false):
		if (c as Button).text == "Retirer" and (c as Button).is_visible_in_tree() and (c as Button) != rm and not m.is_ancestor_of(c):
			conf = c
	conf.pressed.emit()
	await settle()
	check("retirer : l'ami disparaît de la liste", friends.size() == before - 1 and has(m, "Mes amis (%d/100)" % (before - 1)))

	# demandes fermées
	var cb: CheckBox = m.find_children("*", "CheckBox", true, false)[0]
	cb.button_pressed = false
	await settle()
	check("demandes fermées : réglage envoyé au serveur", not requests_open and calls.has("friend_set_open") and has(m, "Les demandes d'ami sont fermées."))
	fr = hub._friends
	fr._input.text = "Fermé"
	fr._send()
	await settle()
	check("joueur aux demandes fermées : message traduit", has(m, "Ce joueur n'accepte pas les demandes d'ami."))

	# refuser (nouvelle demande reçue)
	incoming.append({"player_id": "p-gus", "pseudo": "Gus", "level": 5, "at": "2026-10-16T21:00:00+00:00"})
	hub._show("friends")
	await settle()
	btn(m, "Refuser").pressed.emit()
	await settle()
	check("refuser : la demande disparaît sans créer d'ami", incoming.is_empty() and not friends.any(func(x): return x.pseudo == "Gus"))

	# hors connexion
	Cloud.session = {}
	hub._show("friends")
	await settle(0.4)
	check("sans compte : invitation à se connecter", has(m, "Connectez-vous pour gérer vos amis."))
	Cloud._transport = Callable()
	print("check_friends : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
