class_name KitGeometryLava
extends RefCounted
## Géométrie d'architecture volcanique générée par code pour le kit du thème « lava » (Les Forges du monde brisé) : portails trapézoïdaux en blocs de basalte
## (montants à fruit, linteau épais, ressauts), piliers hexagonaux en orgues basaltiques, corniches à corbeaux, plinthes, plaques de forge et consoles.
##
## C'est une géométrie PROCÉDURALE, pas une sculpture : les blocs sont des boîtes subdivisées dont les sommets sont déplacés par un bruit 3D continu (arêtes et faces
## irrégulières, taille « au pic »), ombrées à plat. Le relief fin vient de la pierre du thème (projection triplanaire, voir KitDecor._with_theme_stone).
## Un GLB du même nom dans assets/kit/lava/ remplace automatiquement le module généré (voir KitDecor._parts et assets/kit/lava/LISEZMOI.md).
##
## Repères (identiques à ceux du kit gothic, voir KitDecor) : portail = plan XY, origine au sol au milieu de l'arête, +Y en haut, profondeur Z symétrique ;
## pilier : origine au sol au sommet d'angle ; corniche, plinthe, plaque : +Z vers l'intérieur de la case, mur en Z = WALL_Z.
## Passage libre garanti : largeur >= 3,0 sur toute la hauteur jusqu'à 3,5 (voir `opening`).

const TOP := 4.0
const HALF := 2.0
const WALL_Z := -0.04
const PROCEDURAL := ["arch", "portal_room", "portal_door", "portal_stair", "pillar", "cornice", "plinth", "ornament", "torch_bracket"]

## Portails : hw0 = demi-largeur de la baie au sol, hw1 = au linteau (montants à fruit : la baie se resserre un peu vers le haut), head = hauteur de la baie,
## jamb = épaisseur du montant intérieur (ressaut), jd / pd = demi-profondeur du ressaut et du mur de remplissage, straps = ferrures, plaque = plaque gravée au linteau.
const PRESETS := {
	"arch": {"hw0": 1.62, "hw1": 1.52, "head": 3.5, "jamb": 0.30, "jd": 0.40, "pd": 0.20, "straps": false, "plaque": false},
	"portal_room": {"hw0": 1.62, "hw1": 1.52, "head": 3.5, "jamb": 0.32, "jd": 0.44, "pd": 0.22, "straps": false, "plaque": true},
	"portal_door": {"hw0": 1.62, "hw1": 1.52, "head": 3.5, "jamb": 0.32, "jd": 0.44, "pd": 0.22, "straps": true, "plaque": true},
	"portal_stair": {"hw0": 1.62, "hw1": 1.52, "head": 3.5, "jamb": 0.32, "jd": 0.44, "pd": 0.22, "straps": true, "plaque": false},
}

static var _nz: FastNoiseLite

static func _noise() -> FastNoiseLite:
	if _nz == null:
		_nz = FastNoiseLite.new()
		_nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_nz.frequency = 1.15
		_nz.seed = 4242
	return _nz

## Champ de déplacement continu (le même en tout point de l'espace : les faces d'un bloc restent soudées).
static func _disp(p: Vector3, amp: float) -> Vector3:
	var n := _noise()
	return Vector3(n.get_noise_3d(p.x, p.y, p.z), n.get_noise_3d(p.x + 7.3, p.y - 2.1, p.z + 4.7), n.get_noise_3d(p.x - 5.9, p.y + 9.4, p.z - 1.3)) * amp

## Point déplacé, sauf sur les plans qui touchent le sol, le plafond ou les murs voisins (x = ±2, y = 0 ou 4) : ils restent exacts.
static func _pt(p: Vector3, amp: float, lock_x: bool = true) -> Vector3:
	var d := _disp(p, amp)
	if p.y <= 0.001 or p.y >= TOP - 0.001:
		d.y = 0.0
	if lock_x and absf(absf(p.x) - HALF) < 0.001:
		d.x = 0.0
	return p + d

