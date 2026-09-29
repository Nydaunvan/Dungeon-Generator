class_name Combat
extends RefCounted
## Combat au tour par tour — portage fidèle de la logique JS (jauges, attaque physique, riposte, mort, butin).
## Aucune notion de temps réel ici : le contrôleur gère les délais. Les effets visibles passent par `events`.
##
## Jauges : chaque participant a une jauge 0..100 qui se remplit à sa vitesse ; le premier à atteindre 100 agit.

var gs: GameState
var level: Dictionary
var grid: DungeonGrid
var pos: Vector2i = Vector2i.ZERO
var dir: int = 0
var gauges: Dictionary = {}
var turn_seq: int = 0
var events: Array = []    # {"type": "popup"|"door_open"|"monster_died"|"game_over"|"loot", ...}

func _init(state: GameState, lvl: Dictionary, g: DungeonGrid) -> void:
	gs = state
	level = lvl
	grid = g

func lstate() -> Dictionary:
	return gs.level_state(level)

func monster_def(id: String) -> Dictionary:
	for m in level.get("monsters", []):
		if str(m.id) == id:
			return m
	return {}

func _live(m: Dictionary) -> bool:
	var st: Dictionary = lstate().monsters.get(str(m.id), {})
	return not st.is_empty() and st.alive and not st.hidden

## Monstre vivant sur la case (x, y), ou {}.
func monster_at(x: int, y: int) -> Dictionary:
	for m in level.get("monsters", []):
		var st: Dictionary = lstate().monsters.get(str(m.id), {})
		if not st.is_empty() and st.alive and not st.hidden and st.x == x and st.y == y:
			return m
	return {}

## Premier monstre adjacent (direction du regard d'abord). Renvoie {"monster": def, "dir": int} ou {}.
func engaged() -> Dictionary:
	for k in 4:
		var di := (dir + k) % 4
		var v: Vector2i = DungeonGrid.DIRS[di]
		var m := monster_at(pos.x + v.x, pos.y + v.y)
		if not m.is_empty():
			return {"monster": m, "dir": di}
	return {}

func in_combat() -> bool:
	return not gs.game_over and not engaged().is_empty()

func front_monster() -> Dictionary:
	var v: Vector2i = DungeonGrid.DIRS[dir]
	return monster_at(pos.x + v.x, pos.y + v.y)

# ------------------------------------------------------------------ jauges

func participant_speed(key: String) -> float:
	if key.begins_with("char_"):
		var c := gs.char_by_id(key.substr(5))
		return maxf(1.0, float(c.get("effSpeed", 10))) if (not c.is_empty() and int(c.hp) > 0) else 0.0
	var rest := key.substr(4)
	var hash_idx := rest.find("#")
	var mid := rest if hash_idx < 0 else rest.substr(0, hash_idx)
	var mi := -1 if hash_idx < 0 else int(rest.substr(hash_idx + 1))
	var def := monster_def(mid)
	var st: Dictionary = lstate().monsters.get(mid, {})
	if def.is_empty() or st.is_empty() or not st.alive:
		return 0.0
	if mi >= 0 and (not st.has("members") or mi >= st.members.size() or not st.members[mi].alive):
		return 0.0
	var base := float(def.get("speed", 8))
	var count: int = st.members.size() if (mi >= 0 and st.has("members")) else 1
	return maxf(1.0, round(base / count))

func ensure_gauges() -> void:
	var wanted := {}
	for c in gs.party:
		if int(c.hp) > 0:
			wanted["char_" + str(c.id)] = true
	var eng := engaged()
	if not eng.is_empty():
		var m: Dictionary = eng.monster
		var st: Dictionary = lstate().monsters[str(m.id)]
		if m.get("isGroup", false) and st.has("members"):
			for i in st.members.size():
				if st.members[i].alive:
					wanted["mon_%s#%d" % [m.id, i]] = true
		else:
			wanted["mon_" + str(m.id)] = true
	for k in wanted:
		if not gauges.has(k):
			gauges[k] = 0.0
	for k in gauges.keys():
		if not wanted.has(k):
			gauges.erase(k)

## Fait avancer les jauges jusqu'au prochain participant prêt ; renvoie sa clé ("" si personne).
func advance_gauges_once() -> String:
	var min_time := INF
	var ready := ""
	for k in gauges:
		var speed := participant_speed(k)
		if speed <= 0.0:
			continue
		var t := maxf(0.0, 100.0 - float(gauges[k])) / speed
		if t < min_time - 1e-9:
			min_time = t
			ready = k
	if ready == "":
		return ""
	for k in gauges:
		var speed := participant_speed(k)
		if speed > 0.0:
			gauges[k] = float(gauges[k]) + speed * min_time
	gauges[ready] = 100.0
	return ready

