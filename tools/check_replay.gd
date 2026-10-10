extends SceneTree
## Équivalence « partie jouée en direct » = « rejeu du journal » : un bot joue une vraie partie classée (graine fixée) jusqu'à ce qu'elle
## ne soit plus rejouable (action non journalisée) ou qu'il ait fait N actions, puis le journal est rejoué sur une nouvelle partie
## et l'empreinte de l'état doit être identique.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_replay.gd -- [graine] [actions]

var fails := 0
# (--script : les autoloads n'existent pas à la compilation ; les classes du jeu sont donc chargées à l'exécution)
var Rep: GDScript
var RL: GDScript
var GC: GDScript
const GRID_DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func _bfs(m: Node, goal_fn: Callable) -> Array:
	var grid = m.grid
	var start := Vector2i(m.rig.gx, m.rig.gy)
	var prev := {start: start}
	var queue: Array = [start]
	var found := Vector2i(-1, -1)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if goal_fn.call(p) and p != start:
			found = p
			break
		for v in GRID_DIRS:
			var n: Vector2i = p + v
			if prev.has(n):
				continue
			var ch: String = grid.cell(n.x, n.y)
			if grid.is_walkable(n.x, n.y) or ch == "D" or ch == "S":
				prev[n] = p
				if ch == "S" or ch == "D":
					if goal_fn.call(n):
						found = n
						break
					continue          # on ne traverse pas une porte / un escalier
				queue.append(n)
		if found.x >= 0:
			break
	if found.x < 0:
		return []
	var path: Array = [found]
	while path[0] != start:
		path.push_front(prev[path[0]])
	return path

## Une action du bot ; renvoie un libellé (pour le suivi).
func _bot_village(m: Node, rng: RandomNumberGenerator) -> String:
	var A: GDScript = load("res://scripts/game/actions.gd")
	var gs = m.gs
	var r := rng.randf()
	if r < 0.25 and not gs.party.is_empty():
		var c: Dictionary = gs.party[rng.randi() % gs.party.size()]
		var slots: Array = []
		for sl in c.get("equipment", {}):
			if c.equipment[sl] != null:
				slots.append(sl)
		if not slots.is_empty():
			A.forge(str(c.id), slots[rng.randi() % slots.size()])
			return "forge"
	elif r < 0.45 and not gs.party.is_empty():
		var c2: Dictionary = gs.party[rng.randi() % gs.party.size()]
		for tr in load("res://scripts/rules/talents.gd").tracks(gs.cfg, str(c2.classId)):
			if int(c2.level) >= int(tr.level):
				var o: Dictionary = tr.options[rng.randi() % tr.options.size()]
				A.master_pick(str(c2.id), int(tr.level), str(o.id))
				return "maitre"
	return ""

func _bot_act(m: Node, rng: RandomNumberGenerator) -> String:
	if m.gs.in_village:
		var v := _bot_village(m, rng)
		if v != "":
			return v
	if m.ctrl.in_combat():
		var c: Dictionary = m.gs.char_by_id(m.gs.active_char_id)
		var known: Array = c.get("spellsKnown", []) if not c.is_empty() else []
		if known.size() > 0 and rng.randf() < 0.35:
			m.ctrl.cast(str(known[rng.randi() % known.size()]))
			return "cast"
		m._on_command("attack")
		return "attack"
	var r := rng.randf()
	if r < 0.10:
		m._on_command("turn_left" if rng.randf() < 0.5 else "turn_right")
		return "turn"
	var path := _bfs(m, func(p: Vector2i): return m.grid.cell(p.x, p.y) == "S")
	if path.size() < 2:
		m._on_command("turn_right")
		return "turn"
	var here := Vector2i(m.rig.gx, m.rig.gy)
	var nxt: Vector2i = path[1]
	var want := GRID_DIRS.find(nxt - here)
	if m.grid.cell(nxt.x, nxt.y) == "S":
		if m.rig.dir != want:
			m._on_command("turn_right")
			return "turn"
		m._on_command("interact")
		return "interact"
	var rel := posmod(want - m.rig.dir, 4)
	m._on_command(["forward", "right", "back", "left"][rel])
	return "move"

