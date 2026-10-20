class_name VillageKit
extends RefCounted
## Décor 3D du village en vrais matériaux (textures fournies : briques, roche, terre, herbe, pavés, ardoise, tronc, feuillage).
## Les jeux de textures sont dans assets/themes/village_hd (2048 px) et village_lite (1024 px), choisis comme la pierre selon le réglage « Textures ».
## Si les textures manquent, chaque matériau renvoie null et l'appelant garde l'ancien rendu.

const CELL := 4.0
const ROOF_RISE := 2.3            # hauteur du toit au-dessus du haut du mur
const ROOF_RUN := 2.6             # profondeur du toit derrière le mur
const EAVE := 0.55                # avancée du bord de toit devant le mur
static var _cache: Dictionary = {}

static func _dir() -> String:
	var hd := "res://assets/themes/village_hd/"
	var lite := "res://assets/themes/village_lite/"
	var order := [lite, hd] if not Settings.texture_hd() else [hd, lite]
	for d in order:
		if ResourceLoader.exists(d + "brique_albedo.jpg"):
			return d
	return ""

## Matériau PBR d'une partie ("brique", "roche", "terre", "herbe", "paves", "toit", "tronc", "feuille"), `repeat` répétitions de la texture par unité UV.
static func mat(part: String, repeat: Vector2 = Vector2.ONE, cutout: bool = false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%d" % [part, str(repeat), str(cutout), 1 if Settings.texture_hd() else 0]
	if _cache.has(key):
		return _cache[key]
	var d := _dir()
	if d == "" or not (ResourceLoader.exists(d + part + "_albedo.jpg") or ResourceLoader.exists(d + part + "_albedo_alpha.png")):
		return null
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(d + part + "_albedo.jpg"):
		m.albedo_texture = load(d + part + "_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(d + part + "_normal.png")
	var orm: Texture2D = load(d + part + "_orm.jpg")   # G = rugosité
	m.roughness = 1.0
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_specular = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(repeat.x, repeat.y, 1)
	if cutout and ResourceLoader.exists(d + part + "_albedo_alpha.png"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		m.albedo_texture = load(d + part + "_albedo_alpha.png")
	_cache[key] = m
	return m

static func grass() -> Material:
	return mat("herbe", Vector2(2, 2))
static func dirt() -> Material:
	return mat("terre", Vector2(2, 2))
static func plaza() -> Material:
	var m := mat("paves", Vector2(2, 1))
	if m != null:
		m.albedo_color = Color(0.62, 0.6, 0.57)     # l'image d'origine est très claire : on l'adoucit pour qu'elle ne brûle pas au soleil
	return m      # image 1024 × 2048 : deux répétitions en largeur pour des pavés à l'échelle
static func wall() -> Material:
	return mat("roche", Vector2(1, 1))      # murs de la porte : roche moussue

# ------------------------------------------------------------------ outils de géométrie

class Batch:
	var st := SurfaceTool.new()
	var n := 0
	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

## Quadrilatère bl, br, tr, tl ; uv en unités de répétition de texture.
static func _quad(b: Batch, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3, uv0: Vector2, uv1: Vector2, flip: bool = false) -> void:
	var nrm := (br - bl).cross(tl - bl).normalized()
	if flip:
		nrm = -nrm
	var p := [bl, br, tr, tl]
	var uv := [Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y)]
	for i in [0, 2, 1, 0, 3, 2]:
		b.st.set_normal(nrm)
		b.st.set_uv(uv[i])
		b.st.add_vertex(p[i])
	b.n += 1

## Parallélépipède aligné sur les axes, centre c, demi-dimensions h.
static func _box(b: Batch, c: Vector3, h: Vector3, uvk: float = 0.5) -> void:
	var x := Vector3(h.x, 0, 0)
	var y := Vector3(0, h.y, 0)
	var z := Vector3(0, 0, h.z)
	_quad(b, c - x - z + y * -1, c + x - z - y, c + x - z + y, c - x - z + y, Vector2.ZERO, Vector2(h.x * 2 * uvk, h.y * 2 * uvk))
	_quad(b, c + x + z - y, c - x + z - y, c - x + z + y, c + x + z + y, Vector2.ZERO, Vector2(h.x * 2 * uvk, h.y * 2 * uvk))
	_quad(b, c - x + z - y, c - x - z - y, c - x - z + y, c - x + z + y, Vector2.ZERO, Vector2(h.z * 2 * uvk, h.y * 2 * uvk))
	_quad(b, c + x - z - y, c + x + z - y, c + x + z + y, c + x - z + y, Vector2.ZERO, Vector2(h.z * 2 * uvk, h.y * 2 * uvk))
	_quad(b, c - x + z + y, c + x + z + y, c + x - z + y, c - x - z + y, Vector2.ZERO, Vector2(h.x * 2 * uvk, h.z * 2 * uvk))

static func _mesh(b: Batch, material: Material) -> MeshInstance3D:
	if b.n == 0 or material == null:
		return null
	b.st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = b.st.commit()
	mi.material_override = material
	return mi

static func _glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.16, 0.22)
	m.roughness = 0.12
	m.metallic = 0.3
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.38)
	m.emission_energy_multiplier = 0.12
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["glass"] = m
	return m

