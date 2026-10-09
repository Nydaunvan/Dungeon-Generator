extends Node
## Vérifie les défis en ligne SANS réseau (faux transport) : liste des défis ouverts, classement, suivi de partie, envoi du score
## (corps, en-têtes, hors ligne puis renvoi) et fenêtre « Défis ». Option `-- <png>` : capture de la fenêtre (affichage requis).
## Lancer : godot --headless --path . res://tools/check_challenges.tscn

var fails := 0
var calls: Array = []
var offline := false
var board_rows: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"method": method, "url": full_url, "headers": headers, "body": body})
	if offline:
		return {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()}
	if "/rest/v1/challenges" in full_url:
		return resp(200, [
			{"id": "c-open", "slug": "le-plus-profond", "title": "Le plus profond", "theme": "Exploration", "description": "Qui ira le plus loin ?", "mode": "declared",
				"unit": "niveaux", "rules": {"metric": "levelsCleared", "origin": "random", "en": {"title": "The Deepest", "description": "Who goes furthest?"}},
				"starts_at": "2020-01-01T00:00:00+00:00", "ends_at": null},
			{"id": "c-ended", "slug": "ancien", "title": "Ancien", "theme": "x", "description": "", "mode": "declared", "unit": "points", "rules": {},
				"starts_at": "2020-01-01T00:00:00+00:00", "ends_at": "2021-01-01T00:00:00+00:00"},
			{"id": "c-future", "slug": "futur", "title": "Futur", "theme": "x", "description": "", "mode": "declared", "unit": "points", "rules": {},
				"starts_at": "2099-01-01T00:00:00+00:00", "ends_at": null},
			{"id": "c-replay", "slug": "replay", "title": "Rejeu", "theme": "x", "description": "", "mode": "replay", "unit": "points", "rules": {},
				"starts_at": "2020-01-01T00:00:00+00:00", "ends_at": null},
		])
	if "/rest/v1/classement" in full_url:
		return resp(200, board_rows)
	if "/rest/v1/scores" in full_url:
		return resp(201)
	return resp(500, {})

func header_of(call: Dictionary, name: String) -> String:
	for h in call.headers:
		if h.begins_with(name + ": "):
			return h.substr(name.length() + 2)
	return ""

func make_gs(origin_levels: int = 3) -> GameState:
	var gs := GameState.new()
	gs.cfg = {"genDifficulty": "hard", "genDims": {"numLevels": 4, "width": 13, "height": 11}}
	gs.run_number = 2
	gs.stats = {"monstersKilled": 7, "levelsCleared": origin_levels, "playSeconds": 321.7}
	return gs