func m2():
	return Rep.main_of(self).gs

## Répond à une fenêtre de décision comme le ferait un joueur. Renvoie un libellé (vide : rien fait cette fois).
func _bot_flow(m: Node, flow: String, md: Node, rng: RandomNumberGenerator) -> String:
	var F: GDScript = load("res://scripts/game/flows.gd")
	match flow:
		"fontaine":
			F.choose("fontaine", 1 if rng.randf() < 0.8 else 0)
			return "fontaine"
		"talent", "evolve":
			var gs = m.gs
			for q in gs.choice_queue:
				var c: Dictionary = gs.char_by_id(str(q.char_id))
				if c.is_empty():
					continue
				var TL: GDScript = load("res://scripts/rules/talents.gd")
				if q.kind == "evolve" and flow == "evolve":
					var cls: Dictionary = load("res://scripts/rules/characters.gd").class_def(gs.cfg, str(c.classId))
					var opts: Array = cls.get("evolvesTo", [])
					if not opts.is_empty():
						F.choose("evolve", str(opts[rng.randi() % opts.size()]))
						return "evolve"
				elif q.kind == "talent" and flow == "talent":
					var track: Dictionary = TL.track_at(gs.cfg, str(c.classId), int(q.level))
					if not track.is_empty():
						F.choose("talent", str(track.options[rng.randi() % track.options.size()].id))
						return "talent"
			return ""
		"victoire":
			F.choose("victoire", "village" if (not m.gs.in_village and rng.randf() < 0.6) else "next")
			return "victoire"
		"mods":
			var mods: Array = []
			var ids: Array = load("res://scripts/rules/dungeon_generator.gd").run_modifiers().map(func(x): return str(x.id))
			for i in rng.randi() % 3:
				mods.append(ids[rng.randi() % ids.size()])
			F.choose("mods", mods)
			return "mods"
		"sortie_village":
			F.choose("sortie_village", 1 if rng.randf() < 0.7 else 0)
			return "sortie"
		"retour_donjon":
			F.choose("retour_donjon", 1 if rng.randf() < 0.2 else 0)
			return "retour"
		"marchand":
			F.choose("marchand", 1 if rng.randf() < 0.7 else 0)
			return "marchand"
		"shop":
			var mm: Dictionary = m.wand.merchant()
			var offers: Array = mm.get("offers", []) if not mm.is_empty() else []
			var r2 := rng.randf()
			if r2 < 0.5:
				for ix in offers.size():
					if int(offers[ix].price) <= int(m.gs.gold):
						if F.input("shop", ["buy", [ix]]):
							return "achat"
			elif r2 < 0.7:
				for ix in m.gs.inventory.size():
					if str(m.gs.inventory[ix].get("type", "")) != "key":
						if F.input("shop", ["sell", [ix]]):
							return "vente"
			F.input("shop", ["close"])
			return "boutique"
		"trap":
			if not md.ready_for_input():
				return ""
			var tries: Array = [["next"], ["pz", rng.randi() % 4], ["sac", 0]]
			var meths: Array = md._methods
			if md._stage == "choose":
				var r := rng.randf()
				if md._puzzle != "" and r < 0.25:
					tries = [["puzzle"]]
				elif r < 0.45:
					tries = [["skip"]]
				elif not meths.is_empty():
					tries = [["method", str(meths[rng.randi() % meths.size()])]]
			elif md._stage == "sacrifice":
				var cands: Array = load("res://scripts/rules/trap_rules.gd").sacrifice_candidates(m.gs)
				tries = [["sac", cands[0]]] if not cands.is_empty() else [["back"]]
			for a in tries:
				if F.input("trap", a):
					return "trap"
			return ""
	return ""

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	Rep = load("res://scripts/core/replayer.gd")
	RL = load("res://scripts/rules/run_log.gd")
	GC = load("res://scripts/rules/game_clock.gd")
	var seed_text := "graine-test-1"
	var max_actions := 250
	var n_levels := 3
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_text = args[0]
	if args.size() > 1:
		max_actions = int(args[1])
	if args.size() > 2:
		n_levels = int(args[2])
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, n_levels, 13, 11, "normal", [], 1, load("res://scripts/rules/seeds.gd").from_text(seed_text))
	cfg["runSeed"] = seed_text
	var m = await Rep.start(self, cfg)
	check("la partie démarre", m != null)
	if m == null:
		quit(1)
		return
	var gs = m.gs
	check("partie classée", RL.ranked())
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var done := 0
	var kinds := {}
	var t0 := Time.get_ticks_msec()
	while done < max_actions and RL.is_clean() and not gs.game_over and (Time.get_ticks_msec() - t0) < 170000:
		await process_frame
		var modals: Array = get_nodes_in_group("modal")
		if not modals.is_empty():
			if not RL.is_clean():
				break
			var flows_seen := false
			for md in modals:
				if md.is_queued_for_deletion():
					continue
				if md.has_meta("flow"):
					flows_seen = true
					var what := _bot_flow(m, str(md.get_meta("flow")), md, rng)
					if what != "":
						kinds[what] = int(kinds.get(what, 0)) + 1
						done += 1
				elif md.has_method("close"):
					md.close()          # fenêtre d'information (bilan de combat…) : sans effet sur la partie
			for i in (30 if flows_seen else 10):
				await process_frame
			continue
		if not m.settled() or (gs.won and not gs.in_village):
			continue
		var k := _bot_act(m, rng)
		kinds[k] = int(kinds.get(k, 0)) + 1
		done += 1
	# laisse finir ce qui est en cours puis fige
	for i in 600:
		await process_frame
		if m.settled():
			break
	var f0 := FileAccess.open("/tmp/x/trace_live.txt", FileAccess.WRITE)
	f0.store_string("\n".join(RL.trace))
	f0.close()
	RL.trace.clear()
	var live_fp: String = Rep.fingerprint(gs)
	var live_dump: String = Rep.dump(gs)
	var live_log: Array = gs.run_log.duplicate(true)
	print("direct : %d actions du bot, journal de %d entrées, taint=%s, niveaux=%d, mort=%s" % [done, live_log.size(), gs.run_taint, int(gs.stats.get("levelsCleared", 0)), gs.game_over])
	print("types : ", kinds)
	var f9 := FileAccess.open("/tmp/x/log_live.json", FileAccess.WRITE)
	f9.store_string(JSON.stringify(live_log))
	f9.close()
	var live_summary: Dictionary = Rep.summary(gs)
	# rejeu : le journal passe par JSON comme s'il avait voyagé jusqu'au serveur
	var wire: Array = JSON.parse_string(JSON.stringify(live_log))
	var cfg2 := cfg.duplicate(true)
	var res: Dictionary = await Rep.run(self, cfg2, wire, {"time_scale": 4.0})
	var f3 := FileAccess.open("/tmp/x/trace_replay.txt", FileAccess.WRITE)
	f3.store_string("\n".join(RL.trace))
	f3.close()
	print("rejeu : ok=%s raison=%s appliquées=%d" % [res.ok, res.reason, res.applied])
	check("le rejeu va au bout (%s)" % res.reason, bool(res.ok))
	if res.ok:
		if live_fp != res.fingerprint:
			var f1 := FileAccess.open("/tmp/x/live.json", FileAccess.WRITE)
			f1.store_string(live_dump)
			f1.close()
			var f2 := FileAccess.open("/tmp/x/replay.json", FileAccess.WRITE)
			f2.store_string(Rep.dump(m2()))
			f2.close()
		check("même empreinte d'état (direct %s / rejeu %s)" % [live_fp.substr(0, 8), str(res.fingerprint).substr(0, 8)], live_fp == res.fingerprint)
		check("même résultat", JSON.stringify(live_summary) == JSON.stringify(res.summary))
	print("check_replay : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
