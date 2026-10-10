class_name RunLog
extends RefCounted
## Journal des actions d'une partie CLASSÉE (graine fournie par le serveur). Chaque entrée : [temps de jeu en ms, commande, arguments…].
## Le vérificateur rejoue la partie avec le vrai jeu (sans affichage) en injectant ces commandes au bon moment : le score est alors
## recalculé par les règles, jamais cru sur parole.
##
## Règle d'or : toute action du joueur qui change la partie doit être journalisée à l'endroit où la logique l'ACCEPTE (pas quand le
## joueur clique). Tant qu'une action n'est pas journalisée, elle appelle `unrecorded()` : la partie devient « non classable ».
##
## Le journal vit dans `gs.run_log` (sauvegardé avec la partie) ; `gs.run_taint` garde la première raison de non-classement.

const VERSION := 1
const MAX_ENTRIES := 60000

static var gs: GameState = null              ## partie en cours (renseignée par GameState)
static var trace: Array = []                 ## (mise au point) trace des pas de monstres
static var replaying: bool = false           ## vrai pendant un rejeu : on n'écrit plus rien

static func attach(state: GameState) -> void:
	gs = state

## Une partie est « classée » quand le serveur a fourni sa graine.
static func ranked() -> bool:
	return gs != null and gs.run_seed != ""

## Ajoute une commande au journal.
static func rec(cmd: String, a: Variant = null, b: Variant = null) -> void:
	if replaying or not ranked():
		return
	if gs.run_log.size() >= MAX_ENTRIES:
		taint("journal_trop_long")
		return
	var e: Array = [GameClock.ms, cmd]
	if a != null:
		e.append(a)
		if b != null:
			e.append(b)
	gs.run_log.append(e)

## Action pas encore journalisée : la partie ne peut plus être classée (la première raison est conservée).
static var _depth: int = 0                  ## > 0 : on est dans une action journalisée (façade Actions)

static func enter() -> void:
	_depth += 1

static func leave() -> void:
	_depth = maxi(0, _depth - 1)

static func unrecorded(reason: String) -> void:
	if _depth == 0:
		taint(reason)

static func taint(reason: String) -> void:
	if replaying or not ranked():
		return
	if gs.run_taint == "":
		gs.run_taint = reason

static func is_clean() -> bool:
	return ranked() and gs.run_taint == ""
