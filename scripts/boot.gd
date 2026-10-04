extends Node
## Scène de démarrage : charge tout le jeu derrière l'écran de chargement, puis ouvre l'accueil.

func _ready() -> void:
	RenderingServer.set_default_clear_color(UiTheme.BG)
	await Loader.boot()
	await Loader.finish_boot()
