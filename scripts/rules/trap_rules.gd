class_name TrapRules
extends RefCounted
## Règles des pièges : réglages (avec défauts), types de piège, méthodes de désamorçage, chances, tirage de l'offre
## (méthodes et puzzle proposés) et récompenses. Logique pure : aucune interface, tout est testable sans scène.

## Tous les réglages sont numériques (0 / 1 pour les interrupteurs) pour tenir dans `cfg.trapSettings`.
const DEFAULTS := {
	"base": 15.0, "rogueBonus": 12.0, "assassinBonus": 6.0, "dexBonus": 0.5, "dexCap": 10.0, "min": 10.0, "max": 95.0,
	"critExtraDmg": 50.0, "dmgPctMin": 15.0, "dmgPctMax": 30.0,
	# méthodes
	"methodCount": 3.0, "statBonus": 2.5, "forceBase": 45.0, "forceFailPct": 125.0, "dispelBase": 40.0, "dispelStaCost": 12.0,
	"probeBase": 65.0, "probeBonus": 20.0, "volunteerBase": 55.0, "volunteerDmgPct": 35.0, "bypassBase": 45.0, "bypassDmgPct": 40.0,
	# puzzles
	"puzzleChancePct": 50.0, "puzzleRuneOn": 1.0, "puzzleRuneLen": 4.0, "puzzleRuneErrors": 1.0,
	"puzzleWireOn": 1.0, "puzzleWireCount": 4.0, "puzzleWireErrors": 0.0,
	"puzzleRiddleOn": 1.0, "puzzleRiddleErrors": 1.0,
	"puzzleTilesOn": 1.0, "puzzleTilesRows": 4.0, "puzzleTilesErrors": 1.0,
	# récompenses
	"rewardChancePct": 15.0, "rewardPerfectPct": 60.0, "puzzleRewardPct": 70.0,
	"rewardGoldMin": 15.0, "rewardGoldMax": 60.0, "rewardXp": 12.0, "rewardHealPct": 30.0,
}

## Méthodes : icône, caractéristique qui compte, cible du jet.
const METHODS := {
	"disarm": {"icon": "🔓", "stat": "dex"},
	"force": {"icon": "🔨", "stat": "force"},
	"dispel": {"icon": "🔮", "stat": "int"},
	"probe": {"icon": "🔍", "stat": "int"},
	"sacrifice": {"icon": "⚗️", "stat": ""},
	"volunteer": {"icon": "🛡️", "stat": "con"},
	"bypass": {"icon": "🌀", "stat": "dex"},
}

## Types de piège : les méthodes possibles et les puzzles qui s'y prêtent.
const TYPES := [
	{"id": "spikes", "icon": "🗡️", "methods": ["disarm", "force", "sacrifice", "bypass"], "puzzles": ["tiles", "wires"]},
	{"id": "dart", "icon": "🏹", "methods": ["disarm", "bypass", "volunteer", "probe"], "puzzles": ["wires", "tiles"]},
	{"id": "pit", "icon": "🕳️", "methods": ["bypass", "volunteer", "sacrifice", "probe"], "puzzles": ["riddle", "tiles", "rune"]},
	{"id": "gas", "icon": "☁️", "methods": ["disarm", "volunteer", "sacrifice", "dispel"], "puzzles": ["wires", "rune"]},
	{"id": "rune", "icon": "🔥", "methods": ["dispel", "probe", "sacrifice", "disarm"], "puzzles": ["rune", "riddle"]},
]
const PUZZLES := ["rune", "wires", "riddle", "tiles"]
const PUZZLE_ICONS := {"rune": "ᚱ", "wires": "🧵", "riddle": "📜", "tiles": "▦"}
const SACRIFICE_TYPES := ["potion", "scroll"]

## Forçage pour les captures / tests : {"kind": id, "methods": [ids], "puzzle": id}.
static var debug_offer: Dictionary = {}

## Réglages du jeu : valeurs de `cfg.trapSettings` (si présentes et lisibles) sur les défauts.
static func cfg(game_cfg: Dictionary) -> Dictionary:
	var o: Dictionary = DEFAULTS.duplicate()
	var c = game_cfg.get("trapSettings", {})
	if c is Dictionary:
		for k in o.keys():
			var v = c.get(k)
			if v != null and (v is float or v is int or (v is String and v.is_valid_float())):
				o[k] = float(v)
	o["max"] = maxf(o.max, o.min)
	o["dmgPctMax"] = maxf(o.dmgPctMax, o.dmgPctMin)
	o["dexCap"] = maxf(o.dexCap, 0.0)
	o["methodCount"] = clampf(o.methodCount, 2.0, 4.0)
	return o

