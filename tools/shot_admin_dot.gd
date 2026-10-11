extends SceneTree
## Capture de la pastille « à traiter » d'un super admin sur le bouton Compte (faux transport, sans réseau).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_admin_dot.gd -- <sortie.png>
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if "rpc/is_super_admin" in full_url:
		return resp(200, true)
	if "rpc/admin_chat_stats" in full_url:
		return resp(200, {"reports_pending": 2})
	if "rpc/admin_gallery_stats" in full_url:
		return resp(200, {"reports_pending": 1})
	return resp(200, [])
func _find(n: Node, out: Array) -> void:
	if n is Button and (n as Button).text == "◂" and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_find(c, out)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600, "email": "a@b.fr", "pseudo": "Nydaunvan"}
	root.get_node("Data").go_home()
	await create_timer(5.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.8).timeout
	var tgl: Array = []
	_find(root, tgl)
	for b in tgl:
		(b as Button).pressed.emit()
	await create_timer(1.0).timeout
	print("à traiter : ", load("res://scripts/core/super_admin.gd").pending())
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/admin_dot.png")
	quit()
