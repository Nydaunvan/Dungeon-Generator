class_name RankedRun
extends RefCounted
## Partie classée par difficulté. Le serveur tire la graine et fixe les réglages (`start_ranked_run`) ; le jeu envoie le journal à la
## fin (`submit_ranked_run`) ; le vérificateur rejoue et classe. `config_for` est PARTAGÉ par le jeu et le vérificateur : le donjon
## du rejeu est ainsi exactement celui du joueur.

const DIFFICULTIES := ["easy", "normal", "hard", "hardcore"]

## Configuration de départ d'une partie classée (donjon de la configuration d'origine, jamais celle modifiée par le joueur).
## Renvoie {} si les réglages sont invalides.
static func config_for(base: Dictionary, seed_text: String, params: Dictionary) -> Dictionary:
	var diff := str(params.get("difficulty", ""))
	var levels := int(params.get("levels", 0))
	var width := int(params.get("width", 0))
	var height := int(params.get("height", 0))
	if not DIFFICULTIES.has(diff) or levels < 1 or levels > 12 or width < 7 or width > 40 or height < 7 or height > 40 or seed_text == "":
		return {}
	var mods: Array = []
	for id in params.get("mods", []):
		mods.append(str(id))
	var cfg := DungeonGenerator.build_config(base, levels, width, height, diff, mods, 1, Seeds.from_text(seed_text))
	cfg["runSeed"] = seed_text
	return cfg

## Résultat classé d'un rejeu : {score, seconds, metrics} ou {} si la partie n'est pas valable.
static func ranking_of(res: Dictionary) -> Dictionary:
	if not bool(res.get("ok", false)) or str(res.get("taint", "")) != "":
		return {}
	var s: Dictionary = res.get("summary", {})
	return {"score": int(s.get("levelsCleared", 0)), "seconds": int(res.get("clock_ms", 0)) / 1000, "metrics": s}

# ------------------------------------------------------------------ côté jeu

## Demande une partie classée au serveur. Renvoie {ok, run_id, seed, params} ou {ok:false, error_code…}.
## `kind` : "difficulty" (par difficulté) ou "hardcore_month" (Hardcore du mois : un essai par jour).
static func start(difficulty: String, kind: String = "difficulty") -> Dictionary:
	if not Cloud.is_signed_in():
		return Cloud._fail("session_expired", 401)
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/start_ranked_run",
		{"p_difficulty": difficulty, "p_game_version": AppVersion.number(), "p_kind": kind}, true)
	if not r.ok:
		return r
	var d: Dictionary = r.data if r.data is Dictionary else {}
	return {"ok": true, "run_id": str(d.get("run_id", "")), "seed": str(d.get("seed", "")), "params": d.get("params", {}),
		"kind": kind, "period": str(d.get("period", ""))}

const PENDING_PATH := "user://ranked_pending.json"

## Lance une partie classée : le serveur donne la graine et les réglages, le donjon est celui de la configuration d'origine.
## Renvoie {ok:false, message…} en cas d'échec (hors ligne, essai du jour déjà utilisé…), sinon {ok:true} et la partie démarre.
static func launch(difficulty: String, kind: String = "difficulty") -> Dictionary:
	var r: Dictionary = await start(difficulty, kind)
	if not r.ok:
		return r
	var cfg := config_for(Data.original_config, str(r.seed), r.params)
	if cfg.is_empty():
		return Cloud._fail("generic")
	cfg["runId"] = str(r.run_id)
	cfg["rankedKind"] = kind
	Data.launch(cfg, "random")
	return r

## Envoie le journal de la partie classée en cours (une seule fois par partie). Sans compte ou partie souillée : ne fait rien.
## Hors ligne : le journal est gardé dans user://ranked_pending.json et renvoyé à la prochaine occasion (`flush_pending`).
static func submit(gs: GameState) -> Dictionary:
	var run_id := str(gs.cfg.get("runId", ""))
	if run_id == "" or not RunLog.is_clean() or gs.run_log.is_empty() or bool(gs.stats.get("rankedSent", false)):
		return {"ok": false, "skipped": true}
	gs.stats["rankedSent"] = true
	return await _send(run_id, gs.run_log.duplicate(true))

static func _send(run_id: String, log: Array) -> Dictionary:
	if not Cloud.is_signed_in():
		_save_pending(run_id, log)
		return {"ok": false, "skipped": true}
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/submit_ranked_run", {"p_run_id": run_id, "p_log": log}, true)
	if not r.ok and (bool(r.get("offline", false)) or int(r.get("status", 0)) >= 500):
		_save_pending(run_id, log)
	return r

static func _save_pending(run_id: String, log: Array) -> void:
	var f := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"run_id": run_id, "log": log}))

## Renvoie le journal resté en attente (envoi échoué hors ligne), si un compte est connecté.
static func flush_pending() -> void:
	if not Cloud.is_signed_in() or not FileAccess.file_exists(PENDING_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))
	if d is Dictionary and d.get("log") is Array and str(d.get("run_id", "")) != "":
		_send(str(d.run_id), d.log)

## Classement vérifié d'une difficulté (vide tant que rien n'est vérifié).
static func board(difficulty: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/classement_difficulte?difficulty=eq.%s&order=score.desc,seconds.asc,achieved_at.asc&limit=100&select=pseudo,score,seconds,metrics" % difficulty.uri_encode())

## Classement du mois (Hardcore) : pseudo, score, temps, titre, cadre, couleur et niveau de compte.
static func period_board(kind: String, period: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/classement_periode?kind=eq.%s&period=eq.%s&order=score.desc,seconds.asc,achieved_at.asc&limit=100&select=pseudo,score,seconds,title_fr,title_en,frame,color,level" % [kind.uri_encode(), period.uri_encode()])

## Badges du catalogue et badges obtenus par le joueur connecté.
static func badges() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/badges?order=sort_order.asc&select=*")

static func my_badges() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/player_badges?player_id=eq.%s&select=badge_id,period,earned_at" % Cloud.user_id(), null, true)

static func my_xp() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/account_xp?player_id=eq.%s&select=xp,level" % Cloud.user_id())

## Équipe titre, cadre et couleur (identifiants de badges possédés, "" = aucun).
static func equip(title: String, frame: String, color: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/equip_cosmetics",
		{"p_title": title if title != "" else null, "p_frame": frame if frame != "" else null, "p_color": color if color != "" else null}, true)