## Type du piège : celui de son décor (`trapKind` : spikes, dart, pit, gas) ; à défaut, stable d'après son identifiant.
static func kind_of(item: Dictionary) -> Dictionary:
	var tk := str(item.get("trapKind", ""))
	for t in TYPES:
		if t.id == tk:
			return t
	return TYPES[absi(str(item.get("id", "")).hash()) % TYPES.size()]

static func kind_by_id(id: String) -> Dictionary:
	for t in TYPES:
		if t.id == id:
			return t
	return TYPES[0]

## Objets du sac que l'on peut sacrifier : indices dans `gs.inventory`.
static func sacrifice_candidates(gs: GameState) -> Array:
	var out: Array = []
	for i in gs.inventory.size():
		if SACRIFICE_TYPES.has(str(gs.inventory[i].get("type", ""))):
			out.append(i)
	return out

static func puzzle_enabled(s: Dictionary, id: String) -> bool:
	match id:
		"rune": return float(s.puzzleRuneOn) > 0.5
		"wires": return float(s.puzzleWireOn) > 0.5
		"riddle": return float(s.puzzleRiddleOn) > 0.5
		"tiles": return float(s.puzzleTilesOn) > 0.5
	return false

## Tire l'offre d'un piège : le type, 2 à 4 méthodes et, une fois sur deux environ, un puzzle.
static func draw_offer(gs: GameState, s: Dictionary, item: Dictionary) -> Dictionary:
	var kind := kind_of(item)
	var methods: Array = []
	var puzzle := ""
	if not debug_offer.is_empty():
		kind = kind_by_id(str(debug_offer.get("kind", kind.id)))
		methods = (debug_offer.get("methods", []) as Array).duplicate()
		puzzle = str(debug_offer.get("puzzle", ""))
		return {"kind": kind, "methods": methods, "puzzle": puzzle}
	var pool: Array = []
	for m in kind.methods:
		if m == "sacrifice" and sacrifice_candidates(gs).is_empty():
			continue
		pool.append(m)
	pool.shuffle()
	var n := mini(int(s.methodCount), pool.size())
	methods = pool.slice(0, n)
	var pz: Array = []
	for p in kind.puzzles:
		if puzzle_enabled(s, p):
			pz.append(p)
	if not pz.is_empty() and randf() * 100.0 < float(s.puzzleChancePct):
		puzzle = str(pz[randi() % pz.size()])
	return {"kind": kind, "methods": methods, "puzzle": puzzle}

static func _best(gs: GameState, stat: String) -> Dictionary:
	var best: Dictionary = {}
	var bv := -1.0
	for c in gs.alive_party():
		var v := float(c.get("eff" + stat.capitalize(), c.get(stat, 10)))
		if v > bv:
			bv = v
			best = c
	return best

## Chance (0-100) d'une méthode, le personnage qui s'en charge, et le détail pour l'infobulle.
## `disarm_chance` : chance classique de crochetage (calculée par `Interactions.trap_breakdown`).
static func method_chance(gs: GameState, s: Dictionary, id: String, disarm_chance: int, probe_bonus: float) -> Dictionary:
	var who: Dictionary = {}
	var raw := 0.0
	var detail := ""
	match id:
		"disarm":
			raw = float(disarm_chance)
		"force":
			who = _best(gs, "force")
			raw = float(s.forceBase) + float(s.statBonus) * maxf(0.0, float(who.get("effForce", 10)) - 10.0)
		"dispel":
			who = _best(gs, "int")
			raw = float(s.dispelBase) + float(s.statBonus) * maxf(0.0, float(who.get("effInt", 10)) - 10.0)
		"probe":
			who = _best(gs, "int")
			raw = float(s.probeBase) + float(s.statBonus) * maxf(0.0, float(who.get("effInt", 10)) - 10.0)
		"volunteer":
			who = _best(gs, "con")
			raw = float(s.volunteerBase) + float(s.statBonus) * maxf(0.0, float(who.get("effCon", 10)) - 10.0)
		"bypass":
			var tot := 0.0
			var n := 0
			for c in gs.alive_party():
				tot += maxf(0.0, float(c.get("effDex", 10)) - 10.0)
				n += 1
			raw = float(s.bypassBase) + float(s.statBonus) * (tot / maxf(1.0, float(n)))
		"sacrifice":
			return {"chance": 100, "who": who, "raw": 100}
	if id != "probe":
		raw += probe_bonus
	var ch := int(round(clampf(raw, float(s.min), maxf(float(s.min), float(s.max)))))
	return {"chance": ch, "who": who, "raw": int(round(raw)), "detail": detail}

