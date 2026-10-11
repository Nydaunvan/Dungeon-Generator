extends SceneTree
## Garde-fou : la requête de la galerie désigne explicitement le lien vers l'auteur (sinon le serveur répond « ambigu » : PGRST201)
## et lit bien le pseudo dans la réponse. Sans réseau (faux transport). Usage : xvfb-run -a godot --path . --script res://tools/check_gallery_query.gd
var urls: Array = []
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	urls.append(full_url)
	var rows := [{"id": "d1", "title": "Test", "description": "", "downloads": 3, "created_at": "2026-10-11T10:00:00+00:00", "owner_id": "u2", "game_version": "1.33.5", "profiles": {"pseudo": "Jyraia"}}]
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(rows).to_utf8_buffer()}
func _init() -> void:
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	if not cloud.is_configured():
		cloud.url = "https://exemple.supabase.co"
		cloud.key = "sb_publishable_test"
	var MD: GDScript = load("res://scripts/core/my_dungeons.gd")
	var r: Dictionary = await MD.gallery("", "recent", 0)
	var bad := 0
	if urls.is_empty() or not str(urls[0]).contains("profiles!dungeons_owner_id_fkey(pseudo)"):
		bad += 1
		print("ÉCHEC : lien explicite absent : ", urls)
	if not r.ok or (r.data as Array).is_empty() or str(r.data[0].get("pseudo", "")) != "Jyraia":
		bad += 1
		print("ÉCHEC : pseudo non lu : ", r)
	print("check_gallery_query : ", "OK" if bad == 0 else "%d échec(s)" % bad)
	quit(1 if bad > 0 else 0)
