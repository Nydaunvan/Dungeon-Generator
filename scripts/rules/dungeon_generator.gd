class_name DungeonGenerator
extends RefCounted
## Génération de donjons aléatoires — portage de generateRandomDungeon / generateRandomParty du HTML.
## Labyrinthe parfait + quelques boucles, porte verrouillée facultative, boss au bout, butin, pièges, fontaines.

const TIER1 := [["Gobelin des cavernes", "mon_cavegoblin"], ["Rat géant", "mon_rat"], ["Loup sauvage", "mon_wolf"], ["Araignée venimeuse", "mon_spider"], ["Orc pillard", "mon_orc"]]
const TIER2 := [["Squelette", "mon_skeleton"], ["Veilleur Os", "mon_veilleur_os"], ["Fossoyeur sans visage", "mon_fossoyeur"], ["Zombie", "mon_zombie"], ["Gnoll", "mon_gnoll"], ["Homme-lézard", "mon_lizardman"], ["Momie", "mon_mummy"], ["Gluant", "mon_slime"], ["Mimique", "mon_mimic"], ["Fantôme", "mon_ghost"], ["Diablotin", "mon_imp"], ["Harpie", "mon_harpy"], ["Minotaure", "mon_minotaur"], ["Ogre", "mon_ogre"], ["Troll des cavernes", "mon_troll"], ["Gargouille", "mon_gargoyle"], ["Loup-garou", "mon_werewolf"], ["Naga", "mon_naga"], ["Golem de boue", "mon_mudgolem"], ["Cultiste", "mon_cultist"]]
const TIER3 := [["Élémentaire de feu", "mon_elemental"], ["Élémentaire de glace", "mon_iceelemental"], ["Béholder", "mon_beholder"], ["Squelette archer", "mon_skeletonarcher"], ["Panthère infernale", "mon_darkpanther"], ["Golem de pierre", "mon_stonegolem"], ["Drake", "mon_drake"]]
const BOSSES := [["Dragon", "boss_dragon"], ["Seigneur démon", "boss_demonlord"], ["Troll géant", "boss_troll"], ["Liche", "boss_lich"], ["Kraken", "boss_kraken"], ["Golem de pierre", "boss_golem"], ["Araignée titanesque", "boss_spider"], ["Spectre des ombres", "boss_wraith"]]
const EQUIP_ICONS := {
	"sword": [0, 1, 2, 3, 23, 112, 113, 114, 121, 126],
	"axe": [4, 5, 6, 7, 115, 116, 117],
	"dagger": [12, 13, 14, 15, 123],
	"staff": [16, 17, 18, 19, 21, 122],
	"bow": [20, 22, 124, 125],
	"mace": [8, 9, 10, 11, 118, 119],
	"head": [24, 25, 26, 27, 28, 29, 59, 60, 127, 128, 129, 131, 132, 156],
	"body": [30, 31, 32, 33, 34, 130, 133, 134, 135],
	"feet": [35, 36, 37, 38, 136, 137, 138],
	"jewelry": [40, 41, 42, 43, 44, 45, 46, 47, 49, 51, 52, 53, 54, 55, 56, 57, 58, 63, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 151, 152, 153, 154, 155, 157, 158],
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
	"Guerrier": [16, 11, 14, 7], "Archer": [10, 17, 11, 8], "Roublard": [11, 16, 10, 9], "Mage": [7, 10, 9, 17], "Prêtre": [9, 9, 13, 14], "Druide": [9, 10, 13, 14],
	"Barde": [9, 15, 11, 13],      # [force, dex, con, int] : dextérité, puis intelligence, constitution, force
}
const PORTRAIT_COUNTS := {"Guerrier": 7, "Mage": 8, "Roublard": 6, "Archer": 8, "Barde": 4, "Prêtre": 6, "Druide": 5}
const PORTRAIT_FILES := {"Guerrier": "guerrier", "Mage": "mage", "Roublard": "roublard", "Archer": "archer", "Barde": "barde", "Prêtre": "pretre", "Druide": "druide"}
## Portraits du Druide empruntés à d'autres classes (même image) : jamais deux fois dans le même groupe.
const PORTRAIT_TWINS := {"druide_0": "pretre_4", "druide_1": "archer_0", "druide_2": "archer_1", "druide_3": "pretre_2", "druide_4": "mage_4"}
const WEAPON_STAT := {"sword": "bonusForce", "axe": "bonusForce", "mace": "bonusForce", "dagger": "bonusDex", "bow": "bonusDex", "staff": "bonusInt"}
const WEAPON_TYPES := ["sword", "axe", "dagger", "staff", "bow", "mace"]
const ARMOR_SLOTS := ["head", "body", "hands", "feet"]
const THEMES := ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]
const TRAP_KINDS := [
	{"kind": "spikes", "name": "Pointes au sol", "icon": "🔺", "permanent": true},
	{"kind": "dart", "name": "Fléchettes dissimulées", "icon": "🎯", "permanent": true},
	{"kind": "pit", "name": "Fosse dissimulée", "icon": "🕳️", "permanent": true},
	{"kind": "gas", "name": "Vapeurs toxiques", "icon": "☠️", "permanent": true},
	{"kind": "rune", "name": "Rune de flammes", "icon": "🔥", "permanent": true},
]

var cfg: Dictionary
var mod: Dictionary
var difficulty: String
var run_bonus: int = 0
var diff_mult: float = 1.0
var lvl_i: int = 0   # index du niveau en cours de génération
var _legend_pity: float = 0.0   # points de chance de légendaire gagnés par les gardiens sans légendaire

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

## Modificateurs proposés au joueur (les règles propres au Défi de la semaine, `weeklyOnly`, n'y figurent pas).
static func run_modifiers() -> Array:
	return all_modifiers().filter(func(m): return not bool(m.get("weeklyOnly", false)))

## Tous les modificateurs connus du jeu (choisis par le joueur ou imposés par le serveur).
static func all_modifiers() -> Array:
	return Data.constants.get("RUN_MODIFIERS", [])

## Effets cumulés des modificateurs d'expédition choisis (ids).
static func combine_mods(ids: Array) -> Dictionary:
	var eff := {"attackSpeedMult": 1.0, "xpMult": 1.0, "goldMult": 1.0, "monsterCountMult": 1.0, "itemMult": 1.0, "staminaMult": 1.0,
		"hpMult": 1.0, "dmgMult": 1.0, "lootMult": 1.0, "monsterHpMult": 1.0, "monsterDmgMult": 1.0, "minRarity": "", "startWeaponRarity": "", "critChanceBonus": 0.0, "groupChanceMult": 1.0, "maxGroupSize": 3, "noFountains": false, "forceLegendary": false, "bossMythicPct": -1.0, "bossMythicMult": 0.0, "fogMinimap": false, "soloParty": false, "noSpells": false,
		"rageChanceMult": 1.0, "trapMult": 1.0, "noSecondWind": false}
	for id in ids:
		for m in all_modifiers():
			if m.id != id:
				continue
			for k in ["attackSpeedMult", "xpMult", "goldMult", "monsterCountMult", "itemMult", "staminaMult", "hpMult", "dmgMult", "groupChanceMult", "lootMult", "monsterHpMult", "monsterDmgMult", "rageChanceMult", "trapMult"]:
				if m.has(k):
					eff[k] = float(eff[k]) * float(m[k])
			if m.has("maxGroupSize"):
				eff["maxGroupSize"] = mini(int(eff["maxGroupSize"]), int(m.maxGroupSize))
			if m.has("critChanceBonus"):
				eff["critChanceBonus"] = float(eff["critChanceBonus"]) + float(m.critChanceBonus)
			for k in ["noFountains", "forceLegendary", "fogMinimap", "soloParty", "noSpells", "noSecondWind"]:
				if m.get(k, false):
					eff[k] = true
			if m.has("bossMythicPct"):          # taux de mythique du butin du boss (le reste est légendaire) ; le plus haut l'emporte
				eff["bossMythicPct"] = maxf(float(eff["bossMythicPct"]), float(m.bossMythicPct))
			if m.has("bossMythicMult"):         # multiplicateur de la chance de mythique de la difficulté (butin du boss) ; le plus haut l'emporte
				eff["bossMythicMult"] = maxf(float(eff["bossMythicMult"]), float(m.bossMythicMult))
			for k in ["minRarity", "startWeaponRarity"]:      # palier le plus haut demandé par les modificateurs choisis
				if str(m.get(k, "")) != "" and Rarity.index(str(m[k])) > Rarity.index(str(eff[k])) :
					eff[k] = str(m[k])
	eff["monsterDmgMult"] = minf(float(eff["monsterDmgMult"]), MAX_MONSTER_DMG_MULT)       # plafond : les dégâts des monstres ne dépassent jamais ×1,5 avec les modificateurs
	return eff

