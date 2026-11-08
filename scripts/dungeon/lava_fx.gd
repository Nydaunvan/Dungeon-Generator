class_name LavaFx
extends RefCounted
## Magma décorative du thème « lava » v2 (Les Forges du monde brisé). PUREMENT VISUEL : aucun nœud de collision, rien dans la grille, le générateur, les
## déplacements, les portes, les escaliers ou le rejeu. Placement déterministe : uniquement la grille et l'identifiant du niveau (jamais GameRng ni le hasard global).
##
## Quatre sortes d'éléments (rares, jamais au milieu d'un mur intact sans raison : impasses, angles, salles, puis très peu de couloirs droits) :
##   « frac_mur » / « frac_sol » : fractures volcaniques. Vrai maillage en ruban irrégulier (largeur variable, pointes effilées qui se perdent en fissure noire),
##       lèvres de croûte refroidie en relief des deux côtés, cœur incandescent en cuvette. Aucune plaque : le contour est la géométrie, pas un masque.
##   « canal » : conduit de forge. Gueule de basalte scellée au mur (la magma en sort), rigole encadrée de rebords de pierre, grille de fer noirci où elle s'engouffre.
##   « suintement » : fracture haute d'où s'écoule une langue épaisse qui s'élargit, puis s'accumule en ménisque sur la plinthe.
## Matériau (assets/shaders/magma.gdshader) : croûte noire, rouge sombre, orange, rares zones jaune-orangé ; trois états (presque refroidie / active / très chaude) ;
## animation lente sur TIME seulement. Lumières : seulement canaux, suintements et quelques fractures très chaudes, sans ombre, peu de brume volumétrique.

const CELL := LevelBuilder.CELL
const HALF := CELL * 0.5
const SHADER := "res://assets/shaders/magma.gdshader"
const MAX_LIGHTS := 6
const LIGHT_GAP := 12.0         # écart minimal entre deux lumières de magma (unités)
const MAX_EMBERS := 14
const MAX_SMOKE := 6
const SPACING := 2              # écart minimal entre deux éléments (cases, distance de Tchebychev)
const LIP_N := 0.05             # hauteur des lèvres de croûte au-dessus du mur ou du sol
const WALL_OFF := 0.03          # le ruban de mur est posé à 3 cm devant le plan du mur (jamais de Z-fighting, jamais flottant : la lèvre et le cœur épousent le mur)
## Dernier niveau posé : {"items": n, "frac_mur": n, ..., "lights": n, "embers": n, "smoke": n} (tests, mesures).
static var last_stats: Dictionary = {}
## Interrupteurs (outils) : false = ne pose pas l'élément.
static var enabled := true
static var effects := true
## Outils seulement : impose la sorte d'élément (et une densité élevée) pour inspecter chaque variante.
static var force_kind := ""

static var _shader: Shader
static var _mats: Array = []
static var _lip_mat: StandardMaterial3D
static var _channel_mesh: ArrayMesh
static var _ember_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _ember_mesh: QuadMesh
static var _smoke_mesh: QuadMesh

static func applies(theme: String, level: Dictionary) -> bool:
	return enabled and theme == "lava" and ThemeMaterials.lava2_on(theme) and not bool(level.get("outdoor", false))

static func _h(a: int, b: int, c: int) -> int:
	return KitDecor._h(a, b, c)

## Réel stable dans [0, 1) tiré d'une graine d'élément et d'un indice.
static func _f(hh: int, k: int) -> float:
	return float(_h(hh, k, 17) % 10000) / 10000.0

## Matériau partagé de l'état `s` (0 presque refroidie, 1 active, 2 très chaude).
static func material(s: int) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	while _mats.size() < 3:
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("state", float(_mats.size()))
		_mats.append(m)
	return _mats[clampi(s, 0, 2)]

