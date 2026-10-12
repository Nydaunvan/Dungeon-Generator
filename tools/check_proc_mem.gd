extends SceneTree
## Vérifie le calcul de la RAM du compteur de performances (valeur non nulle sous Linux, lecture du format tasklist).
## Usage : godot --headless --path . --script res://tools/check_proc_mem.gd
func _init() -> void:
	var bad := 0
	var v: float = ProcMem.mb()
	print("RAM du processus : %.0f Mo" % v)
	if OS.get_name() == "Linux" and v < 20.0:
		bad += 1
		print("ÉCHEC : mesure nulle ou absurde")
	var cases := {
		"\"Godot.exe\",\"1234\",\"Console\",\"1\",\"123 456 Ko\"": 123456.0 / 1024.0,
		"\"Godot.exe\",\"1234\",\"Console\",\"1\",\"1,234,567 K\"": 1234567.0 / 1024.0,
		"\"Godot.exe\",\"1234\",\"Console\",\"1\",\"98 304 Ko\"\r\n": 98304.0 / 1024.0,
	}
	for k in cases:
		var r: float = ProcMem.parse_tasklist(k)
		if absf(r - float(cases[k])) > 0.01:
			bad += 1
			print("ÉCHEC tasklist : ", k, " -> ", r)
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
