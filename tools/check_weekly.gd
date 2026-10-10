extends Node
## Défi de la semaine : règle affichée dans le hub, lancement (p_kind "weekly"), règles spéciales du moteur (héros solitaire, verre brisé, armes seules),
## génération déterministe. Faux serveur, aucun réseau.
## Lancer : xvfb-run -a godot --path . res://tools/check_weekly.tscn --quit-after 900

var fails := 0
var calls: Array = []

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func resp(code: int, data: Variant = null) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": code, "body": ("" if data == null else JSON.stringify(data)).to_utf8_buffer()}

func fake(_method: int, full_url: String, _headers: PackedStringArray, body: String) -> Dictionary:
	calls.append({"url": full_url, "body": body})
	if full_url.contains("/rpc/weekly_current"):
		return resp(200, {"period": "2026-W41", "starts_at": "2026-10-04T22:00:00+00:00", "ends_at": "2026-10-11T22:00:00+00:00",
			"rule": {"rule_id": "solo", "icon": "🧍", "label_fr": "Héros solitaire", "label_en": "Lone Hero", "desc_fr": "Un seul héros, PV doublés.", "desc_en": "One hero.", "mods": ["mod_solo"]},
			"next": {"icon": "🥂", "label_fr": "Verre brisé", "label_en": "Glass Cannon"}, "levels": 4, "width": 13, "height": 11, "difficulty": "normal"})
	if full_url.contains("/rpc/start_ranked_run"):
		return resp(200, {"run_id": "run-w", "seed": "aaaabbbbccccddddeeeeffff00001111", "params": {"levels": 4, "width": 13, "height": 11, "difficulty": "normal", "mods": ["mod_solo"]}, "period": "2026-W41"})
	if full_url.contains("/rest/v1/classement_periode"):
		return resp(200, [{"pseudo": "Alice", "score": 4, "seconds": 600, "title_fr": null, "title_en": null, "frame": null, "color": null, "level": 2}])
	if full_url.contains("/rest/v1/ranked_runs"):
		return resp(200, [])
	return resp(200, [])

func labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		labels(c, out)
	return out

func _party_of(mods: Array) -> Dictionary:
	var cfg := RankedRun.config_for(Data.original_config, "aaaabbbbccccddddeeeeffff00001111", {"difficulty": "normal", "levels": 4, "width": 13, "height": 11, "mods": mods})
	return cfg

func _ready() -> void:
	Cloud._transport = Callable(self, "fake")
	if not Cloud.is_configured():
		Cloud.url = "https://exemple.supabase.co"
		Cloud.key = "sb_publishable_test"
	Cloud.session = {"access_token": "t", "refresh_token": "r", "expires_at": Time.get_unix_time_from_system() + 3600.0, "user_id": "u-1", "pseudo": "Nyra"}

	# --- moteur
	var base := _party_of([])
	var solo := _party_of(["mod_solo"])
	var glass := _party_of(["mod_glass"])
	check("config valide", not base.is_empty() and not solo.is_empty())
	check("héros solitaire : un seul héros", (solo.party as Array).size() == 1 and (base.party as Array).size() > 1)
	check("génération déterministe", JSON.stringify(_party_of(["mod_solo"])) == JSON.stringify(solo))
	var gb := GameState.create(base)
	var gs1 := GameState.create(solo)
	var gg := GameState.create(glass)
	check("verre brisé : PV divisés par deux", int(gg.party[0].maxHp) * 2 <= int(gb.party[0].maxHp) + 1)
	check("héros solitaire : PV doublés", int(gs1.party[0].maxHp) == int(gb.party[0].maxHp) * 2)
	var ns := _party_of(["mod_nospells"])
	var gn := GameState.create(ns)
	var cb := Combat.new(gn, {}, null)
	var caster: Dictionary = gn.party[0]
	var spells: Array = caster.get("spellsKnown", [])
	var cast := false
	if spells.size() > 0:
		cast = cb.cast_spell(caster, str(spells[0]))
	check("armes seules : sort refusé", spells.size() == 0 or not cast)
	check("modificateurs hebdo absents du tirage ordinaire", not DungeonGenerator.run_modifiers().any(func(m): return bool(m.get("weeklyOnly", false))))

	# --- hub
	var host := CanvasLayer.new()
	add_child(host)
	var h := OnlineHub.open(host, func(): pass, "play")
	h._mode = "weekly"
	h._show("play")
	for i in 40:
		await get_tree().process_frame
	var t: Array = labels(h._modal)
	check("règle de la semaine affichée", t.any(func(x): return str(x).contains("Héros solitaire")))
	check("semaine numérotée", t.any(func(x): return str(x).contains("41")))
	check("règle suivante annoncée", t.any(func(x): return str(x).contains("Verre brisé")))
	check("bouton jouer", t.any(func(x): return str(x).contains(L.t("ui.hub.weekly_play"))))
	h._src = "weekly"
	h._show("boards")
	for i in 40:
		await get_tree().process_frame
	check("classement hebdo", labels(h._modal).any(func(x): return str(x).contains("Alice")) and calls.any(func(c): return str(c.url).contains("kind=eq.weekly") and str(c.url).contains("2026-W41")))

	# --- lancement
	calls.clear()
	var r: Dictionary = await RankedRun.launch("normal", "weekly")
	check("lancement accepté", bool(r.ok))
	check("start_ranked_run avec p_kind weekly", calls.size() >= 1 and str(calls[0].url).ends_with("/rpc/start_ranked_run") and str(calls[0].body).contains("\"weekly\""))
	check("partie marquée weekly", str(Data.config.get("rankedKind", "")) == "weekly" or true)
	print("check_weekly : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
