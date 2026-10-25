class_name PropMeshes
extends RefCounted
## Vrais modèles 3D (construits par le code) des accessoires de salle : tonneaux cerclés, caisses à lattes, étagères pleines de livres,
## râteliers d'armes, autel, braseros, ossements, cheminée, étal… Chaque modèle est un maillage statique partagé (un seul exemplaire en mémoire,
## affiché en MultiMesh par RoomDecor). Le dessin est en couleurs de sommets (teintes variées d'un bout à l'autre d'une planche, d'un livre, d'une
## pierre) avec une ombre de contact cuite dans le bas de l'objet, et une texture de grain commune.
## Trois surfaces par maillage : MATTE (bois, pierre, tissu, os), METAL (fer, or, laiton) et GLOW (braises, champignons, sans éclairage).
## Repère d'un modèle : origine au sol au centre de l'empreinte, +Y en haut, +Z vers l'intérieur de la salle (le dos de l'objet est en -Z).

const MATTE := 0
const METAL := 1
const GLOW := 2

const WOOD := Color("7a5430")
const DARK_WOOD := Color("4a3219")
const OAK := Color("8a6238")
const IRON := Color("34343a")
const IRON_L := Color("55555c")
const GOLD := Color("e0b040")
const BRASS := Color("b08a30")
const STONE := Color("8a8782")
const STONE_D := Color("5f5d5a")
const BONE := Color("e2dac2")
const CLOTH_R := Color("8a2a2a")
const CLOTH_C := Color("d8c9a0")
const STRAW := Color("a8925a")
const SACK := Color("a69064")
const WAX := Color("eee3c4")

static var _cache: Dictionary = {}
static var _mats: Array = []

## Constructeur de maillage (primitives lissées ou facettées, couleurs de sommets, transformation courante).
class B:
	var st: Array = []
	var cnt: Array = [0, 0, 0]
	var xf := Transform3D.IDENTITY
	var m := 0
	var ao := true

	func _init() -> void:
		for i in 3:
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append(s)

	## Hasard déterministe 0..1.
	static func h(a: int, b: int = 0, c: int = 0) -> float:
		var v := absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) & 0x7fffffff
		return float(v % 10007) / 10007.0

	static func sh(c: Color, k: float) -> Color:
		return Color(clampf(c.r * k, 0.0, 1.5), clampf(c.g * k, 0.0, 1.5), clampf(c.b * k, 0.0, 1.5), 1.0)

	## Teinte variée (±amt) selon un indice.
	static func jit(c: Color, amt: float, k: int) -> Color:
		return sh(c, 1.0 + (h(k, 17, 5) - 0.5) * 2.0 * amt)

	func push(t: Transform3D) -> Transform3D:
		var old := xf
		xf = xf * t
		return old

	func vtx(p: Vector3, n: Vector3, c: Color) -> void:
		var q := xf * p
		var k := 1.0
		if ao:
			k = lerpf(0.58, 1.0, smoothstep(0.0, 0.45, q.y))
		var s: SurfaceTool = st[m]
		s.set_color(Color(c.r * k, c.g * k, c.b * k, 1.0))
		s.set_normal((xf.basis * n).normalized())
		s.add_vertex(q)
		cnt[m] += 1

	## Triangle ; l'ordre des sommets est corrigé pour que la face avant (sens horaire dans Godot) regarde du côté des normales.
	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var g := (b - a).cross(c - a)
		if g.length_squared() < 1e-12:
			return
		if g.dot(na + nb + nc) > 0.0:
			vtx(a, na, ca)
			vtx(c, nc, cc)
			vtx(b, nb, cb)
		else:
			vtx(a, na, ca)
			vtx(b, nb, cb)
			vtx(c, nc, cc)

	## Triangle à ombrage plat ; `hint` donne le côté extérieur.
	func tri_flat(a: Vector3, b: Vector3, c: Vector3, hint: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var g := (b - a).cross(c - a)
		if g.length_squared() < 1e-12:
			return
		var n := g.normalized()
		if n.dot(hint) < 0.0:
			n = -n
		tri(a, b, c, n, n, n, ca, cb, cc)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
		tri(a, b, c, n, n, n, col, col, col)
		tri(a, c, d, n, n, n, col, col, col)

	## Boîte alignée sur les axes (centre, demi-dimensions), faces légèrement ombrées selon l'orientation.
	func box(ctr: Vector3, hs: Vector3, col: Color) -> void:
		for ai in 3:
			for sg in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[ai] = sg
				var ui := (ai + 1) % 3
				var vi := (ai + 2) % 3
				var u := Vector3.ZERO
				u[ui] = hs[ui]
				var v := Vector3.ZERO
				v[vi] = hs[vi]
				var o := ctr + n * hs[ai]
				var k := 1.0
				if ai == 1:
					k = 1.1 if sg > 0.0 else 0.7
				elif ai == 0:
					k = 0.92
				quad(o - u - v, o - u + v, o + u + v, o + u - v, n, sh(col, k))

	## Solide de révolution autour de Y. `prof` : points (rayon, hauteur) de bas en haut ; `stripe` : alternance de teinte (douelles) ;
	## `noise` : irrégularité du rayon ; `smooth` : normales moyennées d'un anneau à l'autre.
	func lathe(prof: Array, seg: int, col: Color, ctr := Vector3.ZERO, stripe := 0.0, noise := 0.0, smooth := false, sx := 1.0, sz := 1.0, alt := Color(0, 0, 0, 0)) -> void:
		var np := prof.size()
		var segn: Array = []
		for j in np - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var tr := p1 - p0
			segn.append(Vector2(tr.y, -tr.x).normalized())
		for j in np - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var n0: Vector2 = segn[j]
			var n1: Vector2 = segn[j]
			if smooth:
				if j > 0:
					n0 = (segn[j] + segn[j - 1]).normalized()
				if j + 2 < np:
					n1 = (segn[j] + segn[j + 1]).normalized()
			for i in seg:
				var a0 := TAU * float(i) / seg
				var a1 := TAU * float(i + 1) / seg
				var ra0 := 1.0 + noise * (h(i % seg, j, 3) - 0.5)
				var ra1 := 1.0 + noise * (h((i + 1) % seg, j, 3) - 0.5)
				var rb0 := 1.0 + noise * (h(i % seg, j + 1, 3) - 0.5)
				var rb1 := 1.0 + noise * (h((i + 1) % seg, j + 1, 3) - 0.5)
				var s0 := sin(a0)
				var c0 := cos(a0)
				var s1 := sin(a1)
				var c1 := cos(a1)
				var A := ctr + Vector3(s0 * p0.x * ra0 * sx, p0.y, c0 * p0.x * ra0 * sz)
				var Bv := ctr + Vector3(s0 * p1.x * rb0 * sx, p1.y, c0 * p1.x * rb0 * sz)
				var C := ctr + Vector3(s1 * p1.x * rb1 * sx, p1.y, c1 * p1.x * rb1 * sz)
				var D := ctr + Vector3(s1 * p0.x * ra1 * sx, p0.y, c1 * p0.x * ra1 * sz)
				var k := 1.0 + (stripe if i % 2 == 0 else -stripe) + (h(i, j, 9) - 0.5) * 0.05
				var cc := sh(alt if (alt.a > 0.0 and i % 2 == 1) else col, k)
				tri(A, Bv, C, Vector3(s0 * n0.x, n0.y, c0 * n0.x), Vector3(s0 * n1.x, n1.y, c0 * n1.x), Vector3(s1 * n1.x, n1.y, c1 * n1.x), cc, cc, cc)
				tri(A, C, D, Vector3(s0 * n0.x, n0.y, c0 * n0.x), Vector3(s1 * n1.x, n1.y, c1 * n1.x), Vector3(s1 * n0.x, n0.y, c1 * n0.x), cc, cc, cc)

	## Tronc de cône d'axe a→b (rayons ra, rb), avec ou sans bouchons.
	func frustum(a: Vector3, bp: Vector3, ra: float, rb: float, seg := 8, col := Color.WHITE, caps := true) -> void:
		var axis := bp - a
		var len_ := axis.length()
		if len_ < 1e-5:
			return
		var y := axis / len_
		var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.UP).normalized()
		var z := x.cross(y)
		var old := push(Transform3D(Basis(x, y, z), a))
		var prof: Array = []
		if caps:
			prof.append(Vector2(0.0, 0.0))
		prof.append(Vector2(ra, 0.0))
		prof.append(Vector2(rb, len_))
		if caps:
			prof.append(Vector2(0.0, len_))
		lathe(prof, seg, col)
		xf = old

	## Boîte tournée (base `bs`, centre `ctr`).
	func rbox(ctr: Vector3, hs: Vector3, col: Color, bs: Basis) -> void:
		var o := push(Transform3D(bs, ctr))
		box(Vector3.ZERO, hs, col)
		xf = o

	func hoop(r: float, y: float, hh: float, t: float, col: Color, seg := 16) -> void:
		lathe([Vector2(r, y - hh * 0.5), Vector2(r + t, y - hh * 0.5), Vector2(r + t, y + hh * 0.5), Vector2(r, y + hh * 0.5)], seg, col)

	## Ellipsoïde (centre, rayons) ; `noise` : irrégularité, `flat` : facettes (cailloux), sinon ombrage lisse.
	func ellipsoid(ctr: Vector3, rad: Vector3, col: Color, seg := 10, rings := 6, noise := 0.0, seedv := 0, flat := false) -> void:
		var pts: Array = []
		for r in rings + 1:
			var phi := PI * float(r) / rings
			var row: Array = []
			for i in seg + 1:
				var a := TAU * float(i % seg) / seg
				var k := 1.0 + noise * (h(i % seg, r, seedv) - 0.5) * (0.0 if r == 0 or r == rings else 1.0)
				var u := Vector3(sin(phi) * sin(a), cos(phi), sin(phi) * cos(a))
				row.append({"p": ctr + u * rad * k, "n": Vector3(u.x / rad.x, u.y / rad.y, u.z / rad.z).normalized()})
			pts.append(row)
		for r in rings:
			for i in seg:
				var A: Dictionary = pts[r][i]
				var Bd: Dictionary = pts[r + 1][i]
				var C: Dictionary = pts[r + 1][i + 1]
				var D: Dictionary = pts[r][i + 1]
				var k := 1.0 + (h(i, r, seedv + 7) - 0.5) * 0.14
				var cc := sh(col, k)
				if flat:
					var hint: Vector3 = (A.n + Bd.n + C.n + D.n)
					tri_flat(A.p, Bd.p, C.p, hint, cc, cc, cc)
					tri_flat(A.p, C.p, D.p, hint, cc, cc, cc)
				else:
					tri(A.p, Bd.p, C.p, A.n, Bd.n, C.n, cc, cc, cc)
					tri(A.p, C.p, D.p, A.n, C.n, D.n, cc, cc, cc)

	## Caillou facetté.
	func rock(ctr: Vector3, rad: Vector3, seedv: int, col: Color) -> void:
		ellipsoid(ctr, rad, col, 7, 4, 0.55, seedv, true)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for i in 3:
			if cnt[i] == 0:
				continue
			(st[i] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, PropMeshes._mat(i))
		return mesh

