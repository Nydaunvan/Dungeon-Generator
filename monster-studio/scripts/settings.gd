class_name StudioSettings
extends RefCounted
## Réglages du logiciel (user://studio/settings.json).

const PATH := "user://studio/settings.json"
const OLD_COMMAND := "python run.py \"{image}\" --output-dir \"{outdir}\" --model-save-format glb"
const DEFAULTS := {
	"workdir": "",                                                             # dossier du modèle d'IA (ex. TripoSR cloné)
	"command": "python run.py \"{image}\" --output-dir \"{outdir}\" --model-save-format glb --mc-resolution 384",
	"result": "{outdir}/0/mesh.glb",                                           # fichier produit par la commande
	"export_dir": "",                                                          # dossier d'export par défaut (ex. celui des modèles du jeu)
}

static func load_all() -> Dictionary:
	var d: Dictionary = DEFAULTS.duplicate()
	if FileAccess.file_exists(PATH):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if j is Dictionary:
			for k in j:
				d[k] = j[k]
		if str(d.command) == OLD_COMMAND:      # ancienne commande par défaut : passe à la résolution de maillage supérieure
			d.command = DEFAULTS.command
	return d

static func save_all(d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(Library.ROOT)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