## Dégâts maximum des monstres avec les modificateurs cumulés.
const MAX_MONSTER_DMG_MULT := 1.5

## Modificateurs de `ids` qui ne peuvent pas être pris avec `id` (champ `incompatibleWith`, dans les deux sens).
static func conflicts(id: String, ids: Array) -> Array:
	var out: Array = []
	for other in ids:
		if str(other) == id:
			continue
		for m in all_modifiers():
			if (str(m.id) == id and (m.get("incompatibleWith", []) as Array).has(str(other))) or (str(m.id) == str(other) and (m.get("incompatibleWith", []) as Array).has(id)):
				if not out.has(str(other)):
					out.append(str(other))
	return out

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

# ------------------------------------------------------------------ salles

## Parties enregistrées avant l'arrivée des salles (1.37.0) : on rejoue avec l'ancien labyrinthe, sans aucune salle.
static var legacy_layout := false

const ROOM_MIN_NODES := 16        ## en dessous (nombre de cases du labyrinthe), un niveau reste un pur labyrinthe
const ROOM_BUDGET := 0.30         ## part maximale des cases du labyrinthe qui peuvent appartenir à une salle
const ROOM_MAX_DIM := 3           ## côté maximal d'une salle, en cases du labyrinthe (3 -> 5 cases de sol) : jamais un niveau d'une seule salle
const ROOM_PER_NODES := 20.0      ## une salle prévue pour 20 cases du labyrinthe (plafonné à 8)

## Taille (largeur, hauteur) tirée pour une salle, en cases du labyrinthe : surtout de petites salles, rarement une grande.
static func _room_dims(max_dim: int) -> Vector2i:
	var r := randf()
	if r < 0.5 or max_dim < 3:
		return Vector2i(2, 2)
	if r < 0.85:
		return Vector2i(3, 2) if randf() < 0.5 else Vector2i(2, 3)
	return Vector2i(3, 3)

## Plan des salles d'un niveau de `mw` x `mh` cases de labyrinthe : rectangles {x, y, w, h} (en cases du labyrinthe).
## Elles sont réparties régulièrement (chaque nouvelle salle prend, parmi quelques essais, l'emplacement le plus éloigné des autres),
## séparées par au moins une case de couloir, jamais sur le départ, et leur total reste sous ROOM_BUDGET.
static func plan_rooms(mw: int, mh: int) -> Array:
	var rects: Array = []
	var n := mw * mh
	if n < ROOM_MIN_NODES:
		return rects
	var max_dim := mini(ROOM_MAX_DIM, maxi(2, (mini(mw, mh) + 1) / 2))
	var budget := int(n * ROOM_BUDGET)
	var want := clampi(int(round(n / ROOM_PER_NODES)), 1, 8)
	var used_nodes := 0
	for k in want:
		var dims := _room_dims(max_dim)
		if used_nodes + dims.x * dims.y > budget:
			dims = Vector2i(2, 2)
			if used_nodes + 4 > budget:
				break
		var best := {}
		var best_score := -1.0
		for t in 14:
			var rx := randi_range(0, mw - dims.x)
			var ry := randi_range(0, mh - dims.y)
			if rx <= 1 and ry <= 1:
				continue          # ni sur le départ, ni collée à lui
			var ok := true
			var near := 99.0
			for r in rects:
				if not (rx >= r.x + r.w + 1 or r.x >= rx + dims.x + 1 or ry >= r.y + r.h + 1 or r.y >= ry + dims.y + 1):
					ok = false
					break
				var dx := absf((rx + dims.x * 0.5) - (r.x + r.w * 0.5))
				var dy := absf((ry + dims.y * 0.5) - (r.y + r.h * 0.5))
				near = minf(near, maxf(dx, dy))
			if not ok:
				continue
			var score := near + randf() * 0.5
			if score > best_score:
				best_score = score
				best = {"x": rx, "y": ry, "w": dims.x, "h": dims.y}
		if best.is_empty():
			continue
		rects.append(best)
		used_nodes += dims.x * dims.y
	return rects

## Cases de sol (x, y de la grille) à l'intérieur des salles du plan : clés « x,y » -> true. Contient les cases du labyrinthe
## de la salle ET celles qui les relient.
static func room_mask(rects: Array) -> Dictionary:
	var out := {}
	for r in rects:
		for cy in range(2 * int(r.y) + 1, 2 * (int(r.y) + int(r.h) - 1) + 2):
			for cx in range(2 * int(r.x) + 1, 2 * (int(r.x) + int(r.w) - 1) + 2):
				out[_key(cx, cy)] = true
	return out

## Labyrinthe avec salles : chaque salle est ouverte en entier (rectangle de sol) et compte comme UNE seule case pour le tracé
## des couloirs, qui la relient au reste (tout le niveau reste donc connecté). Mêmes boucles supplémentaires (12 %) que `carve_maze`.
static func carve_maze_rooms(mw: int, mh: int, rects: Array) -> Array:
	var gw := 2 * mw + 1
	var gh := 2 * mh + 1
	var grid: Array = []
	for y in gh:
		var row: Array = []
		for x in gw:
			row.append("#")
		grid.append(row)
	var unit: Array = []                      # [y][x] -> numéro d'unité (une salle = une unité)
	var members: Array = []                   # unité -> cases du labyrinthe
	for ry in mh:
		var ur: Array = []
		for rx in mw:
			ur.append(-1)
			grid[2 * ry + 1][2 * rx + 1] = "."
		unit.append(ur)
	for r in rects:
		var id := members.size()
		var nodes: Array = []
		for ry in range(int(r.y), int(r.y) + int(r.h)):
			for rx in range(int(r.x), int(r.x) + int(r.w)):
				unit[ry][rx] = id
				nodes.append(Vector2i(rx, ry))
		members.append(nodes)
		for cy in range(2 * int(r.y) + 1, 2 * (int(r.y) + int(r.h) - 1) + 2):
			for cx in range(2 * int(r.x) + 1, 2 * (int(r.x) + int(r.w) - 1) + 2):
				grid[cy][cx] = "."
	for ry in mh:
		for rx in mw:
			if int(unit[ry][rx]) < 0:
				unit[ry][rx] = members.size()
				members.append([Vector2i(rx, ry)])
	var visited: Array = []
	for u in members.size():
		visited.append(false)
	var first: int = unit[0][0]
	visited[first] = true
	var stack: Array = [first]
	while not stack.is_empty():
		var u: int = stack[stack.size() - 1]
		var cands: Array = []
		for a in members[u]:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var b: Vector2i = a + d
				if b.x < 0 or b.y < 0 or b.x >= mw or b.y >= mh:
					continue
				var vb: int = unit[b.y][b.x]
				if vb != u and not visited[vb]:
					cands.append({"a": a, "b": b, "v": vb})
		if cands.is_empty():
			stack.pop_back()
			continue
		var c: Dictionary = choice(cands)
		var ca: Vector2i = c.a
		var cb: Vector2i = c.b
		grid[2 * ca.y + 1 + (cb.y - ca.y)][2 * ca.x + 1 + (cb.x - ca.x)] = "."
		visited[c.v] = true
		stack.append(c.v)
	for ry in mh:
		for rx in mw:
			if rx < mw - 1 and int(unit[ry][rx]) != int(unit[ry][rx + 1]) and randf() < 0.12:
				grid[2 * ry + 1][2 * rx + 2] = "."
			if ry < mh - 1 and int(unit[ry][rx]) != int(unit[ry + 1][rx]) and randf() < 0.12:
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

