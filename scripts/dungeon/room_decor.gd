class_name RoomDecor
extends RefCounted
## Décors des salles (donjons générés ET dessinés à la main : les salles sont repérées par RoomMap d'après la carte).
## Purement visuels : rien n'occupe jamais une case (piliers sur les sommets entre quatre cases, tapis à plat, lustre au plafond,
## bannières contre les murs), donc aucun effet sur le jeu, les déplacements ni le rejeu. Les choix sont déterministes (hachage de la
## position et du niveau), sans toucher au hasard du jeu.

const CELL := LevelBuilder.CELL

## Couleurs par thème : [fond, galon, sombre].
const PALETTES := {
	"stone": [0x7a1f1f, 0xc9a24a, 0x3f0e0e],
	"dirt": [0x6b4a2a, 0xb08a4a, 0x35230f],
	"damp": [0x2f5a4a, 0x9ab07a, 0x172e25],
	"ruins": [0x5a4a46, 0x9a8a6a, 0x2a2220],
	"ice": [0x3a6a9a, 0xdff2ff, 0x1d3a58],
	"lava": [0x6a1a0a, 0xff8a2a, 0x2e0803],
	"temple": [0x4a2a6a, 0xd8b84a, 0x24133a],
}

static var _tex: Dictionary = {}

static func _h(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

static func _col(v: int) -> Color:
	return Color((v >> 16) / 255.0, ((v >> 8) & 255) / 255.0, (v & 255) / 255.0)

static func _pal(theme: String) -> Array:
	return PALETTES.get(theme, PALETTES["stone"])

## Ajoute les décors des salles du niveau à `view`. `wall_mat` : matériau des murs (piliers de même pierre).
static func add(view: LevelView, level: Dictionary, theme: String, wall_mat: Material) -> void:
	var rows: Array = level.get("mapRows", [])
	var rooms := RoomMap.detect(rows)
	if rooms.is_empty():
		return
	var seed := str(level.get("id", "")).hash()
	var root := Node3D.new()
	root.name = "RoomDecor"
	view.add_child(root)
	var shafts: Array = []
	var bases: Array = []
	var caps: Array = []
	var banners := {0: [], 1: []}
	for r in rooms:
		var rect: Rect2i = r.rect
		var inside := {}
		for c in r.cells:
			inside[c] = true
		var hs := _h(rect.position.x, rect.position.y, seed)
		_pillars(rect, inside, theme, hs, shafts, bases, caps)
		_rug(root, rect, inside, theme)
		_chandelier(root, rect, inside, theme)
		_banners(rows, r.cells, inside, hs, banners)
	if not shafts.is_empty():
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.3
		shaft.bottom_radius = 0.34
		shaft.height = 1.0
		shaft.radial_segments = 12
		shaft.rings = 1
		shaft.material = wall_mat
		_multi(root, shaft, shafts)
		var base := BoxMesh.new()
		base.size = Vector3(0.9, 0.3, 0.9)
		base.material = wall_mat
		_multi(root, base, bases)
		var cap := BoxMesh.new()
		cap.size = Vector3(0.95, 0.28, 0.95)
		cap.material = wall_mat
		_multi(root, cap, caps)
	for k in banners:
		if (banners[k] as Array).is_empty():
			continue
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 2.3)
		q.material = _banner_material(theme, k)
		_multi(root, q, banners[k])

