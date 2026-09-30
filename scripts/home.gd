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
		"saves": SlotsModal.open(_modal_layer, Callable(), Data.launch_save)
		"load-code": _load_code()
		"import-json": _import_json()
		"tutorial": DocModal.tutorial(_modal_layer)
		"changelog": DocModal.changelog(_modal_layer)

func _soon(what: String) -> void:
	Dialogs.notice(_modal_layer, what, "Cette partie est en cours de portage vers Godot.")

func _load_code() -> void:
	Files.paste_dialog(_modal_layer, "Charger un donjon depuis un code",
		"Collez le code reçu : il contient tout le donjon (personnages, classes, sorts, niveaux, objets). Une nouvelle partie démarre avec ce donjon.",
		func(text: String):
			var cfg := Data.decode_code(text)
			if cfg.is_empty() or not cfg.has("levels"):
				Dialogs.notice(_modal_layer, "Code invalide", "Ce code est invalide ou illisible.")
				return
			Data.config = cfg
			Data.save_config()
			Data.launch(cfg, "custom"))

func _import_json() -> void:
	Files.pick_text(self, func(text: String):
		var data := Saves.parse_import(text)
		if data.is_empty():
			Dialogs.notice(_modal_layer, "Import impossible", "Ce fichier ne contient pas de sauvegarde ou de configuration reconnue.")
		elif not data.save.is_empty():
			Data.launch_save(data)
		else:
			Data.config = data.config
			Data.save_config()
			Dialogs.notice(_modal_layer, "Configuration importée", "La configuration a été enregistrée. Elle est modifiable dans l'administration."))
