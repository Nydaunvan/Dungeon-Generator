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
static func start(difficulty: String) -> Dictionary:
	if not Cloud.is_signed_in():
		return Cloud._fail("session_expired", 401)
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/start_ranked_run",
		{"p_difficulty": difficulty, "p_game_version": AppVersion.number()}, true)
	if not r.ok:
		return r
	var d: Dictionary = r.data if r.data is Dictionary else {}
	return {"ok": true, "run_id": str(d.get("run_id", "")), "seed": str(d.get("seed", "")), "params": d.get("params", {})}

## Envoie le journal de la partie classée en cours (une seule fois par partie). Sans compte ou partie souillée : ne fait rien.
static func submit(gs: GameState) -> Dictionary:
	if not RunLog.is_clean() or gs.run_log.is_empty() or str(gs.cfg.get("runId", "")) == "" or not Cloud.is_signed_in():
		return {"ok": false, "skipped": true}
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/submit_ranked_run",
		{"p_run_id": str(gs.cfg.get("runId", "")), "p_log": gs.run_log}, true)

## Classement vérifié d'une difficulté (vide tant que rien n'est vérifié).
static func board(difficulty: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/classement_difficulte?difficulty=eq.%s&order=score.desc,seconds.asc,achieved_at.asc&limit=100&select=pseudo,score,seconds,metrics" % difficulty.uri_encode())
