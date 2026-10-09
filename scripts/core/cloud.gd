extends Node
## Compte en ligne (Supabase) : inscription, connexion, session, mot de passe oublié, suppression du compte.
## Le jeu reste entièrement jouable hors ligne : rien ici n'est appelé au lancement, et aucune requête ne part tant que le joueur
## n'a pas ouvert son compte. La session mémorisée (jetons) est relue au lancement SANS appel réseau.
##
## Seule la clé PUBLIQUE (publishable) de data/cloud_config.json est dans le jeu ; ce qu'elle permet est borné par les règles d'accès
## de la base (supabase/migrations). La clé secrète (sb_secret_… / service_role) ne doit JAMAIS apparaître ici ni dans le dépôt.
## Les mots de passe ne sont ni mémorisés ni journalisés ; seule la session (jetons) est écrite dans user://cloud_session.json.
##
## Toutes les fonctions asynchrones renvoient un dictionnaire :
##   {ok, status, data, error_code, message, offline}   (message = texte traduit, prêt à afficher quand ok est faux)
## À utiliser avec await : `var r: Dictionary = await Cloud.sign_in(email, mot_de_passe)`.

signal session_changed

const CONFIG_PATH := "res://data/cloud_config.json"
const SESSION_PATH := "user://cloud_session.json"
const TIMEOUT := 10.0
const REFRESH_MARGIN := 60.0     ## on rafraîchit le jeton s'il expire dans moins de 60 s

## Code d'erreur (renvoyé par Supabase ou par les garde-fous de la base) → clé de texte traduit.
const ERR_KEYS := {
	"offline": "ui.cloud.err.offline",
	"not_configured": "ui.cloud.err.not_configured",
	"invalid_credentials": "ui.cloud.err.invalid_credentials",
	"email_not_confirmed": "ui.cloud.err.email_not_confirmed",
	"user_already_exists": "ui.cloud.err.user_already_exists",
	"email_exists": "ui.cloud.err.user_already_exists",
	"weak_password": "ui.cloud.err.weak_password",
	"validation_failed": "ui.cloud.err.invalid_input",
	"email_address_invalid": "ui.cloud.err.invalid_email",
	"signup_disabled": "ui.cloud.err.signup_disabled",
	"over_email_send_rate_limit": "ui.cloud.err.rate_limit",
	"over_request_rate_limit": "ui.cloud.err.rate_limit",
	"pseudo_pris": "ui.cloud.err.pseudo_pris",
	"pseudo_invalide": "ui.cloud.err.pseudo_invalide",
	"session_expired": "ui.cloud.err.session_expired",
	"refused": "ui.cloud.err.refused",
	"trop_de_publications": "ui.cloud.err.trop_de_publications",
	"trop_de_donjons": "ui.cloud.err.trop_de_donjons",
	"trop_de_parties_en_attente": "ui.cloud.err.trop_de_parties_en_attente",
	"trop_de_soumissions": "ui.cloud.err.trop_de_soumissions",
	"generic": "ui.cloud.err.generic",
}

var url := ""
var key := ""
## Session : access_token, refresh_token, expires_at (secondes Unix), user_id, email, pseudo. Vide = déconnecté.
var session: Dictionary = {}
## Transport HTTP remplaçable (tests hors réseau) : (méthode, url complète, en-têtes, corps texte) → {result, code, body}.
var _transport: Callable = Callable()
var _refreshing := false
signal _refresh_finished

func _ready() -> void:
	_load_config()
	_load_session()

# ------------------------------------------------------------------ état

func is_configured() -> bool:
	return url != "" and key != ""

func is_signed_in() -> bool:
	return str(session.get("refresh_token", "")) != ""

func pseudo() -> String:
	return str(session.get("pseudo", ""))

func email() -> String:
	return str(session.get("email", ""))

func user_id() -> String:
	return str(session.get("user_id", ""))

func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		url = str(d.get("url", "")).rstrip("/")
		key = str(d.get("publishable_key", ""))

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if d is Dictionary and str(d.get("refresh_token", "")) != "":
		session = d

