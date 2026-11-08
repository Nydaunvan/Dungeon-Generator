class_name VisualFx
extends RefCounted
## Effets visuels propres au rendu Forward+ (étalonnage par thème, halo lumineux, occlusion ambiante, reflets, ombres,
## décalques, relief). Chaque effet est une option des réglages graphiques (fx_*), purement visuelle : aucune règle n'en dépend.
## Repli OpenGL (Compatibilité) : seuls l'étalonnage et le halo existent ; les autres sont ignorés sans erreur.

## Étalonnage par thème : {sat, contrast, bright, shadow, light} ; « shadow » et « light » teintent les ombres et les hautes lumières.
const GRADES := {
	"stone": {"sat": 1.04, "contrast": 1.08, "bright": 1.0, "shadow": Color(0.0, 0.0, 0.0), "light": Color(1.0, 0.96, 0.9)},
	"dirt": {"sat": 1.06, "contrast": 1.06, "bright": 1.0, "shadow": Color(0.02, 0.01, 0.0), "light": Color(1.0, 0.93, 0.82)},
	"damp": {"sat": 0.95, "contrast": 1.1, "bright": 0.98, "shadow": Color(0.0, 0.02, 0.02), "light": Color(0.88, 1.0, 0.95)},
	"ruins": {"sat": 0.88, "contrast": 1.12, "bright": 0.98, "shadow": Color(0.0, 0.0, 0.01), "light": Color(0.96, 0.96, 0.98)},
	"ice": {"sat": 0.96, "contrast": 1.06, "bright": 1.03, "shadow": Color(0.0, 0.01, 0.05), "light": Color(0.86, 0.95, 1.0)},
	"lava": {"sat": 1.12, "contrast": 1.14, "bright": 1.0, "shadow": Color(0.05, 0.0, 0.0), "light": Color(1.0, 0.86, 0.72)},
	"temple": {"sat": 1.05, "contrast": 1.1, "bright": 1.0, "shadow": Color(0.02, 0.01, 0.0), "light": Color(1.0, 0.92, 0.74)},
	# gothic (Atlas Noir) : couleurs retenues, contraste marqué, ombres légèrement bleutées ; les hautes lumières restent neutres, donc les torches restent chaudes
	"gothic": {"sat": 0.78, "contrast": 1.16, "bright": 0.98, "shadow": Color(0.0, 0.006, 0.022), "light": Color(0.97, 0.98, 1.0)},
}
const NEUTRAL := {"sat": 1.0, "contrast": 1.0, "bright": 1.0, "shadow": Color(0, 0, 0), "light": Color(1, 1, 1)}
## Thèmes à sol brillant : les reflets (SSR) n'y sont actifs qu'avec leur rugosité abaissée (voir ThemeMaterials).
const WET_THEMES := {"damp": 0.42, "ice": 0.30, "lava": 0.55, "gothic": 0.52}