## Tire la rareté d'un objet généré (voir `Rarity.weights`) et la lui applique : bonus multipliés et capacités.
func roll_rarity(item: Dictionary, source: String) -> Dictionary:
	if source == "":
		return item
	var w := Rarity.weights(source, lvl_i, run_bonus, difficulty)
	var floor_tier := str(mod.minRarity)
	if floor_tier != "":          # « Butin de choix » : aucun équipement sous ce palier ; les paliers supérieurs gardent leurs chances relatives
		for k in w.keys():
			if Rarity.index(k) < Rarity.index(floor_tier):
				w.erase(k)
		if w.is_empty():
			w[floor_tier] = 1.0
	var tier := Rarity.roll(w, func(): return randf())
	return Rarity.apply(item, tier, func(): return randf())

## Chance qu'un objet légendaire soit mythique : croît avec le niveau, le numéro de partie et la difficulté.
## Facile : quasi inexistante (1 % + 0,5 % par niveau, au plus 5 %) ; Normale : 4 % par niveau ; Difficile : 3 % + 5 % par niveau ; Hardcore : 10 % + 4 % par niveau.
func mythic_chance() -> float:
	var extra := 0.08 * run_bonus
	match difficulty:
		"easy": return clampf(0.01 + 0.005 * lvl_i + extra, 0.0, 0.05)
		"hard": return clampf(0.03 + 0.05 * lvl_i + extra, 0.0, 0.4)
		"hardcore": return clampf(0.1 + 0.04 * lvl_i + extra, 0.0, 0.4)
	return clampf(0.04 * lvl_i + extra, 0.0, 0.4)

## Taux de mythique (en %) imposé au butin du boss par « Nid de monstres » : `bossMythicMult` × la chance de la difficulté (au plus 100) ; -1 = chance normale.
func _boss_mythic_pct() -> float:
	if not mod.forceLegendary:
		return -1.0
	if float(mod.bossMythicMult) > 0.0:
		return minf(100.0, mythic_chance() * float(mod.bossMythicMult) * 100.0)
	return float(mod.bossMythicPct)

## Fait de l'objet un légendaire (ou, plus rarement, un mythique) : nom unique, capacités du palier, bonus ×1,7 (×2 pour un mythique).
## `mythic_pct` >= 0 impose le taux de mythique (en %), sinon `mythic_chance()`. Un seul tirage dans les deux cas (même consommation du hasard).
func apply_legendary(item: Dictionary, mythic_pct: float = -1.0) -> Dictionary:
	var chance := mythic_chance() if mythic_pct < 0.0 else mythic_pct / 100.0
	var tier := "mythic" if randf() < chance else "legendary"
	Rarity.upgrade_to(item, tier, func(): return randf())
	item["name"] = choice(LEGENDARY_NAMES)
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

func make_weapon(id: String, fallback: String, x: int, y: int, mn: int, mx: int, scale: float = 1.0, source: String = "floor") -> Dictionary:
	var wt: String = choice(WEAPON_TYPES)
	var fl := flavor(EQUIP_ICONS.get(wt, EQUIP_ICONS.sword), fallback)
	var ex := {"weaponType": wt, "bonusAtkMin": int(round(mn * scale)), "bonusAtkMax": int(round(mx * scale))}
	ex.merge(weapon_stats(wt), true)
	return roll_rarity(_item(id, fl, x, y, "weapon", ex), source)

func make_armor(id: String, fallback: String, x: int, y: int, scale: float = 1.0, source: String = "floor") -> Dictionary:
	var slot: String = choice(ARMOR_SLOTS)
	var fl := flavor(EQUIP_ICONS.get(slot, EQUIP_ICONS.body), fallback)
	var ex := {"slot": slot}
	ex.merge(_scaled(armor_stats(), scale) if scale != 1.0 else armor_stats(), true)
	return roll_rarity(_item(id, fl, x, y, "armor", ex), source)

func make_jewelry(id: String, fallback: String, x: int, y: int, scale: float = 1.0, source: String = "floor") -> Dictionary:
	var fl := flavor(EQUIP_ICONS.jewelry, fallback)
	return roll_rarity(_item(id, fl, x, y, "jewelry", _scaled(armor_stats(), scale) if scale != 1.0 else armor_stats()), source)

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
	var stamp := randi() % 1000000000           # identifiants uniques par expédition, reproductibles avec une graine
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
	_place_pendulums(out)
	return out