static func _new() -> Dictionary:
	return {"v": [], "n": [], "c": [], "tint": Color.WHITE,
		"ir": {"v": [], "n": [], "c": [], "tint": Color.WHITE}}      # « ir » : ferrures (fer noirci, matériau métallique distinct)

static func _arrays(g: Dictionary) -> Array:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(g.c)
	return arr

## Maillage du module `id` (null si ce module n'est pas généré par code). Surface 0 : pierre ; surface 1 (si présente) : fer noirci.
static func build(id: String) -> ArrayMesh:
	if not PROCEDURAL.has(id):
		return null
	var g := _new()
	if PRESETS.has(id):
		_portal(g, PRESETS[id])
	elif id == "pillar":
		_pillar(g)
	elif id == "cornice":
		_cornice(g)
	elif id == "plinth":
		_plinth(g)
	elif id == "ornament":
		_ornament(g)
	elif id == "torch_bracket":
		_console(g)
	var m := ArrayMesh.new()
	if not (g.v as Array).is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(g))
	var ir: Dictionary = g.ir
	if not (ir.v as Array).is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(ir))
		m.surface_set_material(m.get_surface_count() - 1, _iron_material())
	return m

static var _iron: StandardMaterial3D

## Fer noirci : sombre, mat, légèrement métallique (≥ 0,3 : jamais remplacé par la pierre du thème).
static func _iron_material() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = Color(0.10, 0.095, 0.092)
		_iron.metallic = 0.6
		_iron.metallic_specular = 0.5
		_iron.roughness = 0.62
		_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _iron

## Largeur libre et hauteur libre d'un portail (au plus étroit : au linteau).
static func opening(id: String) -> Vector2:
	var p: Dictionary = PRESETS[id]
	return Vector2(2.0 * float(p.hw1), float(p.head))

# ------------------------------------------------------------------ primitives

## Bloc de pierre taillé « au pic » : boîte dont chaque face est subdivisée n × n, sommets déplacés (amplitude amp). `skip` : faces à ne pas produire ("+x", "-y"…).
## La teinte de sommet (g.tint) varie d'un bloc à l'autre : la pierre du thème est multipliée par elle.
static func _block(g: Dictionary, mn: Vector3, mx: Vector3, n: int = 3, amp: float = 0.025, skip: PackedStringArray = PackedStringArray(), lock_x: bool = true) -> void:
	var dx := mx.x - mn.x
	var dy := mx.y - mn.y
	var dz := mx.z - mn.z
	# face : [origine, axe u, axe v, normale] ; les triangles sont orientés vers la normale par KitGeometry._tri
	var faces := {
		"-z": [Vector3(mn.x, mn.y, mn.z), Vector3(dx, 0, 0), Vector3(0, dy, 0), Vector3(0, 0, -1)],
		"+z": [Vector3(mn.x, mn.y, mx.z), Vector3(dx, 0, 0), Vector3(0, dy, 0), Vector3(0, 0, 1)],
		"-x": [Vector3(mn.x, mn.y, mn.z), Vector3(0, 0, dz), Vector3(0, dy, 0), Vector3(-1, 0, 0)],
		"+x": [Vector3(mx.x, mn.y, mn.z), Vector3(0, 0, dz), Vector3(0, dy, 0), Vector3(1, 0, 0)],
		"-y": [Vector3(mn.x, mn.y, mn.z), Vector3(dx, 0, 0), Vector3(0, 0, dz), Vector3(0, -1, 0)],
		"+y": [Vector3(mn.x, mx.y, mn.z), Vector3(dx, 0, 0), Vector3(0, 0, dz), Vector3(0, 1, 0)],
	}
	for key in faces:
		if skip.has(key):
			continue
		var f: Array = faces[key]
		var o: Vector3 = f[0]
		var au: Vector3 = f[1]
		var av: Vector3 = f[2]
		var nrm: Vector3 = f[3]
		for i in n:
			for j in n:
				var p00 := _pt(o + au * (float(i) / n) + av * (float(j) / n), amp, lock_x)
				var p10 := _pt(o + au * (float(i + 1) / n) + av * (float(j) / n), amp, lock_x)
				var p11 := _pt(o + au * (float(i + 1) / n) + av * (float(j + 1) / n), amp, lock_x)
				var p01 := _pt(o + au * (float(i) / n) + av * (float(j + 1) / n), amp, lock_x)
				KitGeometry._tri(g, p00, p10, p11, nrm)
				KitGeometry._tri(g, p00, p11, p01, nrm)