## Prochain à agir : {"kind":"char","id"} | {"kind":"monster","key"} | {"kind":"none"}.
func advance() -> Dictionary:
	ensure_gauges()
	var safety := 0
	while safety < 30:
		var key := advance_gauges_once()
		if key == "":
			return {"kind": "none"}
		if key.begins_with("char_"):
			var c := gs.char_by_id(key.substr(5))
			if c.is_empty() or int(c.hp) <= 0:
				gauges[key] = 0.0
				safety += 1
				continue
			gs.active_char_id = str(c.id)
			return {"kind": "char", "id": c.id}
		return {"kind": "monster", "key": key}
	return {"kind": "none"}

func can_act(c: Dictionary) -> bool:
	if not in_combat():
		return false
	ensure_gauges()
	return gs.active_char_id == str(c.id) and float(gauges.get("char_" + str(c.id), 0.0)) >= 100.0

func skip_turn(c: Dictionary) -> void:
	gauges["char_" + str(c.id)] = 0.0
	turn_seq += 1

# ------------------------------------------------------------------ attaque du joueur

## Attaque physique du personnage prêt sur le monstre en face. Renvoie true si l'attaque a eu lieu.
func player_attack(attacker: Dictionary) -> bool:
	if gs.game_over or gs.won:
		return false
	var target := front_monster()
	if target.is_empty():
		gs.add_log("Il n'y a rien à attaquer devant vous.")
		return false
	if not can_act(attacker):
		gs.add_log("🔄 %s doit laisser un allié agir avant de pouvoir agir à nouveau." % attacker.name, true)
		return false
	var st: Dictionary = lstate().monsters[str(target.id)]
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var cost := mini(int(sta.get("attackCost", 0)), 2)
	attacker["stamina"] = maxi(0, int(attacker.get("stamina", 0)) - cost)

	var dmg := randi_range(int(attacker.atkMin), int(attacker.atkMax))
	var resist := int(target.get("resistPhys", 0))
	var raw := dmg
	if resist > 0:
		dmg = 0 if resist >= 100 else maxi(1, int(round(dmg * (1.0 - resist / 100.0))))
	var crit := false
	var crit_chance := int(attacker.get("talentCritChance", 0))
	if crit_chance > 0 and randf() < crit_chance / 100.0:
		dmg *= 2
		crit = true

	# cible : premier membre vivant d'un groupe, sinon le monstre lui-même
	var hp_holder: Dictionary = st
	if target.get("isGroup", false) and st.has("members"):
		for mem in st.members:
			if mem.alive:
				hp_holder = mem
				break
	hp_holder["hp"] = float(hp_holder.hp) - dmg
	_add_contrib(st, str(attacker.id), dmg)
	lstate()["last_engaged_id"] = str(target.id)
	if target.get("isBoss", false) and not st.enraged and int(target.get("enrageThreshold", 0)) > 0 \
			and st.hp > 0 and st.hp <= st.maxHp * (int(target.enrageThreshold) / 100.0):
		st["enraged"] = true
		gs.add_log("😡 %s entre en rage, ses attaques deviennent bien plus violentes !" % _mname(target))
	var note := (" (%d%% de résistance physique : %d→%d)" % [resist, raw, dmg]) if resist > 0 else ""
	gs.add_log("%s frappe %s pour %d dégâts%s%s." % [attacker.name, _mname(target), dmg, note, " 💥 Coup critique !" if crit else ""], true)
	events.append({"type": "popup", "text": "-%d" % dmg, "color": Color("ff6a6a") if crit else Color("ffd88a")})

	var lifesteal := int(attacker.get("talentLifestealPct", 0))
	if lifesteal > 0 and dmg > 0:
		var heal := maxi(1, int(round(dmg * lifesteal / 100.0)))
		var before := int(attacker.hp)
		attacker["hp"] = mini(int(attacker.maxHp), before + heal)
		if int(attacker.hp) > before:
			gs.add_log("🩸 %s draine %d PV." % [attacker.name, int(attacker.hp) - before], true)

	if float(hp_holder.hp) <= 0.0:
		hp_holder["alive"] = false
	var all_dead := true
	if target.get("isGroup", false) and st.has("members"):
		for mem in st.members:
			if mem.alive:
				all_dead = false
	else:
		all_dead = float(st.hp) <= 0.0
	if all_dead:
		st["alive"] = false
		_handle_death(target, st)
	elif target.get("isGroup", false) and not hp_holder.alive:
		gs.add_log("💀 %s perd un membre du groupe !" % _mname(target))
	_mark_acted(attacker)
	return true

