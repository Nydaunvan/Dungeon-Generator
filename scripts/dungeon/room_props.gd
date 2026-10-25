class_name RoomProps
extends RefCounted
## Planificateur des accessoires d'une salle selon son style (voir RoomStyles). Ne crée aucun nœud : il renvoie des primitives
## {m: matériau, s: forme, p: centre, z: taille, y/pit/rol: rotations} et des flammes, que RoomDecor transforme en MultiMesh.
## Règle d'or : rien n'occupe le centre d'une case ni une case portant un objet, un escalier ou le marchand. Les accessoires sont
## collés aux murs (un pan de mur ne porte qu'un accessoire) ou posés sur un sommet entre quatre cases (pièce maîtresse).

const CELL := LevelBuilder.CELL
const HALF := CELL * 0.5
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Réglages par style : piliers (true, "broken" ou false), tapis, lustre ("candles" / ""), bannières, sol, effet d'ambiance.
const DEF := {
	"bibliotheque": {"pillars": true, "rug": true, "chand": "candles", "banners": false, "floor": "parquet", "fx": "dust"},
	"armes": {"pillars": true, "rug": false, "chand": "", "banners": true, "floor": "dalles", "fx": "embers"},
	"cellier": {"pillars": true, "rug": false, "chand": "", "banners": false, "floor": "terre", "fx": "dust"},
	"autel": {"pillars": true, "rug": true, "chand": "", "banners": true, "floor": "damier", "fx": "motes"},
	"ruine": {"pillars": "broken", "rug": false, "chand": "", "banners": false, "floor": "fissures", "fx": "dust"},
	"commune": {"pillars": true, "rug": false, "chand": "candles", "banners": true, "floor": "planches", "fx": ""},
	"humide": {"pillars": true, "rug": false, "chand": "", "banners": false, "floor": "mouille", "fx": "mist"},
	"tresor": {"pillars": true, "rug": true, "chand": "candles", "banners": true, "floor": "dore", "fx": "motes"},
	"repaire": {"pillars": true, "rug": true, "chand": "", "banners": false, "floor": "sang", "fx": "embers"},
	"marche": {"pillars": true, "rug": false, "chand": "", "banners": true, "floor": "paille", "fx": "dust"},
}

# ------------------------------------------------------------------ primitives

static func _prim(P: Dictionary, s: String, m: String, p: Vector3, z: Vector3, yaw := 0.0, pit := 0.0, rol := 0.0) -> void:
	P.prims.append({"m": m, "s": s, "p": p, "z": z, "y": yaw, "pit": pit, "rol": rol})

static func _box(P: Dictionary, m: String, p: Vector3, z: Vector3, yaw := 0.0, pit := 0.0, rol := 0.0) -> void:
	_prim(P, "box", m, p, z, yaw, pit, rol)

## Cylindre : z = (diamètre, hauteur, diamètre).
static func _cyl(P: Dictionary, m: String, p: Vector3, z: Vector3, yaw := 0.0, pit := 0.0, rol := 0.0) -> void:
	_prim(P, "cyl", m, p, z, yaw, pit, rol)

static func _sph(P: Dictionary, m: String, p: Vector3, z: Vector3, yaw := 0.0) -> void:
	_prim(P, "sph", m, p, z, yaw)

## Cône pointe en haut : z = (diamètre de la base, hauteur, diamètre).
static func _cone(P: Dictionary, m: String, p: Vector3, z: Vector3, rol := 0.0) -> void:
	_prim(P, "cone", m, p, z, 0.0, 0.0, rol)

static func _flame(P: Dictionary, p: Vector3, size: float, kind := "warm") -> void:
	P.flames.append({"p": p, "size": size, "kind": kind})

## Modèle 3D détaillé (voir PropMeshes) posé en `p` (au sol, sauf objets muraux), tourné de `yaw`, mis à l'échelle `sc`.
static func _model(P: Dictionary, name: String, p: Vector3, yaw := 0.0, sc := 1.0) -> void:
	P.prims.append({"m": name, "s": "mesh", "p": p, "z": Vector3(sc, sc, sc), "y": yaw, "pit": 0.0, "rol": 0.0})

## Point `local` (repère du modèle : +Z vers l'intérieur de la salle) converti dans le repère de la salle.
static func _at(p: Vector3, yaw: float, local: Vector3) -> Vector3:
	return p + Basis(Vector3.UP, yaw) * local

