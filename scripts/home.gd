extends Control
## Scène d'accueil : choix du mode de jeu.

var screen: HomeScreen
var _modal_layer: CanvasLayer

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = HomeScreen.new()
	add_child(screen)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)
	screen.action.connect(_on_action)
	screen.nav.connect(_on_nav)

func _on_nav(name: String) -> void:
	match name:
		"Guide": Dialogs.guide(_modal_layer)
		"Admin": Data.open_admin()

func _launch_original() -> void:
	Data.launch_original()

func _launch_generated(cfg: Dictionary) -> void:
	Data.launch(cfg, "random")

func _on_action(name: String) -> void:
	match name:
		"origin":
			Dialogs.confirm(_modal_layer, "Le Donjon d'Origine",
				"Ce donjon sert de démonstration : un parcours fixe en 3 niveaux pensé pour découvrir les mécaniques principales du jeu (combats, portes verrouillées, fontaine, objets, montée de niveau…).\n\nPour explorer tout ce que le jeu propose, lancez plutôt un donjon aléatoire depuis l'accueil.\n\nCommencer cette démonstration ?",
				_launch_original, "Commencer")
		"random": GeneratorDialog.open(_modal_layer, _launch_generated)
		"create": Dialogs.confirm(_modal_layer, "Créer votre propre donjon", "Un nouveau donjon de départ va être généré et remplacera la configuration actuelle de l'administration. Continuer ?", Data.create_own_dungeon, "Créer")
		"saves": _soon("Sauvegardes")
		"load-code": _soon("Chargement par code")
		"import-json": _soon("Import JSON")
		"tutorial": _soon("Tutoriel")
		"changelog": _soon("Journal des versions")

func _soon(what: String) -> void:
	Dialogs.notice(_modal_layer, what, "Cette partie est en cours de portage vers Godot.")
