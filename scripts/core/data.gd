extends Node
## Chargement des données du jeu (extraites du build HTML Donjon3D).
## Accessible partout via l'autoload `Data`.

var config: Dictionary = {}
var class_talents: Dictionary = {}
var constants: Dictionary = {}
## Configuration de la partie en cours (donjon d'origine, aléatoire, personnalisé…). Vide = donjon d'origine.
var play_config: Dictionary = {}
## Provenance de la partie : "original", "random", "custom".
var play_origin: String = "original"

## Configuration d'origine (jamais modifiée) : sert au Donjon d'Origine et à la réinitialisation.
var original_config: Dictionary = {}
## Une session d'administration est déverrouillée (mot de passe saisi).
var admin_unlocked: bool = false

const USER_CONFIG := "user://config.json"
const USER_PREFS := "user://prefs.cfg"

## Langue de l'interface (« fr » / « en »), mémorisée sur l'appareil.
var lang: String = "fr"

func set_lang(l: String) -> void:
	lang = l
	_apply_locale()
	var cf := ConfigFile.new()
	cf.load(USER_PREFS)
	cf.set_value("ui", "lang", l)
	cf.save(USER_PREFS)
	lang_changed.emit(l)

signal lang_changed(l: String)

func _apply_locale() -> void:
	if TranslationServer.get_translation_object("en") == null or not (TranslationServer.get_translation_object("en") is EnTranslation):
		var tr_en := EnTranslation.new()
		tr_en.load_dictionary("res://data/i18n_en.json")
		TranslationServer.add_translation(tr_en)
	TranslationServer.set_locale("en" if lang == "en" else "fr")

func _ready() -> void:
	add_child(FloatingTip.new())
	var cf := ConfigFile.new()
	if cf.load(USER_PREFS) == OK:
		lang = str(cf.get_value("ui", "lang", "fr"))
	_apply_locale()
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	original_config = _load_json("res://data/default_config.json")
	config = _load_user_config()
	if config.is_empty():
		config = original_config.duplicate(true)
	class_talents = _load_json("res://data/class_talents.json")
	constants = _load_json("res://data/game_constants.json")

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Fichier introuvable : " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func class_by_id(id: String) -> Dictionary:
	for c in config.get("classes", []):
		if c.get("id") == id:
			return c
	return {}

func spell_by_id(id: String) -> Dictionary:
	for s in config.get("spells", []):
		if s.get("id") == id:
			return s
	return {}

## Configuration éditée par l'administration. Comme le `CONFIG` unique de l'original : si une partie est suspendue
## (admin ouvert depuis le jeu), c'est la configuration de CETTE partie (même Dictionary que `gs.cfg`), sinon la configuration
## par défaut de l'appareil. Tous les onglets admin doivent passer par ici, jamais par `Data.config` directement.
func admin_config() -> Dictionary:
	if not resume_game.is_empty() and (resume_game.get("config") is Dictionary):
		return resume_game.config
	return config

## Configuration utilisée par le jeu.
func active() -> Dictionary:
	return play_config if not play_config.is_empty() else config

## Lance une partie avec la configuration donnée (copie profonde) puis ouvre la scène de jeu.
func launch(cfg: Dictionary, origin: String) -> void:
	if origin != "custom":
		admin_unlocked = false
	resume_game = {}
	play_config = cfg.duplicate(true)
	play_origin = origin
	get_tree().change_scene_to_file("res://scenes/main.tscn")

## Partie à restaurer au prochain lancement de la scène de jeu (vide = nouvelle partie).
var pending_save: Dictionary = {}

## Reprend une sauvegarde : {"config", "save", "origin"}. Sans configuration, garde celle de l'administration.
func launch_save(data: Dictionary) -> void:
	var cfg: Dictionary = data.get("config", {})
	if cfg.is_empty() or not cfg.has("levels"):
		cfg = active().duplicate(true)
	launch(cfg, str(data.get("origin", "custom")))
	pending_save = (data.save as Dictionary).duplicate(true)

func launch_original() -> void:
	launch(original_config, "original")

