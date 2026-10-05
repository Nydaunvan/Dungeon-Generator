class_name Wanderers
extends Node
## Errance des monstres (patrouille, poursuite en ligne droite) et du marchand itinérant. Portage du ticker JS (500 ms).

signal merchant_moved
signal monsters_moved

const TICK := 0.5
const CHASE_CHANCE := 0.25
const WANDER_CHANCE := 0.15
const WANDER_CHANCE_BOSS := 0.10

var gs: GameState
var ctrl: CombatController
var rig: PlayerRig
var level: Dictionary = {}
var grid: DungeonGrid
var view: LevelView
var paused_if: Callable = Callable()   # () -> bool : une fenêtre est ouverte, le volet est déployé…
var _acc: float = 0.0
var _zones: Dictionary = {}            # id -> { Vector2i: true }

func setup(state: GameState, controller: CombatController, r: PlayerRig) -> void:
	gs = state
	ctrl = controller
	rig = r

func bind_level(lvl: Dictionary, g: DungeonGrid, v: LevelView) -> void:
	level = lvl
	grid = g
	view = v
	_zones.clear()
	_acc = 0.0
	# monstres qui ont changé de place lors d'un passage précédent ou avant une sauvegarde
	var st_all: Dictionary = gs.level_state(lvl).monsters
	for m in lvl.get("monsters", []):
		var st: Dictionary = st_all.get(str(m.id), {})
		if not st.is_empty() and st.alive and (int(st.x) != int(m.x) or int(st.y) != int(m.y)):
			v.entities.move_monster(str(m.id), int(st.x), int(st.y), true)
	var tm = lvl.get("travelingMerchant")
	if tm is Dictionary:
		var ls := gs.level_state(lvl)
		if not ls.has("merchant"):
			ls["merchant"] = {"x": int(tm.x), "y": int(tm.y), "discovered": false, "offers": null}
		var m: Dictionary = ls.merchant
		v.entities.add_merchant(int(m.x), int(m.y), bool(lvl.get("outdoor", false)))

func merchant() -> Dictionary:
	if level.is_empty() or not (level.get("travelingMerchant") is Dictionary):
		return {}
	return gs.level_state(level).get("merchant", {})

func _process(delta: float) -> void:
	if grid == null or gs.game_over or gs.won:
		return
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	if ctrl.in_combat() or (paused_if.is_valid() and paused_if.call()):
		return
	_tick()

# ------------------------------------------------------------------ helpers

func _monster_cells(except_id: String = "") -> Dictionary:
	var out := {}
	var ls := gs.level_state(level)
	for m in level.get("monsters", []):
		var st: Dictionary = ls.monsters.get(str(m.id), {})
		if st.is_empty() or not st.alive or st.hidden or str(m.id) == except_id:
			continue
		out[Vector2i(int(st.x), int(st.y))] = true
	return out

func _free(p: Vector2i, except_id: String, include_merchant: bool = true) -> bool:
	if not grid.is_walkable(p.x, p.y):
		return false
	if p == Vector2i(rig.gx, rig.gy):
		return false
	if _monster_cells(except_id).has(p):
		return false
	if include_merchant:
		var mm := merchant()
		if not mm.is_empty() and p == Vector2i(int(mm.x), int(mm.y)):
			return false
	return true

## Zone de patrouille : cases atteignables en `radius` pas depuis (ox, oy).
func _zone(key: String, ox: int, oy: int, radius: int) -> Dictionary:
	if _zones.has(key):
		return _zones[key]
	var seen := {Vector2i(ox, oy): 0}
	var queue: Array = [Vector2i(ox, oy)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var d: int = seen[c]
		if d >= radius:
			continue
		for v in DungeonGrid.DIRS:
			var n: Vector2i = c + v
			if not seen.has(n) and grid.is_walkable(n.x, n.y):
				seen[n] = d + 1
				queue.append(n)
	_zones[key] = seen
	return seen

func _has_los(from: Vector2i, to: Vector2i) -> bool:
	if from.x != to.x and from.y != to.y:
		return false
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var c := from + step
	while c != to:
		if not grid.is_walkable(c.x, c.y):
			return false
		c += step
	return true

func _wander_target(from: Vector2i, zone: Dictionary, except_id: String) -> Vector2i:
	var dirs := DungeonGrid.DIRS.duplicate()
	dirs.shuffle()
	for v in dirs:
		var n: Vector2i = from + v
		if zone.has(n) and _free(n, except_id):
			return n
	return Vector2i(-1, -1)

# ------------------------------------------------------------------ tick

func _tick() -> void:
	var ls := gs.level_state(level)
	var player := Vector2i(rig.gx, rig.gy)
	var movers: Array = []
	for m in level.get("monsters", []):
		var st: Dictionary = ls.monsters.get(str(m.id), {})
		if st.is_empty() or not st.alive or st.hidden:
			continue
		movers.append({"def": m, "st": st, "pos": Vector2i(int(st.x), int(st.y))})
	# meneur : le monstre avec vue directe sur le joueur le plus proche
	var lead := ""
	var best := 1 << 30
	for e in movers:
		var d: int = absi(e.pos.x - player.x) + absi(e.pos.y - player.y)
		if d > 1 and d < best and _has_los(e.pos, player):
			best = d
			lead = str(e.def.id)
	var engaged := false
	for e in movers:
		var id := str(e.def.id)
		var p: Vector2i = e.pos
		if absi(p.x - player.x) + absi(p.y - player.y) <= 1:
			continue
		var target := Vector2i(-1, -1)
		if id == lead:
			if randf() < CHASE_CHANCE:
				var step := Vector2i(signi(player.x - p.x), signi(player.y - p.y))
				if _free(p + step, id):
					target = p + step
		elif int(e.def.get("patrolRadius", 0)) > 0:
			if randf() < (WANDER_CHANCE_BOSS if bool(e.def.get("isBoss", false)) else WANDER_CHANCE):
				var zone := _zone(id, int(e.def.x), int(e.def.y), int(e.def.patrolRadius))
				target = _wander_target(p, zone, id)
		if target.x < 0:
			continue
		e.st["x"] = target.x
		e.st["y"] = target.y
		view.entities.move_monster(id, target.x, target.y)
		if id == lead:
			var dist_after := absi(target.x - player.x) + absi(target.y - player.y)
			Sound.sfx("monster_approach", maxf(0.15, 1.0 - (dist_after - 1) / 6.0))
		if absi(target.x - player.x) + absi(target.y - player.y) <= 1:
			engaged = true
	_tick_merchant()
	if engaged or movers.any(func(e): return int(e.st.x) != int(e.pos.x) or int(e.st.y) != int(e.pos.y)):
		monsters_moved.emit()
	if engaged:
		# le monstre arrive au contact : on attend la fin du glissement avant d'engager le combat
		get_tree().create_timer(0.45).timeout.connect(func():
			if not gs.game_over:
				ctrl.refresh())

func _tick_merchant() -> void:
	var mm := merchant()
	if mm.is_empty():
		return
	var tm: Dictionary = level.travelingMerchant
	if true:   # le marchand ambulant ne bouge plus : place fixe contre un mur de fond
		return
	var zone := _zone("__merchant", int(tm.x), int(tm.y), int(tm.patrolRadius))
	var t := _wander_target(Vector2i(int(mm.x), int(mm.y)), zone, "")
	if t.x < 0:
		return
	mm["x"] = t.x
	mm["y"] = t.y
	view.entities.move_merchant(t.x, t.y)
	merchant_moved.emit()