## Variation de teinte par bloc (déterministe : position du bloc).
static func _tone(g: Dictionary, key: Vector3) -> void:
	var h := absf(sin(key.x * 12.9898 + key.y * 78.233 + key.z * 37.719) * 43758.5453)
	var v := 0.78 + 0.34 * (h - floorf(h))
	g.tint = Color(v, v, v * 1.02)

## Prisme hexagonal (orgue basaltique) : flancs en `rows` bandes dont le rayon varie un peu, sommet plat (flat) ou brisé (déplacé, en dents). Base à y0.
static func _hex(g: Dictionary, c: Vector2, r: float, y0: float, y1: float, seed: float, flat: bool, rows: int = 4, rot: float = 0.5236) -> void:
	var ring := func(y: float) -> Array:
		var pts: Array = []
		var rr := r * (1.0 + 0.045 * sin(seed * 3.1 + y * 5.7))
		for k in 6:
			var a := rot + TAU * float(k) / 6.0
			var p := Vector3(c.x + cos(a) * rr, y, c.y + sin(a) * rr)
			pts.append(_pt(p, 0.018, false))
		return pts
	var prev: Array = ring.call(y0)
	for rw in rows:
		var y: float = lerpf(y0, y1, float(rw + 1) / float(rows))
		var cur: Array = ring.call(y)
		for k in 6:
			var k2 := (k + 1) % 6
			var mid := Vector3((prev[k].x + prev[k2].x) * 0.5 - c.x, 0.0, (prev[k].z + prev[k2].z) * 0.5 - c.y)
			KitGeometry._quad(g, prev[k], prev[k2], cur[k2], cur[k], mid)
		prev = cur
	# sommet : plat (sous le plafond) ou brisé
	var top := Vector3(c.x, y1, c.y)
	var tp: Array = prev
	for k in 6:
		var k2 := (k + 1) % 6
		var a: Vector3 = tp[k]
		var b: Vector3 = tp[k2]
		if not flat:
			a.y += 0.10 * sin(seed * 2.3 + float(k) * 2.1)
			b.y += 0.10 * sin(seed * 2.3 + float(k2) * 2.1)
			top.y = y1 + 0.05 * sin(seed * 1.7)
		KitGeometry._tri(g, top, a, b, Vector3(0, 1, 0))

# ------------------------------------------------------------------ portail trapézoïdal

