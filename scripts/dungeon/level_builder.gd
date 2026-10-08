class_name LevelBuilder
extends RefCounted
## Construit le couloir 3D d'un niveau. Même convention que le JS :
## 1 case = CELL unités, case (x, y) centrée en (x*CELL, 0, y*CELL), hauteur CELL.
## Murs / sol / plafond : un seul mesh (3 surfaces) => très peu d'appels de dessin sur mobile.

const CELL := 4.0
const NICHE_HALF_W := 1.25    # demi-largeur du décroché de la fontaine
const NICHE_H := 2.8          # hauteur du décroché
const NICHE_DEPTH := 1.9      # profondeur dans le mur
## Étal du marchand (assets/misc/merchant_stall.webp, 1421 × 983 px) logé dans un creux peu profond du mur.
## Grand format : l'étal fait toute la hauteur du mur (4 u) et ~5,75 u de large ; il déborde donc sur les cases voisines du mur
## (qui doivent être pleines derrière des cases libres). À défaut, petit format : 3,2 u de large, dans la seule case du mur.
const MERCHANT_STALL_DEPTH := 2.3      # profondeur du creux qui loge l'étal 3D (Merchant3D) à pleine échelle
const MERCHANT_WIDE_HALF_W := 3.75     # demi-largeur à pleine échelle : bannières comprises (7,5 u)
const MERCHANT_SMALL_HALF_W := 1.6
const MERCHANT_SMALL_NICHE_H := 2.9    # plus haut que l'œil du joueur (2 u) : le linteau ne masque pas le haut de l'image

