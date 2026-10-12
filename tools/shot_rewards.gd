extends SceneTree
## Capture du navigateur de récompenses (faux transport, sans réseau).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_rewards.gd -- <préfixe>
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if "rpc/announcement_current" in full_url:
		return resp(200, {"id": 1, "body": "Maintenance ce soir à 22 h.", "created_at": "2026-10-12T05:00:00Z", "expires_at": "2026-10-13T05:00:00Z"})
	if "rpc/server_state_get" in full_url:
		return resp(200, {"ranked_closed": true, "chat_closed": false, "message": "Retour vers 23 h"})
	if "rpc/staff_public" in full_url:
		return resp(200, [{"player_id": "u1", "role": "dev"}])
	if "/rest/v1/badges" in full_url:
		return resp(200, [
			{"id": "a", "icon": "🗡️", "label_fr": "Tueur", "desc_fr": "Tuer 100 monstres", "rarity": 1, "title_fr": "Le Tueur", "frame": null, "color": null},
			{"id": "b", "icon": "🛡️", "label_fr": "Gardien", "desc_fr": "Finir un donjon sans mourir", "rarity": 3, "title_fr": null, "frame": "gold", "color": null},
			{"id": "c", "icon": "🌈", "label_fr": "Arc-en-ciel", "desc_fr": "Atteindre le niveau 30", "rarity": 5, "title_fr": null, "frame": null, "color": "#ff66cc"},
			{"id": "d", "icon": "👑", "label_fr": "Roi", "desc_fr": "Top 1 du classement", "rarity": 4, "title_fr": "Le Roi", "frame": "gold", "color": "#ffd700"}])
	if "player_badges" in full_url:
		return resp(200, [{"badge_id": "a"}, {"badge_id": "c"}])
	if "account_xp" in full_url:
		return resp(200, [{"xp": 500, "level": 3}])
	return resp(200, [])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/rw"
	root.size = Vector2i(1280, 900)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600, "email": "a@b.fr", "pseudo": "Nydaunvan"}
	root.get_node("Data").go_home()
	await create_timer(4.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var hub = load("res://scripts/ui/online_hub.gd").open(host, Callable())
	await create_timer(0.5).timeout
	hub._show("rewards")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_all.png")
	for k in ["title", "frame", "color", "skin"]:
		hub._rw_kind = k
		hub._show_rewards_again()
		await create_timer(0.6).timeout
		root.get_texture().get_image().save_png(pre + "_" + k + ".png")
	hub._rw_filter = "todo"
	hub._show_rewards_again()
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(pre + "_todo.png")
	quit()
