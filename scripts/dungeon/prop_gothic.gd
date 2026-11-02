class_name PropGothic
extends RefCounted
## Modèles de salle propres au thème gothic (Atlas Noir), construits par le code avec le constructeur de PropMeshes (PropMeshes.B) : autel sculpté et
## candélabres en fer forgé pour l'instant. Les modèles des autres thèmes (« altar », « candelabra ») restent inchangés.
## Surfaces : STONE (PBR de la pierre gothic, triplanaire, voir PropMeshes._stone_mat), MATTE (cire, tissu, bois), METAL (fer, bronze, or).
## Ce sont des maillages procéduraux détaillés, pas des modèles d'artiste : les spécifications d'un remplacement par un GLB sont dans docs/MODELES_SALLES.md.

const MATTE := 0      # numéros de surface de PropMeshes (MATTE, METAL, STONE)
const METAL := 1
const SURF_STONE := 3

const ST := Color("9a9ca2")            # pierre claire (teinte multipliée par la texture PBR)
const ST_D := Color("6c6e76")
const ST_L := Color("b4b6bc")
const IRON_W := Color("2f2f34")        # fer forgé
const IRON_H := Color("45454c")
const BRONZE := Color("8a6a34")
const GOLD_O := Color("b08a3a")
const CLOTH_G := Color("5a1f22")       # étoffe de l'autel : rouge sombre passé
const CLOTH_G2 := Color("3d1517")

# ------------------------------------------------------------------ primitives

## Sommet d'un parallélépipède chamfreiné : coin `s` (±1 par axe), face d'axe `a` (cette coordonnée est à l'extrême, les deux autres rentrent de `bev`).
static func _cv(ctr: Vector3, hs: Vector3, bev: float, s: Vector3, a: int, seedv: int, wear: float) -> Vector3:
	var p := Vector3.ZERO
	for i in 3:
		p[i] = s[i] * (hs[i] if i == a else hs[i] - bev)
	var k := int(s.x + 1.0) * 1 + int(s.y + 1.0) * 3 + int(s.z + 1.0) * 9 + a * 27
	var j := Vector3(PropMeshes.B.h(k, seedv, 1) - 0.5, PropMeshes.B.h(k, seedv, 2) - 0.5, PropMeshes.B.h(k, seedv, 3) - 0.5) * 2.0 * wear
	return ctr + p + j

## Bloc de pierre à arêtes chamfreinées et légèrement usées (`wear` : amplitude de l'irrégularité). Faces, chanfreins et coins ont leur propre teinte.
static func bbox(b: PropMeshes.B, ctr: Vector3, hs: Vector3, bev: float, col: Color, seedv := 0, wear := 0.005) -> void:
	var sg := [-1.0, 1.0]
	var tint := PropMeshes.B.jit(col, 0.07, seedv * 7 + 3)
	for a in 3:
		var ib := (a + 1) % 3
		var ic := (a + 2) % 3
		for sa in sg:
			var q: Array = []
			for pair in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var s := Vector3.ZERO
				s[a] = sa
				s[ib] = pair[0]
				s[ic] = pair[1]
				q.append(_cv(ctr, hs, bev, s, a, seedv, wear))
			var n := Vector3.ZERO
			n[a] = sa
			var k := 1.0 if a != 1 else (1.12 if sa > 0.0 else 0.7)
			if a == 0:
				k = 0.92
			var c := PropMeshes.B.sh(tint, k * (0.95 + 0.1 * PropMeshes.B.h(a * 2 + int(sa), seedv, 5)))
			b.tri_flat(q[0], q[1], q[2], n, c, c, c)
			b.tri_flat(q[0], q[2], q[3], n, c, c, c)
	for a in 3:
		for bb in range(a + 1, 3):
			var c3 := 3 - a - bb
			for sa in sg:
				for sb in sg:
					var q: Array = []
					for sc in [-1.0, 1.0]:
						var s := Vector3.ZERO
						s[a] = sa
						s[bb] = sb
						s[c3] = sc
						q.append([_cv(ctr, hs, bev, s, a, seedv, wear), _cv(ctr, hs, bev, s, bb, seedv, wear)])
					var hint := Vector3.ZERO
					hint[a] = sa
					hint[bb] = sb
					var c := PropMeshes.B.sh(tint, 1.1)      # l'arête usée accroche la lumière
					b.tri_flat(q[0][0], q[0][1], q[1][1], hint, c, c, c)
					b.tri_flat(q[0][0], q[1][1], q[1][0], hint, c, c, c)
	for sx in sg:
		for sy in sg:
			for sz in sg:
				var s := Vector3(sx, sy, sz)
				var c := PropMeshes.B.sh(tint, 1.04)
				b.tri_flat(_cv(ctr, hs, bev, s, 0, seedv, wear), _cv(ctr, hs, bev, s, 1, seedv, wear), _cv(ctr, hs, bev, s, 2, seedv, wear), s, c, c, c)

