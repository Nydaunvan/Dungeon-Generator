class_name ThemeMaterials
extends RefCounted
## Matériaux (mur / sol / plafond) par thème, d'après texFromB64 / materialsForTheme du JS.
## Thèmes PNG (damp, lava, temple) : rendu net (pixel-art) ; thèmes JPEG : rendu lissé, répété 3x3.

const PIXEL_THEMES := ["damp", "lava", "temple"]
static var _cache: Dictionary = {}

static func for_theme(theme: String) -> Dictionary:
	if not ResourceLoader.exists("res://assets/themes/%s_wall.jpg" % theme) \
			and not ResourceLoader.exists("res://assets/themes/%s_wall.png" % theme):
		theme = "stone"
	if _cache.has(theme):
		return _cache[theme]
	var pixel := PIXEL_THEMES.has(theme)
	var mats := {}
	for part in ["wall", "floor", "ceil"]:
		mats[part] = _make(theme, part, pixel)
	if theme == "damp":
		mats["wall"].uv1_scale = Vector3(2, 2, 1)
	_cache[theme] = mats
	return mats

static func _make(theme: String, part: String, pixel: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := "res://assets/themes/%s_%s" % [theme, part]
	var path := base + (".png" if pixel else ".jpg")
	if not ResourceLoader.exists(path):
		path = base + (".jpg" if pixel else ".png")
	m.albedo_texture = load(path)
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if pixel \
			else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_scale = Vector3(1, 1, 1) if pixel else Vector3(3, 3, 1)
	return m

static func placeholder(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