## `sliced` : pendant l'écran de chargement, le travail est réparti sur plusieurs images (l'épée reste fluide) ; l'appelant doit alors `await`.
static func build(level: Dictionary, grid: DungeonGrid, sliced: bool = false) -> LevelView:
	var theme_name := str(level.get("theme", "stone"))
	var theme: Dictionary = ThemeMaterials.for_theme(theme_name)
	var view := LevelView.new()
	view.name = "Level"
	view.grid = grid
	var torches := TorchLayer.new()
	torches.name = "Torches"
	view.add_child(torches)
	view.torches = torches

	var outdoor := bool(level.get("outdoor", false))
	var path_cells: Array = level.get("pathCells", [])
	var parts := {"wall": SurfaceTool.new(), "floor": SurfaceTool.new(), "ceil": SurfaceTool.new(), "path": SurfaceTool.new()}
	var counts := {"wall": 0, "floor": 0, "ceil": 0, "path": 0}
	for k in parts:
		parts[k].begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := CELL * 0.5
	var niches := {}      # Vector2i(case) -> {d: direction du mur évidé, w: demi-largeur, h: hauteur}
	if not outdoor:
		for it in level.get("items", []):
			if str(it.get("type", "")) == "fountain":
				var nd := fountain_niche_dir(grid, int(it.x), int(it.y), str(it.id))
				if nd != Vector2i.ZERO:
					niches[Vector2i(int(it.x), int(it.y))] = {"d": nd, "w": NICHE_HALF_W, "h": NICHE_H}
		var tm = level.get("travelingMerchant")
		if tm is Dictionary:
			var mp := Vector2i(int(tm.x), int(tm.y))
			var spec := merchant_niche_spec(grid, mp.x, mp.y)
			if not spec.is_empty() and not niches.has(mp):
				niches[mp] = {"d": spec.d, "w": spec.w, "h": spec.h, "t": 0.28, "dp": merchant_niche_depth(float(spec.w))}
	# les creux plus larges qu'une case entament le mur des cases voisines : intervalle évidé (le long du mur) de chaque face concernée
	var holes := {}       # "x,y,dx,dy" -> Vector3(s0, s1, haut du creux)
	for cell in niches:
		var ni: Dictionary = niches[cell]
		var w: float = ni.w
		if w <= half:
			continue
		var dd: Vector2i = ni.d
		var rc := Vector2i(-dd.y, dd.x)
		for k in [-1, 0, 1]:
			var s0 := maxf(-w - CELL * k, -half)
			var s1 := minf(w - CELL * k, half)
			if s1 > s0:
				var nc: Vector2i = cell + rc * k
				holes["%d,%d,%d,%d" % [nc.x, nc.y, dd.x, dd.y]] = Vector3(s0, s1, float(ni.h) - half)
	for y in grid.height:
		if sliced:
			await Loader.slice()
		for x in grid.width:
			var ch := grid.cell(x, y)
			if ch == "#" or ch == "S":
				continue
			var c := Vector3(x * CELL, 0.0, y * CELL)
			if outdoor and path_cells.has("%d,%d" % [x, y]):
				_quad(parts["path"], c, Vector3(0, 0, -1), Vector3.UP, half)
				counts["path"] += 1
			else:
				_quad(parts["floor"], c, Vector3(0, 0, -1), Vector3.UP, half)
				counts["floor"] += 1
			if not outdoor:
				_quad(parts["ceil"], c + Vector3(0, CELL, 0), Vector3(0, 0, 1), Vector3.DOWN, half)
				counts["ceil"] += 1
			for d in DungeonGrid.DIRS:
				var n := grid.cell(x + d.x, y + d.y)
				var edge := c + Vector3(d.x * half, 0.0, d.y * half)   # milieu de l'arête au sol
				var rot := _rot(d)
				var nich: Dictionary = niches.get(Vector2i(x, y), {})
				if n == "#" and not nich.is_empty() and nich.d == d:
					_add_niche(parts, counts, torches, c, d, rot, theme_name, float(nich.w), float(nich.h), float(nich.get("t", 0.5)), float(nich.get("dp", NICHE_DEPTH)))
				elif n == "#":
					var hk := "%d,%d,%d,%d" % [x, y, d.x, d.y]
					if holes.has(hk):
						var hv: Vector3 = holes[hk]
						_wall_with_hole(parts, counts, c, d, hv.x, hv.y, hv.z)
					else:
						_quad(parts["wall"], edge + Vector3(0, half, 0), Vector3.UP, Vector3(-d.x, 0, -d.y), half)
						counts["wall"] += 1
					if not outdoor and (x + y) % 2 == 0:   # ~1 pan de mur sur 2 porte une torche
						torches.add_torch(c + Vector3(d.x * CELL * 0.49, CELL * 0.62, d.y * CELL * 0.49), rot, theme_name)
				elif n == "S":
					_quad(parts["wall"], edge + Vector3(0, half, 0), Vector3.UP, Vector3(-d.x, 0, -d.y), half)
					counts["wall"] += 1
					_add_arch(view, torches, edge, d, rot, theme_name, grid.stairs_at(x + d.x, y + d.y))
				elif n == "D":
					_add_door(view, edge, rot, theme_name, grid.door_at(x + d.x, y + d.y))

	var mesh := ArrayMesh.new()
	for k in ["wall", "floor", "ceil", "path"]:
		if counts[k] == 0:
			continue
		if sliced:
			await Loader.slice()
		if k != "path":
			parts[k].generate_tangents()   # nécessaires aux cartes de normales (mur, sol, plafond)
			if sliced:
				await Loader.slice()
		parts[k].commit(mesh)
		var mat: Material = theme.get(k)
		if outdoor and k == "floor":
			mat = Outdoor.grass()
		elif k == "path":
			mat = Outdoor.path()
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = "LevelMesh"
	mi.mesh = mesh
	view.add_child(mi)
	if sliced:
		await Loader.slice()
	var ents := EntityLayer.new()
	ents.name = "Entities"
	view.add_child(ents)
	await ents.populate(level, grid, sliced)
	view.entities = ents
	var stage := CombatStage.new()
	stage.name = "CombatStage"
	stage.view = view
	view.add_child(stage)
	view.stage = stage
	if sliced:
		await Loader.slice()
	if outdoor:
		Outdoor.decorate(view, level)
	else:
		_add_columns(view, grid, theme.get("wall"))
	return view

## Direction du mur à évider pour loger la fontaine de la case (x, y), ou ZERO s'il n'y a aucun mur autour.
## Le décroché (2,5 × 1,9 u) tient tout entier dans la case pleine voisine ; le côté est choisi de façon stable d'après l'id.
static func fountain_niche_dir(grid: DungeonGrid, x: int, y: int, id: String) -> Vector2i:
	var cands: Array[Vector2i] = []
	for d in DungeonGrid.DIRS:
		if grid.cell(x + d.x, y + d.y) == "#":
			cands.append(d)
	if cands.is_empty():
		return Vector2i.ZERO
	return cands[absi(id.hash()) % cands.size()]