## Variante (0..n-1) déterministe d'après la position.
static func _var(p: Vector3, n: int) -> int:
	return absi(int(floor(p.x * 37.0 + p.z * 91.0))) % n

## Point contre le mur `d` de la case `c` : `off` = distance au mur du centre de l'accessoire, `lat` = décalage le long du mur.
static func _wp(c: Vector2i, d: Vector2i, off: float, lat := 0.0, y := 0.0) -> Vector3:
	var t := Vector3(absf(float(d.y)), 0.0, absf(float(d.x)))
	return Vector3(c.x * CELL, y, c.y * CELL) + Vector3(d.x, 0, d.y) * (HALF - off) + t * lat

static func _yaw(d: Vector2i) -> float:
	return atan2(float(-d.x), float(-d.y))

static func _corner(c: Vector2i, d1: Vector2i, d2: Vector2i, off: float, y := 0.0) -> Vector3:
	return Vector3(c.x * CELL, y, c.y * CELL) + Vector3(d1.x + d2.x, 0, d1.y + d2.y) * (HALF - off)

static func _vw(v: Vector2i) -> Vector3:
	return Vector3((v.x - 0.5) * CELL, 0.0, (v.y - 0.5) * CELL)

static func _is_wall(rows: Array, c: Vector2i) -> bool:
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= str(rows[c.y]).length():
		return true
	return str(rows[c.y])[c.x] == "#"

# ------------------------------------------------------------------ emplacements

static func _shuffle(ctx: Dictionary, a: Array) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## Pans de mur libres de la salle (mélangés). `tall` : seulement les cases où x + y est impair (les torches sont sur les cases paires).
static func _slots(ctx: Dictionary, tall := false) -> Array:
	var out: Array = []
	for c in ctx.cells:
		if ctx.blocked.has(c) or (tall and (c.x + c.y) % 2 == 0):
			continue
		for d in DIRS:
			if _is_wall(ctx.rows, c + d):
				out.append({"c": c, "d": d})
	_shuffle(ctx, out)
	return out

static func _key(c: Vector2i, d: Vector2i) -> String:
	return "%d,%d,%d,%d" % [c.x, c.y, d.x, d.y]

## Prend jusqu'à `n` pans libres dans `slots` et les marque utilisés.
static func _take(P: Dictionary, slots: Array, n: int) -> Array:
	var out: Array = []
	while out.size() < n and not slots.is_empty():
		var s = slots.pop_back()
		var k := _key(s.c, s.d)
		if P.used.has(k):
			continue
		P.used[k] = true
		out.append(s)
	return out

static func _count(ctx: Dictionary, slots: Array, frac: float, cap: int) -> int:
	return mini(cap, maxi(1, ceili(float(slots.size()) * frac * float(ctx.density))))

## Angles de la salle : cases adossées à deux murs perpendiculaires.
static func _corners(ctx: Dictionary) -> Array:
	var out: Array = []
	for c in ctx.cells:
		if ctx.blocked.has(c):
			continue
		for dv in [Vector2i(0, -1), Vector2i(0, 1)]:
			for dh in [Vector2i(-1, 0), Vector2i(1, 0)]:
				if _is_wall(ctx.rows, c + dv) and _is_wall(ctx.rows, c + dh):
					out.append({"c": c, "d1": dv, "d2": dh})
	_shuffle(ctx, out)
	return out

## Sommet (entre quatre cases de la salle) le plus proche du centre de la salle, ou null.
static func _center_vertex(ctx: Dictionary):
	var inside: Dictionary = ctx.inside
	var rect: Rect2i = ctx.rect
	var cx := float(rect.position.x) + float(rect.size.x) * 0.5
	var cy := float(rect.position.y) + float(rect.size.y) * 0.5
	var best = null
	var bd := 1e9
	for c in ctx.cells:
		for v in [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x, c.y + 1), Vector2i(c.x + 1, c.y + 1)]:
			if not (inside.has(Vector2i(v.x - 1, v.y - 1)) and inside.has(Vector2i(v.x, v.y - 1)) and inside.has(Vector2i(v.x - 1, v.y)) and inside.has(v)):
				continue
			var d := absf(float(v.x) - cx) + absf(float(v.y) - cy) + 0.001 * float(v.y) + 0.0001 * float(v.x)
			if d < bd:
				bd = d
				best = v
	return best

