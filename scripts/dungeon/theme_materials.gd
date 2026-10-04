class_name ThemeMaterials
extends RefCounted
## Matériaux (mur / sol / plafond) par thème, d'après texFromB64 / materialsForTheme du JS.
## Thèmes PNG (damp, lava, temple) : rendu net (pixel-art) ; thèmes JPEG : rendu lissé, répété 3x3.

const PIXEL_THEMES := ["damp", "lava", "temple"]
## Mur « pierre » en vrai matériau 3D (couleur + normales + occlusion/rugosité) : deux jeux de textures dans le projet,
## 2048 px pour l'exécutable Windows (stone_hd) et 1024 px pour le Web et le mobile (stone_lite).
## Chaque export ne garde que son jeu (filtres d'exclusion dans export_presets.cfg) ; dans l'éditeur on choisit selon la plateforme.
const STONE_HD := "res://assets/themes/stone_hd/"
const STONE_LITE := "res://assets/themes/stone_lite/"
const STONE_WALL_REPEAT := 2.0   # répétitions de la texture par pan de mur (entier : les pans voisins se raccordent)
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
	if theme == "stone":
		var pbr := _stone_wall()
		if pbr != null:
			mats["wall"] = pbr
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

## Dossier du jeu de textures de pierre à utiliser ("" si aucun) : 1024 sur Web/mobile, 2048 ailleurs.
static func _stone_dir() -> String:
	var small := OS.has_feature("web") or OS.has_feature("mobile")
	var order := [STONE_LITE, STONE_HD] if small else [STONE_HD, STONE_LITE]
	for d in order:
		if ResourceLoader.exists(d + "wall_albedo.jpg"):
			return d
	return ""

static func _stone_wall() -> StandardMaterial3D:
	var d := _stone_dir()
	if d == "":
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(d + "wall_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(d + "wall_normal.png")
	var orm: Texture2D = load(d + "wall_orm.jpg")   # R = occlusion ambiante, G = rugosité
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_specular = 0.35
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(STONE_WALL_REPEAT, STONE_WALL_REPEAT, 1)
	return m

static func placeholder(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
