extends Node
## Vérifie le module de compte en ligne (autoload Cloud) SANS réseau, avec un faux transport HTTP :
## inscription (pseudo invalide / pris / confirmation d'email demandée ou non), connexion, session mémorisée, rafraîchissement du
## jeton (y compris refusé ou hors ligne), codes d'erreur traduits, en-têtes envoyés, déconnexion.
## Lancer : godot --headless --path . res://tools/check_cloud.tscn

var fails := 0
var calls: Array = []        # requêtes faites : {method, url, headers, body}
var queue: Array = []        # réponses à renvoyer, dans l'ordre

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func offline() -> Dictionary:
	return {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()}

func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"method": method, "url": full_url, "headers": headers, "body": body})
	if queue.is_empty():
		return resp(500, {"error": "file vide"})
	return queue.pop_front()

func session_json(access: String, refresh: String, expires_in: int, pseudo: String = "Nyra") -> Dictionary:
	return {"access_token": access, "refresh_token": refresh, "expires_in": expires_in, "token_type": "bearer",
		"user": {"id": "u-1", "email": "nyra@example.org", "user_metadata": {"pseudo": pseudo}}}

func header_of(call: Dictionary, name: String) -> String:
	for h in call.headers:
		if h.begins_with(name + ": "):
			return h.substr(name.length() + 2)
	return ""

func reset() -> void:
	calls.clear()
	queue.clear()
	Cloud.session = {}
	if FileAccess.file_exists(Cloud.SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Cloud.SESSION_PATH))