# ------------------------------------------------------------------ objets communs

static func _barrel(P: Dictionary, p: Vector3, big := 1.0) -> void:
	_model(P, "barrel%d" % _var(p, 3), p, 0.0, big)

static func _crate(P: Dictionary, p: Vector3, s: float, yaw: float) -> void:
	_model(P, "crate%d" % _var(p, 2), p, yaw, s)

static func _sack(P: Dictionary, p: Vector3, yaw: float) -> void:
	_model(P, "sack%d" % _var(p, 3), p, yaw)

static func _candle(P: Dictionary, p: Vector3, h := 0.35, kind := "warm") -> void:
	_model(P, "candle", p, 0.0, h / 0.4)
	_flame(P, p + Vector3(0, h + 0.07, 0), 0.32, kind)

static func _brazier(P: Dictionary, p: Vector3, kind := "warm", gold := false) -> void:
	_model(P, "brazier_gold" if gold else "brazier_iron", p)
	_flame(P, p + Vector3(0, 1.2, 0), 0.9, kind)

static func _rubble(P: Dictionary, ctx: Dictionary, p: Vector3, n: int, spread: float) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var sc := clampf(0.75 + float(n) * 0.06, 0.85, 1.4)
	_model(P, "rubble%d" % (rng.randi() % 3), p, rng.randf() * TAU, sc)
	if spread > 1.2:
		_model(P, "rubble%d" % (rng.randi() % 3), p + Vector3(0.7, 0, -0.6), rng.randf() * TAU, 1.0)
		_model(P, "rock%d" % (rng.randi() % 3), p + Vector3(-0.6, 0, 0.7), rng.randf() * TAU, 1.2)

static func _coins(P: Dictionary, ctx: Dictionary, p: Vector3, n: int) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	_model(P, "coins%d" % (rng.randi() % 3), p, rng.randf() * TAU, 1.0 + float(n) * 0.03)

static func _bones(P: Dictionary, ctx: Dictionary, p: Vector3, n: int) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	_model(P, "bones%d" % (rng.randi() % 3), p, rng.randf() * TAU, 0.8 + float(n) * 0.06)

# ------------------------------------------------------------------ plan

## ctx : rows, inside (case -> true), cells, rect, blocked (case -> true), seed, vedette, style.
static func plan(ctx: Dictionary) -> Dictionary:
	var P := {"prims": [], "flames": [], "webs": [], "used": {}, "vertex": null}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.seed)
	ctx["rng"] = rng
	ctx["density"] = 1.0 if bool(ctx.vedette) else 0.65
	var rect: Rect2i = ctx.rect
	var v = _center_vertex(ctx)
	var feature: bool = v != null and rect.size.x >= 3 and rect.size.y >= 3 and (bool(ctx.vedette) or rng.randf() < 0.35)
	if feature:
		P.vertex = v
	var vw := _vw(v) if feature else Vector3.ZERO
	match str(ctx.style):
		"bibliotheque": _bibliotheque(P, ctx, feature, vw)
		"armes": _armes(P, ctx, feature, vw)
		"cellier": _cellier(P, ctx, feature, vw)
		"autel": _autel(P, ctx, feature, vw)
		"ruine": _ruine(P, ctx, feature, vw)
		"commune": _commune(P, ctx, feature, vw)
		"humide": _humide(P, ctx, feature, vw)
		"tresor": _tresor(P, ctx, feature, vw)
		"repaire": _repaire(P, ctx, feature, vw)
		"marche": _marche(P, ctx, feature, vw)
	return P

# ------------------------------------------------------------------ styles