func _save_session() -> void:
	if session.is_empty():
		if FileAccess.file_exists(SESSION_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
		return
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(session))

func _clear_session() -> void:
	session = {}
	_save_session()
	session_changed.emit()

## Enregistre la session d'une réponse d'authentification (connexion, inscription sans confirmation, rafraîchissement).
func _store_session(d: Dictionary) -> void:
	var u: Dictionary = d.get("user") if d.get("user") is Dictionary else {}
	var meta: Dictionary = u.get("user_metadata") if u.get("user_metadata") is Dictionary else {}
	var now := Time.get_unix_time_from_system()
	var exp_at: float = float(d.get("expires_at")) if d.has("expires_at") else now + float(d.get("expires_in", 3600))
	session = {
		"access_token": str(d.get("access_token", "")),
		"refresh_token": str(d.get("refresh_token", "")),
		"expires_at": exp_at,
		"user_id": str(u.get("id", session.get("user_id", ""))),
		"email": str(u.get("email", session.get("email", ""))),
		"pseudo": str(session.get("pseudo", meta.get("pseudo", ""))),
	}
	_save_session()
	session_changed.emit()

# ------------------------------------------------------------------ requêtes

func _fail(code: String, status: int = 0) -> Dictionary:
	return {"ok": false, "status": status, "data": null, "error_code": code,
		"message": L.t(ERR_KEYS.get(code, ERR_KEYS.generic)), "offline": code == "offline"}

## Code d'erreur « métier » d'une réponse en échec (Supabase Auth : error_code ; PostgREST : message de nos garde-fous SQL).
func _error_code(status: int, d: Variant) -> String:
	if d is Dictionary:
		for k in ["error_code", "message", "msg", "error"]:
			var v := str(d.get(k, ""))
			if ERR_KEYS.has(v):
				return v
	if status == 429:
		return "over_request_rate_limit"
	if status == 401:
		return "session_expired"
	if status == 403:
		return "refused"
	return "generic"