static func _multi(root: Node3D, mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	root.add_child(mi)

# ------------------------------------------------------------------ piliers

## Quatre piliers par salle (d'au moins 3 x 3 cases), posés sur les sommets entre quatre cases proches des angles : jamais dans une case.
## Ruines : piliers brisés à hauteur variable.
static func _pillars(rect: Rect2i, inside: Dictionary, theme: String, hs: int, shafts: Array, bases: Array, caps: Array) -> void:
	if rect.size.x < 3 or rect.size.y < 3:
		return
	for vi in [1, rect.size.x - 1]:
		for vj in [1, rect.size.y - 1]:
			var cx: int = rect.position.x + vi
			var cy: int = rect.position.y + vj
			# le sommet est entouré de quatre cases de la salle
			if not (inside.has(Vector2i(cx - 1, cy - 1)) and inside.has(Vector2i(cx, cy - 1)) and inside.has(Vector2i(cx - 1, cy)) and inside.has(Vector2i(cx, cy))):
				continue
			var wx := (cx - 0.5) * CELL
			var wz := (cy - 0.5) * CELL
			var broken := theme == "ruins" and _h(cx, cy, hs) % 3 == 0
			var h := CELL if not broken else CELL * (0.45 + 0.4 * float(_h(cy, cx, hs) % 100) / 100.0)
			var sh := Transform3D(Basis.from_scale(Vector3(1, h, 1)), Vector3(wx, h * 0.5, wz))
			shafts.append(sh)
			bases.append(Transform3D(Basis.IDENTITY, Vector3(wx, 0.15, wz)))
			if not broken:
				caps.append(Transform3D(Basis.IDENTITY, Vector3(wx, CELL - 0.14, wz)))

# ------------------------------------------------------------------ tapis

static func _rug_texture(theme: String, w: int, h: int) -> Texture2D:
	var key := "rug|%s|%d|%d" % [theme, w, h]
	if _tex.has(key):
		return _tex[key]
	var p := _pal(theme)
	var field := _col(p[0])
	var trim := _col(p[1])
	var dark := _col(p[2])
	var T := 32
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	for y in h * T:
		for x in w * T:
			var edge := mini(mini(x, w * T - 1 - x), mini(y, h * T - 1 - y))
			var c := field
			if edge < 3:
				c = trim
			elif edge < 6:
				c = dark
			elif edge < 8:
				c = trim
			else:
				# motif en losanges répété
				var u := absi((x % T) - T / 2)
				var v := absi((y % T) - T / 2)
				if u + v < 7:
					c = trim.darkened(0.15)
				elif u + v < 9:
					c = dark
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

## Tapis au centre de la salle, à l'intérieur des piliers (bordure d'une case).
static func _rug(root: Node3D, rect: Rect2i, inside: Dictionary, theme: String) -> void:
	var rw := rect.size.x - 2
	var rh := rect.size.y - 2
	if rw < 1 or rh < 1 or rect.size.x < 3 or rect.size.y < 3:
		return
	for yy in range(rect.position.y + 1, rect.position.y + 1 + rh):
		for xx in range(rect.position.x + 1, rect.position.x + 1 + rw):
			if not inside.has(Vector2i(xx, yy)):
				return
	var pm := PlaneMesh.new()
	pm.size = Vector2(rw * CELL * 0.94, rh * CELL * 0.94)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _rug_texture(theme, rw, rh)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 1.0
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3((rect.position.x + 1 + rw * 0.5 - 0.5) * CELL, 0.02, (rect.position.y + 1 + rh * 0.5 - 0.5) * CELL)
	root.add_child(mi)

# ------------------------------------------------------------------ lustre

static func _chandelier(root: Node3D, rect: Rect2i, inside: Dictionary, theme: String) -> void:
	if rect.size.x < 3 or rect.size.y < 3:
		return
	var p := _pal(theme)
	var cxw := (rect.position.x + rect.size.x * 0.5 - 0.5) * CELL
	var czw := (rect.position.y + rect.size.y * 0.5 - 0.5) * CELL
	var n := Node3D.new()
	n.position = Vector3(cxw, 0, czw)
	root.add_child(n)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.1, 0.09)
	iron.metallic = 0.6
	iron.roughness = 0.5
	var chain := CylinderMesh.new()
	chain.top_radius = 0.03
	chain.bottom_radius = 0.03
	chain.height = 0.9
	chain.radial_segments = 6
	chain.material = iron
	var cm := MeshInstance3D.new()
	cm.mesh = chain
	cm.position = Vector3(0, CELL - 0.45, 0)
	n.add_child(cm)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.5
	ring.rings = 16
	ring.ring_segments = 6
	ring.material = iron
	var rm := MeshInstance3D.new()
	rm.mesh = ring
	rm.position = Vector3(0, CELL - 0.95, 0)
	n.add_child(rm)
	var flame_col := _col(p[1]).lerp(Color(1.0, 0.7, 0.3), 0.6)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = ProceduralTextures.flame()
	fm.albedo_color = flame_col
	fm.no_depth_test = false
	var gm := fm.duplicate() as StandardMaterial3D
	gm.albedo_texture = ProceduralTextures.glow()
	gm.albedo_color = Color(flame_col.r, flame_col.g, flame_col.b, 0.35)
	var fq := QuadMesh.new()
	fq.size = Vector2(0.34, 0.5)
	fq.material = fm
	var gq := QuadMesh.new()
	gq.size = Vector2(1.5, 1.5)
	gq.material = gm
	for i in 6:
		var a := TAU * float(i) / 6.0
		var pos := Vector3(cos(a) * 0.46, CELL - 0.95, sin(a) * 0.46)
		var cand := CylinderMesh.new()
		cand.top_radius = 0.04
		cand.bottom_radius = 0.04
		cand.height = 0.22
		cand.radial_segments = 6
		cand.material = iron
		var cmi := MeshInstance3D.new()
		cmi.mesh = cand
		cmi.position = pos + Vector3(0, 0.12, 0)
		n.add_child(cmi)
		var f := MeshInstance3D.new()
		f.mesh = fq
		f.position = pos + Vector3(0, 0.45, 0)
		n.add_child(f)
	var g := MeshInstance3D.new()
	g.mesh = gq
	g.position = Vector3(0, CELL - 0.9, 0)
	n.add_child(g)

