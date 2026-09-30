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
	return maxf(1.0, round(base / count) + Statuses.speed_bonus(st))

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
	return _advance(gauges)

## Prochains participants (clés) dans l'ordre, sans modifier l'état réel (frise d'initiative).
func upcoming(n: int) -> Array:
	ensure_gauges()
	var g: Dictionary = gauges.duplicate()
	var out: Array = []
	for i in n:
		var key := _advance(g)
		if key == "":
			break
		out.append(key)
		g[key] = 0.0
	return out

func _advance(g: Dictionary) -> String:
	var min_time := INF
	var ready := ""
	for k in g:
		var speed := participant_speed(k)
		if speed <= 0.0:
			continue
		var t := maxf(0.0, 100.0 - float(g[k])) / speed
		if t < min_time - 1e-9:
			min_time = t
			ready = k
	if ready == "":
		return ""
	for k in g:
		var speed := participant_speed(k)
		if speed > 0.0:
			g[k] = float(g[k]) + speed * min_time
	g[ready] = 100.0
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
			if Statuses.is_disabled(c):
				var sd: Dictionary = {}
				for e in Statuses.active(c):
					if bool(Statuses.def(str(e.type)).get("disables", false)):
						sd = Statuses.def(str(e.type))
						break
				gs.add_log("%s %s est incapable d'agir ce tour-ci et doit laisser passer son tour." % [sd.get("icon", "😵"), c.name], true)
				tick_char(c)
				gauges[key] = 0.0
				turn_seq += 1
				safety += 1
				if gs.game_over:
					return {"kind": "none"}
				continue
			gs.active_char_id = str(c.id)
			return {"kind": "char", "id": c.id}
		return {"kind": "monster", "key": key}
	return {"kind": "none"}

func skip_turn(c: Dictionary) -> void:
	tick_char(c)
	gauges["char_" + str(c.id)] = 0.0
	turn_seq += 1

# ------------------------------------------------------------------ attaque du joueur

## True si ce personnage peut agir maintenant (hors combat : toujours ; en combat : c'est son tour).
func may_act(c: Dictionary) -> bool:
	if not in_combat():
		return true
	ensure_gauges()
	return gs.active_char_id == str(c.id) and float(gauges.get("char_" + str(c.id), 0.0)) >= 100.0

func can_act(c: Dictionary) -> bool:
	return in_combat() and may_act(c)

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
	if _blocked_by_status(attacker):
		return false
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var cost := mini(int(sta.get("attackCost", 0)), 2)
	attacker["stamina"] = maxi(0, int(attacker.get("stamina", 0)) - cost)
	var dmg := randi_range(int(attacker.atkMin), int(attacker.atkMax)) + Statuses.flat_damage_bonus(attacker)
	_hit_monster(attacker, target, dmg, false, "frappe", false, false)
	_mark_acted(attacker)
	return true

# ------------------------------------------------------------------ sorts

const SUPPORTED_MODES := ["damage", "damageGroup", "healSingle", "healParty", "staminaRestoreSingle", "shieldSingle",
	"dispelSingle", "sleepGroup", "selfBuff", "partyUtility"]

## Un personnage étourdi ou gelé ne peut ni attaquer ni lancer de sort.
func _blocked_by_status(c: Dictionary) -> bool:
	if not Statuses.is_disabled(c):
		return false
	var icon := "😵"
	var label := "un statut"
	for e in Statuses.active(c):
		var d := Statuses.def(str(e.type))
		if bool(d.get("disables", false)):
			icon = str(d.icon)
			label = str(d.label)
			break
	gs.add_log("%s %s est affecté par %s et ne peut pas agir !" % [icon, c.name, label], true)
	return true

func spell_def(spell_id: String) -> Dictionary:
	for sp in gs.cfg.get("spells", []):
		if sp.get("id") == spell_id:
			return sp
	return {}

func spell_needs_ally(spell: Dictionary) -> bool:
	return ["healSingle", "staminaRestoreSingle", "shieldSingle", "dispelSingle"].has(str(spell.get("mode", "")))

## Secondes restantes avant que le sort soit de nouveau lançable.
func cooldown_left(caster: Dictionary, spell_id: String) -> float:
	var ready_at := int((caster.get("spellCooldowns", {}) as Dictionary).get(spell_id, 0))
	return maxf(0.0, (ready_at - Time.get_ticks_msec()) / 1000.0)

