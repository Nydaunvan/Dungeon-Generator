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
## Participants qui ont déjà joué dans la manche en cours (voir `_advance`) et dernier camp ayant joué.
var acted: Dictionary = {}
var _state: Dictionary = {}
var turn_seq: int = 0
var events: Array = []    # {"type": "popup"|"door_open"|"monster_died"|"game_over"|"loot", ...}

func _init(state: GameState, lvl: Dictionary, g: DungeonGrid) -> void:
	gs = state
	level = lvl
	grid = g

## Bilan du combat en cours (monstres vaincus, XP, or, butin) ; vidé par take_summary().
var summary: Dictionary = {}
var pending_instinct: Dictionary = {}   # coup mortel suspendu en attendant l'appui de « Instinct de survie » : {victim, dmg, def, st, cont}
var debug_roll_pct := -1.0              # tests : force le jet de l'instinct (0 = réussite assurée)

func take_summary() -> Dictionary:
	var s := summary
	summary = {}
	var b: Dictionary = lstate().get("combatBilan", {})
	if not s.is_empty() and not b.is_empty():
		s["rounds"] = int(b.get("rounds", 0))
		s["heroes"] = _bilan_heroes(b)
	lstate().erase("combatBilan")
	return s

## Début de combat : état de départ des compteurs de chaque héros, pour le bilan détaillé. Gardé dans l'état du niveau, donc sauvegardé
## avec la partie (un combat interrompu par une sauvegarde garde son bilan).
func _bilan_begin() -> void:
	var base := {}
	var per: Dictionary = gs.stats.get("perChar", {})
	for c in gs.party:
		var p: Dictionary = per.get(str(c.id), {})
		base[str(c.id)] = {"dealt": int(p.get("damageDealt", 0)), "taken": int(p.get("damageTaken", 0)), "heal": int(p.get("healingDone", 0)),
			"kills": int(p.get("kills", 0)), "actions": int(p.get("actions", 0))}
	lstate()["combatBilan"] = {"base": base, "rounds": 0}

## Par héros : ce qui s'est passé depuis le début du combat.
func _bilan_heroes(b: Dictionary) -> Array:
	var out: Array = []
	var per: Dictionary = gs.stats.get("perChar", {})
	var base: Dictionary = b.get("base", {})
	for c in gs.party:
		var p: Dictionary = per.get(str(c.id), {})
		var b0: Dictionary = base.get(str(c.id), {})
		out.append({"name": str(c.name), "dealt": int(p.get("damageDealt", 0)) - int(b0.get("dealt", 0)),
			"taken": int(p.get("damageTaken", 0)) - int(b0.get("taken", 0)), "heal": int(p.get("healingDone", 0)) - int(b0.get("heal", 0)),
			"kills": int(p.get("kills", 0)) - int(b0.get("kills", 0)), "actions": int(p.get("actions", 0)) - int(b0.get("actions", 0))})
	return out

func _note_summary(def: Dictionary, xp: int, gold: int) -> void:
	if summary.is_empty():
		summary = {"order": [], "counts": {}, "xp": 0, "gold": 0, "loot": []}
	var nm := str(def.get("name", "Monstre"))
	if not summary.counts.has(nm):
		summary.order.append(nm)
	summary.counts[nm] = int(summary.counts.get(nm, 0)) + 1
	summary.xp = int(summary.xp) + xp
	summary.gold = int(summary.gold) + gold

func lstate() -> Dictionary:
	return gs.level_state(level)

func monster_def(id: String) -> Dictionary:
	for m in level.get("monsters", []):
		if str(m.id) == id:
			return m
	return {}

## Capacités des objets équipés (toutes raretés) : [{perk, value, item}].
static func perks(c: Dictionary) -> Array:
	return Rarity.equipped_perks(c)

## Somme d'une capacité sur tout l'équipement du personnage.
static func _perk_value(c: Dictionary, perk: String) -> int:
	return Rarity.perk_sum(c, perk)

## Fin d'un combat : les capacités « une fois par combat » se rechargent.
func end_combat_reset() -> void:
	for c in gs.party:
		c.erase("lastStandUsed")
		c.erase("instinctUsed")

func _live(m: Dictionary) -> bool:
	var st: Dictionary = lstate().monsters.get(str(m.id), {})
	return not st.is_empty() and st.alive and not st.hidden

## Monstre vivant sur la case (x, y), ou {}.
func monster_at(x: int, y: int) -> Dictionary:
	var ms: Dictionary = lstate().monsters
	if _cell_dirty or _cell_frame != Engine.get_process_frames() or not is_same(_cell_src, ms) or _cell_level != level.get("id"):
		_rebuild_cells(ms)
	var m = _cell_idx.get(Vector2i(x, y))
	if m == null:
		return {}
	var st: Dictionary = ms.get(str(m.id), {})
	if not st.is_empty() and st.alive and not st.hidden and st.x == x and st.y == y:
		return m
	# l'index était périmé (mort, apparition, déplacement dans la même image) : on le refait, puis on relit
	_rebuild_cells(ms)
	m = _cell_idx.get(Vector2i(x, y))
	return m if m != null else {}

## Index case → monstre vivant et visible (le premier de la liste en cas de doublon, comme l'ancien parcours). Refait à chaque image,
## et dès qu'un monstre bouge ou apparaît (`mark_monsters_dirty`) ; un résultat périmé est de toute façon revérifié dans `monster_at`.
var _cell_idx: Dictionary = {}
var _cell_dirty := true
var _cell_frame := -1
var _cell_src: Dictionary = {}
var _cell_level = null

func mark_monsters_dirty() -> void:
	_cell_dirty = true

func _rebuild_cells(ms: Dictionary) -> void:
	_cell_idx = {}
	for m in level.get("monsters", []):
		var st: Dictionary = ms.get(str(m.id), {})
		if not st.is_empty() and st.alive and not st.hidden:
			var k := Vector2i(int(st.x), int(st.y))
			if not _cell_idx.has(k):
				_cell_idx[k] = m
	_cell_dirty = false
	_cell_frame = Engine.get_process_frames()
	_cell_src = ms
	_cell_level = level.get("id")

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
	var base := Stats.monster_speed(def)
	# chaque membre d'un groupe agit à la vitesse du monstre (avant, la vitesse était divisée par le nombre de membres : le groupe entier agissait
	# comme un seul monstre et les héros jouaient 2 à 3 fois de suite avant lui)
	return maxf(1.0, round(base) + Statuses.speed_bonus(_status_holder(st, mi)))

func ensure_gauges() -> void:
	var wanted := {}
	for c in gs.party:
		if int(c.hp) > 0:
			wanted["char_" + str(c.id)] = true
	var eng := engaged()
	if not eng.is_empty():
		if not lstate().has("combatBilan"):
			_bilan_begin()
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
	for k in acted.keys():
		if not wanted.has(k):
			acted.erase(k)

## Fait avancer les jauges jusqu'au prochain participant prêt ; renvoie sa clé ("" si personne).
func advance_gauges_once() -> String:
	var key := _advance(gauges, acted, _state)
	if key != "":
		if acted.is_empty():      # `_advance` vient d'ouvrir une nouvelle manche
			var bil: Dictionary = lstate().get("combatBilan", {})
			if not bil.is_empty():
				bil["rounds"] = int(bil.get("rounds", 0)) + 1
		acted[key] = true
		_state["last_side"] = _side(key)
		_state["current"] = key
	return key

## Prochains participants (clés) dans l'ordre, sans modifier l'état réel (frise d'initiative).
func upcoming(n: int) -> Array:
	ensure_gauges()
	var g: Dictionary = gauges.duplicate()
	var done: Dictionary = acted.duplicate()
	var cur := str(_state.get("current", ""))
	var stt: Dictionary = _state.duplicate()
	var out: Array = []
	# celui qui joue en ce moment figure TOUJOURS en tête de la frise (sinon, à égalité, la règle d'alternance des camps pouvait
	# placer au centre l'autre camp, par exemple le héros qui va être frappé pendant le tour du monstre)
	if cur != "" and gauges.has(cur) and float(gauges.get(cur, 0.0)) >= 100.0 and participant_speed(cur) > 0.0:
		out.append(cur)
		g[cur] = 0.0
		done[cur] = true
		stt["last_side"] = _side(cur)
	while out.size() < n:
		var key := _advance(g, done, stt)
		if key == "":
			break
		out.append(key)
		g[key] = 0.0
		done[key] = true
		stt["last_side"] = _side(key)
	return out

