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
}
const NEUTRAL := {"sat": 1.0, "contrast": 1.0, "bright": 1.0, "shadow": Color(0, 0, 0), "light": Color(1, 1, 1)}
## Thèmes à sol brillant : les reflets (SSR) n'y sont actifs qu'avec leur rugosité abaissée (voir ThemeMaterials).
const WET_THEMES := {"damp": 0.42, "ice": 0.30, "lava": 0.55}

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
	var g: Dictionary = NEUTRAL
	if Settings.opt("fx_grade") and not outdoor:
		g = GRADES.get(theme, GRADES["stone"])
	env.adjustment_enabled = g != NEUTRAL
	if env.adjustment_enabled:
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
	env.ssao_enabled = fwd and bool(Settings.opt("fx_ssao")) and not outdoor
	if env.ssao_enabled:
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
