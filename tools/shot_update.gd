extends SceneTree
## Capture de la fenêtre de mise à jour avec de vraies notes de publication GitHub (Markdown, bloc VirusTotal compris).
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_update.gd -- <notes.md> <sortie.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 900)
	await process_frame
	root.get_node("Data").go_home()
	await create_timer(4.0).timeout
	var notes := FileAccess.get_file_as_string(a[0]) if a.size() > 0 else ""
	var info := {"version": "1.34.0", "notes": notes, "download_size": 17 * 1048576, "prerelease": false, "page": "", "plan": []}
	var m: Modal = UpdateModal.open(current_scene._modal_layer, info)
	await create_timer(1.5).timeout
	# fait défiler jusqu'en bas (résultats VirusTotal)
	var sc := m.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		(sc[0] as ScrollContainer).scroll_vertical = 100000
		await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(a[1] if a.size() > 1 else "/tmp/update.png")
	quit()