## Camp d'un participant : 0 = héros, 1 = monstres.
func _side(key: String) -> int:
	return 0 if key.begins_with("char_") else 1

## Règle d'initiative : personne ne rejoue avant que tous les autres participants vivants aient joué une fois (la « manche » repart alors de zéro).
## Dans une manche, l'ordre est STABLE : vitesse décroissante ; à vitesse égale, les héros avant les monstres, puis l'ordre d'arrivée dans les jauges
## (ordre du groupe). Il ne change que si une vitesse change (bonus ou malus gagné ou perdu) ou si un participant meurt (sa place disparaît, les
## autres ne bougent pas). Les jauges ne servent plus qu'à l'affichage : elles montent selon la vitesse et valent 100 pour celui qui joue.
func _advance(g: Dictionary, done: Dictionary, stt: Dictionary) -> String:
	if legacy_initiative:
		return _advance_legacy(g, done, stt)
	var live: Array = []
	for k in g:
		if participant_speed(k) > 0.0:
			live.append(k)
	if live.is_empty():
		return ""
	var pool: Array = live.filter(func(k): return not done.has(k))
	if pool.is_empty():
		done.clear()
		pool = live
	var ready := ""
	for k in pool:
		if ready == "":
			ready = k
			continue
		var sk := participant_speed(k)
		var sr := participant_speed(ready)
		if sk > sr or (is_equal_approx(sk, sr) and _side(k) < _side(ready)):
			ready = k
	var elapsed := maxf(0.0, 100.0 - float(g[ready])) / participant_speed(ready)
	for k in live:
		g[k] = minf(100.0, float(g[k]) + participant_speed(k) * elapsed)
	g[ready] = 100.0
	return ready

## Ancienne règle (versions < 1.34.0 : jauges, fenêtre d'égalité et alternance des camps). Conservée pour revoir dans le moteur les parties
## enregistrées avec ces versions ; le serveur, lui, rejoue chaque partie avec le code de sa propre version (étiquette Git).
static var legacy_initiative := false

const TIE_WINDOW := 0.5

func _advance_legacy(g: Dictionary, done: Dictionary, stt: Dictionary) -> String:
	var live: Array = []
	for k in g:
		if participant_speed(k) > 0.0:
			live.append(k)
	if live.is_empty():
		return ""
	var pool: Array = live.filter(func(k): return not done.has(k))
	if pool.is_empty():
		done.clear()
		pool = live
	var min_time := INF
	for k in pool:
		min_time = minf(min_time, maxf(0.0, 100.0 - float(g[k])) / participant_speed(k))
	var ready := ""
	var last_side := int(stt.get("last_side", -1))
	for k in pool:
		var t := maxf(0.0, 100.0 - float(g[k])) / participant_speed(k)
		if t > min_time + TIE_WINDOW:
			continue
		if ready == "" or (_side(k) != last_side and _side(ready) == last_side):
			ready = k
	var elapsed := maxf(0.0, 100.0 - float(g[ready])) / participant_speed(ready)
	for k in live:
		g[k] = minf(100.0, float(g[k]) + participant_speed(k) * elapsed)
	g[ready] = 100.0
	return ready

## Ordre complet d'une manche (clés des participants vivants), le plus rapide d'abord : même règle que `_advance`, sans tenir compte de ceux qui ont déjà joué.
## Sert à numéroter les combattants dans la frise (rang 1 = joue en premier dans la manche).
func round_order() -> Array:
	ensure_gauges()
	var keys: Array = []
	for k in gauges:
		if participant_speed(k) > 0.0:
			keys.append(k)
	var idx := {}
	for i in keys.size():
		idx[keys[i]] = i
	keys.sort_custom(func(a, b):
		var sa := participant_speed(a)
		var sb := participant_speed(b)
		if not is_equal_approx(sa, sb):
			return sa > sb
		if _side(a) != _side(b):
			return _side(a) < _side(b)
		return int(idx[a]) < int(idx[b]))
	return keys

## Vitesse effective d'un participant et sa vitesse de base (pour colorer un bonus ou un malus).
func speed_info(key: String) -> Dictionary:
	var eff := int(participant_speed(key))
	var base := eff
	if key.begins_with("char_"):
		var c := gs.char_by_id(key.substr(5))
		if not c.is_empty():
			var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
			base = int(c["baseSpeed"]) if c.has("baseSpeed") else int(cls.get("baseSpeed", 10))
	else:
		var rest := key.substr(4)
		var hi := rest.find("#")
		var def := monster_def(rest if hi < 0 else rest.substr(0, hi))
		if not def.is_empty():
			base = int(maxf(1.0, round(Stats.monster_speed(def))))
	return {"speed": eff, "base": base}

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
				gs.add_log(L.fa(L.t("rules.combat.est_incapable_agir_ce_tour"), [sd.get("icon", "😵"), c.name]), true)
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
		gs.add_log(L.t("rules.combat.il_n_y_a_rien"))
		return false
	if not can_act(attacker):
		gs.add_log(L.fa(L.t("rules.combat.doit_laisser_un_allie_agir"), attacker.name), true)
		return false
	if _blocked_by_status(attacker):
		return false
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var cost := mini(int(sta.get("attackCost", 0)), 2)
	attacker["stamina"] = maxi(0, int(attacker.get("stamina", 0)) - cost)
	var dmg := GameRng.range_i("combat", int(attacker.atkMin), int(attacker.atkMax)) + Statuses.flat_damage_bonus(attacker)
	var wpn_v = (attacker.get("equipment", {}) as Dictionary).get("weapon")
	var wtype := str(wpn_v.get("weaponType", "sword")) if wpn_v is Dictionary else "fist"
	gs.bump(attacker.id, "actions")
	events.append({"type": "fx", "fx": "unarmed" if wtype == "fist" else wtype, "char": str(attacker.id)})
	Sound.attack_standard()
	_hit_monster(attacker, target, dmg, false, "frappe", false, false)
	_mark_acted(attacker, false)
	return true

# ------------------------------------------------------------------ sorts

const SUPPORTED_MODES := ["damage", "damageGroup", "healSingle", "healParty", "staminaRestoreSingle", "shieldSingle",
	"dispelSingle", "sleepGroup", "selfBuff", "partyUtility"]

## Un personnage étourdi ou gelé ne peut ni attaquer ni lancer de sort.
func _blocked_by_status(c: Dictionary) -> bool:
	if not Statuses.is_disabled(c):
		return false
	var icon := "😵"
	var label := L.t("rules.combat.un_statut")
	for e in Statuses.active(c):
		var d := Statuses.def(str(e.type))
		if bool(d.get("disables", false)):
			icon = str(d.icon)
			label = str(d.label)
			break
	gs.add_log(L.fa(L.t("rules.combat.est_affecte_par_et_ne"), [icon, c.name, label]), true)
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
	return maxf(0.0, (ready_at - GameClock.ms) / 1000.0)