## Ambiance lumineuse propre à un thème (les autres thèmes gardent l'ambiance chaude de main.gd / warm_up.gd, facteurs à 1).
## ambient_color / fog_* : lumière ambiante et brouillard ; ambient_k : facteur sur l'énergie ambiante du niveau ;
## torch_* : portée, énergie et atténuation des torches murales éclairées ; player_* : torche du groupe.
const THEME_LIGHT := {
	# thèmes classiques : même méthode que le gothic (ambiance sombre et teintée, torches à pools de lumière courts et contrastés), en moins marqué ;
	# la torche du groupe et les torches murales gardent la couleur chaude de chaque thème (CANDELABRA_THEME)
	"stone": {"ambient_color": Color("2b2620"), "ambient_k": 0.92, "fog_color": Color("050403"), "fog_density": 0.033,
		"torch_range_k": 0.86, "torch_energy_k": 1.6, "torch_atten": 1.5,
		"player_color": Color("ffc27c"), "player_range_k": 0.8, "player_energy_k": 1.1, "player_atten": 1.35},
	"dirt": {"ambient_color": Color("2e2015"), "ambient_k": 0.9, "fog_color": Color("070302"), "fog_density": 0.036,
		"torch_range_k": 0.8, "torch_energy_k": 1.7, "torch_atten": 1.6,
		"player_color": Color("ffb36a"), "player_range_k": 0.78, "player_energy_k": 1.15, "player_atten": 1.4},
	"damp": {"ambient_color": Color("172629"), "ambient_k": 0.9, "fog_color": Color("020708"), "fog_density": 0.036,
		"torch_range_k": 0.78, "torch_energy_k": 1.8, "torch_atten": 1.6,
		"player_color": Color("d4e8da"), "player_range_k": 0.72, "player_energy_k": 1.15, "player_atten": 1.4},
	"ruins": {"ambient_color": Color("242832"), "ambient_k": 0.9, "fog_color": Color("04050a"), "fog_density": 0.032,
		"torch_range_k": 0.8, "torch_energy_k": 1.8, "torch_atten": 1.6,
		"player_color": Color("e8dcc6"), "player_range_k": 0.75, "player_energy_k": 1.15, "player_atten": 1.4},
	"ice": {"ambient_color": Color("172740"), "ambient_k": 0.8, "fog_color": Color("04080f"), "fog_density": 0.03,
		"torch_range_k": 0.78, "torch_energy_k": 1.7, "torch_atten": 1.5,
		"player_color": Color("d0e4ff"), "player_range_k": 0.75, "player_energy_k": 1.15, "player_atten": 1.4},
	"lava": {"ambient_color": Color("2d1511"), "ambient_k": 0.85, "fog_color": Color("0a0302"), "fog_density": 0.04,
		"torch_range_k": 0.75, "torch_energy_k": 1.5, "torch_atten": 1.6,
		"player_color": Color("ffb272"), "player_range_k": 0.75, "player_energy_k": 1.1, "player_atten": 1.4},
	# lave v2 « Forges du monde brisé » : ambiance très sombre, rouge-brun sans saturation ; le magma et les braseros éclairent localement, la torche du groupe reste sobre
	# brouillard : anthracite à peine chaud (jamais orange : l'orange vient du magma et des torches) ; vol_k : part de la lumière des sources qui se diffuse dans la brume volumétrique,
	# vol_albedo : couleur de cette brume, mist_k : densité du volume de brume (Forward+)
	"lava2": {"ambient_color": Color("2a2628"), "ambient_k": 0.95, "fog_color": Color("151211"), "fog_density": 0.028,
		"vol_k": 0.25, "vol_albedo": Color(0.30, 0.285, 0.28), "mist_k": 0.45,
		"torch_range_k": 0.78, "torch_energy_k": 1.45, "torch_atten": 1.8,
		"player_color": Color("f2e0cf"), "player_range_k": 0.75, "player_energy_k": 1.1, "player_atten": 1.5},
	"temple": {"ambient_color": Color("2c2716"), "ambient_k": 0.95, "fog_color": Color("070502"), "fog_density": 0.032,
		"torch_range_k": 0.82, "torch_energy_k": 1.7, "torch_atten": 1.5,
		"player_color": Color("ffd694"), "player_range_k": 0.78, "player_energy_k": 1.15, "player_atten": 1.4},
	"gothic": {"ambient_color": Color("1a2333"), "ambient_k": 0.85, "fog_color": Color("03050a"), "fog_density": 0.03,
		"torch_range_k": 0.72, "torch_energy_k": 2.1, "torch_atten": 1.7,
		"player_color": Color("bdc9de"), "player_range_k": 0.6, "player_energy_k": 1.2, "player_atten": 1.4,
		# monstres Atlas Noir : lumière de contour froide sur la silhouette (voir AtlasSpriteMaterial.apply_theme) ; désactivée (0) : elle formait un halo à l'intérieur du liseré
		"sprite_rim_color": Color("8fb0e8"), "sprite_rim_k": 0.0},
}

## Réglages d'ambiance du thème (la lave en version « Forges du monde brisé » a les siens, clef « lava2 »).
static func _tl(theme: String) -> Dictionary:
	if theme == "lava" and Settings.lava_v2:
		return THEME_LIGHT.get("lava2", THEME_LIGHT.get("lava", {}))
	return THEME_LIGHT.get(theme, {})

## Valeur d'ambiance du thème (`default` quand le thème n'a pas d'ambiance propre).
static func light_k(theme: String, key: String, default: float = 1.0) -> float:
	var tl: Dictionary = _tl(theme)
	return float(tl.get(key, default))

## Couleur d'ambiance du thème (`default` quand le thème n'a pas d'ambiance propre).
static func light_color(theme: String, key: String, default: Color) -> Color:
	var tl: Dictionary = _tl(theme)
	return tl.get(key, default)

static var _luts: Dictionary = {}
static var _blood: Array = []

static var force_forward := false        # outils : traite le rendu comme Forward+ (les effets sont alors configurés, même si l'écran ne les montre pas)

static func is_forward() -> bool:
	if force_forward:
		return true
	var m := RenderingServer.get_current_rendering_method()
	return m == "forward_plus" or m == "mobile"

