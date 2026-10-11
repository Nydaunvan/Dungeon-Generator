extends SceneTree
## Vérifie le score selon la règle du Défi de la semaine (or, boss, sans piège). Lancer : godot --headless --path . --script res://tools/check_metrics.gd
func _init() -> void:
	await process_frame
	var RR = load("res://scripts/core/ranked_run.gd")
	var fails := 0
	var res := {"ok": true, "taint": "", "clock_ms": 125000, "summary": {"levelsCleared": 4, "gold": 380, "bosses": 3, "traps": 0}}
	var cases := [[{}, 4], [{"metric": "levels"}, 4], [{"metric": "gold"}, 380], [{"metric": "bosses"}, 3], [{"metric": "clean"}, 4], [{"metric": "inconnu"}, 4]]
	for c in cases:
		var r: Dictionary = RR.ranking_of(res, c[0])
		if int(r.get("score", -1)) != c[1] or int(r.get("seconds", -1)) != 125:
			fails += 1
			print("ÉCHEC ", c[0], " → ", r)
	res.summary.traps = 1
	if int(RR.ranking_of(res, {"metric": "clean"}).score) != 0 or int(RR.ranking_of(res, {"metric": "gold"}).score) != 380:
		fails += 1
		print("ÉCHEC piège déclenché")
	res.taint = "admin"
	if not RR.ranking_of(res, {"metric": "gold"}).is_empty():
		fails += 1
		print("ÉCHEC partie souillée acceptée")
	print("check_metrics : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit()