func _mark_acted(c: Dictionary) -> void:
	gauges["char_" + str(c.id)] = 0.0
	turn_seq += 1
	# gain d'endurance de fin de tour (staminaSettings.turnGain), tant qu'un combat se poursuit
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var gain := int(sta.get("turnGain", 3))
	if gain > 0 and in_combat():
		for p in gs.alive_party():
			p["stamina"] = mini(int(p.get("maxStamina", 100)), int(p.get("stamina", 0)) + gain)

func _add_contrib(st: Dictionary, char_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	st.contrib[char_id] = float(st.contrib.get(char_id, 0.0)) + amount

func _mname(def: Dictionary) -> String:
	return str(def.name) + (" (Boss)" if def.get("isBoss", false) else "")

# ------------------------------------------------------------------ riposte des monstres

## Le monstre dont la jauge est pleine agit (clé "mon_<id>" ou "mon_<id>#<membre>").
func monster_act(key: String) -> void:
	var rest := key.substr(4)
	var hash_idx := rest.find("#")
	var mid := rest if hash_idx < 0 else rest.substr(0, hash_idx)
	var mi := -1 if hash_idx < 0 else int(rest.substr(hash_idx + 1))
	var def := monster_def(mid)
	var st: Dictionary = lstate().monsters.get(mid, {})
	var member_alive: bool = mi < 0 or (st.has("members") and mi < st.members.size() and bool(st.members[mi].alive))
	if not def.is_empty() and not st.is_empty() and st.alive and member_alive:
		_monster_attack_party(def, st)
	gauges[key] = 0.0
	turn_seq += 1
	ensure_gauges()

func _monster_attack_party(def: Dictionary, st: Dictionary) -> void:
	var alive := gs.alive_party()
	if alive.is_empty():
		return
	var pool := alive.filter(func(c): return str(c.id) != gs.last_attacker_id)
	if pool.is_empty():
		pool = alive
	var victim: Dictionary = pool[randi() % pool.size()]
	var dmg := randi_range(int(st.atkMin), int(st.atkMax))
	if st.enraged:
		dmg = int(round(dmg * (1.0 + int(def.get("enrageBonusPct", 30)) / 100.0)))
	if int(victim.get("shieldAmount", 0)) > 0 and dmg > 0:
		var absorbed := mini(int(victim.shieldAmount), dmg)
		victim["shieldAmount"] = int(victim.shieldAmount) - absorbed
		dmg -= absorbed
		gs.add_log("🛡️ Le bouclier de %s absorbe %d dégâts%s." % [victim.name, absorbed, " (épuisé)" if int(victim.shieldAmount) <= 0 else ""], true)
	victim["hp"] = maxi(0, int(victim.hp) - dmg)
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	victim["stamina"] = mini(int(victim.get("maxStamina", 100)), int(victim.get("stamina", 0)) + int(sta.get("hitGain", 0)))
	gs.last_attacker_id = str(victim.id)
	gs.add_log("%s attaque et blesse %s (%d dégâts)%s." % [_mname(def), victim.name, dmg, " 😡" if st.enraged else ""], true)
	events.append({"type": "popup", "text": "%s -%d" % [victim.name, dmg], "color": Color("ff5050")})
	events.append({"type": "hit", "char": victim.id})
	if int(victim.hp) <= 0:
		gs.add_log("💀 %s tombe au combat." % victim.name)
		if gs.alive_party().is_empty():
			gs.game_over = true
			gs.add_log("☠️ Toute l'équipe a péri…")
			events.append({"type": "game_over"})

# ------------------------------------------------------------------ mort d'un monstre

func _handle_death(def: Dictionary, st: Dictionary) -> void:
	gs.add_log("%s s'effondre, vaincu !" % _mname(def))
	var group_mult := 1.0
	if def.get("isGroup", false):
		group_mult = 2.0 if int(def.get("groupSize", 2)) == 3 else 1.5
	var xp := int(round(int(def.get("xpReward", 0)) * group_mult))
	var gold := int(round(int(def.get("goldReward", 0)) * group_mult))
	_split_xp(st, xp)
	gs.stats["monstersKilled"] += 1
	if def.get("isBoss", false):
		gs.stats["bossesKilled"] += 1
	gs.stats["xpEarnedTotal"] += xp
	if gold > 0:
		gs.gold += gold
		gs.stats["goldEarnedTotal"] += gold
		gs.add_log("💰 Le groupe récupère %d pièces d'or." % gold)
	if str(def.get("opensDoorId", "")) != "":
		gs.add_log("La mort de %s déverrouille une porte au loin..." % _mname(def))
		events.append({"type": "door_open", "id": str(def.opensDoorId)})
	for k in [["lootItemId", "lootChance"], ["lootItemId2", "lootChance2"]]:
		var item_id := str(def.get(k[0], ""))
		if item_id == "":
			continue
		if randi_range(1, 100) <= int(def.get(k[1], 100)):
			for it in level.get("items", []):
				if str(it.id) == item_id:
					gs.inventory.append(it.duplicate(true))
					gs.stats["itemsFound"] += 1
					gs.add_log("🎁 %s laisse tomber %s !" % [_mname(def), it.name])
					events.append({"type": "loot", "name": str(it.name)})
	# endurance récupérée après la victoire (difficulté « normal »)
	var pct_map: Dictionary = (gs.cfg.get("staminaSettings", {}) as Dictionary).get("victoryGainPct", {"normal": 6})
	var pct := int(pct_map.get("normal", 6))
	if pct > 0:
		for c in gs.alive_party():
			var gain := int(round(int(c.get("maxStamina", 100)) * pct / 100.0))
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + gain)
	events.append({"type": "monster_died", "id": str(def.id)})
	gauges.clear()

