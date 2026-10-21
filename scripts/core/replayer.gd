class_name Replayer
extends RefCounted
## Rejeu d'une partie classée : fait tourner le VRAI jeu (scène principale, sans rien montrer au joueur) et lui injecte le journal
## de commandes (voir RunLog) au bon moment. Les règles recalculent tout : le score vient du rejeu, jamais du client.
##
## Usage (depuis un script de SceneTree, affichage ou Xvfb requis car la scène est en 3D) :
##   var r: Dictionary = await Replayer.run(tree, cfg, log, {"time_scale": 6.0})
## `cfg` : la configuration de départ (avec `runSeed`) ; `log` : le journal [[ms, commande, args…], …].

const READY_TIMEOUT := 60.0
const SETTLE_TIMEOUT := 30.0

## Commandes qui exigent le jeu « au repos ».
const NEEDS_SETTLED := ["m", "t", "i", "atk", "cast", "scroll", "flee", "skip", "tgt", "sel", "w", "eq", "un", "drop", "sort", "drink"]

static func main_of(tree: SceneTree) -> Node:
	var m := tree.current_scene
	return m if m != null and m.get("gs") != null and m.get("ctrl") != null else null

## Attend (avec délai maximal en secondes réelles) qu'une condition devienne vraie.
static func _until(tree: SceneTree, cond: Callable, timeout: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout:
			return false
		await tree.process_frame
	return true

## Lance la partie et attend qu'elle soit prête. Renvoie la scène principale (ou null).
static func start(tree: SceneTree, cfg: Dictionary) -> Node:
	var data = tree.root.get_node("Data")
	data.launch(cfg, "random")
	var ok: bool = await _until(tree, func():
		var m := main_of(tree)
		return m != null and not m.get("_loading") and m.get("level_node") != null and not Loader.is_active(), READY_TIMEOUT)
	return main_of(tree) if ok else null

## Exécute une commande du journal. Renvoie "" si tout va bien, sinon la raison de l'échec.
## Au rejeu, personne ne referme les fenêtres d'information (bilan de combat…) : on le fait, car elles bloquent le jeu.
## Les fenêtres de décision (fontaine, talent…) restent : seule une commande du journal peut y répondre.
static func _sweep(tree: SceneTree, _m: Node) -> void:
	for n in tree.get_nodes_in_group("modal"):
		if n is Modal and not n.has_meta("flow") and not n.is_queued_for_deletion():
			(n as Modal).close()

## La fenêtre de décision est ouverte et prête à recevoir cette entrée.
static func _flow_ready(flow: String, e: Array) -> bool:
	if not Flows.is_open(flow):
		return false
	var ch: Variant = _norm(e[3]) if e.size() > 3 else 0
	return Flows.can_input(flow, ch) if Flows.is_multi(flow) else true

## JSON rend tous les nombres flottants : on les ramène en entiers quand ils le sont.
static func _norm(v: Variant) -> Variant:
	if typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_norm(x))
		return out
	return v

static func _decision_open(tree: SceneTree) -> bool:
	for n in tree.get_nodes_in_group("modal"):
		if n.has_meta("flow") and not n.is_queued_for_deletion():
			return true
	return false

static func apply(m: Node, e: Array) -> String:
	var cmd := str(e[1])
	match cmd:
		"m": m.rig.step(int(e[2]))
		"t": m.rig.turn(int(e[2]) == 1)
		"i": m._interact()
		"atk": m.ctrl.attack()
		"cast": m.ctrl.cast(str(e[2]), str(e[3]) if e.size() > 3 else "")
		"scroll": m.ctrl.read_scroll(str(e[2]), int(e[3]))
		"flee": m.ctrl.do_flee()
		"skip": m.ctrl.skip_active_turn(L.t("game.combat_controller.n_a_pas_agi_a"))
		"tgt":
			var eng: Dictionary = m.ctrl.combat.engaged()
			if eng.is_empty():
				return "tgt_sans_combat"
			m.gs.selected_member[str(eng.monster.id)] = int(e[2])
		"ui":
			if not Flows.is_open(str(e[2])):
				return "decision_sans_fenetre:" + str(e[2])
			var ch: Variant = _norm(e[3]) if e.size() > 3 else 0
			if not Flows.apply(str(e[2]), ch):
				return "entree_refusee:" + str(e[2])
		"sel": m.ctrl.select_char(str(e[2]))
		"eq": Actions.equip(str(e[2]), int(e[3]))
		"un": Actions.unequip(str(e[2]), str(e[3]))
		"drop": Actions.discard(int(e[2]))
		"sort": Actions.sort(str(e[2]), str(e[3]))
		"forge": Actions.forge(str(e[2]), _norm(e[3]))
		"tm": Actions.master_pick(str(e[2]), int(_norm(e[3])[0]), str(e[3][1]))
		"drink": Actions.drink(str(e[2]), int(e[3]))
		"ins": m.ctrl.instinct_input(str(e[2]))
		"w": m.wand.replay_tick()
		"e": m.wand.replay_engage()
		_:
			return "commande_inconnue:" + cmd
	return ""

