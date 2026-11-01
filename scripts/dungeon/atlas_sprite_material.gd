class_name AtlasSpriteMaterial
extends ShaderMaterial
## Matériau des sprites éclairés « Atlas Noir » : mêmes réglages que le StandardMaterial3D qu'il remplace (billboard, alpha, éclairage par pixel, auto-éclairage,
## carte de normales, liseré de lumière), avec UN réglage en plus : un biais de mipmap négatif.
##
## Pourquoi : les mipmaps de Godot sont un filtre boîte, et le sprite (1 700 px) s'affiche 2 à 3 fois plus petit : l'image devenait floue (netteté mesurée à
## environ 50 % d'une vraie réduction à 1440p). Un biais de -1,0 ramène la netteté au niveau d'une réduction correcte, sans toucher aux fichiers
## (banc d'essai : tools/sprite_lab.gd). Le moteur « Compatibilité » ignore le biais de la vue 3D : il faut le demander dans le shader.
##
## Les propriétés ci-dessous portent les noms de celles du StandardMaterial3D, pour que le code de combat (fondu, coup reçu, pose de mort) n'ait pas à changer :
## elles lisent et écrivent les paramètres du shader, donc `duplicate()` et les tweens fonctionnent tels quels.

## Biais de mipmap (modifiable par les outils de capture pour comparer).
static var lod_bias := -1.0
## Netteté ajoutée dans le shader (masque flou, limité aux zones pleines et borné par le voisinage : pas de halo). 0 = désactivée (comparaisons).
static var sharpen := 0.5

static var _shader: Shader = null
static var _globals := false

## Réglages d'ambiance propres au thème, partagés par tous les sprites (uniformes globaux : changer de niveau ne reconstruit aucun matériau).
## Liseré froid : seulement les thèmes qui les déclarent (VisualFx.THEME_LIGHT, clés sprite_*) ; les autres gardent des valeurs nulles.
static func ensure_globals() -> void:
	if _globals:
		return
	_globals = true
	RenderingServer.global_shader_parameter_add("atlas_rim_color", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.56, 0.69, 0.91))
	RenderingServer.global_shader_parameter_add("atlas_rim_k", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)

static func apply_theme(theme: String) -> void:
	ensure_globals()
	var rc := VisualFx.light_color(theme, "sprite_rim_color", Color(0.56, 0.69, 0.91))
	RenderingServer.global_shader_parameter_set("atlas_rim_color", Vector3(rc.r, rc.g, rc.b))
	RenderingServer.global_shader_parameter_set("atlas_rim_k", VisualFx.light_k(theme, "sprite_rim_k", 0.0))

var albedo_texture: Texture2D:
	set(v): set_shader_parameter("albedo_tex", v)
	get: return get_shader_parameter("albedo_tex")
var emission_texture: Texture2D:
	set(v): set_shader_parameter("emission_tex", v)
	get: return get_shader_parameter("emission_tex")
var normal_texture: Texture2D:
	set(v):
		set_shader_parameter("normal_tex", v)
		set_shader_parameter("use_normal", v != null)
	get: return get_shader_parameter("normal_tex")
var albedo_color: Color:
	set(v): set_shader_parameter("albedo_color", v)
	get: return get_shader_parameter("albedo_color")
var emission_energy_multiplier: float:
	set(v): set_shader_parameter("emission_energy", v)
	get: return get_shader_parameter("emission_energy")
var rim: float:
	set(v): set_shader_parameter("rim_amount", v)
	get: return get_shader_parameter("rim_amount")
var emission_enabled := true          # même interface que le StandardMaterial3D (le fondu de mort éteint l'auto-éclairage)
var uv1_scale := Vector3.ONE          # idem : le calcul du centre de masse (CombatStage) lit la région de l'image utilisée
var uv1_offset := Vector3.ZERO