static func _lerp3(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + bb * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t

## Tube courbe (suite de troncs de cône) le long de `pts`, de `r0` à `r1`.
static func tube(b: PropMeshes.B, pts: Array, r0: float, r1: float, col: Color, seg := 7) -> void:
	var n := pts.size() - 1
	for i in n:
		var ra := lerpf(r0, r1, float(i) / n)
		var rb := lerpf(r0, r1, float(i + 1) / n)
		b.frustum(pts[i], pts[i + 1], ra, rb, seg, PropMeshes.B.jit(col, 0.06, i + 11), false)

static func bezier(a: Vector3, bb: Vector3, c: Vector3, d: Vector3, n := 12) -> Array:
	var out: Array = []
	for i in n + 1:
		out.append(_lerp3(a, bb, c, d, float(i) / n))
	return out

## Contour d'un arc brisé (équilatéral) de demi-largeur `hw`, jambages de hauteur `y0` : points de bas à gauche en bas à droite (x, y).
static func ogive(hw: float, y0: float, n := 9) -> Array:
	var r := 2.0 * hw
	var cx := r - hw
	var th_top := acos(clampf(cx / r, -1.0, 1.0))
	var left: Array = [Vector2(-hw, 0.0), Vector2(-hw, y0)]
	for i in range(1, n + 1):
		var th := th_top * float(i) / float(n)
		left.append(Vector2(cx - r * cos(th), y0 + r * sin(th)))
	var out: Array = left.duplicate()
	for i in range(left.size() - 2, -1, -1):
		var p: Vector2 = left[i]
		out.append(Vector2(-p.x, p.y))
	return out

## Panneau à arc brisé en relief sur la face +Z du repère courant : fond en retrait (teinte sombre), cadre mouluré. Origine : milieu du bas du panneau, sur la face.
static func arch_panel(b: PropMeshes.B, hw: float, y0: float, thick: float, depth: float, col: Color, back: Color, seedv := 0) -> void:
	var path := ogive(hw, y0)
	var n := path.size()
	var ctr := Vector3(0, y0 * 0.55, 0.004)
	for i in n - 1:      # fond : éventail à partir du centre
		var p0: Vector2 = path[i]
		var p1: Vector2 = path[i + 1]
		b.tri_flat(ctr, Vector3(p0.x, p0.y, 0.004), Vector3(p1.x, p1.y, 0.004), Vector3(0, 0, 1), back, back, back)
	for i in n - 1:      # cadre : bande de largeur `thick` vers l'extérieur, relief `depth`, chanfrein sur le bord extérieur
		var p0: Vector2 = path[i]
		var p1: Vector2 = path[i + 1]
		var t := (p1 - p0).normalized()
		var nm := Vector2(t.y, -t.x)
		if nm.dot(Vector2(p0.x, p0.y - y0 * 0.55)) < 0.0:
			nm = -nm
		var a_in := Vector3(p0.x, p0.y, depth)
		var b_in := Vector3(p1.x, p1.y, depth)
		var a_out := Vector3(p0.x + nm.x * thick, p0.y + nm.y * thick, depth * 0.55)
		var b_out := Vector3(p1.x + nm.x * thick, p1.y + nm.y * thick, depth * 0.55)
		var c := PropMeshes.B.jit(col, 0.06, i + seedv)
		b.tri_flat(a_in, b_in, b_out, Vector3(0, 0, 1), c, c, c)
		b.tri_flat(a_in, b_out, a_out, Vector3(0, 0, 1), c, c, c)
		var ground_in := Vector3(p0.x, p0.y, 0.0)
		var ground_in1 := Vector3(p1.x, p1.y, 0.0)
		var cs := PropMeshes.B.sh(col, 0.72)
		b.tri_flat(ground_in, ground_in1, b_in, Vector3(-nm.x, -nm.y, 0.3), cs, cs, cs)      # retour intérieur (ombre dans le creux)
		b.tri_flat(ground_in, b_in, a_in, Vector3(-nm.x, -nm.y, 0.3), cs, cs, cs)
		var ao := Vector3(p0.x + nm.x * thick, p0.y + nm.y * thick, 0.0)
		var bo := Vector3(p1.x + nm.x * thick, p1.y + nm.y * thick, 0.0)
		b.tri_flat(a_out, b_out, bo, Vector3(nm.x, nm.y, 0.2), cs, cs, cs)      # retour extérieur
		b.tri_flat(a_out, bo, ao, Vector3(nm.x, nm.y, 0.2), cs, cs, cs)

## Croix pattée en relief (face +Z), origine au centre.
static func cross_relief(b: PropMeshes.B, size: float, col: Color, seedv := 0) -> void:
	bbox(b, Vector3(0, 0, 0.012), Vector3(size * 0.09, size * 0.5, 0.014), 0.006, col, seedv + 1, 0.001)
	bbox(b, Vector3(0, size * 0.18, 0.012), Vector3(size * 0.34, size * 0.09, 0.014), 0.006, col, seedv + 2, 0.001)

## Colonnette d'angle : base, fût, chapiteau.
static func colonnette(b: PropMeshes.B, p: Vector3, h: float, r: float, col: Color) -> void:
	b.m = SURF_STONE
	b.lathe([Vector2(0.0, 0.0), Vector2(r * 1.7, 0.0), Vector2(r * 1.7, 0.03), Vector2(r * 1.25, 0.06), Vector2(r, 0.09), Vector2(r * 0.92, h - 0.1), Vector2(r * 1.2, h - 0.07),
		Vector2(r * 1.6, h - 0.04), Vector2(r * 1.6, h), Vector2(0.0, h)], 12, col, p, 0.0, 0.03, true)

# ------------------------------------------------------------------ autel

## Position des flammes des deux cierges de l'autel (repère du modèle).
const ALTAR_FLAMES := [Vector3(-0.66, 1.64, 0.0), Vector3(0.66, 1.58, 0.0)]

static func altar(b: PropMeshes.B) -> void:
	b.m = SURF_STONE
	# soubassement : deux emmarchements usés, légèrement décalés
	bbox(b, Vector3(0.0, 0.07, 0.0), Vector3(1.46, 0.07, 1.2), 0.035, ST_D, 1, 0.008)
	bbox(b, Vector3(0.0, 0.205, 0.0), Vector3(1.22, 0.065, 0.98), 0.03, PropMeshes.B.sh(ST_D, 1.08), 2, 0.007)
	# base moulurée du corps : gros bloc, filet, tore
	bbox(b, Vector3(0.0, 0.37, 0.0), Vector3(0.98, 0.1, 0.5), 0.04, ST, 3, 0.005)
	bbox(b, Vector3(0.0, 0.485, 0.0), Vector3(0.93, 0.025, 0.455), 0.015, PropMeshes.B.sh(ST, 1.06), 4, 0.003)
	# corps : trois assises irrégulières
	var y0 := 0.51
	bbox(b, Vector3(-0.58, y0 + 0.3, 0.0), Vector3(0.36, 0.3, 0.4), 0.02, ST, 5, 0.004)
	bbox(b, Vector3(0.0, y0 + 0.3, 0.0), Vector3(0.24, 0.3, 0.4), 0.02, PropMeshes.B.sh(ST, 0.94), 6, 0.004)
	bbox(b, Vector3(0.58, y0 + 0.3, 0.0), Vector3(0.36, 0.3, 0.4), 0.02, PropMeshes.B.sh(ST, 1.03), 7, 0.004)
	# panneaux en ogive sculptés sur les deux grands côtés (face avant +Z, dos -Z), croix sur le panneau central
	for side in [1.0, -1.0]:
		var old := b.push(Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3.ZERO))
		for k in 3:
			var px := -0.57 + 0.57 * k
			var o2 := b.push(Transform3D(Basis.IDENTITY, Vector3(px, y0 + 0.07, 0.4)))
			arch_panel(b, 0.2, 0.2, 0.038, 0.022, PropMeshes.B.sh(ST, 1.05), PropMeshes.B.sh(ST_D, 0.82), k + (0 if side > 0.0 else 7))
			if k == 1:
				var o3 := b.push(Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0.0)))
				cross_relief(b, 0.2, PropMeshes.B.sh(ST_L, 1.0), 3)
				b.xf = o3
			b.xf = o2
		b.xf = old
	# panneaux des petits côtés (-X, +X) : un panneau et une croix
	for side in [1.0, -1.0]:
		var old2 := b.push(Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3.ZERO))
		var o4 := b.push(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.07, 0.95)))
		arch_panel(b, 0.17, 0.2, 0.036, 0.02, PropMeshes.B.sh(ST, 1.05), PropMeshes.B.sh(ST_D, 0.82), 20)
		var o5 := b.push(Transform3D(Basis.IDENTITY, Vector3(0, 0.26, 0.0)))
		cross_relief(b, 0.16, PropMeshes.B.sh(ST_L, 1.0), 9)
		b.xf = o5
		b.xf = o4
		b.xf = old2
	# colonnettes d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			colonnette(b, Vector3(sx * 0.93, 0.5, sz * 0.43), 0.66, 0.05, PropMeshes.B.sh(ST, 1.02))
	# corniche, table (mensa) usée
	bbox(b, Vector3(0.0, 1.2, 0.0), Vector3(1.0, 0.03, 0.54), 0.015, PropMeshes.B.sh(ST, 1.04), 8, 0.004)
	bbox(b, Vector3(0.0, 1.265, 0.0), Vector3(1.08, 0.04, 0.58), 0.025, PropMeshes.B.sh(ST, 1.1), 9, 0.007)
	# gravures : bordure et croix sur la table, en creux (teinte sombre, au ras)
	var gy := 1.3055
	var gc := PropMeshes.B.sh(ST_D, 0.55)
	for e in [[Vector3(0, gy, 0.44), Vector3(0.86, 0.0006, 0.012)], [Vector3(0, gy, -0.44), Vector3(0.86, 0.0006, 0.012)],
			[Vector3(0.86, gy, 0.0), Vector3(0.012, 0.0006, 0.44)], [Vector3(-0.86, gy, 0.0), Vector3(0.012, 0.0006, 0.44)]]:
		b.box(e[0], e[1], gc)
	for e in [[Vector3(0, gy, 0.0), Vector3(0.012, 0.0006, 0.3)], [Vector3(0, gy, 0.0), Vector3(0.16, 0.0006, 0.012)]]:
		b.box(e[0], e[1], gc)
	# accessoires : étoffe, calice, livre, deux cierges
	_cloth(b)
	_chalice(b, Vector3(-0.28, 1.306, -0.04))
	_book(b, Vector3(0.28, 1.306, 0.06))
	_candle_tray(b, Vector3(-0.66, 1.306, 0.0), 0.3)
	_candle_tray(b, Vector3(0.66, 1.306, 0.0), 0.24)

