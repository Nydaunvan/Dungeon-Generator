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

## Ce que mesure le classement d'une partie, d'après `params.metric` (règle du Défi de la semaine) : "levels" (niveaux franchis, défaut),
## "gold" (or gagné), "bosses" (boss vaincus) ou "clean" (niveaux franchis, mais un seul piège déclenché ramène le score à 0).
const METRICS := ["levels", "gold", "bosses", "clean"]

static func score_for(summary: Dictionary, metric: String) -> int:
	match metric:
		"gold":
			return int(summary.get("gold", 0))
		"bosses":
			return int(summary.get("bosses", 0))
		"clean":
			return int(summary.get("levelsCleared", 0)) if int(summary.get("traps", 0)) == 0 else 0
	return int(summary.get("levelsCleared", 0))

## Résultat classé d'un rejeu : {score, seconds, metrics} ou {} si la partie n'est pas valable.
static func ranking_of(res: Dictionary, params: Dictionary = {}) -> Dictionary:
	if not bool(res.get("ok", false)) or str(res.get("taint", "")) != "":
		return {}
	var s: Dictionary = res.get("summary", {})
	var metric := str(params.get("metric", "levels"))
	if not METRICS.has(metric):
		metric = "levels"
	return {"score": score_for(s, metric), "seconds": int(res.get("clock_ms", 0)) / 1000, "metrics": s}

## Unité du score d'une règle du Défi de la semaine (clé de traduction) : niveaux par défaut.
static func unit_key(metric: String) -> String:
	match metric:
		"gold":
			return "ui.challenges.unit_or"
		"bosses":
			return "ui.challenges.unit_boss"
	return "ui.challenges.unit_niveaux"

# ------------------------------------------------------------------ côté jeu

## Demande une partie classée au serveur. Renvoie {ok, run_id, seed, params} ou {ok:false, error_code…}.
## `kind` : "difficulty" (par difficulté), "hardcore_month" (Hardcore du mois : un essai par jour) ou "weekly" (Défi de la semaine : règle spéciale, essais illimités) ou "daily" (Défi du jour : petit défi quotidien, essais illimités).
## `test` : partie de TEST réservée aux super admins (le serveur refuse les autres) : hors classements, sans essai consommé.
static func start(difficulty: String, kind: String = "difficulty", test: bool = false) -> Dictionary:
	if not Cloud.is_signed_in():
		return Cloud._fail("session_expired", 401)
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + ("admin_start_ranked_run" if test else "start_ranked_run"),
		{"p_difficulty": difficulty, "p_game_version": AppVersion.number(), "p_kind": kind}, true)
	if not r.ok:
		return r
	var d: Dictionary = r.data if r.data is Dictionary else {}
	return {"ok": true, "run_id": str(d.get("run_id", "")), "seed": str(d.get("seed", "")), "params": d.get("params", {}),
		"kind": kind, "period": str(d.get("period", "")), "test": test}

## Règle et période du Défi de la semaine en cours (lecture publique) : {period, starts_at, ends_at, rule{rule_id, icon, label_fr/en, desc_fr/en, mods}, next{…}, levels, width, height, difficulty}.
static func weekly_current() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/weekly_current", {})

## Défi du jour en cours (lecture publique) : {period, starts_at, ends_at, rule{rule_id, icon, label_fr/en, desc_fr/en, mods}, levels, width, height, difficulty}.
static func daily_current() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/daily_current", {})

## État du Défi du jour du joueur connecté : {done (réussi aujourd'hui), tries (parties lancées aujourd'hui), total (jours réussis)}.
static func daily_status() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/my_daily_status", {}, true)

## Série de semaines du Défi du joueur connecté : {streak, played_this_week}.
static func my_streak() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/rpc/my_weekly_streak", {}, true)

## Hall des légendes : le champion de chaque semaine et de chaque mois clos, le plus récent d'abord.
static func hall() -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/hall_legendes?order=closed_at.desc&limit=60&select=kind,period,score,seconds,pseudo,rule_id,rule_icon,rule_fr,rule_en,frame,color")

## Nom du mode d'un donjon aléatoire d'après sa configuration : partie libre, partie classée, défi de la semaine ou hardcore du mois.
static func mode_label(cfg: Dictionary) -> String:
	var kind := str(cfg.get("rankedKind", ""))
	if kind == "weekly":
		return "📅 " + L.t("ui.hub.mode_weekly")
	if kind == "daily":
		return "🌅 " + L.t("ui.hub.mode_daily")
	if kind == "hardcore_month":
		return "🔥 " + L.t("ui.hub.mode_hardcore")
	if kind == "difficulty" or str(cfg.get("runSeed", "")) != "":
		return "🏆 " + L.t("ui.hub.mode_ranked")
	return "🎲 " + L.t("ui.hub.mode_free")

