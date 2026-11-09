class_name LavaBreach
extends RefCounted
## Brèches de lave du thème « lava » v2 : à quelques endroits, le mur est éventré par une ouverture irrégulière (roche brisée) qui donne sur une cavité
## où la lave coule derrière la pierre. On voit tout de suite que c'est dangereux, sans qu'une texture soit posée sur le mur : c'est un vrai trou.
## PUREMENT VISUEL : la brèche ne s'ouvre que dans un mur plein (zéro épaisseur) et reste à moins de 1,7 u derrière lui, dans la roche pleine ; rien dans la
## grille, le générateur, les collisions, les déplacements ou le rejeu. Choix déterministe : grille et identifiant du niveau seulement (jamais GameRng).
## Maillage : le pourtour de l'ouverture est une couronne de triangles entre un polygone irrégulier (16 sommets, rayons variables) et le bord du pan de mur,
## les ébrasements sont en pierre du thème, le fond et la rampe du bas sont de la magma pleine nappe (shader magma, état « nappe », sens d'écoulement global).

const CELL := LevelBuilder.CELL
const HALF := CELL * 0.5
const N_ANG := 16
const SPACING := 2            # écart minimal entre deux brèches (cases, Tchebychev)

static var _cache_key := ""
static var _cache: Dictionary = {}

static func applies(level: Dictionary) -> bool:
	return LavaFx.enabled and str(level.get("theme", "")) == "lava" and ThemeMaterials.lava2_on("lava") and not bool(level.get("outdoor", false))

static func _h(a: int, b: int, c: int) -> int:
	return KitDecor._h(a, b, c)

static func _f(hh: int, k: int) -> float:
	return float(_h(hh, k, 29) % 10000) / 10000.0

## Cases à éviter : objets, marchand, escaliers, départ, monstres, creux de murs (sans passer par RoomDecor : pas de boucle).
static func _excluded(level: Dictionary, niches: Dictionary) -> Dictionary:
	var out := {}
	for it in level.get("items", []):
		out[Vector2i(int(it.get("x", -1)), int(it.get("y", -1)))] = true
	var tm = level.get("travelingMerchant")
	if tm is Dictionary:
		out[Vector2i(int(tm.get("x", -1)), int(tm.get("y", -1)))] = true
	for st in level.get("stairs", []):
		out[Vector2i(int(st.get("x", -1)), int(st.get("y", -1)))] = true
	for m in level.get("monsters", []):
		out[Vector2i(int(m.get("x", -1)), int(m.get("y", -1)))] = true
	out[Vector2i(int(level.get("startX", -1)), int(level.get("startY", -1)))] = true
	for c in niches:
		out[c] = true
	return out

## Brèches du niveau : "x,y,dx,dy" -> {x, y, d, hh, s (décalage le long du mur), tc (centre de l'ouverture, repère du pan), depth}.
## `niches` : creux déjà décidés (fontaine, marchand), voir LevelBuilder.niche_data.
static func select(grid: DungeonGrid, level: Dictionary, niches: Dictionary, force: bool = false) -> Dictionary:
	var key := "%s|%d|%d|%d" % [str(level.get("id", "")), grid.width, str(level.get("mapRows", [])).hash(), str(level.get("items", [])).hash() ^ str(level.get("monsters", [])).hash()]
	if not force and key == _cache_key:
		return _cache
	var out := {}
	if applies(level):
		var seed := str(level.get("id", "")).hash()
		var special := _excluded(level, niches)
		var ridx := RoomMap.index(RoomMap.detect(level.mapRows))
		var rsize := {}
		for c in ridx:
			rsize[ridx[c]] = int(rsize.get(ridx[c], 0)) + 1
		var taken: Array = []
		for y in grid.height:
			for x in grid.width:
				if grid.cell(x, y) != ".":
					continue
				var cell := Vector2i(x, y)
				if special.has(cell) or KitDecor._near_special(special, grid, cell, 1):
					continue
				var opens: Array = []
				for di in 4:
					var d0: Vector2i = DungeonGrid.DIRS[di]
					if grid.cell(x + d0.x, y + d0.y) != "#":
						opens.append(d0)
				var near := false
				for q in taken:
					if maxi(absi(q.x - x), absi(q.y - y)) <= SPACING:
						near = true
						break
				if near:
					continue
				var big := ridx.has(cell) and int(rsize.get(ridx[cell], 0)) >= 12
				for di in 4:
					var d: Vector2i = DungeonGrid.DIRS[di]
					if grid.cell(x + d.x, y + d.y) != "#":
						continue
					# le mur doit être épais d'au moins une case pleine derrière, et plein de chaque côté de l'ouverture
					if grid.cell(x + d.x * 2, y + d.y * 2) != "#":
						continue
					var hh := _h(x, y, seed ^ (di * 977 + 13))
					var dead_end: bool = opens.size() == 1 and (opens[0] as Vector2i) == -d
					var corner: bool = opens.size() == 2 and (opens[0] as Vector2i).x != (opens[1] as Vector2i).x and (opens[0] as Vector2i).y != (opens[1] as Vector2i).y
					var denom: int = 3 if dead_end else (5 if corner else (5 if big else 9))
					if (hh >> 4) % denom != 0:
						continue
					var torch := (x + y) % 2 == 0      # une torche au centre de ce pan : la brèche est décalée de côté
					var s := 0.0
					if torch:
						s = 0.95 if (hh >> 20) % 2 == 0 else -0.95
					else:
						s = (_f(hh, 1) - 0.5) * 0.5
					out["%d,%d,%d,%d" % [x, y, d.x, d.y]] = {"x": x, "y": y, "d": d, "hh": hh, "s": s, "tc": -0.5 + _f(hh, 2) * 0.28, "depth": 1.15 + _f(hh, 3) * 0.45}
					taken.append(cell)
					break
	_cache_key = key
	_cache = out
	return out

