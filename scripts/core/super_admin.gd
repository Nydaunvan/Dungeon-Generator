class_name SuperAdmin
extends RefCounted
## Équipe d'administration de la partie en ligne : modérateur < super admin < développeur.
##
## SÉCURITÉ : ce fichier ne décide de rien. Le rôle est une ligne de la table `staff_roles` du serveur (illisible depuis le jeu ; le rôle
## de développeur ne se change que par SQL) et CHAQUE fonction appelée ici revérifie le rôle côté serveur (`acces_refuse` sinon).
## `check()` / `rank()` ne servent qu'à décider quoi AFFICHER. Les courriels ne sont jamais renvoyés.

const RANKS := {"moderator": 1, "super_admin": 2, "dev": 3}

static var _known: Dictionary = {}      ## identifiant du compte -> rôle du serveur ("" = aucun, "moderator", "super_admin" ou "dev")

## Réponse déjà connue pour le compte connecté : 1 = membre de l'équipe (tous rôles), 0 = non, -1 = pas encore demandé (ou hors ligne).
static func cached() -> int:
	if not Cloud.is_signed_in() or not _known.has(Cloud.user_id()):
		return -1
	return 1 if str(_known[Cloud.user_id()]) != "" else 0

## Rôle connu du compte connecté : "", "moderator", "super_admin" ou "dev".
static func role() -> String:
	if not Cloud.is_signed_in():
		return ""
	return str(_known.get(Cloud.user_id(), ""))

## Rang connu : 0 aucun, 1 modérateur, 2 super admin, 3 développeur.
static func rank() -> int:
	return int(RANKS.get(role(), 0))

static func is_dev() -> bool:
	return rank() >= 3

static func is_super() -> bool:
	return rank() >= 2

## Demande au serveur le rôle du compte connecté. Hors ligne ou sans compte : "", sans rien mémoriser.
## Un serveur qui n'a pas encore reçu la mise à jour des rôles répond à l'ancienne question « super admin ? ».
static func fetch_role() -> String:
	if not Cloud.is_signed_in():
		return ""
	var id := Cloud.user_id()
	if _known.has(id):
		return str(_known[id])
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/staff_role", {}, true)
	var found := ""
	if r.ok:
		found = str(r.data) if r.data is String and RANKS.has(str(r.data)) else ""
	else:
		var old: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/is_super_admin", {}, true)
		if not old.ok:
			return ""
		found = "super_admin" if old.data is bool and old.data else ""
	_known[id] = found
	return found

## Le compte connecté fait-il partie de l'équipe ? (sert à afficher le bouton ; le serveur revérifie chaque action)
static func check() -> bool:
	return (await fetch_role()) != ""

static func forget() -> void:
	_known.clear()
	_pending = {"chat": 0, "gallery": 0, "at": -1000000}

# ------------------------------------------------------------------ « à regarder » : signalements en attente (pastille sur Compte)

static var _pending := {"chat": 0, "gallery": 0, "at": -1000000}

## Nombre de choses à traiter connu (messages de tchat signalés + donjons signalés), 0 si le compte n'est pas super admin.
static func pending() -> int:
	return int(_pending.chat) + int(_pending.gallery) if cached() == 1 else 0

static func pending_chat() -> int:
	return int(_pending.chat) if cached() == 1 else 0

static func pending_gallery() -> int:
	return int(_pending.gallery) if cached() == 1 else 0

## Relit les compteurs auprès du serveur (au plus une fois toutes les 30 s). Sans effet pour un compte qui n'est pas super admin.
static func refresh_pending() -> void:
	if not Cloud.is_signed_in() or Time.get_ticks_msec() - int(_pending.at) < 30000:
		return
	_pending["at"] = Time.get_ticks_msec()
	if not await check():
		return
	var c: Dictionary = await chat_stats()
	var g: Dictionary = await gallery_stats()
	_pending["chat"] = int((c.data as Dictionary).get("reports_pending", 0)) if c.ok and c.data is Dictionary else 0
	_pending["gallery"] = int((g.data as Dictionary).get("reports_pending", 0)) if g.ok and g.data is Dictionary else 0

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

# ------------------------------------------------------------------ galerie de donjons

static func gallery_stats() -> Dictionary:
	return await _rpc("admin_gallery_stats")

