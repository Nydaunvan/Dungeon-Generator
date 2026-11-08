class_name ThemeMaterials
extends RefCounted
## Matériaux (mur / sol / plafond) par thème, d'après texFromB64 / materialsForTheme du JS.
## Thèmes PNG (damp, lava, temple) : rendu net (pixel-art) ; thèmes JPEG : rendu lissé, répété 3x3.

const PIXEL_THEMES := ["damp", "lava", "temple"]
## Thèmes à jeu de textures PBR complet (wall / floor / ceil dans <thème>_hd et <thème>_lite), une tuile de 4 u = une case.
const PBR_PROCEDURAL := ["dirt", "ice", "ruins"]
## Mur et sol « pierre » en vrai matériau 3D (couleur + normales + occlusion/rugosité) : deux jeux de textures dans le projet,
## 2048 px pour l'exécutable Windows (stone_hd) et 1024 px pour le Web et le mobile (stone_lite).
## Chaque export ne garde que son jeu (filtres d'exclusion dans export_presets.cfg) ; dans l'éditeur on choisit selon la plateforme.
const STONE_HD := "res://assets/themes/stone_hd/"
const STONE_LITE := "res://assets/themes/stone_lite/"
const STONE_WALL_REPEAT := 2.0    # répétitions de la texture par pan de mur (entier : les pans voisins se raccordent)
const STONE_FLOOR_REPEAT := 1.0   # idem pour une case de sol
## Mur du Cachot humide : briques brun-vert en matériau 3D, mêmes deux jeux de résolution (damp_hd / damp_lite).
## Thème Lave : mur et plafond en lave (couleur, normales, rugosité, émission des fissures incandescentes), sol en roche.
## Temple ancien : mur et plafond en pierres plates (Bricks075A), sol de mousse et de feuilles mortes (Ground068).
const TEMPLE_WALL_REPEAT := 1.0
const TEMPLE_FLOOR_REPEAT := 1.0
const LAVA_WALL_REPEAT := 1.0
const LAVA_FLOOR_REPEAT := 1.0
const LAVA_EMISSION := 0.75
const DAMP_FLOOR_REPEAT := 1.0    # terre rocailleuse du sol : une répétition par case
const DAMP_WALL_REPEAT := 0.5     # la texture 2048 couvre deux pans : briques de taille raisonnable (un pan en montre le quart)
## Thème « gothic » (Atlas Noir) : pierre anthracite. Jeux de textures attendus : assets/themes/gothic_hd/ (2048) et gothic_lite/ (1024), avec
## wall_*, floor_* et ceil_* (… _albedo.jpg, _normal.png, _orm.jpg ; voir assets/themes/gothic_LISEZMOI.md). Tant que ces fichiers n'existent pas,
## le thème est TEMPORAIRE : relief et rugosité de la pierre classique, couleur ramenée au gris froid (voir `_gothic_derived`) ; `gothic_placeholder` vaut alors true.
const GOTHIC_WALL_REPEAT := 1.0      # une tuile de 4 u = une case : grosses pierres, raccord par case
const GOTHIC_FLOOR_REPEAT := 1.0
const GOTHIC_CEIL_REPEAT := 1.0
const GOTHIC_WALL_TINT := Color(0.60, 0.65, 0.74)
const GOTHIC_FLOOR_TINT := Color(0.50, 0.54, 0.60)
const GOTHIC_CEIL_TINT := Color(0.40, 0.43, 0.50)
static var gothic_placeholder := false
static var _gray: Dictionary = {}
static var _cache: Dictionary = {}

## Thème lave en version « Forges du monde brisé » (option des réglages, jeu de textures lava2 présent).
static func lava2_on(theme: String) -> bool:
	return theme == "lava" and Settings.lava_v2 and _stone_dir("lava2") != ""