func _ready() -> void:
	var saved_url := Cloud.url
	var saved_key := Cloud.key
	check("configuration chargée", Cloud.is_configured())
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"

	# --- non configuré
	reset()
	var u := Cloud.url
	Cloud.url = ""
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/x")
	check("non configuré : refus", not r.ok and r.error_code == "not_configured" and calls.is_empty())
	Cloud.url = u

	# --- inscription : pseudo invalide (aucun appel réseau)
	reset()
	r = await Cloud.sign_up("nyra@example.org", "motdepasse1", "a!")
	check("pseudo invalide refusé sans réseau", not r.ok and r.error_code == "pseudo_invalide" and calls.is_empty())

	# --- inscription : pseudo déjà pris
	reset()
	queue = [resp(200, false)]
	r = await Cloud.sign_up("nyra@example.org", "motdepasse1", "Nyra")
	check("pseudo pris refusé", not r.ok and r.error_code == "pseudo_pris" and calls.size() == 1)
	check("pseudo pris : texte traduit", r.message != "" and not r.message.begins_with("ui."))
	check("appel anonyme : clé publique, pas de jeton", header_of(calls[0], "apikey") == Cloud.key and header_of(calls[0], "Authorization") == "")

	# --- inscription avec confirmation d'email : pas de session
	reset()
	queue = [resp(200, true), resp(200, {"id": "u-1", "email": "nyra@example.org"})]
	r = await Cloud.sign_up("nyra@example.org", "motdepasse1", "Nyra")
	check("inscription avec confirmation", r.ok and r.needs_confirmation and not Cloud.is_signed_in())
	check("le pseudo part dans les métadonnées", str(JSON.parse_string(calls[1].body).get("data", {}).get("pseudo", "")) == "Nyra")

	# --- inscription sans confirmation : connecté d'emblée
	reset()
	queue = [resp(200, true), resp(200, session_json("A1", "R1", 3600))]
	r = await Cloud.sign_up("nyra@example.org", "motdepasse1", "Nyra")
	check("inscription sans confirmation : connecté", r.ok and not r.needs_confirmation and Cloud.is_signed_in() and Cloud.pseudo() == "Nyra")
	var saved := FileAccess.get_file_as_string(Cloud.SESSION_PATH)
	check("session écrite", saved != "" and "R1" in saved)
	check("le mot de passe n'est jamais mémorisé", not ("motdepasse1" in saved))

	# --- connexion : mauvais identifiants, puis réussie (avec relecture du profil)
	reset()
	queue = [resp(400, {"error_code": "invalid_credentials", "msg": "Invalid login credentials"})]
	r = await Cloud.sign_in("nyra@example.org", "faux")
	check("mauvais mot de passe", not r.ok and r.error_code == "invalid_credentials" and not Cloud.is_signed_in())
	queue = [resp(200, session_json("A2", "R2", 3600, "Ancien")), resp(200, [{"pseudo": "NyraLaRouge"}])]
	r = await Cloud.sign_in("nyra@example.org", "bon")
	check("connexion réussie", r.ok and Cloud.is_signed_in() and Cloud.email() == "nyra@example.org")
	check("pseudo relu depuis le profil", Cloud.pseudo() == "NyraLaRouge")
	check("profil demandé avec le jeton du joueur", header_of(calls[calls.size() - 1], "Authorization") == "Bearer A2")

	# --- code d'erreur de nos garde-fous SQL et limites de débit
	queue = [resp(400, {"code": "P0001", "message": "trop_de_publications"})]
	r = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/dungeons", {"title": "x"}, true)
	check("garde-fou SQL reconnu", not r.ok and r.error_code == "trop_de_publications" and not r.message.begins_with("ui."))
	queue = [resp(429, {"message": "slow down"})]
	r = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/x", null, true)
	check("429 : limite de débit", r.error_code == "over_request_rate_limit")
	queue = [resp(403, {"message": "new row violates row-level security policy"})]
	r = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/x", null, true)
	check("403 : refusé", r.error_code == "refused" and Cloud.is_signed_in())

	# --- jeton expiré : rafraîchi avant la requête
	Cloud.session["expires_at"] = Time.get_unix_time_from_system() + 10.0
	calls.clear()
	queue = [resp(200, session_json("A3", "R3", 3600)), resp(200, [])]
	r = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/dungeons", null, true)
	check("jeton proche de l'expiration : rafraîchi", calls.size() == 2 and "grant_type=refresh_token" in calls[0].url)
	check("la requête utilise le nouveau jeton", header_of(calls[1], "Authorization") == "Bearer A3" and r.ok)

	# --- hors ligne : la session est conservée
	Cloud.session["expires_at"] = 0.0
	queue = [offline()]
	r = await Cloud.refresh()
	check("hors ligne : erreur claire", not r.ok and r.offline and r.error_code == "offline")
	check("hors ligne : session conservée", Cloud.is_signed_in())
	queue = [offline()]
	r = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/x", null, true)
	check("requête authentifiée hors ligne : session_expired sans effacer", not r.ok and Cloud.is_signed_in())

	# --- jeton de rafraîchissement refusé : session effacée
	queue = [resp(400, {"error_code": "refresh_token_not_found", "msg": "Invalid Refresh Token"})]
	r = await Cloud.refresh()
	check("jeton refusé : déconnecté", not r.ok and not Cloud.is_signed_in())
	check("fichier de session supprimé", not FileAccess.file_exists(Cloud.SESSION_PATH))

	# --- déconnexion
	reset()
	queue = [resp(200, session_json("A4", "R4", 3600))]
	await Cloud.sign_in("nyra@example.org", "bon")
	queue = [resp(204)]
	await Cloud.sign_out()
	check("déconnexion", not Cloud.is_signed_in() and not FileAccess.file_exists(Cloud.SESSION_PATH))

	# --- mot de passe oublié
	reset()
	queue = [resp(200, {})]
	r = await Cloud.reset_password("nyra@example.org")
	check("mot de passe oublié", r.ok and "/auth/v1/recover" in calls[0].url)

	# --- relecture d'une session mémorisée au lancement (sans réseau)
	reset()
	var f := FileAccess.open(Cloud.SESSION_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"access_token": "A5", "refresh_token": "R5", "expires_at": 0.0, "user_id": "u-1", "email": "n@e.org", "pseudo": "Nyra"}))
	f.close()
	Cloud._load_session()
	check("session relue sans appel réseau", Cloud.is_signed_in() and Cloud.pseudo() == "Nyra" and calls.is_empty())

	reset()
	Cloud._transport = Callable()
	Cloud.url = saved_url
	Cloud.key = saved_key
	print("check_cloud : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
