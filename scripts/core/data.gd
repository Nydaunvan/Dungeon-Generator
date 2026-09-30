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

func _ready() -> void:
	config = _load_json("res://data/default_config.json")
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

## Configuration utilisée par le jeu.
func active() -> Dictionary:
	return play_config if not play_config.is_empty() else config

## Lance une partie avec la configuration donnée (copie profonde) puis ouvre la scène de jeu.
func launch(cfg: Dictionary, origin: String) -> void:
	play_config = cfg.duplicate(true)
	play_origin = origin
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func launch_original() -> void:
	launch(config, "original")

func go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")
