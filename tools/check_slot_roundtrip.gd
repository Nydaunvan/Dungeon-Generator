extends Node
## Une partie en cours, écrite dans un emplacement puis relue : le fichier doit être un JSON valide et l'emplacement ne doit pas paraître vide.
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_slot_roundtrip.tscn

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var snap: Dictionary = main.snapshot()
	var ok := Saves.write_slot(9, snap.config, snap.save, snap.origin)
	var raw := FileAccess.get_file_as_string(Saves._path(9))
	print("écriture ok=", ok, " taille=", raw.length())
	var jp := JSON.new()
	var err := jp.parse(raw)
	var bad := 0
	if err != OK:
		bad += 1
		print("ÉCHEC lecture JSON : ligne ", jp.get_error_line(), " ", jp.get_error_message())
		var lines := raw.split("\n")
		var ln := jp.get_error_line() - 1
		if ln >= 0 and ln < lines.size():
			print("  contexte : ", lines[ln].substr(0, 200))
		else:
			var at := int(minf(raw.length(), 400))
			print("  début : ", raw.substr(0, at))
	var sm := Saves.summary(9)
	if sm.is_empty():
		bad += 1
		print("ÉCHEC : l'emplacement paraît vide après sauvegarde")
	else:
		print("résumé : ", sm)
	Saves.delete_slot(9)
	print("OK" if bad == 0 else "%d échec(s)" % bad)
	get_tree().quit(1 if bad else 0)