static func _bibliotheque(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var slots := _slots(ctx, true)
	for s in _take(P, slots, _count(ctx, slots, 0.55, 9)):
		_model(P, "bookshelf%d" % (rng.randi() % 3), _wp(s.c, s.d, 0.2, 0, 0.0), _yaw(s.d))
	var floor_slots := _slots(ctx)
	for s in _take(P, floor_slots, 3 + int(5.0 * ctx.density)):
		var q := _wp(s.c, s.d, 0.55 + rng.randf() * 0.45, (rng.randf() - 0.5) * 1.6, 0.012)
		_box(P, "paper", q, Vector3(0.42, 0.012, 0.3), rng.randf() * TAU)
	if feature:
		_model(P, "table_small", vw, rng.randf() * TAU)
		_candle(P, vw + Vector3(0.3, 0.82, 0.0), 0.3)

static func _armes(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var slots := _slots(ctx, true)
	var n := _count(ctx, slots, 0.6, 9)
	var taken := _take(P, slots, n)
	for i in taken.size():
		var c: Vector2i = taken[i].c
		var d: Vector2i = taken[i].d
		var yaw := _yaw(d)
		if i % 2 == 0:
			_model(P, "weapon_rack%d" % ((i / 2) % 2), _wp(c, d, 0.2, 0, 0.0), yaw)
		else:
			_model(P, "shield_wall%d" % (rng.randi() % 2), _wp(c, d, 0.0, 0, 1.55), yaw)
	var corners := _corners(ctx)
	var nb := 1 + int(2.0 * ctx.density)
	for i in mini(nb, corners.size()):
		_brazier(P, _corner(corners[i].c, corners[i].d1, corners[i].d2, 0.45), "warm")
	if feature:
		_model(P, "dummy", vw, rng.randf() * TAU)

static func _cellier(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var corners := _corners(ctx)
	for i in mini(2 + int(4.0 * ctx.density), corners.size()):
		var cr = corners[i]
		var p := _corner(cr.c, cr.d1, cr.d2, 0.46)
		if rng.randf() < 0.55:
			_barrel(P, p)
			if rng.randf() < 0.5:
				_barrel(P, p + Vector3(-cr.d2.x * 0.85, 0, 0))
		else:
			_crate(P, p, 0.8, rng.randf() * 0.3)
			if rng.randf() < 0.6:
				_crate(P, p + Vector3(0, 0.8, 0), 0.6, rng.randf() * 0.6)
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.4, 8)):
		var c: Vector2i = s.c
		var d: Vector2i = s.d
		match rng.randi() % 4:
			0:
				_barrel(P, _wp(c, d, 0.45, (rng.randf() - 0.5) * 1.4))
			1:
				_crate(P, _wp(c, d, 0.42, (rng.randf() - 0.5) * 1.2), 0.75, _yaw(d) + (rng.randf() - 0.5) * 0.3)
			2:
				_sack(P, _wp(c, d, 0.4, -0.4), rng.randf() * TAU)
				_sack(P, _wp(c, d, 0.45, 0.35), rng.randf() * TAU)
			3:
				_model(P, "vase%d" % (rng.randi() % 2), _wp(c, d, 0.4, (rng.randf() - 0.5) * 1.2), rng.randf() * TAU)
	if feature:
		_crate(P, vw + Vector3(-0.5, 0, 0.3), 0.9, 0.2)
		_crate(P, vw + Vector3(0.5, 0, -0.2), 0.8, -0.3)
		_crate(P, vw + Vector3(-0.4, 0.9, 0.3), 0.6, 0.5)
		_barrel(P, vw + Vector3(0.3, 0, 0.7))

static func _autel(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var slots := _slots(ctx, true)
	for s in _take(P, slots, _count(ctx, slots, 0.35, 5)):
		var d: Vector2i = s.d
		var yaw := _yaw(d)
		var o := _wp(s.c, d, 0.0, 0, 1.8)
		_model(P, "sconce", o, yaw)
		_flame(P, _at(o, yaw, Vector3(0, 0.3, 0.26)), 0.5)
	if feature:
		_model(P, "altar", vw)
		for sx in [-1.05, 1.05]:
			for sz in [-1.05, 1.05]:
				var cp := vw + Vector3(sx, 0.0, sz)
				_model(P, "candelabra", cp)
				for fp in PropMeshes.CANDELABRA_FLAMES:
					_flame(P, cp + fp + Vector3(0, 0.03, 0), 0.4)
	else:
		var corners := _corners(ctx)
		for i in mini(2, corners.size()):
			var cp := _corner(corners[i].c, corners[i].d1, corners[i].d2, 0.45)
			_model(P, "candelabra", cp)
			for fp in PropMeshes.CANDELABRA_FLAMES:
				_flame(P, cp + fp + Vector3(0, 0.03, 0), 0.4)

static func _ruine(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var corners := _corners(ctx)
	for i in mini(2 + int(3.0 * ctx.density), corners.size()):
		var cr = corners[i]
		_rubble(P, ctx, _corner(cr.c, cr.d1, cr.d2, 0.6), 4 + rng.randi() % 4, 0.9)
		P.webs.append({"p": _corner(cr.c, cr.d1, cr.d2, 0.0, 3.3) - Vector3(cr.d1.x + cr.d2.x, 0, cr.d1.y + cr.d2.y) * 0.55, "yaw": atan2(float(-(cr.d1.x + cr.d2.x)), float(-(cr.d1.y + cr.d2.y)))})
	var slots := _slots(ctx)
	var taken := _take(P, slots, _count(ctx, slots, 0.35, 6))
	for i in taken.size():
		var c: Vector2i = taken[i].c
		var d: Vector2i = taken[i].d
		match i % 3:
			0:
				_model(P, "column_stump", _wp(c, d, 0.5, (rng.randf() - 0.5) * 0.6, 0.0), rng.randf() * TAU)
			1:
				_model(P, "column_fallen", _wp(c, d, 0.5, (rng.randf() - 0.5) * 0.4, 0.0), _yaw(d) + (rng.randf() - 0.5) * 0.3)
			_:
				_rubble(P, ctx, _wp(c, d, 0.5, (rng.randf() - 0.5) * 1.2), 3 + rng.randi() % 4, 0.8)
	if feature:
		_rubble(P, ctx, vw, 10, 1.5)
		_model(P, "column_fallen", vw + Vector3(0.3, 0, 0.2), rng.randf() * TAU)

static func _commune(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	if feature:
		_model(P, "table_long", vw)
		for sz in [-0.85, 0.85]:
			_model(P, "bench", vw + Vector3(0, 0, sz))
		_model(P, "tableware", vw)
		_candle(P, vw + Vector3(0.0, 0.8, 0.0), 0.3)
	var tall := _slots(ctx, true)
	var chimney: Array = _take(P, tall, 1) if bool(ctx.vedette) else []
	if not chimney.is_empty():
		var c: Vector2i = chimney[0].c
		var d: Vector2i = chimney[0].d
		var yaw := _yaw(d)
		var o := _wp(c, d, 0.3, 0, 0.0)
		_model(P, "fireplace", o, yaw)
		_flame(P, _at(o, yaw, Vector3(0, 0.55, 0.02)), 1.2)
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.3, 6)):
		var c: Vector2i = s.c
		var d: Vector2i = s.d
		if rng.randf() < 0.5:
			_model(P, "stool", _wp(c, d, 0.4, (rng.randf() - 0.5) * 1.2), rng.randf() * TAU)
		else:
			_barrel(P, _wp(c, d, 0.45, (rng.randf() - 0.5) * 1.2), 0.85)

static func _humide(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.5, 9)):
		var c: Vector2i = s.c
		var d: Vector2i = s.d
		var r := 0.8 + rng.randf() * 0.9
		_cyl(P, "water", _wp(c, d, 0.5 + r * 0.3, (rng.randf() - 0.5) * 1.4, 0.014), Vector3(r, 0.01, r * (0.7 + rng.randf() * 0.4)), rng.randf() * TAU)
		if rng.randf() < 0.6:
			_cyl(P, "moss", _wp(c, d, 0.3, (rng.randf() - 0.5) * 1.6, 0.02), Vector3(0.7, 0.012, 0.5), rng.randf() * TAU)
		match rng.randi() % 3:
			0:
				var vv := rng.randi() % 2
				var ht := 0.85 + 0.35 * float(vv)
				_model(P, "stalactite%d" % vv, _wp(c, d, 0.3, (rng.randf() - 0.5) * 1.4, CELL - ht), rng.randf() * TAU)
			1:
				_model(P, "stalagmite%d" % (rng.randi() % 3), _wp(c, d, 0.35, (rng.randf() - 0.5) * 1.4, 0.0), rng.randf() * TAU)
			2:
				var q := _wp(c, d, 0.3, (rng.randf() - 0.5) * 1.4, 0.0)
				_model(P, "mushrooms%d" % (rng.randi() % 2), q, rng.randf() * TAU, 1.5)
				_flame(P, q + Vector3(0, 0.3, 0), 0.45, "green")
	if feature:
		_cyl(P, "water", vw + Vector3(0, 0.014, 0), Vector3(2.2, 0.01, 1.8))
		_model(P, "stalagmite2", vw + Vector3(0.3, 0, 0.2), 0.3, 1.3)
		_model(P, "stalagmite0", vw + Vector3(-0.35, 0, -0.25), 1.2, 1.1)
		_model(P, "mushrooms1", vw + Vector3(0.1, 0, -0.5), 0.5, 1.6)
		_flame(P, vw + Vector3(0, 0.3, 0), 0.9, "green")

static func _tresor(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.4, 7)):
		var p := _wp(s.c, s.d, 0.55, (rng.randf() - 0.5) * 1.2)
		if rng.randf() < 0.65:
			_model(P, "gold_pile%d" % (rng.randi() % 2), p, rng.randf() * TAU, 1.0 + rng.randf() * 0.3)
			_coins(P, ctx, p + Vector3(0.4, 0, 0.3), 6)
		else:
			_model(P, "vase%d" % (rng.randi() % 2), p, rng.randf() * TAU)
			_model(P, "gold_bars", p + Vector3(0.5, 0, 0.1), rng.randf() * TAU)
	var corners := _corners(ctx)
	for i in mini(2 + int(2.0 * ctx.density), corners.size()):
		_brazier(P, _corner(corners[i].c, corners[i].d1, corners[i].d2, 0.45), "gold", true)
	if feature:
		_model(P, "gold_hoard", vw, rng.randf() * TAU)
		_coins(P, ctx, vw + Vector3(1.0, 0, 0.9), 9)
		_coins(P, ctx, vw + Vector3(-1.1, 0, -0.8), 9)
		_flame(P, vw + Vector3(0, 1.3, 0), 1.0, "gold")