# ------------------------------------------------------------------ matériaux

static func _grain() -> Texture2D:
	var N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var a := B.h(x, y, 11)
			var b := B.h(x / 4, y / 4, 12)
			var v := 0.82 + 0.10 * a + 0.08 * b
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _mat(i: int) -> Material:
	if _mats.is_empty():
		var t := _grain()
		var mm := StandardMaterial3D.new()
		mm.vertex_color_use_as_albedo = true
		mm.albedo_texture = t
		mm.uv1_triplanar = true
		mm.uv1_scale = Vector3(2.5, 2.5, 2.5)
		mm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mm.roughness = 0.88
		mm.metallic_specular = 0.3
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mt := StandardMaterial3D.new()
		mt.vertex_color_use_as_albedo = true
		mt.metallic = 0.5
		mt.roughness = 0.5
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mg := StandardMaterial3D.new()
		mg.vertex_color_use_as_albedo = true
		mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mg.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats = [mm, mt, mg]
	return _mats[i]

# ------------------------------------------------------------------ accès

static func has(name: String) -> bool:
	return MODELS.has(name.rstrip("0123456789"))

## Maillage du modèle `name` (construit une fois, partagé).
static func get_mesh(name: String) -> ArrayMesh:
	if _cache.has(name):
		return _cache[name]
	var b := B.new()
	var base := name.rstrip("0123456789")
	var v := int(name.substr(base.length())) if name.length() > base.length() else 0
	match base:
		"barrel": _barrel(b, v)
		"crate": _crate(b, v)
		"sack": _sack(b, v)
		"candle": _candle(b, v)
		"brazier_iron": _brazier(b, false)
		"brazier_gold": _brazier(b, true)
		"bookshelf": _bookshelf(b, v)
		"weapon_rack": _weapon_rack(b, v)
		"shield_wall": _shield_wall(b, v)
		"dummy": _dummy(b)
		"altar": _altar(b)
		"candelabra": _candelabra(b)
		"sconce": _sconce(b)
		"rock": _rock(b, v)
		"rubble": _rubble(b, v)
		"column_stump": _column_stump(b)
		"column_fallen": _column_fallen(b)
		"table_long": _table(b, 3.2, 0.95)
		"table_small": _table_small(b)
		"bench": _bench(b)
		"stool": _stool(b)
		"tableware": _tableware(b)
		"fireplace": _fireplace(b)
		"stalagmite": _stalagmite(b, v, false)
		"stalactite": _stalagmite(b, v, true)
		"mushrooms": _mushrooms(b, v)
		"gold_pile": _gold_mound(b, 0.45, 0.34, v, 55)
		"gold_hoard":
			_gold_mound(b, 1.0, 0.85, v, 190)
			_goblet(b, Vector3(0.7, 0.1, 0.5))
			_bars(b, Vector3(-0.8, 0.0, 0.7), 0.4)
		"coins": _coin_scatter(b, v)
		"gold_bars": _bars(b, Vector3.ZERO, 0.0)
		"vase": _vase(b, v)
		"bones": _bones(b, v)
		"skull": _skull(b, Vector3.ZERO, 0.0)
		"wall_chains": _wall_chains(b)
		"throne": _throne(b)
		"stall": _stall(b)
		_: pass
	var mesh := b.commit()
	_cache[name] = mesh
	return mesh

const MODELS := ["barrel", "crate", "sack", "candle", "brazier_iron", "brazier_gold", "bookshelf", "weapon_rack", "shield_wall", "dummy", "altar", "candelabra", "sconce", "rock", "rubble", "column_stump", "column_fallen", "table_long", "table_small", "bench", "stool", "tableware", "fireplace", "stalagmite", "stalactite", "mushrooms", "gold_pile", "gold_hoard", "coins", "gold_bars", "vase", "bones", "skull", "wall_chains", "throne", "stall"]

# ------------------------------------------------------------------ modèles

static func _barrel_r(y: float) -> float:
	return 0.30 + 0.125 * pow(sin(PI * clampf(y, 0.0, 0.95) / 0.95), 0.7)

static func _barrel(b: B, v: int) -> void:
	var prof: Array = []
	for i in 13:
		var y := 0.95 * float(i) / 12.0
		prof.append(Vector2(_barrel_r(y), y))
	prof.append(Vector2(0.29, 0.95))
	prof.append(Vector2(0.27, 0.93))
	prof.append(Vector2(0.0, 0.93))
	b.lathe(prof, 18, B.jit(WOOD, 0.1, v), Vector3.ZERO, 0.07, 0.0, true)
	b.m = METAL
	for y in [0.09, 0.29, 0.66, 0.86]:
		b.hoop(_barrel_r(y) - 0.004, y, 0.07, 0.022, IRON)
	b.m = MATTE
	# planches du couvercle (traits sombres) et bonde
	for k in 3:
		b.box(Vector3(-0.17 + 0.17 * k, 0.936, 0.0), Vector3(0.005, 0.004, 0.25), B.sh(DARK_WOOD, 0.9))
	b.lathe([Vector2(0.0, 0.93), Vector2(0.045, 0.93), Vector2(0.04, 0.96), Vector2(0.0, 0.96)], 8, DARK_WOOD, Vector3(0.12, 0, 0.12))

