class_name KitGeometry
extends RefCounted
## Géométrie d'architecture gothique générée par code pour le kit du thème « gothic » : portails en ogive à ressauts (archivoltes), nervures de plafond et
## corniches. C'est un REMPLAÇANT TECHNIQUE, pas un travail de sculpture : formes simples, sans détail sculpté ni UV. Il donne dès maintenant la silhouette
## gothique (arc brisé, ressauts, imposte, clef) et marque la place de modèles artistiques : un GLB du même nom dans assets/kit/gothic/ (voir son LISEZMOI)
## remplace automatiquement le module généré (voir KitDecor._parts).
##
## Repère d'un portail : origine au sol au milieu de l'arête, +Y vers le haut, plan du portail = plan XY, profondeur en Z (symétrique). Le portail est un
## mur plein de 4 u (de bord de case à bord de case) percé d'une baie en arc brisé ; la baie reste centrée, large de 2 × hw, et dégage 3,5 u au sommet.
## Les normales sont fournies (une par face) : aucune dépendance à KitDecor.flat_normals.

const TOP := 4.0
const HALF := 2.0
const STEPS_N := 10      # tranches d'arc par ressaut (et par moitié)

## Portails : hw = demi-largeur de la baie, y0 = naissance de l'arc, steps = [[épaisseur radiale, demi-profondeur], …] de l'intérieur vers l'extérieur
## (les ressauts reculent vers l'extérieur : relief), panel_d = demi-profondeur du mur de remplissage, impost / keystone = imposte et clef.
## L'arc est équilatéral (rayon = largeur de baie). Somme des épaisseurs + hw <= 2 (bord de case).
const PRESETS := {
	"ogive": {"hw": 1.55, "y0": 0.85, "steps": [[0.22, 0.26], [0.18, 0.18]], "panel_d": 0.10, "impost": true, "keystone": false},
	"portal_room": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.32], [0.2, 0.22]], "panel_d": 0.12, "impost": true, "keystone": true},
	"portal_door": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.30], [0.2, 0.20]], "panel_d": 0.12, "impost": true, "keystone": true},
	"portal_stair": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.34], [0.2, 0.22]], "panel_d": 0.12, "impost": true, "keystone": true},
}
const PROCEDURAL := ["ogive", "portal_room", "portal_door", "portal_stair", "rib", "cornice"]

## Maillage du module `id` (null si ce module n'est pas généré par code).
static func build(id: String) -> ArrayMesh:
	var g := {"v": [], "n": []}      # tableaux simples (les PackedArray d'un dictionnaire sont copiés à chaque accès)
	if PRESETS.has(id):
		_portal(g, PRESETS[id])
	elif id == "rib":
		_rib(g)
	elif id == "cornice":
		_cornice(g)
	else:
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## Hauteur libre au centre de la baie et largeur : (largeur, hauteur au sommet de l'intrados) d'un portail.
static func opening(id: String) -> Vector2:
	var p: Dictionary = PRESETS[id]
	var hw: float = p.hw
	var r := 2.0 * hw
	var cx := r - hw
	return Vector2(2.0 * hw, float(p.y0) + sqrt(r * r - cx * cx))

# ------------------------------------------------------------------ primitives

## Triangle (a, b, c) tourné pour que sa normale (sens horaire = face avant) soit du côté de `hint`.
static func _tri(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	(g.v as Array).append_array([a, b, c])
	(g.n as Array).append_array([n, n, n])

static func _quad(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	_tri(g, a, b, c, hint)
	_tri(g, a, c, d, hint)

## Même quad et son symétrique par rapport au plan x = 0 (le portail est symétrique).
static func _quad_x(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, mirror: bool = true) -> void:
	_quad(g, a, b, c, d, hint)
	if mirror:
		var m := func(p: Vector3) -> Vector3: return Vector3(-p.x, p.y, p.z)
		_quad(g, m.call(a), m.call(b), m.call(c), m.call(d), Vector3(-hint.x, hint.y, hint.z))

## Face plane dans le plan XY à la profondeur ±z (avant et arrière), avec symétrie en x.
static func _face(g: Dictionary, a: Vector2, b: Vector2, c: Vector2, d: Vector2, z: float) -> void:
	_quad_x(g, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z), Vector3(0, 0, 1))
	_quad_x(g, Vector3(a.x, a.y, -z), Vector3(b.x, b.y, -z), Vector3(c.x, c.y, -z), Vector3(d.x, d.y, -z), Vector3(0, 0, -1))

## Bande de côté entre deux points d'une courbe (a -> b), de la profondeur z0 à z1, des deux côtés (±z) et en symétrie x ; `hint` = vers l'extérieur de la matière.
static func _side(g: Dictionary, a: Vector2, b: Vector2, z0: float, z1: float, hint: Vector2) -> void:
	var h := Vector3(hint.x, hint.y, 0.0)
	_quad_x(g, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), h)
	_quad_x(g, Vector3(a.x, a.y, -z0), Vector3(b.x, b.y, -z0), Vector3(b.x, b.y, -z1), Vector3(a.x, a.y, -z1), h)