## Creux de l'étal du marchand de la case (x, y) : {d: direction du mur évidé, w: demi-largeur, h: hauteur}, ou {} s'il n'y a aucun mur.
## Grand format (étal pleine hauteur) si le mur est assez long : deux cases libres voisines le long du mur, pleines derrière.
static func merchant_niche_spec(grid: DungeonGrid, x: int, y: int) -> Dictionary:
	var walls: Array[Vector2i] = []
	var wide: Array[Vector2i] = []
	for d in DungeonGrid.DIRS:
		if grid.cell(x + d.x, y + d.y) != "#":
			continue
		walls.append(d)
		var r := Vector2i(-d.y, d.x)
		var ok := true
		for k in [-1, 1]:
			var nx: int = x + r.x * k
			var ny: int = y + r.y * k
			if grid.cell(nx, ny) != "." or grid.cell(nx + d.x, ny + d.y) != "#":
				ok = false
		if ok:
			wide.append(d)
	var h := ("merchant_%d_%d" % [x, y]).hash()
	if not wide.is_empty():
		return {"d": wide[absi(h) % wide.size()], "w": MERCHANT_WIDE_HALF_W, "h": CELL}
	if walls.is_empty():
		return {}
	return {"d": walls[absi(h) % walls.size()], "w": MERCHANT_SMALL_HALF_W, "h": MERCHANT_SMALL_NICHE_H}

## Échelle de l'étal 3D dans un creux de demi-largeur `w` (1 = pleine échelle ; réduit si le mur est trop court).
static func merchant_stall_scale(w: float) -> float:
	return minf(1.0, w / MERCHANT_WIDE_HALF_W)

static func merchant_niche_depth(w: float) -> float:
	return MERCHANT_STALL_DEPTH * merchant_stall_scale(w)

## Direction du mur évidé pour l'étal du marchand, ou ZERO.
static func merchant_niche_dir(grid: DungeonGrid, x: int, y: int) -> Vector2i:
	var sp := merchant_niche_spec(grid, x, y)
	return Vector2i.ZERO if sp.is_empty() else sp.d

## Position (monde) et lacet de la fontaine logée dans le décroché de la case (x, y) côté `d`.
static func fountain_niche_pose(x: int, y: int, d: Vector2i) -> Dictionary:
	var c := Vector3(x * CELL, 0.0, y * CELL)
	return {"pos": c + Vector3(d.x, 0, d.y) * (CELL * 0.5 + NICHE_DEPTH * 0.5), "yaw": _rot(d)}

## Rectangle (2 triangles) dans le plan (right, up) autour de `o`, s∈[s0,s1] le long de right, t∈[t0,t1] le long de up.
## Les UV suivent la position (même échelle que les murs : 1 case = 0..1) pour que la texture se prolonge.
static func _rect(st: SurfaceTool, o: Vector3, right: Vector3, up: Vector3, n: Vector3, s0: float, s1: float, t0: float, t1: float) -> void:
	var h := CELL * 0.5
	var uv := func(s: float, t: float) -> Vector2: return Vector2((s + h) / CELL, 1.0 - (t + h) / CELL)
	var bl := o + right * s0 + up * t0
	var br := o + right * s1 + up * t0
	var tr := o + right * s1 + up * t1
	var tl := o + right * s0 + up * t1
	_v(st, bl, n, uv.call(s0, t0))
	_v(st, tl, n, uv.call(s0, t1))
	_v(st, tr, n, uv.call(s1, t1))
	_v(st, bl, n, uv.call(s0, t0))
	_v(st, tr, n, uv.call(s1, t1))
	_v(st, br, n, uv.call(s1, t0))

## Mur percé d'un décroché (niche) : montants + linteau, fond, deux flancs, sol et plafond ; deux torches de part et d'autre.
static func _add_niche(parts: Dictionary, counts: Dictionary, torches: TorchLayer, c: Vector3, d: Vector2i, rot: float, theme_name: String,
		half_w: float = NICHE_HALF_W, height: float = NICHE_H, torch_gap: float = 0.5, depth: float = NICHE_DEPTH) -> void:
	var half := CELL * 0.5
	var dv := Vector3(d.x, 0, d.y)
	var n := -dv                                   # normale du mur vu depuis la case
	var wc := c + dv * half + Vector3(0, half, 0)  # centre du pan de mur
	var right := Vector3.UP.cross(n)
	var w := half_w
	var t1 := height - half
	var wall: SurfaceTool = parts["wall"]
	var wl := minf(w, half)    # un creux plus large qu'une case : montants nuls, les cases voisines sont évidées par _wall_with_hole
	if w < half:
		_rect(wall, wc, right, Vector3.UP, n, -half, -w, -half, half)
		_rect(wall, wc, right, Vector3.UP, n, w, half, -half, half)
	if t1 < half:
		_rect(wall, wc, right, Vector3.UP, n, -wl, wl, t1, half)
	var back := wc + dv * depth
	_rect(wall, back, right, Vector3.UP, n, -w, w, -half, t1)
	# flancs : plan x = ±w, profondeur le long de dv
	_rect(wall, wc - right * w, dv, Vector3.UP, right, 0.0, depth, -half, t1)
	_rect(wall, wc + right * w, -dv, Vector3.UP, -right, -depth, 0.0, -half, t1)
	counts["wall"] += 7
	# sol et plafond du décroché
	_rect(parts["floor"], wc - Vector3(0, half, 0), right, dv, Vector3.UP, -w, w, 0.0, depth)
	counts["floor"] += 1
	_rect(parts["ceil"], wc + Vector3(0, t1, 0), -right, dv, Vector3.DOWN, -w, w, 0.0, depth)
	counts["ceil"] += 1
	for sgn in [-1.0, 1.0]:
		torches.add_torch(c + dv * CELL * 0.49 + right * sgn * (w + torch_gap) + Vector3(0, CELL * 0.62, 0), rot, theme_name)

