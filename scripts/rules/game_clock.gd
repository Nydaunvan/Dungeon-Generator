class_name GameClock
extends RefCounted
## Horloge DU JEU (millisecondes de jeu écoulées), seule référence de temps de la logique : recharge des sorts, fontaines.
## Elle n'avance que lorsque le monde tourne (`frozen` > 0 pendant une boutique) et ne dépend jamais de l'horloge de la machine :
## en rejeu vérifié, le vérificateur la règle sur la valeur enregistrée avec chaque commande (`set_ms`).
## Elle est sauvegardée avec la partie (voir GameState.to_save).

static var ms: int = 0
static var frozen: int = 0            ## > 0 : le temps de jeu est figé (boutique ouverte…)
static var manual: bool = false       ## rejeu : l'horloge ne bouge que par `set_ms` (valeur enregistrée avec chaque commande)
static var _frac: float = 0.0

static func reset(value: int = 0) -> void:
	ms = maxi(value, 0)
	frozen = 0         # (manual n'est pas touché : c'est le rejeu qui le règle)
	_frac = 0.0

## Fait avancer l'horloge d'une image (au plus une seconde d'un coup : une pause du système ne compte pas).
static func advance(delta: float) -> void:
	if frozen > 0 or manual:
		return
	_frac += minf(delta, 1.0) * 1000.0
	var whole := int(_frac)
	ms += whole
	_frac -= whole

## Règle l'horloge (rejeu). Ne recule jamais.
static func set_ms(value: int) -> void:
	if manual or value > ms:
		ms = value
		_frac = 0.0

static func seconds() -> float:
	return ms / 1000.0