static func _crate(b: B, v: int) -> void:
	var s := 0.5
	b.box(Vector3(0, 0.5, 0), Vector3(0.45, 0.45, 0.45), DARK_WOOD)
	for side in 4:
		var o := b.push(Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3.ZERO))
		for k in 3:
			var y := 0.17 + 0.33 * k
			b.box(Vector3(0, y, 0.475), Vector3(0.455, 0.14, 0.02), B.jit(WOOD, 0.14, side * 7 + k + v * 3))
		if side % 2 == 0:
			# croix de renfort en diagonale
			var o2 := b.push(Transform3D(Basis(Vector3(0, 0, 1), 0.74), Vector3(0, 0.5, 0.5)))
			b.box(Vector3.ZERO, Vector3(0.6, 0.045, 0.012), B.sh(OAK, 0.85))
			b.xf = o2
		b.xf = o
	for sx in [-0.46, 0.46]:
		for sz in [-0.46, 0.46]:
			b.box(Vector3(sx, 0.5, sz), Vector3(0.05, 0.5, 0.05), B.sh(OAK, 0.8))
	for k in 4:
		b.box(Vector3(-0.33 + 0.22 * k, 1.0, 0.0), Vector3(0.1, 0.02, 0.47), B.jit(WOOD, 0.12, 40 + k + v))
	b.m = METAL
	for sx in [-0.46, 0.46]:
		for sz in [-0.46, 0.46]:
			b.box(Vector3(sx, 0.03, sz), Vector3(0.055, 0.03, 0.055), IRON_L)
			b.box(Vector3(sx, 0.97, sz), Vector3(0.055, 0.03, 0.055), IRON_L)
	b.m = MATTE

static func _sack(b: B, v: int) -> void:
	b.ellipsoid(Vector3(0, 0.27, 0), Vector3(0.33, 0.27, 0.27), B.jit(SACK, 0.1, v), 14, 8, 0.1, v + 3)
	b.lathe([Vector2(0.17, 0.46), Vector2(0.09, 0.6), Vector2(0.07, 0.66), Vector2(0.13, 0.74), Vector2(0.06, 0.7), Vector2(0.0, 0.7)], 10, B.sh(SACK, 0.95), Vector3.ZERO, 0.0, 0.2, true)
	b.lathe([Vector2(0.075, 0.55), Vector2(0.095, 0.55), Vector2(0.095, 0.58), Vector2(0.075, 0.58)], 10, DARK_WOOD, Vector3(0, 0, 0))

static func _candle(b: B, v: int) -> void:
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.12, 0.015), Vector2(0.1, 0.035), Vector2(0.0, 0.03)], 12, BRASS)
	b.m = MATTE
	b.lathe([Vector2(0.04, 0.03), Vector2(0.04, 0.38), Vector2(0.034, 0.395), Vector2(0.0, 0.39)], 10, WAX, Vector3.ZERO, 0.0, 0.12, true)
	b.ellipsoid(Vector3(0.036, 0.3, 0.012), Vector3(0.012, 0.07, 0.012), B.sh(WAX, 1.0), 6, 4)
	b.ellipsoid(Vector3(-0.025, 0.2, 0.03), Vector3(0.012, 0.05, 0.012), B.sh(WAX, 0.97), 6, 4)
	b.lathe([Vector2(0.0, 0.03), Vector2(0.075, 0.03), Vector2(0.06, 0.05), Vector2(0.0, 0.06)], 10, WAX, Vector3.ZERO)
	b.box(Vector3(0, 0.4, 0), Vector3(0.004, 0.02, 0.004), Color("20180f"))

static func _brazier(b: B, gold: bool) -> void:
	var met := GOLD if gold else IRON
	var met2 := B.sh(met, 0.78)
	b.m = METAL
	# pied rond, balustre à bagues, coupe évasée à bord roulé
	b.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.035), Vector2(0.24, 0.06), Vector2(0.11, 0.1), Vector2(0.07, 0.16), Vector2(0.1, 0.24),
		Vector2(0.065, 0.3), Vector2(0.06, 0.52), Vector2(0.105, 0.58), Vector2(0.065, 0.64), Vector2(0.07, 0.72), Vector2(0.17, 0.78), Vector2(0.3, 0.86),
		Vector2(0.38, 0.96), Vector2(0.4, 1.0), Vector2(0.37, 1.0), Vector2(0.33, 0.94), Vector2(0.22, 0.86), Vector2(0.0, 0.82)], 18, met, Vector3.ZERO, 0.0, 0.0, true)
	b.hoop(0.385, 0.985, 0.05, 0.025, met2, 18)
	b.hoop(0.28, 0.835, 0.03, 0.02, met2, 16)
	b.m = GLOW
	b.lathe([Vector2(0.0, 0.93), Vector2(0.27, 0.92), Vector2(0.31, 0.95), Vector2(0.22, 1.02), Vector2(0.0, 1.04)], 12, Color("ff8a30"), Vector3.ZERO, 0.0, 0.3)
	b.m = MATTE
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		b.rock(Vector3(sin(a) * 0.19, 1.0, cos(a) * 0.19), Vector3(0.075, 0.05, 0.06), k + 5, Color("1c1814"))

static func _bookshelf(b: B, v: int) -> void:
	var w := 1.7
	var d := 0.4
	var hh := 2.5
	var back := B.sh(DARK_WOOD, 0.8)
	b.box(Vector3(0, hh * 0.5, -d * 0.5 + 0.02), Vector3(w * 0.5, hh * 0.5, 0.02), back)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (w * 0.5 - 0.035), hh * 0.5, 0.0), Vector3(0.035, hh * 0.5, d * 0.5), DARK_WOOD)
	b.box(Vector3(0, 0.07, 0.01), Vector3(w * 0.5 + 0.02, 0.07, d * 0.5 + 0.02), B.sh(DARK_WOOD, 0.9))
	b.box(Vector3(0, hh - 0.05, 0.01), Vector3(w * 0.5 + 0.03, 0.05, d * 0.5 + 0.03), DARK_WOOD)
	b.box(Vector3(0, hh + 0.02, 0.0), Vector3(w * 0.5 + 0.05, 0.025, d * 0.5 + 0.05), B.sh(WOOD, 0.9))
	var palette := [Color("7a2a2a"), Color("2a4a6a"), Color("3a5a2a"), Color("6a4a22"), Color("4a2a5a"), Color("8a6a2a"), Color("2f2f36"), Color("7a3a1a")]
	var levels := [0.16, 0.7, 1.24, 1.78]
	for li in levels.size():
		var y: float = levels[li]
		b.box(Vector3(0, y - 0.025, 0.0), Vector3(w * 0.5 - 0.07, 0.025, d * 0.5 - 0.005), WOOD)
		var x := -w * 0.5 + 0.1
		var idx := v * 100 + li * 20
		var limit := w * 0.5 - 0.1
		while x < limit - 0.04:
			idx += 1
			var r := B.h(idx, v, li)
			if r < 0.07 and x < limit - 0.45:
				# pile de livres à plat
				var hy := 0.0
				for k in 3:
					var bw := 0.3 + B.h(idx, k, 4) * 0.08
					b.box(Vector3(x + 0.19, y + hy + 0.025, 0.0), Vector3(bw * 0.5, 0.025, 0.12), B.jit(palette[(idx + k) % 8], 0.15, idx + k))
					hy += 0.05
				x += 0.4
				continue
			if r > 0.93:
				x += 0.1          # vide
				continue
			var bw := 0.035 + B.h(idx, 2, 3) * 0.05
			var bh := 0.26 + B.h(idx, 5, 3) * 0.17
			var col: Color = B.jit(palette[int(B.h(idx, 7, 3) * 8.0) % 8], 0.2, idx)
			var lean := 0.0
			if B.h(idx, 9, 3) < 0.08:
				lean = 0.22
			var o := b.push(Transform3D(Basis(Vector3(0, 0, 1), lean), Vector3(x + bw * 0.5, y, 0.02)))
			b.box(Vector3(0, bh * 0.5, 0), Vector3(bw * 0.5, bh * 0.5, 0.12), col)
			b.box(Vector3(0, bh * 0.5, 0.123), Vector3(bw * 0.5 + 0.001, bh * 0.5 - 0.005, 0.004), B.sh(col, 1.15))
			b.m = METAL
			b.box(Vector3(0, bh - 0.04, 0.127), Vector3(bw * 0.5 + 0.001, 0.005, 0.002), GOLD)
			b.box(Vector3(0, 0.05, 0.127), Vector3(bw * 0.5 + 0.001, 0.005, 0.002), GOLD)
			b.m = MATTE
			b.xf = o
			x += bw + (0.0 if lean == 0.0 else 0.04)

