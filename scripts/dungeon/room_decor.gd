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

## Palettes propres à certains styles (le trésor est doré, le repaire sanglant) ; les autres suivent le thème du niveau.
const STYLE_PAL := {
	"tresor": [0x6a5010, 0xffd76a, 0x3a2a05],
	"repaire": [0x4a0f0f, 0x9a2a1a, 0x1c0606],
}

static var _tex: Dictionary = {}

static func _h(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff

static func _col(v: int) -> Color:
	return Color((v >> 16) / 255.0, ((v >> 8) & 255) / 255.0, (v & 255) / 255.0)

## `key` : un thème, ou « style:<id> » pour la palette propre à un style.
static func _pal(key: String) -> Array:
	if key.begins_with("style:"):
		return STYLE_PAL.get(key.substr(6), PALETTES["stone"])
	return PALETTES.get(key, PALETTES["stone"])

static func _pal_key(theme: String, style: String) -> String:
	return "style:" + style if STYLE_PAL.has(style) else theme

## Ajoute les décors des salles du niveau à `view`. `wall_mat` : matériau des murs (piliers de même pierre).
## Chaque salle reçoit un style (RoomStyles) : accessoires contre les murs (RoomProps), sol, piliers, tapis, lustre, bannières et ambiance.
static func add(view: LevelView, level: Dictionary, theme: String, wall_mat: Material) -> void:
	var rows: Array = level.get("mapRows", [])
	var rooms := RoomMap.detect(rows)
	if rooms.is_empty():
		return
	var seed := str(level.get("id", "")).hash()
	var root := Node3D.new()
	root.name = "RoomDecor"
	view.add_child(root)
	var styles := RoomStyles.assign(level, rooms, theme)
	var vedette := RoomStyles.vedette(rooms)
	var blocked := _blocked_cells(level)
	var mats := {}
	var prims := {}                       # matériau -> forme -> [Transform3D]
	var shafts: Array = []
	var bases: Array = []
	var caps: Array = []
	var banners := {}
	for r in rooms:
		var rect: Rect2i = r.rect
		var inside := {}
		for c in r.cells:
			inside[c] = true
		var style := str(styles.get(int(r.id), "commune"))
		var def: Dictionary = RoomProps.DEF.get(style, RoomProps.DEF["commune"])
		var pk := _pal_key(theme, style)
		var hs := _h(rect.position.x, rect.position.y, seed)
		var plan := RoomProps.plan({"rows": rows, "inside": inside, "cells": r.cells, "rect": rect, "blocked": blocked,
			"seed": hs, "vedette": int(r.id) == vedette, "style": style})
		_floor(root, r.cells, str(def.floor))
		var skip = plan.vertex
		var pil = def.pillars
		if pil:
			_pillars(rect, inside, theme, hs, shafts, bases, caps, skip, pil is String or style == "ruine")
		if def.rug:
			_rug(root, rect, inside, pk)
		if str(def.chand) != "":
			_chandelier(root, rect, inside, pk)
		if def.banners:
			if not banners.has(pk):
				banners[pk] = {0: [], 1: []}
			_banners(rows, r.cells, inside, hs, banners[pk], plan.used)
		for pr in plan.prims:
			var key := str(pr.m) if not str(pr.m).begins_with("cloth") else "%s@%s" % [pr.m, pk]     # les tissus suivent la palette de la salle
			if not mats.has(key):
				mats[key] = _material(key, wall_mat)
			var b := Basis(Vector3.UP, float(pr.y)) * Basis(Vector3.RIGHT, float(pr.pit)) * Basis(Vector3.BACK, float(pr.rol))
			var t := Transform3D(b * Basis.from_scale(pr.z), pr.p)
			if not prims.has(key):
				prims[key] = {}
			var by_shape: Dictionary = prims[key]
			if not by_shape.has(pr.s):
				by_shape[pr.s] = []
			(by_shape[pr.s] as Array).append(t)
		for f in plan.flames:
			_flame(Vector3(f.p), float(f.size), str(f.kind), theme)
		for w in plan.webs:
			_web(root, w.p, float(w.yaw))
		_ambiance(root, r.cells, rect, str(def.fx))
	_flush_flames(root)
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
	for pk in banners:
		for k in banners[pk]:
			if (banners[pk][k] as Array).is_empty():
				continue
			var q := QuadMesh.new()
			q.size = Vector2(1.1, 2.3)
			q.material = _banner_material(pk, k)
			_multi(root, q, banners[pk][k])
	for key in prims:
		for shape in prims[key]:
			_multi(root, _shape_mesh(str(shape), mats[key]), prims[key][shape])

## Cases où aucun accessoire ne se pose : objets du niveau (coffres, fontaines, pièges…), marchand, escaliers, départ.
static func _blocked_cells(level: Dictionary) -> Dictionary:
	var out := {}
	for it in level.get("items", []):
		out[Vector2i(int(it.get("x", -1)), int(it.get("y", -1)))] = true
	var tm = level.get("travelingMerchant")
	if tm is Dictionary:
		out[Vector2i(int(tm.get("x", -1)), int(tm.get("y", -1)))] = true
	for st in level.get("stairs", []):
		out[Vector2i(int(st.get("x", -1)), int(st.get("y", -1)))] = true
	out[Vector2i(int(level.get("startX", -1)), int(level.get("startY", -1)))] = true
	return out

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
static func _pillars(rect: Rect2i, inside: Dictionary, theme: String, hs: int, shafts: Array, bases: Array, caps: Array, skip = null, ruined := false) -> void:
	if rect.size.x < 3 or rect.size.y < 3:
		return
	for vi in [1, rect.size.x - 1]:
		for vj in [1, rect.size.y - 1]:
			var cx: int = rect.position.x + vi
			var cy: int = rect.position.y + vj
			if skip != null and skip == Vector2i(cx, cy):      # la pièce maîtresse occupe ce sommet
				continue
			# le sommet est entouré de quatre cases de la salle
			if not (inside.has(Vector2i(cx - 1, cy - 1)) and inside.has(Vector2i(cx, cy - 1)) and inside.has(Vector2i(cx - 1, cy)) and inside.has(Vector2i(cx, cy))):
				continue
			var wx := (cx - 0.5) * CELL
			var wz := (cy - 0.5) * CELL
			var broken := (theme == "ruins" or ruined) and _h(cx, cy, hs) % 3 == 0
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
	var T := 64                        # pixels par case : tissage fin, bords lissés
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	for y in h * T:
		for x in w * T:
			var edge := float(mini(mini(x, w * T - 1 - x), mini(y, h * T - 1 - y))) / T
			var c := field
			# bordure : filet clair, bande sombre, filet clair (transitions lissées)
			c = c.lerp(dark, 1.0 - smoothstep(0.115, 0.135, edge))
			c = c.lerp(trim, 1.0 - smoothstep(0.075, 0.095, edge))
			c = c.lerp(dark, 1.0 - smoothstep(0.045, 0.06, edge))
			c = c.lerp(trim, 1.0 - smoothstep(0.015, 0.03, edge))
			# losanges répétés au cœur du tapis
			var inner := smoothstep(0.15, 0.19, edge)
			var u := absf(float(x % T) / T - 0.5)
			var v := absf(float(y % T) / T - 0.5)
			var d := u + v
			var pat := field
			pat = pat.lerp(dark, 1.0 - smoothstep(0.26, 0.29, d))
			pat = pat.lerp(trim.darkened(0.15), 1.0 - smoothstep(0.19, 0.22, d))
			pat = pat.lerp(field.darkened(0.2), 1.0 - smoothstep(0.07, 0.1, d))
			c = c.lerp(pat, inner)
			# fibres : grain fin et trame
			var g := float(_h(x, y, 5) % 100) / 100.0
			var weave := 0.5 + 0.5 * sin(float(x) * 1.9) * sin(float(y) * 1.9)
			var k := 0.9 + 0.1 * g + 0.05 * weave
			# bord du tapis fondu sur ~2 pixels : bord lissé sans dépendre du réglage MSAA
			var edge_a := clampf((edge * T + 0.5) / 2.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, edge_a))
	img.generate_mipmaps()
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
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_repeat = false
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
		_flame(n.position + pos + Vector3(0, 0.3, 0), 0.5, "warm", theme)

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
static func _banners(rows: Array, cells: Array, inside: Dictionary, hs: int, out: Dictionary, used: Dictionary = {}) -> void:
	var half := CELL * 0.5
	for c in cells:
		if (c.x + c.y) % 2 == 0:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			var ch := "#"
			if n.y >= 0 and n.y < rows.size() and n.x >= 0 and n.x < str(rows[n.y]).length():
				ch = str(rows[n.y])[n.x]
			if ch != "#" or used.has("%d,%d,%d,%d" % [c.x, c.y, d.x, d.y]):
				continue
			if _h(c.x * 4 + d.x, c.y * 4 + d.y, hs) % 3 != 0:
				continue
			var nrm := Vector3(-d.x, 0, -d.y)
			var pos := Vector3(c.x * CELL, 0, c.y * CELL) + Vector3(d.x * half, 0, d.y * half) + nrm * 0.05 + Vector3(0, 1.95, 0)
			var b := Basis(Vector3.UP, atan2(nrm.x, nrm.z))
			(out[_h(c.x, c.y, hs) % 2] as Array).append(Transform3D(b, pos))

