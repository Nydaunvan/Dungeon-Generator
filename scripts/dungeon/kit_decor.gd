class_name KitDecor
extends RefCounted
## Modules d'architecture gothique posés automatiquement sur le niveau (thème « gothic » uniquement). Purement visuel : rien ne bouge dans la
## grille, aucune collision, aucune lumière ; DungeonGrid, le générateur, les déplacements, les portes et le rejeu ne sont jamais touchés.
##
## Les modèles sont des GLB « assets/kit/gothic/<module>.glb » (repère et cotes : assets/kit/gothic/LISEZMOI.md). Un module sans fichier n'est PAS
## posé (rien de provisoire ne s'affiche en jeu) ; seuls les outils de test activent `placeholders` pour vérifier le placement avec des boîtes.
## Chaque module est posé en MultiMesh, par bloc de LevelBuilder.CHUNK × CHUNK cases comme le décor (le moteur n'envoie que les blocs vus).
## Placement déterministe : uniquement la grille et l'identifiant du niveau (jamais GameRng ni le hasard global).
##
## Repères (origine au sol, +Y vers le haut, +Z vers l'intérieur de la case, comme TorchLayer) :
##   pilaster / plinth / ornament : au milieu du plan de mur (pilaster : sur la jonction de deux pans) ;
##   door_frame / stair_frame     : au milieu de l'arête de la porte ou de l'escalier, +Z vers la case d'où on la voit ;
##   arch                         : au milieu de l'arête entre deux cases d'un couloir droit, +Z dans le sens de marche ;
##   pillar                       : au sommet d'angle (mêmes points que les colonnes) ;
##   bracket                      : au point d'accroche de la torche murale (+Z vers l'intérieur, mur en Z = -0,04).

const CELL := LevelBuilder.CELL
const HALF := CELL * 0.5
const GLB_DIR := "res://assets/kit/gothic/"
const THEMES := ["gothic"]
## Modules : id -> description (la taille est celle attendue du modèle, en unités du jeu : 1 case = 4).
const MODULES := {
	"pilaster": {"size": Vector3(0.9, 4.0, 0.45), "note": "pilastre mural gothique, sur la jonction de deux pans, un tous les 2 pans"},
	"plinth": {"size": Vector3(4.0, 0.35, 0.22), "note": "plinthe de pierre, un pan entier, raccord bord à bord"},
	"arch": {"size": Vector3(4.0, 4.0, 0.5), "note": "arche de passage en ogive, ouverture libre >= 3,0 de large et 3,5 de haut"},
	"pillar": {"size": Vector3(0.8, 4.0, 0.8), "note": "pilier sculpté, aux angles (là où le jeu pose ses colonnes)"},
	"door_frame": {"size": Vector3(4.0, 4.0, 0.6), "note": "encadrement massif de porte, ouverture >= 3,0 x 3,4 (la herse reste visible)"},
	"stair_frame": {"size": Vector3(4.0, 4.0, 0.7), "note": "encadrement d'escalier, ouverture >= 3,0 x 3,4"},
	"bracket": {"size": Vector3(0.3, 0.5, 0.35), "note": "support de torche en fer forgé, autour du point d'accroche de la torche"},
	"torch_bracket": {"size": Vector3(0.2, 0.55, 0.15), "note": "V3 : support de torche en fer forgé (platine, volute, collerette) ; remplace bracket quand il existe ; aucune lumière dans le modèle"},
	"ornament": {"size": Vector3(0.7, 1.0, 0.1), "note": "élément décoratif mural discret, centré sur un pan sans torche"},
	# V2 : modules en arc brisé. Générés par code (KitGeometry) tant qu'aucun GLB de ce nom n'existe dans assets/kit/gothic/ ; un GLB artistique les remplace.
	"ogive": {"size": Vector3(4.0, 4.0, 0.6), "note": "arche gothique en ogive de couloir droit (mur plein de 4 u percé d'une baie en arc brisé de 3,1 u, 3,5 u au sommet), ressauts"},
	"portal_room": {"size": Vector3(4.0, 4.0, 0.7), "note": "portail d'entrée de salle : ogive à deux ressauts, imposte et clef"},
	"portal_door": {"size": Vector3(4.0, 4.0, 0.7), "note": "encadrement de porte (herse) : ogive à deux ressauts, imposte et clef"},
	"portal_stair": {"size": Vector3(4.0, 4.0, 0.7), "note": "encadrement d'escalier : ogive à deux ressauts, imposte et clef"},
	"rib": {"size": Vector3(4.0, 1.1, 0.4), "note": "nervure de plafond d'un mur à l'autre, à ressauts, avec corbeaux"},
	"cornice": {"size": Vector3(4.0, 0.4, 0.22), "note": "corniche en haut d'un pan de mur, trois ressauts"},
}