## Pierre refroidie des lèvres : celle des murs du thème, plus sombre.
static func lip_material() -> StandardMaterial3D:
	if _lip_mat == null:
		var wall := ThemeMaterials.for_theme("lava").get("wall") as StandardMaterial3D
		if wall != null and wall.albedo_texture != null:
			_lip_mat = wall.duplicate() as StandardMaterial3D
			_lip_mat.uv1_triplanar = true
			_lip_mat.uv1_world_triplanar = true
			_lip_mat.uv1_scale = Vector3.ONE * 0.5
			_lip_mat.albedo_color = Color(0.34, 0.32, 0.32)
		else:
			_lip_mat = StandardMaterial3D.new()
			_lip_mat.albedo_color = Color(0.05, 0.045, 0.045)
		_lip_mat.vertex_color_use_as_albedo = true
		_lip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _lip_mat

# ------------------------------------------------------------------ plan

## Plan de pose (pur calcul) : {"items": [{kind, x, y, di, edge, t, d, hh, state}], "lights": [{pos, state}], "embers": [{pos, state}], "smoke": [{pos}]}.
static func plan(level: Dictionary, grid: DungeonGrid, niches: Dictionary, holes: Dictionary) -> Dictionary:
	var seed := str(level.get("id", "")).hash()
	var special := KitDecor._special_cells(level, RoomDecor._blocked_cells(level), niches)
	var ridx := RoomMap.index(RoomMap.detect(level.mapRows))
	var rsize := {}
	for c in ridx:
		rsize[ridx[c]] = int(rsize.get(ridx[c], 0)) + 1
	var items: Array = []
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
				var d: Vector2i = DungeonGrid.DIRS[di]
				if grid.cell(x + d.x, y + d.y) != "#":
					opens.append(d)
			var big := ridx.has(cell) and int(rsize.get(ridx[cell], 0)) >= 12
			var near_taken := false
			for q in taken:
				if maxi(absi(q.x - x), absi(q.y - y)) <= SPACING:
					near_taken = true
					break
			if near_taken:
				continue
			for di in 4:
				var d: Vector2i = DungeonGrid.DIRS[di]
				if grid.cell(x + d.x, y + d.y) != "#" or KitDecor._face_cut(cell, d, niches, holes):
					continue
				var hh := _h(x, y, seed ^ (di * 2713 + 41))
				# cohérence du lieu : impasse (mur du fond) > angle > salle > couloir droit, jamais au hasard au milieu d'un mur intact
				var dead_end: bool = opens.size() == 1 and (opens[0] as Vector2i) == -d
				var corner: bool = opens.size() == 2 and (opens[0] as Vector2i).x != (opens[1] as Vector2i).x and (opens[0] as Vector2i).y != (opens[1] as Vector2i).y
				var denom: int = 2 if dead_end else (6 if corner else (7 if big else (22 if opens.size() == 2 else 16)))
				if force_kind != "":
					denom = 3
				if (hh >> 4) % denom != 0:
					continue
				var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
				var odd: bool = (x + y) % 2 != 0
				var orn: bool = _h(x, y, seed ^ (di * 131 + 7)) % 4 == 0      # ce pan porte (peut-être) un ornement du kit
				var r := (hh >> 9) % 100
				var kind := ""
				if big or opens.size() > 2:
					kind = "canal" if r < 35 else ("frac_sol" if r < 60 else ("frac_mur" if r < 90 else "suintement"))
				elif dead_end or corner:
					kind = "frac_mur" if r < 45 else ("suintement" if r < 65 else ("canal" if r < 82 else "frac_sol"))
				else:
					kind = "frac_sol" if r < 45 else ("frac_mur" if r < 85 else ("suintement" if r < 93 else "canal"))
				if force_kind != "":
					kind = force_kind
				var shift := 0.0
				if (kind == "frac_mur" or kind == "suintement" or kind == "canal") and (not odd or orn):
					shift = 0.95 if (hh >> 20) % 2 == 0 else -0.95      # torche ou ornement au centre du pan : l'élément est décalé de ce côté, jamais dessus
				var state := 0 if (hh >> 14) % 10 < 2 else (1 if (hh >> 14) % 10 < 7 else 2)
				if kind == "canal" or kind == "suintement":
					state = maxi(state, 1)
				var c := Vector3(x * CELL, 0.0, y * CELL)
				items.append({"kind": kind, "x": x, "y": y, "di": di, "edge": c + Vector3(d.x * HALF, 0.0, d.y * HALF) + Vector3(t.x, 0.0, t.y) * shift, "shift": shift, "t": t, "d": d, "hh": hh, "state": state})
				taken.append(cell)
				break
	# lumières (canaux, suintements, fractures très chaudes), braises, fumée : écart minimal, nombre limité
	var lights: Array = []
	var embers: Array = []
	var smoke: Array = []
	var lpos: Array = []
	for it in items:
		var ap := _anchor(it)
		var warm: bool = it.kind == "canal" or it.kind == "suintement" or int(it.state) == 2
		var far := true
		for q in lpos:
			if (q as Vector3).distance_to(ap) < LIGHT_GAP:
				far = false
				break
		if warm and far and lights.size() < MAX_LIGHTS:
			lights.append({"pos": ap + Vector3(0, 0.7, 0), "state": maxi(int(it.state), 1)})
			lpos.append(ap)
		if (warm or _f(int(it.hh), 5) < 0.4) and int(it.state) >= 1 and embers.size() < MAX_EMBERS:
			embers.append({"pos": ap, "state": int(it.state)})
		if (it.kind == "canal" or it.kind == "suintement") and smoke.size() < MAX_SMOKE:
			smoke.append({"pos": ap})
	return {"items": items, "lights": lights, "embers": embers, "smoke": smoke}

