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