## Seuil du d20 pour une chance donnée (même formule que le crochetage).
static func threshold(chance: int) -> int:
	return clampi(int(ceil(21.0 - chance / 5.0)), 2, 20)

## Récompense éventuelle : {} ou {"kind": "gold"|"xp"|"heal", "amount": n}.
## `source` : "perfect" (20 naturel), "dice" (jet réussi), "puzzle".
static func roll_reward(s: Dictionary, source: String) -> Dictionary:
	var pct := float(s.rewardChancePct)
	if source == "perfect":
		pct = float(s.rewardPerfectPct)
	elif source == "puzzle":
		pct = float(s.puzzleRewardPct)
	if randf() * 100.0 >= pct:
		return {}
	var k := randi() % 3
	if k == 0:
		var lo := int(s.rewardGoldMin)
		return {"kind": "gold", "amount": randi_range(lo, maxi(lo, int(s.rewardGoldMax)))}
	if k == 1:
		return {"kind": "xp", "amount": maxi(1, int(s.rewardXp))}
	return {"kind": "heal", "amount": maxi(1, int(s.rewardHealPct))}

# ------------------------------------------------------------------ puzzles

## Fils : une couleur par fil, et un indice qui désigne exactement le bon (prédicats vrais pour lui, ajoutés jusqu'à
## ce qu'il ne reste que lui). Retourne {"colors": [...], "target": i, "clues": [{"k": clé, "a": ...}]}.
const WIRE_COLORS := ["red", "blue", "yellow", "green", "violet", "white"]

static func make_wires(n: int) -> Dictionary:
	n = clampi(n, 3, 6)
	var cols := WIRE_COLORS.duplicate()
	cols.shuffle()
	cols = cols.slice(0, n)
	var target := randi() % n
	var preds: Array = []
	for i in n:
		var c: String = cols[i]
		if i != target:
			preds.append({"k": "not_color", "a": c, "ok": func(j: int): return cols[j] != c})
	preds.append({"k": "pos_not_end", "a": "", "ok": func(j: int): return j != 0 and j != n - 1})
	preds.append({"k": "pos_first_half" if target < n / 2 else "pos_last_half", "a": "",
		"ok": (func(j: int): return j < n / 2) if target < n / 2 else (func(j: int): return j >= n / 2)})
	preds.append({"k": "pos_nth", "a": str(target + 1), "ok": func(j: int): return j == target})
	if target > 0:
		var cb: String = cols[target - 1]
		preds.append({"k": "below_color", "a": cb, "ok": func(j: int): return j > 0 and cols[j - 1] == cb})
	if target < n - 1:
		var ca: String = cols[target + 1]
		preds.append({"k": "above_color", "a": ca, "ok": func(j: int): return j < n - 1 and cols[j + 1] == ca})
	var valid: Array = []
	for p in preds:
		if p.ok.call(target):
			valid.append(p)
	valid.shuffle()
	var clues: Array = []
	var alive: Array = range(n)
	for p in valid:
		var left: Array = []
		for j in alive:
			if p.ok.call(j):
				left.append(j)
		if left.size() < alive.size():
			alive = left
			clues.append({"k": p.k, "a": p.a})
		if alive.size() == 1:
			break
	if alive.size() > 1:
		clues.append({"k": "pos_nth", "a": str(target + 1)})
	return {"colors": cols, "target": target, "clues": clues}

## Dalles : un chemin de bas en haut, une dalle par rangée, de colonne voisine à colonne voisine. 4 colonnes.
static func make_tiles(rows: int, cols: int = 4) -> Array:
	var path: Array = []
	var c := randi() % cols
	for r in rows:
		path.append(c)
		var opts: Array = []
		for d in [-1, 0, 1]:
			if c + d >= 0 and c + d < cols:
				opts.append(c + d)
		c = opts[randi() % opts.size()]
	return path
