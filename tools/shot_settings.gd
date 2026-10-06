extends SceneTree
## Captures du menu Paramètres et du rendu par niveau graphique. Usage :
## xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_settings.gd -- out=/tmp/x scene=home|main tab=graphics|display|sound|access|diag preset=low|medium|high|ultra|auto size=1280x800 lang=fr
## Les réglages du poste (user://settings.cfg) sont rétablis à la fin.
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1280x800")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var cfg := "user://settings.cfg"
	var had := FileAccess.file_exists(cfg)
	var backup := FileAccess.get_file_as_bytes(cfg) if had else PackedByteArray()
	var st: Node = root.get_node("Settings")
	if args.has("lang"):
		root.get_node("Data").set_lang(str(args.lang))
	if args.has("preset"):
		st.set_auto_adapt(false)
		st.set_preset(str(args.preset))
	var scene: Node = load("res://scenes/%s.tscn" % str(args.get("scene", "main"))).instantiate()
	root.add_child(scene)
	await create_timer(2.5).timeout
	if args.has("tab"):
		var host: Node = scene._modals() if scene.has_method("_modals") else scene._modal_layer
		# chargé à l'exécution : un script lancé avec --script compile ses dépendances avant que les autoloads existent
		var modal_cls: GDScript = load("res://scripts/ui/settings_modal.gd")
		modal_cls.open(host, str(args.tab))
		await create_timer(0.8).timeout
	root.get_texture().get_image().save_png("%s.png" % str(args.get("out", "/tmp/s")))
	if had:
		var f := FileAccess.open(cfg, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit()
