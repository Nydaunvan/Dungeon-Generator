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
		"Lang": get_tree().reload_current_scene()

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
		"create": Data.create_own_dungeon()
		"saves": SlotsModal.open(_modal_layer, Callable(), func(d): Data.launch_save(d))
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
			if text.strip_edges() == "":
				return
			Dialogs.confirm(_modal_layer, "", "Démarrer une nouvelle partie avec ce donjon ? Toute progression non sauvegardée sera perdue.", func():
				var cfg := Data.decode_code(text)
				if cfg.is_empty():
					Form.alert(_modal_layer, "Ce code est invalide ou illisible.")
					return
				Data.ensure_defaults(cfg)
				Data.config = cfg
				Data.save_config()
				Data.own_dungeon_launched = false
				Data.launch(cfg, "custom", Data.ADMIN_LOCK)))

func _import_json() -> void:
	Files.pick_text(self, func(text: String):
		if not Saves.is_valid_json(text):
			Form.alert(_modal_layer, "Ce fichier n'est pas un JSON de sauvegarde valide.")
			return
		if not Data.launch_import(Saves.parse_import(text)):
			Form.alert(_modal_layer, "Ce fichier ne contient pas de sauvegarde ou de configuration reconnue."))