## Pan de mur d'une case (face côté `d`) percé d'un creux entre s0 et s1 (le long du mur) jusqu'à la hauteur t1 (repère du centre du pan).
static func _wall_with_hole(parts: Dictionary, counts: Dictionary, c: Vector3, d: Vector2i, s0: float, s1: float, t1: float) -> void:
	var half := CELL * 0.5
	var dv := Vector3(d.x, 0, d.y)
	var n := -dv
	var wc := c + dv * half + Vector3(0, half, 0)
	var right := Vector3.UP.cross(n)
	var wall: SurfaceTool = parts["wall"]
	if s0 > -half:
		_rect(wall, wc, right, Vector3.UP, n, -half, s0, -half, half)
		counts["wall"] += 1
	if s1 < half:
		_rect(wall, wc, right, Vector3.UP, n, s1, half, -half, half)
		counts["wall"] += 1
	if t1 < half:
		_rect(wall, wc, right, Vector3.UP, n, s0, s1, t1, half)
		counts["wall"] += 1

## Colonnes aux angles : là où deux murs se rejoignent, et aux deux extrémités d'un mur isolé (port de buildDecor).
static func _add_columns(view: LevelView, grid: DungeonGrid, wall_mat: Material) -> void:
	var dirs := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "O": Vector2i(-1, 0)}
	var opposite := {"N": "S", "S": "N", "E": "O", "O": "E"}
	var perp := {"N": ["E", "O"], "S": ["E", "O"], "E": ["N", "S"], "O": ["N", "S"]}
	var placed := {}
	var root := Node3D.new()
	root.name = "Columns"
	view.add_child(root)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = CELL
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = wall_mat
	var place := func(wx: float, wz: float):
		var key := "%.2f,%.2f" % [wx, wz]
		if placed.has(key):
			return
		placed[key] = true
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(wx, CELL * 0.5, wz)
		root.add_child(mi)
	for y in grid.height:
		for x in grid.width:
			if grid.cell(x, y) == "#":
				continue
			var walls: Array = []
			for n in ["N", "E", "S", "O"]:
				var d: Vector2i = dirs[n]
				var nx := x + d.x
				var ny := y + d.y
				var solid := nx < 0 or ny < 0 or nx >= grid.width or ny >= grid.height or grid.cell(nx, ny) == "#"
				if solid:
					walls.append(n)
			var cx := x * CELL
			var cz := y * CELL
			if walls.size() == 2 and opposite[walls[0]] != walls[1]:
				var d1: Vector2i = dirs[walls[0]]
				var d2: Vector2i = dirs[walls[1]]
				place.call(cx + (d1.x + d2.x) * CELL * 0.5, cz + (d1.y + d2.y) * CELL * 0.5)
			elif walls.size() == 1:
				var d0: Vector2i = dirs[walls[0]]
				for pn in perp[walls[0]]:
					var p: Vector2i = dirs[pn]
					place.call(cx + (d0.x + p.x) * CELL * 0.5, cz + (d0.y + p.y) * CELL * 0.5)

## Rotation Y d'un plan qui regarde vers l'intérieur de la case (même valeur que `rot` du JS).
static func _rot(d: Vector2i) -> float:
	return atan2(-d.x, -d.y)

