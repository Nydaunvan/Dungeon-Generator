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
	Updater.cleanup()

func _on_nav(name: String) -> void:
	match name:
		"Guide": Dialogs.guide(_modal_layer)
		"Quitter": Dialogs.confirm(_modal_layer, "", L.t("ui.app_header.quitter_confirm"), func(): get_tree().quit(), L.t("ui.app_header.quitter"))
		"Paramètres": SettingsModal.open(_modal_layer)
		"Admin": Data.open_admin()
		"Lang": get_tree().reload_current_scene()

func _launch_original() -> void:
	Data.launch_original()

func _launch_generated(cfg: Dictionary) -> void:
	Data.launch(cfg, "random")

func _on_action(name: String) -> void:
	match name:
		"origin":
			Dialogs.confirm(_modal_layer, L.t("common.le_donjon_origine"),
				L.t("home.ce_donjon_sert_de_demonstration"),
				_launch_original, "Commencer")
		"random": GeneratorDialog.open(_modal_layer, _launch_generated)
		"create": Data.create_own_dungeon()
		"saves": SlotsModal.open(_modal_layer, Callable(), func(d): Data.launch_save(d))
		"load-code": _load_code()
		"import-json": _import_json()
		"tutorial": DocModal.tutorial(_modal_layer)
		"changelog": DocModal.changelog(_modal_layer)
		"credits": CreditsRoll.open(_modal_layer)

func _soon(what: String) -> void:
	Dialogs.notice(_modal_layer, what, L.t("home.cette_partie_est_en_cours"))

func _load_code() -> void:
	Files.paste_dialog(_modal_layer, L.t("common.charger_un_donjon_depuis_un"),
		L.t("home.collez_le_code_recu_il"),
		func(text: String):
			if text.strip_edges() == "":
				return
			Dialogs.confirm(_modal_layer, "", L.t("home.demarrer_une_nouvelle_partie"), func():
				var cfg := Data.decode_code(text)
				if cfg.is_empty():
					Form.alert(_modal_layer, L.t("common.ce_code_est_invalide_ou"))
					return
				Data.ensure_defaults(cfg)
				Data.config = cfg
				Data.save_config()
				Data.own_dungeon_launched = false
				Data.launch(cfg, "custom", Data.ADMIN_LOCK)))

func _import_json() -> void:
	Files.pick_text(self, func(text: String):
		if not Saves.is_valid_json(text):
			Form.alert(_modal_layer, L.t("common.ce_fichier_n_est_pas"))
			return
		if not Data.launch_import(Saves.parse_import(text)):
			Form.alert(_modal_layer, L.t("common.ce_fichier_ne_contient_pas")))
