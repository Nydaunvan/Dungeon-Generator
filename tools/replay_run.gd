extends SceneTree
## Rejoue UNE partie classée (utilisé par le vérificateur). Entrée : un fichier JSON {"seed", "params", "log"} ; sortie : une ligne
## « RESULT:{json} » avec {ok, reason, score, seconds, metrics}. Affichage ou Xvfb requis (la scène du jeu est en 3D).
## Lancer : xvfb-run -a godot --path . --script res://tools/replay_run.gd -- entree.json

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := {"ok": false, "reason": "entree_absente"}
	if args.size() > 0 and FileAccess.file_exists(args[0]):
		out = await _replay(JSON.parse_string(FileAccess.get_file_as_string(args[0])))
	print("RESULT:" + JSON.stringify(out))
	quit(0)

func _replay(inp: Variant) -> Dictionary:
	if not (inp is Dictionary) or not (inp.get("log") is Array) or not (inp.get("params") is Dictionary):
		return {"ok": false, "reason": "entree_invalide"}
	var Rep: GDScript = load("res://scripts/core/replayer.gd")
	var RR: GDScript = load("res://scripts/core/ranked_run.gd")
	var base: Dictionary = root.get_node("Data").original_config
	var cfg: Dictionary = RR.config_for(base, str(inp.get("seed", "")), inp.params)
	if cfg.is_empty():
		return {"ok": false, "reason": "reglages_invalides"}
	var res: Dictionary = await Rep.run(self, cfg, inp.log, {"time_scale": 6.0})
	var rank: Dictionary = RR.ranking_of(res)
	if rank.is_empty():
		return {"ok": false, "reason": str(res.reason) if str(res.reason) != "" else ("souillee:" + str(res.taint))}
	return {"ok": true, "reason": "", "score": rank.score, "seconds": rank.seconds, "metrics": rank.metrics}