static func _add_door(view: LevelView, edge: Vector3, rot: float, theme: String, door_def: Dictionary) -> void:
	var leaf := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CELL, CELL)
	leaf.mesh = q
	var m := ProceduralTextures.grille_material(theme)
	leaf.material_override = m
	leaf.position = edge + Vector3(0, CELL * 0.5, 0)
	leaf.rotation.y = rot
	view.add_child(leaf)
	var id := str(door_def.get("id", ""))
	if id != "":
		if not view.doors.has(id):
			view.doors[id] = []
		view.doors[id].append(leaf)
		if bool(door_def.get("locked", true)) and not view.locks.has(id):
			view.locks[id] = _lock_sprite(view, edge + Vector3(0, CELL * 0.55, 0) + _inward(rot) * CELL * 0.04)

## Vecteur unitaire vers l'intérieur de la case pour un plan de rotation `rot` (inverse de _rot).
static func _inward(rot: float) -> Vector3:
	return Vector3(sin(rot), 0.0, cos(rot))

## Cadenas doré (sprite face caméra, 0,55 u de large) posé devant une porte verrouillée.
static func _lock_sprite(view: LevelView, pos: Vector3) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = load("res://assets/ui/lock_icon.png")
	sp.pixel_size = 0.55 / 512.0 * 1.0
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.double_sided = true
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.render_priority = 2
	sp.position = pos
	view.add_child(sp)
	return sp

## Arche d'escalier : cadre de bronze par-dessus le mur + deux torches de part et d'autre.
static func _add_arch(view: LevelView, torches: TorchLayer, edge: Vector3, d: Vector2i, rot: float,
		theme: String, _stair_def: Dictionary) -> void:
	var arch := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CELL, CELL)
	arch.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ProceduralTextures.arch()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	arch.material_override = m
	arch.position = edge + Vector3(-d.x * 0.01, CELL * 0.5, -d.y * 0.01)   # juste devant le mur
	arch.rotation.y = rot
	view.add_child(arch)
	# grille de fer si l'arche est verrouillée (même vantail que les portes, légèrement en retrait devant l'arche)
	if bool(_stair_def.get("locked", false)):
		var gate := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(CELL, CELL)
		gate.mesh = gq
		var gm := ProceduralTextures.grille_material(theme)
		gate.material_override = gm
		gate.position = edge + Vector3(0, CELL * 0.5, 0) + _inward(rot) * CELL * 0.08
		gate.rotation.y = rot
		view.add_child(gate)
		var sid := str(_stair_def.get("id", ""))
		if sid != "":
			if not view.doors.has(sid):
				view.doors[sid] = []
			view.doors[sid].append(gate)
	# torches : même distance de l'arche des deux côtés, la paire décalée légèrement à gauche
	var tang := Vector3(0.0 if d.x != 0 else 1.0, 0.0, 0.0 if d.y != 0 else 1.0)
	var offset := 0.43
	var lateral := -0.05
	var center := edge + Vector3(-d.x, 0, -d.y) * CELL * 0.01 + tang * CELL * lateral
	var atype := str(_stair_def.get("action", {}).get("type", "")) if _stair_def.get("action") is Dictionary else ""
	var torch_theme := "village_forward" if atype == "villageExit" else ("village_return" if atype == "villageReturn" else theme)
	for side in [-1.0, 1.0]:
		torches.add_torch(center + tang * CELL * side * offset + Vector3(0, CELL * 0.74, 0), rot, torch_theme)
	if atype == "villageExit" or atype == "villageReturn":
		var fwd := atype == "villageExit"
		var label := ArchLabel.make("⚔ DONJON SUIVANT" if fwd else L.t("dungeon.level_builder.donjon_precedent"), Color("ffa030") if fwd else Color("60c8ff"))
		label.position = edge + Vector3(-d.x * CELL * 0.01, CELL * 1.12, -d.y * CELL * 0.01)
		view.add_child(label)

## Ajoute un carré (2 triangles) centré en c, de demi-côté `half`,
## `up` = direction « haut » de la texture, `n` = normale (face visible).
static func _quad(st: SurfaceTool, c: Vector3, up: Vector3, n: Vector3, half: float) -> void:
	var right := up.cross(n)
	var u := up * half
	var r := right * half
	var bl := c - r - u
	var br := c + r - u
	var tr := c + r + u
	var tl := c - r + u
	_v(st, bl, n, Vector2(0, 1))
	_v(st, tl, n, Vector2(0, 0))
	_v(st, tr, n, Vector2(1, 0))
	_v(st, bl, n, Vector2(0, 1))
	_v(st, tr, n, Vector2(1, 0))
	_v(st, br, n, Vector2(1, 1))

static func _v(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)