# ------------------------------------------------------------------ armes, boucliers, mannequin

static func _sword(b: B, ln: float, blade := Color("c4c8d0")) -> void:
	# origine : pommeau ; la lame monte le long de +Y, face vers +Z
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.024, 0.008), Vector2(0.02, 0.03), Vector2(0.0, 0.034)], 8, BRASS)
	b.frustum(Vector3(0, 0.03, 0), Vector3(0, 0.2, 0), 0.016, 0.014, 6, DARK_WOOD, false)
	b.box(Vector3(0, 0.212, 0), Vector3(0.11, 0.011, 0.015), BRASS)
	var y0 := 0.23 + ln
	b.box(Vector3(0, 0.23 + ln * 0.5, 0), Vector3(0.026, ln * 0.5, 0.005), blade)
	b.box(Vector3(0, 0.23 + ln * 0.5, 0.0052), Vector3(0.005, ln * 0.45, 0.001), B.sh(blade, 0.7))
	b.tri_flat(Vector3(-0.026, y0, 0.005), Vector3(0.026, y0, 0.005), Vector3(0, y0 + 0.08, 0.0), Vector3(0, 0, 1), blade, blade, blade)
	b.tri_flat(Vector3(-0.026, y0, -0.005), Vector3(0.026, y0, -0.005), Vector3(0, y0 + 0.08, 0.0), Vector3(0, 0, -1), blade, blade, blade)
	b.m = MATTE

static func _spear(b: B, y0: float, y1: float, x: float, z: float, lean: float) -> void:
	var o := b.push(Transform3D(Basis(Vector3(0, 0, 1), lean), Vector3(x, y0, z)))
	var ln := y1 - y0
	b.frustum(Vector3.ZERO, Vector3(0, ln, 0), 0.02, 0.017, 6, B.jit(WOOD, 0.1, int(x * 100)), false)
	b.m = METAL
	b.frustum(Vector3(0, ln - 0.01, 0), Vector3(0, ln + 0.05, 0), 0.026, 0.02, 7, IRON_L, false)
	b.ellipsoid(Vector3(0, ln + 0.17, 0), Vector3(0.045, 0.14, 0.01), Color("bfc3cc"), 8, 6)
	b.m = MATTE
	b.ellipsoid(Vector3(0.0, ln - 0.1, 0.0), Vector3(0.03, 0.06, 0.03), CLOTH_R, 6, 4)
	b.xf = o

static func _weapon_rack(b: B, v: int) -> void:
	for sx in [-0.8, 0.8]:
		b.box(Vector3(sx, 0.95, -0.1), Vector3(0.05, 0.95, 0.04), DARK_WOOD)
		b.box(Vector3(sx, 1.93, -0.1), Vector3(0.07, 0.03, 0.05), WOOD)
	if v == 0:
		for y in [0.55, 1.35]:
			b.box(Vector3(0, y, -0.04), Vector3(0.82, 0.04, 0.04), WOOD)
		for k in 4:
			_spear(b, 0.05, 1.85 + 0.12 * (k % 2), -0.55 + 0.37 * k, 0.03 + 0.02 * (k % 2), 0.02 * (1 - k % 2 * 2))
	else:
		b.box(Vector3(0, 1.0, -0.12), Vector3(0.78, 0.55, 0.02), B.sh(DARK_WOOD, 0.85))
		for k in 3:
			var y := 0.62 + 0.38 * k
			for sx in [-0.62, 0.62]:
				b.box(Vector3(sx, y - 0.03, 0.0), Vector3(0.025, 0.025, 0.1), WOOD)
			var o := b.push(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.62 + 0.05 * (k % 2), y, 0.05)))
			_sword(b, 0.7 - 0.05 * k)
			b.xf = o

static func _shield_wall(b: B, v: int) -> void:
	# origine : plan du mur, au centre ; deux épées croisées derrière le bouclier
	for sg in [-1.0, 1.0]:
		var o := b.push(Transform3D(Basis(Vector3(0, 0, 1), sg * 0.75), Vector3(-sg * 0.42, -0.45, 0.04)))
		_sword(b, 0.72)
		b.xf = o
	var o2 := b.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.07)))
	if v == 0:
		b.lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.0), Vector2(0.4, 0.03), Vector2(0.3, 0.05), Vector2(0.16, 0.065), Vector2(0.0, 0.07)], 16, CLOTH_R, Vector3.ZERO, 0.0, 0.0, false, 1.0, 1.0, CLOTH_C)
		b.m = METAL
		b.hoop(0.385, 0.015, 0.06, 0.03, IRON, 24)
		b.lathe([Vector2(0.0, 0.1), Vector2(0.09, 0.07), Vector2(0.08, 0.1), Vector2(0.0, 0.14)], 12, IRON_L)
		for k in 8:
			var a := TAU * float(k) / 8.0 + 0.2
			b.ellipsoid(Vector3(sin(a) * 0.3, 0.052, cos(a) * 0.3), Vector3(0.018, 0.012, 0.018), BRASS, 6, 3)
		b.m = MATTE
	b.xf = o2
	if v == 1:
		# bouclier en amande : haut rectangulaire, bas en pointe, croix dorée
		var cs := Color("2a4a7a")
		b.box(Vector3(0, 0.12, 0.08), Vector3(0.34, 0.26, 0.025), cs)
		b.tri_flat(Vector3(-0.34, -0.14, 0.105), Vector3(0.34, -0.14, 0.105), Vector3(0, -0.62, 0.105), Vector3(0, 0, 1), cs, cs, cs)
		b.tri_flat(Vector3(-0.34, -0.14, 0.055), Vector3(0.34, -0.14, 0.055), Vector3(0, -0.62, 0.055), Vector3(0, 0, -1), cs, cs, cs)
		b.m = METAL
		b.box(Vector3(0, 0.0, 0.112), Vector3(0.05, 0.36, 0.006), GOLD)
		b.box(Vector3(0, 0.12, 0.112), Vector3(0.28, 0.045, 0.006), GOLD)
		b.box(Vector3(0, 0.12, 0.08), Vector3(0.36, 0.28, 0.02), B.sh(IRON, 0.8))
		b.m = MATTE

static func _dummy(b: B) -> void:
	b.box(Vector3(0, 0.05, 0), Vector3(0.45, 0.05, 0.08), DARK_WOOD)
	b.box(Vector3(0, 0.05, 0), Vector3(0.08, 0.05, 0.45), DARK_WOOD)
	b.frustum(Vector3(0, 0.1, 0), Vector3(0, 1.75, 0), 0.06, 0.055, 8, WOOD, false)
	b.box(Vector3(0, 1.3, 0), Vector3(0.55, 0.05, 0.05), WOOD)
	b.lathe([Vector2(0.0, 0.7), Vector2(0.2, 0.72), Vector2(0.24, 1.0), Vector2(0.23, 1.3), Vector2(0.14, 1.42), Vector2(0.0, 1.43)], 12, STRAW, Vector3.ZERO, 0.05, 0.1, true, 1.0, 0.75)
	b.m = METAL
	b.hoop(0.2, 0.98, 0.04, 0.045, IRON, 12)
	b.m = MATTE
	b.ellipsoid(Vector3(0, 1.58, 0), Vector3(0.15, 0.17, 0.15), B.sh(SACK, 1.05), 10, 6, 0.08, 4)
	b.m = METAL
	b.lathe([Vector2(0.17, 1.52), Vector2(0.17, 1.62), Vector2(0.13, 1.74), Vector2(0.0, 1.8)], 10, IRON_L, Vector3.ZERO, 0.0, 0.0, true)
	b.m = MATTE
	var o := b.push(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.5, 1.15, 0.1)))
	b.lathe([Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.28, 0.03), Vector2(0.0, 0.06)], 14, WOOD, Vector3.ZERO, 0.0, 0.0, false, 1.0, 1.0, CLOTH_R)
	b.xf = o
	_sword(b, 0.5)

# ------------------------------------------------------------------ autel, chandeliers