# ------------------------------------------------------------------ village en longueur

const MODEL_TIMBER := "res://assets/village_models/maison_beton.fbx"
const MODEL_RUIN := "res://assets/village_models/maison_brique.fbx"
## Angle (rad) à ajouter pour que la façade du modèle regarde vers +X avant la rotation de la maison (réglé d'après les captures).
const TIMBER_YAW := PI * 0.5

static func _tri(b: Batch, a: Vector3, bb: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2) -> void:
	var nrm := (bb - a).cross(c - a).normalized()
	for pair in [[a, uva], [bb, uvb], [c, uvc]]:
		b.st.set_normal(nrm)
		b.st.set_uv(pair[1])
		b.st.add_vertex(pair[0])
	b.n += 1

## Étendue d'un modèle importé (maillages visibles), dans le repère de sa racine.
static func _bounds(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as Node3D).visible:
		var bb: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_bounds(c, t, acc)

## Charge un modèle de maison, retire sa caméra, sa lampe et les pièces à ignorer, lui donne ses matériaux par nom, le met à l'échelle
## (`target` : plus grande dimension au sol, en unités) et le pose au sol, centré sur l'origine du nœud renvoyé.
static func _model(path: String, target: float, keep: Array, assign: Dictionary) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var root: Node = (load(path) as PackedScene).instantiate()
	for c in root.get_children():
		if c is Camera3D or c is Light3D or (not keep.is_empty() and not keep.has(str(c.name))):
			c.queue_free()
	var holder := Node3D.new()
	holder.add_child(root)
	for c in root.get_children():
		if c.is_queued_for_deletion():
			root.remove_child(c)
			c.queue_free()
	_assign(root, assign)
	var acc: Array = [null]
	_bounds(root, Transform3D.IDENTITY, acc)
	if acc[0] == null:
		holder.queue_free()
		return null
	var bb: AABB = acc[0]
	var k := target / maxf(bb.size.x, bb.size.z)
	root.scale = Vector3.ONE * k
	root.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * k, -bb.position.y * k, -(bb.position.z + bb.size.z * 0.5) * k)
	holder.set_meta("size", bb.size * k)
	return holder

