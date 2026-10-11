extends SceneTree
## Tchat en panneau replié sur le jeu (réseau simulé). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_chatdock.gd -- <préfixe>
var _sent := []
func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	var fn := full_url.get_slice("/rpc/", 1).get_slice("?", 0)
	var out: Variant = {}
	match fn:
		"chat_charte_etat": out = {"version": 1, "accepted": 1}
		"chat_fetch":
			var room: String = JSON.parse_string(body).get("p_room", "")
			out = [
				{"id": 1, "player_id": "u2", "pseudo": "Brouss", "body": "Quelqu'un pour un donjon hardcore ce soir ?", "created_at": "2026-10-11T18:02:00Z", "color": "#9cc79a", "level": 12},
				{"id": 2, "player_id": "u3", "pseudo": "Nydaunvan", "body": "Je suis partant, défi de la semaine d'abord !", "created_at": "2026-10-11T18:03:00Z", "color": "", "level": 31},
				{"id": 3, "player_id": "u1", "pseudo": "Moi", "body": "Moi aussi (%s)" % room, "created_at": "2026-10-11T18:04:00Z", "color": "", "level": 5}]
		"chat_unread": out = {"total": 3, "dm": 1, "rooms": {"general": 2, "en": 1}}
		"chat_conversations": out = [{"player_id": "u2", "pseudo": "Brouss", "body": "salut, tu joues ce soir ?", "created_at": "2026-10-11T19:00:00Z", "mine": false, "unread": 1, "last_id": 5}]
		"chat_dm_open": out = true
	return {"result": 0, "code": 200, "body": JSON.stringify(out).to_utf8_buffer()}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/cd"
	root.size = Vector2i(1280, 800)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud.url = "https://fake.supabase.co"
	cloud.key = "k"
	cloud.session = {"refresh_token": "r", "access_token": "a", "expires_at": 9999999999.0, "user_id": "u1", "pseudo": "Moi"}
	cloud._transport = Callable(self, "fake")
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 1, 7)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var dock = root.get_node("ChatDock")
	root.get_node("ChatAlerts").apply({"total": 3, "dm": 1, "rooms": {"general": 2, "en": 1}})
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(pre + "_closed.png")
	dock.open_panel()
	dock._pinned = true
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_open.png")
	print("ouvert=", dock._open)
	dock._show_add()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_add.png")
	dock._show_settings()
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_settings.png")
	# repli : souris loin du panneau
	dock._show_channel("general")
	await create_timer(0.5).timeout
	dock._hold = 0.0
	Input.warp_mouse(Vector2(900, 200))
	await create_timer(1.5).timeout
	print("ouvert après départ de la souris=", dock._open)
	quit()