static func _repaire(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var corners := _corners(ctx)
	for i in mini(2 + int(3.0 * ctx.density), corners.size()):
		_bones(P, ctx, _corner(corners[i].c, corners[i].d1, corners[i].d2, 0.7), 5 + rng.randi() % 4)
	var tall := _slots(ctx, true)
	for s in _take(P, tall, _count(ctx, tall, 0.3, 4)):
		_model(P, "wall_chains", _wp(s.c, s.d, 0.0, 0, 2.1), _yaw(s.d))
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.3, 5)):
		_bones(P, ctx, _wp(s.c, s.d, 0.6, (rng.randf() - 0.5) * 1.2), 3 + rng.randi() % 3)
	for i in mini(2, corners.size()):
		var cr = corners[corners.size() - 1 - i]
		_brazier(P, _corner(cr.c, cr.d1, cr.d2, 0.45), "red")
	if feature:
		_model(P, "throne", vw, 0.0)
		_bones(P, ctx, vw + Vector3(0.5, 0, 1.1), 6)
		_brazier(P, vw + Vector3(-1.3, 0, 0.9), "red")
		_brazier(P, vw + Vector3(1.3, 0, 0.9), "red")

static func _marche(P: Dictionary, ctx: Dictionary, feature: bool, vw: Vector3) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var tall := _slots(ctx, true)
	for s in _take(P, tall, _count(ctx, tall, 0.5, 5)):
		var c: Vector2i = s.c
		var d: Vector2i = s.d
		var yaw := _yaw(d)
		var o := _wp(c, d, 0.4, 0, 0.0)
		_model(P, "stall", o, yaw)
		_flame(P, _at(o, yaw, PropMeshes.STALL_FLAME), 0.5)
	var slots := _slots(ctx)
	for s in _take(P, slots, _count(ctx, slots, 0.35, 6)):
		var c: Vector2i = s.c
		var d: Vector2i = s.d
		match rng.randi() % 4:
			0: _crate(P, _wp(c, d, 0.42, (rng.randf() - 0.5) * 1.2), 0.75, _yaw(d))
			1: _sack(P, _wp(c, d, 0.4, (rng.randf() - 0.5) * 1.2), rng.randf() * TAU)
			2: _barrel(P, _wp(c, d, 0.45, (rng.randf() - 0.5) * 1.2), 0.9)
			3: _model(P, "vase%d" % (rng.randi() % 2), _wp(c, d, 0.4, (rng.randf() - 0.5) * 1.2), rng.randf() * TAU)
	if feature:
		_model(P, "table_small", vw)
		_crate(P, vw + Vector3(-0.4, 0.82, 0.0), 0.4, 0.3)
		_sack(P, vw + Vector3(0.4, 0.82, 0.0), 0.0)
