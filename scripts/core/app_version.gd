class_name AppVersion
extends RefCounted
## Numéro de version du jeu : une seule source, `config/version` de project.godot (ex. « 1.30.1 »).
## Le workflow de publication lit le même champ pour nommer la version, les fichiers et l'étiquette Git.

static func number() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## « v1.30.1 », tel qu'affiché dans les pieds de page.
static func label() -> String:
	return "v" + number()