## Lance un sort. `ally_id` = cible alliée pour les sorts ciblés. Renvoie true si le sort a été lancé.
func cast_spell(caster: Dictionary, spell_id: String, ally_id: String = "", free: bool = false) -> bool:
	if gs.game_over or gs.won:
		return false
	if not free and bool(DungeonGenerator.combine_mods(gs.cfg.get("runModifierIds", [])).noSpells):
		gs.add_log(L.t("rules.combat.sorts_interdits_defi"), true)       # règle « Armes seules » du Défi de la semaine
		return false
	var spell := spell_def(spell_id)
	if spell.is_empty() or (not free and not (caster.get("spellsKnown", []) as Array).has(spell_id)):
		gs.add_log(L.fa(L.t("rules.combat.ne_connait_pas_ce_sort"), caster.name))
		return false
	var mode := str(spell.get("mode", "damage"))
	if not SUPPORTED_MODES.has(mode):
		gs.add_log(L.fa(L.t("rules.combat.effet_pas_encore_disponible_dans"), spell.name))
		return false
	if int(caster.hp) <= 0:
		return false
	if not may_act(caster):
		gs.add_log(L.fa(L.t("rules.combat.doit_laisser_un_allie_agir"), caster.name), true)
		return false
	if _blocked_by_status(caster):
		return false
	var left := 0.0 if free else cooldown_left(caster, spell_id)
	if left > 0.0:
		gs.add_log(L.fa(L.t("rules.combat.n_est_pas_encore_pret"), [spell.name, int(ceil(left))]))
		return false
	var target := {}
	if mode == "damage" or mode == "damageGroup" or mode == "sleepGroup":
		target = front_monster()
		if target.is_empty():
			gs.add_log(L.t("rules.combat.il_n_y_a_rien"))
			return false
	var ally: Dictionary = {}
	if spell_needs_ally(spell):
		ally = gs.char_by_id(ally_id)
		if ally.is_empty():
			gs.add_log(L.fa(L.t("rules.combat.choisissez_un_allie_pour"), spell.name))
			return false
		if int(ally.hp) <= 0:
			gs.add_log(L.fa(L.t("rules.combat.est_mort_et_ne_peut"), ally.name))
			return false
		if Statuses.has(ally, "freeze"):
			gs.add_log(L.fa(L.t("rules.combat.est_gele_impossible_de_lui"), ally.name))
			return false
	var cost := 0 if free else int(spell.get("staminaCost", 15))
	if int(caster.get("stamina", 0)) < cost:
		gs.add_log(L.fa(L.t("rules.combat.n_a_plus_assez_endurance"), [caster.name, spell.name]))
		return false
	caster["stamina"] = int(caster.stamina) - cost
	if not free:
		var cds: Dictionary = caster.get("spellCooldowns", {})
		cds[spell_id] = GameClock.ms + int(float(spell.get("cooldownSec", 6)) * 1000.0)
		caster["spellCooldowns"] = cds
	gs.bump(caster.id, "actions")
	gs.bump(caster.id, "spellsCast")
	# HTML : le compteur global n'est incrémenté que pour un sort de dégâts sur cible unique
	if mode == "damage":
		gs.stats["spellsCast"] = int(gs.stats.get("spellsCast", 0)) + 1
	# l'effet visuel est entièrement 3D (SpellFxStyles) ; le contexte dit où et comment le jouer
	var caster_idx := -1
	var ally_idx := -1
	for pi in gs.party.size():
		if str(gs.party[pi].id) == str(caster.id):
			caster_idx = pi
		if not ally.is_empty() and str(gs.party[pi].id) == str(ally.id):
			ally_idx = pi
	var fx_ctx := {"style": str(spell.get("style", "arcane")), "mode": mode,
		"ally": ally_idx if ally_idx >= 0 else caster_idx, "caster": caster_idx, "status": str(spell.get("statusEffect", "")), "solo": gs.party.size() == 1}
	fx_ctx.merge(SpellFxLibrary.fx_keys(spell))      # effet visuel choisi dans l'éditeur (fx, teinte, intensité)
	events.append({"type": "fx3d", "spell": spell_id, "ctx": fx_ctx})
	if Sound.spell_sound(str(spell_id)):
		pass        # son fourni pour ce sort
	elif ["healSingle", "healParty", "staminaRestoreSingle", "shieldSingle", "dispelSingle", "selfBuff", "partyUtility"].has(mode):
		Sound.sfx("heal")
	else:
		Sound.sfx("spell", str(spell.get("style", "arcane")))
	var bonus := int(caster.get("bonusSpellDmg", 0)) + int(floor((int(caster.level) - 1) * 0.75))
	var power := int(caster.get("spellPower", Stats.spell_power(int(caster.get("effInt", 10)))))   # Intelligence : voir Stats.spell_power
	var verb := L.fa(L.t("rules.combat.lance_sur"), [spell.get("icon", ""), spell.name])
	match mode:
		"damage", "damageGroup":
			var int_bonus := power + bonus
			var dmg := GameRng.range_i("combat", int(spell.get("dmgMin", 0)) + int_bonus, int(spell.get("dmgMax", 0)) + int_bonus)
			var magic: bool = str(spell.get("style", "")) != "physical"
			_hit_monster(caster, target, dmg, magic, verb, mode == "damageGroup", bool(spell.get("ignoreAllResist", false)), spell, mode == "damageGroup")
		"healSingle":
			var amt := GameRng.range_i("combat", int(spell.get("healMin", 0)) + bonus + power, int(spell.get("healMax", 0)) + bonus + power)
			var before := int(ally.hp)
			ally["hp"] = mini(int(ally.maxHp), before + maxi(0, amt))
			var healed := int(ally.hp) - before
			gs.add_log(L.fa(L.t("rules.combat.lance_sur_2"), [caster.name, spell.get("icon", ""), spell.name, ally.name,
				L.fa(L.t("rules.combat.et_soigne_pv"), healed) if healed > 0 else ""]), true)
			_credit_heal(caster, healed)
			events.append({"type": "popup", "text": "+%d" % healed, "on": "char:" + str(ally.id), "color": Color("7fd17f")})
			Statuses.apply_from_spell(gs, spell, ally, str(ally.name), str(caster.id), true)
			Characters.recompute(ally, gs.cfg)
		"healParty":
			var details: Array[String] = []
			var total := 0
			for c in gs.alive_party():
				var amt := GameRng.range_i("combat", int(spell.get("healMin", 0)) + bonus + power, int(spell.get("healMax", 0)) + bonus + power)
				var before := int(c.hp)
				c["hp"] = mini(int(c.maxHp), before + amt)
				var healed := int(c.hp) - before
				total += healed
				if healed > 0:
					details.append("%s +%d" % [c.name, healed])
			gs.add_log(L.fa(L.t("rules.combat.lance_et_soigne_tout_le"), [caster.name, spell.get("icon", ""), spell.name,
				", ".join(details) if not details.is_empty() else L.t("rules.combat.personne_n_avait_besoin_de")]), true)
			_credit_heal(caster, total)
			events.append({"type": "popup", "text": L.t("rules.combat.groupe_soigne"), "on": "party", "color": Color("7fd17f")})
		"staminaRestoreSingle":
			var amt := GameRng.range_i("combat", int(spell.get("staminaMin", 0)) + power, int(spell.get("staminaMax", 0)) + power)
			var before := int(ally.get("stamina", 0))
			ally["stamina"] = mini(int(ally.get("maxStamina", 100)), before + maxi(0, amt))
			var got := int(ally.stamina) - before
			gs.add_log(L.fa(L.t("rules.combat.lance_sur_2"), [caster.name, spell.get("icon", ""), spell.name, ally.name,
				L.fa(L.t("rules.combat.et_restaure_endurance"), got) if got > 0 else ""]), true)
			events.append({"type": "popup", "text": "+%d ⚡" % got, "on": "char:" + str(ally.id), "color": Color("7fd1c9")})
			Statuses.apply_from_spell(gs, spell, ally, str(ally.name), str(caster.id), true)
		"shieldSingle":
			var amt := GameRng.range_i("combat", int(spell.get("shieldMin", 0)) + power, int(spell.get("shieldMax", 0)) + power)
			ally["shieldAmount"] = int(ally.get("shieldAmount", 0)) + maxi(0, amt)
			gs.add_log(L.fa(L.t("rules.combat.lance_sur_et_l_entoure"), [caster.name, spell.get("icon", ""), spell.name, ally.name, amt]), true)
			events.append({"type": "popup", "text": "🛡️ %d" % amt, "on": "char:" + str(ally.id), "color": Color("8fc8e8")})
		"dispelSingle":
			var removed := Statuses.dispel(ally)
			Characters.recompute(ally, gs.cfg)
			if removed.is_empty():
				gs.add_log(L.fa(L.t("rules.combat.lance_sur_qui_n_etait"), [caster.name, spell.get("icon", ""), spell.name, ally.name]), true)
			else:
				gs.add_log(L.fa(L.t("rules.combat.lance_sur_et_dissipe"), [caster.name, spell.get("icon", ""), spell.name, ally.name, ", ".join(removed)]), true)
			events.append({"type": "popup", "text": L.t("rules.combat.purifie"), "on": "char:" + str(ally.id), "color": Color("8fc8e8")})
		"sleepGroup":
			var tst: Dictionary = lstate().monsters[str(target.id)]
			var boss := bool(target.get("isBoss", false))
			var eff_spell: Dictionary = spell.duplicate()
			eff_spell["statusEffect"] = "slow" if boss else "stun"
			eff_spell["statusLook"] = "" if boss else "sleep"      # l'étourdissement de la berceuse se voit comme un sommeil (Z) pendant toute sa durée
			eff_spell["statusDuration"] = int(spell.get("statusDuration", 3)) if boss else maxi(1, int(round(int(spell.get("statusDuration", 3)) / 2.0)))
			gs.add_log(L.fa(L.t("rules.combat.lance_sur_3"), [caster.name, spell.get("icon", ""), spell.name, _mname(target)]), true)
			var any_hit := false
			for h in _hit_holders(target, tst, true):      # la berceuse vise tout le groupe : un jet par membre
				if Statuses.apply_from_spell(gs, eff_spell, h, _mname(target), str(caster.id), false):
					any_hit = true
			if not any_hit:
				gs.add_log(L.fa(L.t("rules.combat.resiste_a_la_berceuse"), _mname(target)))
			events.append({"type": "popup", "text": "💤", "color": Color("b9a0ff")})
			events.append({"type": "mon_stun", "id": str(target.id)})
		"selfBuff":
			gs.add_log(L.fa(L.t("rules.combat.lance"), [caster.name, spell.get("icon", ""), spell.name]), true)
			Statuses.apply_from_spell(gs, spell, caster, str(caster.name), str(caster.id), true)
			Characters.recompute(caster, gs.cfg)
		"partyUtility":
			var cut_ms := int(float(spell.get("cooldownReductionSec", 0)) * 1000.0)
			var now := GameClock.ms
			for c in gs.alive_party():
				var cds: Dictionary = c.get("spellCooldowns", {})
				for sid in cds.keys():
					cds[sid] = maxi(now, int(cds[sid]) - cut_ms)
				Statuses.give(c, "vigor", int(spell.get("statusDuration", 4)), str(caster.id))
				Characters.recompute(c, gs.cfg)
			gs.add_log(L.fa(L.t("rules.combat.lance_sur_tout_le_groupe"), [caster.name, spell.get("icon", ""), spell.name]), true)
			events.append({"type": "popup", "text": "🎶 Vigueur", "on": "party", "color": Color("ffd88a")})
	_mark_acted(caster, mode != "damage")
	return true

