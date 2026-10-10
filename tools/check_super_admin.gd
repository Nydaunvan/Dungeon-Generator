extends SceneTree
## Menu « Super admin » avec un faux serveur qui se comporte comme le vrai : les fonctions admin répondent `acces_refuse` aux comptes
## qui n'ont pas le rôle. Vérifie : le bouton n'apparaît que pour un super admin, les quatre onglets, les parties de test (fonction
## dédiée, jamais `start_ranked_run`), la purge, et que le jeu ne tente rien d'interdit.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_super_admin.gd

var fails := 0
var calls: Array = []
var is_admin := true
var tail := ""

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	var body := "" if data == null else JSON.stringify(data)
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": body.to_utf8_buffer()}

func denied() -> Dictionary:
	return resp(400, {"code": "P0001", "message": "acces_refuse", "details": null, "hint": null})

const OVERVIEW := {
	"generated_at": "2026-10-10T16:00:00.123+00:00",
	"players": {"total": 12, "new_24h": 2, "new_7d": 5, "active_24h": 3, "active_7d": 7, "admins": 1},
	"runs": {"total": 40, "tests": 4, "today": 6,
		"by_status": {"verified": 30, "rejected": 2, "submitted": 3, "started": 4, "expired": 1},
		"by_mode": [{"mode": "easy", "runs": 10, "verified": 9, "avg_score": 2.35, "best_score": 3, "avg_seconds": 420},
			{"mode": "hardcore_month", "runs": 5, "verified": 4, "avg_score": 3.0, "best_score": 5, "avg_seconds": 3700}],
		"by_version": [{"version": "1.33.0", "runs": 40}],
		"reject_reasons": [{"reason": "version_non_rejouable", "n": 2}]},
	"queue": {"submitted": 3, "oldest_seconds": 125, "in_progress": 1},
	"hardcore": {"period": "2026-10", "attempts_today": 2, "attempts_month": 5, "players_month": 4, "verified_month": 4, "best_month": 5, "closed_at": null},
	"rewards": {"xp_total": 9000, "xp_entries": 30, "badges_awarded": 6, "badges": [{"badge": "hc_participant", "n": 4}], "cosmetics_equipped": 2},
	"other": {"dungeons": 3, "dungeons_public": 2, "dungeon_reports": 1, "challenges": 1, "declared_scores": 5, "replay_runs": 0},
}

func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"url": full_url, "body": body})
	if full_url.contains("/auth/v1/token"):
		return resp(200, {"access_token": "t2", "refresh_token": "r2", "expires_in": 3600, "user": {"id": "u-1", "email": "a@b.fr"}})
	if full_url.contains("/rest/v1/profiles"):
		return resp(200, [{"pseudo": "Nyra"}])
	if full_url.ends_with("/rpc/is_super_admin"):
		return resp(200, is_admin)
	if full_url.contains("/rpc/admin_"):
		if not is_admin:
			return denied()
		if full_url.ends_with("/rpc/admin_overview"):
			return resp(200, OVERVIEW)
		if full_url.ends_with("/rpc/admin_players"):
			var q: String = str(JSON.parse_string(body).get("p_search", ""))
			var all := [
				{"id": "u-1", "pseudo": "Nyra", "created_at": "2026-10-09T17:00:00+00:00", "xp": 450, "level": 3, "runs": 5, "verified": 4, "best_score": 3, "last_run_at": "2026-10-10T15:00:00+00:00", "badges": 2, "admin": true},
				{"id": "u-2", "pseudo": "Bob", "created_at": "2026-10-10T10:00:00+00:00", "xp": 0, "level": 1, "runs": 0, "verified": 0, "best_score": null, "last_run_at": null, "badges": 0, "admin": false}]
			return resp(200, all.filter(func(p): return q == "" or str(p.pseudo).to_lower().contains(q.to_lower())))
		if full_url.ends_with("/rpc/admin_runs"):
			return resp(200, [
				{"id": "r1", "pseudo": "Nyra", "difficulty": "easy", "kind": "difficulty", "period": null, "day": null, "status": "verified", "score": 2, "seconds": 300, "game_version": "1.33.0", "reject_reason": null, "started_at": "2026-10-10T15:00:00+00:00", "submitted_at": null, "verified_at": null, "test": true, "actions": 120},
				{"id": "r2", "pseudo": "Bob", "difficulty": "hardcore", "kind": "hardcore_month", "period": "2026-10", "day": "2026-10-10", "status": "rejected", "score": null, "seconds": null, "game_version": "1.2.0", "reject_reason": "version_non_rejouable", "started_at": "2026-10-10T14:00:00+00:00", "submitted_at": null, "verified_at": null, "test": false, "actions": null}])
		if full_url.ends_with("/rpc/admin_purge_tests"):
			return resp(200, 3)
		if full_url.ends_with("/rpc/admin_start_ranked_run"):
			return resp(200, {"run_id": "11111111-1111-1111-1111-111111111111", "seed": "a".repeat(32), "params": {"levels": 3, "width": 13, "height": 11, "difficulty": "easy", "mods": []}, "test": true})
	return resp(404, {"message": "inconnu"})

func labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		labels(c, out)
	return out

func has_text(n: Node, part: String) -> bool:
	return labels(n).any(func(x): return str(x).contains(part))

func settle(frames: int = 30) -> void:
	for i in frames:
		await process_frame

