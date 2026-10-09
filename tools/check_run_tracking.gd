extends SceneTree
## Lance une vraie partie en donjon aléatoire (scène de jeu) et vérifie le suivi pour les défis : temps de jeu, niveaux franchis
## (jamais comptés deux fois), envoi au classement (faux serveur), marquage « administration ouverte ».
## Lancer (affichage ou Xvfb requis, la scène est en 3D) : godot --path . --script res://tools/check_run_tracking.gd

var posts: Array = []
var fails := 0

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func fake(_m: int, url: String, _h: PackedStringArray, body: String) -> Dictionary:
	var data: Variant = []
	if "/rest/v1/challenges" in url:
		data = [{"id": "c1", "slug": "x", "title": "T", "theme": "x", "mode": "declared", "unit": "niveaux", "description": "",
			"rules": {"metric": "levelsCleared", "origin": "random"}, "starts_at": "2020-01-01T00:00:00+00:00", "ends_at": null}]
	elif "/rest/v1/scores" in url:
		posts.append(JSON.parse_string(body))
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": JSON.stringify(data).to_utf8_buffer()}

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var cloud = root.get_node("Cloud")
	var data = root.get_node("Data")
	cloud._transport = Callable(self, "fake")
	cloud.url = "https://exemple.supabase.co"
	cloud.key = "k"
	cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "u-1", "email": "n@e.org", "pseudo": "Nyra"}
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var gs = m.gs
	check("partie chargée", gs != null)
	var t0 := float(gs.stats.get("playSeconds", 0.0))
	await create_timer(2.0).timeout
	var t1 := float(gs.stats.get("playSeconds", 0.0))
	check("le temps de jeu avance (%.2f → %.2f)" % [t0, t1], t1 - t0 > 0.8 and t1 - t0 < 3.5)
	var lv: Array = gs.cfg.levels
	m._transition_regen(lv[1])
	await create_timer(0.5).timeout
	check("niveau franchi compté", int(gs.stats.get("levelsCleared", 0)) == 1)
	m._transition_regen(lv[1])
	check("revenir dans un niveau déjà visité ne recompte pas", int(gs.stats.get("levelsCleared", 0)) == 1)
	check("progression envoyée (1 niveau)", posts.size() >= 1 and int(posts[posts.size() - 1].score) == 1 and str(posts[posts.size() - 1].run_id).length() == 24)
	m._on_menu("Admin")
	check("administration ouverte : partie marquée", bool(gs.stats.get("adminUsed", false)))
	cloud._transport = Callable()
	cloud.session = {}
	print("check_run_tracking : ", "OK" if fails == 0 else "%d échec(s)" % fails, "  (envois : %d)" % posts.size())
	quit(1 if fails > 0 else 0)
