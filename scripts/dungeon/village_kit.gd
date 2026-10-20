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
	if d == "" or not ResourceLoader.exists(d + part + "_albedo.jpg"):
		return null
	var m := StandardMaterial3D.new()
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
	if cutout and ResourceLoader.exists(d + part + "_opacity.jpg"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
		m.albedo_texture = _with_alpha(load(d + part + "_albedo.jpg"), load(d + part + "_opacity.jpg"))
	_cache[key] = m
	return m

## Couleur + opacité réunies dans une seule image RGBA (le moteur ne lit pas une carte d'opacité à part).
static func _with_alpha(color: Texture2D, opacity: Texture2D) -> Texture2D:
	var a := color.get_image()
	var o := opacity.get_image()
	if a.is_compressed():
		a.decompress()
	if o.is_compressed():
		o.decompress()
	a.convert(Image.FORMAT_RGBA8)
	o.convert(Image.FORMAT_L8)
	if o.get_size() != a.get_size():
		o.resize(a.get_width(), a.get_height())
	for y in a.get_height():
		for x in a.get_width():
			var c := a.get_pixel(x, y)
			c.a = o.get_pixel(x, y).r
			a.set_pixel(x, y, c)
	a.generate_mipmaps()
	return ImageTexture.create_from_image(a)

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
	return mat("brique", Vector2(1, 2))     # image 2048 × 1024 : un pan de mur (4 u) montre une largeur et deux hauteurs d'image

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

# ------------------------------------------------------------------ bâtiments autour de la place

## Les murs d'enceinte du village deviennent des façades de maisons en briques : soubassement de roche, fenêtres à volets, portes de bois,
## toit d'ardoise qui part du haut du mur, cheminées. La grille ne change pas : tout est décor.
static func buildings(view: Node3D, grid: DungeonGrid) -> void:
	if mat("brique") == null:
		return
	var plinth := Batch.new()
	var roof := Batch.new()
	var wood := Batch.new()
	var glass := Batch.new()
	var brick := Batch.new()
	var cap := Batch.new()
	var half := CELL * 0.5
	for y in grid.height:
		for x in grid.width:
			var ch := grid.cell(x, y)
			if ch == "#" or ch == "S":
				continue
			for d in DungeonGrid.DIRS:
				if grid.cell(x + d.x, y + d.y) != "#":
					continue
				var c := Vector3(x * CELL, 0.0, y * CELL)
				var dv := Vector3(d.x, 0, d.y)
				var inward := -dv
				var right := Vector3.UP.cross(inward)
				var edge := c + dv * half
				var seed: int = (x * 7 + y * 13 + d.x * 3 + d.y * 5) & 255
				# soubassement : bande de roche en pied de mur
				var e := edge + inward * 0.03
				_quad(plinth, e - right * half, e + right * half, e + right * half + Vector3(0, 0.9, 0), e - right * half + Vector3(0, 0.9, 0), Vector2.ZERO, Vector2(1.0, 0.45))
				_quad(plinth, e - right * half + Vector3(0, 0.9, 0), e + right * half + Vector3(0, 0.9, 0), e + right * half + Vector3(0, 0.9, 0) + inward * 0.06, e - right * half + Vector3(0, 0.9, 0) + inward * 0.06, Vector2.ZERO, Vector2(1.0, 0.1))
				# toit : de l'avant-toit (devant le mur) à la crête (derrière)
				var eave_in := edge + inward * EAVE + Vector3(0, CELL - 0.15, 0)
				var ridge := edge + dv * ROOF_RUN + Vector3(0, CELL + ROOF_RISE, 0)
				var slope_len := (ridge - eave_in).length()
				var rs := half + 0.02
				_quad(roof, eave_in - right * rs, eave_in + right * rs, ridge + right * rs, ridge - right * rs, Vector2.ZERO, Vector2(CELL / 2.0, slope_len / 2.0))
				# épaisseur de rive : tranche de bois sous l'avant-toit
				_quad(wood, eave_in - right * rs + Vector3(0, -0.22, 0), eave_in + right * rs + Vector3(0, -0.22, 0), eave_in + right * rs, eave_in - right * rs, Vector2.ZERO, Vector2(1.0, 0.15))
				# fenêtre (volets de bois, vitre éclairée) ou porte
				var kind: int = seed % 4
				if kind != 3:
					var wc := e + Vector3(0, 2.35, 0)
					var o := inward * 0.04
					var w := 0.55
					var hh := 0.75
					_quad(wood, wc - right * (w + 0.12) + Vector3(0, -hh - 0.12, 0) + o, wc + right * (w + 0.12) + Vector3(0, -hh - 0.12, 0) + o, wc + right * (w + 0.12) + Vector3(0, hh + 0.12, 0) + o, wc - right * (w + 0.12) + Vector3(0, hh + 0.12, 0) + o, Vector2.ZERO, Vector2(0.6, 0.8))
					var o2 := inward * 0.07
					_quad(glass, wc - right * w + Vector3(0, -hh, 0) + o2, wc + right * w + Vector3(0, -hh, 0) + o2, wc + right * w + Vector3(0, hh, 0) + o2, wc - right * w + Vector3(0, hh, 0) + o2, Vector2.ZERO, Vector2.ONE)
					_quad(wood, wc - Vector3(0, 0.03, 0) - right * w + o2 * 1.2, wc + Vector3(0, 0.03, 0) + right * w + o2 * 1.2, wc + Vector3(0, 0.03, 0) + right * w + o2 * 1.2, wc - Vector3(0, 0.03, 0) - right * w + o2 * 1.2, Vector2.ZERO, Vector2(0.1, 0.1))
					# volets entrouverts
					for sgn in [-1.0, 1.0]:
						var base: Vector3 = wc + right * (sgn * (w + 0.12)) + o * 1.5
						var out: Vector3 = right * (sgn * 0.5) + inward * 0.18
						_quad(wood, base + Vector3(0, -hh, 0), base + out + Vector3(0, -hh, 0), base + out + Vector3(0, hh, 0), base + Vector3(0, hh, 0), Vector2.ZERO, Vector2(0.4, 1.2))
					if kind == 1:
						# deuxième fenêtre plus bas : devanture éclairée
						pass
				else:
					var dc := e + Vector3(0, 1.1, 0)
					var o3 := inward * 0.05
					_quad(wood, dc - right * 0.8 + Vector3(0, -1.1, 0) + o3, dc + right * 0.8 + Vector3(0, -1.1, 0) + o3, dc + right * 0.8 + Vector3(0, 1.25, 0) + o3, dc - right * 0.8 + Vector3(0, 1.25, 0) + o3, Vector2.ZERO, Vector2(1.0, 1.2))
					# encadrement de roche
					_quad(plinth, dc - right * 0.95 + Vector3(0, 1.25, 0) + o3 * 0.6, dc + right * 0.95 + Vector3(0, 1.25, 0) + o3 * 0.6, dc + right * 0.95 + Vector3(0, 1.5, 0) + o3 * 0.6, dc - right * 0.95 + Vector3(0, 1.5, 0) + o3 * 0.6, Vector2.ZERO, Vector2(0.5, 0.12))
				# cheminée sur certaines façades
				if seed % 7 == 0:
					var cc := edge + dv * (ROOF_RUN * 0.55) + Vector3(0, CELL + ROOF_RISE * 0.55 + 0.9, 0)
					_box(brick, cc, Vector3(0.38, 0.9, 0.38), 0.6)
					_box(cap, cc + Vector3(0, 0.95, 0), Vector3(0.48, 0.07, 0.48), 0.5)
	for pair in [[plinth, mat("roche", Vector2(1, 1))], [roof, mat("toit", Vector2(1, 1))], [wood, mat("tronc", Vector2(1, 1))],
			[glass, _glass()], [brick, mat("brique", Vector2(1, 1))], [cap, mat("roche", Vector2(1, 1))]]:
		var mi := _mesh(pair[0], pair[1])
		if mi != null:
			mi.name = "VillageDecor"
			view.add_child(mi)

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