static func for_theme(theme: String) -> Dictionary:
	if theme != "gothic" and not ResourceLoader.exists("res://assets/themes/%s_wall.jpg" % theme) \
			and not ResourceLoader.exists("res://assets/themes/%s_wall.png" % theme):
		theme = "stone"
	var reflect: bool = VisualFx.is_forward() and bool(Settings.opt("fx_reflect")) and VisualFx.WET_THEMES.has(theme)
	var relief: bool = VisualFx.is_forward() and bool(Settings.opt("fx_parallax"))
	var lava2 := theme == "lava" and Settings.lava_v2 and _stone_dir("lava2") != ""      # lave : « Forges du monde brisé » (basalte) ; sinon ancien rendu
	var key := "%s|%d|%d|%d|%d" % [theme, 1 if Settings.texture_hd() else 0, 1 if reflect else 0, 1 if relief else 0, 1 if lava2 else 0]   # un jeu de matériaux par réglage de textures et d'effets
	if _cache.has(key):
		return _cache[key]
	var pixel := PIXEL_THEMES.has(theme)
	var mats := {}
	if theme == "gothic":
		mats = _gothic_mats()
	else:
		for part in ["wall", "floor", "ceil"]:
			mats[part] = _make(theme, part, pixel)
	if PBR_PROCEDURAL.has(theme):      # terre, glace, ruines : jeux complets (couleur, normales, rugosité) générés par tools/gen_theme_textures.py
		for part in ["wall", "floor", "ceil"]:
			var pm := _stone_pbr(part, 1.0, theme)
			if pm != null:
				pm.vertex_color_use_as_albedo = true      # variation de teinte par pan (LevelBuilder._vary) : casse la répétition de la texture
				if theme == "ice":      # glace plus sombre : les torches y dessinent des pools de lumière au lieu d'un bloc bleu uniformément éclairé
					pm.albedo_color = Color(0.62, 0.68, 0.78) if part != "ceil" else Color(0.7, 0.74, 0.82)
				mats[part] = pm
	if theme == "damp":
		mats["wall"].uv1_scale = Vector3(2, 2, 1)
		var dwall := _stone_pbr("wall", DAMP_WALL_REPEAT, "damp")
		if dwall != null:
			mats["wall"] = dwall
			mats["ceil"] = dwall   # plafond : mêmes briques que les murs
		var dfloor := _stone_pbr("floor", DAMP_FLOOR_REPEAT, "damp")
		if dfloor != null:
			mats["floor"] = dfloor
	if theme == "temple":
		var twall := _stone_pbr("wall", TEMPLE_WALL_REPEAT, "temple")
		if twall != null:
			mats["wall"] = twall
			mats["ceil"] = twall
		var tfloor := _stone_pbr("floor", TEMPLE_FLOOR_REPEAT, "temple")
		if tfloor != null:
			mats["floor"] = tfloor
	if lava2:
		for part in ["wall", "floor", "ceil"]:
			var lm := _stone_pbr(part, 1.0, "lava2")
			if lm != null:
				lm.vertex_color_use_as_albedo = true      # variation de teinte par pan (LevelBuilder._vary)
				mats[part] = lm
	elif theme == "lava":
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

## Mur, sol et plafond du thème gothic : vrais jeux « gothic_hd / gothic_lite » s'ils existent, sinon version temporaire dérivée de la pierre.
static func _gothic_mats() -> Dictionary:
	var wall := _stone_pbr("wall", GOTHIC_WALL_REPEAT, "gothic")
	var floor_ := _stone_pbr("floor", GOTHIC_FLOOR_REPEAT, "gothic")
	var ceil_ := _stone_pbr("ceil", GOTHIC_CEIL_REPEAT, "gothic")
	gothic_placeholder = wall == null or floor_ == null
	if wall == null:
		wall = _gothic_derived("wall", GOTHIC_WALL_REPEAT, GOTHIC_WALL_TINT)
	if floor_ == null:
		floor_ = _gothic_derived("floor", GOTHIC_FLOOR_REPEAT, GOTHIC_FLOOR_TINT)
	if ceil_ == null:
		if gothic_placeholder:
			ceil_ = _gothic_derived("floor", GOTHIC_CEIL_REPEAT, GOTHIC_CEIL_TINT)
		else:
			ceil_ = wall.duplicate() as StandardMaterial3D      # vrais jeux sans plafond dédié : le mur, plus sombre et à plus grande échelle
			ceil_.albedo_color = Color(0.62, 0.64, 0.70)
			ceil_.uv1_scale = Vector3(1, 1, 1)
	for m in [wall, floor_, ceil_]:
		m.vertex_color_use_as_albedo = true      # variation de teinte par pan (LevelBuilder._vary) : casse la répétition de la texture
	return {"wall": wall, "floor": floor_, "ceil": ceil_}

## TEMPORAIRE : matériau de pierre classique (normales, occlusion, rugosité) dont la couleur est passée en gris contrasté puis teintée froid.
static func _gothic_derived(part: String, repeat: float, tint: Color) -> StandardMaterial3D:
	var m := _stone_pbr(part, repeat)
	if m == null:
		return placeholder(tint.darkened(0.5))
	m.albedo_texture = _cool_gray(m.albedo_texture)
	m.albedo_color = tint
	m.metallic_specular = 0.3
	return m

## Texture en niveaux de gris contrastés (calculée une fois par texture et par résolution).
static func _cool_gray(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var k := tex.resource_path
	if _gray.has(k):
		return _gray[k]
	var img := tex.get_image()
	var out: Texture2D = tex
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGB8)
		img.adjust_bcs(0.95, 1.25, 0.0)
		img.generate_mipmaps()
		out = ImageTexture.create_from_image(img)
	_gray[k] = out
	return out

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
