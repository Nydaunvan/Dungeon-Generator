class_name RoomStyles
extends RefCounted
## Style de décoration de chaque salle d'un niveau. Purement visuel et déterministe (hachage de la position et de l'identifiant du niveau,
## jamais le hasard du jeu), donc sans effet sur les règles, les déplacements ni le rejeu.
##
## Ordre de décision pour une salle :
##   1. le choix de l'éditeur (`level.roomStyles`, clé « x,y » du coin haut-gauche de la salle) ;
##   2. le contenu : repaire du boss, salle du marchand, salle d'un coffre (trésor) ;
##   3. sinon un style courant, tiré selon le thème en évitant de répéter le précédent et en variant d'une salle à l'autre.
## Une salle « vedette » (la plus grande du niveau) reçoit toujours sa pièce maîtresse ; les autres une fois sur trois.

const GENERAL := ["bibliotheque", "armes", "cellier", "autel", "ruine", "commune", "humide"]
const CONTENT := ["tresor", "repaire", "marche"]
const ALL := ["bibliotheque", "armes", "cellier", "autel", "ruine", "commune", "humide", "tresor", "repaire", "marche"]

## Taille minimale (cases de sol, et côté du rectangle englobant) pour accueillir une pièce maîtresse ou un style encombrant.
const SMALL_CELLS := 9
const BIG_STYLES := ["commune", "autel", "armes"]

## Poids de tirage par thème (1 par défaut).
const THEME_WEIGHTS := {
	"stone": {},
	"dirt": {"cellier": 3.0, "ruine": 2.0, "humide": 1.5, "autel": 0.4},
	"damp": {"humide": 4.0, "cellier": 1.5, "ruine": 1.5, "bibliotheque": 0.6},
	"ruins": {"ruine": 4.0, "autel": 1.5, "humide": 1.3, "commune": 0.6},
	"ice": {"ruine": 2.0, "humide": 2.0, "autel": 1.5, "cellier": 0.8},
	"lava": {"armes": 3.0, "ruine": 1.5, "autel": 1.2, "humide": 0.2, "bibliotheque": 0.5},
	"temple": {"autel": 3.0, "bibliotheque": 2.5, "commune": 0.8, "cellier": 0.6},
}

static func _h(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

static func key_of(rect: Rect2i) -> String:
	return "%d,%d" % [rect.position.x, rect.position.y]

## Style de chaque salle : {id de salle (int) -> style}. `rooms` vient de RoomMap.detect.
static func assign(level: Dictionary, rooms: Array, theme: String) -> Dictionary:
	var out := {}
	if rooms.is_empty():
		return out
	var idx := RoomMap.index(rooms)
	var forced := {}
	for m in level.get("monsters", []):
		var c := Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))
		if bool(m.get("isBoss", false)) and idx.has(c):
			forced[idx[c]] = "repaire"
	var tm = level.get("travelingMerchant")
	if tm is Dictionary:
		var mc := Vector2i(int(tm.get("x", -1)), int(tm.get("y", -1)))
		if idx.has(mc) and not forced.has(idx[mc]):
			forced[idx[mc]] = "marche"
	# Trésor : la salle qui contient le plus de coffres (à égalité, la plus grande), et toute salle d'au moins deux coffres.
	var chests := {}
	for it in level.get("items", []):
		if str(it.get("type", "")) == "chest":
			var cc := Vector2i(int(it.get("x", -1)), int(it.get("y", -1)))
			if idx.has(cc):
				chests[idx[cc]] = int(chests.get(idx[cc], 0)) + 1
	var rich := -1
	var rich_score := -1.0
	for rid in chests:
		var sc := float(chests[rid]) * 1000.0 + float((rooms[rid].cells as Array).size())
		if sc > rich_score:
			rich_score = sc
			rich = rid
	for rid in chests:
		if (rid == rich or int(chests[rid]) >= 2) and not forced.has(rid):
			forced[rid] = "tresor"
	var chosen: Dictionary = level.get("roomStyles", {}) if level.get("roomStyles") is Dictionary else {}
	var seed := str(level.get("id", "")).hash()
	var weights: Dictionary = THEME_WEIGHTS.get(theme, {})
	var order: Array = rooms.duplicate()
	order.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y or (a.rect.position.y == b.rect.position.y and a.rect.position.x < b.rect.position.x))
	var used := {}
	var prev := ""
	for r in order:
		var rect: Rect2i = r.rect
		var style := ""
		var pick := str(chosen.get(key_of(rect), ""))
		if ALL.has(pick):
			style = pick
		elif forced.has(int(r.id)):
			style = str(forced[int(r.id)])
		else:
			style = _pick(r, seed, weights, used, prev)
		out[int(r.id)] = style
		used[style] = int(used.get(style, 0)) + 1
		prev = style
	return out

static func _pick(r: Dictionary, seed: int, weights: Dictionary, used: Dictionary, prev: String) -> String:
	var rect: Rect2i = r.rect
	var small: bool = (r.cells as Array).size() < SMALL_CELLS or rect.size.x < 3 or rect.size.y < 3
	var cands: Array = []
	for s in GENERAL:
		if small and BIG_STYLES.has(s):
			continue
		cands.append(s)
	if cands.size() > 1 and cands.has(prev):
		cands.erase(prev)
	var total := 0.0
	var w: Array = []
	for s in cands:
		var v := float(weights.get(s, 1.0)) / (1.0 + 2.0 * float(used.get(s, 0)))
		w.append(v)
		total += v
	var roll := float(_h(rect.position.x, rect.position.y, seed) % 10000) / 10000.0 * total
	for i in cands.size():
		roll -= float(w[i])
		if roll < 0.0:
			return str(cands[i])
	return str(cands[cands.size() - 1])

## Salle vedette : la plus grande (à égalité, la première dans l'ordre haut-gauche).
static func vedette(rooms: Array) -> int:
	var best := -1
	var bn := -1
	var order: Array = rooms.duplicate()
	order.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y or (a.rect.position.y == b.rect.position.y and a.rect.position.x < b.rect.position.x))
	for r in order:
		if (r.cells as Array).size() > bn:
			bn = (r.cells as Array).size()
			best = int(r.id)
	return best