func _ready() -> void:
	Cloud._transport = Callable(self, "fake")
	Cloud.url = "https://exemple.supabase.co"
	Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "u-1", "email": "n@e.org", "pseudo": "Nyra"}
	if FileAccess.file_exists(Challenges.PENDING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Challenges.PENDING_PATH))

	# --- liste : seuls les défis ouverts, dans la langue courante
	var r: Dictionary = await Challenges.list(true)
	check("liste : 2 défis ouverts (ni terminé ni futur)", r.ok and (r.data as Array).size() == 2)
	check("liste : titre en français", Challenges.title_of(r.data[0]) == "Le plus profond")
	var lang := Data.lang
	Data.lang = "en"
	check("liste : titre en anglais", Challenges.title_of(r.data[0]) == "The Deepest" and Challenges.description_of(r.data[0]) == "Who goes furthest?")
	Data.lang = lang
	check("lecture sans jeton (public)", header_of(calls[0], "Authorization") == "")

	# --- suivi de partie
	var gs := make_gs()
	check("donjon aléatoire : informations de partie", Challenges.run_info(gs, "random").get("metrics", {}).get("levelsCleared", 0) == 3)
	check("un donjon non aléatoire n'envoie rien", Challenges.run_info(gs, "custom").is_empty() and Challenges.run_info(gs, "original").is_empty())
	var info := Challenges.run_info(gs, "random")
	check("identifiant de partie créé et conservé", str(info.run_id).length() == 24 and Challenges.run_info(gs, "random").run_id == info.run_id)
	check("détails de la partie", info.details.expeditions == 2 and info.details.difficulty == "hard" and info.details.levels == 4 and info.seconds == 321)
	Challenges.mark_admin_used(gs)
	check("administration ouverte : plus d'envoi", Challenges.run_info(gs, "random").is_empty())
	check("aucun niveau franchi : plus d'envoi", Challenges.run_info(make_gs(0), "random").is_empty())
	var gs2 := make_gs(0)
	Challenges.track_level_cleared(gs2)
	Challenges.track_time(gs2, 0.5)
	Challenges.track_time(gs2, 30.0)    # image très longue (pause) : plafonnée à 1 s
	check("compteurs de partie (image très longue plafonnée à 1 s)", int(gs2.stats.levelsCleared) == 1 and absf(float(gs2.stats.playSeconds) - 323.2) < 0.01)

	# --- envoi du score
	calls.clear()
	var sent: Dictionary = await Challenges.submit_run(info)
	check("envoi réussi : une ligne pour le défi déclaré", sent.ok and int(sent.get("sent", 0)) == 1)
	var post: Dictionary = calls[calls.size() - 1]
	check("envoi : requête POST sur scores avec fusion", post.method == HTTPClient.METHOD_POST and "/rest/v1/scores?on_conflict=challenge_id,player_id,run_id" in post.url
		and header_of(post, "Prefer") == "resolution=merge-duplicates,return=minimal")
	var body: Dictionary = JSON.parse_string(post.body)
	check("envoi : contenu", body.challenge_id == "c-open" and body.player_id == "u-1" and int(body.score) == 3 and int(body.seconds) == 321
		and body.run_id == info.run_id and body.details.difficulty == "hard" and body.game_version == AppVersion.number())
	check("envoi avec le jeton du joueur", header_of(post, "Authorization") == "Bearer A")

	# --- sans compte : aucun envoi
	var saved := Cloud.session
	Cloud.session = {}
	calls.clear()
	var none: Dictionary = await Challenges.submit_run(info)
	check("sans compte : rien envoyé", bool(none.get("skipped", false)) and calls.is_empty())
	Cloud.session = saved

	# --- hors ligne : progression gardée puis renvoyée
	offline = true
	Challenges._cache = []
	var off: Dictionary = await Challenges.submit_run(info)
	check("hors ligne : échec propre", not off.ok and off.offline)
	check("hors ligne : progression gardée", FileAccess.file_exists(Challenges.PENDING_PATH))
	offline = false
	calls.clear()
	Challenges.flush_pending()
	await get_tree().create_timer(0.3).timeout
	check("renvoi de la progression en attente", calls.any(func(c): return "/rest/v1/scores" in c.url) and not FileAccess.file_exists(Challenges.PENDING_PATH))

	# --- affichage
	check("format du temps", Challenges.format_time(65) == "1:05" and Challenges.format_time(3725) == "1:02:05")
	board_rows = [
		{"pseudo": "Nyra", "player_id": "u-9", "score": 12, "seconds": 2400, "verified": false, "details": {"expeditions": 3, "difficulty": "hardcore", "kills": 88}},
		{"pseudo": "Bob", "player_id": "u-2", "score": 9, "seconds": 1800, "verified": false, "details": {"expeditions": 2, "difficulty": "normal", "kills": 40}},
	]
	for i in 12:
		board_rows.append({"pseudo": "Joueur%d" % i, "player_id": "p-%d" % i, "score": 8 - i / 2, "seconds": 900 + i * 60, "verified": false, "details": {}})
	board_rows.insert(11, {"pseudo": "Nyra", "player_id": "u-1", "score": 3, "seconds": 321, "verified": false, "details": {"expeditions": 2, "difficulty": "hard", "kills": 7}})
	var layer := CanvasLayer.new()
	add_child(layer)
	var launched := [false]
	var m := ChallengesModal.open(layer, func(): launched[0] = true)
	await get_tree().create_timer(0.6).timeout
	var texts: Array = []
	_collect(layer, texts)
	check("fenêtre : titre du défi affiché", texts.any(func(t): return "Le plus profond" in t))
	check("fenêtre : ligne du joueur (rang 12) affichée après le séparateur", texts.has("12") and texts.has("…"))
	check("fenêtre : note « déclarés »", texts.any(func(t): return "non vérifiés" in t))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(args[0])
	m._launch()
	check("« Lancer » ferme la fenêtre et déclenche la suite", launched[0])

	Cloud._transport = Callable()
	Cloud.session = {}
	print("check_challenges : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _collect(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect(c, out)