## Applique les effets d'environnement (étalonnage, halo, occlusion, reflets) pour ce thème. `outdoor` : village, sans effet de donjon.
static func apply_environment(env: Environment, theme: String, outdoor: bool) -> void:
	if env == null:
		return
	var tl: Dictionary = _tl(theme)
	if not tl.is_empty() and not outdoor:      # ambiance propre au thème : gris bleuté très sombre, brouillard discret
		env.ambient_light_color = tl.ambient_color
		env.fog_light_color = tl.fog_color
		env.fog_density = float(tl.fog_density)
	var g: Dictionary = NEUTRAL
	if Settings.opt("fx_grade") and not outdoor:
		g = GRADES.get(theme, GRADES["stone"])
	env.adjustment_enabled = g != NEUTRAL or outdoor
	if outdoor:      # village : couleurs plus franches et contraste un peu plus marqué, sans table de couleurs
		env.adjustment_saturation = 1.22
		env.adjustment_contrast = 1.1
		env.adjustment_brightness = 1.0
		env.adjustment_color_correction = null
	elif env.adjustment_enabled:
		env.adjustment_saturation = float(g.sat)
		env.adjustment_contrast = float(g.contrast)
		env.adjustment_brightness = float(g.bright)
		env.adjustment_color_correction = _lut(g)
	var glow: bool = bool(Settings.opt("fx_glow"))
	env.glow_enabled = glow
	if glow:
		env.glow_intensity = 0.55
		env.glow_strength = 0.95
		env.glow_bloom = 0.04
		env.glow_hdr_threshold = 0.8
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var fwd := is_forward()
	env.ssao_enabled = fwd and bool(Settings.opt("fx_ssao"))
	if env.ssao_enabled and outdoor:
		env.ssao_radius = 2.2
		env.ssao_intensity = 1.6
		env.ssao_power = 1.5
		env.ssao_detail = 0.5
		env.ssao_light_affect = 0.15
	elif env.ssao_enabled:
		env.ssao_radius = 1.6
		env.ssao_intensity = 2.2
		env.ssao_power = 1.6
		env.ssao_detail = 0.6
		env.ssao_light_affect = 0.25
	env.ssr_enabled = fwd and bool(Settings.opt("fx_reflect")) and not outdoor and WET_THEMES.has(theme)
	if env.ssr_enabled:
		env.ssr_max_steps = 48
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
		env.ssr_depth_tolerance = 0.25

## Table de correspondance des couleurs (1D) : ombres vers `shadow`, hautes lumières vers `light`.
static func _lut(g: Dictionary) -> GradientTexture1D:
	var key := "%s|%s" % [g.shadow, g.light]
	if _luts.has(key):
		return _luts[key]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([g.shadow, g.light])
	var t := GradientTexture1D.new()
	t.gradient = grad
	t.width = 256
	_luts[key] = t
	return t

## Tache de sang (texture procédurale, 3 variantes créées une fois) pour les décalques posés au sol après un combat.
static func blood_texture(variant: int) -> Texture2D:
	if _blood.is_empty():
		for v in 3:
			var noise := FastNoiseLite.new()
			noise.seed = 4711 + v * 97
			noise.frequency = 0.045
			noise.fractal_octaves = 4
			var drops := FastNoiseLite.new()
			drops.seed = 9001 + v * 31
			drops.frequency = 0.16
			var size := 128
			var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
			for y in size:
				for x in size:
					var dx := (x - size * 0.5) / (size * 0.5)
					var dy := (y - size * 0.5) / (size * 0.5)
					var r := sqrt(dx * dx + dy * dy)
					var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
					var core := clampf(1.0 - r * 1.15 + (n - 0.5) * 0.9, 0.0, 1.0)
					var d := clampf((drops.get_noise_2d(x, y) - 0.38) * 6.0, 0.0, 1.0) * clampf(1.15 - r, 0.0, 1.0)
					var a := clampf(maxf(smoothstep(0.1, 0.55, core), d * 0.9), 0.0, 1.0)
					var shade := 0.55 + 0.45 * n
					img.set_pixel(x, y, Color(0.30 * shade, 0.015, 0.02, a * 0.9))
			_blood.append(ImageTexture.create_from_image(img))
	return _blood[posmod(variant, _blood.size())]

## Résolution du brouillard volumétrique selon le niveau graphique (plus fin = plus net, plus coûteux) : largeur/hauteur et profondeur du volume.
static func apply_volumetric_quality() -> void:
	var lvl := str(Settings.level)
	var xy := 128 if lvl == "ultra" else 96
	var depth := 96 if lvl == "ultra" else 64
	RenderingServer.environment_set_volumetric_fog_volume_size(xy, depth)
	RenderingServer.environment_set_volumetric_fog_filter_active(true)