## Les soins comptent dans la contribution au combat (XP), pondérés par xpSettings.healRatio.
func _credit_heal(caster: Dictionary, healed: int, stat: bool = true) -> void:
	if healed <= 0:
		return
	if stat:
		gs.bump(caster.id, "healingDone", healed)
	var eng := engaged()
	var mid := str(lstate().get("last_engaged_id", ""))
	if not eng.is_empty():
		mid = str(eng.monster.id)
	var st: Dictionary = lstate().monsters.get(mid, {})
	if st.is_empty() or not st.alive:
		return
	var ratio := float((gs.cfg.get("xpSettings", {}) as Dictionary).get("healRatio", 0.8))
	_add_contrib(st, str(caster.id), healed * ratio)

## Porteur des statuts d'un monstre : le membre `mi` d'un groupe (chaque membre a les siens), sinon le monstre lui-même.
func _status_holder(st: Dictionary, mi: int) -> Dictionary:
	if mi >= 0 and st.has("members") and mi < st.members.size():
		return st.members[mi]
	return st

## Indice d'un membre dans son groupe, par identité (deux membres de mêmes PV sont égaux en valeur).
func _member_idx(st: Dictionary, h: Dictionary) -> int:
	for i in st.members.size():
		if is_same(st.members[i], h):
			return i
	return -1

## Membres (ou monstre seul) touchés par une attaque sur `target` : tout le groupe si `all_members`, sinon le membre visé.
func _hit_holders(target: Dictionary, st: Dictionary, all_members: bool) -> Array:
	var out: Array = []
	if bool(target.get("isGroup", false)) and st.has("members"):
		if all_members:
			for mem in st.members:
				if mem.alive:
					out.append(mem)
		else:
			var sel := gs.selected_member_idx(str(target.id), st)
			if sel >= 0:
				out.append(st.members[sel])
	else:
		out.append(st)
	return out

## Applique une attaque (physique ou magique) au monstre visé. `all_members` : frappe tout un groupe.
func _hit_monster(attacker: Dictionary, target: Dictionary, raw_dmg: int, magic: bool, verb: String,
		all_members: bool, ignore_resist: bool, spell: Dictionary = {}, aoe: bool = false) -> void:
	var st: Dictionary = lstate().monsters[str(target.id)]
	var base_resist := int(target.get("resistMagic", 0)) if magic else int(target.get("resistPhys", 0))
	var first_h: Array = _hit_holders(target, st, all_members)
	var sh: Dictionary = first_h[0] if not first_h.is_empty() else st      # statuts du monstre (ou du membre) réellement frappé
	var resist := base_resist if aoe else (0 if ignore_resist else maxi(0, base_resist - Statuses.resist_reduction_pct(sh)))
	# résistance de l'école du coup (feu, glace, sacré…) : s'ajoute ; négative = faiblesse (dégâts accrus)
	var rkey := Resist.style_key(str(spell.get("style", ""))) if not spell.is_empty() else "phys"
	var elem := 0 if ignore_resist else Resist.of_monster(target, rkey)
	resist = clampi(resist + elem, Resist.MIN_PCT, 100)
	var dmg := raw_dmg
	var weak := Statuses.damage_reduction_pct(attacker)      # héros affaibli / vulnérable : dégâts réduits
	if weak > 0:
		dmg = maxi(1, int(round(dmg * (1.0 - weak / 100.0))))
	var dmg_mult := float(DungeonGenerator.combine_mods(gs.cfg.get("runModifierIds", [])).dmgMult)      # « Héros solitaire » : ×2 (attaques et sorts)
	if dmg_mult != 1.0:
		dmg = int(round(dmg * dmg_mult))
	if magic and not aoe:
		var spell_pct := _perk_value(attacker, "spell")
		if spell_pct > 0:
			dmg = int(round(dmg * (1.0 + spell_pct / 100.0)))
	if resist > 0:
		dmg = 0 if resist >= 100 else maxi(1, int(round(dmg * (1.0 - resist / 100.0))))
	elif resist < 0:
		dmg = int(round(dmg * (1.0 - resist / 100.0)))
	var exec_pct := _perk_value(attacker, "execute")
	if exec_pct > 0 and not aoe and not bool(target.get("isGroup", false)) and float(st.hp) <= float(st.maxHp) * 0.25:
		dmg = int(round(dmg * (1.0 + exec_pct / 100.0)))
	var crit := false
	var crit_chance := Stats.crit_total(attacker)
	if crit_chance > 0 and GameRng.f("combat") < crit_chance / 100.0:
		dmg = int(round(dmg * (2.0 + _perk_value(attacker, "critdmg") / 100.0)))
		crit = true

	var is_group: bool = bool(target.get("isGroup", false)) and st.has("members")
	var holders: Array = first_h
	for h in holders:
		h["hp"] = float(h.hp) - dmg
		_add_contrib(st, str(attacker.id), dmg)
		gs.bump(attacker.id, "damageDealt", dmg)
	lstate()["last_engaged_id"] = str(target.id)
	if not aoe and not st.enraged and int(target.get("enrageThreshold", 0)) > 0 \
			and st.hp > 0 and st.hp <= st.maxHp * (int(target.enrageThreshold) / 100.0):
		st["enraged"] = true
		gs.add_log(L.fa(L.t("rules.combat.entre_en_rage_ses_attaques"), _mname(target)))
	var note := (L.fa(L.t("rules.combat.de_resistance"), [resist, L.t("rules.combat.magique") if magic else L.t("rules.combat.physique"), raw_dmg, dmg])) if resist > 0 else ""
	var who := L.t("rules.combat.tout_le_groupe") if (all_members and is_group) else _mname(target)
	if aoe and is_group and all_members:
		gs.add_log(L.fa(L.t("rules.combat.et_frappe_tout_le_groupe"), [attacker.name, verb.trim_suffix(" sur"), dmg, holders.size(), "cibles" if holders.size() > 1 else "cible", note, " 💥 Coup critique !" if crit else ""]), true)
	elif verb == "frappe":
		gs.add_log(L.fa(L.t("rules.combat.frappe_pour_degats"), [attacker.name, who, dmg, note, " 💥 Coup critique !" if crit else ""]), true)
	else:
		gs.add_log(L.fa(L.t("rules.combat.pour_degats"), [attacker.name, verb, who, dmg, note, " 💥 Coup critique !" if crit else ""]), true)
	# chaque membre touché d'un groupe affiche SES dégâts au-dessus de lui (cible « mon:<index> ») ; monstre seul : au centre de la vue
	var pop_ons: Array = []
	for h in holders:
		pop_ons.append("mon:%d" % _member_idx(st, h) if is_group and _member_idx(st, h) >= 0 else "")
	if pop_ons.is_empty():
		pop_ons.append("")
	for on in pop_ons:
		events.append({"type": "popup", "text": "-%d" % dmg, "on": on, "color": Color("ff6a6a") if crit else Color("ffd88a")})
		if elem >= 25:
			events.append({"type": "popup", "text": L.t("rules.combat.popup_resiste"), "on": on, "color": Color("8fc8e8")})
		elif elem <= -25:
			events.append({"type": "popup", "text": L.t("rules.combat.popup_faiblesse"), "on": on, "color": Color("ffb347")})
	events.append({"type": "mon_hit", "id": str(target.id), "crit": crit, "mi": (_member_idx(st, holders[0]) if is_group and not holders.is_empty() else -1)})

	var lifesteal := int(attacker.get("talentLifestealPct", 0)) + int(spell.get("spellLifestealPct", 0)) + _perk_value(attacker, "lifesteal")
	if lifesteal > 0 and dmg > 0 and not aoe:
		var heal := maxi(1, int(round(dmg * lifesteal / 100.0)))
		var before := int(attacker.hp)
		attacker["hp"] = mini(int(attacker.maxHp), before + heal)
		if int(attacker.hp) > before:
			gs.add_log(L.fa(L.t("rules.combat.draine_pv"), [attacker.name, int(attacker.hp) - before]), true)

	for h in holders:
		if float(h.hp) <= 0.0:
			h["alive"] = false
			gs.bump(attacker.id, "kills")
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
				gs.add_log(L.fa(L.t("rules.combat.voit_ses_rangs_decimes"), _mname(target)))
	if (aoe or not all_dead) and not spell.is_empty():
		for h in holders:      # le statut va sur le monstre touché, ou sur chaque membre touché (sort de zone) ; jamais sur le reste du groupe
			if bool(h.get("alive", true)):
				var shown := _mname(target) + (" #%d" % (_member_idx(st, h) + 1) if is_group and st.members.size() > 1 else "")
				Statuses.apply_from_spell(gs, spell, h, shown, str(attacker.id), false)
	var bleed := _perk_value(attacker, "bleed")
	if bleed > 0 and not aoe and not all_dead and dmg > 0 and not holders.is_empty() and bool(holders[0].get("alive", true)) and GameRng.f("combat") * 100.0 < float(bleed):
		Statuses.give(holders[0], "poison", 3, str(attacker.id))
		gs.add_log(L.fa(L.t("rules.combat.saigne_sous_l_arme_de"), [_mname(target), attacker.name]))