static func _assign(n: Node, assign: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var nm := str(m.resource_name) if m != null else ""
			for key in assign:
				if nm.begins_with(key):
					var mm = assign[key]
					if mm != null:
						mi.set_surface_override_material(i, mm)
	for c in n.get_children():
		_assign(c, assign)

static func _house_timber(target: float) -> Node3D:
	return _model(MODEL_TIMBER, target, [], {"concrete": mat("beton"), "redwood": mat("bois_m"), "roof": mat("toit_m")})

static func _house_ruin(target: float) -> Node3D:
	return _model(MODEL_RUIN, target, ["Cube", "Cube_028"], {"Material.001": mat("brique", Vector2(1, 1)), "Material": mat("tronc"), "Material.004": null})

## Maison de briques à toit d'ardoise construite en code : façade côté +Z, faîtage le long de X.
static func _house_brick(wd: float, dp: float, seed: int) -> Node3D:
	var hw := wd * 0.5
	var hd := dp * 0.5
	var wh := 3.3
	var rise := 2.6
	var ov := 0.55
	var brick := Batch.new()
	var roof := Batch.new()
	var wood := Batch.new()
	var glass := Batch.new()
	var stone := Batch.new()
	var cap := Batch.new()
	var bu := 1.0 / 4.0
	# murs
	_quad(brick, Vector3(-hw, 0, hd), Vector3(hw, 0, hd), Vector3(hw, wh, hd), Vector3(-hw, wh, hd), Vector2.ZERO, Vector2(wd * bu, wh * bu))
	_quad(brick, Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd), Vector3(-hw, wh, -hd), Vector3(hw, wh, -hd), Vector2.ZERO, Vector2(wd * bu, wh * bu))
	_quad(brick, Vector3(hw, 0, hd), Vector3(hw, 0, -hd), Vector3(hw, wh, -hd), Vector3(hw, wh, hd), Vector2.ZERO, Vector2(dp * bu, wh * bu))
	_quad(brick, Vector3(-hw, 0, -hd), Vector3(-hw, 0, hd), Vector3(-hw, wh, hd), Vector3(-hw, wh, -hd), Vector2.ZERO, Vector2(dp * bu, wh * bu))
	# pignons
	for sgn in [-1.0, 1.0]:
		var x: float = sgn * hw
		var a := Vector3(x, wh, hd * sgn)
		_tri(brick, Vector3(x, wh, -hd), Vector3(x, wh, hd), Vector3(x, wh + rise, 0), Vector2(0, 0), Vector2(dp * bu, 0), Vector2(dp * bu * 0.5, rise * bu))
	# toit
	var slope := Vector2(hd + ov, rise).length()
	for sgn in [1.0, -1.0]:
		var z0: float = sgn * (hd + ov)
		var b0 := Vector3(-hw - ov, wh - 0.2, z0)
		var b1 := Vector3(hw + ov, wh - 0.2, z0)
		var t1 := Vector3(hw + ov, wh + rise, 0)
		var t0 := Vector3(-hw - ov, wh + rise, 0)
		if sgn > 0:
			_quad(roof, b0, b1, t1, t0, Vector2.ZERO, Vector2((wd + 2 * ov) / 2.5, slope / 2.5))
		else:
			_quad(roof, b1, b0, t0, t1, Vector2.ZERO, Vector2((wd + 2 * ov) / 2.5, slope / 2.5))
	# faîtière
	_box(cap, Vector3(0, wh + rise + 0.05, 0), Vector3(hw + ov, 0.09, 0.12), 0.5)
	# porte au centre de la façade, marche de pierre et linteau
	_quad(wood, Vector3(-0.8, 0, hd + 0.04), Vector3(0.8, 0, hd + 0.04), Vector3(0.8, 2.3, hd + 0.04), Vector3(-0.8, 2.3, hd + 0.04), Vector2.ZERO, Vector2(0.8, 1.1))
	_box(stone, Vector3(0, 0.1, hd + 0.35), Vector3(1.2, 0.1, 0.35), 0.5)
	_box(stone, Vector3(0, 2.45, hd + 0.08), Vector3(1.15, 0.14, 0.1), 0.5)
	# fenêtres sur la façade et le dos, volets de bois
	for zs in [1.0, -1.0]:
		for xs in [-3.0, 3.0, 0.0]:
			if zs > 0 and xs == 0.0:
				continue
			var wz: float = zs * (hd + 0.05)
			var nz: float = zs
			var wc := Vector3(xs, 1.9, wz)
			var w := 0.55
			var hh := 0.7
			_box(wood, wc + Vector3(0, 0, nz * 0.02), Vector3(w + 0.12, hh + 0.12, 0.03), 0.6)
			_quad(glass, wc + Vector3(-w, -hh, nz * 0.06), wc + Vector3(w, -hh, nz * 0.06), wc + Vector3(w, hh, nz * 0.06), wc + Vector3(-w, hh, nz * 0.06), Vector2.ZERO, Vector2.ONE) if zs > 0 else _quad(glass, wc + Vector3(w, -hh, nz * 0.06), wc + Vector3(-w, -hh, nz * 0.06), wc + Vector3(-w, hh, nz * 0.06), wc + Vector3(w, hh, nz * 0.06), Vector2.ZERO, Vector2.ONE)
			_box(stone, wc + Vector3(0, -hh - 0.14, nz * 0.14), Vector3(w + 0.2, 0.06, 0.14), 0.5)
			for sg in [-1.0, 1.0]:
				_box(wood, wc + Vector3(sg * (w + 0.4), 0, nz * 0.08), Vector3(0.28, hh + 0.1, 0.03), 0.6)
	# cheminée
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cx := -hw * 0.5 + rng.randf() * hw
	_box(brick, Vector3(cx, wh + rise * 0.6, -hd * 0.35), Vector3(0.4, 1.4, 0.4), 0.5)
	_box(cap, Vector3(cx, wh + rise * 0.6 + 1.45, -hd * 0.35), Vector3(0.5, 0.07, 0.5), 0.5)
	# socle de pierre
	_box(stone, Vector3(0, 0.25, hd + 0.02), Vector3(hw + 0.05, 0.25, 0.05), 0.5)
	var holder := Node3D.new()
	for pair in [[brick, mat("brique", Vector2(1, 2))], [roof, mat("toit", Vector2(1, 1))], [wood, mat("tronc", Vector2(1, 1))],
			[glass, _glass()], [stone, mat("roche", Vector2(1, 1))], [cap, mat("roche", Vector2(1, 1))]]:
		var mi := _mesh(pair[0], pair[1])
		if mi != null:
			holder.add_child(mi)
	holder.set_meta("size", Vector3(wd + 2 * ov, wh + rise, dp + 2 * ov))
	return holder