## Point d'ancrage des effets d'un élément : au-dessus de la partie incandescente, côté case.
static func _anchor(it: Dictionary) -> Vector3:
	var d: Vector2i = it.d
	var dv := Vector3(d.x, 0.0, d.y)
	match str(it.kind):
		"canal":
			return (it.edge as Vector3) - dv * 1.5 + Vector3(0, 0.1, 0)
		"suintement":
			return (it.edge as Vector3) - dv * 0.35 + Vector3(0, 0.6, 0)
		"frac_mur":
			return (it.edge as Vector3) - dv * 0.35 + Vector3(0, 1.4, 0)
	return (it.edge as Vector3) - dv * 0.9 + Vector3(0, 0.1, 0)

# ------------------------------------------------------------------ maillages

## Point du repère de l'élément : mur (u le long du mur, a la hauteur, n l'écart au mur) ou sol (u le long du mur, a l'écart au mur, n la hauteur).
static func _pos(it: Dictionary, wall: bool, u: float, a: float, n: float) -> Vector3:
	var t: Vector2i = it.t
	var d: Vector2i = it.d
	var e: Vector3 = it.edge
	var tv := Vector3(t.x, 0.0, t.y)
	var dv := Vector3(d.x, 0.0, d.y)
	if wall:
		return e + tv * u + Vector3(0, a, 0) - dv * n
	return e + tv * u - dv * a + Vector3(0, n, 0)

static func _out(it: Dictionary, wall: bool) -> Vector3:
	var d: Vector2i = it.d
	return -Vector3(d.x, 0.0, d.y) if wall else Vector3.UP

static func _tv(it: Dictionary, wall: bool, dir: Vector2) -> Vector3:
	var t: Vector2i = it.t
	var tv := Vector3(t.x, 0.0, t.y)
	var d: Vector2i = it.d
	var dv := Vector3(d.x, 0.0, d.y)
	return tv * dir.x + (Vector3.UP if wall else -dv) * dir.y

static func _group(groups: Dictionary, key: String, it: Dictionary) -> Dictionary:
	var span := CELL * float(LevelBuilder.CHUNK)
	var e: Vector3 = it.edge
	var k := "%s|%d|%d" % [key, int(floor((e.x + HALF) / span)), int(floor((e.z + HALF) / span))]
	if not groups.has(k):
		groups[k] = {"key": key, "v": [], "n": [], "c": [], "uv": []}
	return groups[k]

