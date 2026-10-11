extends SceneTree
## Teste les récompenses de communauté SANS réseau (faux transport) : donjon de la semaine en tête de la galerie, téléchargement lié à la
## galerie, déclaration de victoire (une seule fois). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_community.gd -- <png>
var calls: Array = []
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	calls.append(full_url + " " + body)
	if "gallery_featured" in full_url:
		return resp(200, {"id": "d1", "title": "Le temple englouti", "description": "Trois niveaux d'eau et d'ombre.", "downloads": 42, "week_downloads": 9, "created_at": "2026-10-09T10:00:00Z", "owner_id": "u2", "pseudo": "Nydaunvan"})
	if "record_gallery_clear" in full_url:
		return resp(200, 1)
	if "count_download" in full_url:
		return resp(204)
	if "/rest/v1/dungeons?id=eq." in full_url:
		return resp(200, [{"title": "Le temple englouti", "description": "x", "code": ""}])
	if "/rest/v1/dungeons" in full_url:
		return resp(200, [])
	return resp(200, [])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 900)
	await process_frame
	var cloud = root.get_node("Cloud")
	var data = root.get_node("Data")
	var MD = load("res://scripts/core/my_dungeons.gd")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600}
	for m in MD.list():
		MD.delete(m.id)
	# donjon importé de la galerie, puis victoire
	var id: String = MD.create(data.original_config.duplicate(true), "", "", false, "d1")
	MD.begin_existing(id)
	await MD.report_gallery_clear()
	await MD.report_gallery_clear()
	var n := 0
	for c in calls:
		if "record_gallery_clear" in c:
			n += 1
	print("déclarations de victoire envoyées : ", n, " (attendu 1) cleared=", MD.meta(id).get("cleared"))
	print("donjon sans origine galerie : ")
	var id2: String = MD.create(data.original_config.duplicate(true))
	MD.begin_existing(id2)
	calls.clear()
	await MD.report_gallery_clear()
	print("  appels : ", calls.size(), " (attendu 0)")
	data.go_home()
	await create_timer(4.0).timeout
	var host: Node = current_scene._modal_layer
	load("res://scripts/ui/gallery_modal.gd").open(host)
	await create_timer(1.5).timeout
	for mo in get_nodes_in_group("modal"):
		if mo.has_method("_fit"):
			mo._fit()
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/community.png")
	for m in MD.list():
		MD.delete(m.id)
	quit()
