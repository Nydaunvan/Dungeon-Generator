extends SceneTree
## Capture du journal des versions (date à côté du numéro de version).
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_changelog.gd -- /tmp/changelog.png
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 900)
	await process_frame
	root.get_node("Data").go_home()
	await create_timer(4.0).timeout
	DocModal.changelog(current_scene._modal_layer)
	await create_timer(2.0).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/changelog.png")
	quit()
