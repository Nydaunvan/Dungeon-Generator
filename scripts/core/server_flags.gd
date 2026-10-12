class_name ServerFlags
extends RefCounted
## Réglages à distance du développeur (table `feature_flags`, lecture publique) : publication en galerie, signalements, seuil d'alerte
## de l'équipe. Le SERVEUR applique les règles ; ici on ne s'en sert que pour prévenir le joueur avant qu'il tente. Hors ligne, ou serveur
## sans la mise à jour : aucun réglage connu, tout est considéré comme ouvert.

static var flags: Dictionary = {}
static var _at := -1000000

static func refresh(force: bool = false) -> void:
	if not force and Time.get_ticks_msec() - _at < 60000:
		return
	_at = Time.get_ticks_msec()
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/flags_get", {})
	flags = r.data if r.ok and r.data is Dictionary else {}

static func is_on(key: String, default: bool = true) -> bool:
	var v: Variant = flags.get(key, default)
	return bool(v) if v is bool else default

static func number(key: String, default: int) -> int:
	var v: Variant = flags.get(key, default)
	return int(v) if v is float or v is int else default