## Cases portant une brèche (pour tenir les accessoires de salle à l'écart).
static func cells(grid: DungeonGrid, level: Dictionary, niches: Dictionary) -> Dictionary:
	var out := {}
	for k in select(grid, level, niches):
		var sp: Dictionary = select(grid, level, niches)[k]
		out[Vector2i(int(sp.x), int(sp.y))] = true
	return out

## Point (monde) où poser la lueur de la brèche.
static func anchor(sp: Dictionary) -> Vector3:
	var d: Vector2i = sp.d
	var dv := Vector3(d.x, 0.0, d.y)
	var right := Vector3.UP.cross(-dv)
	return Vector3(int(sp.x) * CELL, 0.0, int(sp.y) * CELL) + dv * (HALF + 0.55) + right * float(sp.s) + Vector3(0, HALF + float(sp.tc) + 0.2, 0)

# ------------------------------------------------------------------ maillage

## Ajoute la brèche : couronne de mur et ébrasements dans les surfaces `wall` du bloc, magma dans la surface `magma`.
static func build(parts: Dictionary, counts: Dictionary, sp: Dictionary) -> void:
	var d: Vector2i = sp.d
	var dv := Vector3(d.x, 0.0, d.y)
	var n := -dv
	var right := Vector3.UP.cross(n)
	var wc := Vector3(int(sp.x) * CELL, 0.0, int(sp.y) * CELL) + dv * HALF + Vector3(0, HALF, 0)
	var hh: int = sp.hh
	var s0: float = sp.s
	var tc: float = sp.tc
	var depth: float = sp.depth
	var wall: SurfaceTool = parts["wall"]
	var magma: SurfaceTool = parts["magma"]
	# angles : les quatre coins du pan, plus trois angles intermédiaires entre deux coins (le pourtour touche les coins exactement)
	var corner_ang: Array = []
	for cc in [Vector2(2.0 - s0, 2.0 - tc), Vector2(-2.0 - s0, 2.0 - tc), Vector2(-2.0 - s0, -2.0 - tc), Vector2(2.0 - s0, -2.0 - tc)]:
		corner_ang.append(fposmod(atan2(cc.y, cc.x), TAU))
	corner_ang.sort()
	var angs: Array = []
	var is_corner: Array = []
	for k in 4:
		var a0: float = corner_ang[k]
		var a1: float = corner_ang[(k + 1) % 4] + (TAU if k == 3 else 0.0)
		for j in 4:
			angs.append(a0 + (a1 - a0) * float(j) / 4.0)
			is_corner.append(j == 0)
	var ax := 0.50 + 0.16 * _f(hh, 4)
	var by := 0.98 + 0.14 * _f(hh, 5)
	var pp: Array = []      # polygone de l'ouverture (s, t)
	var qq: Array = []      # point du bord du pan sur le même rayon
	var rr: Array = []      # polygone du fond de l'ébrasement
	for i in N_ANG:
		var a: float = angs[i]
		var cs := cos(a)
		var sn := sin(a)
		var rad := 0.70 + 0.46 * _f(hh, 10 + i)      # roche brisée : rayon irrégulier
		if i % 2 == 1:
			rad *= 0.85
		var ps := s0 + cs * ax * rad
		var pt := tc + sn * by * rad
		pp.append(Vector2(ps, pt))
		var tmax := 1e9
		if absf(cs) > 1e-5:
			tmax = minf(tmax, ((2.0 if cs > 0.0 else -2.0) - s0) / cs)
		if absf(sn) > 1e-5:
			tmax = minf(tmax, ((2.0 if sn > 0.0 else -2.0) - tc) / sn)
		var qs := s0 + cs * tmax
		var qt := tc + sn * tmax
		if absf(absf(qs) - 2.0) < 1e-3:
			qs = 2.0 if qs > 0.0 else -2.0
		if absf(absf(qt) - 2.0) < 1e-3:
			qt = 2.0 if qt > 0.0 else -2.0
		qq.append(Vector2(qs, qt))
		rr.append(Vector2(s0 + (ps - s0) * 0.80, tc + (pt - tc) * 0.78 - (0.12 if sn < -0.3 else 0.0)))
	var P := func(v: Vector2, z: float) -> Vector3: return wc + right * v.x + Vector3.UP * v.y + dv * z
	var wuv := func(v: Vector2) -> Vector2: return Vector2((v.x + HALF) / CELL, 1.0 - (v.y + HALF) / CELL)
	var piv: Vector3 = P.call(Vector2(s0, tc), depth * 0.5)
	var perim := 0.0
	for i in N_ANG:
		var j := (i + 1) % N_ANG
		# couronne : pourtour de l'ouverture -> bord du pan
		var a0: Vector2 = pp[i]
		var a1: Vector2 = pp[j]
		var b0: Vector2 = qq[i]
		var b1: Vector2 = qq[j]
		_tri(wall, P.call(a0, 0.0), P.call(b0, 0.0), P.call(b1, 0.0), n, wuv.call(a0), wuv.call(b0), wuv.call(b1))
		_tri(wall, P.call(a0, 0.0), P.call(b1, 0.0), P.call(a1, 0.0), n, wuv.call(a0), wuv.call(b1), wuv.call(a1))
		# ébrasement : de l'ouverture au fond (pierre en haut et sur les côtés, magma en rampe dans le bas)
		var ai := fposmod(float(angs[i]), TAU)
		var aj := fposmod(float(angs[j]), TAU)
		var lower: bool = ai > PI * 1.1 and ai < PI * 1.9 and aj > PI * 1.1 and aj < PI * 1.9 and aj > ai
		var r0: Vector2 = rr[i]
		var r1: Vector2 = rr[j]
		var seg := a0.distance_to(a1)
		var u0 := perim / CELL
		var u1 := (perim + seg) / CELL
		perim += seg
		var A := P.call(a0, 0.0) as Vector3
		var B := P.call(a1, 0.0) as Vector3
		var C := P.call(r1, depth) as Vector3
		var D := P.call(r0, depth) as Vector3
		var mid := (A + B + C + D) * 0.25
		var toward := (piv - mid)
		if lower:
			var ul := Vector2(0.55, 0.0)
			var uf := Vector2(0.9, 0.0)
			_tri(magma, A, B, C, Vector3.UP, ul, ul, uf)
			_tri(magma, A, C, D, Vector3.UP, ul, uf, uf)
		else:
			_tri(wall, A, B, C, toward, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, depth / CELL))
			_tri(wall, A, C, D, toward, Vector2(u0, 0.0), Vector2(u1, depth / CELL), Vector2(u0, depth / CELL))
		# fond : nappe de lave
		_tri(magma, P.call(Vector2(s0, tc), depth), D, C, n, Vector2(1.0, 0.0), Vector2(0.9, 0.0), Vector2(0.9, 0.0))
	counts["wall"] += 2 * N_ANG * 2
	counts["magma"] += 2 * N_ANG

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var ng := (c - a).cross(b - a)
	if ng.length_squared() < 1e-10:
		return
	if ng.dot(n) < 0.0:      # face avant du côté de la normale voulue
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	var nn := n.normalized()
	LevelBuilder._v(st, a, nn, ua)
	LevelBuilder._v(st, b, nn, ub)
	LevelBuilder._v(st, c, nn, uc)