# ------------------------------------------------------------------ matériaux et formes des accessoires

static func _solid(c: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func _material(key: String, wall_mat: Material) -> Material:
	if key.begins_with("cloth"):
		var parts := key.split("@")
		var p := _pal(parts[1])
		var m := _solid(_col(p[0]) if parts[0] == "cloth_a" else _col(p[1]), 1.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		return m
	match key:
		"stone": return wall_mat
		"wood": return _solid(Color("6b4a2a"), 0.95)
		"dark_wood": return _solid(Color("3c2814"), 0.95)
		"marble": return _solid(Color("d8d4cc"), 0.4)
		"iron": return _solid(Color("2a2a2e"), 0.5, 0.5)
		"gold":
			var g := _solid(Color("d8b040"), 0.35, 0.8)
			g.emission_enabled = true
			g.emission = Color("d8b040")
			g.emission_energy_multiplier = 0.12
			return g
		"bone": return _solid(Color("e0d8c0"), 0.8)
		"paper": return _solid(Color("e8dcb4"), 1.0)
		"straw": return _solid(Color("9a8a5c"), 1.0)
		"moss": return _solid(Color("3f6a2a"), 1.0)
		"candle": return _solid(Color("f0e8cc"), 0.8)
		"soot": return _solid(Color("0d0b0a"), 1.0)
		"book1": return _solid(Color("7a2a2a"), 0.9)
		"book2": return _solid(Color("2a4a6a"), 0.9)
		"book3": return _solid(Color("3a5a2a"), 0.9)
		"water":
			var w := _solid(Color(0.16, 0.3, 0.4, 0.6), 0.1, 0.3)
			w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			return w
		"ember":
			var e := _solid(Color("ff7a2a"), 1.0)
			e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return e
		"shroom":
			var sh := _solid(Color("6affa0"), 0.8)
			sh.emission_enabled = true
			sh.emission = Color("4aff90")
			sh.emission_energy_multiplier = 1.2
			return sh
	return _solid(Color("808080"))

static var _shape_cache: Dictionary = {}

static func _shape_mesh(shape: String, mat: Material) -> Mesh:
	var mesh: Mesh
	match shape:
		"box":
			mesh = BoxMesh.new()
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 14
			c.rings = 1
			mesh = c
		"sph":
			var sp := SphereMesh.new()
			sp.radius = 0.5
			sp.height = 1.0
			sp.radial_segments = 12
			sp.rings = 6
			mesh = sp
		_:
			var co := CylinderMesh.new()
			co.top_radius = 0.0
			co.bottom_radius = 0.5
			co.height = 1.0
			co.radial_segments = 10
			co.rings = 1
			mesh = co
	mesh.material = mat
	return mesh

# ------------------------------------------------------------------ flammes, toiles, ambiance

const FLAME_COLORS := {
	"green": Color(0.4, 1.0, 0.55),
	"red": Color(1.0, 0.3, 0.2),
	"gold": Color(1.0, 0.82, 0.4),
}

## Flammes de décor : exactement celles des torches des couloirs (TorchLayer : goutte 3D animée par shader + cœur + halo vacillant),
## regroupées en MultiMesh par couleur. `p` = centre de l'ancienne flamme ; le pied de la nouvelle est posé un peu plus bas.
static var _pending_flames: Array = []

static func _flame(p: Vector3, size: float, kind: String, theme: String) -> void:
	_pending_flames.append({"p": p, "size": size, "kind": kind, "theme": theme})

static func _flush_flames(root: Node3D) -> void:
	var groups := {}
	var cfg: Dictionary = Data.constants.get("CANDELABRA_THEME", {})
	for f in _pending_flames:
		var kind := str(f.kind)
		var col: Color
		var glow: Color
		var key: String
		if FLAME_COLORS.has(kind):
			col = FLAME_COLORS[kind]
			glow = col
			key = "room_" + kind
		else:
			var c: Dictionary = cfg.get(str(f.theme), cfg.get("stone", {}))
			col = TorchLayer._hex(int(c.get("flame", 0xffb050)))
			glow = TorchLayer._hex(int(c.get("glow", 0xffb060)))
			key = str(f.theme)
		if not groups.has(key):
			groups[key] = {"flame": [], "inner": [], "glow": [], "fc": col, "gc": glow}
		var g: Dictionary = groups[key]
		var k: float = float(f.size) * 1.4
		var base: Vector3 = f.p - Vector3(0, 0.2 * float(f.size), 0)
		g.flame.append(Transform3D(Basis.from_scale(Vector3.ONE * k), base))
		g.inner.append(Transform3D(Basis.from_scale(Vector3(0.52, 0.72, 0.52) * k), base))
		g.glow.append(Transform3D(Basis.from_scale(Vector3.ONE * float(f.size) * 1.6), base + Vector3(0, TorchLayer.FLAME_H * 0.44 * k, 0)))
	_pending_flames.clear()
	if groups.is_empty():
		return
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(0.5, 0.5)
	for key in groups:
		var g: Dictionary = groups[key]
		root.add_child(TorchLayer._multimesh(glow_quad, g.glow, TorchLayer._get_glow_mat(key, g.gc)))
		root.add_child(TorchLayer._multimesh(TorchLayer._get_flame_mesh(), g.flame, TorchLayer._get_flame_mat(key, false, g.fc)))
		root.add_child(TorchLayer._multimesh(TorchLayer._get_flame_mesh(), g.inner, TorchLayer._get_flame_mat(key, true, g.fc)))

static func _web(root: Node3D, p: Vector3, yaw: float) -> void:
	var key := "web"
	if not _tex.has(key):
		var W := 48
		var img := Image.create(W, W, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var col := Color(0.92, 0.92, 0.95, 0.75)
		for i in 7:                                  # fils rayonnant depuis le haut
			var a := PI * (0.12 + 0.76 * float(i) / 6.0)
			for t in W:
				var x := int(W * 0.5 + cos(a) * t * 0.98)
				var y := int(sin(a) * t * 0.98)
				if x >= 0 and x < W and y >= 0 and y < W:
					img.set_pixel(x, y, col)
		for rr in [10, 18, 27, 36]:                  # arcs de soie
			for k in 90:
				var a2 := PI * (0.1 + 0.8 * float(k) / 89.0)
				var x2 := int(W * 0.5 + cos(a2) * rr)
				var y2 := int(sin(a2) * rr)
				if x2 >= 0 and x2 < W and y2 >= 0 and y2 < W:
					img.set_pixel(x2, y2, col)
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tex[key] = m
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.material = _tex[key]
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = p
	mi.rotation.y = yaw
	root.add_child(mi)

## Poussière, braises, brume ou éclats dorés flottant dans la salle (peu de particules, en simple CPU pour l'export Web).
static func _ambiance(root: Node3D, cells: Array, rect: Rect2i, kind: String) -> void:
	if kind == "":
		return
	var pr := CPUParticles3D.new()
	pr.name = "Ambiance_" + kind
	pr.amount = clampi(int(cells.size() * (1.2 if kind != "mist" else 0.5)), 8, 28)
	pr.lifetime = 9.0
	pr.preprocess = 9.0
	pr.local_coords = false
	pr.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pr.emission_box_extents = Vector3(rect.size.x * CELL * 0.5, 1.6 if kind != "mist" else 0.4, rect.size.y * CELL * 0.5)
	pr.position = Vector3((rect.position.x + rect.size.x * 0.5 - 0.5) * CELL, 1.8 if kind != "mist" else 0.5, (rect.position.y + rect.size.y * 0.5 - 0.5) * CELL)
	pr.direction = Vector3.UP
	pr.spread = 180.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	match kind:
		"dust":
			mat.albedo_texture = ProceduralTextures.glow()
			pr.color = Color(0.85, 0.8, 0.7, 0.35)
			pr.initial_velocity_min = 0.02
			pr.initial_velocity_max = 0.08
			q.size = Vector2(0.07, 0.07)
		"embers":
			mat.albedo_texture = ProceduralTextures.glow()
			pr.color = Color(1.0, 0.5, 0.2, 0.8)
			pr.initial_velocity_min = 0.1
			pr.initial_velocity_max = 0.3
			pr.gravity = Vector3(0, 0.12, 0)
			q.size = Vector2(0.06, 0.06)
		"motes":
			mat.albedo_texture = ProceduralTextures.glow()
			pr.color = Color(1.0, 0.9, 0.55, 0.7)
			pr.initial_velocity_min = 0.03
			pr.initial_velocity_max = 0.12
			q.size = Vector2(0.09, 0.09)
		_:
			mat.albedo_texture = ProceduralTextures.smoke()
			pr.color = Color(0.55, 0.9, 0.75, 0.1)
			pr.initial_velocity_min = 0.03
			pr.initial_velocity_max = 0.1
			q.size = Vector2(2.4, 2.4)
	q.material = mat
	pr.mesh = q
	root.add_child(pr)

# ------------------------------------------------------------------ sol

static func _floor_texture(name: String) -> Texture2D:
	var key := "floor|" + name
	if _tex.has(key):
		return _tex[key]
	var N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var n := float(_h(x, y, name.hash()) % 100) / 100.0
			var c := Color(0, 0, 0, 0)
			match name:
				"parquet":
					var plank := (x / 8) % 2
					c = Color("6b4a2a").lerp(Color("8a6238"), 0.35 * float(plank) + 0.2 * n)
					if x % 8 == 0 or (y + plank * 16) % 32 == 0:
						c = c.darkened(0.45)
				"dalles":
					c = Color("5a5a64").lerp(Color("74747e"), n * 0.6 + (0.2 if ((x / 32) + (y / 32)) % 2 == 0 else 0.0))
					if x % 32 < 1 or y % 32 < 1:
						c = Color("33333a")
				"terre":
					c = Color(0.18, 0.12, 0.07, 0.35 + 0.3 * n)
				"damier":
					c = Color("8c8a86") if ((x / 32) + (y / 32)) % 2 == 0 else Color("1e1e26")
					c = c.lerp(Color(0.5, 0.5, 0.5), n * 0.08)
					if x % 32 == 0 or y % 32 == 0:
						c = Color("8a7030")
				"fissures":
					c = Color(0.08, 0.07, 0.07, 0.15 + 0.2 * n)
					var cr := absi((x * 3 + y * 5 + (y / 9) * 11) % 41 - 20)
					if cr < 1 and n < 0.8:
						c = Color(0.02, 0.02, 0.02, 0.8)
				"planches":
					var pl := (y / 10) % 2
					c = Color("7a5a38").lerp(Color("5e4126"), 0.3 * float(pl) + 0.3 * n)
					if y % 10 == 0 or (x + pl * 21) % 42 == 0:
						c = c.darkened(0.5)
				"mouille":
					c = Color(0.05, 0.14, 0.15, 0.3 + 0.25 * n)
				"dore":
					c = Color("2a2418").lerp(Color("3a3020"), n * 0.6)
					if x % 32 < 2 or y % 32 < 2 or absi((x % 32) - (y % 32)) < 1:
						c = Color("d8b040")
				"sang":
					var blob := sin(float(x) * 0.22) * cos(float(y) * 0.19) + sin(float(x + y) * 0.31)
					c = Color(0.35, 0.03, 0.03, 0.55) if blob > 1.0 else Color(0.06, 0.03, 0.03, 0.35 + 0.15 * n)
				"paille":
					c = Color(0.62, 0.5, 0.22, 0.5 + 0.25 * n)
					if (x * 7 + y * 3) % 13 == 0:
						c = Color(0.8, 0.66, 0.3, 0.9)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

## Revêtement de sol propre au style : un matériau PBR (couleur + normales + rugosité, mêmes jeux de textures que le village) posé sur le sol
## du thème, une dalle par case de la salle, puis un calque dessiné lissé (joints, damier, filets d'or, fissures, paille, sang) par-dessus.
## Sans les textures PBR (export allégé), on retombe sur l'ancien dessin à basse définition.
## style -> [texture PBR, répétitions par case, teinte, rugosité (0 = celle de la texture), calque]
const FLOOR_PBR := {
	"parquet": ["bois_m", Vector2(2, 1), Color(1.9, 1.35, 0.9), 0.0, ""],
	"planches": ["bois_m", Vector2(1, 1), Color(1.6, 1.3, 1.0), 0.0, ""],
	"dalles": ["beton", Vector2(2, 2), Color(0.85, 0.87, 0.95), 0.0, "joints"],
	"terre": ["terre", Vector2(1, 1), Color(0.62, 0.55, 0.5), 0.0, ""],
	"damier": ["beton", Vector2(1, 1), Color(1, 1, 1), 0.35, "damier"],
	"fissures": ["beton", Vector2(2, 2), Color(0.55, 0.55, 0.58), 0.0, "fissures"],
	"mouille": ["paves", Vector2(2, 2), Color(0.5, 0.62, 0.6), 0.45, ""],
	"dore": ["beton", Vector2(2, 2), Color(0.42, 0.38, 0.34), 0.5, "filets"],
	"sang": ["beton", Vector2(2, 2), Color(0.38, 0.33, 0.33), 0.0, "sang"],
	"paille": ["terre", Vector2(1, 1), Color(1.15, 0.98, 0.6), 0.0, "paille"],
}

static func _floor_base(name: String) -> Material:
	var key := "floorpbr|" + name
	if _tex.has(key):
		return _tex[key]
	var d: Array = FLOOR_PBR[name]
	var src := VillageKit.mat(str(d[0]), d[1])
	var m: StandardMaterial3D = null
	if src != null:
		m = src.duplicate() as StandardMaterial3D           # le matériau du village est partagé : on ne le teinte pas
		m.albedo_color = d[2]
		if float(d[3]) > 0.0:
			m.roughness = float(d[3])
	_tex[key] = m
	return m

## Calque dessiné (256 px, filtré en lissé) ; l'alpha porte le motif.
static func _floor_overlay(kind: String) -> Texture2D:
	var key := "floorov|" + kind
	if _tex.has(key):
		return _tex[key]
	var N := 256
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	match kind:
		"joints":
			for y in N:
				for x in N:
					var u := float(x) / N
					var v := float(y) / N
					var dx := absf(fposmod(u * 2.0 + 0.5, 1.0) - 0.5) / 2.0
					var dy := absf(fposmod(v * 2.0 + 0.5, 1.0) - 0.5) / 2.0
					var dl := minf(dx, dy)
					var line := 1.0 - smoothstep(0.004, 0.011, dl)
					var tone := float(_h(int(u * 2.0), int(v * 2.0), 7) % 100) / 100.0
					var n := _pnoise(u * 8.0, v * 8.0, 8) * 0.5 + _pnoise(u * 24.0, v * 24.0, 24) * 0.5
					var a := clampf(line * 0.9 + (1.0 - line) * (0.06 + 0.16 * tone) * (0.6 + n), 0.0, 1.0)
					img.set_pixel(x, y, Color(0.03, 0.03, 0.04, a))
		"damier":
			for y in N:
				for x in N:
					var u := float(x) / N
					var v := float(y) / N
					var cx := int(floorf(u * 4.0))
					var cy := int(floorf(v * 4.0))
					var white := (cx + cy) % 2 == 0
					var n := _pnoise(u * 6.0, v * 6.0, 6) * 0.6 + _pnoise(u * 20.0, v * 20.0, 20) * 0.4
					var vein := 1.0 - smoothstep(0.0, 0.05, absf(_pnoise(u * 5.0 + 3.0, v * 5.0, 5) - 0.5))
					var c := Color(0.82, 0.8, 0.76).lerp(Color(0.6, 0.58, 0.55), n * 0.7) if white else Color(0.07, 0.07, 0.09).lerp(Color(0.16, 0.16, 0.2), n)
					c = c.lerp(Color(0.5, 0.5, 0.55) if white else Color(0.3, 0.3, 0.36), vein * 0.5)
					var ex := absf(fposmod(u * 4.0 + 0.5, 1.0) - 0.5) / 4.0
					var ey := absf(fposmod(v * 4.0 + 0.5, 1.0) - 0.5) / 4.0
					var e := 1.0 - smoothstep(0.002, 0.007, minf(ex, ey))
					c = c.lerp(Color(0.04, 0.035, 0.03), e * 0.8)
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		"filets":
			for y in N:
				for x in N:
					var u := float(x) / N - 0.5
					var v := float(y) / N - 0.5
					var border := absf(maxf(absf(u), absf(v)) - 0.46)
					var diamond := absf(absf(u) + absf(v) - 0.34)
					var line := maxf(1.0 - smoothstep(0.006, 0.016, border), 1.0 - smoothstep(0.004, 0.012, diamond))
					var n := _pnoise((u + 0.5) * 16.0, (v + 0.5) * 16.0, 16)
					var c := Color(0.9, 0.7, 0.25).lerp(Color(0.62, 0.45, 0.14), n * 0.6)
					img.set_pixel(x, y, Color(c.r, c.g, c.b, line))
		"fissures":
			for y in N:
				for x in N:
					var u := float(x) / N
					var v := float(y) / N
					var w := _pnoise(u * 3.0, v * 3.0, 3) * 0.5
					var cr := absf(_pnoise(u * 5.0 + w, v * 5.0 + w, 5) - 0.5)
					var cr2 := absf(_pnoise(u * 9.0 + 2.0, v * 9.0 - w, 9) - 0.5)
					var a := maxf(1.0 - smoothstep(0.004, 0.02, cr), (1.0 - smoothstep(0.003, 0.012, cr2)) * 0.6)
					var dust := _pnoise(u * 7.0, v * 7.0, 7)
					img.set_pixel(x, y, Color(0.02, 0.02, 0.02, clampf(a * 0.9 + 0.12 * dust, 0.0, 1.0)))
		"sang":
			for y in N:
				for x in N:
					var u := float(x) / N
					var v := float(y) / N
					var n := _pnoise(u * 3.0, v * 3.0, 3) * 0.55 + _pnoise(u * 7.0, v * 7.0, 7) * 0.3 + _pnoise(u * 18.0, v * 18.0, 18) * 0.15
					var a := smoothstep(0.54, 0.62, n)
					var rim := smoothstep(0.54, 0.6, n) * (1.0 - smoothstep(0.62, 0.72, n))
					var c := Color(0.34, 0.03, 0.03).lerp(Color(0.14, 0.01, 0.01), rim)
					img.set_pixel(x, y, Color(c.r, c.g, c.b, a * 0.8))
		"paille":
			img.fill(Color(0, 0, 0, 0))
			for i in 420:
				var cx := rng.randf() * N
				var cy := rng.randf() * N
				var ang := rng.randf() * TAU
				var ln := 14.0 + rng.randf() * 20.0
				var c := Color(0.86, 0.7, 0.32).lerp(Color(0.6, 0.45, 0.18), rng.randf())
				for k in int(ln):
					var px := int(fposmod(cx + cos(ang) * k, N))
					var py := int(fposmod(cy + sin(ang) * k, N))
					img.set_pixel(px, py, Color(c.r, c.g, c.b, 0.85))
					var px2 := int(fposmod(cx + cos(ang) * k + 1.0, N))
					img.set_pixel(px2, py, Color(c.r, c.g, c.b, 0.45))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

## Bruit de valeur périodique (période entière : le motif se raccorde d'une case à l'autre).
static func _pnoise(x: float, y: float, period: int) -> float:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	var fx: float = x - floorf(x)
	var fy: float = y - floorf(y)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x0 := posmod(xi, period)
	var x1 := posmod(xi + 1, period)
	var y0 := posmod(yi, period)
	var y1 := posmod(yi + 1, period)
	var a := float(_h(x0, y0, 31) % 1000) / 1000.0
	var b := float(_h(x1, y0, 31) % 1000) / 1000.0
	var c := float(_h(x0, y1, 31) % 1000) / 1000.0
	var d := float(_h(x1, y1, 31) % 1000) / 1000.0
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

static func _floor(root: Node3D, cells: Array, name: String) -> void:
	var base := _floor_base(name) if FLOOR_PBR.has(name) else null
	if base == null:
		_floor_legacy(root, cells, name)
		return
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL, CELL)
	pm.material = base
	var xf: Array = []
	for c in cells:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(c.x * CELL, 0.012, c.y * CELL)))
	_multi(root, pm, xf)
	var ov := str((FLOOR_PBR[name] as Array)[4])
	if ov == "":
		return
	var okey := "floorovmat|" + ov
	if not _tex.has(okey):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _floor_overlay(ov)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.texture_repeat = false
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if ov != "damier" else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.roughness = 0.25 if ov == "sang" else (0.35 if ov == "damier" else (0.3 if ov == "filets" else 0.85))
		m.metallic = 0.6 if ov == "filets" else 0.0
		m.metallic_specular = 0.5
		_tex[okey] = m
	var om := PlaneMesh.new()
	om.size = Vector2(CELL, CELL)
	om.material = _tex[okey]
	var oxf: Array = []
	for c in cells:
		oxf.append(Transform3D(Basis.IDENTITY, Vector3(c.x * CELL, 0.018, c.y * CELL)))
	_multi(root, om, oxf)

static func _floor_legacy(root: Node3D, cells: Array, name: String) -> void:
	var key := "floormat|" + name
	if not _tex.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _floor_texture(name)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.9
		_tex[key] = m
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL, CELL)
	pm.material = _tex[key]
	var xf: Array = []
	for c in cells:
		xf.append(Transform3D(Basis.IDENTITY, Vector3(c.x * CELL, 0.012, c.y * CELL)))
	_multi(root, pm, xf)
