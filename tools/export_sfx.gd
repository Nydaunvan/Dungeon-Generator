extends Node
## Écrit chaque effet sonore synthétisé du jeu en .wav pour mesurer son volume (voir tools/sfx_levels.py).
## godot --headless --path . res://tools/export_sfx.tscn -- out=/chemin/dossier

func _ready() -> void:
	var out := "user://sfx_wav"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var jobs: Array = []   # [nom de fichier, nom du son, argument]
	for n in Sound.PRELOAD_PLAIN:
		jobs.append([n, n, null])
	for w in Sound.PRELOAD_SWINGS:
		jobs.append(["swing_" + w, "swing", w])
	for st in Sound.PRELOAD_SPELLS:
		jobs.append(["spell_" + st, "spell", st])
	jobs.append(["stairs_up", "stairs", true])
	jobs.append(["stairs_down", "stairs", false])
	for j in jobs:
		var st: AudioStreamWAV = Sound._build_sfx(str(j[1]), j[2])
		st.save_to_wav("%s/%s.wav" % [out, j[0]])
	print("%d sons écrits dans %s" % [jobs.size(), out])
	get_tree().quit()