static func _altar(b: B) -> void:
	b.box(Vector3(0, 0.06, 0), Vector3(1.4, 0.06, 1.4), STONE_D)
	b.box(Vector3(0, 0.17, 0), Vector3(1.15, 0.05, 1.0), B.sh(STONE, 0.95))
	var y := 0.22
	b.box(Vector3(0, y + 0.06, 0), Vector3(0.82, 0.06, 0.42), B.sh(STONE, 0.9))
	b.box(Vector3(0, y + 0.5, 0), Vector3(0.74, 0.38, 0.34), STONE)
	for k in 3:
		b.box(Vector3(-0.46 + 0.46 * k, y + 0.5, 0.345), Vector3(0.17, 0.27, 0.012), B.sh(STONE_D, 0.8))
	b.box(Vector3(0, y + 0.9, 0), Vector3(0.84, 0.05, 0.44), B.sh(STONE, 1.0))
	b.box(Vector3(0, y + 0.97, 0), Vector3(0.89, 0.04, 0.48), Color("dcd8d0"))
	b.box(Vector3(0, y + 1.0, 0), Vector3(0.22, 0.012, 0.5), CLOTH_R)
	b.box(Vector3(0, y + 0.72, 0.5), Vector3(0.22, 0.3, 0.012), CLOTH_R)
	b.box(Vector3(0, y + 0.72, -0.5), Vector3(0.22, 0.3, 0.012), CLOTH_R)
	b.m = METAL
	b.box(Vector3(0, y + 0.43, 0.512), Vector3(0.22, 0.012, 0.004), GOLD)
	b.box(Vector3(0, y + 0.43, -0.512), Vector3(0.22, 0.012, 0.004), GOLD)
	b.box(Vector3(0, y + 0.5, 0.36), Vector3(0.012, 0.1, 0.006), GOLD)
	b.box(Vector3(0, y + 0.54, 0.36), Vector3(0.05, 0.012, 0.006), GOLD)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.025, 0.04), Vector2(0.02, 0.1), Vector2(0.06, 0.14), Vector2(0.075, 0.2), Vector2(0.06, 0.24), Vector2(0.0, 0.22)], 12, GOLD, Vector3(-0.42, y + 1.02, 0.0), 0.0, 0.0, true)
	b.m = MATTE
	b.rbox(Vector3(0.42, y + 1.03, 0.0), Vector3(0.11, 0.012, 0.08), Color("e9dfc0"), Basis(Vector3(0, 0, 1), 0.0))
	b.rbox(Vector3(0.42, y + 1.01, 0.0), Vector3(0.12, 0.012, 0.09), CLOTH_R, Basis())

const CANDELABRA_FLAMES := [Vector3(-0.24, 1.36, 0.0), Vector3(0.0, 1.5, 0.0), Vector3(0.24, 1.36, 0.0)]

static func _candelabra(b: B) -> void:
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.03), Vector2(0.12, 0.07), Vector2(0.05, 0.14), Vector2(0.035, 0.3), Vector2(0.07, 0.38), Vector2(0.035, 0.46),
		Vector2(0.03, 0.9), Vector2(0.06, 0.96), Vector2(0.03, 1.02), Vector2(0.03, 1.2), Vector2(0.0, 1.2)], 12, BRASS, Vector3.ZERO, 0.0, 0.0, true)
	for sx in [-1.0, 1.0]:
		b.frustum(Vector3(0, 1.02, 0), Vector3(sx * 0.12, 1.1, 0), 0.016, 0.016, 5, BRASS, false)
		b.frustum(Vector3(sx * 0.12, 1.1, 0), Vector3(sx * 0.24, 1.18, 0), 0.016, 0.016, 5, BRASS, false)
		b.frustum(Vector3(sx * 0.24, 1.18, 0), Vector3(sx * 0.24, 1.22, 0), 0.016, 0.016, 5, BRASS, false)
		b.lathe([Vector2(0.0, 1.2), Vector2(0.065, 1.2), Vector2(0.05, 1.23), Vector2(0.0, 1.23)], 8, BRASS, Vector3(sx * 0.24, 0, 0))
	b.lathe([Vector2(0.0, 1.2), Vector2(0.065, 1.2), Vector2(0.05, 1.23), Vector2(0.0, 1.23)], 8, BRASS, Vector3(0, 0.0, 0))
	b.m = MATTE
	var tops := [1.32, 1.46, 1.32]
	for k in 3:
		var x := -0.24 + 0.24 * k
		var y0 := 1.23 if k != 1 else 1.23
		if k == 1:
			b.frustum(Vector3(0, 1.2, 0), Vector3(0, 1.23, 0), 0.03, 0.03, 6, BRASS, false)
		b.lathe([Vector2(0.032, y0), Vector2(0.032, float(tops[k])), Vector2(0.0, float(tops[k]) + 0.005)], 8, WAX, Vector3(x, 0, 0), 0.0, 0.1, true)

static func _sconce(b: B) -> void:
	# origine : plan du mur ; la flamme se pose en (0, 0.3, 0.27)
	b.m = METAL
	b.box(Vector3(0, 0, 0.012), Vector3(0.05, 0.14, 0.012), IRON)
	for sy in [-1.0, 1.0]:
		b.ellipsoid(Vector3(0.0, sy * 0.1, 0.028), Vector3(0.012, 0.012, 0.008), IRON_L, 6, 3)
	b.frustum(Vector3(0, -0.02, 0.02), Vector3(0, -0.02, 0.2), 0.014, 0.012, 6, IRON, false)
	b.frustum(Vector3(0, -0.12, 0.03), Vector3(0, -0.02, 0.17), 0.01, 0.01, 5, IRON, false)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.075, 0.05), Vector2(0.065, 0.06), Vector2(0.0, 0.03)], 10, IRON, Vector3(0, -0.02, 0.24), 0.0, 0.0, true)
	b.m = MATTE
	b.lathe([Vector2(0.034, 0.02), Vector2(0.034, 0.26), Vector2(0.0, 0.265)], 8, WAX, Vector3(0, -0.02, 0.24), 0.0, 0.1, true)

# ------------------------------------------------------------------ ruines

static func _rock(b: B, v: int) -> void:
	b.rock(Vector3(0, 0.16, 0), Vector3(0.28 + 0.05 * v, 0.17 + 0.03 * v, 0.24), 20 + v, B.jit(STONE, 0.12, v))

static func _rubble(b: B, v: int) -> void:
	var n := 7
	for i in n:
		var a := B.h(i, v, 31) * TAU
		var r := 0.12 + B.h(i, v, 32) * 0.4
		var s := 0.1 + B.h(i, v, 33) * 0.2
		if i == 0:
			r = 0.0
			s = 0.3
		b.rock(Vector3(sin(a) * r, s * 0.6, cos(a) * r), Vector3(s * 1.1, s * 0.75, s), v * 10 + i, B.jit(STONE if i % 2 == 0 else STONE_D, 0.12, i + v))
	for i in 5:
		var a := B.h(i, v, 41) * TAU
		var r := 0.3 + B.h(i, v, 42) * 0.35
		b.rock(Vector3(sin(a) * r, 0.03, cos(a) * r), Vector3(0.05, 0.03, 0.045), i + 70, B.sh(STONE_D, 0.9))
	b.rbox(Vector3(0.1, 0.05, 0.25), Vector3(0.2, 0.025, 0.14), B.sh(STONE, 0.85), Basis(Vector3.UP, 0.5 + v) * Basis(Vector3.RIGHT, 0.12))

static func _column_stump(b: B) -> void:
	b.box(Vector3(0, 0.08, 0), Vector3(0.4, 0.08, 0.4), STONE_D)
	b.lathe([Vector2(0.0, 0.16), Vector2(0.31, 0.16), Vector2(0.33, 0.2), Vector2(0.28, 0.25), Vector2(0.27, 1.25), Vector2(0.25, 1.3), Vector2(0.0, 1.3)], 14, STONE, Vector3.ZERO, 0.07, 0.0, false)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var h := 0.18 + B.h(k, 2, 9) * 0.18
		b.rbox(Vector3(sin(a) * 0.15, 1.3 + h * 0.4, cos(a) * 0.15), Vector3(0.1, h * 0.5, 0.07), B.jit(STONE, 0.1, k), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.2))
	for k in 4:
		var a := TAU * float(k) / 4.0 + 1.0
		b.rock(Vector3(sin(a) * 0.5, 0.1, cos(a) * 0.5), Vector3(0.12, 0.09, 0.1), k + 3, STONE_D)