## Lance un sort. `ally_id` = cible alliée pour les sorts ciblés. Renvoie true si le sort a été lancé.
func cast_spell(caster: Dictionary, spell_id: String, ally_id: String = "", free: bool = false) -> bool:
	if gs.game_over or gs.won:
		return false
	var spell := spell_def(spell_id)
	if spell.is_empty() or (not free and not (caster.get("spellsKnown", []) as Array).has(spell_id)):
		gs.add_log("%s ne connaît pas ce sort." % caster.name)
		return false
	var mode := str(spell.get("mode", "damage"))
	if not SUPPORTED_MODES.has(mode):
		gs.add_log("✨ %s : effet pas encore disponible dans cette version." % spell.name)
		return false
	if int(caster.hp) <= 0:
		return false
	if not may_act(caster):
		gs.add_log("🔄 %s doit laisser un allié agir avant de pouvoir agir à nouveau." % caster.name, true)
		return false
	if _blocked_by_status(caster):
		return false
	var left := 0.0 if free else cooldown_left(caster, spell_id)
	if left > 0.0:
		gs.add_log("⏳ %s n'est pas encore prêt (%d s restantes)." % [spell.name, int(ceil(left))])
		return false
	var target := {}
	if mode == "damage" or mode == "damageGroup" or mode == "sleepGroup":
		target = front_monster()
		if target.is_empty():
			gs.add_log("Il n'y a rien à attaquer devant vous.")
			return false
	var ally: Dictionary = {}
	if spell_needs_ally(spell):
		ally = gs.char_by_id(ally_id)
		if ally.is_empty():
			gs.add_log("Choisissez un allié pour %s." % spell.name)
			return false
		if int(ally.hp) <= 0:
			gs.add_log("💀 %s est mort et ne peut pas être ciblé." % ally.name)
			return false
	var cost := 0 if free else int(spell.get("staminaCost", 15))
	if int(caster.get("stamina", 0)) < cost:
		gs.add_log("😮‍💨 %s n'a plus assez d'endurance pour lancer %s." % [caster.name, spell.name])
		return false
	caster["stamina"] = int(caster.stamina) - cost
	if not free:
		var cds: Dictionary = caster.get("spellCooldowns", {})
		cds[spell_id] = Time.get_ticks_msec() + int(float(spell.get("cooldownSec", 6)) * 1000.0)
		caster["spellCooldowns"] = cds
	var bonus := int(caster.get("bonusSpellDmg", 0)) + int(floor((int(caster.level) - 1) * 0.75))
	var verb := "lance %s %s sur" % [spell.get("icon", ""), spell.name]
	match mode:
		"damage", "damageGroup":
			var int_bonus := int(floor(int(caster.get("effInt", 10)) / 5.0)) + bonus
			var dmg := randi_range(int(spell.get("dmgMin", 0)) + int_bonus, int(spell.get("dmgMax", 0)) + int_bonus)
			var magic: bool = str(spell.get("style", "")) != "physical"
			_hit_monster(caster, target, dmg, magic, verb, mode == "damageGroup", bool(spell.get("ignoreAllResist", false)), spell)
		"healSingle":
			var amt := randi_range(int(spell.get("healMin", 0)) + bonus, int(spell.get("healMax", 0)) + bonus)
			var before := int(ally.hp)
			ally["hp"] = mini(int(ally.maxHp), before + maxi(0, amt))
			var healed := int(ally.hp) - before
			gs.add_log("%s lance %s %s sur %s%s." % [caster.name, spell.get("icon", ""), spell.name, ally.name,
				(" et soigne %d PV" % healed) if healed > 0 else ""], true)
			_credit_heal(caster, healed)
			events.append({"type": "popup", "text": "+%d" % healed, "color": Color("7fd17f")})
			Statuses.apply_from_spell(gs, spell, ally, str(ally.name), str(caster.id), true)
			Characters.recompute(ally, gs.cfg)
		"healParty":
			var details: Array[String] = []
			var total := 0
			for c in gs.alive_party():
				var amt := randi_range(int(spell.get("healMin", 0)) + bonus, int(spell.get("healMax", 0)) + bonus)
				var before := int(c.hp)
				c["hp"] = mini(int(c.maxHp), before + amt)
				var healed := int(c.hp) - before
				total += healed
				if healed > 0:
					details.append("%s +%d" % [c.name, healed])
			gs.add_log("%s lance %s %s et soigne tout le groupe : %s." % [caster.name, spell.get("icon", ""), spell.name,
				", ".join(details) if not details.is_empty() else "personne n'avait besoin de soin"], true)
			_credit_heal(caster, total)
			events.append({"type": "popup", "text": "✨ Groupe soigné ✨", "color": Color("7fd17f")})
		"staminaRestoreSingle":
			var amt := randi_range(int(spell.get("staminaMin", 0)), int(spell.get("staminaMax", 0)))
			var before := int(ally.get("stamina", 0))
			ally["stamina"] = mini(int(ally.get("maxStamina", 100)), before + maxi(0, amt))
			var got := int(ally.stamina) - before
			gs.add_log("%s lance %s %s sur %s%s." % [caster.name, spell.get("icon", ""), spell.name, ally.name,
				(" et restaure %d endurance" % got) if got > 0 else ""], true)
			events.append({"type": "popup", "text": "+%d ⚡" % got, "color": Color("7fd1c9")})
			Statuses.apply_from_spell(gs, spell, ally, str(ally.name), str(caster.id), true)
		"shieldSingle":
			var amt := randi_range(int(spell.get("shieldMin", 0)), int(spell.get("shieldMax", 0)))
			ally["shieldAmount"] = int(ally.get("shieldAmount", 0)) + maxi(0, amt)
			gs.add_log("%s lance %s %s sur %s et l'entoure d'un bouclier de %d." % [caster.name, spell.get("icon", ""), spell.name, ally.name, amt], true)
			events.append({"type": "popup", "text": "🛡️ %d" % amt, "color": Color("8fc8e8")})
		"dispelSingle":
			var removed := Statuses.dispel(ally)
			Characters.recompute(ally, gs.cfg)
			if removed.is_empty():
				gs.add_log("%s lance %s %s sur %s, qui n'était affecté par rien de négatif." % [caster.name, spell.get("icon", ""), spell.name, ally.name], true)
			else:
				gs.add_log("%s lance %s %s sur %s et dissipe %s." % [caster.name, spell.get("icon", ""), spell.name, ally.name, ", ".join(removed)], true)
			events.append({"type": "popup", "text": "✨ Purifié", "color": Color("8fc8e8")})
		"sleepGroup":
			var tst: Dictionary = lstate().monsters[str(target.id)]
			var boss := bool(target.get("isBoss", false))
			var eff_spell: Dictionary = spell.duplicate()
			eff_spell["statusEffect"] = "slow" if boss else "stun"
			eff_spell["statusDuration"] = int(spell.get("statusDuration", 3)) if boss else maxi(1, int(round(int(spell.get("statusDuration", 3)) / 2.0)))
			gs.add_log("%s lance %s %s sur %s." % [caster.name, spell.get("icon", ""), spell.name, _mname(target)], true)
			if not Statuses.apply_from_spell(gs, eff_spell, tst, _mname(target), str(caster.id), false):
				gs.add_log("💤 %s résiste à la berceuse." % _mname(target))
			events.append({"type": "popup", "text": "💤", "color": Color("b9a0ff")})
		"selfBuff":
			gs.add_log("%s lance %s %s." % [caster.name, spell.get("icon", ""), spell.name], true)
			Statuses.apply_from_spell(gs, spell, caster, str(caster.name), str(caster.id), true)
			Characters.recompute(caster, gs.cfg)
		"partyUtility":
			var cut_ms := int(float(spell.get("cooldownReductionSec", 0)) * 1000.0)
			var now := Time.get_ticks_msec()
			for c in gs.alive_party():
				var cds: Dictionary = c.get("spellCooldowns", {})
				for sid in cds.keys():
					cds[sid] = maxi(now, int(cds[sid]) - cut_ms)
				Statuses.give(c, "vigor", int(spell.get("statusDuration", 4)), str(caster.id))
				Characters.recompute(c, gs.cfg)
			gs.add_log("%s lance %s %s sur tout le groupe, qui se sent revigoré !" % [caster.name, spell.get("icon", ""), spell.name], true)
			events.append({"type": "popup", "text": "🎶 Vigueur", "color": Color("ffd88a")})
	_mark_acted(caster)
	return true