func _http(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if _transport.is_valid():
		return await _transport.call(method, full_url, headers, body)
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	add_child(req)
	if req.request(full_url, headers, method, body) != OK:
		req.queue_free()
		return {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()}
	var r: Array = await req.request_completed
	req.queue_free()
	return {"result": r[0], "code": r[1], "body": r[3]}

## Requête brute : `token` vide = anonyme (clé publique seule). Ne rafraîchit rien.
func _raw(method: int, path: String, body: Variant, token: String, extra: PackedStringArray = PackedStringArray()) -> Dictionary:
	if not is_configured():
		return _fail("not_configured")
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json", "Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	headers.append_array(extra)
	var payload := "" if body == null else JSON.stringify(body)
	var r: Dictionary = await _http(method, url + path, headers, payload)
	if int(r.get("result", -1)) != HTTPRequest.RESULT_SUCCESS:
		return _fail("offline")
	var status := int(r.get("code", 0))
	var text: String = (r.get("body", PackedByteArray()) as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text.strip_edges() != "" else null
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "data": data, "error_code": "", "message": "", "offline": false}
	var code := _error_code(status, data)
	var res := _fail(code, status)
	res["data"] = data
	return res

## Requête de l'API (PostgREST, RPC…) ; `auth` : avec la session du joueur (jeton rafraîchi si besoin).
## Exemple : `await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/dungeons?select=*&order=created_at.desc&limit=20")`.
func request(method: int, path: String, body: Variant = null, auth: bool = false, extra: PackedStringArray = PackedStringArray()) -> Dictionary:
	var token := ""
	if auth:
		token = await _valid_token()
		if token == "":
			return _fail("session_expired", 401)
	return await _raw(method, path, body, token, extra)

func _valid_token() -> String:
	if not is_signed_in():
		return ""
	if float(session.get("expires_at", 0.0)) - Time.get_unix_time_from_system() > REFRESH_MARGIN:
		return str(session.get("access_token", ""))
	var r: Dictionary = await refresh()
	return str(session.get("access_token", "")) if r.ok else ""

# ------------------------------------------------------------------ compte

## Le pseudo est-il valide et libre ? (vérifié avant l'inscription)
func pseudo_available(p: String) -> Dictionary:
	var r: Dictionary = await _raw(HTTPClient.METHOD_POST, "/rest/v1/rpc/pseudo_disponible", {"p": p}, "")
	if r.ok and r.data == false:
		return _fail("pseudo_pris")
	return r

## Inscription. Sans confirmation d'email côté Supabase : le joueur est connecté d'emblée ; avec confirmation : `needs_confirmation`.
func sign_up(mail: String, password: String, pseudo_wanted: String) -> Dictionary:
	if not RegEx.create_from_string("^[A-Za-z0-9_-]{3,20}$").search(pseudo_wanted):
		return _fail("pseudo_invalide")
	var ok_pseudo: Dictionary = await pseudo_available(pseudo_wanted)
	if not ok_pseudo.ok:
		return ok_pseudo
	var r: Dictionary = await _raw(HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": mail.strip_edges(), "password": password, "data": {"pseudo": pseudo_wanted}}, "")
	if not r.ok:
		return r
	if r.data is Dictionary and str((r.data as Dictionary).get("access_token", "")) != "":
		session = {"pseudo": pseudo_wanted}
		_store_session(r.data)
		r["needs_confirmation"] = false
	else:
		r["needs_confirmation"] = true
	return r

func sign_in(mail: String, password: String) -> Dictionary:
	var r: Dictionary = await _raw(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": mail.strip_edges(), "password": password}, "")
	if r.ok and r.data is Dictionary:
		session = {}
		_store_session(r.data)
		await load_profile()
	return r

## Relit le pseudo du profil (il peut avoir été changé depuis l'inscription).
func load_profile() -> Dictionary:
	var r: Dictionary = await request(HTTPClient.METHOD_GET, "/rest/v1/profiles?id=eq.%s&select=pseudo" % user_id(), null, true)
	if r.ok and r.data is Array and (r.data as Array).size() > 0:
		session["pseudo"] = str((r.data as Array)[0].get("pseudo", pseudo()))
		_save_session()
		session_changed.emit()
	return r

## Renouvelle le jeton. Hors ligne : la session est conservée ; jeton refusé : la session est effacée.
func refresh() -> Dictionary:
	if not is_signed_in():
		return _fail("session_expired", 401)
	if _refreshing:
		await _refresh_finished      # un autre appel renouvelle déjà le jeton : on attend son résultat
		if not is_signed_in():
			return _fail("session_expired", 401)
		return {"ok": true, "status": 200, "data": null, "error_code": "", "message": "", "offline": false}
	_refreshing = true
	var r: Dictionary = await _raw(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": str(session.get("refresh_token", ""))}, "")
	if r.ok and r.data is Dictionary:
		_store_session(r.data)
	elif not r.offline and int(r.status) >= 400 and int(r.status) < 500:
		_clear_session()
	_refreshing = false
	_refresh_finished.emit()
	return r

## Au lancement du mode en ligne : vérifie que la session mémorisée est encore valable (sans bloquer le jeu hors ligne).
func restore_session() -> Dictionary:
	if not is_signed_in():
		return _fail("session_expired", 401)
	return await refresh()

func sign_out() -> void:
	if is_signed_in():
		await _raw(HTTPClient.METHOD_POST, "/auth/v1/logout", null, str(session.get("access_token", "")))
	_clear_session()

func reset_password(mail: String) -> Dictionary:
	return await _raw(HTTPClient.METHOD_POST, "/auth/v1/recover", {"email": mail.strip_edges()}, "")

## Suppression définitive du compte et de ses données en ligne (donjons, parties). Les sauvegardes locales ne sont pas touchées.
func delete_account() -> Dictionary:
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/rest/v1/rpc/supprimer_mon_compte", {}, true)
	if r.ok:
		_clear_session()
	return r
