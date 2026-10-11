extends SceneTree
## Onglet Galerie du Super admin (réseau simulé). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_sadmin_gallery.gd -- <fichier.png>
func fake(_method: int, full_url: String, _headers: PackedStringArray, _body: String) -> Dictionary:
	var fn := full_url.get_slice("/rpc/", 1).get_slice("?", 0)
	var out: Variant = {}
	match fn:
		"admin_gallery_stats": out = {"public": 14, "total": 51, "downloads": 230, "reports_pending": 2, "bans": 1}
		"admin_gallery_reports": out = [
			{"dungeon_id": "d1", "title": "Le temple englouti", "description": "Trois niveaux d'eau et d'ombre.", "is_public": true, "downloads": 42, "created_at": "2026-10-09T10:00:00Z", "player_id": "p1", "pseudo": "Troll42", "reports": 3, "reasons": ["contenu offensant", "spam"], "banned": false},
			{"dungeon_id": "d2", "title": "Cave", "description": "", "is_public": false, "downloads": 1, "created_at": "2026-10-10T18:30:00Z", "player_id": "p2", "pseudo": "Brouss", "reports": 1, "reasons": ["nom"], "banned": true}]
		"admin_gallery_bans": out = [{"player_id": "p2", "pseudo": "Brouss", "reason": "signalement", "created_at": "2026-10-10T20:00:00Z"}]
	return {"result": 0, "code": 200, "body": JSON.stringify(out).to_utf8_buffer()}

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/sg.png"
	root.size = Vector2i(1280, 1000)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud.url = "https://fake.supabase.co"
	cloud.key = "k"
	cloud.session = {"refresh_token": "r", "access_token": "a", "expires_at": 9999999999.0, "user_id": "u1", "pseudo": "Moi"}
	cloud._transport = Callable(self, "fake")
	root.get_node("Data").go_home()
	await create_timer(5.0).timeout
	var host: Node = current_scene.get("_modal_layer")
	var s = load("res://scripts/ui/super_admin_modal.gd").open(host)
	s._show("gallery")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out)
	quit()
