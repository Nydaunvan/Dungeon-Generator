extends Node
## Chargement des données du jeu (extraites du build HTML Donjon3D).
## Accessible partout via l'autoload `Data`.

var config: Dictionary = {}
var class_talents: Dictionary = {}
var constants: Dictionary = {}

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
