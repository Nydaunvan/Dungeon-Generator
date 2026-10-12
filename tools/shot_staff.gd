extends SceneTree
## Captures de l'écran Administration selon le rôle (faux transport, sans réseau).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_staff.gd -- <rôle> <préfixe>
var role := "dev"
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var u := full_url
	if "rpc/staff_role" in u:
		return resp(200, role)
	if "rpc/staff_public" in u:
		return resp(200, [{"player_id": "u1", "role": role}, {"player_id": "u2", "role": "super_admin"}])
	if "rpc/staff_list" in u:
		return resp(200, [
			{"player_id": "u1", "pseudo": "Nydaunvan", "role": "dev", "rank": 3, "granted_at": "2026-10-12T05:00:00Z", "granted_by": null, "granted_by_pseudo": null},
			{"player_id": "u2", "pseudo": "Alice", "role": "super_admin", "rank": 2, "granted_at": "2026-10-11T10:00:00Z", "granted_by": "u1", "granted_by_pseudo": "Nydaunvan"},
			{"player_id": "u3", "pseudo": "Bob", "role": "moderator", "rank": 1, "granted_at": "2026-10-11T12:00:00Z", "granted_by": "u2", "granted_by_pseudo": "Alice"}])
	if "rpc/admin_player_card" in u:
		return resp(200, {"player_id": "u2", "pseudo": "Alice", "created_at": "2026-09-01T10:00:00Z", "role": "super_admin", "rank": 2,
			"mute": null, "gallery_ban": null, "account_ban": null,
			"messages": [{"id": 5, "room": "general", "body": "Salut tout le monde", "created_at": "2026-10-12T04:00:00Z", "deleted": false}],
			"history": [{"action": "role_set", "detail": {}, "created_at": "2026-10-11T10:00:00Z", "actor_pseudo": "Nydaunvan"}]})
	if "rpc/admin_players" in u:
		return resp(200, [{"id": "u2", "pseudo": "Alice", "level": 4, "xp": 900, "runs": 5, "verified": 3, "best_score": 12, "last_run_at": "2026-10-11T10:00:00Z", "role": "super_admin", "muted": false, "banned": false},
			{"id": "u4", "pseudo": "Charlie", "level": 2, "xp": 200, "runs": 1, "verified": 1, "best_score": 4, "last_run_at": null, "role": null, "muted": true, "banned": true}])
	if "rpc/staff_log_list" in u:
		return resp(200, [{"id": 3, "actor": "u3", "actor_pseudo": "Bob", "action": "chat_mute", "target": "u4", "target_pseudo": "Charlie", "detail": {"until": "2026-10-13T10:00:00Z", "reason": "spam"}, "created_at": "2026-10-12T04:10:00Z"},
			{"id": 2, "actor": "u1", "actor_pseudo": "Nydaunvan", "action": "maintenance", "target": null, "target_pseudo": null, "detail": {"ranked_closed": true, "chat_closed": false, "message": "Mise à jour"}, "created_at": "2026-10-12T03:00:00Z"}])
	if "rpc/admin_health" in u:
		return resp(200, {"queue": 0, "oldest_queue_seconds": null, "in_progress": 2, "stuck_started": 1, "expired_24h": 3, "chat_24h": 40, "staff_actions_24h": 5, "db_bytes": 12582912,
			"rejected_24h": [{"reason": "score_invraisemblable", "n": 2}], "tables": [{"name": "ranked_runs", "bytes": 1048576}], "server_state": {"ranked_closed": false, "chat_closed": false, "message": null}})
	if "rpc/admin_account_bans" in u:
		return resp(200, [{"player_id": "u4", "pseudo": "Charlie", "reason": "triche", "until": null, "created_at": "2026-10-12T01:00:00Z"}])
	if "rpc/admin_boards" in u:
		return resp(200, [{"kind": "weekly", "period": "2026-W41", "difficulty": null, "verified": 2}, {"kind": "difficulty", "period": null, "difficulty": "normal", "verified": 5}])
	if "rpc/admin_chat_stats" in u:
		return resp(200, {"reports_pending": 2, "messages_24h": 10, "authors_24h": 3, "messages_total": 100, "deleted_total": 1, "mutes_active": 1, "blocks": 0, "words": 3})
	if "rpc/admin_gallery_stats" in u:
		return resp(200, {"reports_pending": 1})
	if "rpc/admin_chat_reports" in u or "rpc/admin_gallery_reports" in u or "rpc/admin_chat_words" in u:
		return resp(200, [])
	if "rpc/announcement_current" in u:
		return resp(200, {"id": 1, "body": "Maintenance ce soir à 22 h.", "created_at": "2026-10-12T05:00:00Z", "expires_at": "2026-10-13T05:00:00Z"})
	if "rpc/server_state_get" in u:
		return resp(200, {"ranked_closed": true, "chat_closed": false, "message": "Retour vers 23 h"})
	return resp(200, [])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0] if a.size() > 0 else "dev"
	var pre: String = a[1] if a.size() > 1 else "/tmp/staff"
	root.size = Vector2i(1280, 900)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600, "expires_at": 9999999999.0, "email": "a@b.fr", "pseudo": "Nydaunvan"}
	root.get_node("Data").go_home()
	await create_timer(4.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var SA = load("res://scripts/core/super_admin.gd")
	print("rôle : ", await SA.fetch_role(), " rang ", SA.rank())
	var m = load("res://scripts/ui/super_admin_modal.gd").open(host)
	print("onglets : ", load("res://scripts/ui/super_admin_modal.gd").tabs_for_rank(SA.rank()))
	await create_timer(1.0).timeout
	for t in ["mod", "players", "team", "log", "dev"]:
		if not load("res://scripts/ui/super_admin_modal.gd").tabs_for_rank(SA.rank()).has(t):
			continue
		m._show(t)
		await create_timer(1.2).timeout
		root.get_texture().get_image().save_png("%s_%s.png" % [pre, t])
	m._open_card("u2")
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png(pre + "_card.png")
	quit()
