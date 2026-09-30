class_name TrapDecals
extends RefCounted
## Décalques de pièges au sol (pointes, fléchettes, fosse, vapeurs) — port de spikes/dart/pit/gasDecalTexture.

const N := 256
static var _cache: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if not ["spikes", "dart", "pit", "gas"].has(kind):
		kind = "spikes"
	if _cache.has(kind):
		return _cache[kind]
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	match kind:
		"dart": _dart(img)
		"pit": _pit(img)
		"gas": _gas(img)
		_: _spikes(img)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[kind] = t
	return t

static func _over(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= N or y >= N or c.a <= 0.0:
		return
	var d := img.get_pixel(x, y)
	var a := c.a + d.a * (1.0 - c.a)
	if a <= 0.0:
		return
	var rgb := (Vector3(c.r, c.g, c.b) * c.a + Vector3(d.r, d.g, d.b) * d.a * (1.0 - c.a)) / a
	img.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, a))

## Dégradé radial à arrêts [(t, Color)] ; t = distance / rayon.
static func _radial(img: Image, cx: float, cy: float, r0: float, r1: float, stops: Array, clip_ry: float = -1.0) -> void:
	var rad := int(ceil(r1)) + 1
	for y in range(maxi(0, int(cy) - rad), mini(N, int(cy) + rad)):
		for x in range(maxi(0, int(cx) - rad), mini(N, int(cx) + rad)):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			if clip_ry > 0.0:
				dy *= r1 / clip_ry
			var d := sqrt(dx * dx + dy * dy)
			if d > r1:
				continue
			var t := clampf((d - r0) / (r1 - r0), 0.0, 1.0) if d > r0 else 0.0
			_over(img, x, y, _sample(stops, t))

static func _sample(stops: Array, t: float) -> Color:
	for i in stops.size() - 1:
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if t <= float(b[0]):
			var u := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return (a[1] as Color).lerp(b[1], u)
	return (stops[stops.size() - 1] as Array)[1]

static func _spikes(img: Image) -> void:
	_radial(img, 128, 128, 20, 124, [[0.0, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.55)], [0.6, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.3)], [1.0, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.0)]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 15:
		var ang := rng.randf() * TAU
		var dist := rng.randf() * 85.0
		var cx := 128.0 + cos(ang) * dist
		var cy := 128.0 + sin(ang) * dist * 0.7
		var ln := 14.0 + rng.randf() * 16.0
		var w := 4.0 + rng.randf() * 4.0
		var rot := rng.randf() * TAU
		_triangle(img, cx, cy, rot, Vector2(-w * 0.6 + 2, 4), Vector2(w * 0.6 + 2, 4), Vector2(2, -ln + 4), ln, true)
		_triangle(img, cx, cy, rot, Vector2(-w * 0.6, 4), Vector2(w * 0.6, 4), Vector2(0, -ln), ln, false)

static func _triangle(img: Image, cx: float, cy: float, rot: float, a: Vector2, b: Vector2, c: Vector2, ln: float, shadow: bool) -> void:
	var inv := Transform2D(rot, Vector2(cx, cy)).affine_inverse()
	var rad := int(ln) + 10
	for y in range(maxi(0, int(cy) - rad), mini(N, int(cy) + rad)):
		for x in range(maxi(0, int(cx) - rad), mini(N, int(cx) + rad)):
			var p := inv * Vector2(x + 0.5, y + 0.5)
			if not _in_tri(p, a, b, c):
				continue
			if shadow:
				_over(img, x, y, Color(0, 0, 0, 0.5))
			else:
				var t := clampf((4.0 - p.y) / (4.0 + ln), 0.0, 1.0)
				_over(img, x, y, _sample([[0.0, Color(70 / 255.0, 68 / 255.0, 66 / 255.0, 0.95)], [0.5, Color(120 / 255.0, 118 / 255.0, 114 / 255.0, 0.95)], [1.0, Color(50 / 255.0, 48 / 255.0, 46 / 255.0, 0.9)]], t))

static func _in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var neg := d1 < 0 or d2 < 0 or d3 < 0
	var pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (neg and pos)

static func _dart(img: Image) -> void:
	_radial(img, 128, 128, 20, 124, [[0.0, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.5)], [0.6, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.25)], [1.0, Color(20 / 255.0, 16 / 255.0, 12 / 255.0, 0.0)]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 9:
		var ang := rng.randf() * TAU
		var dist := rng.randf() * 80.0
		var r := 6.0 + rng.randf() * 5.0
		_radial(img, 128.0 + cos(ang) * dist, 128.0 + sin(ang) * dist * 0.7, 0, r, [[0.0, Color(10 / 255.0, 8 / 255.0, 6 / 255.0, 0.9)], [0.7, Color(40 / 255.0, 35 / 255.0, 30 / 255.0, 0.7)], [1.0, Color(40 / 255.0, 35 / 255.0, 30 / 255.0, 0.0)]])

static func _pit(img: Image) -> void:
	_radial(img, 128, 128, 10, 110, [[0.0, Color(4 / 255.0, 3 / 255.0, 2 / 255.0, 0.95)], [0.55, Color(18 / 255.0, 14 / 255.0, 10 / 255.0, 0.7)], [1.0, Color(18 / 255.0, 14 / 255.0, 10 / 255.0, 0.0)]], 90.0)
	# contour sombre de la fosse (ellipse 88 x 70, trait 6)
	for y in N:
		for x in N:
			var dx := (x + 0.5 - 128.0) / 88.0
			var dy := (y + 0.5 - 128.0) / 70.0
			var d := (sqrt(dx * dx + dy * dy) - 1.0) * 79.0
			if absf(d) <= 3.0:
				_over(img, x, y, Color(0, 0, 0, 0.6 * clampf(3.5 - absf(d), 0.0, 1.0)))

static func _gas(img: Image) -> void:
	_radial(img, 128, 128, 10, 120, [[0.0, Color(90 / 255.0, 180 / 255.0, 70 / 255.0, 0.55)], [0.5, Color(70 / 255.0, 140 / 255.0, 60 / 255.0, 0.32)], [1.0, Color(70 / 255.0, 140 / 255.0, 60 / 255.0, 0.0)]])

## Plan posé à plat sur le sol.
static func make_mesh(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := 1.9 if (kind == "pit" or kind == "gas") else 1.5
	q.size = Vector2(s, s)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = texture(kind)
	m.render_priority = 1
	mi.material_override = m
	mi.rotation.x = -PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