## Interrupteur général (outils, essais) : false = aucun module, le niveau est identique à celui sans kit.
static var enabled := true
## Outils de test seulement : pose des boîtes à la place des GLB manquants.
static var placeholders := false
## Modules générés par code (KitGeometry) quand le GLB du même nom manque : arches en ogive, portails, nervures, corniches. false = seulement les GLB (V1).
static var procedural := true
## Dernier niveau posé : {"total": n, "count": {module: n}} (tests et mesures).
static var last_stats: Dictionary = {}
## GLB livrés au format V3 (assets/kit/gothic/kit_v3.json). Sert à distinguer l'ancien arch.glb (portique rectangulaire du premier pack) d'une vraie ogive.
const V3_FILE := "res://assets/kit/gothic/kit_v3.json"
static func v3_ids() -> Array:
	if ResourceLoader.exists(V3_FILE):
		var j = load(V3_FILE)
		if j is JSON and j.data is Dictionary:
			return (j.data as Dictionary).get("v3", [])
	return []

static var _parts_cache: Dictionary = {}
static var _default_mat: StandardMaterial3D

static func _h(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

## Le kit s'applique à ce niveau : thème prévu, intérieur, pas de refus du niveau (`kit: false`).
static func applies(theme: String, level: Dictionary) -> bool:
	return enabled and THEMES.has(theme) and not bool(level.get("outdoor", false)) and bool(level.get("kit", true))

## Le kit pose son propre encadrement d'escalier sur ce niveau : l'ancien cadre de bronze dessiné (arch_frame.png) est alors inutile et reste caché derrière la pierre.
static func has_stair_frame(theme: String, level: Dictionary) -> bool:
	return applies(theme, level) and (not _parts("portal_stair").is_empty() or not _parts("stair_frame").is_empty())

## Vide le cache des modèles (outils : changement de `placeholders`).
static func reset_cache() -> void:
	_parts_cache.clear()
	_stone_cache.clear()

## Ajoute les modules du kit à `view`. `niches` / `holes` : creux des murs (fontaine, marchand), voir LevelBuilder.niche_data.
static func add(view: LevelView, level: Dictionary, grid: DungeonGrid, theme: String, niches: Dictionary, holes: Dictionary, sliced: bool = false) -> void:
	last_stats = {}
	if not applies(theme, level):
		return
	var avail := {}
	for id in MODULES:
		if not _parts(id).is_empty():
			avail[id] = true
	if avail.is_empty():
		last_stats = {"total": 0, "count": {}}
		return
	var items: Array = await plan(level, grid, niches, holes, avail, sliced)
	_build(view, items)

## Plan de pose : [{id, xf}] (xf = position et orientation du module). Pur calcul, utilisable sans rendu.
## Les portails (arches, entrées de salle) sont calculés d'abord : leurs arêtes ne reçoivent pas de pilastre (même plan).
static func plan(level: Dictionary, grid: DungeonGrid, niches: Dictionary, holes: Dictionary, avail: Dictionary, sliced: bool = false) -> Array:
	var out: Array = []
	var seed := str(level.get("id", "")).hash()
	var blocked := RoomDecor._blocked_cells(level)
	var special := _special_cells(level, blocked, niches)
	var arch_id := "arch" if (avail.has("arch") and v3_ids().has("arch")) else ("ogive" if avail.has("ogive") else "arch")
	var door_id := "portal_door" if avail.has("portal_door") else "door_frame"
	var stair_id := "portal_stair" if avail.has("portal_stair") else "stair_frame"
	var arches: Array = _arch_edges(level, grid, special, seed) if (avail.has(arch_id) or avail.has("portal_room")) else []
	var occupied := {}
	for ar in arches:
		occupied[ar.key] = true
		var id: String = "portal_room" if (ar.kind == "room" and avail.has("portal_room")) else arch_id
		if avail.has(id):
			out.append({"id": id, "xf": Transform3D(Basis(Vector3.UP, ar.ang), ar.pos)})
	if avail.has("rib"):
		for rb in _rib_edges(grid, special, seed, arches):
			out.append({"id": "rib", "xf": Transform3D(Basis(Vector3.UP, rb.ang), rb.pos)})
	for y in grid.height:
		if sliced:
			await Loader.slice()
		for x in grid.width:
			var ch := grid.cell(x, y)
			if ch == "#" or ch == "S":
				continue
			var cell := Vector2i(x, y)
			var c := Vector3(x * CELL, 0.0, y * CELL)
			for di in 4:
				var d: Vector2i = DungeonGrid.DIRS[di]
				var n := grid.cell(x + d.x, y + d.y)
				var edge := c + Vector3(d.x * HALF, 0.0, d.y * HALF)
				var basis := Basis(Vector3.UP, LevelBuilder._rot(d))
				if n == "#":
					if _face_cut(cell, d, niches, holes):
						continue
					if avail.has("plinth"):
						out.append({"id": "plinth", "xf": Transform3D(basis, edge)})
					if avail.has("cornice"):
						out.append({"id": "cornice", "xf": Transform3D(basis, edge)})
					if avail.has("pilaster") and _pilaster_at(grid, cell, d, niches, holes, seed, di, occupied):
						var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
						out.append({"id": "pilaster", "xf": Transform3D(basis, edge + Vector3(t.x * HALF, 0.0, t.y * HALF))})
					var torch := (x + y) % 2 == 0
					var bracket_id := "torch_bracket" if avail.has("torch_bracket") else "bracket"
					if torch and avail.has(bracket_id):
						out.append({"id": bracket_id, "xf": Transform3D(basis, c + Vector3(d.x * CELL * 0.49, CELL * 0.62, d.y * CELL * 0.49))})
					elif not torch and avail.has("ornament") and not special.has(cell) and not _near_special(special, grid, cell, 1) \
							and _h(x, y, seed ^ (di * 131 + 7)) % 4 == 0:
						out.append({"id": "ornament", "xf": Transform3D(basis, edge)})
				elif n == "D" and avail.has(door_id):
					out.append({"id": door_id, "xf": Transform3D(basis, edge)})
				elif n == "S" and avail.has(stair_id):
					out.append({"id": stair_id, "xf": Transform3D(basis, edge)})
	if avail.has("pillar"):
		for p in LevelBuilder.column_points(grid):
			out.append({"id": "pillar", "xf": Transform3D(Basis.IDENTITY, Vector3(p.x, 0.0, p.y))})
	return out

## Face de mur évidée par une niche (fontaine, marchand) ou voisine d'un creux : on n'y pose rien.
static func _face_cut(cell: Vector2i, d: Vector2i, niches: Dictionary, holes: Dictionary) -> bool:
	var ni: Dictionary = niches.get(cell, {})
	if not ni.is_empty() and ni.d == d:
		return true
	return holes.has("%d,%d,%d,%d" % [cell.x, cell.y, d.x, d.y])

## Pilastre sur la jonction entre ce pan et le suivant (côté positif du mur), si le suivant est aussi un pan de mur plein.
## Un pilastre tous les deux pans le long du mur (décalage tiré de la ligne), avec quelques absences pour casser la régularité.
static func _pilaster_at(grid: DungeonGrid, cell: Vector2i, d: Vector2i, niches: Dictionary, holes: Dictionary, seed: int, di: int, occupied: Dictionary = {}) -> bool:
	var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
	var nb := cell + t
	var nch := grid.cell(nb.x, nb.y)
	if nch == "#" or nch == "S" or nch == "D" or grid.cell(cell.x, cell.y) == "D":
		return false
	if occupied.has(Vector2i(cell.x + nb.x, cell.y + nb.y)):      # un portail occupe déjà cette arête
		return false
	if grid.cell(nb.x + d.x, nb.y + d.y) != "#" or _face_cut(nb, d, niches, holes):
		return false
	var along := cell.x if t.x != 0 else cell.y
	var line := cell.y if t.x != 0 else cell.x
	if (along + _h(line, di, seed) % 2) % 2 != 0:
		return false
	return _h(cell.x, cell.y, seed ^ (di * 977 + 3)) % 5 != 0

## Distance minimale (en cases) entre deux arches : le long d'un couloir droit, et autour d'une entrée de salle.
const ARCH_GAP_RUN := 2.9
const ARCH_GAP_ROOM := 2.4

## Case de couloir ouverte à l'avant et à l'arrière (`d`) avec un mur plein de chaque côté : passage droit.
static func _walled_sides(grid: DungeonGrid, c: Vector2i, d: Vector2i) -> bool:
	var p := Vector2i(d.y, d.x)
	return grid.cell(c.x + p.x, c.y + p.y) == "#" and grid.cell(c.x - p.x, c.y - p.y) == "#"

static func _arch_ok(grid: DungeonGrid, c: Vector2i, d: Vector2i, special: Dictionary) -> bool:
	return grid.cell(c.x, c.y) == "." and _walled_sides(grid, c, d) and not special.has(c) and not _near_special(special, grid, c, 1)

## Arête d'arche : deux cases de sol libres, dont AU MOINS UNE est un passage droit (murs pleins de chaque côté). L'autre peut être un angle, un T ou une croix :
## l'arche garde alors l'entrée de l'intersection (elle ne couvre que ± 2 u, les départs latéraux restent au-delà de ses montants).
static func _arch_edge_ok(grid: DungeonGrid, c: Vector2i, nb: Vector2i, d: Vector2i, special: Dictionary) -> bool:
	if grid.cell(nb.x, nb.y) != "." or grid.cell(c.x, c.y) != ".":
		return false
	for q in [c, nb]:
		if special.has(q) or _near_special(special, grid, q, 1):
			return false
	return _walled_sides(grid, c, d) or _walled_sides(grid, nb, d)

## Arches : [{pos, ang}] dans l'ordre de lecture de la grille (donc stables). Deux sortes d'emplacements, jamais près d'une porte, d'un escalier,
## d'une niche, d'un objet, d'un monstre ou du départ (voir `_near_special`) :
##   1. entrées de salle : arête entre une case de couloir (murs pleins de chaque côté) et une case de salle, trois sur quatre ;
##   2. couloirs droits : arête entre deux cases de couloir droites, écartées d'au moins ARCH_GAP_RUN cases des autres arches, deux sur trois.
## Les écarts rendent le motif irrégulier (aucune répétition à pas fixe). Une arche garde l'entrée d'un angle, d'un T ou d'une croix mais n'est jamais posée entre deux cases d'intersection.
static func _arch_edges(level: Dictionary, grid: DungeonGrid, special: Dictionary, seed: int) -> Array:
	var out: Array = []
	var taken: Array = []      # milieux d'arête déjà pris, en cases
	var ridx := RoomMap.index(RoomMap.detect(level.mapRows))
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			if ridx.has(c):
				continue
			for di in 4:
				var d: Vector2i = DungeonGrid.DIRS[di]
				var nb := c + d
				if not ridx.has(nb) or grid.cell(nb.x, nb.y) != "." or not _arch_ok(grid, c, d, special):
					continue
				if _h(x, y, seed ^ (di * 523 + 11)) % 8 == 0 or special.has(nb):
					continue
				_take_arch(out, taken, c, d, ARCH_GAP_ROOM, "room")
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			for e in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = c + e
				if not _arch_edge_ok(grid, c, nb, e, special):
					continue
				if _h(x, y, seed ^ (e.x * 311 + 4099)) % 6 == 0:
					continue
				_take_arch(out, taken, c, e, ARCH_GAP_RUN)
	return out

## Ajoute l'arche de l'arête (c -> c + d) si aucune autre n'est plus près que `gap` cases.
static func _take_arch(out: Array, taken: Array, c: Vector2i, d: Vector2i, gap: float, kind: String = "run") -> void:
	var mid := Vector2(c.x + d.x * 0.5, c.y + d.y * 0.5)
	for t in taken:
		if mid.distance_to(t) < gap:
			return
	taken.append(mid)
	out.append({"pos": Vector3(mid.x * CELL, 0.0, mid.y * CELL), "ang": atan2(float(d.x), float(d.y)), "kind": kind,
			"key": Vector2i(2 * c.x + d.x, 2 * c.y + d.y)})      # +Z du module = sens de marche ; clef = somme des deux cases (arête)

## Nervures de plafond : arêtes de couloir droit (comme les arches), écartées d'au moins RIB_GAP cases entre elles et de RIB_ARCH_GAP cases des arches, trois sur quatre.
const RIB_GAP := 1.9
const RIB_ARCH_GAP := 1.4

static func _rib_edges(grid: DungeonGrid, special: Dictionary, seed: int, arches: Array) -> Array:
	var out: Array = []
	var taken: Array = []
	var amid: Array = []
	for ar in arches:
		amid.append(Vector2((ar.pos as Vector3).x / CELL, (ar.pos as Vector3).z / CELL))
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			for e in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = c + e
				if grid.cell(nb.x, nb.y) != "." or not _arch_ok(grid, c, e, special) or not _arch_ok(grid, nb, e, special):
					continue
				if _h(x, y, seed ^ (e.x * 613 + 29)) % 4 == 0:
					continue
				var mid := Vector2(c.x + e.x * 0.5, c.y + e.y * 0.5)
				var near := false
				for a in amid:
					if mid.distance_to(a) < RIB_ARCH_GAP:
						near = true
				for t in taken:
					if mid.distance_to(t) < RIB_GAP:
						near = true
				if near:
					continue
				taken.append(mid)
				out.append({"pos": Vector3(mid.x * CELL, 0.0, mid.y * CELL), "ang": atan2(float(e.x), float(e.y))})
	return out

## Cases à ménager : objets, marchand, escaliers, départ, niches et départs des monstres.
static func _special_cells(level: Dictionary, blocked: Dictionary, niches: Dictionary) -> Dictionary:
	var out := blocked.duplicate()
	for c in niches:
		out[c] = true
	for m in level.get("monsters", []):
		out[Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))] = true
	out[Vector2i(int(level.get("startX", -1)), int(level.get("startY", -1)))] = true
	return out

