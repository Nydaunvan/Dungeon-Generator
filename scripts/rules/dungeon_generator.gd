class_name DungeonGenerator
extends RefCounted
## Génération de donjons aléatoires — portage de generateRandomDungeon / generateRandomParty du HTML.
## Labyrinthe parfait + quelques boucles, porte verrouillée facultative, boss au bout, butin, pièges, fontaines.

const TIER1 := [["Gobelin des cavernes", "mon_cavegoblin"], ["Rat géant", "mon_rat"], ["Loup sauvage", "mon_wolf"], ["Araignée venimeuse", "mon_spider"], ["Orc pillard", "mon_orc"]]
const TIER2 := [["Squelette", "mon_skeleton"], ["Zombie", "mon_zombie"], ["Gnoll", "mon_gnoll"], ["Homme-lézard", "mon_lizardman"], ["Momie", "mon_mummy"], ["Gluant", "mon_slime"], ["Mimique", "mon_mimic"], ["Fantôme", "mon_ghost"], ["Diablotin", "mon_imp"], ["Harpie", "mon_harpy"], ["Minotaure", "mon_minotaur"], ["Ogre", "mon_ogre"], ["Troll des cavernes", "mon_troll"], ["Gargouille", "mon_gargoyle"], ["Loup-garou", "mon_werewolf"], ["Naga", "mon_naga"], ["Golem de boue", "mon_mudgolem"], ["Cultiste", "mon_cultist"]]
const TIER3 := [["Élémentaire de feu", "mon_elemental"], ["Élémentaire de glace", "mon_iceelemental"], ["Béholder", "mon_beholder"], ["Squelette archer", "mon_skeletonarcher"], ["Panthère infernale", "mon_darkpanther"], ["Golem de pierre", "mon_stonegolem"], ["Drake", "mon_drake"]]
const BOSSES := [["Dragon", "boss_dragon"], ["Seigneur démon", "boss_demonlord"], ["Troll géant", "boss_troll"], ["Liche", "boss_lich"], ["Kraken", "boss_kraken"], ["Golem de pierre", "boss_golem"], ["Araignée titanesque", "boss_spider"], ["Spectre des ombres", "boss_wraith"]]
const EQUIP_ICONS := {
	"sword": [0, 1, 2, 3, 23, 112, 113, 114, 121, 126],
	"axe": [4, 5, 6, 7, 115, 116, 117],
	"dagger": [12, 13, 14, 15, 123],
	"staff": [16, 17, 18, 19, 21, 122],
	"bow": [20, 22, 124, 125],
	"mace": [8, 9, 10, 11, 118, 119],
	"head": [24, 25, 26, 27, 28, 29, 59, 60, 127, 128, 129, 131, 132],
	"body": [30, 31, 32, 33, 34, 130, 133, 134, 135],
	"feet": [35, 36, 37, 38, 136, 137, 138],
	"jewelry": [40, 41, 42, 43, 44, 45, 46, 47, 49, 51, 52, 53, 54, 55, 56, 57, 58, 63, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 151, 152, 153, 154, 155, 156, 157, 158],
	"hands": [159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182],
}
const TITLE_NOUNS := ["Cryptes", "Catacombes", "Cavernes", "Ruines", "Profondeurs", "Galeries", "Donjons"]
const TITLE_ADJ := ["Oubliées", "Maudites", "Perdues", "Sombres", "Anciennes", "Silencieuses", "Éternelles"]
const TITLE_PLACES := ["de Karn Uzgoth", "de Vaelthorn", "d'Ombrelune", "du Roi Déchu", "de Nyxandra", "des Brumes", "de l'Aube Noire"]
const LEGENDARY_NAMES := ["Croc du Néant", "Larme d'Aurore", "Rugissement de Fer", "Étreinte des Ombres", "Souffle Glacial",
	"Colère du Titan", "Chant des Abysses", "Flamme Éternelle", "Voile de Brume", "Écho du Chaos",
	"Griffe Céleste", "Serment Brisé", "Lueur du Crépuscule", "Fureur Silencieuse", "Couronne Oubliée"]
const LEGENDARY_PERKS := ["lifesteal", "crit", "thorns"]
const HERO_NAMES := ["Aldric", "Brienne", "Cassian", "Dorian", "Elowen", "Fenwick", "Gwyneth", "Hadrian", "Isolde", "Joren", "Kaelen", "Liora", "Magnus", "Nyra", "Osric", "Perenelle", "Quillan", "Rhiannon", "Silas", "Thalia", "Ulric", "Vesna", "Wystan", "Xanthe", "Yorick", "Zephyrine", "Alistair", "Branwen", "Cedric", "Dariel"]
const ARCHETYPE_STATS := {
	"Guerrier": [16, 11, 14, 7], "Archer": [10, 17, 11, 8], "Roublard": [11, 16, 10, 9], "Mage": [7, 10, 9, 17], "Prêtre": [9, 9, 13, 14],
}
const PORTRAIT_COUNTS := {"Guerrier": 7, "Mage": 8, "Roublard": 6, "Archer": 8, "Barde": 4, "Prêtre": 6}
const PORTRAIT_FILES := {"Guerrier": "guerrier", "Mage": "mage", "Roublard": "roublard", "Archer": "archer", "Barde": "barde", "Prêtre": "pretre"}
const WEAPON_STAT := {"sword": "bonusForce", "axe": "bonusForce", "mace": "bonusForce", "dagger": "bonusDex", "bow": "bonusDex", "staff": "bonusInt"}
const WEAPON_TYPES := ["sword", "axe", "dagger", "staff", "bow", "mace"]
const ARMOR_SLOTS := ["head", "body", "hands", "feet"]
const THEMES := ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]
const TRAP_KINDS := [
	{"kind": "spikes", "name": "Pointes au sol", "icon": "🔺", "permanent": true},
	{"kind": "dart", "name": "Fléchettes dissimulées", "icon": "🎯", "permanent": false},
	{"kind": "pit", "name": "Fosse dissimulée", "icon": "🕳️", "permanent": false},
	{"kind": "gas", "name": "Vapeurs toxiques", "icon": "☠️", "permanent": false},
]

