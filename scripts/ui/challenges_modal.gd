class_name ChallengesModal
extends RefCounted
## Point d'entrée historique du mode en ligne avant un donjon aléatoire : ouvre la fenêtre « Mode en ligne » (OnlineHub).
## Hors ligne ou sans compte, le jeu reste jouable : « Retour au menu » et la partie libre restent disponibles.

const DIFF_KEYS := {"easy": "ui.challenges.diff_easy", "normal": "ui.challenges.diff_normal", "hard": "ui.challenges.diff_hard", "hardcore": "ui.challenges.diff_hardcore"}

## `on_launch` : appelé quand le joueur lance une partie libre (la fenêtre est alors fermée).
static func open(host: Node, on_launch: Callable) -> OnlineHub:
	return OnlineHub.open(host, on_launch, "play")