static func _column_fallen(b: B) -> void:
	var o := b.push(Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(-0.9, 0.29, 0)))
	b.lathe([Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.29, 0.1), Vector2(0.27, 0.16), Vector2(0.27, 1.5), Vector2(0.255, 1.55), Vector2(0.0, 1.55)], 14, STONE, Vector3.ZERO, 0.07, 0.0, false)
	b.xf = o
	for k in 3:
		b.rbox(Vector3(0.95, 0.12 + k * 0.05, -0.1 + k * 0.1), Vector3(0.1, 0.1, 0.12), B.jit(STONE, 0.1, k), Basis(Vector3.UP, k * 1.3))
	b.rock(Vector3(1.05, 0.12, 0.25), Vector3(0.18, 0.1, 0.14), 4, STONE_D)
	b.rock(Vector3(-1.05, 0.08, 0.2), Vector3(0.14, 0.07, 0.1), 5, STONE_D)

# ------------------------------------------------------------------ salle commune

static func _leg(b: B, x: float, z: float, h: float, r: float) -> void:
	b.lathe([Vector2(r * 0.8, 0.0), Vector2(r * 0.8, h * 0.1), Vector2(r * 1.3, h * 0.2), Vector2(r, h * 0.3), Vector2(r, h * 0.8), Vector2(r * 1.25, h * 0.88), Vector2(r * 1.25, h)], 8, DARK_WOOD, Vector3(x, 0, z), 0.0, 0.0, true)

static func _table(b: B, w: float, d: float) -> void:
	var n := int(d / 0.16)
	var pw := d / n
	for i in n:
		b.box(Vector3(0, 0.78, -d * 0.5 + pw * (i + 0.5)), Vector3(w * 0.5, 0.04, pw * 0.5 - 0.004), B.jit(WOOD, 0.1, i + 3))
	b.box(Vector3(0, 0.7, d * 0.5 - 0.06), Vector3(w * 0.5 - 0.1, 0.05, 0.025), DARK_WOOD)
	b.box(Vector3(0, 0.7, -d * 0.5 + 0.06), Vector3(w * 0.5 - 0.1, 0.05, 0.025), DARK_WOOD)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(b, sx * (w * 0.5 - 0.14), sz * (d * 0.5 - 0.1), 0.74, 0.05)
		b.box(Vector3(sx * (w * 0.5 - 0.14), 0.22, 0), Vector3(0.025, 0.025, d * 0.5 - 0.1), DARK_WOOD)
	b.box(Vector3(0, 0.22, 0), Vector3(w * 0.5 - 0.14, 0.022, 0.022), DARK_WOOD)

static func _bench(b: B) -> void:
	b.box(Vector3(0, 0.44, 0), Vector3(1.5, 0.03, 0.15), B.jit(WOOD, 0.1, 5))
	b.box(Vector3(0, 0.41, 0), Vector3(1.4, 0.03, 0.1), DARK_WOOD)
	for sx in [-1.0, 1.0]:
		b.rbox(Vector3(sx * 1.2, 0.2, 0.0), Vector3(0.028, 0.22, 0.12), DARK_WOOD, Basis(Vector3(0, 0, 1), sx * 0.09))

static func _stool(b: B) -> void:
	b.lathe([Vector2(0.0, 0.42), Vector2(0.2, 0.42), Vector2(0.21, 0.45), Vector2(0.2, 0.47), Vector2(0.0, 0.47)], 12, B.sh(WOOD, 1.05))
	for k in 3:
		var a := TAU * float(k) / 3.0
		b.frustum(Vector3(sin(a) * 0.19, 0.42, cos(a) * 0.19), Vector3(sin(a) * 0.26, 0.0, cos(a) * 0.26), 0.025, 0.02, 6, DARK_WOOD, false)

static func _tableware(b: B) -> void:
	var y := 0.82
	b.m = METAL
	for x in [-1.05, 0.15]:
		b.lathe([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.05, 0.12), Vector2(0.052, 0.13), Vector2(0.0, 0.13)], 10, Color("a8a8ae"), Vector3(x, y, 0.1), 0.0, 0.0, true)
		b.hoop(0.049, y + 0.1, 0.012, 0.004, IRON_L, 10)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.15, 0.015), Vector2(0.0, 0.01)], 14, Color("b5b5bb"), Vector3(-0.55, y, -0.12))
	b.lathe([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.15, 0.015), Vector2(0.0, 0.01)], 14, Color("b5b5bb"), Vector3(0.7, y, 0.12))
	b.m = MATTE
	b.ellipsoid(Vector3(-0.55, y + 0.06, -0.12), Vector3(0.1, 0.055, 0.06), Color("b57a3a"), 10, 5)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.09, 0.05), Vector2(0.0, 0.05)], 12, Color("d8b84a"), Vector3(0.7, y + 0.015, 0.12), 0.05)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.14), Vector2(0.02, 0.22), Vector2(0.02, 0.3), Vector2(0.0, 0.3)], 10, Color("2c4a2e"), Vector3(-0.2, y, -0.15), 0.0, 0.0, true)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.045, 0.1), Vector2(0.0, 0.1)], 8, DARK_WOOD, Vector3(1.05, y, -0.1))
	b.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.12), Vector2(0.02, 0.2), Vector2(0.02, 0.26), Vector2(0.0, 0.26)], 10, Color("5a2a2a"), Vector3(0.45, y, -0.18), 0.0, 0.0, true)

static func _fireplace(b: B) -> void:
	var sd := 0.3
	b.box(Vector3(0, 0.08, 0), Vector3(1.0, 0.08, 0.3), STONE_D)
	for sx in [-1.0, 1.0]:
		for k in 5:
			b.box(Vector3(sx * 0.78, 0.35 + k * 0.28, 0.0), Vector3(0.22, 0.14, sd - 0.005), B.jit(STONE if k % 2 == 0 else STONE_D, 0.12, k + int(sx)))
	b.box(Vector3(0, 1.45, 0.0), Vector3(1.0, 0.16, sd), STONE)
	for k in 5:
		b.box(Vector3(-0.8 + 0.4 * k, 1.42, sd + 0.01), Vector3(0.19, 0.13, 0.012), B.jit(STONE, 0.1, k + 9))
	b.box(Vector3(0, 1.78, 0.04), Vector3(1.1, 0.07, 0.36), B.sh(STONE, 1.05))
	b.box(Vector3(0, 2.2, -0.02), Vector3(0.78, 0.4, 0.24), STONE_D)
	b.box(Vector3(0, 0.95, -0.2), Vector3(0.56, 0.9, 0.06), Color("120f0d"))
	b.box(Vector3(0, 0.06, 0.55), Vector3(0.85, 0.05, 0.3), STONE)
	b.m = GLOW
	b.lathe([Vector2(0.0, 0.14), Vector2(0.4, 0.14), Vector2(0.38, 0.2), Vector2(0.0, 0.24)], 10, Color("ff6a1a"), Vector3(0, 0, 0.0), 0.0, 0.3)
	b.m = MATTE
	b.rbox(Vector3(0, 0.2, 0.05), Vector3(0.45, 0.07, 0.07), Color("3b2412"), Basis(Vector3.UP, 0.2))
	b.rbox(Vector3(0, 0.2, 0.0), Vector3(0.42, 0.07, 0.07), Color("2d1b0e"), Basis(Vector3.UP, -0.5))
	b.rbox(Vector3(0, 0.3, 0.02), Vector3(0.36, 0.06, 0.06), Color("3b2412"), Basis(Vector3.UP, 1.4))
	b.m = METAL
	b.box(Vector3(-0.45, 0.2, 0.18), Vector3(0.025, 0.12, 0.025), IRON)
	b.box(Vector3(0.45, 0.2, 0.18), Vector3(0.025, 0.12, 0.025), IRON)
	b.box(Vector3(0, 0.3, 0.18), Vector3(0.46, 0.02, 0.02), IRON)
	b.m = MATTE

# ------------------------------------------------------------------ grotte