func _mark_acted(c: Dictionary, turn_gain: bool = true) -> void:
	tick_char(c)
	if not in_combat():
		return
	gauges["char_" + str(c.id)] = 0.0
	turn_seq += 1
	if turn_gain:
		end_turn_gain()

## endPlayerTurn de l'original : gain d'endurance de fin de tour (staminaSettings.turnGain) tant qu'un combat est engagé.
## Appelé aussi après un pas, une collision avec un monstre ou un escalier.
func end_turn_gain() -> void:
	if not in_combat():
		return
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var gain := int(sta.get("turnGain", 3))
	if gain > 0:
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
		var holder := _status_holder(st, mi)
		var stunned := tick_monster(def, st, holder)
		if st.alive and bool(holder.get("alive", true)) and not stunned:
			_monster_attack_party(def, st, holder)
	gauges[key] = 0.0
	turn_seq += 1
	ensure_gauges()

## Dégâts après la réduction du héros (résistance des talents + garde de Constitution, plafonnée) ; un coup qui touche inflige toujours 1 au moins.
func _hero_reduction(victim: Dictionary, dmg: int, magic: bool, key: String = "") -> int:
	var red := maxi(0, Stats.reduction(victim, magic) - Statuses.resist_reduction_pct(victim))      # « Vulnérable » : protection réduite
	red = clampi(red + Resist.of_hero(victim, key), Resist.MIN_PCT, Stats.CAP_REDUCTION)           # école du coup : résistance de classe / d'objet, ou faiblesse
	if red == 0 or dmg <= 0:
		return dmg
	return maxi(1, int(round(dmg * (1.0 - red / 100.0))))

func _monster_attack_party(def: Dictionary, st: Dictionary, holder: Dictionary = {}) -> void:
	if holder.is_empty():
		holder = st
	var alive := gs.alive_party()
	if alive.is_empty():
		return
	var pool := alive.filter(func(c): return str(c.id) != gs.last_attacker_id)
	if pool.is_empty():
		pool = alive
	if str(def.get("abilitySpellId", "")) != "" and GameRng.f("combat") * 100.0 < float(def.get("abilityChance", 0)):
		var ab := spell_def(str(def.abilitySpellId))
		if not ab.is_empty():
			_monster_use_ability(def, st, ab, pool)
			return
	var victim: Dictionary = pool[GameRng.i("combat") % pool.size()]
	var dodge := int(victim.get("dodgePct", 0))
	if dodge > 0 and GameRng.f("combat") * 100.0 < float(dodge):
		gs.add_log(L.fa(L.t("rules.combat.esquive_attaque"), [victim.name, _mname(def), dodge]), true)
		Sound.sfx("swing", "dagger")
		events.append({"type": "popup", "text": L.t("rules.combat.esquive"), "on": "char:" + str(victim.id), "color": Color("8fc8e8")})
		return
	var dmg := GameRng.range_i("combat", int(st.atkMin), int(st.atkMax))
	if st.enraged:
		dmg = int(round(dmg * (1.0 + int(def.get("enrageBonusPct", 30)) / 100.0)))
	var reduction := Statuses.damage_reduction_pct(holder)
	if reduction > 0:
		dmg = maxi(0, int(round(dmg * (1.0 - reduction / 100.0))))
	dmg = _hero_reduction(victim, dmg, false, "phys")
	if int(victim.get("shieldAmount", 0)) > 0 and dmg > 0:
		var absorbed := mini(int(victim.shieldAmount), dmg)
		victim["shieldAmount"] = int(victim.shieldAmount) - absorbed
		dmg -= absorbed
		gs.add_log(L.fa(L.t("rules.combat.le_bouclier_de_absorbe_degats"), [victim.name, absorbed, L.t("rules.combat.epuise") if int(victim.shieldAmount) <= 0 else ""]), true)
	if _offer_instinct(def, st, victim, dmg, func(o: String, d: int): _basic_hit_tail(def, st, victim, d, o)):
		return
	_basic_hit_tail(def, st, victim, dmg, "")

## Suite du coup d'un monstre : applique les dégâts, le « Dernier souffle », l'épine, les journaux et la chute éventuelle du héros.
## `outcome` : résultat d'« Instinct de survie » ("" = pas d'instinct, "fail", "ok", "perfect").
func _basic_hit_tail(def: Dictionary, st: Dictionary, victim: Dictionary, dmg: int, outcome: String) -> void:
	var raw := dmg
	dmg = _instinct_damage(victim, dmg, outcome)
	victim["hp"] = maxi(0, int(victim.hp) - dmg)
	if outcome == "perfect":
		_instinct_class_effect(def, st, victim, raw)
	if int(victim.hp) <= 0 and dmg > 0 and _perk_value(victim, "last_stand") > 0 and not bool(victim.get("lastStandUsed", false)):
		victim["hp"] = 1
		victim["lastStandUsed"] = true
		gs.add_log(L.fa(L.t("rules.combat.dernier_souffle_survit_coup_mortel"), victim.name))
	var thorns := _perk_value(victim, "thorns")
	if thorns > 0 and dmg > 0:
		var reflect := maxi(1, int(round(dmg * thorns / 100.0)))
		st["hp"] = float(st.hp) - reflect
		gs.add_log(L.fa(L.t("rules.combat.l_equipement_de_renvoie_degats"), [victim.name, reflect, _mname(def)]))
		if float(st.hp) <= 0.0 and st.alive:
			st["alive"] = false
			_handle_death(def, st)
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	victim["stamina"] = mini(int(victim.get("maxStamina", 100)), int(victim.get("stamina", 0)) + int(sta.get("hitGain", 0)))
	gs.add_log(L.fa(L.t("rules.combat.attaque_et_blesse_degats"), [_mname(def), victim.name, dmg, " 😡" if st.enraged else ""]), true)
	Sound.sfx("monster_attack")
	events.append({"type": "fx", "fx": "hit", "char": str(victim.id)})
	events.append({"type": "mon_attack", "id": str(def.id)})      # animation du sprite du monstre (purement visuelle)
	gs.bump(victim.id, "damageTaken", dmg)
	if int(victim.hp) <= 0:
		gs.bump(victim.id, "knockdowns")
	events.append({"type": "popup", "text": "-%d" % dmg, "on": "char:" + str(victim.id), "color": Color("ff5050")})
	events.append({"type": "hit", "char": victim.id})
	if int(victim.hp) > 0:
		_monster_inflict(def, victim)
	if int(victim.hp) <= 0:
		Sound.sfx_later(0.15, "down")
		gs.add_log(L.fa(L.t("common.effondre_a_terre"), victim.name))
		_switch_active_if_down()
		if gs.alive_party().is_empty():
			gs.game_over = true
			gs.add_log(L.t("common.le_groupe_est_aneanti_les"))
			_game_over_sound(def)
			events.append({"type": "game_over"})

