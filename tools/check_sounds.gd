extends Node
## Vérifie que chaque sort par défaut a son fichier son, et que les sons divers se chargent.
func _ready() -> void:
	var bad := 0
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/default_config.json"))
	var ids: Array = []
	for sp in cfg.get("spells", []):
		ids.append(str(sp.id))
	for id in ids:
		if not Sound.spell_sound(str(id)):
			print("SANS SON : ", id)
			bad += 1
	for id in Sound.SPELL_SOUND_IDS:
		if not ids.has(id):
			print("FICHIER SANS SORT : ", id)
			bad += 1
	for k in Sound.MISC_SOUNDS:
		if load(Sound.MISC_SOUNDS[k]) == null:
			print("MANQUE ", k)
			bad += 1
	Sound.attack_standard(); Sound.boss_win("x"); Sound.boss_win("y"); Sound.potion(); Sound.fountain()
	print("RESULTAT sons : ", "OK" if bad == 0 else "%d problème(s)" % bad, " (", ids.size(), " sorts)")
	get_tree().quit()