func _init() -> void:
	ensure_globals()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _CODE
	shader = _shader
	set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
	set_shader_parameter("emission_energy", 0.22)
	set_shader_parameter("rim_amount", 0.25)
	set_shader_parameter("rim_tint_amount", 0.5)
	set_shader_parameter("lod_bias", lod_bias)
	set_shader_parameter("sharpen", sharpen)
	set_shader_parameter("use_normal", false)

const _CODE := "
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emission_tex : source_color, hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float emission_energy = 0.22;
uniform float rim_amount = 0.25;
uniform float rim_tint_amount = 0.5;
uniform float lod_bias = -1.0;
uniform float sharpen = 0.5;
uniform bool use_normal = false;
global uniform vec3 atlas_rim_color;
global uniform float atlas_rim_k;

void vertex() {
	// face caméra en gardant l'échelle de l'objet (billboard_keep_scale du StandardMaterial3D)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV, lod_bias);
	// netteté : écart au flou de 4 voisins (au pas d'un pixel d'écran), pondéré par l'opacité, borné par le min/max du voisinage
	vec2 ts = 1.0 / vec2(textureSize(albedo_tex, 0));
	vec2 px = vec2(length(vec2(dFdx(UV.x), dFdy(UV.x))), length(vec2(dFdx(UV.y), dFdy(UV.y))));
	vec2 o = max(px * 0.9, ts);
	vec4 n1 = texture(albedo_tex, UV + vec2(o.x, 0.0), lod_bias);
	vec4 n2 = texture(albedo_tex, UV - vec2(o.x, 0.0), lod_bias);
	vec4 n3 = texture(albedo_tex, UV + vec2(0.0, o.y), lod_bias);
	vec4 n4 = texture(albedo_tex, UV - vec2(0.0, o.y), lod_bias);
	float wsum = n1.a + n2.a + n3.a + n4.a;
	vec3 blur = wsum > 0.01 ? (n1.rgb * n1.a + n2.rgb * n2.a + n3.rgb * n3.a + n4.rgb * n4.a) / wsum : a.rgb;
	float interior = smoothstep(0.7, 1.0, min(min(n1.a, n2.a), min(n3.a, n4.a)) * a.a);
	vec3 lo = min(a.rgb, min(min(n1.rgb, n2.rgb), min(n3.rgb, n4.rgb)));
	vec3 hi = max(a.rgb, max(max(n1.rgb, n2.rgb), max(n3.rgb, n4.rgb)));
	vec3 col = clamp(a.rgb + sharpen * interior * (a.rgb - blur), lo, hi);
	ALBEDO = col * albedo_color.rgb;
	ALPHA = a.a * albedo_color.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	vec3 em = texture(emission_tex, UV, lod_bias).rgb * emission_energy;
	// lumière de contour froide : bande intérieure le long de la silhouette (couverture d'opacité autour du pixel), surtout en haut ; nulle hors des thèmes qui la déclarent
	if (atlas_rim_k > 0.001) {
		float r = 0.016;
		float cov = 0.0;
		cov += texture(albedo_tex, UV + vec2(r, 0.0), 3.0).a;
		cov += texture(albedo_tex, UV + vec2(-r, 0.0), 3.0).a;
		cov += texture(albedo_tex, UV + vec2(r * 0.5, r * 0.87), 3.0).a;
		cov += texture(albedo_tex, UV + vec2(-r * 0.5, r * 0.87), 3.0).a;
		cov += texture(albedo_tex, UV + vec2(r * 0.5, -r * 0.87), 3.0).a;
		cov += texture(albedo_tex, UV + vec2(-r * 0.5, -r * 0.87), 3.0).a;
		float edge = a.a * clamp((1.0 - cov / 6.0) * 1.8, 0.0, 1.0);
		float from_top = mix(0.35, 1.0, clamp(1.0 - UV.y, 0.0, 1.0));
		em += atlas_rim_color * edge * from_top * atlas_rim_k * 0.45 * albedo_color.a;
	}
	EMISSION = em;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
"
