extends SceneTree
## Parcours d'une partie classée côté jeu, SANS réseau (faux transport) : démarrage par le serveur (graine reçue), partie classée,
## envoi unique du journal, journal gardé hors ligne puis renvoyé, « repartir de zéro » = partie libre.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_ranked_flow.gd

var fails := 0
var calls: Array = []
var queue: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func fake(method: int, full_url: String, headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"method": method, "url": full_url, "body": body})
	if queue.is_empty():
		return resp(500, {"error": "file vide"})
	return queue.pop_front()

func _init() -> void:
	await process_frame
	var Cloud = root.get_node("Cloud")
	var Rep: GDScript = load("res://scripts/core/replayer.gd")
	var RR: GDScript = load("res://scripts/core/ranked_run.gd")
	var RL: GDScript = load("res://scripts/rules/run_log.gd")
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra"}

	# --- démarrage par le serveur
	queue = [resp(200, {"run_id": "run-abc", "seed": "aaaabbbbccccddddeeeeffff00001111", "params": {"levels": 1, "width": 13, "height": 11, "difficulty": "hardcore", "mods": []}, "period": "2026-10"})]
	var r: Dictionary = await RR.launch("hardcore", "hardcore_month")
	check("le serveur démarre la partie", bool(r.ok))
	check("la requête appelle start_ranked_run avec le mode", calls.size() == 1 and str(calls[0].url).ends_with("/rpc/start_ranked_run") and str(calls[0].body).contains("hardcore_month"))
	var m: Node = null
	for i in 900:
		await process_frame
		m = Rep.main_of(self)
		if m != null and not m.get("_loading") and m.get("level_node") != null:
			break
	check("la scène de jeu est prête", m != null)
	if m == null:
		quit(1)
		return
	var gs = m.gs
	check("graine du serveur", gs.run_seed == "aaaabbbbccccddddeeeeffff00001111")
	check("partie classée", RL.ranked())
	check("identifiant de partie conservé", str(gs.cfg.get("runId", "")) == "run-abc")
	check("difficulté hardcore", str(gs.cfg.get("genDifficulty", "")) == "hardcore")
	for k in 4:
		m._on_command("turn_right")
		for j in 20:
			await process_frame
	check("le journal se remplit", gs.run_log.size() >= 1)

	# --- envoi unique
	queue = [resp(204)]
	calls.clear()
	m._end_ranked_run()
	for j in 10:
		await process_frame
	check("journal envoyé", calls.size() == 1 and str(calls[0].url).ends_with("/rpc/submit_ranked_run") and str(calls[0].body).contains("run-abc") and str(calls[0].body).contains("p_log"))
	m._end_ranked_run()
	for j in 5:
		await process_frame
	check("jamais envoyé deux fois", calls.size() == 1)

	# --- hors ligne : journal gardé puis renvoyé
	var off := {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0, "body": PackedByteArray()}
	queue = [off]
	calls.clear()
	var s: Dictionary = await RR._send("run-hors-ligne", [[0, "m", 1]])
	check("hors ligne : échec", not s.ok)
	check("journal gardé", FileAccess.file_exists(RR.PENDING_PATH))
	queue = [resp(204)]
	calls.clear()
	RR.flush_pending()
	for j in 10:
		await process_frame
	check("journal renvoyé", calls.size() == 1 and str(calls[0].body).contains("run-hors-ligne"))
	check("fichier en attente supprimé", not FileAccess.file_exists(RR.PENDING_PATH))

	# --- repartir de zéro : partie libre
	m._restart()
	var m2: Node = null
	for i in 900:
		await process_frame
		var c = Rep.main_of(self)
		if c != null and c != m and not c.get("_loading") and c.get("level_node") != null:
			m2 = c
			break
	check("nouvelle partie lancée", m2 != null)
	if m2 != null:
		check("la nouvelle partie est libre", m2.gs.run_seed == "" and str(m2.gs.cfg.get("runId", "")) == "" and not RL.ranked())

	# --- refus du serveur : message traduit
	queue = [resp(400, {"message": "essai_du_jour_utilise"})]
	var r2: Dictionary = await RR.start("hardcore", "hardcore_month")
	check("essai du jour déjà utilisé : refus traduit", not r2.ok and r2.error_code == "essai_du_jour_utilise" and str(r2.message) != "")
	print("check_ranked_flow : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