## Pose toutes les maisons du niveau (liste `houses`), orientées vers la rue.
static func houses(view: Node3D, level: Dictionary) -> void:
	var idx := 0
	for h in level.get("houses", []):
		var cx := (float(h.x) + (float(h.w) - 1.0) * 0.5) * CELL
		var cz := (float(h.y) + (float(h.h) - 1.0) * 0.5) * CELL
		var foot := float(h.w) * CELL * 0.94
		var node: Node3D = null
		var yaw := 0.0
		var face: String = str(h.face)
		var front_yaw := PI * 0.5 if face == "E" else -PI * 0.5   # +Z local → vers +X (est) ou -X (ouest)
		match str(h.kind):
			"brick":
				node = _house_brick(foot, foot * 0.78, idx * 31 + 7)
				yaw = front_yaw
			"ruin":
				node = _house_ruin(foot * 0.8)
				yaw = front_yaw + (PI if idx % 2 == 0 else 0.0)
			_:
				node = _house_timber(foot)
				yaw = front_yaw + TIMBER_YAW
		if node == null:
			node = _house_brick(foot, foot * 0.78, idx)
			yaw = front_yaw
		node.name = "House_%d" % idx
		node.position = Vector3(cx, 0, cz)
		node.rotation.y = yaw
		view.add_child(node)
		idx += 1

# ------------------------------------------------------------------ barrières, sol et lisière

## Barrières de bois le long de l'enceinte, hors de la façade des portes.
static func fences(view: Node3D, grid: DungeonGrid) -> void:
	var post := Batch.new()
	var half := CELL * 0.5
	for y in grid.height:
		for x in grid.width:
			if grid.cell(x, y) == "#" or grid.cell(x, y) == "S":
				continue
			for d in DungeonGrid.DIRS:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if grid.cell(nx, ny) != "#":
					continue
				if not (nx == 0 or ny == 0 or nx == grid.width - 1 or ny == grid.height - 1):
					continue                                                   # seule l'enceinte est close ; les maisons se suffisent
				if (y == 1 or y == grid.height - 2) and absi(x - grid.width / 2) <= 2:
					continue                                                   # mur de la porte
				var c := Vector3(x * CELL, 0.0, y * CELL)
				var dv := Vector3(d.x, 0, d.y)
				var edge := c + dv * (half - 0.05)
				var along := Vector3(absi(d.y), 0, absi(d.x))
				for s in [-1.5, -0.5, 0.5, 1.5]:
					var pc: Vector3 = edge + along * s
					_box(post, pc + Vector3(0, 0.62, 0), Vector3(0.09, 0.62, 0.09), 0.7)
				for hgt in [0.42, 0.95]:
					_box(post, edge + Vector3(0, hgt, 0), along * half + Vector3(0.03, 0.04, 0.03) + (Vector3(0.0, 0.0, 0.0)), 0.7)
	var mi := _mesh(post, mat("tronc", Vector2(1, 1)))
	if mi != null:
		mi.name = "Fences"
		view.add_child(mi)