func _init() -> void:
	await process_frame
	var Cloud = root.get_node("Cloud")
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra", "email": "a@b.fr"}
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var SA: GDScript = load("res://scripts/core/super_admin.gd")
	var SM: GDScript = load("res://scripts/ui/super_admin_modal.gd")
	var AM: GDScript = load("res://scripts/ui/account_modal.gd")
	var RR: GDScript = load("res://scripts/core/ranked_run.gd")

	# --- le bouton n'apparaît que pour un super admin (réponse du serveur)
	is_admin = false
	SA.forget()
	var a1 = AM.open(host)
	await settle()
	check("compte normal : pas de bouton Super admin", not has_text(a1._modal, "Super admin"))
	check("compte normal : le serveur a bien été interrogé", calls.any(func(c): return str(c.url).ends_with("/rpc/is_super_admin")))
	a1._modal.close()
	check("compte normal : un appel admin direct est refusé", not (await SA.overview()).ok and (await SA.overview()).error_code == "acces_refuse")
	check("compte normal : message d'erreur traduit", str((await SA.overview()).message).contains("Accès refusé"))
	var rs: Dictionary = await RR.start("easy", "difficulty", true)
	check("compte normal : une partie de test est refusée", not rs.ok)

	is_admin = true
	SA.forget()
	check("pas encore connu", SA.cached() == -1)
	var a2 = AM.open(host)
	await settle()
	check("super admin : bouton affiché", has_text(a2._modal, "Super admin"))
	check("réponse mémorisée", SA.cached() == 1)
	a2._modal.close()

	# --- onglet Tests
	var sm = SM.open(host)
	await settle()
	var t: Array = labels(sm._modal)
	check("onglets présents", t.has("Tests") and t.has("Vue d'ensemble") and t.has("Joueurs") and t.has("Parties"))
	check("boutons de test par difficulté", t.has("Test — Facile") and t.has("Test — Hardcore") and t.has("Test — Hardcore du mois"))
	calls.clear()
	var r1: Dictionary = await RR.start("easy", "difficulty", true)
	check("test : fonction dédiée appelée", r1.ok and calls.size() == 1 and str(calls[0].url).ends_with("/rpc/admin_start_ranked_run") and str(calls[0].body).contains("\"p_kind\":\"difficulty\""))
	calls.clear()
	var r2: Dictionary = await RR.start("easy", "difficulty", false)
	check("partie normale : jamais la fonction de test", calls.size() == 1 and str(calls[0].url).ends_with("/rpc/start_ranked_run"))
	var cfg: Dictionary = RR.config_for(root.get_node("Data").original_config, "a".repeat(32), r1.params)
	check("le donjon de test se construit comme une partie classée", not cfg.is_empty() and str(cfg.get("runSeed", "")) == "a".repeat(32))

	# --- onglet Vue d'ensemble
	calls.clear()
	sm._show("overview")
	await settle()
	var o: Array = labels(sm._modal)
	check("vue d'ensemble : appel serveur", calls.any(func(c): return str(c.url).ends_with("/rpc/admin_overview")))
	check("vue d'ensemble : comptes et actifs", o.has("12") and o.has("Comptes") and o.has("Actifs (7 jours)"))
	check("vue d'ensemble : tableau par mode", o.has("Facile") and o.has("Hardcore du mois") and o.has("2.35") and o.has("1 h 01"))
	check("vue d'ensemble : file de vérification (2 min)", o.has("Parties en attente") and o.has("2 min"))
	check("vue d'ensemble : motifs de rejet", o.has("version_non_rejouable"))
	check("vue d'ensemble : mois en cours", o.has("2026-10") and o.has("Mois clôturé") and o.has("non"))
	check("vue d'ensemble : badges", o.has("   hc_participant"))
	check("aucun courriel ni journal dans l'écran", not has_text(sm._modal, "@"))

	# --- onglet Joueurs
	calls.clear()
	sm._show("players")
	await settle()
	var p: Array = labels(sm._modal)
	check("joueurs : liste", p.any(func(x): return str(x).begins_with("Nyra")) and p.has("Bob"))
	check("joueurs : super admin marqué", p.any(func(x): return str(x).contains("Nyra 🛡️")))
	check("joueurs : vérifiées/total", p.has("4/5") and p.has("0/0"))
	sm._search.text = "bo"
	sm._fill_players()
	await settle()
	check("joueurs : recherche envoyée et filtrée", str(calls[calls.size() - 1].body).contains("\"p_search\":\"bo\"") and not has_text(sm._modal, "Nyra"))

	# --- onglet Parties
	calls.clear()
	sm._show("runs")
	await settle()
	var u: Array = labels(sm._modal)
	check("parties : lignes et marque de test", u.any(func(x): return str(x).contains("🧪")) and u.has("Rejetée"))
	check("parties : motif de rejet visible", u.any(func(x): return str(x).contains("version_non_rejouable")))
	check("parties : mode du mois nommé", u.any(func(x): return str(x).begins_with("Hardcore du mois")))
	sm._run_tests = "only"
	sm._run_status = "verified"
	sm._fill_runs()
	await settle()
	var last: Dictionary = JSON.parse_string(str(calls[calls.size() - 1].body))
	check("parties : filtres envoyés", last.p_tests == "only" and last.p_status == "verified")

	# --- purge
	sm._show("tests")
	await settle()
	calls.clear()
	sm._purge()
	await settle()
	check("purge : appel et message", calls.any(func(c): return str(c.url).ends_with("/rpc/admin_purge_tests")) and has_text(sm._modal, "3 partie(s) de test supprimée(s)."))

	# --- un serveur qui refuse (rôle retiré entre-temps) : l'écran l'affiche sans planter
	is_admin = false
	sm._show("overview")
	await settle()
	check("rôle retiré : message de refus affiché", has_text(sm._modal, "Accès refusé"))
	sm._modal.close()

	Cloud._clear_session()
	Cloud._transport = Callable()
	print("check_super_admin : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