## Boîte alignée sur les axes ; `skip` liste les faces à ne pas produire ("+x", "-y"…) : celles qui seraient dans le plan d'un mur, du sol ou du plafond.
static func _box(g: Dictionary, mn: Vector3, mx: Vector3, skip: PackedStringArray = PackedStringArray(), mirror: bool = false) -> void:
	var p := [Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z),
		Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z)]
	var faces := {"-z": [0, 1, 2, 3, Vector3(0, 0, -1)], "+z": [4, 5, 6, 7, Vector3(0, 0, 1)], "-x": [0, 3, 7, 4, Vector3(-1, 0, 0)],
		"+x": [1, 2, 6, 5, Vector3(1, 0, 0)], "-y": [0, 1, 5, 4, Vector3(0, -1, 0)], "+y": [3, 2, 6, 7, Vector3(0, 1, 0)]}
	for f in faces:
		if skip.has(f):
			continue
		var q: Array = faces[f]
		_quad_x(g, p[q[0]], p[q[1]], p[q[2]], p[q[3]], q[4], mirror)

# ------------------------------------------------------------------ portail en arc brisé

## Point de l'arc de rayon r (moitié gauche, x <= 0) : centre (cx, y0), de l'angle 0 (naissance) à l'angle du sommet (x = 0).
static func _arc_x(cx: float, r: float, th: float) -> float:
	return cx - r * cos(th)

static func _arc_y(cx: float, y0: float, r: float, x: float) -> float:
	return minf(y0 + sqrt(maxf(r * r - (x - cx) * (x - cx), 0.0)), TOP)

## Abscisses d'échantillonnage d'un arc (angles réguliers : le pied de l'arc, presque vertical, reste bien décrit), jusqu'au sommet (x = 0).
static func _arc_xs(cx: float, r: float) -> Array:
	var tha := acos(clampf(cx / r, -1.0, 1.0))
	var out: Array = []
	for i in STEPS_N + 1:
		out.append(minf(_arc_x(cx, r, tha * float(i) / float(STEPS_N)), 0.0))
	return out