## Les soins comptent dans la contribution au combat (XP), pondérés par xpSettings.healRatio.
func _credit_heal(caster: Dictionary, healed: int) -> void:
	if healed <= 0:
		return
	var eng := engaged()
	var mid := str(lstate().get("last_engaged_id", ""))
	if not eng.is_empty():
		mid = str(eng.monster.id)
	var st: Dictionary = lstate().monsters.get(mid, {})
	if st.is_empty() or not st.alive:
		return
	var ratio := float((gs.cfg.get("xpSettings", {}) as Dictionary).get("healRatio", 0.8))
	_add_contrib(st, str(caster.id), healed * ratio)

## Applique une attaque (physique ou magique) au monstre visé. `all_members` : frappe tout un groupe.
func _hit_monster(attacker: Dictionary, target: Dictionary, raw_dmg: int, magic: bool, verb: String,
		all_members: bool, ignore_resist: bool, spell: Dictionary = {}) -> void:
	var st: Dictionary = lstate().monsters[str(target.id)]
	var base_resist := int(target.get("resistMagic", 0)) if magic else int(target.get("resistPhys", 0))
	var resist := 0 if ignore_resist else maxi(0, base_resist - Statuses.resist_reduction_pct(st))
	var dmg := raw_dmg
	if resist > 0:
		dmg = 0 if resist >= 100 else maxi(1, int(round(raw_dmg * (1.0 - resist / 100.0))))
	var crit := false
	var crit_chance := int(attacker.get("talentCritChance", 0))
	if crit_chance > 0 and randf() < crit_chance / 100.0:
		dmg *= 2
		crit = true

	var is_group: bool = bool(target.get("isGroup", false)) and st.has("members")
	var holders: Array = []
	if is_group:
		for mem in st.members:
			if mem.alive:
				holders.append(mem)
				if not all_members:
					break
	else:
		holders.append(st)
	for h in holders:
		h["hp"] = float(h.hp) - dmg
		_add_contrib(st, str(attacker.id), dmg)
	lstate()["last_engaged_id"] = str(target.id)
	if bool(target.get("isBoss", false)) and not st.enraged and int(target.get("enrageThreshold", 0)) > 0 \
			and st.hp > 0 and st.hp <= st.maxHp * (int(target.enrageThreshold) / 100.0):
		st["enraged"] = true
		gs.add_log("😡 %s entre en rage, ses attaques deviennent bien plus violentes !" % _mname(target))
	var note := (" (%d%% de résistance : %d→%d)" % [resist, raw_dmg, dmg]) if resist > 0 else ""
	var who := "tout le groupe" if (all_members and is_group) else _mname(target)
	if verb == "frappe":
		gs.add_log("%s frappe %s pour %d dégâts%s%s." % [attacker.name, who, dmg, note, " 💥 Coup critique !" if crit else ""], true)
	else:
		gs.add_log("%s %s %s pour %d dégâts%s%s." % [attacker.name, verb, who, dmg, note, " 💥 Coup critique !" if crit else ""], true)
	events.append({"type": "popup", "text": "-%d" % dmg, "color": Color("ff6a6a") if crit else Color("ffd88a")})

	var lifesteal := int(attacker.get("talentLifestealPct", 0)) + int(spell.get("spellLifestealPct", 0))
	if lifesteal > 0 and dmg > 0:
		var heal := maxi(1, int(round(dmg * lifesteal / 100.0)))
		var before := int(attacker.hp)
		attacker["hp"] = mini(int(attacker.maxHp), before + heal)
		if int(attacker.hp) > before:
			gs.add_log("🩸 %s draine %d PV." % [attacker.name, int(attacker.hp) - before], true)

	for h in holders:
		if float(h.hp) <= 0.0:
			h["alive"] = false
	var all_dead := true
	if is_group:
		for mem in st.members:
			if mem.alive:
				all_dead = false
	else:
		all_dead = float(st.hp) <= 0.0
	if all_dead:
		st["alive"] = false
		_handle_death(target, st)
	elif is_group:
		for h in holders:
			if not h.alive:
				gs.add_log("💀 %s perd un membre du groupe !" % _mname(target))
	if not all_dead and not spell.is_empty():
		Statuses.apply_from_spell(gs, spell, st, _mname(target), str(attacker.id), false)

