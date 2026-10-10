class_name GameState
extends RefCounted
## État d'une partie : équipe, or, inventaire, état des niveaux (monstres, objets), journal.

signal log_added(text: String, player_hit: bool)

var cfg: Dictionary = {}
var party: Array = []
var gold: int = 0
var inventory: Array = []
var active_char_id: String = ""
var last_attacker_id: String = ""
var level_states: Dictionary = {}
var stats: Dictionary = {"monstersKilled": 0, "bossesKilled": 0, "goldEarnedTotal": 0, "xpEarnedTotal": 0, "itemsFound": 0}
var bestiary: Dictionary = {}
var log_lines: Array[String] = []
var full_log: Array = []            # journal complet : {type: "divider"|"entry", text, playerHit?} (4000 entrées au plus)
var game_over: bool = false
var won: bool = false
# position du groupe (renseignée au moment d'une sauvegarde) et cases découvertes de la mini-carte
var level_index: int = 0
var px: int = 0
var py: int = 0
var pdir: int = 0
var choice_queue: Array = []        # talents et évolutions en attente : {kind, char_id, level}
var run_number: int = 1
var run_seed: String = ""         # graine (texte) de la partie classée, fournie par le serveur ("" = partie libre) : détermine tout le hasard
var run_mods_chosen: bool = false
var in_village: bool = false
var village_prev: Dictionary = {}   # donjon quitté pour le village : {levels, level_index, x, y, dir}
var selected_member: Dictionary = {}   # id de groupe de monstres -> membre visé (pas sauvegardé, comme un simple état d'affichage)

## Membre visé d'un groupe : celui choisi par le joueur s'il est vivant, sinon le premier vivant (-1 si tous morts).
func selected_member_idx(id: String, st: Dictionary) -> int:
	var members: Array = st.get("members", [])
	var i := int(selected_member.get(id, 0))
	if i >= 0 and i < members.size() and bool(members[i].alive):
		return i
	i = -1
	for k in members.size():
		if bool(members[k].alive):
			i = k
			break
	selected_member[id] = i
	return i

const SAVE_FIELDS := ["party", "gold", "inventory", "active_char_id", "last_attacker_id", "level_states", "stats",
	"bestiary", "log_lines", "full_log", "game_over", "won", "level_index", "px", "py", "pdir", "choice_queue", "run_number", "run_seed", "run_mods_chosen", "in_village", "village_prev"]

## Compteur par personnage pour l'écran de statistiques (actions, dégâts, soins…).
func bump(char_id, field: String, amount = 1) -> void:
	if str(char_id) == "":
		return
	var per: Dictionary = stats.get_or_add("perChar", {})
	var c: Dictionary = per.get_or_add(str(char_id), {"actions": 0, "damageDealt": 0, "damageTaken": 0, "healingDone": 0, "kills": 0, "knockdowns": 0, "spellsCast": 0})
	c[field] = int(c.get(field, 0)) + int(amount)

func to_save() -> Dictionary:
	var d := {}
	for f in SAVE_FIELDS:
		d[f] = get(f)
	d["clock"] = GameClock.ms                 # temps de jeu écoulé (recharges de sorts, fontaines)
	d["rng"] = GameRng.export_state()      # position de chaque flux de hasard : la partie reprise continue à l'identique
	return d.duplicate(true)

static func from_save(config: Dictionary, d: Dictionary) -> GameState:
	var s := GameState.new()
	s.cfg = config
	for f in SAVE_FIELDS:
		if not d.has(f):
			continue
		if f == "log_lines":
			for l in d[f]:
				s.log_lines.append(str(l))
		elif f == "full_log":
			s.full_log = (d[f] as Array).duplicate(true)
		else:
			s.set(f, d[f])
	if d.has("clock"):
		GameClock.reset(int(d.clock))
	else:
		GameClock.reset(0)         # ancienne sauvegarde : les recharges étaient mesurées sur l'horloge de la machine, on les remet à zéro
		for c in s.party:
			if c is Dictionary:
				c["spellCooldowns"] = {}
		for ls in s.level_states.values():
			for st in (ls.get("items_state", {}) as Dictionary).values():
				(st as Dictionary).erase("usedAt")
	if d.get("rng") is Dictionary:
		GameRng.import_state(d.rng)
	else:
		GameRng.begin_random()
		if s.run_seed != "":
			GameRng.begin(Seeds.from_text(s.run_seed))
	return s