static func _portal(g: Dictionary, p: Dictionary) -> void:
	var hw: float = p.hw
	var y0: float = p.y0
	var r0 := 2.0 * hw
	var cx := r0 - hw
	var steps: Array = p.steps
	var pd: float = p.panel_d
	var radii: Array = [r0]
	for s in steps:
		radii.append(float(radii[-1]) + float(s[0]))
	var rl: float = radii[-1]
	var jx: float = cx - rl                       # bord extérieur du dernier ressaut (<= -2 + ...)
	# ressauts : bandes entre deux arcs, face avant et arrière
	for k in steps.size():
		var rin: float = radii[k]
		var rout: float = radii[k + 1]
		var d: float = steps[k][1]
		var x0 := cx - rin                        # naissance de l'arc intérieur
		var xs: Array = _arc_xs(cx, rout)
		if not xs.has(x0):
			xs.append(x0)
		xs.sort()
		for i in xs.size() - 1:
			var xa: float = xs[i]
			var xb: float = xs[i + 1]
			if xb - xa < 1e-5:
				continue
			var mid := 0.5 * (xa + xb)
			var la := 0.0 if mid < x0 else _arc_y(cx, y0, rin, xa)
			var lb := 0.0 if mid < x0 else _arc_y(cx, y0, rin, xb)
			_face(g, Vector2(xa, la), Vector2(xb, lb), Vector2(xb, _arc_y(cx, y0, rout, xb)), Vector2(xa, _arc_y(cx, y0, rout, xa)), d)
	# mur de remplissage (de l'arc extérieur au plafond, et le long des piédroits jusqu'au bord de la case)
	var pxs: Array = _arc_xs(cx, rl)
	pxs.append(jx)
	pxs.append(-HALF)
	pxs.sort()
	for i in pxs.size() - 1:
		var xa: float = pxs[i]
		var xb: float = pxs[i + 1]
		if xb - xa < 1e-5 or xb <= -HALF:
			continue
		var mid := 0.5 * (xa + xb)
		var la := 0.0 if mid < jx else _arc_y(cx, y0, rl, xa)
		var lb := 0.0 if mid < jx else _arc_y(cx, y0, rl, xb)
		if la >= TOP - 1e-4 and lb >= TOP - 1e-4:
			continue
		_face(g, Vector2(xa, la), Vector2(xb, lb), Vector2(xb, TOP), Vector2(xa, TOP), pd)
	# intrados : fond de la baie (arc intérieur et piédroit), profondeur du premier ressaut
	var d0: float = steps[0][1]
	var ixs: Array = _arc_xs(cx, r0)
	for i in ixs.size() - 1:
		var xa: float = ixs[i]
		var xb: float = ixs[i + 1]
		if xb - xa < 1e-5:
			continue
		var a := Vector3(xa, _arc_y(cx, y0, r0, xa), -d0)
		var b := Vector3(xb, _arc_y(cx, y0, r0, xb), -d0)
		_quad_x(g, a, b, Vector3(b.x, b.y, d0), Vector3(a.x, a.y, d0), Vector3(cx - xa, y0 - a.y, 0.0))
	_quad_x(g, Vector3(-hw, 0.0, -d0), Vector3(-hw, y0, -d0), Vector3(-hw, y0, d0), Vector3(-hw, 0.0, d0), Vector3(1, 0, 0))
	# faces de ressaut : de la profondeur d_k à d_(k+1) (ou à celle du mur), le long de l'arc extérieur de chaque bande et de son piédroit
	for k in steps.size():
		var rout: float = radii[k + 1]
		var dk: float = steps[k][1]
		var dn: float = steps[k + 1][1] if k + 1 < steps.size() else pd
		var sxs: Array = _arc_xs(cx, rout)
		for i in sxs.size() - 1:
			var xa: float = sxs[i]
			var xb: float = sxs[i + 1]
			if xb - xa < 1e-5:
				continue
			var ya := _arc_y(cx, y0, rout, xa)
			var yb := _arc_y(cx, y0, rout, xb)
			if ya >= TOP - 1e-4 and yb >= TOP - 1e-4:
				continue
			_side(g, Vector2(xa, ya), Vector2(xb, yb), dk, dn, Vector2(xa - cx, ya - y0))
		_side(g, Vector2(cx - rout, 0.0), Vector2(cx - rout, y0), dk, dn, Vector2(-1, 0))
	# imposte (corniche à la naissance de l'arc), socle des piédroits, clef
	var ext := rl - r0 + 0.02
	var dmax: float = steps[0][1]
	if p.impost:
		_box(g, Vector3(-hw - ext, y0 - 0.1, -dmax - 0.07), Vector3(-hw + 0.05, y0 + 0.08, dmax + 0.07), PackedStringArray(), true)
	_box(g, Vector3(-hw - ext, 0.0, -dmax - 0.05), Vector3(-hw + 0.04, 0.28, dmax + 0.05), PackedStringArray(["-y"]), true)
	if p.keystone:
		var yi := _arc_y(cx, y0, r0, 0.0)
		var yo := _arc_y(cx, y0, rl, 0.0)
		_box(g, Vector3(-0.17, yi - 0.04, -dmax - 0.08), Vector3(0.17, minf(yo + 0.1, TOP), dmax + 0.08), PackedStringArray(["+y"]))

# ------------------------------------------------------------------ nervure de plafond et corniche

## Nervure transversale sous le plafond, d'un mur à l'autre, à ressauts, avec deux corbeaux. Au plan de l'arête (profondeur ±0,2).
static func _rib(g: Dictionary) -> void:
	_box(g, Vector3(-HALF, 3.68, -0.2), Vector3(HALF, TOP, 0.2), PackedStringArray(["+y", "-x", "+x"]))
	_box(g, Vector3(-1.95, 3.54, -0.12), Vector3(1.95, 3.68, 0.12), PackedStringArray(["-x", "+x"]))
	_box(g, Vector3(-HALF, 3.1, -0.17), Vector3(-1.72, 3.54, 0.17), PackedStringArray(["-x"]), true)
	_box(g, Vector3(-HALF, 2.98, -0.1), Vector3(-1.84, 3.1, 0.1), PackedStringArray(["-x"]), true)

## Corniche le long du haut d'un pan de mur (4 u), saillie de 0,22 u vers l'intérieur (+Z), en trois ressauts. Origine au milieu du pan.
static func _cornice(g: Dictionary) -> void:
	var skip := PackedStringArray(["-z", "+y", "-x", "+x"])
	_box(g, Vector3(-HALF, 3.84, 0.0), Vector3(HALF, TOP, 0.22), skip)
	_box(g, Vector3(-HALF, 3.72, 0.0), Vector3(HALF, 3.84, 0.14), skip)
	_box(g, Vector3(-HALF, 3.63, 0.0), Vector3(HALF, 3.72, 0.07), skip)
