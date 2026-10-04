class_name LavaBar3D
extends Control
## Barre de chargement en vraie 3D : un canal de pierre cerclé de bronze que la lave remplit.
## La lave est un shader (bruit déformé, croûte refroidie, front incandescent) ; elle éclaire réellement la pierre et le bronze,
## projette des étincelles, et allume une à une dix gemmes sertie dans la paroi au passage du front.
## Rendu à double définition (suréchantillonnage + MSAA) puis réduit : bords nets, quelle que soit la taille d'écran.

const BAR_SIZE := Vector2(780, 200)
const SS := 2.0                     # suréchantillonnage
const HALF := 5.0                   # demi-longueur de la lave (unités 3D)
const GEMS := 10

const LAVA_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float progress = 0.0;
uniform float time_s = 0.0;
varying float v_lava;

float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 5; i++){ s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; }
	return s;
}

void vertex(){
	float m = 1.0 - smoothstep(progress - 0.012, progress, UV.x);
	float bulge = sin(UV.y * 3.14159);
	float wob = fbm(vec2(UV.x * 14.0 - time_s * 0.6, UV.y * 3.0 + time_s * 0.2));
	VERTEX.y += m * (0.07 * bulge + 0.05 * wob);
	v_lava = m;
}

void fragment(){
	vec2 p = vec2(UV.x * 10.0, UV.y) * 1.7;
	float t = time_s;
	vec2 q = vec2(fbm(p + vec2(-t * 0.25, 0.0)), fbm(p + vec2(5.2, 1.3) + vec2(t * 0.08, -t * 0.05)));
	float h = fbm(p + 2.3 * q + vec2(-t * 0.38, 0.0));
	float front = progress + (fbm(vec2(UV.y * 7.0, t * 0.7)) - 0.5) * 0.014;
	float lava = 1.0 - smoothstep(front - 0.003, front + 0.003, UV.x);
	float behind = max(front - UV.x, 0.0);
	float hot = exp(-behind * 11.0);

	float k = clamp(h * 1.25 + q.x * 0.2 + hot * 0.32 - 0.05, 0.0, 1.0);
	vec3 c = mix(vec3(0.16, 0.02, 0.01), vec3(0.9, 0.13, 0.02), smoothstep(0.12, 0.42, k));
	c = mix(c, vec3(1.0, 0.56, 0.07), smoothstep(0.4, 0.7, k));
	c = mix(c, vec3(1.0, 0.8, 0.35), smoothstep(0.78, 1.0, k) * 0.7);
	// plaques de croûte refroidie : la lave vive se devine entre elles
	float plates = smoothstep(0.46, 0.60, fbm(p * 0.85 + vec2(-t * 0.05, 3.0)));
	c *= 1.0 - plates * (1.0 - hot) * 0.88;
	// front incandescent
	float edge = exp(-abs(UV.x - front) * 70.0) * step(0.003, progress);
	c += vec3(1.0, 0.7, 0.3) * edge * 1.1;
	// bords du canal plus sombres
	float wall = smoothstep(0.0, 0.16, UV.y) * smoothstep(1.0, 0.84, UV.y);
	c *= mix(0.45, 1.0, wall);

	// partie non remplie : obsidienne, quelques braises lointaines
	float spark = smoothstep(0.80, 0.92, fbm(p * 2.6 + 11.0)) * (0.5 + 0.5 * sin(t * 1.7 + UV.x * 40.0));
	vec3 cold = vec3(0.07, 0.05, 0.045) + vec3(1.0, 0.28, 0.05) * spark * 0.22;
	cold += vec3(0.09, 0.07, 0.07) * smoothstep(0.5, 0.85, fbm(p * 0.6 + 4.0));
	ALBEDO = mix(cold, c * 1.05, lava);
}
"""

var value := 0.0
var _vp: SubViewport
var _cam: Camera3D
var _lava: MeshInstance3D
var _lava_mat: ShaderMaterial
var _front_light: OmniLight3D
var _sparks: CPUParticles3D
var _gems: Array = []
var _t := 0.0

func _init() -> void:
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(BAR_SIZE * SS)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_build_world()
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

func _mat(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func _box(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_world() -> void:
	var root := Node3D.new()
	_vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.36, 0.26)
	env.ambient_light_energy = 1.1
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.28, 0.2, 0.15)
	psm.sky_horizon_color = Color(0.7, 0.45, 0.28)
	psm.ground_horizon_color = Color(0.45, 0.28, 0.16)
	psm.ground_bottom_color = Color(0.08, 0.05, 0.03)
	sky.sky_material = psm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	_cam = Camera3D.new()
	_cam.fov = 25.5
	_cam.position = Vector3(0, 6.6, 3.7)
	_cam.look_at_from_position(_cam.position, Vector3(0, -0.2, 0.25))
	root.add_child(_cam)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.7
	key.rotation_degrees = Vector3(-52, -18, 0)
	root.add_child(key)

	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/themes/stone_wall.jpg")
	stone.albedo_color = Color(1.25, 1.1, 0.95)
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.9, 0.9, 0.9)
	stone.roughness = 0.92
	var bronze := _mat(Color(0.62, 0.45, 0.24), 0.95, 0.34)
	var bronze_dark := _mat(Color(0.3, 0.2, 0.1), 0.9, 0.5)

	# canal : socle, deux parois, extrémités de bronze
	_box(root, Vector3(0, -0.6, 0), Vector3(11.0, 0.6, 2.6), stone)
	_box(root, Vector3(0, -0.075, -0.98), Vector3(10.7, 0.45, 0.58), stone)
	_box(root, Vector3(0, -0.15, 0.98), Vector3(10.7, 0.3, 0.58), stone)
	_box(root, Vector3(0, -0.3, 0), Vector3(10.7, 0.1, 1.4), stone)
	for sgn in [-1.0, 1.0]:
		_box(root, Vector3(sgn * 5.55, -0.2, 0), Vector3(0.9, 0.9, 2.7), bronze)
		_box(root, Vector3(sgn * 5.55, 0.28, 0), Vector3(0.7, 0.1, 2.3), bronze_dark)
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.5
		knob.mesh = sm
		knob.material_override = bronze
		knob.position = Vector3(sgn * 5.55, 0.3, 0)
		root.add_child(knob)
	# listels de bronze sur le dessus des parois + rivets
	for z in [-0.98, 0.98]:
		_box(root, Vector3(0, 0.17 if z < 0 else 0.02, z), Vector3(10.7, 0.06, 0.62), bronze)
		_box(root, Vector3(0, 0.2 if z < 0 else 0.05, z), Vector3(10.7, 0.03, 0.14), bronze_dark)
	for i in 22:
		var x := -5.25 + i * 0.5
		for z in [-0.98, 0.98]:
			var rv := MeshInstance3D.new()
			var rs := SphereMesh.new()
			rs.radius = 0.07
			rs.height = 0.14
			rv.mesh = rs
			rv.material_override = bronze
			rv.position = Vector3(x, 0.22 if z < 0 else 0.07, z + (0.2 if z > 0 else -0.2))
			root.add_child(rv)
	# gemmes serties dans la paroi avant : elles s'allument au passage de la lave
	for i in GEMS:
		var gx := -HALF + (i + 1) * (2.0 * HALF) / (GEMS + 1)
		var setting := _box(root, Vector3(gx, -0.17, 1.285), Vector3(0.38, 0.38, 0.06), bronze)
		setting.rotation_degrees = Vector3(0, 0, 45)
		var gm := MeshInstance3D.new()
		var gs := SphereMesh.new()
		gs.radius = 0.12
		gs.height = 0.3
		gs.radial_segments = 4
		gs.rings = 2
		gm.mesh = gs
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.04, 0.03)
		mat.roughness = 0.2
		mat.metallic = 0.3
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.32, 0.06)
		mat.emission_energy_multiplier = 0.0
		gm.material_override = mat
		gm.position = Vector3(gx, -0.17, 1.33)
		root.add_child(gm)
		_gems.append({"mat": mat, "thr": float(i + 1) / (GEMS + 1)})

	# lave
	_lava = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0 * HALF, 1.5)
	pm.subdivide_width = 220
	pm.subdivide_depth = 10
	_lava.mesh = pm
	var sh := Shader.new()
	sh.code = LAVA_SHADER
	_lava_mat = ShaderMaterial.new()
	_lava_mat.shader = sh
	_lava.material_override = _lava_mat
	_lava.position = Vector3(0, -0.12, 0)
	root.add_child(_lava)

	_front_light = OmniLight3D.new()
	_front_light.light_color = Color(1.0, 0.5, 0.15)
	_front_light.light_energy = 0.0
	_front_light.omni_range = 4.5
	_front_light.position = Vector3(-HALF, 0.7, 0.3)
	root.add_child(_front_light)

	_sparks = CPUParticles3D.new()
	_sparks.amount = 28
	_sparks.lifetime = 1.6
	_sparks.emitting = false
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sparks.emission_box_extents = Vector3(0.1, 0.02, 0.6)
	_sparks.direction = Vector3(0.25, 1, 0)
	_sparks.spread = 35.0
	_sparks.initial_velocity_min = 0.8
	_sparks.initial_velocity_max = 2.2
	_sparks.gravity = Vector3(0, -1.2, 0)
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.6
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spm.vertex_color_use_as_albedo = true
	spm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spm.albedo_color = Color(1.0, 0.7, 0.3)
	qm.material = spm
	_sparks.mesh = qm
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	cg.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.12, 0.9), Color(0.7, 0.1, 0.02, 0.0)])
	_sparks.color_ramp = cg
	_sparks.position = Vector3(-HALF, 0.05, 0.0)
	root.add_child(_sparks)

func _process(delta: float) -> void:
	_t += delta
	if _lava_mat == null:
		return
	var v := clampf(value, 0.0, 1.0)
	_lava_mat.set_shader_parameter("progress", v)
	_lava_mat.set_shader_parameter("time_s", _t)
	var fx := -HALF + 2.0 * HALF * v
	_front_light.position.x = fx
	_front_light.light_energy = (1.7 + 0.35 * sin(_t * 9.0) + 0.2 * sin(_t * 23.0)) * clampf(v * 40.0, 0.0, 1.0)
	_sparks.position.x = fx
	_sparks.emitting = v > 0.003 and v < 0.999
	for g in _gems:
		var on := smoothstep(float(g.thr) - 0.01, float(g.thr) + 0.04, v)
		(g.mat as StandardMaterial3D).emission_energy_multiplier = on * (1.15 + 0.2 * sin(_t * 5.0 + float(g.thr) * 20.0))
	# léger balancement de la caméra : la profondeur se lit
	_cam.position.x = sin(_t * 0.5) * 0.18
	_cam.look_at(Vector3(0, -0.2, 0.25))