# ------------------------------------------------------------------ Instinct de survie

## Chance de base du jet (%) et plafond selon la difficulté de la partie.
const INSTINCT_BASE := {"easy": 45.0, "normal": 40.0, "hard": 35.0, "hardcore": 30.0}
const INSTINCT_CAP := {"easy": 90.0, "normal": 85.0, "hard": 80.0, "hardcore": 75.0}
const INSTINCT_BONUS := {"early": 0.0, "good": 10.0, "perfect": 25.0, "auto": -10.0}
const INSTINCT_SECONDS := {"easy": 3.5, "normal": 3.0, "hard": 2.5, "hardcore": 2.0}
const INSTINCT_MIN_PCT := 15.0

func difficulty() -> String:
	return str(gs.cfg.get("genDifficulty", "normal")) if Data.play_origin == "random" else "normal"

## Fenêtre de réaction (s) : la valeur de la difficulté, allongée par l'option d'accessibilité (jamais en partie classée).
func instinct_seconds() -> float:
	var sec := float(INSTINCT_SECONDS.get(difficulty(), 3.0))
	return sec if RunLog.ranked() else sec * Settings.instinct_scale

## Un coup de monstre qui ferait tomber ce héros à 0 PV peut-il être suspendu pour l'instinct ? (une fois par combat et par héros)
func _instinct_eligible(victim: Dictionary, dmg: int) -> bool:
	if dmg <= 0 or int(victim.hp) <= 0 or dmg < int(victim.hp) or bool(victim.get("instinctUsed", false)):
		return false
	if Statuses.is_disabled(victim) or not in_combat():
		return false
	return RunLog.ranked() or Settings.instinct_mode != "off"

## Suspend le coup si l'instinct s'offre au héros. Renvoie vrai quand le coup attend la réponse (voir resolve_instinct).
func _offer_instinct(def: Dictionary, st: Dictionary, victim: Dictionary, dmg: int, cont: Callable) -> bool:
	if not _instinct_eligible(victim, dmg):
		return false
	pending_instinct = {"victim": victim, "dmg": dmg, "def": def, "st": st, "cont": cont}
	events.append({"type": "instinct", "char": str(victim.id), "seconds": instinct_seconds()})
	return true

func _instinct_chance(quality: String, p: Dictionary) -> float:
	var victim: Dictionary = p.victim
	var diff := difficulty()
	var chance := float(INSTINCT_BASE.get(diff, 40.0)) + float(INSTINCT_BONUS.get(quality, 0.0))
	chance += maxf(0.0, float(victim.get("effCon", victim.get("con", 10))) - 10.0)
	chance += float(_perk_value(victim, "instinct"))
	var over := float(int(p.dmg) - int(victim.hp))
	if over > 0.5 * float(victim.maxHp):
		chance -= 15.0         # coup très dur : bien au-delà de ce qui restait de PV
	if bool(p.def.get("isBoss", false)) and bool(p.st.get("enraged", false)):
		chance -= 10.0
	return clampf(chance, INSTINCT_MIN_PCT, float(INSTINCT_CAP.get(diff, 85.0)))

## Réponse du joueur : `quality` = "none" (rien appuyé), "early", "good", "perfect" ou "auto" (mode automatique d'accessibilité).
## Lance le dé, applique le résultat et poursuit le coup suspendu.
func resolve_instinct(quality: String) -> void:
	if pending_instinct.is_empty():
		return
	var p := pending_instinct
	pending_instinct = {}
	var victim: Dictionary = p.victim
	victim["instinctUsed"] = true
	var outcome := "fail"
	if quality != "none":
		var chance := _instinct_chance(quality, p)
		var roll := GameRng.f("combat") * 100.0 if debug_roll_pct < 0.0 else debug_roll_pct     # debug_roll_pct : tests (force le jet)
		if roll < chance:
			outcome = "perfect" if quality == "perfect" else "ok"
	var on := "char:" + str(victim.id)
	match outcome:
		"perfect":
			gs.add_log(L.fa(L.t("rules.combat.instinct_parfait"), victim.name))
			events.append({"type": "popup", "text": L.t("rules.combat.instinct_popup_parfait"), "on": on, "color": Color("ffd88a")})
			Sound.sfx("level_up")
		"ok":
			gs.add_log(L.fa(L.t("rules.combat.instinct_ok"), victim.name))
			events.append({"type": "popup", "text": L.t("rules.combat.instinct_popup_ok"), "on": on, "color": Color("ffb347")})
			Sound.sfx("heal")
		_:
			gs.add_log(L.fa(L.t("rules.combat.instinct_rate") if quality != "none" else L.t("rules.combat.instinct_pas_le_temps"), victim.name))
			events.append({"type": "popup", "text": L.t("rules.combat.instinct_popup_rate" if quality != "none" else "rules.combat.instinct_popup_none"), "on": on, "color": Color("8fc8e8")})
	events.append({"type": "instinct_result", "char": str(victim.id), "outcome": outcome})
	(p.cont as Callable).call(outcome, int(p.dmg))
	if outcome != "fail" and int(victim.hp) > 0:
		Statuses.give(victim, "slow", 2, "")           # « Hébété » : ralenti pendant 2 tours, l'instinct a un prix
	if outcome != "fail":
		gs.bump(victim.id, "instinctSaves", 1)

## Famille de classe du héros (« Guerrier », « Archer »…) : les classes évoluées reprennent celle dont elles dérivent.
func _class_family(c: Dictionary) -> String:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	return str(cls.get("evolvesFrom", cls.get("name", "")))

## Dégâts réellement encaissés selon le résultat : "ok" laisse 1 PV, "perfect" 15 % des PV max (Archer et Roublard esquivent tout).
func _instinct_damage(victim: Dictionary, dmg: int, outcome: String) -> int:
	match outcome:
		"ok":
			return maxi(0, int(victim.hp) - 1)
		"perfect":
			if ["Archer", "Roublard"].has(_class_family(victim)):
				return 0
			return maxi(0, int(victim.hp) - maxi(1, int(ceil(float(victim.maxHp) * 0.15))))
	return dmg

## Effet de classe d'un instinct parfait (le coup d'origine fait `raw` dégâts).
func _instinct_class_effect(def: Dictionary, st: Dictionary, victim: Dictionary, raw: int) -> void:
	match _class_family(victim):
		"Guerrier":
			var back := maxi(1, int(round(raw * 0.5)))
			if not st.has("members"):
				st["hp"] = float(st.hp) - back
				gs.add_log(L.fa(L.t("rules.combat.instinct_renvoi"), [victim.name, back, _mname(def)]))
				if float(st.hp) <= 0.0 and st.alive:
					st["alive"] = false
					_handle_death(def, st)
		"Archer", "Roublard":
			gs.add_log(L.fa(L.t("rules.combat.instinct_esquive"), victim.name))
		"Mage":
			var sh := maxi(1, int(round(float(victim.maxHp) * 0.2)))
			victim["shieldAmount"] = int(victim.get("shieldAmount", 0)) + sh
			gs.add_log(L.fa(L.t("rules.combat.instinct_barriere"), [victim.name, sh]))
		"Prêtre", "Druide":
			var heal := maxi(1, int(round(float(victim.maxHp) * 0.1)))
			victim["hp"] = mini(int(victim.maxHp), int(victim.hp) + heal)
			gs.add_log(L.fa(L.t("rules.combat.instinct_soin"), [victim.name, heal]))
		"Barde":
			for c in gs.alive_party():
				c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + 10)
			gs.add_log(L.fa(L.t("rules.combat.instinct_cri"), victim.name))

