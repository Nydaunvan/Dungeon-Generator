class_name Challenges
extends RefCounted
## Défis en ligne : liste des défis ouverts, classements, envoi du score d'une partie en donjon aléatoire.
## Tout passe par l'autoload Cloud (compte facultatif) ; sans compte, sans réseau ou sans configuration, rien n'est envoyé et le jeu
## reste jouable. Les scores d'un défi « declared » sont DÉCLARÉS par le jeu (pas de rejeu possible pour un donjon aléatoire) :
## la base les borne par des contrôles de plausibilité (voir supabase/migrations/20261010000100_defis_declares.sql).
##
## Suivi de partie (dans `gs.stats`, donc sauvegardé avec la partie) :
##   runId         identifiant de la partie (une ligne de classement par partie, mise à jour au fil de la progression)
##   levelsCleared niveaux franchis (escalier pris pour la première fois + sortie finale d'un donjon), expéditions comprises
##   playSeconds   temps de jeu écoulé (secondes)
##   adminUsed     vrai dès que l'administration a été ouverte dans la partie : la partie n'est plus envoyée au classement

const PENDING_PATH := "user://challenge_pending.json"
const CACHE_SECONDS := 600.0
const MIN_SECONDS_PER_UNIT := 10     ## doit rester cohérent avec scores_garde (base de données)

## Unités de score connues → texte traduit (une autre unité est affichée telle quelle).
const UNIT_KEYS := {"niveaux": "ui.challenges.unit_niveaux", "points": "ui.challenges.unit_points"}

static var _cache: Array = []
static var _cache_at: float = -1.0e9
static var _busy := false
static var _queued: Dictionary = {}

static func _now() -> float:
	return Time.get_unix_time_from_system()

static func _iso_now() -> String:
	return Time.get_datetime_string_from_system(true)     # « 2026-10-10T08:30:00 » (UTC)

# ------------------------------------------------------------------ lecture

## Titre et description d'un défi dans la langue courante (le français vient de la base, l'anglais de `rules.en`).
static func title_of(ch: Dictionary) -> String:
	return _localized(ch, "title")

static func description_of(ch: Dictionary) -> String:
	return _localized(ch, "description")

static func _localized(ch: Dictionary, field: String) -> String:
	if Data.lang == "en":
		var rules: Dictionary = ch.get("rules") if ch.get("rules") is Dictionary else {}
		var en: Dictionary = rules.get("en") if rules.get("en") is Dictionary else {}
		if str(en.get(field, "")) != "":
			return str(en[field])
	return str(ch.get(field, ""))

## Libellé de l'unité du score (« niveaux », « points »…), traduit.
static func unit_label(unit: String) -> String:
	return L.t(UNIT_KEYS[unit]) if UNIT_KEYS.has(unit) else unit

## Défis ouverts, du plus prioritaire au moins prioritaire. Résultat : {ok, data: Array de défis, message, offline…}.
static func list(force: bool = false) -> Dictionary:
	if not force and not _cache.is_empty() and _now() - _cache_at < CACHE_SECONDS:
		return {"ok": true, "status": 200, "data": _cache, "error_code": "", "message": "", "offline": false}
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_GET,
		"/rest/v1/challenges?select=id,slug,title,theme,description,mode,unit,rules,starts_at,ends_at&order=sort_order.asc,starts_at.asc&limit=50")
	if not r.ok:
		return r
	var now_iso := _iso_now()
	var open: Array = []
	for ch in (r.data if r.data is Array else []):
		if not (ch is Dictionary):
			continue
		var ends := str(ch.get("ends_at", "")) if ch.get("ends_at") != null else ""
		var starts := str(ch.get("starts_at", "")).substr(0, 19)
		if starts > now_iso:
			continue
		if ends != "" and ends.substr(0, 19) <= now_iso:
			continue
		open.append(ch)
	_cache = open
	_cache_at = _now()
	r["data"] = open
	return r

## Classement d'un défi : {ok, data: Array de {pseudo, player_id, score, seconds, details, verified}}.
static func board(challenge_id: String, limit: int = 100) -> Dictionary:
	return await Cloud.request(HTTPClient.METHOD_GET,
		"/rest/v1/classement?challenge_id=eq.%s&select=pseudo,player_id,score,seconds,details,verified&order=score.desc,seconds.asc.nullslast,achieved_at.asc&limit=%d"
		% [challenge_id, limit])

