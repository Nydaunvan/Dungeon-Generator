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

static var _shader: Shader = null

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
	if _shader == null:
		_shader = Shader.new()
		_shader.code = _CODE
	shader = _shader
	set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
	set_shader_parameter("emission_energy", 0.22)
	set_shader_parameter("rim_amount", 0.25)
	set_shader_parameter("rim_tint_amount", 0.5)
	set_shader_parameter("lod_bias", lod_bias)
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
uniform bool use_normal = false;

void vertex() {
	// face caméra en gardant l'échelle de l'objet (billboard_keep_scale du StandardMaterial3D)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV, lod_bias);
	ALBEDO = a.rgb * albedo_color.rgb;
	ALPHA = a.a * albedo_color.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = texture(emission_tex, UV, lod_bias).rgb * emission_energy;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	}
	RIM = rim_amount;
	RIM_TINT = rim_tint_amount;
}
"
