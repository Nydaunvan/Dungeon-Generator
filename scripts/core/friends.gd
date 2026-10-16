class_name Friends
extends RefCounted
## Liste d'amis des joueurs connectés : demandes d'ami (envoyer, accepter, refuser, annuler), retrait, état en ligne des amis.
##
## SÉCURITÉ : toutes les règles (limites, blocages, demandes fermées, qui voit l'état en ligne) sont appliquées par le serveur
## (supabase/migrations/20261013000400_amis.sql) ; ce fichier ne fait qu'appeler ses fonctions. Aucune donnée locale : rien à migrer.
## Chaque appel renvoie le dictionnaire de `Cloud.request` ({ok, data, message, offline…}).

const MAX_FRIENDS := 100

## {requests_open, friends: [{player_id, pseudo, level, online, last_login, since}], incoming: [{player_id, pseudo, level, at}],
##  outgoing: [{player_id, pseudo, level, at}]}
static func list() -> Dictionary:
	return await _rpc("friend_list")

## Nombre de demandes reçues en attente (pastille de l'onglet Amis).
static func pending_count() -> Dictionary:
	return await _rpc("friend_pending_count")

## Demande d'ami. `data` vaut « sent » (envoyée) ou « accepted » (l'autre avait déjà demandé : vous êtes amis).
static func request(player_id: String) -> Dictionary:
	return await _rpc("friend_request", {"p_player": player_id})

static func request_pseudo(pseudo: String) -> Dictionary:
	return await _rpc("friend_request_pseudo", {"p_pseudo": pseudo.strip_edges()})

static func accept(player_id: String) -> Dictionary:
	return await _rpc("friend_accept", {"p_player": player_id})

static func decline(player_id: String) -> Dictionary:
	return await _rpc("friend_decline", {"p_player": player_id})

static func cancel(player_id: String) -> Dictionary:
	return await _rpc("friend_cancel", {"p_player": player_id})

static func remove(player_id: String) -> Dictionary:
	return await _rpc("friend_remove", {"p_player": player_id})

## Accepter (true) ou non (false) les demandes d'ami.
static func set_open(open: bool) -> Dictionary:
	return await _rpc("friend_set_open", {"p_open": open})

static func _rpc(name: String, body: Dictionary = {}) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + name, body, true)