## Grand sol d'herbe qui déborde du village (jusqu'à l'horizon dans le brouillard).
static func ground(view: Node3D, grid: DungeonGrid) -> void:
	var base := mat("herbe", Vector2(2, 2))
	if base == null:
		return
	var m := base.duplicate() as StandardMaterial3D
	var size := Vector2(grid.width * CELL + 360.0, grid.height * CELL + 360.0)
	m.uv1_scale = Vector3(size.x / 2.0, size.y / 2.0, 1)
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3((grid.width - 1) * CELL * 0.5, -0.03, (grid.height - 1) * CELL * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "FarGround"
	view.add_child(mi)

## Arbre léger de la lisière (peu de triangles : on en pose des centaines).
static func forest_tree() -> ArrayMesh:
	if _cache.has("forest_tree"):
		return _cache["forest_tree"]
	var trunk_mat := mat("tronc", Vector2(1, 2))
	var leaf_mat := mat("feuille", Vector2(5, 5), true)
	if trunk_mat == null or leaf_mat == null:
		return null
	var mesh := ArrayMesh.new()
	var tr := CylinderMesh.new()
	tr.top_radius = 0.07
	tr.bottom_radius = 0.15
	tr.height = 1.9
	tr.radial_segments = 6
	tr.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(tr, 0, Transform3D(Basis(), Vector3(0, 0.95, 0)))
	st.generate_tangents()
	st.commit(mesh)
	mesh.surface_set_material(0, trunk_mat)
	var fs := SurfaceTool.new()
	fs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blob in [[Vector3(0, 2.4, 0), 1.05], [Vector3(0.6, 2.0, 0.2), 0.75], [Vector3(-0.55, 2.1, -0.3), 0.78], [Vector3(0.05, 3.0, -0.1), 0.66]]:
		var sp := SphereMesh.new()
		sp.radius = blob[1]
		sp.height = blob[1] * 1.7
		sp.radial_segments = 8
		sp.rings = 5
		fs.append_from(sp, 0, Transform3D(Basis(), blob[0]))
	fs.generate_tangents()
	fs.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	_cache["forest_tree"] = mesh
	return mesh

## Lisière : arbres serrés autour de l'enceinte (et dans la bande de cases pleines), en blocs par tronçon de rue pour ne dessiner que les proches.
static func forest(view: Node3D, grid: DungeonGrid) -> void:
	var mesh := forest_tree()
	if mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var band := 4                                  # épaisseur de la lisière (cases) au-delà de la grille
	var chunks := {}
	for y in range(-band, grid.height + band):
		for x in range(-band, grid.width + band):
			var inside_play := x >= 1 and x <= grid.width - 2 and y >= 1 and y <= grid.height - 2
			if inside_play:
				continue
			var near_edge := x < 2 or x > grid.width - 3 or y < 2 or y > grid.height - 3
			var count := 2 if near_edge else 1
			for i in count:
				if rng.randf() < 0.22 and not near_edge:
					continue
				var p := Vector3((x + rng.randf() - 0.5) * CELL, 0.0, (y + rng.randf() - 0.5) * CELL)
				var sc := 1.5 + rng.randf() * 1.1
				var key := Vector2i(clampi(x / 8, -1, grid.width / 8 + 1), clampi(y / 8, -1, grid.height / 8 + 1))
				if not chunks.has(key):
					chunks[key] = []
				chunks[key].append(Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p))
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Forest_%d_%d" % [key.x, key.y]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 120.0
		view.add_child(mmi)

static func decorate(view: Node3D, level: Dictionary, grid: DungeonGrid) -> void:
	if mat("brique") == null or grid == null:
		return
	ground(view, grid)
	houses(view, level)
	fences(view, grid)
	forest(view, grid)

# ------------------------------------------------------------------ arbres

static func tree_mesh() -> ArrayMesh:
	if _cache.has("tree"):
		return _cache["tree"]
	var trunk_mat := mat("tronc", Vector2(1, 2))
	var leaf_mat := mat("feuille", Vector2(2, 2))
	if trunk_mat == null or leaf_mat == null:
		return null
	var mesh := ArrayMesh.new()
	var tr := CylinderMesh.new()
	tr.top_radius = 0.07
	tr.bottom_radius = 0.14
	tr.height = 1.7
	tr.radial_segments = 10
	tr.rings = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(tr, 0, Transform3D(Basis(), Vector3(0, 0.85, 0)))
	st.generate_tangents()
	st.commit(mesh)
	mesh.surface_set_material(0, trunk_mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var fs := SurfaceTool.new()
	fs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blob in [[Vector3(0, 2.2, 0), 0.95], [Vector3(0.55, 1.9, 0.2), 0.7], [Vector3(-0.5, 2.0, -0.3), 0.72], [Vector3(0.1, 2.75, -0.1), 0.62], [Vector3(-0.2, 1.75, 0.5), 0.55]]:
		var sp := SphereMesh.new()
		sp.radius = blob[1]
		sp.height = blob[1] * 1.7
		sp.radial_segments = 14
		sp.rings = 8
		fs.append_from(sp, 0, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU), blob[0]))
	fs.generate_tangents()
	fs.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	_cache["tree"] = mesh
	return mesh
