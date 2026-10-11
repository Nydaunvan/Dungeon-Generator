class_name ChatPrefs
extends RefCounted
## Réglages du tchat du joueur (par compte, gardés sur l'appareil) : canaux ajoutés et notifications coupées.
## Canaux OBLIGATOIRES : « Général » et le salon de la langue du jeu. Le joueur peut en ajouter d'autres (salon de l'autre langue,
## conversations privées) : 5 canaux ouverts en même temps au maximum.

const PATH := "user://chat_prefs.json"
const MAX_CHANNELS := 5

static var _loaded_for := "<none>"
static var _optional: Array = []         ## canaux ajoutés (hors obligatoires), dans l'ordre d'ajout
static var _muted: Dictionary = {}       ## canal → true : pas de bulle rouge pour ce canal
static var _names: Dictionary = {}       ## « dm:<id> » → pseudo du correspondant
static var _last := ""                   ## dernier canal affiché

static func mandatory() -> Array:
	return ["general", "en" if Data.lang == "en" else "fr"]

static func _load() -> void:
	var uid := Cloud.user_id() if Cloud.is_signed_in() else ""
	if uid == _loaded_for:
		return
	_loaded_for = uid
	_optional = []
	_muted = {}
	_names = {}
	_last = ""
	if uid == "" or not FileAccess.file_exists(PATH):
		return
	var all = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (all is Dictionary) or not (all.get(uid) is Dictionary):
		return
	var d: Dictionary = all[uid]
	_optional = d.get("optional", []) if d.get("optional") is Array else []
	_muted = d.get("muted", {}) if d.get("muted") is Dictionary else {}
	_names = d.get("names", {}) if d.get("names") is Dictionary else {}
	_last = str(d.get("last", ""))

static func _save() -> void:
	var uid := Cloud.user_id() if Cloud.is_signed_in() else ""
	if uid == "":
		return
	var all = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else {}
	if not (all is Dictionary):
		all = {}
	all[uid] = {"optional": _optional, "muted": _muted, "names": _names, "last": _last}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(all))

## Canaux ouverts : obligatoires d'abord, puis ceux ajoutés (le salon de langue obligatoire n'est jamais en double).
static func active() -> Array:
	_load()
	var out: Array = mandatory()
	for r in _optional:
		if not out.has(r):
			out.append(r)
	return out.slice(0, MAX_CHANNELS)

static func is_mandatory(room: String) -> bool:
	return mandatory().has(room)

static func is_active(room: String) -> bool:
	return active().has(room)

static func can_add() -> bool:
	return active().size() < MAX_CHANNELS

## Ajoute un canal ; renvoie false s'il y en a déjà 5.
static func add(room: String, name: String = "") -> bool:
	_load()
	if is_active(room):
		return true
	if not can_add():
		return false
	_optional.append(room)
	if name != "":
		_names[room] = name
	_save()
	return true

static func remove(room: String) -> void:
	_load()
	if is_mandatory(room):
		return
	_optional.erase(room)
	_save()

static func name_of(room: String) -> String:
	_load()
	if Chat.is_dm(room):
		return str(_names.get(room, "?"))
	return Chat.room_name(room)

static func remember_name(room: String, name: String) -> void:
	_load()
	if name != "" and str(_names.get(room, "")) != name:
		_names[room] = name
		_save()

static func is_muted(room: String) -> bool:
	_load()
	return bool(_muted.get(room, false))

static func set_muted(room: String, on: bool) -> void:
	_load()
	if on:
		_muted[room] = true
	else:
		_muted.erase(room)
	_save()

static func last() -> String:
	_load()
	return _last if is_active(_last) else str(active()[0])

static func set_last(room: String) -> void:
	_load()
	if _last != room:
		_last = room
		_save()

## Conversations privées dont les notifications sont coupées.
static func muted_dms() -> Array:
	_load()
	var out: Array = []
	for k in _muted:
		if Chat.is_dm(str(k)):
			out.append(str(k))
	return out

## À la déconnexion / changement de compte : recharge les réglages du compte courant au prochain accès.
static func reset() -> void:
	_loaded_for = "<none>"