## « 1:05:09 » ou « 12:30 ».
static func format_time(seconds: int) -> String:
	if seconds < 0:
		return "–"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]

# ------------------------------------------------------------------ suivi de la partie

static func _new_id() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(12).hex_encode()

## Mises à jour de statistiques de partie appelées par le jeu.
static func track_level_cleared(gs: GameState) -> void:
	gs.stats["levelsCleared"] = int(gs.stats.get("levelsCleared", 0)) + 1

static func track_time(gs: GameState, delta: float) -> void:
	gs.stats["playSeconds"] = float(gs.stats.get("playSeconds", 0.0)) + minf(delta, 1.0)

static func mark_admin_used(gs: GameState) -> void:
	gs.stats["adminUsed"] = true

## Données à envoyer pour la partie en cours. Vide si la partie ne concerne pas les défis.
static func run_info(gs: GameState, origin: String) -> Dictionary:
	if origin != "random" or bool(gs.stats.get("adminUsed", false)):
		return {}
	if int(gs.stats.get("levelsCleared", 0)) <= 0:
		return {}
	if str(gs.stats.get("runId", "")) == "":
		gs.stats["runId"] = _new_id()
	var dims: Dictionary = gs.cfg.get("genDims") if gs.cfg.get("genDims") is Dictionary else {}
	return {
		"run_id": str(gs.stats["runId"]),
		"metrics": {"levelsCleared": int(gs.stats.get("levelsCleared", 0))},
		"seconds": int(gs.stats.get("playSeconds", 0.0)),
		"details": {
			"expeditions": gs.run_number,
			"difficulty": str(gs.cfg.get("genDifficulty", "")),
			"kills": int(gs.stats.get("monstersKilled", 0)),
			"levels": int(dims.get("numLevels", 0)),
		},
	}

# ------------------------------------------------------------------ envoi

## Envoie la progression de la partie à tous les défis ouverts qui la concernent. Sans compte connecté : ne fait rien.
## Une seule requête à la fois : si un envoi est en cours, la dernière progression attend son tour.
## Hors ligne : la progression est gardée dans user://challenge_pending.json et renvoyée à la prochaine occasion.
static func submit_run(info: Dictionary) -> Dictionary:
	if info.is_empty() or not Cloud.is_signed_in() or not Cloud.is_configured():
		return {"ok": false, "skipped": true}
	if _busy:
		_queued = info
		return {"ok": false, "skipped": true, "queued": true}
	_busy = true
	var r: Dictionary = await _send(info)
	_busy = false
	if not r.ok and (bool(r.get("offline", false)) or int(r.get("status", 0)) >= 500):
		_save_pending(info)
	elif r.ok:
		_clear_pending()
	if not _queued.is_empty():
		var next := _queued
		_queued = {}
		submit_run(next)
	return r

static func _send(info: Dictionary) -> Dictionary:
	var lst: Dictionary = await list()
	if not lst.ok:
		return lst
	var sent := 0
	var last: Dictionary = {"ok": true, "status": 200, "data": null, "error_code": "", "message": "", "offline": false}
	for ch in lst.data:
		if str(ch.get("mode", "")) != "declared":
			continue
		var rules: Dictionary = ch.get("rules") if ch.get("rules") is Dictionary else {}
		if str(rules.get("origin", "random")) != "random":
			continue
		var score := int((info.get("metrics", {}) as Dictionary).get(str(rules.get("metric", "")), 0))
		if score <= 0:
			continue
		var body := {
			"challenge_id": str(ch.id), "player_id": Cloud.user_id(), "run_id": str(info.run_id),
			"score": score, "seconds": maxi(int(info.get("seconds", 0)), 0), "details": info.get("details", {}),
			"game_version": AppVersion.number(),
		}
		last = await Cloud.request(HTTPClient.METHOD_POST, "/rest/v1/scores?on_conflict=challenge_id,player_id,run_id", body, true,
			PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
		if not last.ok:
			return last
		sent += 1
	last["sent"] = sent
	return last

static func _save_pending(info: Dictionary) -> void:
	var f := FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(info))

static func _clear_pending() -> void:
	if FileAccess.file_exists(PENDING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))

## Renvoie la dernière progression restée en attente (envoi échoué hors ligne), si un compte est connecté.
static func flush_pending() -> void:
	if not Cloud.is_signed_in() or not FileAccess.file_exists(PENDING_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PENDING_PATH))
	if d is Dictionary and str(d.get("run_id", "")) != "":
		submit_run(d)
	else:
		_clear_pending()
