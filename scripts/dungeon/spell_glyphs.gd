extends RefCounted
## Motifs gravés au sol par les sorts (décalques lumineux) : un par école. Chaque motif est tracé une seule fois, en niveaux de gris,
## puis gardé en mémoire. Les valeurs sont multipliées par l'opacité : l'émission d'un décalque ignore l'alpha, sinon tout le carré brillerait.

static var _cache: Dictionary = {}

const N := 384

static func _dab(img: PackedFloat32Array, x: float, y: float, rad: float) -> void:
	var x0 := maxi(int(x - rad - 1.0), 0)
	var x1 := mini(int(x + rad + 1.0), N - 1)
	var y0 := maxi(int(y - rad - 1.0), 0)
	var y1 := mini(int(y + rad + 1.0), N - 1)
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var d := Vector2(float(px) + 0.5 - x, float(py) + 0.5 - y).length()
			var v := clampf(rad + 0.5 - d, 0.0, 1.0)
			if v > img[py * N + px]:
				img[py * N + px] = v

static func _line(img: PackedFloat32Array, a: Vector2, b: Vector2, rad: float, rad_b: float = -1.0) -> void:
	var steps := maxi(int(a.distance_to(b) / 0.7), 1)
	var rb := rad if rad_b < 0.0 else rad_b
	for i in steps + 1:
		var u := float(i) / float(steps)
		var p := a.lerp(b, u)
		_dab(img, p.x, p.y, lerpf(rad, rb, u))

static func _ring(img: PackedFloat32Array, r: float, rad: float, from_a: float = 0.0, to_a: float = TAU) -> void:
	var c := float(N) * 0.5
	var steps := maxi(int((to_a - from_a) * r * c / 0.7), 8)
	for i in steps + 1:
		var ang := lerpf(from_a, to_a, float(i) / float(steps))
		_dab(img, c + cos(ang) * r * c, c + sin(ang) * r * c, rad)

static func _pt(r: float, ang: float) -> Vector2:
	var c := float(N) * 0.5
	return Vector2(c + cos(ang) * r * c, c + sin(ang) * r * c)

static func _finish(key: String, img: PackedFloat32Array) -> Texture2D:
	var bytes := PackedByteArray()
	bytes.resize(N * N * 4)
	for i in N * N:
		var b := int(clampf(img[i], 0.0, 1.0) * 255.0)
		bytes[i * 4] = b
		bytes[i * 4 + 1] = b
		bytes[i * 4 + 2] = b
		bytes[i * 4 + 3] = b
	var t := ImageTexture.create_from_image(Image.create_from_data(N, N, false, Image.FORMAT_RGBA8, bytes))
	_cache[key] = t
	return t

static func _blank() -> PackedFloat32Array:
	var img := PackedFloat32Array()
	img.resize(N * N)
	return img

## Brûlure : anneau irrégulier de braises et fissures incandescentes qui rayonnent depuis le centre.
static func scorch() -> Texture2D:
	if _cache.has("scorch"):
		return _cache["scorch"]
	var img := _blank()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 3:
		var r := 0.9 - float(k) * 0.12
		var prev := _pt(r, 0.0)
		for i in range(1, 49):
			var ang := float(i) / 48.0 * TAU
			var rr := r + rng.randf_range(-0.045, 0.045)
			var q := _pt(rr, ang)
			if rng.randf() < 0.78:
				_line(img, prev, q, 2.4 - float(k) * 0.5)
			prev = q
	for i in 14:
		var ang := float(i) / 14.0 * TAU + rng.randf_range(-0.2, 0.2)
		var p := _pt(0.06, ang)
		var segs := rng.randi_range(4, 6)
		var rad := 2.6
		for s in segs:
			var ang2 := ang + rng.randf_range(-0.28, 0.28)
			var q := _pt(0.06 + (float(s) + 1.0) / float(segs) * rng.randf_range(0.6, 0.86), ang2)
			_line(img, p, q, rad, rad * 0.55)
			if rng.randf() < 0.4 and s > 0:
				var br := _pt(0.06 + (float(s) + 1.0) / float(segs) * 0.5, ang2 + rng.randf_range(-0.7, 0.7))
				_line(img, p, br, 1.6, 0.6)
			p = q
			rad *= 0.8
	_dab(img, N * 0.5, N * 0.5, 7.0)
	return _finish("scorch", img)