## Chemin d'autel : bande d'étoffe passant sur la table et pendant devant et derrière, avec plis et franges.
static func _cloth(b: PropMeshes.B) -> void:
	b.m = MATTE
	var hw := 0.2
	var cols := 6
	var rows := 30
	var zf := 0.62                 # le bord de la table dépasse du corps : l'étoffe pend à son aplomb
	var drop := 0.2
	var pts: Array = []
	for i in rows + 1:
		var along := float(i) / rows * (2.0 * (zf + drop))      # abscisse curviligne : pendant avant, table, pendant arrière
		var p := Vector3.ZERO
		var nrm := Vector3.UP
		if along < drop:
			p = Vector3(0, 1.3 - drop + along, zf + 0.014)
			nrm = Vector3(0, 0, 1)
		elif along < drop + 2.0 * zf:
			p = Vector3(0, 1.3 + 0.012, zf - (along - drop))
		else:
			p = Vector3(0, 1.3 - (along - drop - 2.0 * zf), -zf - 0.014)
			nrm = Vector3(0, 0, -1)
		pts.append([p, nrm, along])
	for i in rows:
		for j in cols:
			var verts: Array = []
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				var d: Array = pts[q[0]]
				var x := -hw + 2.0 * hw * float(q[1]) / cols
				var fold := 0.01 * sin(x * 21.0 + float(d[2]) * 6.0) + 0.005 * sin(float(d[2]) * 14.0 + x * 7.0)
				verts.append((d[0] as Vector3) + Vector3(x, 0, 0) + (d[1] as Vector3) * fold)
			var hint: Vector3 = (pts[i][1] as Vector3) + Vector3(0, 0.1, 0)
			var c := PropMeshes.B.sh(CLOTH_G, 0.85 + 0.3 * PropMeshes.B.h(i, j, 77))
			b.tri_flat(verts[0], verts[1], verts[2], hint, c, c, c)
			b.tri_flat(verts[0], verts[2], verts[3], hint, c, c, c)
	# galons et franges aux deux extrémités
	b.m = METAL
	for s in [1.0, -1.0]:
		var zb: float = (zf + 0.02) * float(s)
		b.box(Vector3(0, 1.3 - drop + 0.04, zb), Vector3(hw + 0.005, 0.01, 0.004), GOLD_O)
		for k in 9:
			var x := -hw + 0.04 + (2.0 * hw - 0.08) * float(k) / 8.0
			b.box(Vector3(x, 1.3 - drop - 0.02, zb), Vector3(0.006, 0.026 + 0.012 * PropMeshes.B.h(k, 3, 4), 0.003), PropMeshes.B.sh(GOLD_O, 0.8))