var cfg: Dictionary
var mod: Dictionary
var difficulty: String
var run_bonus: int = 0
var diff_mult: float = 1.0
var lvl_i: int = 0   # index du niveau en cours de génération

func _init(config: Dictionary, diff: String, run: int, mods: Array) -> void:
	cfg = config
	difficulty = diff
	mod = combine_mods(mods)
	run_bonus = maxi(0, run - 1)

# ------------------------------------------------------------------ utilitaires

static func choice(arr: Array):
	return arr[randi_range(0, arr.size() - 1)]

static func rand_f1(a: float, b: float) -> float:
	return roundf((randf() * (b - a) + a) * 10.0) / 10.0

static func title() -> String:
	return L.t("rules.dungeon_generator.les").format({"noun": L.c(choice(TITLE_NOUNS)), "adj": L.c(choice(TITLE_ADJ)), "place": L.c(choice(TITLE_PLACES))})

static func run_modifiers() -> Array:
	return Data.constants.get("RUN_MODIFIERS", [])

## Effets cumulés des modificateurs d'expédition choisis (ids).
static func combine_mods(ids: Array) -> Dictionary:
	var eff := {"attackSpeedMult": 1.0, "xpMult": 1.0, "goldMult": 1.0, "monsterCountMult": 1.0, "itemMult": 1.0, "staminaMult": 1.0,
		"hpMult": 1.0, "critChanceBonus": 0.0, "groupChanceMult": 1.0, "noFountains": false, "forceLegendary": false, "fogMinimap": false}
	for id in ids:
		for m in run_modifiers():
			if m.id != id:
				continue
			for k in ["attackSpeedMult", "xpMult", "goldMult", "monsterCountMult", "itemMult", "staminaMult", "hpMult", "groupChanceMult"]:
				if m.has(k):
					eff[k] = float(eff[k]) * float(m[k])
			if m.has("critChanceBonus"):
				eff["critChanceBonus"] = float(eff["critChanceBonus"]) + float(m.critChanceBonus)
			for k in ["noFountains", "forceLegendary", "fogMinimap"]:
				if m.get(k, false):
					eff[k] = true
	return eff

static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func pick_tiered_monster(depth: int, num_levels: int) -> Array:
	var p := float(depth) / (num_levels - 1) if num_levels > 1 else 0.0
	var w: Array
	if p < 0.4:
		w = [0.70, 0.25, 0.05]
	elif p < 0.75:
		w = [0.20, 0.65, 0.15]
	else:
		w = [0.05, 0.25, 0.70]
	var r := randf()
	if r < w[0]:
		return choice(TIER1)
	if r < w[0] + w[1]:
		return choice(TIER2)
	return choice(TIER3)

static func _depth_bonus(depth: int, rate: float) -> float:
	return minf(depth, 4) * rate + maxf(0, depth - 4) * rate * 0.5

# ------------------------------------------------------------------ labyrinthe

static func carve_maze(mw: int, mh: int) -> Array:
	var gw := 2 * mw + 1
	var gh := 2 * mh + 1
	var grid: Array = []
	for y in gh:
		var row: Array = []
		for x in gw:
			row.append("#")
		grid.append(row)
	for ry in mh:
		for rx in mw:
			grid[2 * ry + 1][2 * rx + 1] = "."
	var visited: Array = []
	for y in mh:
		var vr: Array = []
		for x in mw:
			vr.append(false)
		visited.append(vr)
	var stack: Array = [Vector2i(0, 0)]
	visited[0][0] = true
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var nbrs: Array = []
		if c.x > 0 and not visited[c.y][c.x - 1]:
			nbrs.append(Vector2i(c.x - 1, c.y))
		if c.x < mw - 1 and not visited[c.y][c.x + 1]:
			nbrs.append(Vector2i(c.x + 1, c.y))
		if c.y > 0 and not visited[c.y - 1][c.x]:
			nbrs.append(Vector2i(c.x, c.y - 1))
		if c.y < mh - 1 and not visited[c.y + 1][c.x]:
			nbrs.append(Vector2i(c.x, c.y + 1))
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = choice(nbrs)
		grid[2 * c.y + 1 + (n.y - c.y)][2 * c.x + 1 + (n.x - c.x)] = "."
		visited[n.y][n.x] = true
		stack.append(n)
	for ry in mh:
		for rx in mw:
			if rx < mw - 1 and randf() < 0.12:
				grid[2 * ry + 1][2 * rx + 2] = "."
			if ry < mh - 1 and randf() < 0.12:
				grid[2 * ry + 2][2 * rx + 1] = "."
	return grid

