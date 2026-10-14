extends SceneTree
## Capture de la fenêtre « Mode en ligne » (faux transport, aucune donnée inventée : listes vides). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_online.gd -- <png> [onglet]
func fake(_m: int, _url: String, _h: PackedStringArray, _b: String) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": "[]".to_utf8_buffer()}
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 800)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.url = "https://exemple.supabase.co"
	cloud.key = "k"
	cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "p1", "email": "n@e.org", "pseudo": "Nydaunvan"}
	var home = load("res://scenes/home.tscn").instantiate()
	root.add_child(home)
	await create_timer(1.5).timeout
	load("res://scripts/ui/online_hub.gd").open(home, Callable(), a[1] if a.size() > 1 else "play")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/online.png")
	quit()
