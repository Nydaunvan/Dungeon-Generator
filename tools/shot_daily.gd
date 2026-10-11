extends SceneTree
## Capture du Défi du jour et des nouvelles règles hebdomadaires dans le hub, SANS réseau (faux transport).
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_daily.gd -- <préfixe>
func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}
func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	if "rpc/daily_current" in full_url:
		return resp(200, {"period": "2026-10-11", "ends_at": "2026-10-12T22:00:00+00:00", "starts_at": "2026-10-11T22:00:00+00:00", "levels": 2,
			"rule": {"rule_id": "fog", "icon": "🌫️", "label_fr": "Brouillard épais", "label_en": "Thick Fog", "desc_fr": "Mini-carte très réduite : on avance à tâtons.", "desc_en": "x", "mods": ["mod_fog"], "metric": "levels"}})
	if "rpc/my_daily_status" in full_url:
		return resp(200, {"done": true, "tries": 2, "total": 6})
	if "rpc/weekly_current" in full_url:
		return resp(200, {"period": "2026-W49", "ends_at": "2026-12-06T23:00:00+00:00", "starts_at": "2026-11-29T23:00:00+00:00", "levels": 6,
			"rule": {"rule_id": "richest", "icon": "💰", "label_fr": "Plus riche", "label_en": "Richest", "desc_fr": "Le classement se fait à l'or gagné : butin des monstres et trésors trouvés (les ventes ne comptent pas). Terminer le donjon reste nécessaire pour le badge.", "desc_en": "x", "mods": [], "metric": "gold"},
			"next": {"rule_id": "bossrush", "icon": "👑", "label_fr": "Chasseur de boss", "label_en": "Boss Hunter"}})
	if "classement_periode" in full_url:
		return resp(200, [{"pseudo": "Nydaunvan", "score": 1280, "seconds": 1500, "level": 12}, {"pseudo": "Jyraia", "score": 940, "seconds": 1710, "level": 4}])
	return resp(200, [])
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/daily"
	root.size = Vector2i(1280, 900)
	await process_frame
	var cloud = root.get_node("Cloud")
	cloud._transport = Callable(self, "fake")
	cloud.session = {"access_token": "A", "refresh_token": "R", "user_id": "u1", "expires_in": 3600, "email": "a@b.fr", "pseudo": "Nydaunvan"}
	var data = root.get_node("Data")
	data.go_home()
	await create_timer(4.0).timeout
	var host: Node = current_scene._modal_layer
	var hub = load("res://scripts/ui/online_hub.gd").open(host, Callable())
	await create_timer(1.5).timeout
	hub._mode = "daily"
	hub._show("play")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_daily.png")
	hub._mode = "weekly"
	hub._show("play")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_weekly.png")
	hub._src = "weekly"
	hub._tab = "boards"
	hub._show("boards")
	await create_timer(1.5).timeout
	root.get_texture().get_image().save_png(pre + "_board.png")
	quit()
