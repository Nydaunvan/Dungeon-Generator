class_name LevelBuilder
extends RefCounted
## Construit le couloir 3D d'un niveau : un seul mesh par matériau (léger pour le mobile).
## Même convention que le JS : 1 case = CELL unités, case (x, y) centrée en (x*CELL, 0, y*CELL).

const CELL := 4.0

static func build(level: Dictionary, grid: DungeonGrid) -> MeshInstance3D:
	var theme: Dictionary = ThemeMaterials.for_theme(str(level.get("theme", "stone")))
	var door_mat := ThemeMaterials.placeholder(Color(0.36, 0.22, 0.1))   # provisoire : porte
	var stair_mat := ThemeMaterials.placeholder(Color(0.55, 0.5, 0.4))   # provisoire : escalier
	var parts := {
		"wall": SurfaceTool.new(), "floor": SurfaceTool.new(), "ceil": SurfaceTool.new(),
		"door": SurfaceTool.new(), "stair": SurfaceTool.new(),
	}
	var mats := {"wall": theme["wall"], "floor": theme["floor"], "ceil": theme["ceil"],
		"door": door_mat, "stair": stair_mat}
	var counts := {"wall": 0, "floor": 0, "ceil": 0, "door": 0, "stair": 0}
	for k in parts:
		parts[k].begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := CELL * 0.5
	for y in grid.height:
		for x in grid.width:
			var ch := grid.cell(x, y)
			if ch == "#" or ch == "S":
				continue
			var c := Vector3(x * CELL, 0.0, y * CELL)
			_quad(parts["floor"], c, Vector3(0, 0, -1), Vector3.UP, half)
			_quad(parts["ceil"], c + Vector3(0, CELL, 0), Vector3(0, 0, 1), Vector3.DOWN, half)
			counts["floor"] += 1
			counts["ceil"] += 1
			for d in DungeonGrid.DIRS:
				var n := grid.cell(x + d.x, y + d.y)
				var kind := ""
				if n == "#":
					kind = "wall"
				elif n == "D":
					kind = "door"
				elif n == "S":
					kind = "stair"
				else:
					continue
				var center := c + Vector3(d.x * half, half, d.y * half)
				_quad(parts[kind], center, Vector3.UP, Vector3(-d.x, 0, -d.y), half)
				counts[kind] += 1

	var mesh := ArrayMesh.new()
	for k in ["wall", "floor", "ceil", "door", "stair"]:
		if counts[k] == 0:
			continue
		parts[k].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
	var mi := MeshInstance3D.new()
	mi.name = "LevelMesh"
	mi.mesh = mesh
	return mi

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
