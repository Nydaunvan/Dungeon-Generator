extends SceneTree
## Génère l'image de démarrage (boot splash) : l'écran de chargement à 0 %, épée vide, sans conseil ni braises.
## godot --rendering-driver opengl3 --path . --script res://tools/gen_splash.gd -- out=res://assets/splash.png
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 720)
	await process_frame
	var screen := LoadingScreen.new()
	root.add_child(screen)
	screen.set_subtitle(L.t("loading.sous_titre_jeu"))
	screen._tip.visible = false
	screen._embers.emitting = false
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(str(args.get("out", "res://assets/splash.png"))))
	quit()