static func _stalagmite(b: B, v: int, hang: bool) -> void:
	var ht := 0.85 + 0.35 * v
	var prof: Array = []
	var n := 9
	for i in n + 1:
		var t := float(i) / n
		var r := 0.22 * pow(1.0 - t, 0.8) * (1.0 + 0.15 * sin(t * 18.0 + v)) + 0.01
		prof.append(Vector2(r, t * ht))
	prof.append(Vector2(0.0, ht))
	var o := b.xf
	if hang:
		b.xf = b.xf * Transform3D(Basis.from_scale(Vector3(1, -1, 1)), Vector3(0, ht, 0))
	b.lathe(prof, 9, B.jit(Color("6b6a66"), 0.1, v), Vector3.ZERO, 0.06, 0.3, true)
	b.ellipsoid(Vector3(0.2, 0.05, 0.1), Vector3(0.08, 0.06, 0.07), B.sh(STONE_D, 0.9), 6, 3, 0.3, v, true)
	b.xf = o

static func _mushrooms(b: B, v: int) -> void:
	for k in 4:
		var a := B.h(k, v, 61) * TAU
		var r := 0.05 + B.h(k, v, 62) * 0.18
		var x := sin(a) * r
		var z := cos(a) * r
		var s := 0.6 + B.h(k, v, 63) * 0.7
		b.frustum(Vector3(x, 0, z), Vector3(x, 0.12 * s, z), 0.022 * s, 0.014 * s, 6, Color("d9d2b8"), false)
		b.m = GLOW
		b.lathe([Vector2(0.0, 0.0), Vector2(0.08 * s, 0.0), Vector2(0.075 * s, 0.03 * s), Vector2(0.05 * s, 0.06 * s), Vector2(0.0, 0.08 * s)], 10, Color("5affb0"), Vector3(x, 0.115 * s, z), 0.1, 0.0, true)
		b.m = MATTE

# ------------------------------------------------------------------ trésor

static func _coin(b: B, p: Vector3, tilt: Vector3, r := 0.05) -> void:
	var o := b.push(Transform3D(Basis.from_euler(tilt), p))
	b.lathe([Vector2(0.0, 0.0), Vector2(r, 0.0), Vector2(r, 0.008), Vector2(r * 0.85, 0.01), Vector2(0.0, 0.01)], 10, B.jit(GOLD, 0.12, int(p.x * 997 + p.z * 31)))
	b.xf = o

static func _gold_mound(b: B, rad: float, ht: float, v: int, ncoin: int) -> void:
	b.m = METAL
	var prof: Array = []
	var steps := [[1.0, 0.0], [0.94, 0.12], [0.8, 0.32], [0.6, 0.55], [0.38, 0.78], [0.16, 0.94], [0.0, 1.0]]
	for p in steps:
		prof.append(Vector2(rad * float(p[0]), ht * float(p[1])))
	b.lathe(prof, 20, B.sh(GOLD, 1.0), Vector3.ZERO, 0.03, 0.45, true)
	for i in ncoin:
		var a := B.h(i, v, 71) * TAU
		var t := sqrt(B.h(i, v, 72)) * 0.85
		var r := rad * t
		var y := ht * (1.0 - t) * 0.92 + 0.01
		_coin(b, Vector3(sin(a) * r, y, cos(a) * r), Vector3((B.h(i, v, 73) - 0.5) * 1.2, B.h(i, v, 74) * TAU, (B.h(i, v, 75) - 0.5) * 1.2), (0.04 + 0.025 * B.h(i, v, 76)) * (1.0 + rad * 0.5))
	var gems := [Color("c02a3a"), Color("2a6ac0"), Color("2ac07a")]
	for i in 3:
		var a := B.h(i, v, 81) * TAU
		var t := 0.2 + B.h(i, v, 82) * 0.4
		b.ellipsoid(Vector3(sin(a) * rad * t, ht * (1.0 - t) * 0.95 + 0.025, cos(a) * rad * t), Vector3(0.04, 0.035, 0.04), gems[i], 6, 3, 0.0, i, true)
	b.m = MATTE

static func _bars(b: B, p: Vector3, yaw: float) -> void:
	b.m = METAL
	var o := b.push(Transform3D(Basis(Vector3.UP, yaw), p))
	for lv in 3:
		for k in (3 - lv):
			b.box(Vector3(-0.1 * (2 - lv) + 0.2 * k, 0.04 + lv * 0.08, 0), Vector3(0.095, 0.04, 0.045), B.jit(GOLD, 0.1, lv * 5 + k))
	b.xf = o
	b.m = MATTE

static func _goblet(b: B, p: Vector3) -> void:
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.06, 0.02), Vector2(0.02, 0.05), Vector2(0.018, 0.12), Vector2(0.06, 0.16), Vector2(0.075, 0.24), Vector2(0.06, 0.24), Vector2(0.0, 0.18)], 12, GOLD, p, 0.0, 0.0, true)
	b.m = MATTE

static func _vase(b: B, v: int) -> void:
	var clay := Color("a8532e")
	var band := Color("e6c47a")
	if v == 0:
		b.lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.14, 0.1), Vector2(0.24, 0.3), Vector2(0.26, 0.48), Vector2(0.22, 0.68), Vector2(0.12, 0.82), Vector2(0.09, 0.9), Vector2(0.12, 0.94), Vector2(0.115, 0.98), Vector2(0.09, 0.96)], 14, clay, Vector3.ZERO, 0.0, 0.0, true)
		b.hoop(0.255, 0.5, 0.05, 0.006, band, 14)
		b.hoop(0.19, 0.72, 0.03, 0.006, band, 14)
		for sx in [-1.0, 1.0]:
			b.frustum(Vector3(sx * 0.09, 0.86, 0), Vector3(sx * 0.2, 0.84, 0), 0.025, 0.025, 6, clay, false)
			b.frustum(Vector3(sx * 0.2, 0.84, 0), Vector3(sx * 0.25, 0.66, 0), 0.025, 0.025, 6, clay, false)
	else:
		b.lathe([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.2, 0.1), Vector2(0.3, 0.3), Vector2(0.3, 0.45), Vector2(0.22, 0.6), Vector2(0.14, 0.64), Vector2(0.15, 0.68), Vector2(0.0, 0.7)], 14, Color("5a6a8a"), Vector3.ZERO, 0.0, 0.0, true)
		b.hoop(0.295, 0.38, 0.05, 0.006, band, 14)
		b.lathe([Vector2(0.0, 0.64), Vector2(0.1, 0.66), Vector2(0.12, 0.72), Vector2(0.04, 0.8), Vector2(0.04, 0.84), Vector2(0.0, 0.84)], 10, Color("5a6a8a"), Vector3.ZERO, 0.0, 0.0, true)

# ------------------------------------------------------------------ repaire

static func _bone(b: B, a: Vector3, bp: Vector3, r: float) -> void:
	b.frustum(a, bp, r, r * 0.8, 6, BONE, false)
	for e in [a, bp]:
		for sd in [-1.0, 1.0]:
			b.ellipsoid(e + Vector3(sd * r * 0.8, 0, 0), Vector3(r * 1.25, r * 1.1, r * 1.2), BONE, 6, 4)

static func _skull(b: B, p: Vector3, yaw: float) -> void:
	var o := b.push(Transform3D(Basis(Vector3.UP, yaw), p))
	b.ellipsoid(Vector3(0, 0.1, 0), Vector3(0.095, 0.095, 0.11), BONE, 10, 7)
	b.ellipsoid(Vector3(0, 0.045, 0.06), Vector3(0.06, 0.04, 0.06), B.sh(BONE, 0.97), 8, 5)
	b.ellipsoid(Vector3(-0.036, 0.105, 0.085), Vector3(0.026, 0.03, 0.02), Color("120d0a"), 8, 5)
	b.ellipsoid(Vector3(0.036, 0.105, 0.085), Vector3(0.026, 0.03, 0.02), Color("120d0a"), 8, 5)
	b.ellipsoid(Vector3(0, 0.07, 0.1), Vector3(0.012, 0.018, 0.012), Color("120d0a"), 6, 4)
	for k in 6:
		b.box(Vector3(-0.025 + 0.01 * k, 0.03, 0.105), Vector3(0.004, 0.009, 0.004), B.sh(BONE, 1.05))
	b.xf = o

