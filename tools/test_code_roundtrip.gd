extends SceneTree
## Aller-retour DGZ1 avec la version HTML : godot --headless --script res://tools/test_code_roundtrip.gd -- dir=/tmp/rt
## Lit <dir>/html_code.txt + html_cfg.json (produits par le HTML via Chromium) : le code doit se décoder en la même configuration.
## Écrit <dir>/go_code.txt + go_cfg.json : le HTML doit à son tour décoder ce code (voir tools/code_roundtrip.py).
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var dir := str(args.get("dir", "/tmp/rt"))
	await process_frame
	var data = root.get_node("Data")
	var fails := 0
	var saves = load("res://scripts/core/saves.gd")
	var code := FileAccess.get_file_as_string(dir + "/html_code.txt")
	var want = JSON.parse_string(FileAccess.get_file_as_string(dir + "/html_cfg.json"))
	var got: Dictionary = data.decode_code(code)
	var ok := not got.is_empty() and JSON.stringify(got, "", true) == JSON.stringify(want, "", true)
	print(("OK   " if ok else "FAIL ") + "HTML -> Godot : le code (%d caractères) se décode à l'identique" % code.length())
	if not ok: fails += 1
	# Godot -> HTML
	var mine: String = data.encode_code(data.config)
	var f := FileAccess.open(dir + "/go_code.txt", FileAccess.WRITE)
	f.store_string(mine)
	f.close()
	f = FileAccess.open(dir + "/go_cfg.json", FileAccess.WRITE)
	f.store_string(saves.stringify(data.config))
	f.close()
	var back: Dictionary = data.decode_code(mine)
	var ok2: bool = saves.stringify(back) == saves.stringify(data.config)
	print(("OK   " if ok2 else "FAIL ") + "Godot -> Godot (%d caractères)" % mine.length())
	if not ok2: fails += 1
	print("ÉCHECS: %d" % fails)
	quit()