# ------------------------------------------------------------------ bannières

static func _banner_material(theme: String, variant: int) -> Material:
	var key := "ban|%s|%d" % [theme, variant]
	if _tex.has(key):
		return _tex[key]
	var p := _pal(theme)
	var field := _col(p[0]) if variant == 0 else _col(p[2]).lerp(_col(p[0]), 0.35)
	var trim := _col(p[1])
	var dark := _col(p[2])
	var W := 44
	var H := 96
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var c := field
			var edge := mini(mini(x, W - 1 - x), y)
			if y > H - 14:                                # bas en pointe (queue d'aronde)
				var cut := (y - (H - 14)) * W / 2 / 14
				if absi(x - W / 2) < cut:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
			if edge < 2:
				c = trim
			elif edge < 4:
				c = dark
			# emblème : losange (variante 0) ou croix (variante 1)
			var u := absi(x - W / 2)
			var v := absi(y - 40)
			if variant == 0 and u + v < 13 and u + v > 8:
				c = trim
			elif variant == 0 and u + v <= 8:
				c = dark
			elif variant == 1 and ((u < 3 and v < 16) or (v < 3 and u < 11)):
				c = trim
			img.set_pixel(x, y, c)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	_tex[key] = mat
	return mat

## Bannières contre les murs des salles, sur les pans sans torche (le décor de torches pose une torche sur un pan sur deux).
static func _banners(rows: Array, cells: Array, inside: Dictionary, hs: int, out: Dictionary) -> void:
	var half := CELL * 0.5
	for c in cells:
		if (c.x + c.y) % 2 == 0:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			var ch := "#"
			if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < str(rows[n.y]).length():
				ch = str(rows[n.y])[n.x]
			if ch != "#":
				continue
			if _h(c.x * 4 + d.x, c.y * 4 + d.y, hs) % 3 != 0:
				continue
			var nrm := Vector3(-d.x, 0, -d.y)
			var pos := Vector3(c.x * CELL, 0, c.y * CELL) + Vector3(d.x * half, 0, d.y * half) + nrm * 0.05 + Vector3(0, 1.95, 0)
			var b := Basis(Vector3.UP, atan2(nrm.x, nrm.z))
			(out[_h(c.x, c.y, hs) % 2] as Array).append(Transform3D(b, pos))
