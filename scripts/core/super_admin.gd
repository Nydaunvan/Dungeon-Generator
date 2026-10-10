class_name SuperAdmin
extends RefCounted
## Rôle « super admin » de la partie en ligne : parties classées de TEST et statistiques de toute la partie en ligne.
##
## SÉCURITÉ : ce fichier ne décide de rien. Le rôle est une ligne de la table `admins` du serveur (illisible depuis le jeu, inscriptible
## seulement depuis le tableau de bord Supabase) et CHAQUE fonction appelée ici revérifie le rôle côté serveur (`acces_refuse` sinon).
## `check()` ne sert qu'à décider si le bouton s'affiche. Les courriels et les journaux d'actions ne sont jamais renvoyés.

static var _known: Dictionary = {}      ## identifiant du compte -> bool (réponse du serveur)

## Réponse déjà connue pour le compte connecté : 1 = super admin, 0 = non, -1 = pas encore demandé (ou hors ligne).
static func cached() -> int:
	if not Cloud.is_signed_in() or not _known.has(Cloud.user_id()):
		return -1
	return 1 if _known[Cloud.user_id()] else 0

## Demande au serveur si le compte connecté est super admin. Hors ligne ou sans compte : false, sans rien mémoriser.
static func check() -> bool:
	if not Cloud.is_signed_in():
		return false
	var id := Cloud.user_id()
	if _known.has(id):
		return _known[id]
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/is_super_admin", {}, true)
	if not r.ok:
		return false
	var yes: bool = r.data == true
	_known[id] = yes
	return yes

static func forget() -> void:
	_known.clear()

## Partie classée de TEST : n'utilise pas l'essai du jour, hors classements, sans expérience ni badge ; rejouée comme les autres.
## `kind` : "difficulty" ou "hardcore_month" (réglages du mois, graine tirée au hasard : la vraie graine du mois n'est jamais donnée).
static func launch_test(difficulty: String, kind: String = "difficulty") -> Dictionary:
	return await RankedRun.launch(difficulty, kind, true)

static func overview() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/admin_overview", {}, true)

static func players(search: String = "", limit: int = 50, offset: int = 0) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/admin_players", {"p_search": search, "p_limit": limit, "p_offset": offset}, true)

## `status` : "" (tous) ou started / submitted / verified / rejected / expired ; `tests` : "all", "only" ou "none".
static func runs(status: String = "", tests: String = "all", limit: int = 50, offset: int = 0) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/admin_runs",
		{"p_status": status if status != "" else null, "p_tests": tests, "p_limit": limit, "p_offset": offset}, true)

## Supprime toutes les parties de test ; renvoie leur nombre dans `data`.
static func purge_tests() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/admin_purge_tests", {}, true)

# ------------------------------------------------------------------ modération du tchat (chaque fonction revérifie le rôle côté serveur)

static func _rpc(name: String, body: Dictionary = {}) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + name, body, true)

static func chat_stats() -> Dictionary:
	return await _rpc("admin_chat_stats")

## Messages signalés non traités (ou tous avec `handled`), le plus récemment signalé d'abord.
static func chat_reports(handled: bool = false, limit: int = 50) -> Dictionary:
	return await _rpc("admin_chat_reports", {"p_include_handled": handled, "p_limit": limit})

static func chat_delete(message_id: int) -> Dictionary:
	return await _rpc("admin_chat_delete", {"p_message_id": message_id})

static func chat_dismiss(message_id: int) -> Dictionary:
	return await _rpc("admin_chat_dismiss", {"p_message_id": message_id})

static func chat_mute(player_id: String, minutes: int, reason: String = "") -> Dictionary:
	return await _rpc("admin_chat_mute", {"p_player": player_id, "p_minutes": minutes, "p_reason": reason})

static func chat_unmute(player_id: String) -> Dictionary:
	return await _rpc("admin_chat_unmute", {"p_player": player_id})

static func chat_words() -> Dictionary:
	return await _rpc("admin_chat_words")

static func chat_word_add(word: String) -> Dictionary:
	return await _rpc("admin_chat_word_add", {"p_word": word})

static func chat_word_remove(word: String) -> Dictionary:
	return await _rpc("admin_chat_word_remove", {"p_word": word})