## Applique UNE entrée du journal : attend l'état requis (jeu au repos, fenêtre de décision…), règle l'horloge de jeu, exécute la
## commande puis laisse passer une image. Renvoie "" si tout va bien, sinon la raison de l'échec. `applied` : nombre d'entrées déjà
## appliquées (pour le message d'erreur). Partagé par le vérificateur (`run`) et par le lecteur de rejeu (ReplayLive).
static func step(tree: SceneTree, m: Node, e: Array, applied: int) -> String:
	var ms := int(e[0])
	var cmd := str(e[1])
	var wm: WeakRef = weakref(m)                                # la scène peut être remplacée (relance du rejeu) pendant l'attente
	if cmd == "e":
		var ok_e: bool = await _until(tree, func(): return wm.get_ref() == null or wm.get_ref().wand.engage_pending, SETTLE_TIMEOUT)
		if not ok_e:
			return "engagement_inattendu@%d" % applied
	elif cmd == "ins":
		var ok_i: bool = await _until(tree, func(): return wm.get_ref() == null or wm.get_ref().ctrl.instinct_waiting, SETTLE_TIMEOUT)
		if not ok_i:
			return "instinct_absent@%d" % applied
	elif cmd == "ui":
		var flow := str(e[2])
		var ok_u: bool = await _until(tree, func():
			if wm.get_ref() == null:
				return true
			_sweep(tree, null)
			return _flow_ready(flow, e), SETTLE_TIMEOUT)
		if not ok_u:
			return "fenetre_absente@%d(%s)" % [applied, flow]
	elif NEEDS_SETTLED.has(cmd):
		var ok_s: bool = await _until(tree, func():
			if wm.get_ref() == null:
				return true
			_sweep(tree, null)
			return wm.get_ref().settled() and not _decision_open(tree), SETTLE_TIMEOUT)
		if not ok_s:
			return "jeu_jamais_au_repos@%d(%s)" % [applied, cmd]
	if wm.get_ref() == null:
		return "scene_perdue"
	var shown := false
	if _on_screen():
		shown = await _show_before(tree, m, e)
		if wm.get_ref() == null:
			return "scene_perdue"
	GameClock.set_ms(ms)
	var why := apply(m, e)
	if why != "":
		return why
	if shown:
		await _show_after(tree, m, e)
	await tree.process_frame
	return ""

# ------------------------------------------------------------------ rejeu à l'écran (ReplayLive)
# Le vérificateur (sans affichage) ne passe jamais ici : `_on_screen()` n'est vrai que pendant un rejeu regardé par une personne.
# Rien de ce qui suit ne modifie la partie : on ne fait que MONTRER ce que le joueur faisait (volet d'inventaire ouvert sur le bon
# personnage, objet ou emplacement mis en évidence, fenêtres de décision laissées visibles un instant).

const DOCK_CMDS := ["eq", "un", "drop", "sort", "drink", "forge"]     ## commandes montrées dans le volet d'inventaire
const KEEP_DOCK_CMDS := ["sel"]                                        ## n'interrompent pas l'inventaire ouvert
const BEAT_BEFORE := 0.55                                              ## secondes (à vitesse ×1) pour voir la sélection avant l'action
const BEAT_AFTER := 0.45                                               ## … pour voir le résultat
const BEAT_FLOW := 0.7                                                 ## … pour voir une fenêtre de décision avant la réponse

static func _on_screen() -> bool:
	return ReplayLive.active != null and is_instance_valid(ReplayLive.active)

## Pause de `secs` secondes de lecture (divisée par la vitesse), sauf pendant une avance rapide.
static func _beat(tree: SceneTree, secs: float) -> void:
	var rl := ReplayLive.active
	if rl == null or not is_instance_valid(rl) or rl.is_seeking():
		return
	await tree.create_timer(secs / maxf(rl.speed, 1.0), true, false, true).timeout

static func _dock_of(m: Node) -> EquipDock:
	var d: Variant = m.get("dock")
	return d as EquipDock if d is EquipDock else null

## Avant l'action : ouvre l'inventaire sur le bon personnage (objet / emplacement choisi en évidence), le ferme quand le joueur est
## passé à autre chose, laisse voir les fenêtres de décision. Renvoie vrai si l'inventaire a été montré pour cette action.
static func _show_before(tree: SceneTree, m: Node, e: Array) -> bool:
	var cmd := str(e[1])
	var dock := _dock_of(m)
	if dock != null and dock.is_open and not DOCK_CMDS.has(cmd) and not KEEP_DOCK_CMDS.has(cmd):
		dock.close()                       # le joueur a refermé l'inventaire : il ne bouge plus tant qu'il est ouvert
	if cmd == "ui":
		await _beat(tree, BEAT_FLOW)
		return false
	if dock == null or not DOCK_CMDS.has(cmd) or m.ctrl.in_combat():
		return false
	var gs: GameState = m.gs
	var who := gs.active_char_id
	match cmd:
		"eq":
			dock.replay_show(str(e[2]), int(_norm(e[3])))
		"un":
			dock.replay_show(str(e[2]), -1, str(e[3]))
		"drop":
			dock.replay_show(who, int(_norm(e[2])))
		"sort":
			dock.replay_show(who, -1, "", str(e[2]))
		"drink":
			dock.replay_show(str(e[2]), int(_norm(e[3])))
		"forge":
			if str(e[2]) == "":
				dock.replay_show(who, int(_norm(e[3])))
			else:
				dock.replay_show(str(e[2]), -1, str(e[3]))
	await _beat(tree, BEAT_BEFORE)
	return true

