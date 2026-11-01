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
const STEPS_N := 10      # claveaux par ressaut et par moitié d'arc
const JOINT_TINT := Color(0.32, 0.34, 0.40)      # flanc d'un joint de claveau : creux sombre
const VOUSSOIR_RECESS := 0.05      # retrait d'un claveau sur deux (relief des joints)

## Portails : hw = demi-largeur de la baie, y0 = naissance de l'arc, steps = [[épaisseur radiale, demi-profondeur], …] de l'intérieur vers l'extérieur
## (les ressauts reculent vers l'extérieur : relief), panel_d = demi-profondeur du mur de remplissage, impost / keystone = imposte et clef.
## L'arc est équilatéral (rayon = largeur de baie). Somme des épaisseurs + hw <= 2 (bord de case).
const PRESETS := {
	"ogive": {"hw": 1.55, "y0": 0.85, "steps": [[0.22, 0.26], [0.18, 0.18]], "panel_d": 0.10, "impost": true, "keystone": false},
	"portal_room": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.32], [0.2, 0.22]], "panel_d": 0.12, "impost": true, "keystone": true},
	"portal_door": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.30], [0.2, 0.20]], "panel_d": 0.12, "impost": true, "keystone": true},
	"portal_stair": {"hw": 1.5, "y0": 0.9, "steps": [[0.2, 0.34], [0.2, 0.22]], "panel_d": 0.12, "impost": true, "keystone": true},
}
const PROCEDURAL := ["ogive", "portal_room", "portal_door", "portal_stair", "rib", "cornice", "torch_bracket"]

## Maillage du module `id` (null si ce module n'est pas généré par code).
static func build(id: String) -> ArrayMesh:
	var g := {"v": [], "n": [], "c": [], "tint": Color.WHITE}      # tableaux simples (les PackedArray d'un dictionnaire sont copiés à chaque accès)
	if PRESETS.has(id):
		_portal(g, PRESETS[id])
	elif id == "rib":
		_rib(g)
	elif id == "cornice":
		_cornice(g)
	elif id == "torch_bracket":
		_torch_bracket(g)
	else:
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
	if (g.c as Array).any(func(c: Color) -> bool: return c != Color.WHITE):
		arr[Mesh.ARRAY_COLOR] = PackedColorArray(g.c)      # joints des claveaux assombris (la pierre du thème multiplie la couleur de sommet)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if id == "torch_bracket":
		m.surface_set_material(0, _iron_material())      # fer forgé : métal ≥ 0,3, donc jamais remplacé par la pierre du thème
	return m

static var _iron: StandardMaterial3D

static func _iron_material() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new()
		_iron.albedo_color = Color(0.13, 0.135, 0.15)
		_iron.metallic = 0.55
		_iron.metallic_specular = 0.5
		_iron.roughness = 0.52
		_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _iron

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
	(g.c as Array).append_array([g.tint, g.tint, g.tint])

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

## Point de l'arc de rayon r à la fraction t (0 = naissance, 1 = sommet à x = 0) ; moitié gauche.
static func _arc_pt(cx: float, y0: float, r: float, t: float) -> Vector2:
	var th := acos(clampf(cx / r, -1.0, 1.0)) * t
	return Vector2(minf(_arc_x(cx, r, th), 0.0), minf(y0 + r * sin(th), TOP))

## Retrait du claveau i du ressaut k (alterné d'un ressaut à l'autre : les joints ne se superposent pas).
static func _recess(i: int, k: int) -> float:
	return VOUSSOIR_RECESS if (i + k) % 2 == 1 else 0.0

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
	# ressauts : piédroit plein, puis claveaux (joints radiaux). Les claveaux alternent entre saillie et léger retrait (VOUSSOIR_RECESS) : de vrais joints en relief.
	for k in steps.size():
		var rin: float = radii[k]
		var rout: float = radii[k + 1]
		var d: float = steps[k][1]
		var x0 := cx - rin                        # naissance de l'arc intérieur
		_face(g, Vector2(cx - rout, 0.0), Vector2(x0, 0.0), Vector2(x0, y0), Vector2(cx - rout, y0), d)
		for i in STEPS_N:
			var t0 := float(i) / float(STEPS_N)
			var t1 := float(i + 1) / float(STEPS_N)
			var ia := _arc_pt(cx, y0, rin, t0)
			var ib := _arc_pt(cx, y0, rin, t1)
			var oa := _arc_pt(cx, y0, rout, t0)
			var ob := _arc_pt(cx, y0, rout, t1)
			if oa.y >= TOP - 1e-4 and ob.y >= TOP - 1e-4:
				continue
			var rec := _recess(i, k)
			_face(g, ia, oa, ob, ib, d - rec)
			if i > 0 and rec != _recess(i - 1, k):
				var toward := (ib - ia).normalized()          # vers le claveau suivant (sens croissant de l'arc)
				g.tint = JOINT_TINT
				_side(g, ia, oa, d - VOUSSOIR_RECESS, d, toward if rec > 0.0 else -toward)
				g.tint = Color.WHITE
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

# ------------------------------------------------------------------ support de torche en fer forgé

## Repère de TorchLayer : origine au point d'accroche, +Z vers l'intérieur, mur en Z = -0,04, bas du manche en (0, -0,24, 0,045), axe du manche incliné de ~23°.
const WALL_Z := -0.04
const SHAFT_BOT := Vector3(0.0, -0.24, 0.045)
const SHAFT_AXIS := Vector3(0.0, 0.31, 0.13)

