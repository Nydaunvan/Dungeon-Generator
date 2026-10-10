extends Node
## Notifications du tchat (« bulle rouge ») : nombre de messages privés non lus et de nouveaux messages dans les salons depuis la dernière visite.
## Le serveur tient le compte (fonction chat_unread) ; le jeu l'interroge toutes les 30 s tant qu'une bulle est affichée, et tout de suite après
## une lecture. Rien n'est interrogé sans compte connecté.

signal changed

const EVERY := 30.0

var total := 0
var dm := 0
var rooms: Dictionary = {}
var _left := 3.0
var _busy := false
var _watchers := 0

func _ready() -> void:
	Cloud.session_changed.connect(_on_session)

## Une bulle est affichée (+1) ou disparaît (−1) : l'interrogation régulière ne tourne que si au moins une bulle est visible.
func watch(on: bool) -> void:
	_watchers = maxi(0, _watchers + (1 if on else -1))

func _on_session() -> void:
	total = 0
	dm = 0
	rooms = {}
	_left = 3.0
	if Cloud.is_signed_in() and not Cloud._transport.is_valid():
		Unlocks.refresh()          # règles et apparences débloquées du compte (copie gardée pour jouer hors ligne)
	changed.emit()

func _process(delta: float) -> void:
	if _watchers <= 0 or _busy or not Cloud.is_signed_in() or Cloud._transport.is_valid():
		return
	_left -= delta
	if _left <= 0.0:
		_left = EVERY
		refresh()

## Interroge le serveur maintenant.
func refresh() -> void:
	if _busy or not Cloud.is_signed_in():
		return
	_busy = true
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/chat_unread", {}, true)
	_busy = false
	if r.ok and r.data is Dictionary:
		apply(r.data)

func apply(d: Dictionary) -> void:
	var nt := int(d.get("total", 0))
	var nd := int(d.get("dm", 0))
	var nr: Dictionary = d.get("rooms", {}) if d.get("rooms") is Dictionary else {}
	if nt != total or nd != dm or nr != rooms:
		total = nt
		dm = nd
		rooms = nr
		changed.emit()

## Messages non lus d'un salon.
func unread_room(room: String) -> int:
	return int(rooms.get(room, 0))