## Après l'action : le volet est redessiné (le résultat reste visible un instant).
static func _show_after(tree: SceneTree, m: Node, e: Array) -> void:
	var dock := _dock_of(m)
	if dock != null:
		dock.replay_refresh(str(e[3]) if str(e[1]) == "sort" else "")
	await _beat(tree, BEAT_AFTER)

## Rejoue `log` sur une nouvelle partie. Options : time_scale (accélération, 1 = temps réel).
## Résultat : {ok, reason, applied, clock_ms, fingerprint, summary}
static func run(tree: SceneTree, cfg: Dictionary, log: Array, opts: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "reason": "", "applied": 0, "clock_ms": 0, "fingerprint": "", "summary": {}, "taint": ""}
	RunLog.replaying = true
	GameClock.manual = true
	var prev_scale := Engine.time_scale
	Engine.time_scale = float(opts.get("time_scale", 1.0))
	var m := await start(tree, cfg)
	var wm: WeakRef = weakref(m)
	if m == null:
		out.reason = "demarrage_impossible"
		return _finish(out, prev_scale)
	var last_ms := 0
	for e in log:
		if not (e is Array) or e.size() < 2:
			out.reason = "entree_invalide"
			return _finish(out, prev_scale)
		var ms := int(e[0])
		if ms < last_ms:
			out.reason = "temps_non_monotone"
			return _finish(out, prev_scale)
		last_ms = ms
		var why: String = await step(tree, m, e, out.applied)
		if why != "":
			out.reason = why
			return _finish(out, prev_scale)
		out.applied += 1
	var ok_end: bool = await _until(tree, func(): return wm.get_ref() == null or wm.get_ref().settled() or wm.get_ref().gs.game_over or wm.get_ref().gs.won, SETTLE_TIMEOUT)
	if not ok_end:
		out.reason = "fin_jamais_au_repos"
		return _finish(out, prev_scale)
	out.ok = true
	out.clock_ms = last_ms
	out.fingerprint = fingerprint(m.gs)
	out.summary = summary(m.gs)
	out.taint = m.gs.run_taint
	return _finish(out, prev_scale)

static func _finish(out: Dictionary, prev_scale: float) -> Dictionary:
	Engine.time_scale = prev_scale
	RunLog.replaying = false
	GameClock.manual = false
	return out

## Résultat de la partie tel que les règles le calculent (c'est ce que le serveur classe).
static func summary(gs: GameState) -> Dictionary:
	var dims: Dictionary = gs.cfg.get("genDims") if gs.cfg.get("genDims") is Dictionary else {}
	return {
		"levelsCleared": int(gs.stats.get("levelsCleared", 0)),
		"kills": int(gs.stats.get("monstersKilled", 0)),
		"gold": int(gs.stats.get("goldEarnedTotal", 0)),
		"bosses": int(gs.stats.get("bossesKilled", 0)),
		"traps": int(gs.stats.get("trapsTriggered", 0)),
		"expeditions": gs.run_number,
		"difficulty": str(gs.cfg.get("genDifficulty", "")),
		"levels": int(dims.get("numLevels", 0)),
		"game_over": gs.game_over,
		"won": gs.won,
	}

## Empreinte de l'état de la partie (sert à comparer une partie jouée en direct et son rejeu).
static func fingerprint(gs: GameState) -> String:
	return dump(gs).md5_text()

## Retire ce qui est purement visuel (aspect en miroir d'un membre de groupe) avant de comparer deux états.
static func _strip(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if str(k) != "mirrorSlot":
				out[k] = _strip(v[k])
		return out
	if v is Array:
		var arr: Array = []
		for x in v:
			arr.append(_strip(x))
		return arr
	return v

## Texte (JSON à clés triées) dont `fingerprint` est l'empreinte : sert à comparer deux états quand ils diffèrent.
static func dump(gs: GameState) -> String:
	var stats := gs.stats.duplicate(true)
	stats.erase("playSeconds")
	stats.erase("runId")
	var d := {
		"party": gs.party, "gold": gs.gold, "inventory": gs.inventory, "level_states": _strip(gs.level_states), "stats": stats,
		"level_index": gs.level_index, "run_number": gs.run_number, "game_over": gs.game_over, "won": gs.won,
		"rng": GameRng.export_state(), "active": gs.active_char_id,
	}
	return JSON.stringify(d, "  ", true)