## Une case spéciale, une porte ou un escalier se trouve à moins de `r` cases (carré) de `c`.
static func _near_special(special: Dictionary, grid: DungeonGrid, c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2i(c.x + dx, c.y + dy)
			if special.has(q):
				return true
			var ch := grid.cell(q.x, q.y)
			if ch == "D" or ch == "S":
				return true
	return false

# ------------------------------------------------------------------ construction

static func _build(view: LevelView, items: Array) -> void:
	var count := {}
	var groups := {}      # "module|bloc x|bloc z" -> {id, xf: Array[Transform3D], ck}
	var span := CELL * float(LevelBuilder.CHUNK)
	for it in items:
		var id: String = it.id
		var xf: Transform3D = it.xf
		var ck := Vector2i(int(floor((xf.origin.x + HALF) / span)), int(floor((xf.origin.z + HALF) / span)))
		var key := "%s|%d|%d" % [id, ck.x, ck.y]
		if not groups.has(key):
			groups[key] = {"id": id, "ck": ck, "xf": []}
		(groups[key].xf as Array).append(xf)
		count[id] = int(count.get(id, 0)) + 1
	last_stats = {"total": items.size(), "count": count}
	if groups.is_empty():
		return
	var root := Node3D.new()
	root.name = "KitDecor"
	view.add_child(root)
	var keys: Array = groups.keys()
	keys.sort()
	for key in keys:
		var g: Dictionary = groups[key]
		var xfs: Array = g.xf
		var pi := 0
		for part in _parts(str(g.id)):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part.mesh
			mm.instance_count = xfs.size()
			var local: Transform3D = part.xf
			for i in xfs.size():
				mm.set_instance_transform(i, (xfs[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Kit_%s_%d_%d_%d" % [g.id, g.ck.x, g.ck.y, pi]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 80.0
			var mesh: Mesh = part.mesh
			if mesh.get_surface_count() > 0 and mesh.surface_get_material(0) == null:
				mmi.material_override = _kit_material()      # modèle livré sans matériau : pierre sombre neutre
			root.add_child(mmi)
			pi += 1

## Maillages d'un module : [{mesh, xf}] (xf = position du maillage dans le modèle). Vide si le GLB n'existe pas (et hors mode `placeholders`).
static func _parts(id: String) -> Array:
	if _parts_cache.has(id):
		return _parts_cache[id]
	var out: Array = []
	var path := GLB_DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps != null:
			var root := ps.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null:
					continue
				var xf := mi.transform
				var up := mi.get_parent()
				while up != null and up is Node3D:
					xf = (up as Node3D).transform * xf
					up = up.get_parent()
				out.append({"mesh": _with_theme_stone(flat_normals(mi.mesh), _stone_scale(id)), "xf": xf})
			root.free()
	elif procedural and KitGeometry.PROCEDURAL.has(id):
		out.append({"mesh": _with_theme_stone(KitGeometry.build(id), _stone_scale(id)), "xf": Transform3D.IDENTITY})
	elif placeholders:
		out = _placeholder_parts(id)
	_parts_cache[id] = out
	return out

## Les GLB livrés ne contiennent que les positions (ni normales ni UV) : sans normales l'éclairage et la projection triplanaire sont faux (toutes les faces
## se comportent comme si elles regardaient +Z). Les normales sont donc recalculées ici, par face (ombrage plat, sommets dédoublés), d'après le sens
## de rotation des triangles de Godot (sens horaire = face avant). Un modèle qui fournit déjà ses normales est laissé tel quel.
static func flat_normals(mesh: Mesh) -> Mesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		if arr[Mesh.ARRAY_NORMAL] != null or mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), arr)
		else:
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var tri: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
			var pv := PackedVector3Array()
			var pn := PackedVector3Array()
			for t in range(0, tri.size() - 2, 3):
				var a: Vector3 = v[tri[t]]
				var b: Vector3 = v[tri[t + 1]]
				var c: Vector3 = v[tri[t + 2]]
				var n := (c - a).cross(b - a).normalized()
				pv.append_array(PackedVector3Array([a, b, c]))
				pn.append_array(PackedVector3Array([n, n, n]))
			var na: Array = []
			na.resize(Mesh.ARRAY_MAX)
			na[Mesh.ARRAY_VERTEX] = pv
			na[Mesh.ARRAY_NORMAL] = pn
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out

## Les GLB livrés ont des pierres en couleur unie (sans texture) : leurs surfaces non métalliques reçoivent la pierre du thème (même texture, relief et
## rugosité que les murs, en projection triplanaire : aucun UV nécessaire, 1 tuile = 2 u comme les murs), nuancée par la couleur d'origine.
## Les surfaces métalliques (fer, bronze) gardent leur matériau. Sans textures de thème réelles, le modèle reste tel que livré.
static var _stone_cache: Dictionary = {}

## Échelle de la pierre projetée (en tuiles par unité) : la texture couvre 4 u ; les grands modules (arches, portails) montrent de gros claveaux,
## les petits (pilastres, nervures, corniches, consoles) une pierre deux fois plus fine pour que les joints y restent visibles.
const BIG_STONE := ["arch", "ogive", "portal_room", "portal_door", "portal_stair", "door_frame", "stair_frame"]
static func _stone_scale(id: String) -> float:
	return 0.25 if BIG_STONE.has(id) else 0.5

static func _with_theme_stone(mesh: Mesh, scale: float = 0.5) -> Mesh:
	var wall := ThemeMaterials.for_theme("gothic").get("wall") as StandardMaterial3D
	if wall == null or wall.albedo_texture == null or mesh.get_surface_count() == 0:
		return mesh
	var m2 := mesh.duplicate() as Mesh
	for i in m2.get_surface_count():
		var mat := m2.surface_get_material(i) as StandardMaterial3D
		if mat != null and mat.metallic >= 0.3:
			continue
		var v := 1.0 if mat == null else clampf(mat.albedo_color.get_luminance() / 0.6, 0.7, 1.25)
		var key := int(round(v * 20.0)) * 100 + int(round(scale * 40.0))
		if not _stone_cache.has(key):
			var sm := wall.duplicate() as StandardMaterial3D
			sm.uv1_triplanar = true
			sm.uv1_world_triplanar = true       # échelle et orientation identiques d'une instance à l'autre (les modules sont tournés)
			sm.uv1_triplanar_sharpness = 8.0    # faces nettes : peu de mélange entre axes, donc pas de texture étirée sur les chanfreins
			sm.uv1_scale = Vector3.ONE * scale
			sm.albedo_color = Color(v, v, v)
			_stone_cache[key] = sm
		m2.surface_set_material(i, _stone_cache[key])
	return m2

static func _kit_material() -> StandardMaterial3D:
	if _default_mat == null:
		_default_mat = StandardMaterial3D.new()
		_default_mat.albedo_color = Color(0.17, 0.18, 0.21)
		_default_mat.roughness = 0.9
		_default_mat.metallic_specular = 0.2
	return _default_mat

static func _box(size: Vector3, pos: Vector3) -> Dictionary:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _kit_material()
	return {"mesh": bm, "xf": Transform3D(Basis.IDENTITY, pos)}

## Boîtes de test aux cotes du cahier des charges (OUTILS SEULEMENT : jamais affichées en jeu, voir `placeholders`).
static func _placeholder_parts(id: String) -> Array:
	match id:
		"pilaster":
			return [_box(Vector3(0.9, 4.0, 0.45), Vector3(0, 2.0, 0.225))]
		"plinth":
			return [_box(Vector3(4.0, 0.35, 0.22), Vector3(0, 0.175, 0.11))]
		"arch":
			return [_box(Vector3(0.5, 4.0, 0.5), Vector3(-1.75, 2.0, 0)), _box(Vector3(0.5, 4.0, 0.5), Vector3(1.75, 2.0, 0)), _box(Vector3(4.0, 0.5, 0.5), Vector3(0, 3.75, 0))]
		"pillar":
			return [_box(Vector3(0.8, 4.0, 0.8), Vector3(0, 2.0, 0))]
		"door_frame":
			return [_box(Vector3(0.5, 3.4, 0.6), Vector3(-1.75, 1.7, 0.3)), _box(Vector3(0.5, 3.4, 0.6), Vector3(1.75, 1.7, 0.3)), _box(Vector3(4.0, 0.6, 0.6), Vector3(0, 3.7, 0.3))]
		"stair_frame":
			return [_box(Vector3(0.5, 3.4, 0.7), Vector3(-1.75, 1.7, 0.35)), _box(Vector3(0.5, 3.4, 0.7), Vector3(1.75, 1.7, 0.35)), _box(Vector3(4.0, 0.6, 0.7), Vector3(0, 3.7, 0.35))]
		"bracket":
			return [_box(Vector3(0.12, 0.12, 0.3), Vector3(0, -0.1, 0.15))]
		"ornament":
			return [_box(Vector3(0.7, 1.0, 0.08), Vector3(0, 1.9, 0.04))]
	return []
