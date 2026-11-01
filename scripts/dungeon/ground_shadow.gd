class_name GroundShadow
extends RefCounted
## Ombre de contact et brume basse sous un monstre Atlas Noir : un disque plat posé sur le sol, enfant du sprite (il suit ses déplacements).
## Cœur sombre, doux, qui ancre les pieds ; en périphérie, une brume froide qui dérive lentement, uniquement dans les thèmes qui la déclarent
## (uniforme global atlas_mist_k, voir AtlasSpriteMaterial.apply_theme) : partout ailleurs il ne reste que l'ombre.
## Purement visuel : pas de collision, pas de lumière, une seule surface par monstre ; dessiné AVANT le sprite (render_priority) pour ne jamais le recouvrir.

const SHADOW_ALPHA := 0.6
const FLOOR_GAP := 0.012          # hauteur au-dessus du sol réel (au-dessus des dalles de salle posées à 0,012 / 0,018)

## Interrupteur (outils de capture : comparaison avant / après). false = aucune ombre.
static var enabled := true
static var _mat: ShaderMaterial = null

const _CODE := "
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
global uniform vec3 atlas_mist_color;
global uniform float atlas_mist_k;
uniform float shadow_alpha = 0.6;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = 1.0 - smoothstep(0.08, 0.5, r);
	core *= core;
	float mist = 1.0 - smoothstep(0.15, 1.0, r);
	float n = 0.5 + 0.5 * sin(p.x * 5.0 + TIME * 0.35) * sin(p.y * 4.0 - TIME * 0.27);
	float a_sh = core * shadow_alpha;
	float a_mi = mist * (0.35 + 0.65 * n) * atlas_mist_k * 0.32;
	float a = a_sh + a_mi * (1.0 - a_sh);
	ALBEDO = (vec3(0.0) * a_sh + atlas_mist_color * a_mi * (1.0 - a_sh)) / max(a, 0.001);
	ALPHA = a;
}
"

static func _material() -> ShaderMaterial:
	if _mat == null:
		AtlasSpriteMaterial.ensure_globals()
		var sh := Shader.new()
		sh.code = _CODE
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("shadow_alpha", SHADOW_ALPHA)
		_mat.render_priority = -1
	return _mat

## Disque d'ombre pour un sprite de hauteur `h` ; `floor_y` = hauteur du sol dans le repère du sprite (local).
static func make(h: float, floor_y: float) -> MeshInstance3D:
	if not enabled:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "GroundShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * h * 1.5
	mi.mesh = pm
	mi.material_override = _material()
	mi.position = Vector3(0.0, floor_y + FLOOR_GAP, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