static func _portal(g: Dictionary, p: Dictionary) -> void:
	var hw0: float = p.hw0
	var hw1: float = p.hw1
	var head: float = p.head
	var jamb: float = p.jamb
	var jd: float = p.jd
	var pd: float = p.pd
	# montants : assises de hauteurs irrégulières ; le montant intérieur (ressaut, saillant) et le mur de remplissage derrière lui, de part et d'autre (±x)
	var courses := [0.62, 0.48, 0.71, 0.55, 0.52, 0.62]      # somme 3,5
	for side in [-1.0, 1.0]:
		var y := 0.0
		for ci in courses.size():
			var h: float = courses[ci]
			var ym := y + h * 0.5
			var hw: float = lerpf(hw0, hw1, ym / head)      # fruit : la baie se resserre vers le haut
			var xi: float = hw
			var xo: float = hw + jamb * (0.9 + 0.2 * float((ci * 7) % 3) / 2.0)
			# ressaut intérieur
			_tone(g, Vector3(side * xo, y, 0.0))
			var a := Vector3(minf(side * xi, side * xo), y, -jd)
			var b := Vector3(maxf(side * xi, side * xo), y + h - 0.02, jd)
			_block(g, a, b, 2, 0.02, PackedStringArray([]))
			# mur de remplissage, plus mince, jusqu'au bord de la case
			_tone(g, Vector3(side * 1.9, y + 0.1, 1.0))
			var fa := Vector3(minf(side * xo, side * HALF), y, -pd)
			var fb := Vector3(maxf(side * xo, side * HALF), y + h - 0.02, pd)
			_block(g, fa, fb, 2, 0.015, PackedStringArray(["-x", "+x"]))
			y += h
	# linteau : trois blocs, celui du milieu (clef) plus saillant ; il surplombe la baie sans jamais entrer dans le passage (y >= head)
	var lx := [[-HALF, -0.55, 0.40], [-0.55, 0.55, 0.52], [0.55, HALF, 0.40]]
	for i in lx.size():
		var l: Array = lx[i]
		_tone(g, Vector3(float(i), 3.9, 2.0))
		_block(g, Vector3(l[0], head + 0.03, -float(l[2])), Vector3(l[1], TOP, float(l[2])), 3, 0.02, PackedStringArray(["+y"]))
	if p.plaque:      # plaque gravée sous le linteau : fer noirci, trois barres en relief (symbole de forgeron)
		var ir: Dictionary = g.ir
		for z in [-1.0, 1.0]:
			var zf: float = 0.545 * z
			KitGeometry._box(ir, Vector3(-0.28, head + 0.12, minf(zf, zf + 0.03 * z)), Vector3(0.28, head + 0.40, maxf(zf, zf + 0.03 * z)))
			for bx in [-0.15, 0.0, 0.15]:
				KitGeometry._box(ir, Vector3(bx - 0.018, head + 0.16, minf(zf, zf + 0.05 * z)), Vector3(bx + 0.018, head + 0.36, maxf(zf, zf + 0.05 * z)))
	if p.straps:      # ferrures : deux bandes de fer sur chaque montant, avec clous
		var ir: Dictionary = g.ir
		for side in [-1.0, 1.0]:
			for sy in [0.85, 2.55]:
				var xa: float = hw0 + 0.02
				var xb: float = hw0 + jamb + 0.04
				for z in [-1.0, 1.0]:
					var zf: float = (jd + 0.01) * z
					KitGeometry._box(ir, Vector3(minf(side * xa, side * xb), sy, minf(zf, zf + 0.022 * z)), Vector3(maxf(side * xa, side * xb), sy + 0.14, maxf(zf, zf + 0.022 * z)), PackedStringArray([]))
					for k in 2:
						var nx: float = lerpf(xa, xb, 0.25 + 0.5 * float(k))
						KitGeometry._cone(ir, Vector3(side * nx, sy + 0.07, zf + 0.022 * z), Vector3(side * nx, sy + 0.07, zf + 0.04 * z), 0.022, 0.012, 6)

# ------------------------------------------------------------------ pilier hexagonal

## Pilier d'angle : orgue central pleine hauteur, deux orgues plus courts et brisés accolés, socle hexagonal. Emprise <= 0,8 × 0,8 (comme le pilier gothic).
static func _pillar(g: Dictionary) -> void:
	_tone(g, Vector3(0.3, 0.0, 0.1))
	_hex(g, Vector2(0.0, 0.0), 0.37, 0.0, 0.34, 0.5, true, 2)            # socle
	_tone(g, Vector3(0.6, 1.0, 0.4))
	_hex(g, Vector2(0.0, 0.0), 0.27, 0.34, TOP, 1.3, true, 7)             # fût central, jusqu'au plafond
	for s in [[0.22, 0.08, 0.13, 2.7], [-0.12, -0.24, 0.13, 3.3], [-0.20, 0.20, 0.12, 1.9]]:
		_tone(g, Vector3(s[0] * 5.0, s[3], 0.7))
		_hex(g, Vector2(s[0], s[1]), s[2], 0.0, s[3], s[0] * 9.0 + s[1] * 4.0, false, 5, 0.2 + s[0])

# ------------------------------------------------------------------ corniche, plinthe, plaque, console