# ------------------------------------------------------------------ configuration modifiable (administration)

func _load_user_config() -> Dictionary:
	if not FileAccess.file_exists(USER_CONFIG):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_CONFIG))
	if parsed is Dictionary and (parsed as Dictionary).has("levels") and (parsed as Dictionary).has("classes"):
		return parsed
	return {}

## Enregistre la configuration courante comme configuration par défaut de l'appareil.
func save_config() -> bool:
	var f := FileAccess.open(USER_CONFIG, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(admin_config()))
	return true

func reset_config() -> void:
	config = original_config.duplicate(true)
	if FileAccess.file_exists(USER_CONFIG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_CONFIG))

func export_json() -> String:
	return JSON.stringify(config, "\t")

## Remplace la configuration par le JSON donné. Renvoie "" si tout va bien, sinon le message d'erreur.
func import_json(text: String) -> String:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return "Le contenu n'est pas un fichier de configuration valide."
	var d: Dictionary = parsed
	if not d.has("levels") or not d.has("classes") or not d.has("party"):
		return "Configuration incomplète (niveaux, classes ou groupe manquant)."
	config = d
	return ""

## Code de partage : « DGZ1 » + base64 du JSON compressé en gzip (même format que la version HTML).
func encode_code(cfg: Dictionary) -> String:
	var raw := JSON.stringify(cfg).to_utf8_buffer()
	return "DGZ1" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))

## Décode un code de partage. Renvoie {} si le code est invalide.
func decode_code(code: String) -> Dictionary:
	code = code.strip_edges().replace("\n", "").replace(" ", "")
	var json := ""
	if code.begins_with("DGZ1"):
		var packed := Marshalls.base64_to_raw(code.substr(4))
		var raw := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		json = raw.get_string_from_utf8()
	elif code.begins_with("DRAW1"):
		json = Marshalls.base64_to_raw(code.substr(5)).get_string_from_utf8()
	else:
		return {}
	var parsed = JSON.parse_string(json)
	return parsed if parsed is Dictionary else {}

## Portrait (téléphone) : la base 1280×720 rendrait l'interface minuscule ; on agrandit pour viser ~540 unités de large.
## Dans la scène de jeu, l'interface est dessinée sur une zone de conception 1600 x 1000 (comme la page de l'original) puis
## réduite/agrandie pour toujours tout afficher, sans ascenseur, quelle que soit la définition de l'écran.
const GAME_DESIGN := Vector2(1600.0, 1000.0)
var game_scale_mode: bool = false:
	set(v):
		game_scale_mode = v
		_update_scale()

func _update_scale() -> void:
	var win := get_window()
	var sz := Vector2(win.size)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var base := minf(sz.x / 1280.0, sz.y / 720.0)
	var factor := 1.0
	if sz.x < sz.y * 1.05:
		factor = clampf((sz.x / 540.0) / base, 1.0, 8.0)
	elif game_scale_mode:
		var real := minf(sz.x / GAME_DESIGN.x, sz.y / GAME_DESIGN.y)
		factor = real / base
	win.content_scale_factor = factor

## Bandeau « Jouer ce donjon » de l'administration (création d'un donjon personnel).
var admin_banner: bool = false

## « Créer votre propre donjon » : part d'un donjon aléatoire modifiable dans l'administration.
func create_own_dungeon() -> void:
	config = DungeonGenerator.build_config(original_config, 3, 13, 11, "normal", [])
	save_config()
	admin_unlocked = true
	admin_banner = true
	get_tree().change_scene_to_file("res://scenes/admin.tscn")

## Partie en cours mise de côté pendant qu'on ouvre l'administration depuis le jeu.
var resume_game: Dictionary = {}

func resume_from_admin() -> void:
	var g := resume_game
	resume_game = {}
	if not g.is_empty():
		launch_save(g)

func open_admin() -> void:
	admin_banner = false
	get_tree().change_scene_to_file("res://scenes/admin.tscn")

func go_home() -> void:
	resume_game = {}
	Sound.stop_ambient()
	get_tree().change_scene_to_file("res://scenes/home.tscn")
