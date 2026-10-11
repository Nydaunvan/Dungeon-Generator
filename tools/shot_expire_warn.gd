extends SceneTree
## Capture de l'avertissement « une partie classée est déjà en cours », SANS réseau (faux transport).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_expire_warn.gd -- <sortie.png>
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if "ranked_runs" in full_url:
		var t := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - 1800)
		return resp(200, [{"id": "r1", "difficulty": "hard", "kind": "difficulty", "status": "started", "started_at": t + "+00:00"}])
	return resp(200, [])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 900)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600, "email": "a@b.fr", "pseudo": "Nydaunvan"}
	root.get_node("Data").go_home()
	await create_timer(4.0).timeout
	var host: Node = current_scene._modal_layer
	var hub = load("res://scripts/ui/online_hub.gd").open(host, Callable())
	await create_timer(1.5).timeout
	hub._ask("difficulty")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/warn.png")
	quit()
