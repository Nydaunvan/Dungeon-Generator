extends Node
## Vérifie la fenêtre « Compte » sans réseau (faux transport) : formulaire, validations côté jeu, connexion, déconnexion, suppression.
## Lancer : godot --headless --path . res://tools/check_account.tscn   (avec --shot <png> et un affichage : capture d'écran)

var fails := 0
var calls: Array = []
var queue: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	calls.append(full_url)
	return queue.pop_front() if not queue.is_empty() else resp(500, {})

func sess(pseudo := "Nyra") -> Dictionary:
	return {"access_token": "A", "refresh_token": "R", "expires_in": 3600, "user": {"id": "u1", "email": "n@e.org", "user_metadata": {"pseudo": pseudo}}}

func _ready() -> void:
	Cloud._transport = Callable(self, "fake")
	Cloud.session = {}
	var layer := CanvasLayer.new()
	add_child(layer)
	var a := AccountModal.open(layer)
	await get_tree().process_frame
	check("formulaire de connexion", a._mode == "login" and a._email != null and a._pseudo == null and a._pass.secret)
	a._email.text = "pas-un-mail"
	a._submit()
	check("email invalide refusé sans réseau", calls.is_empty() and a._status.text != "")
	a._switch("signup")
	await get_tree().process_frame
	a._email.text = "n@e.org"; a._pseudo.text = "a!"; a._pass.text = "motdepasse1"
	a._submit()
	check("pseudo invalide refusé sans réseau", calls.is_empty())
	a._pseudo.text = "Nyra"; a._pass.text = "court"
	a._submit()
	check("mot de passe trop court refusé sans réseau", calls.is_empty())
	a._pass.text = "motdepasse1"
	queue = [resp(200, true), resp(200, {"id": "u1", "email": "n@e.org"})]
	await a._submit()
	check("confirmation demandée : retour à la connexion", a._mode == "login" and a._status.text != "")
	a._email.text = "n@e.org"; a._pass.text = "motdepasse1"
	queue = [resp(200, sess()), resp(200, [{"pseudo": "Nyra"}])]
	await a._submit()
	check("connexion : vue du compte", a._mode == "account" and Cloud.is_signed_in())
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[0] == "--shot":
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	queue = [resp(204)]
	await a._logout()
	check("déconnexion : retour au formulaire", a._mode == "login" and not Cloud.is_signed_in())
	Cloud._transport = Callable()
	print("check_account : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
