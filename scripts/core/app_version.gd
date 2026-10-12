class_name AppVersion
extends RefCounted
## Numéro de version du jeu : une seule source, `config/version` de project.godot (ex. « 1.30.1 »).
## Le workflow de publication lit le même champ pour nommer la version, les fichiers et l'étiquette Git.

static func number() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## « v1.30.1 », tel qu'affiché dans les pieds de page.
static func label() -> String:
	return "v" + number()

## True si la version `v` (« 1.33.6 », éventuellement « 1.34.0-test2 ») est strictement antérieure à `ref` (« 1.34.0 »).
static func is_before(v: String, ref: String) -> bool:
	var a := _key(v)
	var b := _key(ref)
	for i in 3:
		if a[i] != b[i]:
			return a[i] < b[i]
	return false

static func _key(v: String) -> Array:
	var base := v.split("-")[0]
	var out: Array = []
	for part in base.split("."):
		out.append(int(part))
	while out.size() < 3:
		out.append(0)
	return out