func _one_level(i: int, num_levels: int, mw: int, mh: int, ids: Array, prev_levels: Array, party_pow: float,
		count_mult: float, run_escalation: float, since_fountain: int) -> Dictionary:
	var rects: Array = [] if legacy_layout else plan_rooms(mw, mh)
	_room_mask = room_mask(rects)
	var grid := carve_maze(mw, mh) if rects.is_empty() else carve_maze_rooms(mw, mh, rects)
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
	# la sortie est toujours dans un couloir (une arche dans le mur du fond), jamais au milieu d'une salle
	var far: Dictionary = rooms.filter(func(r): return not _room_mask.has(_key(int(r.x), int(r.y))))[0]
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
		# la clé ne se pose jamais sur le départ ni sur un escalier : sans autre case possible, pas de porte verrouillée
		var key_cands: Array = []
		if not placement.is_empty():
			# jamais sur un escalier (la sortie ou le retour) ni sur une case déjà prise, et toujours du côté accessible sans la porte
			key_cands = rooms.filter(func(r): return placement.dist[r.y][r.x] != -1 and not used.has(_key(int(r.x), int(r.y))))
		if not placement.is_empty() and not key_cands.is_empty():
			var np: Vector2i = placement.cell
			grid[np.y][np.x] = "D"
			var door_id := "door_gen_%d" % i
			doors.append({"id": door_id, "x": np.x, "y": np.y, "locked": true})
			locked_rooms = placement.locked
			var kr: Dictionary = choice(key_cands)
			key_placed = {"x": kr.x, "y": kr.y, "doorId": door_id}
			used[_key(kr.x, kr.y)] = true

	var items: Array = []
	var fountain_here := false
	if not doors.is_empty() and not locked_rooms.is_empty():
		var behind := locked_rooms.filter(func(r): return not used.has(_key(r.x, r.y)))
		if not behind.is_empty():
			var room: Dictionary = choice(behind)
			var want_fountain: bool = (not mod.noFountains) and randf() < 0.4
			if want_fountain:   # la fontaine se loge dans un décroché du mur : on préfère une case qui a un mur
				var walled := behind.filter(func(r): return _has_wall_side(grid, r.x, r.y))
				if not walled.is_empty():
					room = choice(walled)
			used[_key(room.x, room.y)] = true
			if want_fountain:
				items.append({"id": "reward_fountain_%d" % i, "name": L.t("rules.dungeon_generator.fontaine_cachee"), "icon": "@icon:misc_fountain", "x": room.x, "y": room.y, "type": "fountain"})
				fountain_here = true
				since_fountain = 0
			else:
				var rtype: String = choice(["weapon", "armor", "jewelry"])
				var reward: Dictionary
				match rtype:
					"weapon": reward = make_weapon("reward_item_%d" % i, L.t("rules.dungeon_generator.arme_de_la_salle_secrete"), room.x, room.y, 4 + i * 2 + run_bonus, 6 + i * 2 + run_bonus * 2, 1.35, "reward")
					"armor": reward = make_armor("reward_item_%d" % i, L.t("rules.dungeon_generator.equipement_de_la_salle_secrete"), room.x, room.y, 1.35, "reward")
					_: reward = make_jewelry("reward_item_%d" % i, L.t("rules.dungeon_generator.bijou_de_la_salle_secrete"), room.x, room.y, 1.35, "reward")
				var base_pct: float = 55.0 if difficulty == "hardcore" else (35.0 if difficulty == "hard" else float(cfg.get("legendaryChancePct", 25)) * 0.9)
				if randf() < minf(1.0, base_pct * run_escalation / 100.0):
					apply_legendary(reward)
				items.append(reward)

	# monstres
	var monsters: Array = []
	var pool := rooms.filter(func(r): return not used.has(_key(r.x, r.y)) and not _near_stairs(grid, r.x, r.y, 3) and not _near_door(doors, r.x, r.y))
	# aucun monstre près de l'arrivée du joueur : il doit avoir le temps de s'orienter (on ne réduit cette distance que si le niveau n'offre rien d'autre)
	for clear in [START_CLEAR, 5, 3]:
		var away := pool.filter(func(r): return absi(int(r.x) - sx) + absi(int(r.y) - sy) >= clear and absi(int(r.x) - int(far.x)) + absi(int(r.y) - int(far.y)) >= clear)
		if away.size() >= maxi(1, pool.size() / 3):
			pool = away
			break
	var monster_count := maxi(1, int(round(pool.size() / 4.0 * count_mult * float(mod.monsterCountMult))))
	var base_force := 8.0 + _depth_bonus(i, 3)
	var base_dex := 8.0 + _depth_bonus(i, 2)
	var base_con := 6.0 + _depth_bonus(i, 2)
	var baseline := base_force + base_dex + base_con
	var damage_spells: Array = (cfg.get("spells", []) as Array).filter(func(s): return s.get("mode") == "damage")
	for mi in monster_count:
		if pool.is_empty():
			break
		# les monstres sont espacés : jamais deux combats à la suite (écart de 8 cases au moins ; on réduit seulement si le niveau est trop étroit, jamais sous 3)
		var room := {}
		pool = pool.filter(func(c): return not used.has(_key(c.x, c.y)))
		for gap in MONSTER_GAPS:
			var ok: Array = pool.filter(func(c): return _far_from_monsters(c.x, c.y, monsters, gap))
			if not ok.is_empty():
				room = ok[randi_range(0, ok.size() - 1)]
				pool.erase(room)
				break
		if room.is_empty():
			break
		used[_key(room.x, room.y)] = true
		var fl: Array = pick_tiered_monster(i, num_levels)
		var is_group := randf() < 0.3 * float(mod.groupChanceMult)
		var group_size := mini((2 if randf() < 0.6 else 3), int(mod.maxGroupSize)) if is_group else 0
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
		if float(mod.monsterHpMult) != 1.0:
			m["hpMult"] = float(mod.monsterHpMult)
		if float(mod.monsterDmgMult) != 1.0:
			m["dmgMult"] = float(mod.monsterDmgMult)
		m.merge(_resist(), true)
		m.merge(Resist.roll(str(fl[1]), false, 100.0, true), true)        # résistances de famille : toujours présentes, valeurs au hasard (jamais zéro)
		m.merge(MonsterEffects.roll(str(fl[1]), false, float(cfg.get("monsterStatusChancePct", 60)), false, i), true)       # effet de famille (au hasard)
		# rage : tous les monstres peuvent en avoir une, au hasard (chance réglée dans l'admin) ; elle se déclenche sous un seuil de PV
		var rage_on := randf() * 100.0 < minf(100.0, float(cfg.get("monsterRageChancePct", 25)) * float(mod.rageChanceMult))
		m["enrageThreshold"] = randi_range(30, 50) if rage_on else 0
		m["enrageBonusPct"] = randi_range(15, 30) if rage_on else 0
		monsters.append(m)

	# boss : toujours au fond du niveau, jamais près de l'arrivée (distance de chemin d'au moins 60 % du chemin jusqu'à la sortie, et 8 cases)
	var boss_cell := {}
	var boss_cands: Array = []
	var boss_min_d: int = mini(maxi(8, int(ceil(float(far.d) * 0.6))), maxi(int(far.d) - 2, 0))
	for r in rooms:
		var gap: int = far.d - r.d
		if gap >= 3 and gap <= 6 and int(r.d) >= boss_min_d and _boss_spot_ok(r, sx, sy, used, monsters, grid, doors, true):
			boss_cands.append(r)
	if not boss_cands.is_empty():
		boss_cell = choice(boss_cands)
	if boss_cell.is_empty():
		for gap in range(2, 11):
			for r in rooms:
				if far.d - r.d == gap and int(r.d) >= boss_min_d and _boss_spot_ok(r, sx, sy, used, monsters, grid, doors, false):
					boss_cell = r
					break
			if not boss_cell.is_empty():
				break
	if boss_cell.is_empty():
		# aucune salle assez loin des monstres : la salle (hors départ et escalier) la plus éloignée de tous
		var best_d := -1
		for r in rooms:
			if used.has(_key(r.x, r.y)) or int(r.d) < boss_min_d or absi(int(r.x) - sx) + absi(int(r.y) - sy) < START_CLEAR - 2 or _near_stairs(grid, r.x, r.y, 3):
				continue
			var dmin := 99
			for m in monsters:
				dmin = mini(dmin, absi(int(m.x) - int(r.x)) + absi(int(m.y) - int(r.y)))
			if dmin > best_d:
				best_d = dmin
				boss_cell = r
	if boss_cell.is_empty():
		# dernier recours : la salle libre la plus éloignée de l'arrivée (jamais près du départ)
		var deepest := -1
		for r in rooms:
			if not used.has(_key(r.x, r.y)) and int(r.d) > deepest:
				deepest = int(r.d)
				boss_cell = r
	if boss_cell.is_empty():
		boss_cell = pool[0] if not pool.is_empty() else {"x": far.x, "y": far.y}
	used[_key(boss_cell.x, boss_cell.y)] = true
	# jamais un monstre à moins de 3 cases du boss (pas de combat sur combat) : un monstre trop proche cède la place
	monsters = monsters.filter(func(m): return absi(int(m.x) - int(boss_cell.x)) + absi(int(m.y) - int(boss_cell.y)) >= 3)
	var bf: Array = choice(BOSSES)
	var bbf := 22.0 + _depth_bonus(i, 6)
	var bbd := 16.0 + _depth_bonus(i, 4)
	var bbc := 20.0 + _depth_bonus(i, 6)
	var b_force := int(round(bbf * diff_mult * party_pow)) + randi_range(-3, 3)
	var b_dex := int(round(bbd * diff_mult * party_pow)) + randi_range(-3, 3)
	var b_con := int(round(bbc * diff_mult * party_pow)) + randi_range(-3, 3)
	var boss_power := (b_force + b_dex + b_con) / ((bbf + bbd + bbc) * diff_mult)
	var b_ability := ""
	if not damage_spells.is_empty():      # un boss a toujours une capacité spéciale
		b_ability = str(choice(damage_spells).id)
	var boss := {"id": "boss_gen_%d" % i, "name": "👑 " + str(bf[0]), "icon": "@icon:" + str(bf[1]), "x": boss_cell.x, "y": boss_cell.y, "isBoss": true,
		"force": b_force, "dex": b_dex, "con": b_con, "speed": randi_range(8, 12),
		"resistPhys": randi_range(10, 25) if randf() < 0.4 else 0, "resistMagic": randi_range(10, 25) if randf() < 0.4 else 0,
		"abilitySpellId": b_ability, "abilityChance": randi_range(35, 50) if b_ability != "" else 0,
		"enrageThreshold": randi_range(35, 55) if bool(cfg.get("bossRage", true)) else 0, "enrageBonusPct": randi_range(25, 40), "patrolRadius": randi_range(2, 3),
		"attackSpeed": rand_f1(2.2, 3) * float(mod.attackSpeedMult),
		"xpReward": maxi(20, int(round((60 + i * 25) * diff_mult * boss_power * party_pow * float(mod.xpMult)))),
		"goldReward": maxi(15, int(round((30 + i * 15) * diff_mult * boss_power * float(mod.goldMult)))), "opensDoorId": ""}
	boss.merge(Resist.roll(str(bf[1]), true, 100.0, bool(cfg.get("bossResist", true))), true)
	# boss plus costauds : PV et dégâts majorés (réglages bossHpMult, bossFinalHpMult, bossDmgPct, bossRewardPct)
	boss["hpMult"] = float(cfg.get("bossFinalHpMult", 2.2)) if i == num_levels - 1 else float(cfg.get("bossHpMult", 1.8))
	boss["dmgMult"] = (1.0 + float(cfg.get("bossDmgPct", 10)) / 100.0) * float(mod.monsterDmgMult)
	boss["hpMult"] = float(boss["hpMult"]) * float(mod.monsterHpMult)
	var rw := 1.0 + float(cfg.get("bossRewardPct", 25)) / 100.0
	boss["xpReward"] = int(round(int(boss.xpReward) * rw))
	boss["goldReward"] = int(round(int(boss.goldReward) * rw))
	boss.merge(MonsterEffects.roll(str(bf[1]), true, 100.0, bool(cfg.get("bossStatus", true)), i), true)       # un boss a toujours un effet
	monsters.append(boss)

	# butin au sol
	var item_pool := rooms.filter(func(r): return not used.has(_key(r.x, r.y)))
	var take := func() -> Dictionary:
		if item_pool.is_empty():
			return {}
		var r: Dictionary = item_pool.pop_at(randi_range(0, item_pool.size() - 1))
		used[_key(r.x, r.y)] = true
		return r
	# case libre adossée à un mur (pour loger une fontaine dans un décroché) ; à défaut, n'importe quelle case libre
	var take_walled := func() -> Dictionary:
		var walled := item_pool.filter(func(r): return _has_wall_side(grid, r.x, r.y))
		if walled.is_empty():
			return take.call()
		var r: Dictionary = walled[randi_range(0, walled.size() - 1)]
		item_pool.erase(r)
		used[_key(r.x, r.y)] = true
		return r
	var item_mult := float(mod.itemMult)
	var heal_tier := i / 3
	var sta_tier := i / 3
	var loot_rounds := maxi(1, int(round(rooms.size() / 36.0 * float(mod.lootMult))))
	var equip_here := false
	for lr in loot_rounds:
		if randf() < minf(1.0, 0.7 * item_mult):
			for pi in randi_range(1, 2):
				var r: Dictionary = take.call()
				if not r.is_empty():
					items.append({"id": "pot_gen_%d_%d_%d" % [i, lr, pi], "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": r.x, "y": r.y, "type": "potion", "heal": 12 + heal_tier * 8 + run_bonus * 2})
		if randf() < minf(1.0, 0.5 * item_mult):
			var r: Dictionary = take.call()
			if not r.is_empty():
				items.append({"id": "pot_sta_gen_%d_%d" % [i, lr], "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": r.x, "y": r.y, "type": "potion", "staminaRestore": 18 + sta_tier * 9 + run_bonus * 3})
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
	# pièges : toujours sur le passage obligé (une case que le groupe doit traverser pour atteindre la sortie), jamais dans une impasse
	# où le joueur ne s'aventurerait pas ; faute de passage libre, la case est remplacée par un objet à ramasser
	var forced: Array = _forced_passage(grid, dist, item_pool, far, sx, sy)
	var trap_n := randi_range(2, 3)
	trap_n = int(round(trap_n * float(mod.trapMult)))        # « Couloirs piégés » : +50 % (2 → 3, 3 → 5) ; sans modificateur, inchangé
	for ti in trap_n:
		var tk: Dictionary = choice(TRAP_KINDS)
		var r: Dictionary = {}
		if tk.kind == "dart":     # fléchettes : mécanisme fixé au mur, donc seulement sur une case adossée à un mur ; à défaut, des pointes
			var wl := forced.filter(func(c): return _has_wall_side(grid, c.x, c.y))
			if wl.is_empty():
				tk = TRAP_KINDS[0]
			else:
				r = wl[randi_range(0, wl.size() - 1)]
		if r.is_empty() and not forced.is_empty():
			r = forced[randi_range(0, forced.size() - 1)]
		if r.is_empty():
			r = take.call()
			if not r.is_empty():
				match choice(["potion", "armor", "jewelry", "stamina"]):
					"potion": items.append({"id": "pot_trapless_%d_%d" % [i, ti], "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": r.x, "y": r.y, "type": "potion", "heal": 12 + heal_tier * 8 + run_bonus * 2})
					"stamina": items.append({"id": "pot_sta_trapless_%d_%d" % [i, ti], "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": r.x, "y": r.y, "type": "potion", "staminaRestore": 18 + sta_tier * 9 + run_bonus * 3})
					"armor":
						items.append(make_armor("ar_trapless_%d_%d" % [i, ti], L.t("rules.dungeon_generator.equipement_trouve"), r.x, r.y))
						equip_here = true
					_:
						items.append(make_jewelry("jw_trapless_%d_%d" % [i, ti], L.t("rules.dungeon_generator.bijou_trouve"), r.x, r.y))
						equip_here = true
			continue
		forced.erase(r)
		item_pool.erase(r)
		used[_key(r.x, r.y)] = true
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
		items.append({"id": "key_gen_%d" % i, "name": L.fa(L.t("rules.dungeon_generator.cle_du_niveau"), i + 1), "icon": "@icon:misc_key", "x": key_placed.x, "y": key_placed.y, "type": "key", "opensDoorId": key_placed.doorId})
	var spells: Array = cfg.get("spells", [])
	if not spells.is_empty() and randf() < 0.4:
		var r: Dictionary = take.call()
		if not r.is_empty():
			var sp: Dictionary = choice(spells)
			items.append({"id": "scroll_gen_%d" % i, "name": L.t("common.parchemin_de") + str(sp.name), "icon": "@icon:misc_scroll", "x": r.x, "y": r.y, "type": "scroll", "spellId": sp.id})
	if not fountain_here and not mod.noFountains and (i == 0 or since_fountain >= 2 or randf() < 0.45):
		var r: Dictionary = take_walled.call()
		if not r.is_empty():
			items.append({"id": "fountain_gen_%d" % i, "name": L.t("rules.dungeon_generator.fontaine_de_vie"), "icon": "@icon:misc_fountain", "x": r.x, "y": r.y, "type": "fountain"})
			fountain_here = true
	since_fountain = 0 if fountain_here else since_fountain + 1

	# coffres : posés contre un mur, le plus souvent dans une salle, parfois dans un couloir (ils ne gênent jamais le passage) ; seulement
	# avec les salles (l'ancien labyrinthe, rejoué à l'identique, n'en a pas)
	if not legacy_layout:
		var chest_want := clampi(int(round(float(rects.size()) * 0.7 + randf())), 1 if not rects.is_empty() else 0, 4)
		if rects.is_empty() and randf() < 0.5:
			chest_want = 1
		for ci in chest_want:
			var spots := item_pool.filter(func(r): return _has_wall_side(grid, r.x, r.y) and not _near_stairs(grid, r.x, r.y, 3) and not _near_door(doors, r.x, r.y))
			if spots.is_empty():
				break
			var in_room := spots.filter(func(r): return _room_mask.has(_key(int(r.x), int(r.y))))
			var in_corr := spots.filter(func(r): return not _room_mask.has(_key(int(r.x), int(r.y))))
			var from: Array = in_room if (not in_room.is_empty() and (in_corr.is_empty() or randf() < 0.7)) else in_corr
			var spot: Dictionary = from[randi_range(0, from.size() - 1)]
			item_pool.erase(spot)
			used[_key(spot.x, spot.y)] = true
			items.append(_make_chest(i, ci, grid, int(spot.x), int(spot.y), run_bonus, heal_tier, sta_tier))

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
			"potion": loot = {"id": lid, "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": sx, "y": sy, "type": "potion", "heal": 10 + i * 4 + run_bonus * 2}
			"potion_sta": loot = {"id": lid, "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": sx, "y": sy, "type": "potion", "staminaRestore": 15 + i * 5 + run_bonus * 3}
			"weapon": loot = make_weapon(lid, L.t("rules.dungeon_generator.arme_du_butin"), sx, sy, 2 + i + run_bonus, 3 + i * 2 + run_bonus * 2, 1.0, "monster")
			"armor": loot = make_armor(lid, L.t("rules.dungeon_generator.equipement_du_butin"), sx, sy, 1.0, "monster")
			_: loot = make_jewelry(lid, L.t("rules.dungeon_generator.bijou_du_butin"), sx, sy, 1.0, "monster")
		loot["startHidden"] = true
		items.append(loot)
		mon["lootItemId"] = lid
		mon["lootChance"] = mini(100, int(round(randi_range(40, 80) * float(mod.lootMult))))

	# butin du boss
	# chance de base d'un légendaire sur un boss : Facile 4 % (très rare), Normale 15 %, Difficile 30 %, Hardcore 50 % (Facile et Normale suivent le réglage « legendaryChancePct ») ;
	# avec la « pitié » la moyenne mesurée par boss est d'environ 7 / 22 / 37 / 56 % (tools/check_boss_loot.tscn)
	var cfg_legend := float(cfg.get("legendaryChancePct", 25))
	var legend_base: float = 50.0 if difficulty == "hardcore" else (30.0 if difficulty == "hard" else (cfg_legend * 0.16 if difficulty == "easy" else cfg_legend * 0.6))
	var legend_pct: float = 100.0 if mod.forceLegendary else minf(100.0, roundf(legend_base * run_escalation))
	var boss_loot: Dictionary
	match choice(["weapon", "armor", "jewelry"]):
		"weapon": boss_loot = make_weapon("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 3 + i * 2 + run_bonus, 5 + i * 2 + run_bonus * 2, 1.0, "boss")
		"armor": boss_loot = make_armor("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 1.3, "boss")
		_: boss_loot = make_jewelry("loot_boss_%d" % i, L.t("rules.dungeon_generator.butin_du_gardien"), sx, sy, 1.3, "boss")
	boss_loot["startHidden"] = true
	legend_pct = minf(100.0, legend_pct + _legend_pity)   # « pitié » : chaque gardien sans légendaire rapproche le prochain
	if randf() < legend_pct / 100.0:
		apply_legendary(boss_loot, _boss_mythic_pct())
		_legend_pity = 0.0
	else:
		_legend_pity = minf(10.0 if difficulty == "easy" else 40.0, _legend_pity + (2.0 if difficulty == "easy" else 8.0))
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

## Coffre posé contre un mur de la case (x, y) : or et 1 à 3 objets (équipement un cran au-dessus du sol, potions).
func _make_chest(i: int, ci: int, grid: Array, x: int, y: int, run_bonus: int, heal_tier: int, sta_tier: int) -> Dictionary:
	var walls: Array = []
	var names := ["N", "E", "S", "O"]
	for di in 4:
		var v: Vector2i = DungeonGrid.DIRS[di]
		var nx := x + v.x
		var ny := y + v.y
		if ny < 0 or ny >= grid.size() or nx < 0 or nx >= grid[0].size() or grid[ny][nx] == "#":
			walls.append(names[di])
	var wall: String = walls[randi_range(0, walls.size() - 1)] if not walls.is_empty() else "N"
	var contents: Array = []
	var n := 1 + (1 if randf() < 0.45 else 0) + (1 if randf() < 0.15 else 0)
	for k in n:
		var cid := "chest_%d_%d_%d" % [i, ci, k]
		var roll := randf()
		if roll < 0.25:
			contents.append(make_weapon(cid, L.t("rules.dungeon_generator.arme_trouvee"), x, y, 2 + i + run_bonus, 3 + i * 2 + run_bonus * 2, 1.1, "chest"))
		elif roll < 0.5:
			contents.append(make_armor(cid, L.t("rules.dungeon_generator.equipement_trouve"), x, y, 1.1, "chest"))
		elif roll < 0.7:
			contents.append(make_jewelry(cid, L.t("rules.dungeon_generator.bijou_trouve"), x, y, 1.1, "chest"))
		elif roll < 0.9:
			contents.append({"id": cid, "name": L.t("common.potion_de_soin"), "icon": "@icon:potion_heal", "x": x, "y": y, "type": "potion", "heal": 12 + heal_tier * 8 + run_bonus * 2})
		else:
			contents.append({"id": cid, "name": L.t("common.potion_endurance"), "icon": "@icon:potion_endurance", "x": x, "y": y, "type": "potion", "staminaRestore": 18 + sta_tier * 9 + run_bonus * 3})
	var gold := int(round((randi_range(8, 14) + i * 6 + run_bonus * 3) * float(mod.goldMult)))
	return {"id": "chest_gen_%d_%d" % [i, ci], "name": L.t("rules.dungeon_generator.coffre"), "icon": "@icon:chest", "x": x, "y": y, "type": "chest",
		"wall": wall, "gold": maxi(1, gold), "contents": contents}

func _boss_spot_ok(r: Dictionary, sx: int, sy: int, used: Dictionary, monsters: Array, grid: Array, doors: Array, check_door: bool) -> bool:
	if absi(int(r.x) - sx) + absi(int(r.y) - sy) < START_CLEAR - 2:
		return false         # jamais un boss près de l'arrivée du joueur
	if used.has(_key(r.x, r.y)) or not _far_from_monsters(r.x, r.y, monsters, BOSS_GAP) or _near_stairs(grid, r.x, r.y, 3):
		return false
	return not (check_door and _near_door(doors, r.x, r.y))

func _resist() -> Dictionary:
	var roll := randf()
	if roll < 0.65:
		return {"resistPhys": 0, "resistMagic": 0}
	if roll < 0.85:
		return {"resistPhys": randi_range(10, 35), "resistMagic": 0}
	return {"resistPhys": 0, "resistMagic": randi_range(10, 35)}

## Écarts (en cases, à vol d'oiseau : le chemin réel est au moins aussi long) entre un nouveau monstre et ceux déjà placés, du plus souhaitable au minimum toléré.
var _room_mask: Dictionary = {}     ## cases de sol des salles du niveau en cours de génération (clés « x,y »)

const MONSTER_GAPS := [8, 7, 6, 5, 4, 3]
const BOSS_GAP := 5

func _far_from_monsters(x: int, y: int, placed: Array, gap: int = 2) -> bool:
	for m in placed:
		if absi(int(m.x) - x) + absi(int(m.y) - y) < gap:
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
## Vrai si au moins un des 4 voisins de la case est un mur plein (là où un décroché peut être creusé).
## Jusqu'à 6 cases (parmi `pool`) du plus court chemin départ → sortie dont le blocage coupe la sortie : le groupe ne peut pas les éviter.
## On écarte les abords des escaliers (pas de piège dès l'arrivée). Chaque case est testée par un parcours : seul le chemin est examiné.
static func _forced_passage(grid: Array, dist: Array, pool: Array, far: Dictionary, sx: int, sy: int) -> Array:
	var in_pool := {}
	for c in pool:
		in_pool[_key(c.x, c.y)] = c
	var out: Array = []
	var cur := Vector2i(int(far.x), int(far.y))
	var guard := 0
	while cur != Vector2i(sx, sy) and guard < 100000:
		guard += 1
		var step := Vector2i(-1, -1)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.y >= 0 and n.y < grid.size() and n.x >= 0 and n.x < grid[0].size() and int(dist[n.y][n.x]) == int(dist[cur.y][cur.x]) - 1 and int(dist[n.y][n.x]) >= 0:
				step = n
				break
		if step.x < 0:
			break
		cur = step
		var k := _key(cur.x, cur.y)
		if in_pool.has(k) and maxi(absi(cur.x - sx), absi(cur.y - sy)) >= 4 and maxi(absi(cur.x - int(far.x)), absi(cur.y - int(far.y))) >= 4:
			out.append(in_pool[k])
	# seules quelques cases sont vérifiées (un parcours chacune) : trois pièges au plus, le reste du chemin est inutile à tester
	out.shuffle()
	var sure: Array = []
	for c in out:
		if sure.size() >= 6:
			break
		if int(bfs(grid, sx, sy, Vector2i(int(c.x), int(c.y)))[far.y][far.x]) < 0:
			sure.append(c)
	return sure

static func _has_wall_side(grid: Array, x: int, y: int) -> bool:
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if ny >= 0 and ny < grid.size() and nx >= 0 and nx < grid[0].size() and grid[ny][nx] == "#":
			return true
	return false

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
			if _room_mask.has(_key(n.x, n.y)):
				continue          # jamais de porte au milieu d'une salle : seulement dans un couloir ou à l'entrée
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

## Hache pendulaire : sur certains niveaux (chance `pendulumChancePct`, à partir du niveau `pendulumMinLevel`), un piège de couloir sur le
## chemin de la sortie et, ailleurs sur la carte, le levier de contrepoids qui le bloque. Passage à part, avec son propre générateur
## (seedé par l'identifiant du niveau) : il ne consomme AUCUN tirage du hasard général, donc ne change ni les monstres ni le butin d'une graine.
func _place_pendulums(lvls: Array) -> void:
	var s := TrapRules.cfg(cfg)
	if float(s.pendulumChancePct) <= 0.0:
		return
	for i in lvls.size():
		var lv: Dictionary = lvls[i]
		if i + 1 < int(s.pendulumMinLevel):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("pendulum|" + str(lv.id))
		if rng.randf() * 100.0 >= minf(100.0, float(s.pendulumChancePct) * float(mod.trapMult)):
			continue
		var rows: Array = lv.mapRows
		var occupied := {}
		var specials: Array = [Vector2i(int(lv.startX), int(lv.startY))]
		for m in lv.monsters:
			occupied[_key(int(m.x), int(m.y))] = true
		for it in lv.items:
			occupied[_key(int(it.x), int(it.y))] = true
			if str(it.get("type", "")) == "fountain":
				specials.append(Vector2i(int(it.x), int(it.y)))
		for d in lv.doors:
			occupied[_key(int(d.x), int(d.y))] = true
			specials.append(Vector2i(int(d.x), int(d.y)))
		for st in lv.stairs:
			occupied[_key(int(st.x), int(st.y))] = true
			specials.append(Vector2i(int(st.x), int(st.y)))
		var tm = lv.get("travelingMerchant")
		if tm is Dictionary:
			specials.append(Vector2i(int(tm.x), int(tm.y)))
		var grid: Array = []
		for r in rows:
			grid.append((r as String).split(""))
		# chemin le plus court de l'arrivée à la sortie : le piège s'y trouve de préférence (on le rencontre forcément)
		var dist := bfs(grid, int(lv.startX), int(lv.startY))
		var path := {}
		var cur := Vector2i(int(lv.stairs[0].x), int(lv.stairs[0].y))
		var guard := 0
		while dist[cur.y][cur.x] > 0 and guard < 100000:
			guard += 1
			path[_key(cur.x, cur.y)] = true
			var nxt := Vector2i(-1, -1)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cur + d
				if n.y >= 0 and n.y < dist.size() and n.x >= 0 and n.x < dist[0].size() and int(dist[n.y][n.x]) == int(dist[cur.y][cur.x]) - 1 and int(dist[n.y][n.x]) >= 0:
					nxt = n
					break
			if nxt.x < 0:
				break
			cur = nxt
		var on_path: Array = []
		var anywhere: Array = []
		for y in rows.size():
			for x in (rows[y] as String).length():
				if (x + y) % 2 != 1 or occupied.has(_key(x, y)):     # parité : ces cases ne portent jamais de torche murale (voir LevelBuilder)
					continue
				var axis := _corridor_axis(rows, x, y)
				if axis == "":
					continue
				var near := false
				for sp in specials:
					if maxi(absi(sp.x - x), absi(sp.y - y)) <= 2:
						near = true
						break
				if near:
					continue
				var c := {"x": x, "y": y, "axis": axis}
				anywhere.append(c)
				if path.has(_key(x, y)):
					on_path.append(c)
		var pool: Array = on_path if not on_path.is_empty() else anywhere
		if pool.is_empty():
			continue
		var spot: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		# levier de contrepoids : une case libre loin de la hache, ni sur le chemin forcé ni près d'un point spécial
		var free: Array = []
		for y in rows.size():
			for x in (rows[y] as String).length():
				if (rows[y] as String)[x] != "." or occupied.has(_key(x, y)) or (x == int(spot.x) and y == int(spot.y)):
					continue
				if maxi(absi(x - int(spot.x)), absi(y - int(spot.y))) < 6 or int(dist[y][x]) < 0:
					continue
				var close := false
				for sp in specials:
					if maxi(absi(sp.x - x), absi(sp.y - y)) <= 1:
						close = true
						break
				if not close:
					free.append(Vector2i(x, y))
		if free.is_empty():
			continue
		var on_wall: Array = free.filter(func(c: Vector2i) -> bool:      # interrupteur mural : de préférence une case qui touche un mur
			return _wall_at(rows, c.x + 1, c.y) or _wall_at(rows, c.x - 1, c.y) or _wall_at(rows, c.x, c.y + 1) or _wall_at(rows, c.x, c.y - 1))
		var lever_pool: Array = on_wall if not on_wall.is_empty() else free
		var lever: Vector2i = lever_pool[rng.randi_range(0, lever_pool.size() - 1)]
		var pid := "pend_gen_%d" % i
		lv.items.append({"id": pid, "name": L.t("rules.dungeon_generator.hache_pendulaire"), "icon": "🪓", "x": int(spot.x), "y": int(spot.y), "type": "pendulum",
			"axis": str(spot.axis), "permanent": true, "leverId": "pend_lever_%d" % i,
			"trapDmgMin": 2 + int(i * 0.8) + int(run_bonus * 0.5), "trapDmgMax": 5 + int(i * 1.2) + run_bonus})
		lv.items.append({"id": "pend_lever_%d" % i, "name": L.t("rules.dungeon_generator.levier_de_contrepoids"), "icon": "@icon:misc_lever", "x": lever.x, "y": lever.y,
			"type": "switch", "switchDisarmsId": pid})

## Axe d'un couloir rectiligne : « ns » (murs à l'est et à l'ouest, ouvert au nord et au sud), « ew » (l'inverse), « » sinon.
static func _corridor_axis(rows: Array, x: int, y: int) -> String:
	if (rows[y] as String)[x] != ".":
		return ""
	var n := not _wall_at(rows, x, y - 1) and (rows[y - 1] as String)[x] == "."
	var s2 := not _wall_at(rows, x, y + 1) and (rows[y + 1] as String)[x] == "."
	var e := _wall_at(rows, x + 1, y)
	var w := _wall_at(rows, x - 1, y)
	if n and s2 and e and w:
		return "ns"
	var e2 := not _wall_at(rows, x + 1, y) and (rows[y] as String)[x + 1] == "."
	var w2 := not _wall_at(rows, x - 1, y) and (rows[y] as String)[x - 1] == "."
	if e2 and w2 and _wall_at(rows, x, y - 1) and _wall_at(rows, x, y + 1):
		return "ew"
	return ""

## Marchand ambulant sur le 2ᵉ niveau (ou le seul) : étal logé dans un décroché du mur, sur une case libre contre un mur.
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
	var rows: Array = ml.mapRows
	var free: Array = []
	var back: Array = []   # cases contre un mur
	var wide: Array = []   # cases contre un mur assez long pour le grand étal (voir LevelBuilder.merchant_niche_spec)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "." and not occupied.has(_key(x, y)):
				free.append(Vector2i(x, y))
				if _wall_sides(rows, x, y) > 0 and not _near_special(ml, x, y):
					back.append(Vector2i(x, y))
					if _wide_wall(rows, x, y):
						wide.append(Vector2i(x, y))
	# l'étal est logé dans un décroché du mur : il ne bloque jamais la case, donc aucune contrainte de connexité
	var pool: Array = wide if not wide.is_empty() else back
	if pool.is_empty():   # à défaut : une case libre dont l'occupation ne coupe jamais la carte (le marchand s'y tient alors)
		pool = free.filter(func(c): return _keeps_connected(rows, c))
	if not pool.is_empty():
		var spot: Vector2i = choice(pool)
		ml["travelingMerchant"] = {"x": spot.x, "y": spot.y, "patrolRadius": 0}

## Mur assez long pour le grand étal : les deux cases voisines le long du mur sont libres et pleines derrière.
static func _wide_wall(rows: Array, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _wall_at(rows, x + d.x, y + d.y):
			continue
		var r := Vector2i(-d.y, d.x)
		var ok := true
		for k in [-1, 1]:
			var nx: int = x + r.x * k
			var ny: int = y + r.y * k
			if _wall_at(rows, nx, ny) or (rows[ny] as String)[nx] != "." or not _wall_at(rows, nx + d.x, ny + d.y):
				ok = false
		if ok:
			return true
	return false

static func _wall_at(rows: Array, x: int, y: int) -> bool:
	return y < 0 or y >= rows.size() or x < 0 or x >= (rows[y] as String).length() or (rows[y] as String)[x] == "#"

const START_CLEAR := 8     ## distance minimale (en cases) entre l'arrivée du joueur et un monstre à la création du niveau

static func _wall_sides(rows: Array, x: int, y: int) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _wall_at(rows, x + d.x, y + d.y):
			n += 1
	return n

## Pas collé à une porte, un escalier ou au départ (on ne doit jamais gêner un passage).
static func _near_special(ml: Dictionary, x: int, y: int) -> bool:
	for l in [ml.doors, ml.stairs]:
		for o in l:
			if absi(int(o.x) - x) + absi(int(o.y) - y) <= 1:
				return true
	return absi(int(ml.startX) - x) + absi(int(ml.startY) - y) <= 2

## Vrai si, une fois la case `cell` occupée, toutes les autres cases praticables restent reliées.
static func _keeps_connected(rows: Array, cell: Vector2i) -> bool:
	var total := 0
	var start := Vector2i(-1, -1)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "#" and Vector2i(x, y) != cell:
				total += 1
				if start.x < 0:
					start = Vector2i(x, y)
	if total == 0:
		return false
	var seen := {start: true}
	var q: Array = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n != cell and not seen.has(n) and not _wall_at(rows, n.x, n.y):
				seen[n] = true
				q.append(n)
	return seen.size() == total

# ------------------------------------------------------------------ groupe aléatoire

## Portrait qui montre la même image que `path` (dans un sens ou dans l'autre), ou "".
static func _portrait_twin(path: String) -> String:
	var stem := path.get_file().get_basename()
	for k in PORTRAIT_TWINS:
		if k == stem:
			return "res://assets/portraits/%s.webp" % str(PORTRAIT_TWINS[k])
		if str(PORTRAIT_TWINS[k]) == stem:
			return "res://assets/portraits/%s.webp" % k
	return ""

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
## `picks` (facultatif, partie libre) : le groupe choisi par le joueur, [{"classId", "portrait"}] pour 1 à 4 héros (2 d'une même classe au maximum) ;
## `portrait` = indice du portrait de la classe (-1 : au hasard). Vide : groupe tiré au hasard comme avant.
static func generate_party(cfg: Dictionary, diff: String, picks: Array = []) -> Array:
	var base_ids: Array = []
	for c in cfg.get("classes", []):
		if _is_base(c):
			base_ids.append(str(c.id))
	if base_ids.is_empty():
		return cfg.get("party", [])
	var counts := {}
	var chosen: Array = []
	var wanted: Array = []        # portrait demandé par héros (indice), -1 = au hasard
	for pk in picks:
		var cid := str(pk.get("classId", ""))
		if chosen.size() < 4 and base_ids.has(cid) and int(counts.get(cid, 0)) < 2:
			counts[cid] = int(counts.get(cid, 0)) + 1
			chosen.append(cid)
			wanted.append(int(pk.get("portrait", -1)))
	var manual := not chosen.is_empty()
	if not manual:
		for i in 4:
			var avail := base_ids.filter(func(id): return int(counts.get(id, 0)) < 2)
			var pick: String = choice(avail)
			counts[pick] = int(counts.get(pick, 0)) + 1
			chosen.append(pick)
		chosen.shuffle()
	var any_evo := manual         # un groupe choisi à la main n'est pas retouché
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
	var stamp := randi() % 1000000000
	var out: Array = []
	for idx in chosen.size():
		var cls := Characters.class_def(cfg, str(chosen[idx]))
		var cname := str(cls.name)
		var t: Array = ARCHETYPE_STATS.get(cname, [11, 11, 11, 11])
		var portrait := ""
		if PORTRAIT_FILES.has(cname):
			var want: int = int(wanted[idx]) if idx < wanted.size() else -1
			var want_path := "res://assets/portraits/%s_%d.webp" % [PORTRAIT_FILES[cname], want]
			if want >= 0 and want < int(PORTRAIT_COUNTS[cname]) and not used_portraits.has(want_path) and not used_portraits.has(_portrait_twin(want_path)):
				portrait = want_path
				used_portraits[portrait] = true
			var free: Array = []
			for n in int(PORTRAIT_COUNTS[cname]):
				var p := "res://assets/portraits/%s_%d.webp" % [PORTRAIT_FILES[cname], n]
				if not used_portraits.has(p) and not used_portraits.has(_portrait_twin(p)):
					free.append(p)
			if portrait == "" and not free.is_empty():
				portrait = choice(free)
				used_portraits[portrait] = true
		var weapon_id := ""
		var wt: String = Characters.signature_weapon_type(cls)   # arme emblématique de la classe : bâton pour le mage et le druide, épée pour le guerrier…
		var cands: Array = (cfg.get("itemLibrary", []) as Array).filter(func(it): return it.get("type") == "weapon" and wt == str(it.get("weaponType")))
		if cands.is_empty():   # bibliothèque personnalisée sans arme de ce type : repli sur un type autorisé
			var allowed: Array = cls.get("allowedWeaponTypes", [])
			cands = (cfg.get("itemLibrary", []) as Array).filter(func(it): return it.get("type") == "weapon" and allowed.has(it.get("weaponType")))
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
## `seed_value` >= 0 : génération REPRODUCTIBLE (mêmes paramètres + même graine = même donjon, même groupe de héros, mêmes titres) ;
## indispensable aux parties classées, que le serveur rejoue pour les vérifier. -1 : hasard libre.
static func build_config(base: Dictionary, num_levels: int, width: int, height: int, diff: String, mods: Array, run: int = 1, seed_value: int = -1, picks: Array = []) -> Dictionary:
	if seed_value >= 0:
		return Seeds.with_global(Seeds.derive(seed_value, "expedition", run), func(): return build_config(base, num_levels, width, height, diff, mods, run, -1, picks))
	var c: Dictionary = base.duplicate(true)
	var gen := DungeonGenerator.new(c, diff, run, mods)
	c["party"] = generate_party(c, diff, picks)
	if bool(gen.mod.soloParty) and (c["party"] as Array).size() > 1:
		c["party"] = (c["party"] as Array).slice(0, 1)        # « Héros solitaire » : le tirage du groupe est le même, seul le premier part
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
