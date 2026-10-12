extends SceneTree
## Lecteur de rejeu (ReplayLive) : un bot joue une partie classée, puis son journal est revu dans le moteur (pause, avance, recul, vitesse)
## et on vérifie que le rejeu va au bout sans diverger. Écrit aussi une capture d'écran et une vidéo AVI de contrôle.
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_replay_live.gd -- <préfixe de sortie>
var fails := 0
func check(label: String, cond: bool) -> void:
	print(("OK     " if cond else "ÉCHEC  "), label)
	if not cond:
		fails += 1

func _idle(w: WeakRef) -> bool:
	return w.get_ref() == null or (w.get_ref().settled() and not w.get_ref().rig._busy)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/rl"
	root.size = Vector2i(1280, 720)
	await process_frame
	var Data = root.get_node("Data")
	var RR: GDScript = load("res://scripts/core/ranked_run.gd")
	var Rep: GDScript = load("res://scripts/core/replayer.gd")
	var params := {"difficulty": "easy", "levels": 2, "width": 9, "height": 9, "mods": []}
	var seed_text := "aaaabbbbccccddddeeeeffff00001111"
	var cfg: Dictionary = RR.config_for(Data.original_config, seed_text, params)
	var m: Node = await Rep.start(self, cfg)
	var wm: WeakRef = weakref(m)
	check("partie de départ", m != null)
	for i in 24:
		await Rep._until(self, func(): return _idle(wm), 20.0)
		if i % 4 == 3:
			m.rig.turn(true)
		else:
			m.rig.step(0)
		await create_timer(0.05, true, false, true).timeout
	await Rep._until(self, func(): return _idle(wm), 20.0)
	var log: Array = JSON.parse_string(JSON.stringify(m.gs.run_log))
	check("journal enregistré (%d actions)" % log.size(), log.size() >= 20)
	print("fin du journal : ", log[log.size() - 1][0], " ms")
	Data.go_home()
	await create_timer(3.0, true, false, true).timeout
	var meta := {"id": "11111111-2222-3333-4444-555555555555", "pseudo": "Alice", "seed": seed_text, "params": params, "kind": "difficulty", "difficulty": "easy",
		"game_version": "1.34.0", "status": "verified", "score": 0, "started_at": "2026-10-12T10:00:00Z", "log": log}
	# CSV
	var csv: String = load("res://scripts/core/run_export.gd").to_csv(meta)
	var lines := csv.split("\r\n", false)
	check("CSV : en-tête + %d lignes" % (lines.size() - 1), lines.size() == log.size() + 1 and lines[0].contains("temps_ms"))
	var f := FileAccess.open(pre + ".csv", FileAccess.WRITE)
	f.store_string(csv)
	f.close()
	var RL: GDScript = load("res://scripts/core/replay_live.gd")
	var err: String = RL.open(meta)
	check("ouverture du rejeu", err == "")
	var rl = RL.active
	rl.cp_every_ms = 1500
	await create_timer(6.0, true, false, true).timeout
	check("rejeu en lecture seule (replaying)", load("res://scripts/rules/run_log.gd").replaying)
	rl.set_speed(16.0)
	await create_timer(2.0, true, false, true).timeout
	root.get_texture().get_image().save_png(pre + "_1.png")
	var t1: float = rl._pos_ms
	rl.toggle_pause()
	await create_timer(1.0, true, false, true).timeout
	var t2: float = rl._pos_ms
	await create_timer(1.0, true, false, true).timeout
	check("pause : la position ne bouge plus (%.0f → %.0f)" % [t2, rl._pos_ms], is_equal_approx(t2, rl._pos_ms))
	# vidéo : quelques images
	rl.hide_bar = false
	rl.toggle_recording()
	await create_timer(2.0, true, false, true).timeout
	var n: int = rl._rec_frames.size()
	check("vidéo : images capturées (%d)" % n, n >= 8)
	var avi = load("res://scripts/core/avi_writer.gd").new(rl._rec_w, rl._rec_h, 15)
	for fr in rl._rec_frames:
		avi.add_jpeg(fr)
	var av := FileAccess.open(pre + ".avi", FileAccess.WRITE)
	av.store_buffer(avi.finish())
	av.close()
	rl._rec = false
	# recul puis avance
	rl.toggle_pause()
	await create_timer(1.0, true, false, true).timeout
	rl.seek(int(rl._pos_ms) / 2)
	await create_timer(15.0, true, false, true).timeout
	print("après recul : pos ", rl._pos_ms, " paused ", rl.paused, " busy ", rl._busy, " applied ", rl._applied)
	check("recul : relancé, pas d'échec", not rl._bad)
	root.get_texture().get_image().save_png(pre + "_2.png")
	rl.paused = false
	rl.set_speed(16.0)
	await create_timer(25.0, true, false, true).timeout
	print("fin : ended ", rl._ended, " bad ", rl._bad, " status ", rl._status)
	check("rejeu terminé sans divergence", rl._ended and not rl._bad)
	var fp1: String = rl._end_fp
	check("points de reprise enregistrés (%d)" % rl._cps.size(), rl._cps.size() >= 2)
	print("recul via point : repart de l'action ", rl._from_cp)
	check("le recul est reparti d'un point de reprise", rl._from_cp > 0)
	# recul vers 4 s : doit utiliser un point puis finir à l'identique
	rl.seek(4000)
	await create_timer(12.0, true, false, true).timeout
	print("2e recul : depuis action ", rl._from_cp, " pos ", rl._pos_ms, " bad ", rl._bad)
	check("2e recul : point de reprise utilisé", rl._from_cp > 0 and not rl._bad)
	rl.paused = false
	rl.set_speed(16.0)
	await create_timer(15.0, true, false, true).timeout
	print("fin 2 : ended ", rl._ended, " bad ", rl._bad, " busy ", rl._busy, " paused ", rl.paused, " pos ", rl._pos_ms, " applied ", rl._applied, " fp1 ", fp1, " fp2 ", rl._end_fp)
	check("fin après point de reprise identique à la lecture complète", rl._ended and rl._end_fp == fp1 and fp1 != "")
	root.get_texture().get_image().save_png(pre + "_3.png")
	rl.close()
	await create_timer(3.0, true, false, true).timeout
	check("sortie : horloge et rejeu restaurés", not load("res://scripts/rules/run_log.gd").replaying and Engine.time_scale == 1.0)
	print("ÉCHECS : ", fails)
	quit()
