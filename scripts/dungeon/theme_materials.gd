class_name ThemeMaterials
extends RefCounted
## Matériaux (mur / sol / plafond) par thème, d'après texFromB64 / materialsForTheme du JS.
## Thèmes PNG (damp, lava, temple) : rendu net (pixel-art) ; thèmes JPEG : rendu lissé, répété 3x3.

const PIXEL_THEMES := ["damp", "lava", "temple"]
## Mur et sol « pierre » en vrai matériau 3D (couleur + normales + occlusion/rugosité) : deux jeux de textures dans le projet,
## 2048 px pour l'exécutable Windows (stone_hd) et 1024 px pour le Web et le mobile (stone_lite).
## Chaque export ne garde que son jeu (filtres d'exclusion dans export_presets.cfg) ; dans l'éditeur on choisit selon la plateforme.
const STONE_HD := "res://assets/themes/stone_hd/"
const STONE_LITE := "res://assets/themes/stone_lite/"
const STONE_WALL_REPEAT := 2.0    # répétitions de la texture par pan de mur (entier : les pans voisins se raccordent)
const STONE_FLOOR_REPEAT := 1.0   # idem pour une case de sol
## Mur du Cachot humide : briques brun-vert en matériau 3D, mêmes deux jeux de résolution (damp_hd / damp_lite).
## Thème Lave : mur et plafond en lave (couleur, normales, rugosité, émission des fissures incandescentes), sol en roche.
const LAVA_WALL_REPEAT := 1.0
const LAVA_FLOOR_REPEAT := 1.0
const LAVA_EMISSION := 0.75
const DAMP_FLOOR_REPEAT := 1.0    # terre rocailleuse du sol : une répétition par case
const DAMP_WALL_REPEAT := 0.5     # la texture 2048 couvre deux pans : briques de taille raisonnable (un pan en montre le quart)
static var _cache: Dictionary = {}

static func for_theme(theme: String) -> Dictionary:
	if not ResourceLoader.exists("res://assets/themes/%s_wall.jpg" % theme) \
			and not ResourceLoader.exists("res://assets/themes/%s_wall.png" % theme):
		theme = "stone"
	var reflect: bool = VisualFx.is_forward() and bool(Settings.opt("fx_reflect")) and VisualFx.WET_THEMES.has(theme)
	var relief: bool = VisualFx.is_forward() and bool(Settings.opt("fx_parallax"))
	var key := "%s|%d|%d|%d" % [theme, 1 if Settings.texture_hd() else 0, 1 if reflect else 0, 1 if relief else 0]   # un jeu de matériaux par réglage de textures et d'effets
	if _cache.has(key):
		return _cache[key]
	var pixel := PIXEL_THEMES.has(theme)
	var mats := {}
	for part in ["wall", "floor", "ceil"]:
		mats[part] = _make(theme, part, pixel)
	if theme == "damp":
		mats["wall"].uv1_scale = Vector3(2, 2, 1)
		var dwall := _stone_pbr("wall", DAMP_WALL_REPEAT, "damp")
		if dwall != null:
			mats["wall"] = dwall
			mats["ceil"] = dwall   # plafond : mêmes briques que les murs
		var dfloor := _stone_pbr("floor", DAMP_FLOOR_REPEAT, "damp")
		if dfloor != null:
			mats["floor"] = dfloor
	if theme == "lava":
		var lwall := _stone_pbr("wall", LAVA_WALL_REPEAT, "lava")
		if lwall != null:
			mats["wall"] = lwall
			mats["ceil"] = lwall
		var lfloor := _stone_pbr("floor", LAVA_FLOOR_REPEAT, "lava")
		if lfloor != null:
			mats["floor"] = lfloor
	if theme == "stone":
		var wall := _stone_pbr("wall", STONE_WALL_REPEAT)
		if wall != null:
			mats["wall"] = wall
			mats["ceil"] = wall   # plafond : même pierre que les murs
		var floor_ := _stone_pbr("floor", STONE_FLOOR_REPEAT)
		if floor_ != null:
			mats["floor"] = floor_
	if reflect:
		var fl: StandardMaterial3D = mats["floor"]
		fl.roughness = float(VisualFx.WET_THEMES[theme])      # sol brillant : les reflets (SSR) y deviennent visibles
		fl.metallic_specular = 0.8
	if relief:
		var wl: StandardMaterial3D = mats["wall"]
		if wl.albedo_texture != null:
			wl.heightmap_enabled = true
			wl.heightmap_texture = _height_tex(wl.albedo_texture)
			wl.heightmap_scale = 0.9
			wl.heightmap_deep_parallax = false
	_cache[key] = mats
	return mats

static var _heights: Dictionary = {}

## Carte de relief déduite des niveaux de gris de la texture (les zones claires ressortent), calculée une fois par texture.
static func _height_tex(tex: Texture2D) -> Texture2D:
	var k := tex.get_rid().get_id()
	if _heights.has(k):
		return _heights[k]
	var img := tex.get_image()
	var out: Texture2D = null
	if img != null:
		if img.is_compressed():
			img.decompress()
		var big := maxi(img.get_width(), img.get_height())
		if big > 512:
			var sc := 512.0 / float(big)
			img.resize(maxi(1, int(img.get_width() * sc)), maxi(1, int(img.get_height() * sc)), Image.INTERPOLATE_BILINEAR)
		img.convert(Image.FORMAT_L8)
		img.adjust_bcs(1.0, 1.35, 1.0)
		img.generate_mipmaps()
		out = ImageTexture.create_from_image(img)
	_heights[k] = out
	return out

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

## Dossier du jeu de textures de pierre à utiliser ("" si aucun) : 1024 ou 2048 selon le réglage « Textures » du niveau graphique
## (Web et mobile n'embarquent que le jeu 1024 : le repli est automatique).
static func _stone_dir(prefix: String = "stone") -> String:
	var small := not Settings.texture_hd()
	var hd := "res://assets/themes/%s_hd/" % prefix
	var lite := "res://assets/themes/%s_lite/" % prefix
	var order := [lite, hd] if small else [hd, lite]
	for d in order:
		if ResourceLoader.exists(d + "wall_albedo.jpg"):
			return d
	return ""

## part : "wall" ou "floor" (fichiers <part>_albedo.jpg, <part>_normal.png, <part>_orm.jpg).
static func _stone_pbr(part: String, repeat: float, prefix: String = "stone") -> StandardMaterial3D:
	var d := _stone_dir(prefix)
	if d == "" or not ResourceLoader.exists(d + part + "_albedo.jpg"):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(d + part + "_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(d + part + "_normal.png")
	var orm: Texture2D = load(d + part + "_orm.jpg")   # R = occlusion ambiante, G = rugosité
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
	m.uv1_scale = Vector3(repeat, repeat, 1)
	if ResourceLoader.exists(d + part + "_emission.jpg"):       # fissures incandescentes (lave)
		m.emission_enabled = true
		m.emission_texture = load(d + part + "_emission.jpg")
		m.emission_energy_multiplier = LAVA_EMISSION
	return m

static func placeholder(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