## Triangle à normales lissées fournies (a, b, c) ; l'ordre est corrigé pour que la face avant regarde du côté des normales.
static func _tri_n(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var ng := (c - a).cross(b - a)
	if ng.dot(na + nb + nc) < 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
	(g.v as Array).append_array([a, b, c])
	(g.n as Array).append_array([na, nb, nc])
	(g.c as Array).append_array([g.tint, g.tint, g.tint])

## Tube lisse (section à n côtés) le long d'une courbe de Catmull-Rom passant par `ctrl` (points (z, y) dans le plan x = 0). Extrémités fermées.
static func _tube(g: Dictionary, ctrl: Array, r: float, n: int, per: int = 6) -> void:
	var pts: Array = []
	for i in ctrl.size() - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, ctrl.size() - 1)]
		for j in per:
			var t := float(j) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	pts.append(ctrl[-1])
	var rings: Array = []
	for i in pts.size():
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var tg := Vector3(0.0, (b - a).y, (b - a).x).normalized()
		var w := tg.cross(Vector3.RIGHT).normalized()
		var ring: Array = []
		for j in n:
			var ang := TAU * float(j) / float(n)
			var nn := Vector3.RIGHT * cos(ang) + w * sin(ang)
			ring.append([Vector3(0.0, pts[i].y, pts[i].x) + nn * r, nn])
		rings.append(ring)
	for i in rings.size() - 1:
		for j in n:
			var j2 := (j + 1) % n
			var a0: Array = rings[i][j]
			var a1: Array = rings[i][j2]
			var b0: Array = rings[i + 1][j]
			var b1: Array = rings[i + 1][j2]
			_tri_n(g, a0[0], a1[0], b1[0], a0[1], a1[1], b1[1])
			_tri_n(g, a0[0], b1[0], b0[0], a0[1], b1[1], b0[1])
	for end in [0, rings.size() - 1]:       # bouchons
		var c3 := Vector3(0.0, pts[end].y, pts[end].x)
		var out_n := (Vector3(0.0, (pts[end] - pts[1 if end == 0 else end - 1]).y, (pts[end] - pts[1 if end == 0 else end - 1]).x)).normalized()
		for j in n:
			var j2 := (j + 1) % n
			_tri_n(g, c3, rings[end][j][0], rings[end][j2][0], out_n, out_n, out_n)

## Tronc de cône d'axe a→b (rayons ra puis rb), normales lissées, non fermé aux bouts.
static func _cone(g: Dictionary, a: Vector3, b: Vector3, ra: float, rb: float, n: int, caps: bool = true) -> void:
	var ax := (b - a).normalized()
	var u := ax.cross(Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.UP).normalized()
	var v := ax.cross(u).normalized()
	for j in n:
		var a0 := TAU * float(j) / float(n)
		var a1 := TAU * float(j + 1) / float(n)
		var r0 := u * cos(a0) + v * sin(a0)
		var r1 := u * cos(a1) + v * sin(a1)
		_tri_n(g, a + r0 * ra, a + r1 * ra, b + r1 * rb, r0, r1, r1)
		_tri_n(g, a + r0 * ra, b + r1 * rb, b + r0 * rb, r0, r1, r0)
		if caps:
			_tri_n(g, b, b + r0 * rb, b + r1 * rb, ax, ax, ax)

## Platine en ogive clouée au mur, volute de fer qui porte le pied du manche, collerette évasée. Aucune lumière : la flamme appartient à TorchLayer.
static func _torch_bracket(g: Dictionary) -> void:
	var zb := WALL_Z
	var zf := WALL_Z + 0.012
	var poly: Array = [Vector2(-0.085, -0.28), Vector2(0.085, -0.28), Vector2(0.085, 0.01), Vector2(0.06, 0.115), Vector2(0.0, 0.215),
		Vector2(-0.06, 0.115), Vector2(-0.085, 0.01)]
	var c2 := Vector2(0.0, -0.05)
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		_tri(g, Vector3(c2.x, c2.y, zf), Vector3(a.x, a.y, zf), Vector3(b.x, b.y, zf), Vector3(0, 0, 1))
		var out2 := Vector3((a + b).x * 0.5 - c2.x, (a + b).y * 0.5 - c2.y, 0.0)
		_quad(g, Vector3(a.x, a.y, zb), Vector3(b.x, b.y, zb), Vector3(b.x, b.y, zf), Vector3(a.x, a.y, zf), out2)
	for sx in [-1.0, 1.0]:                  # clous à tête bombée
		for yy in [-0.235, 0.02]:
			_cone(g, Vector3(0.056 * sx, yy, zf), Vector3(0.056 * sx, yy, zf + 0.014), 0.014, 0.008, 8)
	# volute : part du bas de la platine, passe sous le pied du manche et le soutient
	_tube(g, [Vector2(zb + 0.01, -0.285), Vector2(0.0, -0.318), Vector2(0.05, -0.316), Vector2(0.092, -0.285), Vector2(0.1, -0.245), Vector2(0.082, -0.212)], 0.0105, 8)
	_tube(g, [Vector2(0.082, -0.212), Vector2(0.066, -0.196), Vector2(0.052, -0.2)], 0.0085, 6, 4)    # enroulement de l'extrémité
	# collerette qui entoure le manche au-dessus du pied
	var ax := SHAFT_AXIS.normalized()
	var c0 := SHAFT_BOT + ax * 0.03
	_cone(g, c0, c0 + ax * 0.03, 0.03, 0.040, 12, false)
	_cone(g, c0 + ax * 0.03, c0 + ax * 0.036, 0.040, 0.040, 12, false)
