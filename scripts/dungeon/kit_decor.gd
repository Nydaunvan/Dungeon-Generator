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
	"ornament": {"size": Vector3(0.7, 1.0, 0.1), "note": "élément décoratif mural discret, centré sur un pan sans torche"},
}

## Interrupteur général (outils, essais) : false = aucun module, le niveau est identique à celui sans kit.
static var enabled := true
## Outils de test seulement : pose des boîtes à la place des GLB manquants.
static var placeholders := false
## Dernier niveau posé : {"total": n, "count": {module: n}} (tests et mesures).
static var last_stats: Dictionary = {}
static var _parts_cache: Dictionary = {}
static var _default_mat: StandardMaterial3D

static func _h(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

## Le kit s'applique à ce niveau : thème prévu, intérieur, pas de refus du niveau (`kit: false`).
static func applies(theme: String, level: Dictionary) -> bool:
	return enabled and THEMES.has(theme) and not bool(level.get("outdoor", false)) and bool(level.get("kit", true))

## Vide le cache des modèles (outils : changement de `placeholders`).
static func reset_cache() -> void:
	_parts_cache.clear()

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
static func plan(level: Dictionary, grid: DungeonGrid, niches: Dictionary, holes: Dictionary, avail: Dictionary, sliced: bool = false) -> Array:
	var out: Array = []
	var seed := str(level.get("id", "")).hash()
	var blocked := RoomDecor._blocked_cells(level)
	var special := _special_cells(level, blocked, niches)
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
					if avail.has("pilaster") and _pilaster_at(grid, cell, d, niches, holes, seed, di):
						var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
						out.append({"id": "pilaster", "xf": Transform3D(basis, edge + Vector3(t.x * HALF, 0.0, t.y * HALF))})
					var torch := (x + y) % 2 == 0
					if torch and avail.has("bracket"):
						out.append({"id": "bracket", "xf": Transform3D(basis, c + Vector3(d.x * CELL * 0.49, CELL * 0.62, d.y * CELL * 0.49))})
					elif not torch and avail.has("ornament") and not special.has(cell) and not _near_special(special, grid, cell, 1) \
							and _h(x, y, seed ^ (di * 131 + 7)) % 4 == 0:
						out.append({"id": "ornament", "xf": Transform3D(basis, edge)})
				elif n == "D" and avail.has("door_frame"):
					out.append({"id": "door_frame", "xf": Transform3D(basis, edge)})
				elif n == "S" and avail.has("stair_frame"):
					out.append({"id": "stair_frame", "xf": Transform3D(basis, edge)})
			if ch == "." and avail.has("arch"):
				for e in [Vector2i(1, 0), Vector2i(0, 1)]:
					if _arch_at(grid, cell, e, special, seed):
						var ang := atan2(float(e.x), float(e.y))      # +Z du module = sens de marche
						out.append({"id": "arch", "xf": Transform3D(Basis(Vector3.UP, ang), c + Vector3(e.x * HALF, 0.0, e.y * HALF))})
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
static func _pilaster_at(grid: DungeonGrid, cell: Vector2i, d: Vector2i, niches: Dictionary, holes: Dictionary, seed: int, di: int) -> bool:
	var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
	var nb := cell + t
	var nch := grid.cell(nb.x, nb.y)
	if nch == "#" or nch == "S" or nch == "D" or grid.cell(cell.x, cell.y) == "D":
		return false
	if grid.cell(nb.x + d.x, nb.y + d.y) != "#" or _face_cut(nb, d, niches, holes):
		return false
	var along := cell.x if t.x != 0 else cell.y
	var line := cell.y if t.x != 0 else cell.x
	if (along + _h(line, di, seed) % 2) % 2 != 0:
		return false
	return _h(cell.x, cell.y, seed ^ (di * 977 + 3)) % 5 != 0

## Arche sur l'arête entre `cell` et `cell + e` : couloir droit (murs pleins de chaque côté, des deux cases), loin des portes, escaliers,
## niches, objets, monstres et du départ ; une arête sur trois le long de la ligne, avec quelques absences.
static func _arch_at(grid: DungeonGrid, cell: Vector2i, e: Vector2i, special: Dictionary, seed: int) -> bool:
	var nb := cell + e
	if grid.cell(nb.x, nb.y) != ".":
		return false
	var p := Vector2i(e.y, e.x)
	for q in [cell, nb]:
		if grid.cell(q.x + p.x, q.y + p.y) != "#" or grid.cell(q.x - p.x, q.y - p.y) != "#":
			return false
		if special.has(q) or _near_special(special, grid, q, 1):
			return false
	var along := cell.x if e.x != 0 else cell.y
	var line := cell.y if e.x != 0 else cell.x
	if (along + _h(line, e.x, seed) % 3) % 3 != 0:
		return false
	return _h(cell.x, cell.y, seed ^ 4099) % 4 != 0

## Cases à ménager : objets, marchand, escaliers, départ, niches et départs des monstres.
static func _special_cells(level: Dictionary, blocked: Dictionary, niches: Dictionary) -> Dictionary:
	var out := blocked.duplicate()
	for c in niches:
		out[c] = true
	for m in level.get("monsters", []):
		out[Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))] = true
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
				out.append({"mesh": mi.mesh, "xf": xf})
			root.free()
	elif placeholders:
		out = _placeholder_parts(id)
	_parts_cache[id] = out
	return out

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
