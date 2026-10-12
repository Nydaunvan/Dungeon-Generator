extends SceneTree
## Capture de l'onglet « Mes parties » (résumé + histogramme des scores), SANS réseau (faux transport).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_runs.gd -- <sortie.png>
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(_method: int, full_url: String, _headers: PackedStringArray, _body: String) -> Dictionary:
	if "ranked_runs" in full_url:
		var out: Array = []
		var scores := [3, 5, 4, 7, 6, 8, 5, 9, 7, 10, 8, 12]
		var now := int(Time.get_unix_time_from_system())
		for i in scores.size():
			var t := Time.get_datetime_string_from_unix_time(now - 86400 * (scores.size() - i) - 600)
			out.push_front({"id": "r%d" % i, "difficulty": "normal", "kind": "difficulty", "status": "verified", "score": scores[i], "seconds": 600 + i * 40, "started_at": t + "+00:00", "submitted_at": t + "+00:00"})
		return resp(200, out)
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
	load("res://scripts/ui/online_hub.gd").open(host, Callable(), "runs")
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/runs.png")
	quit()
