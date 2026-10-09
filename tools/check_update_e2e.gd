extends Node
## Essai complet de la mise à jour partielle contre un serveur local (voir tools/check_update_e2e.sh) :
## lecture du manifeste → liste des fichiers modifiés → téléchargement vérifié → script de remplacement.
## Arguments (après « -- ») : base=<url du serveur> exe=<exécutable factice installé> assets=<noms séparés par des virgules>

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	Updater.exe_override = str(args.exe)
	var assets := {}
	for n in str(args.assets).split(","):
		assets[n] = str(args.base) + "/" + n
	var u := Updater.new()
	add_child(u)
	var got: Array = []
	u.check_done.connect(func(d: Dictionary): got.append(d))
	u.load_manifest({"version": "9.9.9", "manifest_url": str(args.base) + "/manifest-linux.json", "assets": assets})
	while got.is_empty():
		await get_tree().process_frame
	var info: Dictionary = got[0]
	var paths := []
	for f in info.get("plan", []):
		paths.append(f.path)
	paths.sort()
	print("PLAN=", ",".join(PackedStringArray(paths)), " TAILLE=", info.get("download_size", -1))
	var res: Array = []
	u.finished.connect(func(ok: bool, msg: String): res.append([ok, msg]))
	u.download(info)
	while res.is_empty():
		await get_tree().process_frame
	print("FINI=", res[0])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