static func _chalice(b: PropMeshes.B, p: Vector3) -> void:
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.075, 0.012), Vector2(0.03, 0.03), Vector2(0.016, 0.07), Vector2(0.034, 0.095), Vector2(0.016, 0.12),
		Vector2(0.015, 0.15), Vector2(0.065, 0.2), Vector2(0.072, 0.25), Vector2(0.06, 0.255), Vector2(0.0, 0.2)], 16, GOLD_O, p, 0.0, 0.0, true)

static func _book(b: PropMeshes.B, p: Vector3) -> void:
	b.m = MATTE
	var base := Basis(Vector3.UP, 0.35)
	b.rbox(p + Vector3(0, 0.012, 0), Vector3(0.18, 0.012, 0.13), DARK_W, base)      # couverture
	b.rbox(p + base * Vector3(-0.085, 0.032, 0), Vector3(0.082, 0.016, 0.115), Color("d9ceaa"), base * Basis(Vector3(0, 0, 1), 0.07))      # page gauche
	b.rbox(p + base * Vector3(0.085, 0.032, 0), Vector3(0.082, 0.016, 0.115), Color("e2d8b6"), base * Basis(Vector3(0, 0, 1), -0.07))      # page droite
	b.m = METAL
	b.rbox(p + base * Vector3(0.0, 0.018, 0), Vector3(0.006, 0.005, 0.118), BRONZE, base)