## Flocon de givre : six bras à branches, hexagone central, petits cristaux entre les bras, double anneau extérieur.
static func frost() -> Texture2D:
	if _cache.has("frost"):
		return _cache["frost"]
	var img := _blank()
	_ring(img, 0.975, 2.4)
	_ring(img, 0.925, 1.2)
	_ring(img, 0.30, 1.4)
	for i in 6:
		var a := float(i) / 6.0 * TAU - PI * 0.5
		_line(img, _pt(0.0, a), _pt(0.80, a), 2.4, 1.2)
		for tv in [0.34, 0.54, 0.70]:
			var t: float = tv
			var len: float = 0.22 - (t - 0.34) * 0.4
			for sgn in [-1.0, 1.0]:
				var b: Vector2 = _pt(t * 0.8, a)
				var d := Vector2(cos(a + sgn * 1.05), sin(a + sgn * 1.05))
				_line(img, b, b + d * len * float(N) * 0.5, 1.7, 0.8)
		var tip := _pt(0.80, a)
		_dab(img, tip.x, tip.y, 4.0)
		# petit cristal entre deux bras
		var m := _pt(0.86, a + PI / 6.0)
		for k in 3:
			var ka := float(k) / 3.0 * PI
			_line(img, m - Vector2(cos(ka), sin(ka)) * 9.0, m + Vector2(cos(ka), sin(ka)) * 9.0, 1.3)
	for i in 6:
		var a1 := float(i) / 6.0 * TAU
		var a2 := float(i + 1) / 6.0 * TAU
		_line(img, _pt(0.30, a1), _pt(0.30, a2), 1.4)
	_dab(img, N * 0.5, N * 0.5, 6.0)
	return _finish("frost", img)

## Soleil sacré : double anneau, graduations alternées, étoile à huit pointes, anneau intérieur et croix évasée au centre.
static func sun() -> Texture2D:
	if _cache.has("sun"):
		return _cache["sun"]
	var img := _blank()
	_ring(img, 0.975, 2.4)
	_ring(img, 0.93, 1.2)
	for i in 32:
		var a := float(i) / 32.0 * TAU
		var r1 := 0.80 if i % 2 == 0 else 0.84
		_line(img, _pt(r1, a), _pt(0.90, a), 1.5 if i % 2 == 0 else 1.0)
	_ring(img, 0.76, 1.5)
	for sq in 2:
		var off := float(sq) * PI * 0.25
		for k in 4:
			var a1 := off + float(k) * PI * 0.5
			var a2 := off + float(k + 1) * PI * 0.5
			_line(img, _pt(0.70, a1), _pt(0.70, a2), 1.8)
			var v := _pt(0.70, a1)
			_dab(img, v.x, v.y, 3.6)
	_ring(img, 0.46, 1.5)
	_ring(img, 0.40, 1.0)
	var c := Vector2(N * 0.5, N * 0.5)
	_line(img, c + Vector2(0, -0.34) * N * 0.5, c + Vector2(0, 0.34) * N * 0.5, 3.0, 3.0)
	_line(img, c + Vector2(-0.34, 0) * N * 0.5, c + Vector2(0.34, 0) * N * 0.5, 3.0, 3.0)
	for sgn in [-1.0, 1.0]:
		_line(img, c + Vector2(sgn * 0.34, -0.06) * N * 0.5, c + Vector2(sgn * 0.34, 0.06) * N * 0.5, 2.0)
		_line(img, c + Vector2(-0.06, sgn * 0.34) * N * 0.5, c + Vector2(0.06, sgn * 0.34) * N * 0.5, 2.0)
	_dab(img, c.x, c.y, 6.0)
	return _finish("sun", img)

