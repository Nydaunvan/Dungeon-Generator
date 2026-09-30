class_name LevelBuilder
extends RefCounted
## Construit le couloir 3D d'un niveau. Même convention que le JS :
## 1 case = CELL unités, case (x, y) centrée en (x*CELL, 0, y*CELL), hauteur CELL.
## Murs / sol / plafond : un seul mesh (3 surfaces) => très peu d'appels de dessin sur mobile.

const CELL := 4.0

static func build(level: Dictionary, grid: DungeonGrid) -> LevelView:
	var theme_name := str(level.get("theme", "stone"))
	var theme: Dictionary = ThemeMaterials.for_theme(theme_name)
	var view := LevelView.new()
	view.name = "Level"
	view.grid = grid
	var torches := TorchLayer.new()
	torches.name = "Torches"
	view.add_child(torches)

	var outdoor := bool(level.get("outdoor", false))
	var path_cells: Array = level.get("pathCells", [])
	var parts := {"wall": SurfaceTool.new(), "floor": SurfaceTool.new(), "ceil": SurfaceTool.new(), "path": SurfaceTool.new()}
	var counts := {"wall": 0, "floor": 0, "ceil": 0, "path": 0}
	for k in parts:
		parts[k].begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := CELL * 0.5
	for y in grid.height:
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
				if n == "#":
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
	var ents := EntityLayer.new()
	ents.name = "Entities"
	view.add_child(ents)
	ents.populate(level)
	view.entities = ents
	if outdoor:
		Outdoor.decorate(view, level)
	return view

## Rotation Y d'un plan qui regarde vers l'intérieur de la case (même valeur que `rot` du JS).
static func _rot(d: Vector2i) -> float:
	return atan2(-d.x, -d.y)

static func _add_door(view: LevelView, edge: Vector3, rot: float, theme: String, door_def: Dictionary) -> void:
	var leaf := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CELL, CELL)
	leaf.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = ProceduralTextures.door(theme)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	leaf.material_override = m
	leaf.position = edge + Vector3(0, CELL * 0.5, 0)
	leaf.rotation.y = rot
	view.add_child(leaf)
	var id := str(door_def.get("id", ""))
	if id != "":
		if not view.doors.has(id):
			view.doors[id] = []
		view.doors[id].append(leaf)

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
	# torches : même distance de l'arche des deux côtés, la paire décalée légèrement à gauche
	var tang := Vector3(0.0 if d.x != 0 else 1.0, 0.0, 0.0 if d.y != 0 else 1.0)
	var offset := 0.43
	var lateral := -0.05
	var center := edge + Vector3(-d.x, 0, -d.y) * CELL * 0.01 + tang * CELL * lateral
	for side in [-1.0, 1.0]:
		torches.add_torch(center + tang * CELL * side * offset + Vector3(0, CELL * 0.74, 0), rot, theme)

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