func _mark_acted(c: Dictionary) -> void:
	tick_char(c)
	if not in_combat():
		return
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
		var stunned := tick_monster(def, st)
		if st.alive and not stunned:
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
	var reduction := Statuses.damage_reduction_pct(st)
	if reduction > 0:
		dmg = maxi(0, int(round(dmg * (1.0 - reduction / 100.0))))
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

# ------------------------------------------------------------------ statuts (tick)

## Fait avancer les statuts d'un personnage d'un tour : dégâts sur la durée, durée restante, fin.
func tick_char(c: Dictionary) -> void:
	if int(c.hp) <= 0 or (c.get("statusEffects", []) as Array).is_empty():
		return
	var remaining: Array = []
	for eff in c.statusEffects:
		var sdef := Statuses.def(str(eff.type))
		if sdef.is_empty():
			continue
		if bool(sdef.get("dot", false)) and int(c.hp) > 0:
			var dmg := maxi(1, int(eff.get("power", 3)))
			c["hp"] = maxi(0, int(c.hp) - dmg)
			gs.add_log("%s %s subit %d dégâts de %s." % [sdef.icon, c.name, dmg, sdef.label], true)
			events.append({"type": "popup", "text": "%s -%d" % [c.name, dmg], "color": Color("c98bff")})
			events.append({"type": "hit", "char": c.id})
			if int(c.hp) <= 0:
				gs.add_log("💀 %s succombe à %s." % [c.name, sdef.label])
				if gs.alive_party().is_empty() and not gs.game_over:
					gs.game_over = true
					gs.add_log("☠️ Toute l'équipe a péri…")
					events.append({"type": "game_over"})
		eff["remaining"] = int(eff.remaining) - 1
		if int(eff.remaining) > 0:
			remaining.append(eff)
		else:
			gs.add_log("%s %s n'est plus affecté par %s." % [sdef.icon, c.name, sdef.label], true)
	c["statusEffects"] = remaining
	Characters.recompute(c, gs.cfg)

