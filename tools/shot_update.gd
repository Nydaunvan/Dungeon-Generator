extends SceneTree
## Capture de la fenêtre de mise à jour : godot --path . --script res://tools/shot_update.gd -- out=/tmp/maj.png
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1280, 800)
	await process_frame
	var data = root.get_node("Data")
	data.launch_original()
	await create_timer(8.0).timeout
	var host := CanvasLayer.new()
	host.layer = 50
	current_scene.add_child(host)
	var info := {"version": "1.31.0", "prerelease": false, "notes": "## Besace\nNouvelle besace avec onglets en rail.\n## Mises à jour\nMise à jour directement dans le jeu.\nLes sauvegardes sont migrées.", "page": "", "url": "", "asset": "x"}
	load("res://scripts/ui/update_modal.gd").open(host, info)
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/maj.png")))
	quit()
