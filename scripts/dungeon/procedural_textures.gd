class_name ProceduralTextures
extends RefCounted
## Textures dessinées par code (équivalents des canvas du JS) : flamme, halo, grille de porte, arche.

static var _cache: Dictionary = {}

static func glow() -> Texture2D:
	if _cache.has("glow"):
		return _cache["glow"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_cache["glow"] = t
	return t

static func flame() -> Texture2D:
	if _cache.has("flame"):
		return _cache["flame"]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in size:
		var t := float(y) / float(size - 1)
		if t < 0.05 or t > 0.92:
			continue
		var w := pow(sin(PI * pow(t, 0.7)), 0.9) * 0.34
		for x in size:
			var d := absf(float(x) / float(size - 1) - 0.5)
			var a := clampf((w - d) / 0.05, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_cache["flame"] = tex
	return tex

static func _hex(v: int) -> Color:
	return Color.hex((v << 8) | 0xff)

## Grille de fer (porte) : barreaux verticaux + 3 traverses, fond transparent.
static func door(theme: String) -> Texture2D:
	var key := "door_" + theme
	if _cache.has(key):
		return _cache[key]
	var tints: Dictionary = Data.constants.get("DOOR_TINTS", {})
	var tint: Dictionary = tints.get(theme, tints.get("stone", {"metal": "#7a7a78", "metalDark": "#3a3a38"}))
	var metal := Color(str(tint.get("metal", "#7a7a78")))
	var dark := Color(str(tint.get("metalDark", "#3a3a38")))
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bar_w := 20
	var gap := 44
	var x := gap / 2
	while x < 256:
		img.fill_rect(Rect2i(x - bar_w / 2, 0, bar_w, 256), metal)
		img.fill_rect(Rect2i(x - bar_w / 2, 0, 3, 256), dark)
		img.fill_rect(Rect2i(x + bar_w / 2 - 3, 0, 3, 256), dark)
		img.fill_rect(Rect2i(x - 1, 0, 3, 256), metal.lightened(0.25))
		x += gap
	for yy in [10, 128, 246]:
		img.fill_rect(Rect2i(0, yy - 9, 256, 18), dark)
		img.fill_rect(Rect2i(0, yy - 6, 256, 5), metal)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Arche en ogive à cadre de bronze, posée par-dessus le mur (fond transparent hors arche).
static func arch() -> Texture2D:
	if _cache.has("arch"):
		return _cache["arch"]
	var W := 512
	var H := 512
	var m_x := W * 0.1172
	var apex_y := H * 0.1016
	var sp_y := H * 0.4766
	var floor_y := float(H)
	var cx := W * 0.5
	var h1 := sp_y - apex_y
	var arch_w2 := W - 2.0 * m_x
	var c1y := sp_y - 0.608 * h1
	var c2x := m_x + 0.2308 * arch_w2
	# Bord gauche de l'arche pour chaque ligne (courbe de Bézier échantillonnée)
	var left := PackedFloat32Array()
	left.resize(H)
	left.fill(-1.0)
	var p0 := Vector2(m_x, sp_y)
	var p1 := Vector2(m_x, c1y)
	var p2 := Vector2(c2x, apex_y)
	var p3 := Vector2(cx, apex_y)
	var steps := 600
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		var p := u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
		var row := int(p.y)
		if row >= 0 and row < H and (left[row] < 0.0 or p.x < left[row]):
			left[row] = p.x
	for r in H:
		if r > int(sp_y):
			left[r] = m_x
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# épaisseurs (px) des bandes, de la plus large à l'intérieur
	var bands := [
		{"t": 34.0, "c": Color("070504")},
		{"t": 30.0, "c": Color("7a654b")},
		{"t": 24.0, "c": Color("6b5840"), "grad": true},
		{"t": 6.0, "c": Color("7a654b")},
		{"t": 0.0, "c": Color("000000")},
	]
	for band in bands:
		var sx: float = 1.0 + band["t"] / (arch_w2 * 0.5)
		var sy: float = 1.0 + band["t"] / (floor_y - apex_y)
		for y in H:
			var by := floor_y - (floor_y - y) / sy
			var row := int(by)
			if row < 0 or row >= H or left[row] < 0.0:
				continue
			var l: float = left[row]
			var x0 := int(cx + (l - cx) * sx)
			var x1 := int(cx + ((W - l) - cx) * sx)
			var col: Color = band["c"]
			if band.get("grad", false):
				var k := clampf(float(y) / H, 0.0, 1.0)
				col = Color("6b5840").lerp(Color("241c14"), k)
			img.fill_rect(Rect2i(maxi(x0, 0), y, mini(x1, W - 1) - maxi(x0, 0) + 1, 1), col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["arch"] = tex
	return tex