## Anéantissement du groupe : un boss a ses propres sons de victoire (en alternance selon le boss), les autres monstres le jingle habituel.
func _game_over_sound(def: Dictionary) -> void:
	if bool(def.get("isBoss", false)):
		Sound.boss_win(str(def.get("id", def.get("name", ""))))
	else:
		Sound.sfx("game_over")

## Effet de famille du monstre (poison, sommeil, brûlure…) : sur un coup qui touche, avec la chance du monstre.
func _monster_inflict(def: Dictionary, victim: Dictionary) -> void:
	var sp := MonsterEffects.spell_of(def)
	if sp.is_empty() or GameRng.f("combat") * 100.0 >= float(def.get("hitStatusChance", 0)):
		return
	Statuses.apply_from_spell(gs, sp, victim, str(victim.name), str(def.get("id", "")), true)

## Capacité spéciale d'un monstre (sort de dégâts) lancée à la place de son attaque.
func _monster_use_ability(def: Dictionary, st: Dictionary, spell: Dictionary, pool: Array) -> void:
	var victim: Dictionary = pool[GameRng.i("combat") % pool.size()]
	var dmg := GameRng.range_i("combat", int(spell.get("dmgMin", 3)), int(spell.get("dmgMax", 6)))
	dmg = maxi(1, int(round(dmg * float(def.get("dmgMult", 1.0)))))
	if st.enraged:
		dmg = int(round(dmg * (1.0 + int(def.get("enrageBonusPct", 30)) / 100.0)))
	dmg = _hero_reduction(victim, dmg, str(spell.get("style", "")) != "physical", Resist.style_key(str(spell.get("style", ""))))
	if _offer_instinct(def, st, victim, dmg, func(o: String, d: int): _ability_hit_tail(def, st, spell, victim, d, o)):
		return
	_ability_hit_tail(def, st, spell, victim, dmg, "")

## Suite d'une capacité de monstre (voir _basic_hit_tail pour `outcome`).
func _ability_hit_tail(def: Dictionary, st: Dictionary, spell: Dictionary, victim: Dictionary, dmg: int, outcome: String) -> void:
	var raw := dmg
	dmg = _instinct_damage(victim, dmg, outcome)
	victim["hp"] = maxi(0, int(victim.hp) - dmg)
	if outcome == "perfect":
		_instinct_class_effect(def, st, victim, raw)
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	victim["stamina"] = mini(int(victim.get("maxStamina", 100)), int(victim.get("stamina", 0)) + int(sta.get("hitGain", 0)))
	gs.add_log(L.fa(L.t("rules.combat.utilise_sur_degats"), [_mname(def), spell.get("icon", ""), spell.name, victim.name, dmg, " 😡" if st.enraged else ""]), true)
	Sound.sfx("monster_attack")
	# effet visuel de la capacité : part du monstre vers la place du héros visé (SpellFxLibrary, famille « monstre »)
	var victim_idx := 0
	for pi in gs.party.size():
		if str(gs.party[pi].id) == str(victim.id):
			victim_idx = pi
	var mfx := {"style": str(spell.get("style", "arcane")), "mode": "damage", "fromMonster": true, "victim": victim_idx,
		"status": str(spell.get("statusEffect", "")), "ally": victim_idx, "caster": 0, "solo": gs.party.size() == 1}
	mfx.merge(SpellFxLibrary.fx_keys(spell))
	events.append({"type": "fx3d", "spell": str(spell.get("id", "")), "ctx": mfx})
	events.append({"type": "fx", "fx": "hit", "char": str(victim.id)})
	events.append({"type": "mon_attack", "id": str(def.id)})      # animation du sprite du monstre (purement visuelle)
	gs.bump(victim.id, "damageTaken", dmg)
	if int(victim.hp) <= 0:
		gs.bump(victim.id, "knockdowns")
	events.append({"type": "popup", "text": "-%d" % dmg, "on": "char:" + str(victim.id), "color": Color("ff5050")})
	events.append({"type": "hit", "char": victim.id})
	# vol de vie de la capacité (sort de drain) : le monstre récupère une part des dégâts infligés
	var steal := int(spell.get("spellLifestealPct", 0))
	if steal > 0 and dmg > 0 and not st.has("members"):
		var heal := maxi(1, int(round(dmg * steal / 100.0)))
		var before := float(st.hp)
		st["hp"] = minf(float(st.get("maxHp", st.hp)), before + heal)
		if float(st.hp) > before:
			gs.add_log(L.fa(L.t("rules.combat.draine_pv"), [_mname(def), int(float(st.hp) - before)]), true)
			events.append({"type": "popup", "text": "+%d" % int(float(st.hp) - before), "color": Color("7ddc7d")})
	if int(victim.hp) > 0:
		if not Statuses.apply_from_spell(gs, spell, victim, str(victim.name), "", true):
			_monster_inflict(def, victim)
	else:
		gs.bump(victim.id, "knockdowns")
		gs.add_log(L.fa(L.t("common.effondre_a_terre"), victim.name))
		_switch_active_if_down()
		if gs.alive_party().is_empty():
			gs.game_over = true
			gs.add_log(L.t("common.le_groupe_est_aneanti_les"))
			_game_over_sound(def)
			events.append({"type": "game_over"})

# ------------------------------------------------------------------ statuts (tick)

## Fait avancer les statuts d'un personnage d'un tour : dégâts sur la durée, durée restante, fin.
func _switch_active_if_down() -> void:
	var a := gs.char_by_id(gs.active_char_id)
	if a.is_empty() or int(a.hp) <= 0:
		var alive := gs.alive_party()
		if not alive.is_empty():
			gs.active_char_id = str(alive[0].id)

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
			gs.add_log(L.fa(L.t("rules.combat.subit_degats_de"), [sdef.icon, c.name, dmg, sdef.label]), true)
			events.append({"type": "popup", "text": "-%d" % dmg, "on": "char:" + str(c.id), "color": Color("c98bff")})
			events.append({"type": "hit", "char": c.id})
			# « Vol de vie » infligé par un monstre : le monstre se soigne du montant drainé
			if bool(sdef.get("heals", false)) and str(eff.get("casterId", "")) != "":
				var mst: Dictionary = lstate().monsters.get(str(eff.casterId), {})
				if not mst.is_empty() and bool(mst.get("alive", false)) and not mst.has("members"):
					var mb := float(mst.hp)
					mst["hp"] = minf(float(mst.get("maxHp", mst.hp)), mb + dmg)
					if float(mst.hp) > mb:
						var mdef := monster_def(str(eff.casterId))
						gs.add_log(L.fa(L.t("rules.combat.draine_pv"), [_mname(mdef), int(float(mst.hp) - mb)]), true)
						events.append({"type": "popup", "text": "+%d" % int(float(mst.hp) - mb), "color": Color("7ddc7d")})
			if int(c.hp) <= 0:
				gs.bump(c.id, "knockdowns")
				gs.add_log(L.fa(L.t("common.effondre_a_terre"), c.name))
				Sound.sfx("down")
				_switch_active_if_down()
				if gs.alive_party().is_empty() and not gs.game_over:
					gs.game_over = true
					gs.add_log(L.t("common.le_groupe_est_aneanti_les"))
					Sound.sfx("game_over")
					events.append({"type": "game_over"})
		eff["remaining"] = int(eff.remaining) - 1
		if int(eff.remaining) > 0:
			remaining.append(eff)
		else:
			gs.add_log(L.fa(L.t("rules.combat.n_est_plus_affecte_par"), [sdef.icon, c.name, sdef.label]), true)
	c["statusEffects"] = remaining
	Characters.recompute(c, gs.cfg)