func _split_xp(st: Dictionary, total: int) -> void:
	var entries: Array = []
	var weight := 0.0
	for cid in st.contrib:
		if float(st.contrib[cid]) > 0.0:
			entries.append(cid)
			weight += float(st.contrib[cid])
	if entries.is_empty():
		var a := gs.char_by_id(gs.active_char_id)
		if not a.is_empty():
			Characters.award_xp(gs, a, total)
		return
	var shares: Array[String] = []
	for cid in entries:
		var c := gs.char_by_id(str(cid))
		if c.is_empty():
			continue
		var share := int(round(total * float(st.contrib[cid]) / weight))
		if share <= 0 or int(c.hp) <= 0:
			continue
		Characters.award_xp(gs, c, share)
		shares.append("%s +%d" % [c.name, share])
	if shares.size() > 1:
		gs.add_log("✨ XP répartie selon la contribution au combat : %s." % ", ".join(shares))

# ------------------------------------------------------------------ fuite

## Le groupe fuit vers la case sûre la plus proche (jamais adjacente à un monstre ni visible de lui).
## Renvoie la case, ou (-1,-1) si aucune n'est trouvée.
func flee() -> Vector2i:
	var dest := _safe_destination()
	for c in gs.alive_party():
		c["stamina"] = int(floor(int(c.get("stamina", 0)) * 0.5))
	gs.add_log("🏃 Le groupe prend la fuite ! Chacun perd la moitié de son endurance dans la précipitation.")
	gauges.clear()
	return dest

func _alive_monster_cells() -> Array:
	var out: Array = []
	for m in level.get("monsters", []):
		var st: Dictionary = lstate().monsters.get(str(m.id), {})
		if not st.is_empty() and st.alive and not st.hidden:
			out.append(Vector2i(st.x, st.y))
	return out

func _is_safe(p: Vector2i, cells: Array) -> bool:
	for c in cells:
		if maxi(absi(c.x - p.x), absi(c.y - p.y)) <= 1:
			return false
		if _line_of_sight(c, p):
			return false
	return true

func _line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps):
		var t := float(i) / steps
		var x := int(round(lerpf(a.x, b.x, t)))
		var y := int(round(lerpf(a.y, b.y, t)))
		if not grid.is_walkable(x, y):
			return false
	return true

func _safe_destination() -> Vector2i:
	var cells := _alive_monster_cells()
	var visited := {pos: true}
	var frontier: Array = [pos]
	for step in 12:
		var next: Array = []
		for cell in frontier:
			for v in DungeonGrid.DIRS:
				var n: Vector2i = cell + v
				if visited.has(n) or not grid.is_walkable(n.x, n.y):
					continue
				visited[n] = true
				if step >= 1 and _is_safe(n, cells):
					return n
				next.append(n)
		frontier = next
		if frontier.is_empty():
			break
	return Vector2i(-1, -1)
