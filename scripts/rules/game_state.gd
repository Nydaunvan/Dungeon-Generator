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
var game_over: bool = false
var won: bool = false
# position du groupe (renseignée au moment d'une sauvegarde) et cases découvertes de la mini-carte
var level_index: int = 0
var px: int = 0
var py: int = 0
var pdir: int = 0
var choice_queue: Array = []        # talents et évolutions en attente : {kind, char_id, level}
var run_number: int = 1
var run_mods_chosen: bool = false
var in_village: bool = false
var village_prev: Dictionary = {}   # donjon quitté pour le village : {levels, level_index, x, y, dir}

const SAVE_FIELDS := ["party", "gold", "inventory", "active_char_id", "last_attacker_id", "level_states", "stats",
	"bestiary", "log_lines", "game_over", "won", "level_index", "px", "py", "pdir", "choice_queue", "run_number", "run_mods_chosen", "in_village", "village_prev"]

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
		else:
			s.set(f, d[f])
	return s

static func create(config: Dictionary) -> GameState:
	var s := GameState.new()
	s.cfg = config
	for t in config.get("party", []):
		s.party.append(Characters.create(t, config))
	if s.party.size() > 0:
		s.active_char_id = str(s.party[0].id)
	return s

func add_log(msg: String, player_hit: bool = false) -> void:
	log_lines.append(msg)
	if log_lines.size() > 200:
		log_lines.pop_front()
	log_added.emit(msg, player_hit)

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
			monsters[str(m.id)] = _monster_state(m)
		level_states[id] = {"monsters": monsters, "taken_items": {}, "last_engaged_id": "", "seen": {}, "visited": {}}
	return level_states[id]

## État d'un objet de niveau : taken, disarmed, usedAt, triggered, hidden…
func item_state(level_id: String, item_id: String) -> Dictionary:
	var ls: Dictionary = level_states.get(level_id, {})
	var d: Dictionary = ls.get_or_add("items_state", {})
	return d.get_or_add(item_id, {})

func _monster_state(m: Dictionary) -> Dictionary:
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
	return st