## Distances (nombre de pas) depuis (sx, sy) ; -1 = inaccessible. `block` : case infranchissable facultative.
static func bfs(grid: Array, sx: int, sy: int, block: Vector2i = Vector2i(-1, -1)) -> Array:
	var h := grid.size()
	var w: int = grid[0].size()
	var dist: Array = []
	for y in h:
		var r: Array = []
		for x in w:
			r.append(-1)
		dist.append(r)
	dist[sy][sx] = 0
	var queue: Array = [Vector2i(sx, sy)]
	var qi := 0
	while qi < queue.size():
		var p: Vector2i = queue[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.y >= h or n.x >= w:
				continue
			if grid[n.y][n.x] == "#" or n == block or dist[n.y][n.x] != -1:
				continue
			dist[n.y][n.x] = dist[p.y][p.x] + 1
			queue.append(n)
	return dist

# ------------------------------------------------------------------ objets

func _label_for(sprite: int) -> String:
	return str((Data.constants.get("ITEM_SPRITE_LABELS", {}) as Dictionary).get(str(sprite), ""))

func flavor(list: Array, fallback: String) -> Dictionary:
	var sprite: int = choice(list)
	var label := _label_for(sprite)
	return {"name": label if label != "" else fallback, "icon": ("@icon:spr_%d" % sprite) if label != "" else "💎"}

func apply_legendary(item: Dictionary) -> Dictionary:
	item["legendary"] = true
	item["name"] = choice(LEGENDARY_NAMES)
	item["legendaryPerk"] = choice(LEGENDARY_PERKS)
	item["legendaryValue"] = randi_range(15, 25) if item.legendaryPerk == "crit" else randi_range(12, 20)
	for k in ["bonusAtkMin", "bonusAtkMax", "bonusHp", "bonusSpellDmg", "bonusForce", "bonusDex", "bonusCon", "bonusInt"]:
		if item.get(k, 0):
			item[k] = int(round(int(item[k]) * 1.4))
	return item

func _secondary(base: Dictionary, pool: Array) -> Dictionary:
	var order := pool.duplicate()
	order.shuffle()
	var roll_count := mini(2, order.size()) if randf() < 0.2 else (1 if randf() < 0.65 else 0)
	for k in roll_count:
		var field: String = order[k]
		base[field] = int(base.get(field, 0)) + randi_range(1, 2) + lvl_i / 2 + run_bonus
	return base

func weapon_stats(weapon_type: String) -> Dictionary:
	var primary: String = WEAPON_STAT.get(weapon_type, "bonusForce")
	var pool: Array = ["bonusInt", "bonusDex"] if primary == "bonusInt" else ["bonusForce", "bonusDex", "bonusCon"]
	return _secondary({}, pool)

func armor_stats() -> Dictionary:
	var roll := randf()
	var base: Dictionary
	if roll < 0.4:
		base = {"bonusHp": maxi(2, int(round((6 + lvl_i * 3) * diff_mult)) + run_bonus * 2)}
		_secondary(base, ["bonusCon", "bonusForce"])
	elif roll < 0.7:
		var mn := maxi(2, int(round((2 + lvl_i * 1.5) * diff_mult)) + run_bonus)
		base = {"bonusAtkMin": mn, "bonusAtkMax": mn + randi_range(2, 3)}
		_secondary(base, ["bonusForce", "bonusDex"])
	else:
		base = {"bonusSpellDmg": maxi(2, int(round((2 + lvl_i * 1.5) * diff_mult)) + run_bonus)}
		_secondary(base, ["bonusInt"])
	if randf() < 0.12:
		base["bonusSpeed"] = 1
	return base

func _scaled(stats: Dictionary, f: float) -> Dictionary:
	for k in stats.keys():
		stats[k] = int(round(stats[k] * f))
	return stats

func _item(id: String, fl: Dictionary, x: int, y: int, type: String, extra: Dictionary) -> Dictionary:
	var it := {"id": id, "name": fl.name, "icon": fl.icon, "x": x, "y": y, "type": type}
	it.merge(extra, true)
	return it

func make_weapon(id: String, fallback: String, x: int, y: int, mn: int, mx: int, scale: float = 1.0) -> Dictionary:
	var wt: String = choice(WEAPON_TYPES)
	var fl := flavor(EQUIP_ICONS.get(wt, EQUIP_ICONS.sword), fallback)
	var ex := {"weaponType": wt, "bonusAtkMin": int(round(mn * scale)), "bonusAtkMax": int(round(mx * scale))}
	ex.merge(weapon_stats(wt), true)
	return _item(id, fl, x, y, "weapon", ex)

func make_armor(id: String, fallback: String, x: int, y: int, scale: float = 1.0) -> Dictionary:
	var slot: String = choice(ARMOR_SLOTS)
	var fl := flavor(EQUIP_ICONS.get(slot, EQUIP_ICONS.body), fallback)
	var ex := {"slot": slot}
	ex.merge(_scaled(armor_stats(), scale) if scale != 1.0 else armor_stats(), true)
	return _item(id, fl, x, y, "armor", ex)

func make_jewelry(id: String, fallback: String, x: int, y: int, scale: float = 1.0) -> Dictionary:
	var fl := flavor(EQUIP_ICONS.jewelry, fallback)
	return _item(id, fl, x, y, "jewelry", _scaled(armor_stats(), scale) if scale != 1.0 else armor_stats())

# ------------------------------------------------------------------ niveaux

## Génère `num_levels` niveaux. `party_pow` : puissance du groupe (1 pour une nouvelle expédition).
func levels(num_levels: int, width: int, height: int, party_pow: float = 1.0) -> Array:
	var run_escalation := 1.0 + run_bonus * 0.15
	var base_mult := 1.0
	match difficulty:
		"easy": base_mult = 0.6
		"hard": base_mult = 1.7
		"hardcore": base_mult = 3.0
	diff_mult = base_mult * run_escalation
	var count_mult := 1.0
	match difficulty:
		"easy": count_mult = 0.7
		"hard": count_mult = 1.35
		"hardcore": count_mult = 1.8
	count_mult *= run_escalation
	var mw := maxi(3, (width - 1) / 2)
	var mh := maxi(3, (height - 1) / 2)
	var stamp := Time.get_ticks_msec()
	var ids: Array = []
	for i in num_levels:
		ids.append("gen_lvl_%d_%d" % [i, stamp])
	var out: Array = []
	var since_fountain := 0
	for i in num_levels:
		lvl_i = i
		var lv := _one_level(i, num_levels, mw, mh, ids, out, party_pow, count_mult, run_escalation, since_fountain)
		since_fountain = int(lv.get("_since_fountain", 0))
		lv.erase("_since_fountain")
		out.append(lv)
	for l in out:
		l.erase("_fwdX")
		l.erase("_fwdY")
	_place_merchant(out)
	return out

func _one_level(i: int, num_levels: int, mw: int, mh: int, ids: Array, prev_levels: Array, party_pow: float,
		count_mult: float, run_escalation: float, since_fountain: int) -> Dictionary:
	var grid := carve_maze(mw, mh)
	var sx := 1
	var sy := 1
	var dist := bfs(grid, sx, sy)
	var rooms: Array = []
	for ry in mh:
		for rx in mw:
			var gx := 2 * rx + 1
			var gy := 2 * ry + 1
			if dist[gy][gx] >= 0:
				rooms.append({"x": gx, "y": gy, "d": dist[gy][gx]})
	rooms.sort_custom(func(a, b): return a.d > b.d)
	var far: Dictionary = rooms[0]
	var used := {_key(sx, sy): true, _key(far.x, far.y): true}

	var stairs: Array = []
	grid[far.y][far.x] = "S"
	var fwd: Dictionary = {"type": "victory"} if i == num_levels - 1 else {"type": "level", "targetId": ids[i + 1]}
	stairs.append({"id": "st_%d_fwd" % i, "x": far.x, "y": far.y, "action": fwd})
	if i > 0:
		grid[sy][sx] = "S"
		var prev: Dictionary = prev_levels[i - 1]
		stairs.append({"id": "st_%d_back" % i, "x": sx, "y": sy,
			"action": {"type": "level", "targetId": ids[i - 1], "targetX": prev._fwdX, "targetY": prev._fwdY, "targetDir": 2}})

	# porte verrouillée + clé
	var doors: Array = []
	var key_placed: Dictionary = {}
	var locked_rooms: Array = []
	var candidates := rooms.filter(func(r): return r.d >= 2 and not (r.x == far.x and r.y == far.y))
	if candidates.size() > 4 and randf() < 0.7:
		var placement := _try_locking_door(grid, dist, rooms, candidates, far, sx, sy, 2)
		if placement.is_empty():
			placement = _try_locking_door(grid, dist, rooms, candidates, far, sx, sy, 1)
		if not placement.is_empty():
			var np: Vector2i = placement.cell
			grid[np.y][np.x] = "D"
			var door_id := "door_gen_%d" % i
			doors.append({"id": door_id, "x": np.x, "y": np.y, "locked": true})
			locked_rooms = placement.locked
			var key_cands := rooms.filter(func(r): return placement.dist[r.y][r.x] != -1)
			var kr: Dictionary = choice(key_cands) if not key_cands.is_empty() else {"x": sx, "y": sy}
			key_placed = {"x": kr.x, "y": kr.y, "doorId": door_id}
			used[_key(kr.x, kr.y)] = true

	var items: Array = []
	var fountain_here := false
	if not doors.is_empty() and not locked_rooms.is_empty():
		var behind := locked_rooms.filter(func(r): return not used.has(_key(r.x, r.y)))
		if not behind.is_empty():
			var room: Dictionary = choice(behind)
			used[_key(room.x, room.y)] = true
			if not mod.noFountains and randf() < 0.4:
				items.append({"id": "reward_fountain_%d" % i, "name": L.t("rules.dungeon_generator.fontaine_cachee"), "icon": "@icon:misc_fountain", "x": room.x, "y": room.y, "type": "fountain"})
				fountain_here = true
				since_fountain = 0
			else:
				var rtype: String = choice(["weapon", "armor", "jewelry"])
				var reward: Dictionary
				match rtype:
					"weapon": reward = make_weapon("reward_item_%d" % i, L.t("rules.dungeon_generator.arme_de_la_salle_secrete"), room.x, room.y, 4 + i * 2 + run_bonus, 6 + i * 2 + run_bonus * 2, 1.35)
					"armor": reward = make_armor("reward_item_%d" % i, L.t("rules.dungeon_generator.equipement_de_la_salle_secrete"), room.x, room.y, 1.35)
					_: reward = make_jewelry("reward_item_%d" % i, L.t("rules.dungeon_generator.bijou_de_la_salle_secrete"), room.x, room.y, 1.35)
				var base_pct: float = 55.0 if difficulty == "hardcore" else (35.0 if difficulty == "hard" else float(cfg.get("legendaryChancePct", 25)) * 0.9)
				if randf() < minf(1.0, base_pct * run_escalation / 100.0):
					apply_legendary(reward)
				items.append(reward)

	# monstres
	var monsters: Array = []
	var pool := rooms.filter(func(r): return not used.has(_key(r.x, r.y)) and not _near_stairs(grid, r.x, r.y, 3) and not _near_door(doors, r.x, r.y))
	var monster_count := maxi(1, int(round(pool.size() / 4.0 * count_mult * float(mod.monsterCountMult))))
	var base_force := 8.0 + _depth_bonus(i, 3)
	var base_dex := 8.0 + _depth_bonus(i, 2)
	var base_con := 6.0 + _depth_bonus(i, 2)
	var baseline := base_force + base_dex + base_con
	var damage_spells: Array = (cfg.get("spells", []) as Array).filter(func(s): return s.get("mode") == "damage")
	for mi in monster_count:
		if pool.is_empty():
			break
		var room := {}
		for t in pool.size():
			if pool.is_empty():
				break
			var idx := randi_range(0, pool.size() - 1)
			var cand: Dictionary = pool[idx]
			if used.has(_key(cand.x, cand.y)):
				pool.remove_at(idx)
				continue
			if _far_from_monsters(cand.x, cand.y, monsters):
				room = cand
				pool.remove_at(idx)
				break
		if room.is_empty():
			break
		used[_key(room.x, room.y)] = true
		var fl: Array = pick_tiered_monster(i, num_levels)
		var is_group := randf() < 0.3 * float(mod.groupChanceMult)
		var group_size := (2 if randf() < 0.6 else 3) if is_group else 0
		var m_force := maxi(4, int(round((base_force + randi_range(-2, 2)) * party_pow * diff_mult)))
		var m_dex := maxi(4, int(round((base_dex + randi_range(-2, 2)) * party_pow * diff_mult)))
		var m_con := maxi(4, int(round((base_con + randi_range(-2, 2)) * party_pow * diff_mult)))
		var power := (m_force + m_dex + m_con) / baseline
		var ability := ""
		if not damage_spells.is_empty() and randf() < 0.3:
			ability = str(choice(damage_spells).id)
		var m := {"id": "mon_gen_%d_%d" % [i, mi], "name": fl[0], "icon": "@icon:" + str(fl[1]), "x": room.x, "y": room.y,
			"force": m_force, "dex": m_dex, "con": m_con, "speed": randi_range(11, 18),
			"abilitySpellId": ability, "abilityChance": randi_range(25, 40) if ability != "" else 0,
			"patrolRadius": randi_range(6, 10), "attackSpeed": rand_f1(1, 2.6) * float(mod.attackSpeedMult),
			"xpReward": maxi(3, int(round((10 + i * 6) * diff_mult * power * party_pow * float(mod.xpMult)))),
			"goldReward": maxi(1, int(round((4 + i * 3) * diff_mult * power * float(mod.goldMult)))),
			"opensDoorId": "", "isGroup": is_group, "groupSize": group_size}
		m.merge(_resist(), true)
		monsters.append(m)

	# boss
	var boss_cell := {}
	var boss_cands: Array = []
	for r in rooms:
		var gap: int = far.d - r.d
		if gap >= 3 and gap <= 6 and _boss_spot_ok(r, sx, sy, used, monsters, grid, doors, true):
			boss_cands.append(r)
	if not boss_cands.is_empty():
		boss_cell = choice(boss_cands)
	if boss_cell.is_empty():
		for gap in range(2, 11):
			for r in rooms:
				if far.d - r.d == gap and _boss_spot_ok(r, sx, sy, used, monsters, grid, doors, false):
					boss_cell = r
					break
			if not boss_cell.is_empty():
				break
	if boss_cell.is_empty():
		for r in pool:
			if _far_from_monsters(r.x, r.y, monsters):
				boss_cell = r
				break
	if boss_cell.is_empty():
		boss_cell = pool[0] if not pool.is_empty() else {"x": far.x, "y": far.y}
	used[_key(boss_cell.x, boss_cell.y)] = true
	var bf: Array = choice(BOSSES)
	var bbf := 22.0 + _depth_bonus(i, 6)
	var bbd := 16.0 + _depth_bonus(i, 4)
	var bbc := 20.0 + _depth_bonus(i, 6)
	var b_force := int(round(bbf * diff_mult * party_pow)) + randi_range(-3, 3)
	var b_dex := int(round(bbd * diff_mult * party_pow)) + randi_range(-3, 3)
	var b_con := int(round(bbc * diff_mult * party_pow)) + randi_range(-3, 3)
	var boss_power := (b_force + b_dex + b_con) / ((bbf + bbd + bbc) * diff_mult)
	var b_ability := ""
	if not damage_spells.is_empty() and randf() < 0.6:
		b_ability = str(choice(damage_spells).id)
	var boss := {"id": "boss_gen_%d" % i, "name": "👑 " + str(bf[0]), "icon": "@icon:" + str(bf[1]), "x": boss_cell.x, "y": boss_cell.y, "isBoss": true,
		"force": b_force, "dex": b_dex, "con": b_con, "speed": randi_range(8, 12),
		"resistPhys": randi_range(10, 25) if randf() < 0.4 else 0, "resistMagic": randi_range(10, 25) if randf() < 0.4 else 0,
		"abilitySpellId": b_ability, "abilityChance": randi_range(35, 50) if b_ability != "" else 0,
		"enrageThreshold": randi_range(35, 55), "enrageBonusPct": randi_range(25, 40), "patrolRadius": randi_range(2, 3),
		"attackSpeed": rand_f1(2.2, 3) * float(mod.attackSpeedMult),
		"xpReward": maxi(20, int(round((60 + i * 25) * diff_mult * boss_power * party_pow * float(mod.xpMult)))),
		"goldReward": maxi(15, int(round((30 + i * 15) * diff_mult * boss_power * float(mod.goldMult)))), "opensDoorId": ""}
	monsters.append(boss)

	# butin au sol
	var item_pool := rooms.filter(func(r): return not used.has(_key(r.x, r.y)))
	var take := func() -> Dictionary:
		if item_pool.is_empty():
			return {}
		var r: Dictionary = item_pool.pop_at(randi_range(0, item_pool.size() - 1))
		used[_key(r.x, r.y)] = true
		return r
	var item_mult := float(mod.itemMult)
	var heal_tier := i / 3
	var sta_tier := i / 3
	var loot_rounds := maxi(1, int(round(rooms.size() / 36.0)))
	var equip_here := false
	for lr in loot_rounds:
		if randf() < minf(1.0, 0.7 * item_mult):
			for pi in randi_range(1, 2):
				var r: Dictionary = take.call()
				if not r.is_empty():
					items.append({"id": "pot_gen_%d_%d_%d" % [i, lr, pi], "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": r.x, "y": r.y, "type": "potion", "heal": 6 + heal_tier * 4 + run_bonus})
		if randf() < minf(1.0, 0.5 * item_mult):
			var r: Dictionary = take.call()
			if not r.is_empty():
				items.append({"id": "pot_sta_gen_%d_%d" % [i, lr], "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": r.x, "y": r.y, "type": "potion", "staminaRestore": 12 + sta_tier * 6 + run_bonus * 2})
		if randf() < minf(1.0, 0.85 * item_mult):
			var r: Dictionary = take.call()
			if not r.is_empty():
				items.append(make_weapon("wp_gen_%d_%d" % [i, lr], L.t("rules.dungeon_generator.arme_trouvee"), r.x, r.y, 2 + i + run_bonus, 3 + i * 2 + run_bonus * 2))
				equip_here = true
		if randf() < minf(1.0, 0.75 * item_mult):
			var r: Dictionary = take.call()
			if not r.is_empty():
				items.append(make_armor("ar_gen_%d_%d" % [i, lr], L.t("rules.dungeon_generator.equipement_trouve"), r.x, r.y))
				equip_here = true
		if randf() < 0.65:
			var r: Dictionary = take.call()
			if not r.is_empty():
				items.append(make_jewelry("jw_gen_%d_%d" % [i, lr], L.t("rules.dungeon_generator.bijou_trouve"), r.x, r.y))
				equip_here = true
	for ti in randi_range(2, 3):
		var r: Dictionary = take.call()
		if not r.is_empty():
			var tk: Dictionary = choice(TRAP_KINDS)
			items.append({"id": "trap_gen_%d_%d" % [i, ti], "name": tk.name, "icon": tk.icon, "x": r.x, "y": r.y, "type": "trap", "trapKind": tk.kind, "permanent": tk.permanent,
				"trapDmgMin": 2 + int(i * 0.8) + int(run_bonus * 0.5), "trapDmgMax": 5 + int(i * 1.2) + run_bonus})
	if not equip_here:
		var r: Dictionary = take.call()
		if not r.is_empty():
			match choice(["weapon", "armor", "jewelry"]):
				"weapon": items.append(make_weapon("wp_gen_%d_force" % i, L.t("rules.dungeon_generator.arme_trouvee"), r.x, r.y, 2 + i + run_bonus, 3 + i * 2 + run_bonus * 2))
				"armor": items.append(make_armor("ar_gen_%d_force" % i, L.t("rules.dungeon_generator.equipement_trouve"), r.x, r.y))
				_: items.append(make_jewelry("jw_gen_%d_force" % i, L.t("rules.dungeon_generator.bijou_trouve"), r.x, r.y))
	if not key_placed.is_empty():
		items.append({"id": "key_gen_%d" % i, "name": L.t("rules.dungeon_generator.cle_trouvee"), "icon": "@icon:misc_key", "x": key_placed.x, "y": key_placed.y, "type": "key", "opensDoorId": key_placed.doorId})
	var spells: Array = cfg.get("spells", [])
	if not spells.is_empty() and randf() < 0.4:
		var r: Dictionary = take.call()
		if not r.is_empty():
			var sp: Dictionary = choice(spells)
			items.append({"id": "scroll_gen_%d" % i, "name": L.t("common.parchemin_de") + str(sp.name), "icon": "@icon:misc_scroll", "x": r.x, "y": r.y, "type": "scroll", "spellId": sp.id})
	if not fountain_here and not mod.noFountains and (i == 0 or since_fountain >= 2 or randf() < 0.45):
		var r: Dictionary = take.call()
		if not r.is_empty():
			items.append({"id": "fountain_gen_%d" % i, "name": L.t("rules.dungeon_generator.fontaine_de_vie"), "icon": "@icon:misc_fountain", "x": r.x, "y": r.y, "type": "fountain"})
			fountain_here = true
	since_fountain = 0 if fountain_here else since_fountain + 1

	# butin porté par les monstres (caché jusqu'à leur mort)
	var lootable := monsters.filter(func(m): return not m.get("isBoss", false))
	var loot_count := int(round(lootable.size() * 0.45 * diff_mult))
	for li in loot_count:
		if lootable.is_empty():
			break
		var mon: Dictionary = lootable.pop_at(randi_range(0, lootable.size() - 1))
		var lid := "loot_%d_%d" % [i, li]
		var loot: Dictionary
		match choice(["potion", "potion_sta", "weapon", "armor", "jewelry"]):
			"potion": loot = {"id": lid, "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": sx, "y": sy, "type": "potion", "heal": 5 + i * 2 + run_bonus}
			"potion_sta": loot = {"id": lid, "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": sx, "y": sy, "type": "potion", "staminaRestore": 10 + i * 3 + run_bonus * 2}
			"weapon": loot = make_weapon(lid, L.t("rules.dungeon_generator.arme_du_butin"), sx, sy, 2 + i + run_bonus, 3 + i * 2 + run_bonus * 2)
			"armor": loot = make_armor(lid, L.t("rules.dungeon_generator.equipement_du_butin"), sx, sy)
			_: loot = make_jewelry(lid, L.t("rules.dungeon_generator.bijou_du_butin"), sx, sy)
		loot["startHidden"] = true
		items.append(loot)
		mon["lootItemId"] = lid
		mon["lootChance"] = randi_range(40, 80)

	# butin du boss
	var legend_base: float = 45.0 if difficulty == "hardcore" else (25.0 if difficulty == "hard" else float(cfg.get("legendaryChancePct", 25)) * 0.6)
	var legend_pct: float = 100.0 if mod.forceLegendary else minf(100.0, roundf(legend_base * run_escalation))
	var boss_loot: Dictionary
	match choice(["weapon", "armor", "jewelry"]):
		"weapon": boss_loot = make_weapon("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 3 + i * 2 + run_bonus, 5 + i * 2 + run_bonus * 2)
		"armor": boss_loot = make_armor("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 1.3)
		_: boss_loot = make_jewelry("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 1.3)
	boss_loot["startHidden"] = true
	if randf() < legend_pct / 100.0:
		apply_legendary(boss_loot)
	items.append(boss_loot)
	boss["lootItemId"] = boss_loot.id
	boss["lootChance"] = 100

	# clé de l'arche (sortie verrouillée) portée par le boss
	var exit_stairs: Dictionary = stairs[0]
	if exit_stairs.action.type == "level":
		exit_stairs["locked"] = true
		var key_item := {"id": "key_exit_%d" % i, "name": L.t("rules.dungeon_generator.cle_de_l_arche"), "icon": "@icon:misc_key", "x": sx, "y": sy, "type": "key", "opensDoorId": exit_stairs.id, "startHidden": true}
		items.append(key_item)
		boss["lootItemId2"] = key_item.id
		boss["lootChance2"] = 100

	var theme: String = "stone" if i == 0 else choice(THEMES)
	var start_dir := 1
	for d in [1, 2, 0, 3]:
		var v: Vector2i = DungeonGrid.DIRS[d]
		var nx := sx + v.x
		var ny := sy + v.y
		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[0].size() and grid[ny][nx] != "#":
			start_dir = d
			break
	var rows: Array = []
	for row in grid:
		rows.append("".join(row))
	return {"id": ids[i], "name": L.fa(L.t("common.niveau"), (i + 1)), "theme": theme, "mapRows": rows, "startX": sx, "startY": sy, "startDir": start_dir,
		"stairs": stairs, "doors": doors, "monsters": monsters, "items": items,
		"_fwdX": far.x, "_fwdY": far.y, "_since_fountain": since_fountain}

func _boss_spot_ok(r: Dictionary, sx: int, sy: int, used: Dictionary, monsters: Array, grid: Array, doors: Array, check_door: bool) -> bool:
	if r.x == sx and r.y == sy:
		return false
	if used.has(_key(r.x, r.y)) or not _far_from_monsters(r.x, r.y, monsters) or _near_stairs(grid, r.x, r.y, 3):
		return false
	return not (check_door and _near_door(doors, r.x, r.y))

func _resist() -> Dictionary:
	var roll := randf()
	if roll < 0.65:
		return {"resistPhys": 0, "resistMagic": 0}
	if roll < 0.85:
		return {"resistPhys": randi_range(10, 35), "resistMagic": 0}
	return {"resistPhys": 0, "resistMagic": randi_range(10, 35)}

func _far_from_monsters(x: int, y: int, placed: Array) -> bool:
	for m in placed:
		if absi(int(m.x) - x) + absi(int(m.y) - y) <= 1:
			return false
	return true

func _near_stairs(grid: Array, gx: int, gy: int, min_dist: int) -> bool:
	for sy in grid.size():
		for sx in grid[sy].size():
			if grid[sy][sx] == "S" and maxi(absi(sx - gx), absi(sy - gy)) < min_dist:
				return true
	return false

func _near_door(doors: Array, gx: int, gy: int) -> bool:
	for d in doors:
		if maxi(absi(int(d.x) - gx), absi(int(d.y) - gy)) < 2:
			return true
	return false

## Cherche une case de couloir à verrouiller : la sortie doit rester accessible et au moins `min_locked` salles être coupées.
func _try_locking_door(grid: Array, dist: Array, rooms: Array, candidates: Array, far: Dictionary, sx: int, sy: int, min_locked: int) -> Dictionary:
	var tries := candidates.duplicate()
	var best := {}
	var attempt := 0
	while attempt < 14 and not tries.is_empty():
		attempt += 1
		var room: Dictionary = tries.pop_at(randi_range(0, tries.size() - 1))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = Vector2i(int(room.x), int(room.y)) + d
			if n.y < 0 or n.y >= grid.size() or n.x < 0 or n.x >= grid[0].size():
				continue
			if grid[n.y][n.x] != "#" and dist[n.y][n.x] == room.d - 1:
				var dl := bfs(grid, sx, sy, n)
				var stairs_ok: bool = dl[far.y][far.x] != -1
				var reachable := 0
				var locked: Array = []
				for r in rooms:
					if dl[r.y][r.x] != -1:
						reachable += 1
					else:
						locked.append(r)
				if stairs_ok and reachable >= rooms.size() * 0.5 and locked.size() >= min_locked:
					if best.is_empty() or locked.size() > best.locked.size():
						best = {"cell": n, "dist": dl, "locked": locked}
				break
	return best

## Marchand ambulant sur le 2ᵉ niveau (ou le seul), sur une case libre.
func _place_merchant(lvls: Array) -> void:
	var ml: Dictionary = lvls[mini(1, lvls.size() - 1)]
	var occupied := {}
	for m in ml.monsters:
		occupied[_key(int(m.x), int(m.y))] = true
	for it in ml.items:
		occupied[_key(int(it.x), int(it.y))] = true
	for d in ml.doors:
		occupied[_key(int(d.x), int(d.y))] = true
	for s in ml.stairs:
		occupied[_key(int(s.x), int(s.y))] = true
	occupied[_key(int(ml.startX), int(ml.startY))] = true
	var free: Array = []
	for y in ml.mapRows.size():
		var row: String = ml.mapRows[y]
		for x in row.length():
			if row[x] == "." and not occupied.has(_key(x, y)):
				free.append(Vector2i(x, y))
	if not free.is_empty():
		var spot: Vector2i = choice(free)
		ml["travelingMerchant"] = {"x": spot.x, "y": spot.y, "patrolRadius": randi_range(4, 8)}

# ------------------------------------------------------------------ groupe aléatoire

static func _is_base(cls: Dictionary) -> bool:
	return str(cls.get("evolvesFrom", "")) == ""

static func _has_evolution(cfg: Dictionary, cls: Dictionary) -> bool:
	var evo = cls.get("evolvesTo", [])
	if evo == null:
		return false
	for id in evo:
		if id != null and not Characters.class_def(cfg, str(id)).is_empty():
			return true
	return false

## 4 héros de classes de base (2 exemplaires d'une même classe au maximum), portraits et noms distincts.
static func generate_party(cfg: Dictionary, diff: String) -> Array:
	var base_ids: Array = []
	for c in cfg.get("classes", []):
		if _is_base(c):
			base_ids.append(str(c.id))
	if base_ids.is_empty():
		return cfg.get("party", [])
	var counts := {}
	var chosen: Array = []
	for i in 4:
		var avail := base_ids.filter(func(id): return int(counts.get(id, 0)) < 2)
		var pick: String = choice(avail)
		counts[pick] = int(counts.get(pick, 0)) + 1
		chosen.append(pick)
	chosen.shuffle()
	var any_evo := false
	for id in chosen:
		if _has_evolution(cfg, Characters.class_def(cfg, id)):
			any_evo = true
	if not any_evo:
		var evolvable := base_ids.filter(func(id): return _has_evolution(cfg, Characters.class_def(cfg, id)))
		if not evolvable.is_empty():
			chosen[randi_range(0, chosen.size() - 1)] = choice(evolvable)
	var names := HERO_NAMES.duplicate()
	names.shuffle()
	var used_portraits := {}
	var hard := diff == "hardcore"
	var stamp := Time.get_ticks_msec()
	var out: Array = []
	for idx in chosen.size():
		var cls := Characters.class_def(cfg, str(chosen[idx]))
		var cname := str(cls.name)
		var t: Array = ARCHETYPE_STATS.get(cname, [11, 11, 11, 11])
		var portrait := ""
		if PORTRAIT_FILES.has(cname):
			var free: Array = []
			for n in int(PORTRAIT_COUNTS[cname]):
				var p := "res://assets/portraits/%s_%d.webp" % [PORTRAIT_FILES[cname], n]
				if not used_portraits.has(p):
					free.append(p)
			if not free.is_empty():
				portrait = choice(free)
				used_portraits[portrait] = true
		var weapon_id := ""
		var wt: Array = cls.get("allowedWeaponTypes", [])
		var cands: Array = (cfg.get("itemLibrary", []) as Array).filter(func(it): return it.get("type") == "weapon" and wt.has(it.get("weaponType")))
		if not cands.is_empty():
			weapon_id = str(choice(cands).id)
		var known: Array = []
		for p in cls.get("spellProgression", []):
			if int(p.level) <= 1 and not known.has(p.spellId):
				known.append(p.spellId)
		var bonus := 2 if hard else 0
		out.append({"id": "gen_%d_%d_%d" % [stamp, idx, randi() % 10000], "name": names[idx], "icon": cls.icon, "classId": cls.id, "portrait": portrait,
			"force": maxi(5, int(t[0]) + randi_range(-1, 1)) + bonus, "dex": maxi(5, int(t[1]) + randi_range(-1, 1)) + bonus,
			"con": maxi(5, int(t[2]) + randi_range(-1, 1)) + bonus, "int": maxi(5, int(t[3]) + randi_range(-1, 1)) + bonus,
			"maxStamina": randi_range(95, 115), "inventorySlots": 8, "level": 1, "spellsKnown": known,
			"startEquipment": {"weapon": weapon_id} if weapon_id != "" else {}, "hpDoubleStart": hard})
	return out

## Configuration complète d'une expédition aléatoire à partir de la configuration de base.
static func build_config(base: Dictionary, num_levels: int, width: int, height: int, diff: String, mods: Array, run: int = 1) -> Dictionary:
	var c: Dictionary = base.duplicate(true)
	var gen := DungeonGenerator.new(c, diff, run, mods)
	c["party"] = generate_party(c, diff)
	c["levels"] = gen.levels(num_levels, width, height)
	c["title"] = title()
	c["genDifficulty"] = diff
	c["runModifierIds"] = mods.duplicate()
	c["genDims"] = {"numLevels": num_levels, "width": width, "height": height}
	var sta: Dictionary = (c.get("staminaSettings", {}) as Dictionary).duplicate()
	sta["moveGain"] = 1
	sta["moveInterval"] = 3
	c["staminaSettings"] = sta
	return c