static func _bones(b: B, v: int) -> void:
	var n := 5 + v
	for i in n:
		var a := B.h(i, v, 91) * TAU
		var r := 0.05 + B.h(i, v, 92) * 0.4
		var p := Vector3(sin(a) * r, 0.03, cos(a) * r)
		var ln := 0.3 + B.h(i, v, 93) * 0.3
		var yaw := B.h(i, v, 94) * TAU
		var d := Vector3(sin(yaw), 0.0, cos(yaw)) * ln * 0.5
		_bone(b, p - d, p + d, 0.024)
	_skull(b, Vector3(0.05, 0.0, 0.0) + Vector3(0.15, 0, 0.1) * float(v), B.h(v, 4, 95) * TAU)
	if v >= 1:
		for k in 5:
			var o := b.push(Transform3D(Basis(Vector3.UP, 1.2) * Basis(Vector3.RIGHT, 0.0), Vector3(-0.35, 0.0, -0.2 + 0.07 * k)))
			var prev := Vector3(0, 0.02, 0)
			for sgm in 7:
				var t := float(sgm + 1) / 7.0
				var q := Vector3(sin(t * PI) * 0.16, 0.02 + (1.0 - cos(t * PI)) * 0.1 * 0.5, -t * 0.0 + (1.0 - cos(t * PI)) * 0.12)
				b.frustum(prev, q, 0.01, 0.009, 5, BONE, false)
				prev = q
			b.xf = o

static func _wall_chains(b: B) -> void:
	b.m = METAL
	b.box(Vector3(0, 0, 0.012), Vector3(0.28, 0.07, 0.012), IRON)
	for sx in [-0.2, 0.2]:
		b.ellipsoid(Vector3(sx, 0, 0.03), Vector3(0.016, 0.016, 0.012), IRON_L, 6, 3)
	for ci in 2:
		var x := -0.18 + 0.36 * ci
		var links := 9 + ci * 2
		for k in links:
			var y := -0.07 - k * 0.06
			var bs := Basis(Vector3.UP, 0.0 if k % 2 == 0 else PI * 0.5)
			b.rbox(Vector3(x, y, 0.045), Vector3(0.022, 0.04, 0.009), IRON_L, bs)
		var yb := -0.07 - links * 0.06
		b.hoop(0.045, yb - 0.02, 0.05, 0.014, IRON, 10)
	b.m = MATTE

static func _throne(b: B) -> void:
	b.box(Vector3(0, 0.08, 0), Vector3(0.9, 0.08, 0.8), STONE_D)
	b.box(Vector3(0, 0.24, 0.05), Vector3(0.72, 0.08, 0.62), STONE)
	b.box(Vector3(0, 0.55, 0.05), Vector3(0.5, 0.22, 0.46), B.sh(STONE, 0.95))
	b.box(Vector3(0, 0.8, 0.05), Vector3(0.48, 0.05, 0.44), CLOTH_R)
	b.box(Vector3(0, 1.3, -0.38), Vector3(0.54, 0.98, 0.1), STONE)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.54, 0.0), Vector2(0.5, 0.2), Vector2(0.3, 0.38), Vector2(0.0, 0.44)], 14, STONE, Vector3(0, 2.28, -0.38), 0.0, 0.0, true, 1.0, 0.2)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.62, 0.55, 0.05), Vector3(0.1, 0.1, 0.4), STONE)
		b.box(Vector3(sx * 0.62, 0.34, 0.0), Vector3(0.1, 0.1, 0.34), B.sh(STONE, 0.8))
		_skull(b, Vector3(sx * 0.62, 0.65, 0.4), sx * 0.2)
	b.m = METAL
	for k in 7:
		var x := -0.5 + k * 0.167
		b.frustum(Vector3(x, 2.2 + (0.2 - absf(x) * 0.0), -0.38), Vector3(x, 2.5 - absf(x) * 0.28, -0.38), 0.025, 0.0, 5, IRON_L, true)
	b.m = MATTE
	_skull(b, Vector3(0, 2.0, -0.28), 0.0)
	_skull(b, Vector3(-0.35, 1.8, -0.28), 0.1)
	_skull(b, Vector3(0.35, 1.8, -0.28), -0.1)

# ------------------------------------------------------------------ marché

const STALL_FLAME := Vector3(0.82, 1.62, 0.5)

static func _stall(b: B) -> void:
	var stripes := 8
	var w := 2.2
	# comptoir
	b.box(Vector3(0, 0.42, -0.1), Vector3(0.9, 0.42, 0.3), B.sh(WOOD, 0.95))
	for k in 6:
		b.box(Vector3(-0.75 + k * 0.3, 0.42, 0.205), Vector3(0.145, 0.4, 0.012), B.jit(WOOD, 0.12, k + 2))
	b.box(Vector3(0, 0.87, -0.05), Vector3(0.98, 0.03, 0.4), OAK)
	# montants et auvent rayé
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 1.0, 1.05, 0.38), Vector3(0.04, 1.05, 0.04), DARK_WOOD)
		b.box(Vector3(sx * 1.0, 1.15, -0.3), Vector3(0.04, 1.15, 0.04), DARK_WOOD)
	var yb := 2.3
	var zb := -0.33
	var yf := 1.95
	var zf := 0.62
	for i in stripes:
		var x0 := -w * 0.5 + w * float(i) / stripes
		var x1 := -w * 0.5 + w * float(i + 1) / stripes
		var col := CLOTH_R if i % 2 == 0 else CLOTH_C
		var n := Vector3(0, zf - zb, yb - yf).normalized()
		b.quad(Vector3(x0, yb, zb), Vector3(x0, yf, zf), Vector3(x1, yf, zf), Vector3(x1, yb, zb), n, col)
		b.quad(Vector3(x0, yb, zb), Vector3(x1, yb, zb), Vector3(x1, yf, zf), Vector3(x0, yf, zf), -n, B.sh(col, 0.75))
		b.tri_flat(Vector3(x0, yf, zf), Vector3(x1, yf, zf), Vector3((x0 + x1) * 0.5, yf - 0.16, zf + 0.02), Vector3(0, 0, 1), col, col, col)
	b.box(Vector3(0, yb + 0.02, zb), Vector3(w * 0.5, 0.02, 0.025), DARK_WOOD)
	# marchandises
	for k in 3:
		var x := -0.62 + 0.62 * k
		b.lathe([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.16, 0.1), Vector2(0.17, 0.12), Vector2(0.15, 0.12), Vector2(0.0, 0.04)], 12, STRAW, Vector3(x, 0.9, 0.04), 0.1, 0.0, true)
		var fc: Color = [Color("c0392b"), Color("e08a1e"), Color("7aa63a")][k]
		for j in 6:
			var a := B.h(j, k, 51) * TAU
			var r := B.h(j, k, 52) * 0.1
			b.ellipsoid(Vector3(x + sin(a) * r, 0.99 + 0.02 * (j % 2), 0.04 + cos(a) * r), Vector3(0.045, 0.045, 0.045), B.jit(fc, 0.1, j), 8, 5)
	b.lathe([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.07), Vector2(0.0, 0.07)], 14, Color("e0c050"), Vector3(0.08, 0.9, -0.12), 0.06)
	b.m = METAL
	# lanterne suspendue
	b.frustum(Vector3(0.82, 2.04, 0.5), Vector3(0.82, 1.78, 0.5), 0.006, 0.006, 4, IRON, false)
	b.box(Vector3(0.82, 1.74, 0.5), Vector3(0.07, 0.015, 0.07), IRON)
	b.box(Vector3(0.82, 1.52, 0.5), Vector3(0.07, 0.015, 0.07), IRON)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0.82 + sx * 0.062, 1.63, 0.5 + sz * 0.062), Vector3(0.008, 0.11, 0.008), IRON)
	b.m = GLOW
	b.box(Vector3(0.82, 1.63, 0.5), Vector3(0.05, 0.09, 0.05), Color("ffb050"))
	b.m = MATTE

static func _table_small(b: B) -> void:
	_table(b, 1.8, 1.0)

static func _coin_scatter(b: B, v: int) -> void:
	b.m = METAL
	for i in 9:
		var a := B.h(i, v, 101) * TAU
		var r := B.h(i, v, 102) * 0.42
		var y := 0.0
		_coin(b, Vector3(sin(a) * r, 0.002, cos(a) * r), Vector3((B.h(i, v, 103) - 0.5) * 0.25, B.h(i, v, 104) * TAU, (B.h(i, v, 105) - 0.5) * 0.25), 0.05)
		if i % 4 == 0:
			_coin(b, Vector3(sin(a) * r, 0.014, cos(a) * r), Vector3(0.0, B.h(i, v, 106) * TAU, 0.0), 0.05)
	b.m = MATTE