const DARK_W := Color("3b2814")

static func _candle_tray(b: PropMeshes.B, p: Vector3, h: float) -> void:
	b.m = METAL
	b.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.1, 0.012), Vector2(0.075, 0.03), Vector2(0.045, 0.036), Vector2(0.0, 0.034)], 14, BRONZE, p, 0.0, 0.0, true)
	b.m = MATTE
	b.lathe([Vector2(0.036, 0.03), Vector2(0.038, h * 0.5), Vector2(0.034, h), Vector2(0.0, h + 0.006)], 10, Color("e6dcbc"), p, 0.0, 0.06, true)
	b.lathe([Vector2(0.034, 0.03), Vector2(0.05, 0.036), Vector2(0.038, 0.07), Vector2(0.03, 0.05)], 8, Color("d8cca8"), p + Vector3(0.0, 0.0, 0.0), 0.0, 0.2, true)      # cire coulée au pied

# ------------------------------------------------------------------ candélabre en fer forgé

## Bougies de chaque variante : [x, hauteur de la coupelle, hauteur de la bougie].
const LIGHTS := [
	[[-0.3, 1.18, 0.17], [0.0, 1.34, 0.22], [0.3, 1.18, 0.15]],
	[[-0.42, 1.04, 0.14], [-0.22, 1.2, 0.18], [0.0, 1.38, 0.24], [0.22, 1.2, 0.2], [0.42, 1.04, 0.16]],
	[[-0.3, 1.12, 0.2], [0.0, 1.3, 0.15], [0.3, 1.2, 0.23]],
]

## Flammes d'une variante (repère du modèle).
static func flames(v: int) -> Array:
	var out: Array = []
	for l in LIGHTS[v % LIGHTS.size()]:
		out.append(Vector3(float(l[0]), float(l[1]) + 0.04 + float(l[2]) + 0.04, 0.0))
	return out