## Délai habituel entre la fin d'une période (semaine, mois) et la distribution des récompenses : la base clôt la période dès qu'aucune
## partie n'est plus en cours (2 h maximum) ni à vérifier ; sans partie en cours à l'échéance, cela prend quelques minutes.
const REWARD_DELAY_SEC := 600

## Durée maximale d'une partie classée (secondes), du lancement à la fin. Au-delà, la partie est envoyée en l'état.
## Miroir côté base : `expire_stale_ranked_runs` (2 h + 10 min de marge pour l'envoi).
const TIME_LIMIT_SEC := 7200

const PENDING_PATH := "user://ranked_pending.json"

## Lance une partie classée : le serveur donne la graine et les réglages, le donjon est celui de la configuration d'origine.
## Renvoie {ok:false, message…} en cas d'échec (hors ligne, essai du jour déjà utilisé…), sinon {ok:true} et la partie démarre.
static func launch(difficulty: String, kind: String = "difficulty", test: bool = false) -> Dictionary:
	var r: Dictionary = await start(difficulty, kind, test)
	if not r.ok:
		return r
	var cfg := config_for(Data.original_config, str(r.seed), r.params)
	if cfg.is_empty():
		return Cloud._fail("generic")
	cfg["runId"] = str(r.run_id)
	cfg["rankedKind"] = kind
	if test:
		cfg["rankedTest"] = true
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
	else:
		_clear_pending(run_id)        # envoyé, ou refusé pour de bon par le serveur (partie expirée…) : plus rien à renvoyer
	return r

static func _save_pending(run_id: String, log: Array) -> void:
	var f := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"run_id": run_id, "log": log}))

## Supprime le journal en attente (de cette partie seulement, si `run_id` est donné).
static func _clear_pending(run_id: String = "") -> void:
	if not FileAccess.file_exists(PENDING_PATH):
		return
	if run_id != "":
		var d = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
		if d is Dictionary and str(d.get("run_id", "")) != run_id:
			return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))

# ------------------------------------------------------------------ reprise après plantage / fermeture brutale
# Pendant une partie classée, le journal est recopié dans user://ranked_pending.json (au plus toutes les 15 s, et à la fermeture de la
# fenêtre). Si le jeu plante ou se ferme sans avoir envoyé la partie, `flush_pending` l'envoie au prochain lancement : le serveur
# l'accepte tant que la partie a moins de 2 h 10, et le score est celui de l'abandon (« Terminer ici » : niveaux déjà franchis).

const CHECKPOINT_SEC := 15.0
static var _live_id := ""              ## partie classée en cours dans cette session (jamais renvoyée par flush_pending)
static var _ck_ms := -1000000
static var _ck_n := -1

static func checkpoint(gs: GameState, force: bool = false) -> void:
	var run_id := str(gs.cfg.get("runId", ""))
	if run_id == "" or not RunLog.ranked() or gs.run_log.is_empty() or bool(gs.stats.get("rankedSent", false)):
		return
	_live_id = run_id
	if not RunLog.is_clean():
		_clear_pending(run_id)          # partie souillée : jamais classable, rien à récupérer
		return
	var n := gs.run_log.size()
	var now := Time.get_ticks_msec()
	if not force and (n == _ck_n or now - _ck_ms < int(CHECKPOINT_SEC * 1000.0)):
		return
	_ck_n = n
	_ck_ms = now
	_save_pending(run_id, gs.run_log)

## Les nombres entiers relus d'un fichier JSON sont des flottants : on les remet en entiers avant l'envoi.
static func _ints(v: Variant) -> Variant:
	if v is Array:
		return (v as Array).map(func(x): return _ints(x))
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 9.0e15:
		return int(v)
	return v

## Renvoie le journal resté en attente (envoi échoué hors ligne), si un compte est connecté.
static func flush_pending() -> void:
	if not Cloud.is_signed_in() or not FileAccess.file_exists(PENDING_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	if d is Dictionary and str(d.get("run_id", "")) == _live_id and _live_id != "":
		return                          # c'est la partie en cours dans cette session : elle s'enverra à sa fin
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))
	if d is Dictionary and d.get("log") is Array and str(d.get("run_id", "")) != "":
		_send(str(d.run_id), _ints(d.log))

## Les parties classées du joueur connecté (hors tests), les plus récentes d'abord : état, score, temps, jour de Paris.
static func my_runs(limit: int = 30) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/ranked_runs?player_id=eq.%s&test=eq.false&order=started_at.desc&limit=%d&select=id,difficulty,kind,period,day,status,score,seconds,started_at,submitted_at,reject_reason" % [Cloud.user_id(), limit], null, true)

## Classement vérifié d'une difficulté (vide tant que rien n'est vérifié).
static func board(difficulty: String) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/classement_difficulte?difficulty=eq.%s&order=score.desc,seconds.asc,achieved_at.asc&limit=100&select=pseudo,score,seconds,metrics,title_fr,title_en,frame,color,level" % difficulty.uri_encode())

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
