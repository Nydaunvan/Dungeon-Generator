extends Node
## Réglage de brume par niveau (champ `mist` de l'éditeur d'administration) : « on » toujours, « off » jamais, « auto »/absent = règle normale, jamais en extérieur.
## Lancer : xvfb-run -a godot --headless --path . res://tools/check_mist.tscn

func _ready() -> void:
	var fails := 0
	if not FogMist.level_has_mist("s", "L1", false, "on"):
		fails += 1
		print("ÉCHEC : on doit forcer la brume")
	if FogMist.level_has_mist("s", "L1", false, "off"):
		fails += 1
		print("ÉCHEC : off doit la couper")
	if FogMist.level_has_mist("s", "L1", true, "on"):
		fails += 1
		print("ÉCHEC : jamais en extérieur")
	var same := 0
	var with := 0
	for i in 400:
		var a := FogMist.level_has_mist("s", "L%d" % i, false, "auto")
		if a == FogMist.level_has_mist("s", "L%d" % i, false):
			same += 1
		if a:
			with += 1
	if same != 400:
		fails += 1
		print("ÉCHEC : auto doit rester la règle d'origine")
	print("brume auto : %d niveaux sur 400" % with)
	print("RESULTAT brume -> ", "OK" if fails == 0 else "ECHEC")
	get_tree().quit()