static func create(config: Dictionary) -> GameState:
	var s := GameState.new()
	s.cfg = config
	s.run_seed = str(config.get("runSeed", ""))
	GameClock.reset(0)
	if s.run_seed != "":
		GameRng.begin(Seeds.from_text(s.run_seed))         # partie classée : toute la partie découle de cette graine
	else:
		GameRng.begin_random()
	for t in config.get("party", []):
		s.party.append(Characters.create(t, config))
	if s.party.size() > 0:
		s.active_char_id = str(s.party[0].id)
	s.add_divider(L.fa(L.t("rules.game_state.expedition_n_1"), str(config.get("title", ""))))
	s.add_log(L.t("core.saves.opening_log"))
	return s

func add_log(msg: String, player_hit: bool = false) -> void:
	log_lines.append(msg)
	if log_lines.size() > 200:
		log_lines.pop_front()
	full_log.append({"type": "entry", "text": msg, "playerHit": player_hit})
	if full_log.size() > 4000:
		full_log.pop_front()
	log_added.emit(msg, player_hit)

## Séparateur du journal complet (« Expédition n°N — titre »).
func add_divider(text: String) -> void:
	full_log.append({"type": "divider", "text": text})

func char_by_id(id: String) -> Dictionary:
	for c in party:
		if c.id == id:
			return c
	return {}

func alive_party() -> Array:
	return party.filter(func(c): return int(c.hp) > 0)

## État (persistant) d'un niveau : monstres, objets ramassés, portes.
func level_state(level: Dictionary) -> Dictionary:
	var id := str(level.id)
	if not level_states.has(id):
		var monsters := {}
		for m in level.get("monsters", []):
			monsters[str(m.id)] = monster_state(m)
		level_states[id] = {"monsters": monsters, "taken_items": {}, "last_engaged_id": "", "seen": {}, "visited": {}}
	return level_states[id]

## État d'un objet de niveau : taken, disarmed, usedAt, triggered, hidden…
func item_state(level_id: String, item_id: String) -> Dictionary:
	var ls: Dictionary = level_states.get(level_id, {})
	var d: Dictionary = ls.get_or_add("items_state", {})
	return d.get_or_add(item_id, {})

## État initial d'un monstre de la configuration (`buildMonsterState`).
func monster_state(m: Dictionary) -> Dictionary:
	var d := Stats.monster_derived(m)
	var st := {"hp": d.maxHp, "maxHp": d.maxHp, "atkMin": d.atkMin, "atkMax": d.atkMax, "alive": true,
		"x": int(m.x), "y": int(m.y), "hidden": bool(m.get("startHidden", false)),
		"contrib": {}, "enraged": false, "statusEffects": []}
	if m.get("isGroup", false):
		var size := 3 if int(m.get("groupSize", 2)) == 3 else 2
		var members: Array = []
		for i in size:
			members.append({"hp": d.maxHp, "maxHp": d.maxHp, "alive": true})
		st["members"] = members
		st["mirrorSlot"] = randi() % size   # un membre du groupe est affiché en miroir pour varier l'aspect
	return st

# ------------------------------------------------------------------ répercussion de la configuration sur la partie

const DEF_FIELDS := ["classId", "name", "icon", "portrait", "force", "dex", "con", "int", "inventorySlots"]