## Statuts d'un monstre au début de son action. Renvoie true s'il est étourdi / gelé (il perd son action).
func tick_monster(def: Dictionary, st: Dictionary, holder: Dictionary = {}) -> bool:
	if holder.is_empty():
		holder = st
	var is_member: bool = not is_same(holder, st)
	var stunned := false
	if (holder.get("statusEffects", []) as Array).is_empty():
		return false
	var remaining: Array = []
	for eff in holder.statusEffects:
		var sdef := Statuses.def(str(eff.type))
		if sdef.is_empty():
			continue
		if bool(sdef.get("dot", false)) and float(holder.hp) > 0.0:
			var dmg := maxi(1, int(eff.get("power", 3)))
			holder["hp"] = maxf(0.0, float(holder.hp) - dmg)
			gs.add_log(L.fa(L.t("rules.combat.subit_degats_de"), [sdef.icon, _mname(def), dmg, sdef.label]))
			var dot_mi := _member_idx(st, holder) if is_member else -1
			events.append({"type": "popup", "text": "-%d" % dmg, "on": ("mon:%d" % dot_mi) if dot_mi >= 0 else "", "color": Color("c98bff")})
			if bool(sdef.get("heals", false)) and str(eff.get("casterId", "")) != "":
				var caster := gs.char_by_id(str(eff.casterId))
				if not caster.is_empty() and int(caster.hp) > 0:
					var before := int(caster.hp)
					caster["hp"] = mini(int(caster.maxHp), before + dmg)
					if int(caster.hp) > before:
						gs.add_log(L.fa(L.t("rules.combat.draine_pv"), [caster.name, int(caster.hp) - before]), true)
			if float(holder.hp) <= 0.0 and bool(holder.get("alive", true)):
				holder["alive"] = false
				if is_member:
					var left := false
					for mem in st.members:
						if mem.alive:
							left = true
					if left:
						gs.add_log(L.fa(L.t("rules.combat.voit_ses_rangs_decimes"), _mname(def)))
					else:
						st["alive"] = false
						_handle_death(def, st)
				else:
					_handle_death(def, st)
		elif bool(sdef.get("disables", false)):
			stunned = true
			gs.add_log(L.fa(L.t("rules.combat.est_et_ne_peut_agir"), [sdef.icon, _mname(def), L.t("rules.combat.gele") if str(eff.type) == "freeze" else L.t("rules.combat.etourdi")]))
		eff["remaining"] = int(eff.remaining) - 1
		if int(eff.remaining) > 0:
			remaining.append(eff)
		else:
			gs.add_log(L.fa(L.t("rules.combat.n_est_plus_affecte_par"), [sdef.icon, _mname(def), sdef.label]))
	holder["statusEffects"] = remaining
	return stunned

# ------------------------------------------------------------------ mort d'un monstre

func _handle_death(def: Dictionary, st: Dictionary) -> void:
	gs.add_log("%s s'effondre, vaincu !" % _mname(def))
	var group_mult := 1.0
	if def.get("isGroup", false):
		group_mult = 2.0 if int(def.get("groupSize", 2)) == 3 else 1.5
	var xp := int(round(int(def.get("xpReward", 0)) * group_mult))
	var gold_pct := 0
	for c in gs.alive_party():
		gold_pct += _perk_value(c, "gold")
	var gold := int(round(int(def.get("goldReward", 0)) * group_mult * (1.0 + gold_pct / 100.0)))
	_note_summary(def, xp, gold)
	_split_xp(st, xp)
	var tally: int = st.members.size() if def.get("isGroup", false) and st.get("members") is Array else 1
	for _i in tally:
		_record_bestiary(def)
	gs.stats["monstersKilled"] += 1
	if def.get("isBoss", false):
		gs.stats["bossesKilled"] += 1
	gs.stats["xpEarnedTotal"] += xp
	if gold > 0:
		gs.gold += gold
		gs.stats["goldEarnedTotal"] += gold
		gs.add_log(L.fa(L.t("rules.combat.le_groupe_recupere_pieces_or"), [gold, L.t("rules.combat.butin_de_groupe") if group_mult > 1.0 else ""]))
	if str(def.get("opensDoorId", "")) != "":
		gs.add_log(L.fa(L.t("rules.combat.la_mort_de_deverrouille_une"), _mname(def)))
		events.append({"type": "door_open", "id": str(def.opensDoorId)})
	for k in [["lootItemId", "lootChance"], ["lootItemId2", "lootChance2"]]:
		var item_id := str(def.get(k[0], ""))
		if item_id == "":
			continue
		if GameRng.range_i("combat", 1, 100) <= int(def.get(k[1], 100)):
			for it in level.get("items", []):
				if str(it.id) == item_id:
					var inst := Inventory.make_instance(it)
					if Inventory.add(gs, inst):
						gs.stats["itemsFound"] += 1
						gs.add_log("🎁 %s laisse tomber %s !" % [_mname(def), it.name])
						events.append({"type": "loot", "name": str(it.name)})
						if not summary.is_empty():
							summary.loot.append(str(it.name))
					else:
						# besace pleine : le butin n'est jamais perdu, il tombe au sol à l'emplacement du monstre
						var drop := Inventory.drop_to_floor(gs, level, it, int(st.get("x", gs.px)), int(st.get("y", gs.py)))
						events.append({"type": "loot_drop", "id": str(drop.id)})
						gs.add_log(L.fa(L.t("rules.combat.laissait_tomber_mais_la_besace"), [_mname(def), it.name]))
	# endurance récupérée après la victoire (difficulté « normal »)
	var pct_map: Dictionary = (gs.cfg.get("staminaSettings", {}) as Dictionary).get("victoryGainPct", {"easy": 4, "normal": 6, "hard": 9, "hardcore": 13})
	var diff := str(gs.cfg.get("genDifficulty", "normal")) if Data.play_origin == "random" else "normal"
	var pct := int(pct_map.get(diff, pct_map.get("normal", 6)))
	if pct > 0:
		for c in gs.alive_party():
			var gain := int(round(int(c.get("maxStamina", 100)) * pct / 100.0))
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + gain)
	events.append({"type": "monster_died", "id": str(def.id)})
	ensure_gauges()

func _record_bestiary(def: Dictionary) -> void:
	var d := Stats.monster_derived(def)
	var key := str(def.get("name", "?"))
	var e: Dictionary = gs.bestiary.get(key, {"killCount": 0})
	e.merge({"name": key, "icon": def.get("icon", ""), "isBoss": bool(def.get("isBoss", false)),
		"force": int(def.get("force", 8)), "dex": int(def.get("dex", 8)), "con": int(def.get("con", 8)),
		"maxHp": d.maxHp, "atkMin": d.atkMin, "atkMax": d.atkMax,
		"resistPhys": int(def.get("resistPhys", 0)), "resistMagic": int(def.get("resistMagic", 0)),
		"xpReward": int(def.get("xpReward", 0)), "goldReward": int(def.get("goldReward", 0)),
		"speed": int(Stats.monster_speed(def)), "attackSpeed": float(def.get("attackSpeed", 2.0)), "patrolRadius": int(def.get("patrolRadius", 0)),
		"abilitySpellId": str(def.get("abilitySpellId", "")), "abilityChance": int(def.get("abilityChance", 0)),
		"enrageThreshold": int(def.get("enrageThreshold", 0)),
		"hitStatus": str(def.get("hitStatus", "")), "hitStatusLook": str(def.get("hitStatusLook", "")), "hitStatusChance": int(def.get("hitStatusChance", 0)),
		"hitStatusDuration": int(def.get("hitStatusDuration", 0))}, true)
	e["killCount"] = int(e.killCount) + 1
	gs.bestiary[key] = e

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
	var skipped: Array[String] = []
	for cid in entries:
		var c := gs.char_by_id(str(cid))
		if c.is_empty():
			continue
		var share := int(round(total * float(st.contrib[cid]) / weight))
		if share <= 0:
			continue
		if int(c.hp) <= 0:
			skipped.append(str(c.name))
			continue
		Characters.award_xp(gs, c, share)
		shares.append("%s +%d" % [c.name, share])
	if shares.size() > 1:
		gs.add_log(L.fa(L.t("rules.combat.xp_repartie_selon_la_contribution"), ", ".join(shares)))
	if not skipped.is_empty():
		gs.add_log(L.fa(L.t("rules.combat.tombe_au_combat_et_n"), [", ".join(skipped), L.t("rules.combat.etaient") if skipped.size() > 1 else L.t("rules.combat.etait")]))

# ------------------------------------------------------------------ fuite

## Le groupe fuit vers la case sûre la plus proche (jamais adjacente à un monstre ni visible de lui).
## Renvoie la case, ou (-1,-1) si aucune n'est trouvée.
func flee() -> Vector2i:
	var dest := _safe_destination()
	for c in gs.alive_party():
		c["stamina"] = int(floor(int(c.get("stamina", 0)) * 0.5))
	gs.add_log(L.t("rules.combat.le_groupe_prend_la_fuite"))
	gauges.clear()
	acted.clear()
	_state.clear()
	lstate().erase("combatBilan")
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