## Sceau de jugement : carré et carré tourné, douze graduations, grande épée verticale à garde, cercle central.
static func judgment() -> Texture2D:
	if _cache.has("judgment"):
		return _cache["judgment"]
	var img := _blank()
	_ring(img, 0.975, 2.4)
	_ring(img, 0.925, 1.2)
	for i in 24:
		var a := float(i) / 24.0 * TAU
		_line(img, _pt(0.83, a), _pt(0.90, a), 1.3)
	for sq in 2:
		var off := float(sq) * PI * 0.25 + PI * 0.25
		for k in 4:
			var a1 := off + float(k) * PI * 0.5
			var a2 := off + float(k + 1) * PI * 0.5
			_line(img, _pt(0.78, a1), _pt(0.78, a2), 1.7)
	_ring(img, 0.55, 1.4)
	var c := Vector2(N * 0.5, N * 0.5)
	var h := float(N) * 0.5
	_line(img, c + Vector2(0, -0.62) * h, c + Vector2(0, 0.40) * h, 4.0, 1.8)
	_line(img, c + Vector2(-0.24, -0.06) * h, c + Vector2(0.24, -0.06) * h, 2.6)
	_dab(img, c.x, c.y + 0.5 * h * 0.46, 4.0)
	_dab(img, c.x, c.y - 0.5 * h * 0.62 * 2.0 * 0.5, 3.0)
	return _finish("judgment", img)

## Sceau d'anathème : huit pointes, croix renversée, couronne de croix en X.
static func anathema() -> Texture2D:
	if _cache.has("anathema"):
		return _cache["anathema"]
	var img := _blank()
	_ring(img, 0.975, 2.4)
	_ring(img, 0.90, 1.3)
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var m := _pt(0.84, a)
		var d1 := Vector2(cos(a + 0.785), sin(a + 0.785)) * 9.0
		var d2 := Vector2(cos(a - 0.785), sin(a - 0.785)) * 9.0
		_line(img, m - d1, m + d1, 1.6)
		_line(img, m - d2, m + d2, 1.6)
	_ring(img, 0.74, 1.4)
	for i in 8:
		var a := float(i) / 8.0 * TAU
		_line(img, _pt(0.74, a), _pt(0.40, a + PI / 8.0), 1.7)
		_line(img, _pt(0.40, a + PI / 8.0), _pt(0.74, a + PI / 4.0), 1.7)
	_ring(img, 0.30, 1.4)
	var c := Vector2(N * 0.5, N * 0.5)
	var h := float(N) * 0.5
	_line(img, c + Vector2(0, -0.22) * h, c + Vector2(0, 0.42) * h, 3.2)
	_line(img, c + Vector2(-0.2, 0.18) * h, c + Vector2(0.2, 0.18) * h, 3.0)
	_dab(img, c.x, c.y, 5.0)
	return _finish("anathema", img)

## Pentagramme : double anneau, couronne de graduations, étoile à cinq branches (une ligne sur deux), cercles aux sommets, œil central.
static func pentagram() -> Texture2D:
	if _cache.has("pentagram"):
		return _cache["pentagram"]
	var img := _blank()
	_ring(img, 0.975, 2.4)
	_ring(img, 0.93, 1.2)
	for i in 40:
		var a := float(i) / 40.0 * TAU
		_line(img, _pt(0.84, a), _pt(0.90 if i % 2 == 0 else 0.87, a), 1.2)
	_ring(img, 0.80, 1.5)
	var pts: Array = []
	for k in 5:
		pts.append(_pt(0.80, -PI * 0.5 + float(k) * TAU / 5.0))
	for k in 5:
		_line(img, pts[k], pts[(k + 2) % 5], 2.0)
		var v: Vector2 = pts[k]
		_dab(img, v.x, v.y, 4.5)
	_ring(img, 0.31, 1.4)
	_ring(img, 0.12, 1.4)
	_dab(img, N * 0.5, N * 0.5, 5.5)
	return _finish("pentagram", img)