static func _tri(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var ng := (c - a).cross(b - a)
	if ng.length_squared() < 1e-10:
		return
	if ng.dot(na + nb + nc) < 0.0:      # face avant du côté des normales (sens horaire = face avant)
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
		var tc := cb
		cb = cc
		cc = tc
		var tu := ub
		ub = uc
		uc = tu
	(g.v as Array).append_array([a, b, c])
	(g.n as Array).append_array([na, nb, nc])
	(g.c as Array).append_array([ca, cb, cc])
	(g.uv as Array).append_array([ua, ub, uc])

## Ruban irrégulier le long d'un chemin 2D `pts` (u, a) : demi-largeur du cœur `w[i]` (0 aux pointes), lèvres de croûte `lipw[i]` de chaque côté.
## Cœur : 5 colonnes en cuvette (COLOR.r = position -1..1 en travers, pour le shader), lèvres : bandes relevées en pente douce vers l'extérieur.
static func _ribbon(groups: Dictionary, it: Dictionary, wall: bool, pts: Array, w: Array, lipw: Array, state: int, uv0: float, n0: float = 0.0, lips: bool = true) -> void:
	var cnt := pts.size()
	if cnt < 2:
		return
	var base := (WALL_OFF if wall else 0.012) + n0
	var out := _out(it, wall)
	var tang: Array = []
	var nrm: Array = []
	var lens: Array = [0.0]
	for i in cnt:
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, cnt - 1)]
		var tg := (b - a).normalized()
		tang.append(tg)
		nrm.append(Vector2(-tg.y, tg.x))
		if i > 0:
			lens.append(float(lens[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
	var cols := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var gc: Dictionary = _group(groups, "s%d" % state, it)
	var gl: Dictionary = _group(groups, "lip", it)
	var hh := int(it.hh)
	for i in cnt - 1:
		for k in 4:
			var q: Array = []
			for pr in [[i, cols[k]], [i + 1, cols[k]], [i + 1, cols[k + 1]], [i, cols[k + 1]]]:
				var ii: int = pr[0]
				var cc: float = pr[1]
				var p2: Vector2 = pts[ii] + (nrm[ii] as Vector2) * float(w[ii]) * float(cc)
				var hgt := base + LIP_N * 0.55 - 0.03 * (1.0 - float(cc) * float(cc))      # cuvette : le centre est plus bas que les bords
				q.append({"p": _pos(it, wall, p2.x, p2.y, hgt), "c": Color(float(cc), float(lens[ii]) / maxf(float(lens[cnt - 1]), 0.01), 0.0, 1.0),
					"uv": Vector2(uv0 + float(lens[ii]), float(cc) * float(w[ii]))})
			var o: Vector3 = out
			if (w[i] as float) > 0.003 or (w[i + 1] as float) > 0.003:
				_tri(gc, q[0].p, q[1].p, q[2].p, o, o, o, q[0].c, q[1].c, q[2].c, q[0].uv, q[1].uv, q[2].uv)
				_tri(gc, q[0].p, q[2].p, q[3].p, o, o, o, q[0].c, q[2].c, q[3].c, q[0].uv, q[2].uv, q[3].uv)
		if not lips:
			continue
		for s in [-1.0, 1.0]:
			var qq: Array = []
			for ii in [i, i + 1]:
				var n2: Vector2 = nrm[ii]
				var inner: Vector2 = pts[ii] + n2 * float(w[ii]) * float(s)
				var outer: Vector2 = pts[ii] + n2 * (float(w[ii]) + float(lipw[ii])) * float(s)
				var sh := 0.55 + 0.4 * _f(hh, 40 + ii * 3 + (0 if s < 0.0 else 1))      # croûte inégale, plus ou moins claire
				var tilt := (_tv(it, wall, n2 * float(s)) * 0.8 + out).normalized()      # pente vers l'extérieur : la lèvre accroche la lumière
				qq.append({"pi": _pos(it, wall, inner.x, inner.y, base + LIP_N), "po": _pos(it, wall, outer.x, outer.y, base + 0.012), "col": Color(sh, sh, sh, 1.0), "nn": tilt})
			var a0: Dictionary = qq[0]
			var b0: Dictionary = qq[1]
			_tri(gl, a0.pi, b0.pi, b0.po, a0.nn, b0.nn, b0.nn, a0.col, b0.col, b0.col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_tri(gl, a0.pi, b0.po, a0.po, a0.nn, b0.nn, a0.nn, a0.col, b0.col, a0.col, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

## Chemin de fracture : de `a0` à `a1` (parcours principal le long de `axis`), avec méandre déterministe ; renvoie {pts, w, lipw}.
## Les deux premiers et derniers échantillons ont un cœur de largeur 0 : le ruban s'effile en fissure noire qui se perd dans la roche.
static func _fracture(hh: int, k0: int, u0: float, a0: float, u1: float, a1: float, wmax: float, drift: float, n: int = 38) -> Dictionary:
	var pts: Array = []
	var w: Array = []
	var lipw: Array = []
	var ph := _f(hh, k0) * TAU
	var ph2 := _f(hh, k0 + 1) * TAU
	var amp := drift * (0.5 + _f(hh, k0 + 2))
	for i in n:
		var s := float(i) / float(n - 1)
		var wob := sin(s * 6.1 + ph) * 0.65 + sin(s * 11.3 + ph2) * 0.35      # méandre en deux fréquences
		var u := lerpf(u0, u1, s)
		var a := lerpf(a0, a1, s)
		# le méandre est perpendiculaire à l'axe principal
		var dir := Vector2(u1 - u0, a1 - a0).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var p := Vector2(u, a) + perp * wob * amp
		pts.append(p)
		var core := smoothstep(0.10, 0.28, s) * (1.0 - smoothstep(0.72, 0.90, s))      # pointes effilées
		var var_w := 0.55 + 0.45 * (0.5 + 0.5 * sin(s * 11.0 + ph * 1.7)) * (0.6 + 0.4 * _f(hh, k0 + 3 + i % 5))      # largeur de cœur variable
		w.append(wmax * core * var_w)
		lipw.append(0.022 + 0.42 * wmax * core * var_w + 0.025 * sin(s * 9.0 + ph2) * 0.5 + 0.02 * (1.0 - absf(s - 0.5) * 2.0))
	return {"pts": pts, "w": w, "lipw": lipw}

static func _build_item(groups: Dictionary, parts: Array, it: Dictionary) -> void:
	var hh := int(it.hh)
	var st := int(it.state)
	var uv0 := _f(hh, 1) * 40.0
	match str(it.kind):
		"frac_mur":
			var ut := (_f(hh, 2) - 0.5) * (1.2 if absf(float(it.shift)) < 0.1 else 0.3)
			var len_ := 1.5 + _f(hh, 3) * 1.1
			var top := 2.65 + _f(hh, 4) * 0.35
			var f := _fracture(hh, 10, ut, top, ut + (_f(hh, 6) - 0.5) * 0.9, top - len_, 0.07 + 0.05 * _f(hh, 7), 0.22)
			_ribbon(groups, it, true, f.pts, f.w, f.lipw, st, uv0)
			if _f(hh, 8) < 0.55:      # branche secondaire née du tracé principal
				var si := 9 + int(_f(hh, 9) * 5.0)
				var p0: Vector2 = f.pts[si]
				var sg := -1.0 if _f(hh, 11) < 0.5 else 1.0
				var f2 := _fracture(hh, 30, p0.x, p0.y, p0.x + sg * (0.45 + 0.3 * _f(hh, 12)), p0.y - 0.5 - 0.4 * _f(hh, 13), 0.035, 0.08, 12)
				_ribbon(groups, it, true, f2.pts, f2.w, f2.lipw, st, uv0 + 17.0, 0.004)
		"frac_sol":
			var len2 := 2.3 + _f(hh, 3) * 2.4
			var uc := (_f(hh, 2) - 0.5) * 0.6
			var v0 := 0.55 + _f(hh, 4) * 0.7
			var f3 := _fracture(hh, 10, uc - len2 * 0.5, v0, uc + len2 * 0.5, v0 + (_f(hh, 6) - 0.5) * 0.8, 0.10 + 0.08 * _f(hh, 7), 0.2)
			_ribbon(groups, it, false, f3.pts, f3.w, f3.lipw, st, uv0)
			if _f(hh, 8) < 0.5:
				var si2 := 8 + int(_f(hh, 9) * 6.0)
				var q0: Vector2 = f3.pts[si2]
				var f4 := _fracture(hh, 30, q0.x, q0.y, q0.x + (_f(hh, 12) - 0.5) * 0.5, q0.y + 0.5 + 0.4 * _f(hh, 13), 0.05, 0.07, 12)
				_ribbon(groups, it, false, f4.pts, f4.w, f4.lipw, st, uv0 + 17.0, 0.004)
		"suintement":
			# fracture haute (source identifiable) puis langue qui descend, s'épaissit, et s'accumule en ménisque sur la plinthe
			var ut2 := (_f(hh, 2) - 0.5) * (0.8 if absf(float(it.shift)) < 0.1 else 0.2)
			var src := _fracture(hh, 10, ut2 + 0.40, 3.10, ut2, 2.40, 0.04, 0.05, 14)
			_ribbon(groups, it, true, src.pts, src.w, src.lipw, st, uv0)
			var pts: Array = []
			var w: Array = []
			var lw: Array = []
			var n := 32
			var ph := _f(hh, 20) * TAU
			for i in n:
				var s := float(i) / float(n - 1)
				var y := lerpf(2.36, 0.40, s)
				var u := ut2 + sin(s * 5.0 + ph) * 0.07 + (s * s) * (_f(hh, 21) - 0.5) * 0.3
				pts.append(Vector2(u, y))
				var wd := lerpf(0.02, 0.085, smoothstep(0.0, 0.5, s)) * (0.8 + 0.25 * sin(s * 13.0 + ph))      # épaisseur variable
				wd += 0.09 * smoothstep(0.80, 1.0, s)      # renflement : la magma s'accumule
				wd *= smoothstep(0.0, 0.08, s) * (1.0 - 0.6 * smoothstep(0.985, 1.0, s))
				w.append(wd)
				lw.append(0.025 + 0.55 * wd)
			_ribbon(groups, it, true, pts, w, lw, st, uv0 + 5.0, 0.004)
			# ménisque sur la plinthe haute (y = 0,34, profondeur 0,10) : mince ruban horizontal en bas de la langue
			var mp: Array = []
			var mw: Array = []
			var ml: Array = []
			var pu: float = (pts[n - 1] as Vector2).x
			for i in 9:
				var s2 := float(i) / 8.0
				mp.append(Vector2(pu + lerpf(-0.42, 0.42, s2), 0.032))
				mw.append(0.016 * sin(s2 * PI) * (0.8 + 0.4 * _f(hh, 25 + i)))
				ml.append(0.012)
			_ribbon(groups, it, false, mp, mw, ml, st, uv0 + 9.0, 0.34 + 0.0)
		"canal":
			parts.append({"it": it})
			# magma de la rigole et sous la grille (rubans droits, largeur constante), lueur dans la gueule
			var cp: Array = []
			var cw: Array = []
			var cl: Array = []
			for i in 9:
				var s3 := float(i) / 8.0
				cp.append(Vector2(0.0, lerpf(0.30, 1.72, s3)))
				cw.append(0.26 * smoothstep(0.0, 0.12, s3) * (1.0 - 0.2 * smoothstep(0.8, 1.0, s3)))
				cl.append(0.0)
			_ribbon(groups, it, false, cp, cw, cl, st, uv0, 0.012, false)
			var mp2: Array = []
			var mw2: Array = []
			var ml2: Array = []
			for i in 7:
				var s4 := float(i) / 6.0
				mp2.append(Vector2(0.0, lerpf(0.04, 0.40, s4)))      # gueule : de bas en haut du mur, dans l'ouverture
				mw2.append(0.26 * (0.35 + 0.65 * sin(minf(s4 * 3.0, 1.0) * PI * 0.5)) * (1.0 - 0.5 * smoothstep(0.7, 1.0, s4)))
				ml2.append(0.0)
			_ribbon(groups, it, true, mp2, mw2, ml2, maxi(st, 1), uv0 + 3.0, 0.0, false)

## Gueule, rebords et grille d'un canal : repère local (origine au pied du mur au milieu du pan, +Z vers l'intérieur de la case, +X le long du mur).
static func channel_mesh() -> ArrayMesh:
	if _channel_mesh != null:
		return _channel_mesh
	var g := KitGeometryLava._new()
	var z0 := -0.02
	KitGeometryLava._tone(g, Vector3(0.1, 0.3, 0.2))
	# gueule : deux joues et un linteau de basalte scellés au mur ; l'ouverture (0,6 × 0,42) laisse voir la lueur
	KitGeometryLava._block(g, Vector3(-0.56, 0.0, z0), Vector3(-0.30, 0.66, z0 + 0.34), 3, 0.014, PackedStringArray(["-z", "-y"]), false)
	KitGeometryLava._block(g, Vector3(0.30, 0.0, z0), Vector3(0.56, 0.66, z0 + 0.34), 3, 0.014, PackedStringArray(["-z", "-y"]), false)
	KitGeometryLava._tone(g, Vector3(0.7, 0.2, 0.5))
	KitGeometryLava._block(g, Vector3(-0.56, 0.42, z0), Vector3(0.56, 0.66, z0 + 0.34), 3, 0.014, PackedStringArray(["-z", "-y"]), false)
	# rebords de la rigole : deux murets bas, ils guident l'écoulement de la gueule à la grille
	for sx in [-1.0, 1.0]:
		KitGeometryLava._tone(g, Vector3(sx, 0.4, 0.3))
		var xa: float = 0.30 if sx > 0.0 else -0.44
		var xb: float = 0.44 if sx > 0.0 else -0.30
		KitGeometryLava._block(g, Vector3(xa, 0.0, z0 + 0.30), Vector3(xb, 0.13, 1.78), 3, 0.012, PackedStringArray(["-y", "-z"]), false)
	# grille de fer noirci à l'extrémité : cadre et barreaux dans le sens de l'écoulement ; la magma s'y engouffre
	var ir: Dictionary = g.ir
	KitGeometry._box(ir, Vector3(-0.30, 0.0, 1.30), Vector3(0.30, 0.07, 1.42))
	KitGeometry._box(ir, Vector3(-0.30, 0.0, 1.70), Vector3(0.30, 0.07, 1.82))
	for i in 7:
		var bx := -0.255 + 0.085 * float(i)
		KitGeometry._box(ir, Vector3(bx - 0.016, 0.0, 1.40), Vector3(bx + 0.016, 0.075, 1.72))
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, KitGeometryLava._arrays(g))
	var irm: Dictionary = g.ir
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, KitGeometryLava._arrays(irm))
	m.surface_set_material(1, KitGeometryLava._iron_material())
	KitDecor._theme = "lava"
	_channel_mesh = KitDecor._with_theme_stone(m, 0.5) as ArrayMesh
	return _channel_mesh

# ------------------------------------------------------------------ pose

static func add(view: LevelView, level: Dictionary, grid: DungeonGrid, theme: String, niches: Dictionary, holes: Dictionary) -> void:
	last_stats = {}
	if not applies(theme, level):
		return
	var pl := plan(level, grid, niches, holes)
	var root := Node3D.new()
	root.name = "LavaFx"
	view.add_child(root)
	var groups := {}
	var parts: Array = []
	var kinds := {}
	for it in pl.items:
		_build_item(groups, parts, it)
		kinds[it.kind] = int(kinds.get(it.kind, 0)) + 1
	var keys: Array = groups.keys()
	keys.sort()
	for k in keys:
		var g: Dictionary = groups[k]
		if (g.v as Array).is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
		arr[Mesh.ARRAY_COLOR] = PackedColorArray(g.c)
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(g.uv)
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Magma_" + str(k).replace("|", "_")
		mi.mesh = m
		var key: String = g.key
		mi.material_override = lip_material() if key == "lip" else material(int(key.substr(1)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		root.add_child(mi)
	for p in parts:
		var it: Dictionary = p.it
		var d: Vector2i = it.d
		var mi2 := MeshInstance3D.new()
		mi2.name = "Canal_%d_%d" % [it.x, it.y]
		mi2.mesh = channel_mesh()
		mi2.transform = Transform3D(Basis(Vector3.UP, LevelBuilder._rot(d)), it.edge)
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi2.visibility_range_end = 60.0
		root.add_child(mi2)
	var nl := 0
	var ne := 0
	var ns := 0
	if effects and Settings.torch_lights() > 0:
		for l in pl.lights:
			var ol := OmniLight3D.new()
			ol.position = l.pos
			ol.light_color = Color(1.0, 0.40, 0.12)
			ol.light_energy = 1.0 if int(l.state) == 1 else 1.5
			ol.omni_range = 5.5
			ol.omni_attenuation = 1.6
			ol.shadow_enabled = false
			ol.light_specular = 0.2
			ol.light_volumetric_fog_energy = 0.1
			ol.distance_fade_enabled = true
			ol.distance_fade_begin = 14.0
			ol.distance_fade_length = 8.0
			root.add_child(ol)
			nl += 1
	if effects and float(Settings.opt("particles")) > 0.05:
		for e in pl.embers:
			root.add_child(_embers(e.pos, int(e.state)))
			ne += 1
		for s in pl.smoke:
			root.add_child(_smoke(s.pos))
			ns += 1
	last_stats = {"items": pl.items.size(), "lights": nl, "embers": ne, "smoke": ns}
	last_stats.merge(kinds)

static func _soft_texture() -> Texture2D:
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gr
	return gt

static func _embers(pos: Vector3, state: int) -> CPUParticles3D:
	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.albedo_texture = _soft_texture()
		_ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mesh = QuadMesh.new()
		_ember_mesh.size = Vector2(0.07, 0.07)
		_ember_mesh.material = _ember_mat
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.1, 0)
	p.mesh = _ember_mesh
	p.amount = Settings.pc(4 if state == 1 else 7)
	p.lifetime = 3.6
	p.randomness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0.04, 0.18, 0.0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.22, 0.9))
	g.add_point(0.6, Color(1.0, 0.30, 0.06, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.35, 0.04, 0.0, 0.0))
	p.color_ramp = g
	p.visibility_range_end = 24.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _smoke(pos: Vector3) -> CPUParticles3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = _soft_texture()
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mesh = QuadMesh.new()
		_smoke_mesh.size = Vector2(1.0, 1.0)
		_smoke_mesh.material = _smoke_mat
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.5, 0)
	p.mesh = _smoke_mesh
	p.amount = Settings.pc(3)
	p.lifetime = 6.0
	p.randomness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 0.1, 0.0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.5))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(0.15, 0.13, 0.12, 0.0))
	g.add_point(0.2, Color(0.15, 0.13, 0.12, 0.16))
	g.set_color(g.get_point_count() - 1, Color(0.08, 0.075, 0.075, 0.0))
	p.color_ramp = g
	p.visibility_range_end = 20.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
