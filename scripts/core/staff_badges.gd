class_name StaffBadges
extends RefCounted
## Marque de rôle (développeur, super admin, modérateur) affichée à côté des pseudos. Liste publique {player_id, role} de l'équipe,
## relue au plus toutes les 5 minutes ; aucune autre donnée n'est exposée.

const MARKS := {"dev": "🛠️", "super_admin": "🛡️", "moderator": "⚔️"}
const NAMES := {"dev": "ui.role.dev", "super_admin": "ui.role.super_admin", "moderator": "ui.role.moderator"}

static var _roles: Dictionary = {}
static var _at := -1000000
static var _loading := false

static func refresh(force: bool = false) -> void:
	if _loading or (not force and Time.get_ticks_msec() - _at < 300000):
		return
	_loading = true
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/staff_public", {})
	_loading = false
	_at = Time.get_ticks_msec()
	if r.ok and r.data is Array:
		_roles = {}
		for x in r.data:
			_roles[str(x.get("player_id", ""))] = str(x.get("role", ""))

static func role_of(player_id: String) -> String:
	return str(_roles.get(player_id, ""))

## Icône du rôle, "" pour un joueur ordinaire.
static func mark(player_id: String) -> String:
	return str(MARKS.get(role_of(player_id), ""))

## Nom lisible du rôle ("Développeur"…), "" pour un joueur ordinaire.
static func role_name(role: String) -> String:
	return L.t(str(NAMES[role])) if NAMES.has(role) else ""
