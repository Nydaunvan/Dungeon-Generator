extends Node
## Premier autoload : monte les paquets de ressources (.pck) installés à côté de l'exécutable, dans le dossier « packs ».
## L'exécutable ne contient que le moteur ; le code et les données sont dans « <nom>.pck » (chargé par Godot tout seul) et les
## gros fichiers (thèmes, monstres, audio…) dans « packs/*.pck », ce qui permet de ne mettre à jour que ce qui a changé.
## Les paquets ne remplacent jamais un fichier du paquet principal (replace_files = false) : un ancien paquet resté en place ne peut donc
## pas masquer project.binary ni le code à jour.
## Le montage se fait dans `_init` : avant la création des autoloads suivants, donc avant qu'ils ne lisent la moindre ressource.
## Dans l'éditeur ou sur le Web (tout est déjà dans le projet / dans l'export), il n'y a rien à faire.

const DIR := "packs"

var loaded: PackedStringArray = []

func _init() -> void:
	if OS.has_feature("editor") or OS.has_feature("web"):
		return
	var dir := OS.get_executable_path().get_base_dir().path_join(DIR)
	if not DirAccess.dir_exists_absolute(dir):
		return
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for n in names:
		if str(n).ends_with(".pck") and ProjectSettings.load_resource_pack(dir.path_join(str(n)), false):
			loaded.append(str(n))
