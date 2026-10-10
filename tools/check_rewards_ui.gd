extends Node
## Écrans onglets Récompenses, Classements et Mes parties de la fenêtre « Mode en ligne », avec un faux serveur (aucun réseau).
## Lancer : godot --path . res://tools/check_rewards_ui.tscn --quit-after 900

var fails := 0
var calls: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

const BADGES := [
	{"id": "hc_participant", "icon": "🔥", "rarity": 1, "label_fr": "Entré dans la fournaise", "label_en": "Into the Furnace", "desc_fr": "d", "desc_en": "d", "title_fr": "Téméraire", "title_en": "Daredevil", "frame": "bronze", "color": null},
	{"id": "hc_profondeur_5", "icon": "🕳️", "rarity": 3, "label_fr": "Au cœur du gouffre", "label_en": "Heart", "desc_fr": "d", "desc_en": "d", "title_fr": "Abyssal", "title_en": "Abyssal", "frame": "argent", "color": "#8fd3ff"},
	{"id": "hc_champion", "icon": "👑", "rarity": 5, "label_fr": "Champion du mois", "label_en": "Champion", "desc_fr": "d", "desc_en": "d", "title_fr": "Champion hardcore", "title_en": "Hardcore Champion", "frame": "royal", "color": "#ffd24a"},
]

func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"url": full_url, "body": body})
	if full_url.contains("/rest/v1/badges"):
		return resp(200, BADGES)
	if full_url.contains("/rest/v1/player_badges"):
		return resp(200, [{"badge_id": "hc_participant", "period": "", "earned_at": "x"}, {"badge_id": "hc_profondeur_5", "period": "", "earned_at": "x"}])
	if full_url.contains("/rest/v1/account_xp"):
		return resp(200, [{"xp": 450, "level": 3}])
	if full_url.contains("/rest/v1/player_cosmetics"):
		return resp(200, [{"title_badge": "hc_participant", "frame_badge": null, "color_badge": null}])
	if full_url.contains("/rpc/equip_cosmetics"):
		return resp(204)
	if full_url.contains("/rest/v1/classement_periode"):
		return resp(200, [{"pseudo": "Alice", "score": 7, "seconds": 900, "title_fr": "Champion hardcore", "title_en": "Hardcore Champion", "frame": "royal", "color": "#ffd24a", "level": 5},
			{"pseudo": "Bob", "score": 4, "seconds": 700, "title_fr": null, "title_en": null, "frame": null, "color": null, "level": 2}])
	if full_url.contains("/rest/v1/classement_difficulte"):
		return resp(200, [{"pseudo": "Carol", "score": 3, "seconds": 500, "title_fr": null, "title_en": null, "frame": "bronze", "color": null, "level": 1, "metrics": {}}])
	if full_url.contains("/rest/v1/ranked_runs"):
		return resp(200, [{"id": "r1", "difficulty": "hard", "kind": "difficulty", "period": "", "day": "", "status": "verified", "score": 3, "seconds": 500, "started_at": "2026-10-09T10:00:00+00:00", "reject_reason": null}])
	if full_url.contains("/rest/v1/challenges"):
		return resp(200, [])
	return resp(404, {"message": "inconnu"})

func labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		labels(c, out)
	return out

func frames(n: Node) -> int:
	var k := 0
	if n is PanelContainer and (n as PanelContainer).get_theme_stylebox("panel") is StyleBoxFlat and ((n as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_width_left >= 2:
		k = 1
	for c in n.get_children():
		k += frames(c)
	return k

func _ready() -> void:
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra"}
	var host := CanvasLayer.new()
	add_child(host)
	check("niveau de compte (450 XP = niveau 3)", Cosmetics.level_of(450) == 3 and Cosmetics.xp_for_level(3) == 400 and Cosmetics.xp_for_level(4) == 900)

	# --- Récompenses
	var h := OnlineHub.open(host, func(): pass, "rewards")
	for i in 40:
		await get_tree().process_frame
	var t: Array = labels(h._modal)
	check("niveau et XP affichés", t.any(func(x): return str(x).contains("Niveau 3")) and t.any(func(x): return str(x).contains("450")))
	check("badges affichés", t.has("Entré dans la fournaise") and t.has("Champion du mois"))
	h._sel.frame = "hc_profondeur_5"
	h._sel.color = "hc_profondeur_5"
	calls.clear()
	h._equip()
	for i in 10:
		await get_tree().process_frame
	check("équipement envoyé au serveur", calls.size() >= 1 and str(calls[0].url).ends_with("/rpc/equip_cosmetics") and str(calls[0].body).contains("hc_profondeur_5") and str(calls[0].body).contains("hc_participant"))

	# --- Classements : parties classées
	h._src = "ranked"
	h._src_diff = "hard"
	calls.clear()
	h._show("boards")
	for i in 40:
		await get_tree().process_frame
	var t2: Array = labels(h._modal)
	check("classement par difficulté affiché", t2.any(func(x): return str(x).contains("Carol")))
	check("cadre du joueur dessiné", frames(h._modal) >= 1)
	check("interroge la bonne difficulté", calls.any(func(c): return str(c.url).contains("difficulty=eq.hard")))

	# --- Classements : Hardcore du mois
	h._src = "hardcore"
	h._show("boards")
	for i in 40:
		await get_tree().process_frame
	var t3: Array = labels(h._modal)
	check("classement du mois", t3.any(func(x): return str(x).contains("Alice")))
	check("titre du champion affiché", t3.any(func(x): return str(x).contains("Champion hardcore")))

	# --- Mes parties
	h._show("runs")
	for i in 40:
		await get_tree().process_frame
	var t4: Array = labels(h._modal)
	check("liste de mes parties", t4.any(func(x): return str(x).contains("Difficile")) )
	print("check_rewards_ui : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