## Corniche massive et anguleuse : trois ressauts et corbeaux de basalte tous les mètres. Hauteur 0,75, saillie 0,30 : ne gêne jamais le passage.
static func _cornice(g: Dictionary) -> void:
	var z0 := WALL_Z
	_tone(g, Vector3(1.0, 3.8, 0.0))
	_block(g, Vector3(-HALF, 3.74, z0), Vector3(HALF, TOP, z0 + 0.22), 4, 0.012, PackedStringArray(["+y", "-z", "-x", "+x"]))
	_block(g, Vector3(-HALF, 3.56, z0), Vector3(HALF, 3.74, z0 + 0.14), 4, 0.012, PackedStringArray(["-z", "-x", "+x"]))
	_block(g, Vector3(-HALF, 3.44, z0), Vector3(HALF, 3.56, z0 + 0.07), 4, 0.012, PackedStringArray(["-z", "-x", "+x"]))
	for cx in [-1.5, -0.5, 0.5, 1.5]:      # corbeaux
		_tone(g, Vector3(cx, 3.5, 2.0))
		_block(g, Vector3(cx - 0.17, 3.18, z0), Vector3(cx + 0.17, 3.44, z0 + 0.26), 2, 0.012, PackedStringArray(["-z", "+y"]))

## Plinthe lourde : deux ressauts de basalte au pied du mur.
static func _plinth(g: Dictionary) -> void:
	var z0 := WALL_Z
	_tone(g, Vector3(2.0, 0.1, 0.0))
	_block(g, Vector3(-HALF, 0.0, z0), Vector3(HALF, 0.20, z0 + 0.19), 4, 0.012, PackedStringArray(["-y", "-z", "-x", "+x"]))
	_block(g, Vector3(-HALF, 0.20, z0), Vector3(HALF, 0.34, z0 + 0.10), 4, 0.010, PackedStringArray(["-y", "-z", "-x", "+x"]))

## Plaque de forge : cadre de basalte, plaque de fer noirci portant trois barres et un cercle de rivets. 0,7 × 1,0.
static func _ornament(g: Dictionary) -> void:
	var z0 := WALL_Z
	_tone(g, Vector3(0.0, 1.9, 0.0))
	_block(g, Vector3(-0.35, 1.40, z0), Vector3(0.35, 2.40, z0 + 0.075), 3, 0.008, PackedStringArray(["-z"]))
	var ir: Dictionary = g.ir
	KitGeometry._box(ir, Vector3(-0.27, 1.48, z0 + 0.07), Vector3(0.27, 2.32, z0 + 0.095), PackedStringArray(["-z"]))
	for bx in [-0.13, 0.0, 0.13]:
		KitGeometry._box(ir, Vector3(bx - 0.022, 1.62, z0 + 0.095), Vector3(bx + 0.022, 2.16, z0 + 0.118), PackedStringArray(["-z"]))
	for a in 8:
		var an := TAU * float(a) / 8.0
		KitGeometry._cone(ir, Vector3(cos(an) * 0.2, 1.9 + sin(an) * 0.34, z0 + 0.095), Vector3(cos(an) * 0.2, 1.9 + sin(an) * 0.34, z0 + 0.118), 0.018, 0.010, 6)

## Console du support de torche : bloc de basalte scellé au mur sous le point d'accroche, le fer forgé du support (celui du gothic) la traverse.
static func _console(g: Dictionary) -> void:
	var z0 := WALL_Z
	_tone(g, Vector3(0.0, 0.5, 0.3))
	_block(g, Vector3(-0.12, -0.36, z0), Vector3(0.12, -0.06, z0 + 0.13), 2, 0.008, PackedStringArray(["-z"]))
	_block(g, Vector3(-0.16, -0.06, z0), Vector3(0.16, 0.02, z0 + 0.16), 2, 0.008, PackedStringArray(["-z"]))
	# platine et volute de fer, reprises du support gothic (même point d'accroche, même tête de torche)
	var iron := KitGeometry.build("torch_bracket")
	if iron != null:
		var arr := iron.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ir: Dictionary = g.ir
		for i in vs.size():
			(ir.v as Array).append(vs[i])
			(ir.n as Array).append(ns[i])
			(ir.c as Array).append(Color.WHITE)