## Donjons signalés non traités (ou tous avec `handled`), le plus récemment signalé d'abord.
static func gallery_reports(handled: bool = false, limit: int = 50) -> Dictionary:
	return await _rpc("admin_gallery_reports", {"p_include_handled": handled, "p_limit": limit})

static func gallery_unpublish(dungeon_id: String) -> Dictionary:
	return await _rpc("admin_gallery_unpublish", {"p_dungeon": dungeon_id})

static func gallery_delete(dungeon_id: String) -> Dictionary:
	return await _rpc("admin_gallery_delete", {"p_dungeon": dungeon_id})

static func gallery_dismiss(dungeon_id: String) -> Dictionary:
	return await _rpc("admin_gallery_dismiss", {"p_dungeon": dungeon_id})

static func gallery_ban(player_id: String, reason: String = "") -> Dictionary:
	return await _rpc("admin_gallery_ban", {"p_player": player_id, "p_reason": reason})

static func gallery_unban(player_id: String) -> Dictionary:
	return await _rpc("admin_gallery_unban", {"p_player": player_id})

static func gallery_bans() -> Dictionary:
	return await _rpc("admin_gallery_bans")

# ------------------------------------------------------------------ équipe, fiches joueurs, journal

## Membres de l'équipe : [{player_id, pseudo, role, rank, granted_at, granted_by, granted_by_pseudo}].
static func team() -> Dictionary:
	return await _rpc("staff_list")

## `role` : "moderator", "super_admin" ou "none" (retire).
static func set_role(player_id: String, new_role: String) -> Dictionary:
	return await _rpc("staff_set_role", {"p_player": player_id, "p_role": new_role})

static func player_card(player_id: String) -> Dictionary:
	return await _rpc("admin_player_card", {"p_player": player_id})

## Journal des actions. Un modérateur ne reçoit que les siennes (le serveur impose le filtre).
static func log_list(action: String = "", since_iso: String = "", limit: int = 100, offset: int = 0) -> Dictionary:
	return await _rpc("staff_log_list", {"p_actor": null, "p_action": action if action != "" else null,
		"p_since": since_iso if since_iso != "" else null, "p_limit": limit, "p_offset": offset})

# ------------------------------------------------------------------ outils du développeur

## `hours` <= 0 : définitif.
static func account_ban(player_id: String, hours: int, reason: String = "") -> Dictionary:
	return await _rpc("admin_account_ban", {"p_player": player_id, "p_hours": hours if hours > 0 else null, "p_reason": reason})

static func account_unban(player_id: String) -> Dictionary:
	return await _rpc("admin_account_unban", {"p_player": player_id})

static func account_bans() -> Dictionary:
	return await _rpc("admin_account_bans")

static func announce(body: String, hours: int) -> Dictionary:
	return await _rpc("admin_announce", {"p_body": body, "p_hours": hours})

static func announce_clear() -> Dictionary:
	return await _rpc("admin_announce_clear")

static func set_server_state(ranked_closed: bool, chat_closed: bool, message: String) -> Dictionary:
	return await _rpc("admin_set_server_state", {"p_ranked_closed": ranked_closed, "p_chat_closed": chat_closed, "p_message": message})

static func boards() -> Dictionary:
	return await _rpc("admin_boards")

static func reset_board(kind: String, period: String, difficulty: String, confirm: String) -> Dictionary:
	return await _rpc("admin_reset_board", {"p_kind": kind, "p_period": period if period != "" else null,
		"p_difficulty": difficulty if difficulty != "" else null, "p_confirm": confirm})

static func cancel_run(run_id: String, reason: String = "") -> Dictionary:
	return await _rpc("admin_cancel_run", {"p_run": run_id, "p_reason": reason})

static func health() -> Dictionary:
	return await _rpc("admin_health")

# ------------------------------------------------------------------ revoir les parties (développeur)

## Les 30 dernières parties d'un joueur (sans le journal).
static func player_runs(player_id: String) -> Dictionary:
	return await _rpc("admin_player_runs", {"p_player": player_id, "p_limit": 30})

## Une partie complète : graine, réglages, version, résultat et journal d'actions. La consultation est écrite dans le journal de l'équipe.
static func run_log(run_id: String) -> Dictionary:
	return await _rpc("admin_run_log", {"p_run": run_id})