## `syncStatePartyDefinitionsFromConfig` : les définitions des personnages modifiées dans l'administration (classe, nom, icône,
## portrait, caractéristiques, emplacements de besace, endurance de base, sorts de départ) s'appliquent à la partie en cours.
func sync_party_definitions() -> void:
	var defs: Array = cfg.get("party", [])
	for sc in party:
		var cc: Dictionary = {}
		for t in defs:
			if str(t.get("id", "")) == str(sc.id):
				cc = t
				break
		if cc.is_empty():
			continue     # personnage supprimé côté admin entre-temps
		for f in DEF_FIELDS:
			if cc.has(f):
				sc[f] = cc[f]
		if cc.has("maxStamina"):
			sc["baseMaxStamina"] = cc.maxStamina
		if cc.get("spellsKnown") is Array:
			if not (sc.get("spellsKnown") is Array):
				sc["spellsKnown"] = []
			var known: Array = sc.spellsKnown
			for sid in cc.spellsKnown:
				if not known.has(sid) and known.size() < Characters.MAX_SPELLS:
					known.append(sid)
		Characters.recompute(sc, cfg)
		sc["hp"] = mini(int(sc.hp), int(sc.maxHp))
		sc["stamina"] = mini(int(sc.get("stamina", 0)), int(sc.maxStamina))

## `syncAllLevelStates` : répercute la configuration de tous les niveaux déjà visités.
func sync_all_level_states() -> void:
	for lid in level_states.keys():
		sync_level_state(str(lid))

## `syncLevelStateWithConfig` : monstres, objets et marchand ajoutés, déplacés ou supprimés dans l'administration.
func sync_level_state(level_id: String) -> void:
	if not level_states.has(level_id):
		return
	var lvl: Dictionary = {}
	for l in cfg.get("levels", []):
		if str(l.get("id", "")) == level_id:
			lvl = l
			break
	if lvl.is_empty():
		return
	var ls: Dictionary = level_states[level_id]
	var mons: Dictionary = ls.get_or_add("monsters", {})
	var cur_m := {}
	for m in lvl.get("monsters", []):
		var id := str(m.id)
		cur_m[id] = true
		if not mons.has(id):
			mons[id] = monster_state(m)
			continue
		var st: Dictionary = mons[id]
		st["x"] = int(m.x)
		st["y"] = int(m.y)
		var want := (3 if int(m.get("groupSize", 2)) == 3 else 2) if bool(m.get("isGroup", false)) else 0
		var has: int = (st.members as Array).size() if st.has("members") else 0
		if want != has:
			if want > 0:
				var d := Stats.monster_derived(m)
				var members: Array = []
				for i in want:
					members.append({"hp": d.maxHp, "maxHp": d.maxHp, "alive": true})
				st["members"] = members
				st["mirrorSlot"] = randi() % want
			else:
				st.erase("members")
				st.erase("mirrorSlot")
	for id in mons.keys():
		if not cur_m.has(id):
			mons.erase(id)
	var items: Dictionary = ls.get_or_add("items_state", {})
	var taken: Dictionary = ls.get_or_add("taken_items", {})
	var cur_i := {}
	for it in lvl.get("items", []):
		var iid := str(it.id)
		cur_i[iid] = true
		if not items.has(iid):
			items[iid] = {"taken": false, "hidden": bool(it.get("startHidden", false)), "triggered": false}
	for iid in items.keys():
		if not cur_i.has(iid):
			items.erase(iid)
	for iid in taken.keys():
		if not cur_i.has(iid):
			taken.erase(iid)
	var tm = lvl.get("travelingMerchant")
	if tm is Dictionary:
		if not (ls.get("merchant") is Dictionary):
			ls["merchant"] = {"x": int(tm.x), "y": int(tm.y), "discovered": false, "offers": null}
		else:
			ls.merchant["x"] = int(tm.x)
			ls.merchant["y"] = int(tm.y)
	else:
		ls.erase("merchant")

## Entre au village (`enterVillage`) : le donjon quitté est mémorisé, la configuration ne contient plus que le village.
## Renvoie le niveau du village ; la position de départ est celle du village.
func enter_village() -> Dictionary:
	if not in_village:
		village_prev = {"levels": cfg.levels, "level_index": level_index, "x": px, "y": py, "dir": pdir}
	var v := Village.build_level()
	cfg["levels"] = [v]
	in_village = true
	won = false
	game_over = false
	level_index = 0
	px = int(v.startX)
	py = int(v.startY)
	pdir = int(v.startDir)
	var ls := level_state(v)
	var k := "%d,%d" % [px, py]
	ls.get_or_add("visited", {})[k] = true
	ls.get_or_add("seen", {})[k] = true
	return v
