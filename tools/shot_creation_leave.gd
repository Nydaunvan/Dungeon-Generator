extends SceneTree
## Capture de la fenêtre « Quitter la création du donjon ». Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_creation_leave.gd -- <fichier.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/cl.png"
	root.size = Vector2i(1280, 800)
	await process_frame
	var data = root.get_node("Data")
	data.admin_unlocked = true
	data.open_admin()
	await create_timer(6.0).timeout
	current_scene._creation_leave_overlay()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out)
	quit()