## Statuts d'un monstre au début de son action. Renvoie true s'il est étourdi / gelé (il perd son action).
func tick_monster(def: Dictionary, st: Dictionary) -> bool:
	var stunned := false
	if (st.get("statusEffects", []) as Array).is_empty():
		return false
	var remaining: Array = []
	for eff in st.statusEffects:
		var sdef := Statuses.def(str(eff.type))
		if sdef.is_empty():
			continue
		if bool(sdef.get("dot", false)) and float(st.hp) > 0.0:
			var dmg := maxi(1, int(eff.get("power", 3)))
			st["hp"] = maxf(0.0, float(st.hp) - dmg)
			gs.add_log("%s %s subit %d dégâts de %s." % [sdef.icon, _mname(def), dmg, sdef.label])
			events.append({"type": "popup", "text": "-%d" % dmg, "color": Color("c98bff")})
			if bool(sdef.get("heals", false)) and str(eff.get("casterId", "")) != "":
				var caster := gs.char_by_id(str(eff.casterId))
				if not caster.is_empty() and int(caster.hp) > 0:
					var before := int(caster.hp)
					caster["hp"] = mini(int(caster.maxHp), before + dmg)
					if int(caster.hp) > before:
						gs.add_log("🩸 %s draine %d PV." % [caster.name, int(caster.hp) - before], true)
			if float(st.hp) <= 0.0 and st.alive:
				st["alive"] = false
				_handle_death(def, st)
		elif bool(sdef.get("disables", false)):
			stunned = true
			gs.add_log("%s %s est %s et ne peut agir !" % [sdef.icon, _mname(def), "gelé" if str(eff.type) == "freeze" else "étourdi"])
		eff["remaining"] = int(eff.remaining) - 1
		if int(eff.remaining) > 0:
			remaining.append(eff)
		else:
			gs.add_log("%s %s n'est plus affecté par %s." % [sdef.icon, _mname(def), sdef.label])
	st["statusEffects"] = remaining
	return stunned

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