static func candelabra(b: PropMeshes.B, v: int) -> void:
	v = v % LIGHTS.size()
	b.m = METAL
	# trois pieds en volute (tubes courbes), terminés par une patte
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.5
		var dir := Vector3(sin(a), 0, cos(a))
		var pts := bezier(dir * 0.03 + Vector3(0, 0.36, 0), dir * 0.16 + Vector3(0, 0.34, 0), dir * 0.26 + Vector3(0, 0.2, 0), dir * 0.31 + Vector3(0, 0.03, 0), 10)
		tube(b, pts, 0.024, 0.017, IRON_W)
		var curl := bezier(dir * 0.31 + Vector3(0, 0.03, 0), dir * 0.36 + Vector3(0, 0.0, 0), dir * 0.39 + Vector3(0, 0.06, 0), dir * 0.35 + Vector3(0, 0.08, 0), 6)
		tube(b, curl, 0.017, 0.011, IRON_H, 6)
		b.lathe([Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.026, 0.014), Vector2(0.0, 0.016)], 8, IRON_H, dir * 0.31, 0.0, 0.0, true)
	# fût : collier, tige, nœuds, bague
	b.lathe([Vector2(0.0, 0.3), Vector2(0.07, 0.3), Vector2(0.075, 0.33), Vector2(0.05, 0.36), Vector2(0.026, 0.4), Vector2(0.024, 0.62), Vector2(0.05, 0.66), Vector2(0.06, 0.7),
		Vector2(0.05, 0.74), Vector2(0.024, 0.78), Vector2(0.024, 1.0), Vector2(0.044, 1.03), Vector2(0.05, 1.07), Vector2(0.044, 1.1), Vector2(0.022, 1.13), Vector2(0.022, 1.3),
		Vector2(0.0, 1.3)], 12, IRON_W, Vector3.ZERO, 0.0, 0.04, true)
	b.hoop(0.045, 0.52, 0.02, 0.012, IRON_H, 10)
	# bras en S, un par de volutes par côté, jusqu'aux coupelles à pointe
	for l in LIGHTS[v]:
		var x := float(l[0])
		var yc := float(l[1])
		if absf(x) > 0.01:
			var sg := signf(x)
			var pts := bezier(Vector3(0, 1.02 + 0.03 * absf(x) * 4.0, 0), Vector3(x * 0.95, 1.0, 0), Vector3(x * 1.12, yc - 0.16, 0), Vector3(x, yc - 0.02, 0), 14)
			tube(b, pts, 0.017, 0.013, IRON_W)
			# petite volute décorative sous le bras
			var sc := bezier(Vector3(x * 0.55, 1.0 + 0.015 * absf(x) * 4.0, 0), Vector3(x * 0.55, 0.9, 0), Vector3(x * 0.3, 0.92, 0), Vector3(x * 0.3, 1.0, 0), 8)
			tube(b, sc, 0.011, 0.008, IRON_H, 6)
			b.ellipsoid(Vector3(x * 0.5, 1.0 + 0.012 * absf(x) * 4.0, 0), Vector3(0.016, 0.016, 0.016), IRON_H, 6, 3)
		# coupelle (bobèche) et pointe
		b.lathe([Vector2(0.0, yc - 0.03), Vector2(0.03, yc - 0.03), Vector2(0.045, yc), Vector2(0.075, yc + 0.018), Vector2(0.07, yc + 0.026), Vector2(0.03, yc + 0.012), Vector2(0.0, yc + 0.014)], 12, IRON_H, Vector3(x, 0, 0), 0.0, 0.0, true)
		b.frustum(Vector3(x, yc + 0.01, 0), Vector3(x, yc + 0.05, 0), 0.008, 0.002, 5, IRON_H, false)
	# cierges : hauteurs différentes, cire irrégulière avec coulures
	b.m = MATTE
	var vi := 0
	for l in LIGHTS[v]:
		var x := float(l[0])
		var yc := float(l[1])
		var hc := float(l[2])
		var cw := PropMeshes.B.jit(Color("e4d9b8"), 0.07, v * 5 + vi)
		b.lathe([Vector2(0.03, yc + 0.02), Vector2(0.032, yc + hc * 0.5), Vector2(0.028 + 0.004 * PropMeshes.B.h(vi, v, 2), yc + hc), Vector2(0.0, yc + hc + 0.006)], 10, cw, Vector3(x, 0, 0), 0.0, 0.08, true)
		b.lathe([Vector2(0.028, yc + hc * 0.6), Vector2(0.04, yc + hc * 0.55), Vector2(0.034, yc + hc * 0.3), Vector2(0.03, yc + hc * 0.3)], 6, PropMeshes.B.sh(cw, 0.92), Vector3(x + 0.0, 0, 0.0), 0.0, 0.3, true)      # coulure
		vi += 1
