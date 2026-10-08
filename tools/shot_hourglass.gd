extends SceneTree
## Capture de l'écran de chargement avec le sablier : godot --path . --script res://tools/shot_hourglass.gd -- out=/tmp/sablier.png
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 720)
	await process_frame
	var s := LoadingScreen.new()
	root.add_child(s)
	await create_timer(0.5).timeout
	s.set_progress(1.0, "Prêt")
	s.show_hourglass("Recherche de mises à jour…")
	await create_timer(1.6).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/sablier.png")))
	quit()
