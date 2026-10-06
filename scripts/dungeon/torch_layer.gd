class_name TorchLayer
extends Node3D
## Torches murales. Chaque torche est un vrai objet 3D (plaque murale, bras, anneau, manche incliné, tête enveloppée,
## braise) qui porte une flamme 3D en volume (shader animé) et un halo. La flamme est posée à partir de la géométrie
## de la torche (FLAME_BASE_LOCAL) : elle reste calée sur la tête quel que soit l'angle de vue.
## Pour rester léger sur mobile / Web, tout est regroupé en quelques MultiMesh (une poignée d'appels de dessin
## pour tout le niveau) et animé par le shader : aucun calcul par torche côté CPU.
## Seules les torches proches du joueur reçoivent en plus un « rig » mutualisé : vraie lumière vacillante,
## fumée légère qui s'évapore et étincelles rares.

# --- géométrie de la torche, repère local : origine = point d'accroche, +Y = haut, +Z = vers l'intérieur de la salle,
# --- le mur est en Z = WALL_Z (les torches sont posées à 4 cm du mur)
const WALL_Z := -0.04
const SH_BOT := Vector3(0.0, -0.24, 0.045)     # bas du manche
const SH_TOP := Vector3(0.0, 0.07, 0.175)      # haut du manche (incliné de ~23° vers l'avant)
const HEAD_LEN := 0.07                         # la tête dépasse du manche de cette longueur
const EMBER_Y := 0.012                         # épaisseur de la braise
## Pied de la flamme : centre de la braise, au sommet de la tête (même repère local).
static var FLAME_BASE_LOCAL: Vector3 = _ember_center() + Vector3(0.0, EMBER_Y - 0.006, 0.0)
## Teinte du bois / fer par thème (multipliée dans la couleur des sommets).
const TORCH_TINT := {"stone": Color(1, 1, 1), "dirt": Color(1.0, 0.92, 0.78), "damp": Color(0.82, 0.95, 0.88),
	"ruins": Color(0.93, 0.9, 0.88), "ice": Color(0.78, 0.88, 1.0), "lava": Color(0.78, 0.68, 0.66),
	"temple": Color(1.0, 0.9, 0.62), "village_forward": Color(1.0, 0.9, 0.62), "village_return": Color(0.82, 0.95, 0.88)}

# --- réglages (à ajuster à l'œil) ---
const POOL := 9                  # rigs (lumière + fumée + étincelles) en tout, dont ceux qui s'éteignent en fondu (≥ torches Ultra + 2)
# nombre de torches éclairées en même temps : réglage « Torches avec lumière » (Settings.torch_lights)
const ACTIVATE_R := 24.0         # distance max (unités) pour recevoir un rig
const REFRESH := 0.15            # secondes entre deux réaffectations
const FADE_SPEED := 2.2          # allumage / extinction d'un rig (≈ 0,45 s)
const FLAME_H := 0.34            # hauteur de la flamme (m)
const FLAME_R := 0.085           # rayon max de la flamme
const SMOKE_N := 9               # particules de fumée par torche (avant réglage « Particules »)
const SPARK_N := 3               # étincelles par torche (idem)
const LIGHT_ENERGY := 1.1
const LIGHT_RANGE := 7.5
const SMOKE_ALPHA := 0.45        # opacité max de la fumée (légère mais lisible)

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 flame_color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform float gain = 1.1;

varying float v_h;
varying vec3 v_p;
varying float v_seed;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void vertex() {
	float h = UV.y;
	float seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 40.0;
	float t = TIME + seed;
	VERTEX.xz *= 1.0 + sin(t * 0.9) * 0.06;
	VERTEX.y *= 1.0 + sin(t * 1.6 + 1.0) * 0.12 + sin(t * 4.5) * 0.05;
	float sway = h * h;
	VERTEX.x += (sin(t * 5.1 + h * 3.0) * 0.5 + sin(t * 8.3) * 0.25) * 0.035 * sway;
	VERTEX.z += sin(t * 4.3 + h * 2.4 + 1.7) * 0.5 * 0.03 * sway;
	float n = vnoise(vec3(VERTEX.x * 14.0, h * 3.0 - t * 2.2, VERTEX.z * 14.0 + seed));
	VERTEX.xz *= 1.0 + (n - 0.5) * 0.4 * sway;
	v_h = h;
	v_p = VERTEX;
	v_seed = seed;
}

void fragment() {
	float h = v_h;
	float t = TIME + v_seed;
	float n1 = vnoise(vec3(v_p.x * 18.0, h * 4.0 - t * 2.6, v_p.z * 18.0 + v_seed));
	float n2 = vnoise(vec3(v_p.x * 34.0 + 5.0, h * 8.0 - t * 4.1, v_p.z * 34.0));
	float tex = n1 * 0.65 + n2 * 0.35;
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float body = pow(ndv, 1.3);
	float tip = 1.0 - smoothstep(0.45, 1.0, h + (tex - 0.5) * 0.55);
	float foot = smoothstep(0.0, 0.14, h);
	float a = body * tip * foot * (0.55 + 0.6 * tex);
	vec3 col = mix(flame_color.rgb, core_color.rgb, clamp(body * body * (1.0 - h * 0.8), 0.0, 1.0));
	col = mix(col, flame_color.rgb * vec3(1.0, 0.45, 0.3), smoothstep(0.55, 1.0, h));
	ALBEDO = col * gain;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Halo additif face caméra, vacillant (échelle + opacité) animé par le shader.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D glow_tex : source_color, filter_linear_mipmap;
uniform vec4 glow_color : source_color = vec4(1.0, 0.69, 0.38, 1.0);

varying float v_a;

void vertex() {
	float seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 40.0;
	float p = TIME * (0.85 + fract(seed) * 0.5) + seed;
	VERTEX.xy *= (0.45 + sin(p) * 0.08) / 0.5;
	v_a = clamp(0.55 + sin(p * 1.3) * 0.2, 0.0, 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 t = texture(glow_tex, UV);
	ALBEDO = glow_color.rgb * t.rgb;
	ALPHA = t.a * v_a;
}
"""

## Un rig réutilisable : lumière + fumée + étincelles.
class TorchFx extends RefCounted:
	var root: Node3D
	var smoke: CPUParticles3D
	var sparks: CPUParticles3D
	var light: OmniLight3D
	var torch := -1          # indice de la torche servie (-1 = libre)
	var target := 0.0        # 1 = allumé, 0 = en train de s'éteindre
	var level := 0.0         # fondu courant 0..1
	var phase := 0.0
	var speed := 1.0

var light_scale := 1.0      # intensité des torches du niveau (réglage « lightTorch » de l'admin / 1,4)

var _torches: Array = []    # {pos, fpos, gpos, rot, theme, flame, glow, light_color, light_k, rig}
var _rigs: Array = []
var _time: float = 0.0
var _tick: float = 0.0
static var _torch_mesh: ArrayMesh
static var _flame_shader: Shader
static var _glow_shader: Shader
static var _flame_mesh: ArrayMesh
static var _flame_mats: Dictionary = {}
static var _glow_mats: Dictionary = {}
static var _smoke_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D

func _ready() -> void:
	_build_batches()
	for i in POOL:
		_rigs.append(_make_rig())
	Settings.changed.connect(_on_quality)

## Réglages graphiques modifiés : ajuste le nombre de particules des rigs existants (le nombre de lumières est relu à chaque réaffectation).
func _on_quality() -> void:
	for r in _rigs:
		r.smoke.amount = Settings.pc(SMOKE_N)
		r.sparks.amount = Settings.pc(SPARK_N)

func add_torch(pos: Vector3, rot: float, theme: String) -> void:
	var cfg: Dictionary = Data.constants.get("CANDELABRA_THEME", {})
	var c: Dictionary = cfg.get(theme, cfg.get("stone", {}))
	var basis := Basis(Vector3.UP, rot)       # +Z local = vers l'intérieur de la salle
	var flame_col := _hex(int(c.get("flame", 0xffb050)))
	var glow_col := _hex(int(c.get("glow", 0xffb060)))
	var base := pos + basis * FLAME_BASE_LOCAL   # pied de la flamme = braise de la torche
	_torches.append({
		"pos": pos,
		"fpos": base,
		"gpos": base + Vector3(0.0, FLAME_H * 0.44, 0.0),
		"rot": rot, "theme": theme, "flame": flame_col, "glow": glow_col,
		"light_color": glow_col.lerp(flame_col, 0.35),
		"light_k": clampf(float(c.get("glowOpacity", 0.75)) / 0.75, 0.6, 1.3),
		"rig": null})

# ---------------------------------------------------------------- lots (MultiMesh)

## Regroupe toutes les torches en quelques MultiMesh : flamme + cœur + halo par thème, et un seul lot pour les torches 3D.
func _build_batches() -> void:
	if _torches.is_empty():
		return
	var by_theme := {}
	var bodies: Array = []
	var tints: Array = []
	for t in _torches:
		var th: String = t.theme
		if not by_theme.has(th):
			by_theme[th] = {"flame": [], "inner": [], "glow": [], "fc": t.flame, "gc": t.glow}
		var g: Dictionary = by_theme[th]
		var b := Basis(Vector3.UP, float(t.rot))
		g.flame.append(Transform3D(b, t.fpos))
		g.inner.append(Transform3D(b.scaled_local(Vector3(0.52, 0.72, 0.52)), t.fpos))
		g.glow.append(Transform3D(Basis.IDENTITY, t.gpos))
		bodies.append(Transform3D(b, t.pos))
		tints.append(TORCH_TINT.get(th, Color.WHITE))
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2(0.5, 0.5)
	for th in by_theme:
		var g: Dictionary = by_theme[th]
		add_child(_multimesh(glow_quad, g.glow, _get_glow_mat(str(th), g.gc)))
		add_child(_multimesh(_get_flame_mesh(), g.flame, _get_flame_mat(str(th), false, g.fc)))
		add_child(_multimesh(_get_flame_mesh(), g.inner, _get_flame_mat(str(th), true, g.fc)))
	# torches 3D : matériaux portés par le maillage (bois / fer éclairés, braise lumineuse), teinte par instance
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _get_torch_mesh()
	mm.instance_count = bodies.size()
	for i in bodies.size():
		mm.set_instance_transform(i, bodies[i])
		mm.set_instance_color(i, tints[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "TorchBodies"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

static func _multimesh(mesh: Mesh, xforms: Array, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

# ---------------------------------------------------------------- rigs (lumière, fumée, étincelles)

func _make_rig() -> TorchFx:
	var r := TorchFx.new()
	r.root = Node3D.new()
	r.root.visible = false
	add_child(r.root)
	r.smoke = _make_smoke()
	r.root.add_child(r.smoke)
	r.sparks = _make_sparks()
	r.root.add_child(r.sparks)
	r.light = OmniLight3D.new()
	r.light.omni_range = LIGHT_RANGE
	r.light.omni_attenuation = 1.3
	r.light.shadow_enabled = false
	r.light.position = Vector3(0.0, FLAME_H * 0.65, 0.28)
	r.root.add_child(r.light)
	r.phase = randf() * TAU
	r.speed = 0.85 + randf() * 0.5
	return r

func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Settings.pc(SMOKE_N)
	p.lifetime = 2.8
	p.lifetime_randomness = 0.3
	p.randomness = 0.5
	p.local_coords = false
	p.fixed_fps = 30
	p.emitting = false
	p.position = Vector3(0.0, FLAME_H * 0.9, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.035
	p.direction = Vector3(0.0, 1.0, 0.3)     # monte et s'éloigne un peu du mur (+Z local = vers l'intérieur)
	p.spread = 18.0
	p.initial_velocity_min = 0.20
	p.initial_velocity_max = 0.34
	p.gravity = Vector3(0.0, 0.04, 0.0)
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.23
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = 4.0
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 3.2))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.95, 0.66, 0.4, 0.0), Color(0.78, 0.64, 0.52, SMOKE_ALPHA),
		Color(0.58, 0.54, 0.5, SMOKE_ALPHA * 0.6), Color(0.45, 0.45, 0.46, 0.0)])
	p.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = _get_smoke_mat()
	p.mesh = qm
	return p

func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Settings.pc(SPARK_N)
	p.lifetime = 1.8
	p.lifetime_randomness = 0.6
	p.explosiveness = 0.85
	p.randomness = 1.0
	p.local_coords = false
	p.fixed_fps = 30
	p.emitting = false
	p.position = Vector3(0.0, FLAME_H * 0.6, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3(0.0, 1.0, 0.2)
	p.spread = 35.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.55
	p.gravity = Vector3(0.0, -0.12, 0.0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.055
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(0.8, 0.2, 0.05, 0.0)])
	p.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = _get_spark_mat()
	p.mesh = qm
	return p

func _free_rig() -> TorchFx:
	for r in _rigs:
		if r.torch < 0:
			return r
	return null

func _assign(r: TorchFx, ti: int) -> void:
	var t: Dictionary = _torches[ti]
	var flame: Color = t.flame
	r.torch = ti
	r.target = 1.0
	r.level = 0.0
	t["rig"] = r
	r.root.position = t.fpos
	r.root.rotation.y = float(t.rot)
	r.light.light_color = t.light_color
	r.light.light_energy = 0.0
	r.smoke.color = Color.WHITE.lerp(flame, 0.3)
	r.sparks.color = Color.WHITE.lerp(flame, 0.3)
	r.root.visible = true
	r.smoke.restart()
	r.smoke.emitting = true
	r.sparks.restart()
	r.sparks.emitting = true

func _release(r: TorchFx) -> void:
	if r.torch >= 0:
		_torches[r.torch]["rig"] = null
	r.torch = -1
	r.level = 0.0
	r.target = 0.0
	r.smoke.emitting = false
	r.sparks.emitting = false
	r.root.visible = false

## Réaffecte les rigs aux torches les plus proches de la caméra (position dans le repère de la couche).
func _refresh(cam_pos: Vector3) -> void:
	var r2 := ACTIVATE_R * ACTIVATE_R
	var cand: Array = []
	for i in _torches.size():
		var d2 := cam_pos.distance_squared_to(_torches[i].fpos)
		if d2 <= r2:
			cand.append([d2, i])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var want := {}
	for k in mini(Settings.torch_lights(), cand.size()):
		want[int(cand[k][1])] = true
	for r in _rigs:
		if r.torch >= 0 and not want.has(r.torch):
			r.target = 0.0      # fondu sortant (la fumée cesse d'être émise), puis le rig est libéré
			r.smoke.emitting = false
			r.sparks.emitting = false
	for ti in want:
		var rig = _torches[ti].rig
		if rig != null:
			rig.target = 1.0
			rig.smoke.emitting = true
			rig.sparks.emitting = true
		else:
			var free := _free_rig()
			if free != null:
				_assign(free, int(ti))

func _update_rig(r: TorchFx, delta: float) -> void:
	if r.torch < 0:
		return
	r.level = move_toward(r.level, r.target, delta * FADE_SPEED)
	if r.level <= 0.0 and r.target <= 0.0:
		_release(r)
		return
	var t: Dictionary = _torches[r.torch]
	var p := _time * r.speed + r.phase
	var flick := 1.0 + (sin(p) * 0.10 + sin(p * 2.7) * 0.06 + sin(p * 7.3) * 0.04) * Settings.motion_k()
	r.light.light_energy = LIGHT_ENERGY * light_scale * float(t.light_k) * smoothstep(0.0, 1.0, r.level) * flick

func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	if _tick >= REFRESH:
		_tick = 0.0
		var cam := get_viewport().get_camera_3d()
		if cam != null and not _torches.is_empty():
			_refresh(to_local(cam.global_position))
	for r in _rigs:
		_update_rig(r, delta)

# ---------------------------------------------------------------- ressources partagées

static func _get_flame_shader() -> Shader:
	if _flame_shader == null:
		_flame_shader = Shader.new()
		_flame_shader.code = FLAME_SHADER
	return _flame_shader

static func _get_glow_shader() -> Shader:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_SHADER
	return _glow_shader

static func _get_flame_mat(theme: String, inner: bool, flame: Color) -> ShaderMaterial:
	var key := "%s_%d" % [theme, 1 if inner else 0]
	if _flame_mats.has(key):
		return _flame_mats[key]
	var m := ShaderMaterial.new()
	m.shader = _get_flame_shader()
	if inner:
		m.set_shader_parameter("flame_color", flame.lerp(Color.WHITE, 0.55))
		m.set_shader_parameter("core_color", Color(1.0, 0.97, 0.85).lerp(flame, 0.15))
		m.set_shader_parameter("gain", 1.25)
	else:
		m.set_shader_parameter("flame_color", flame)
		m.set_shader_parameter("core_color", flame.lerp(Color(1.0, 0.95, 0.75), 0.6))
		m.set_shader_parameter("gain", 1.1)
	_flame_mats[key] = m
	return m

static func _get_glow_mat(theme: String, glow: Color) -> ShaderMaterial:
	if _glow_mats.has(theme):
		return _glow_mats[theme]
	var m := ShaderMaterial.new()
	m.shader = _get_glow_shader()
	m.set_shader_parameter("glow_tex", ProceduralTextures.glow())
	m.set_shader_parameter("glow_color", glow)
	_glow_mats[theme] = m
	return m

static func _flame_radius(h: float) -> float:
	return FLAME_R * pow(maxf(sin(PI * pow(clampf(h, 0.0, 1.0), 0.65)), 0.0), 0.9)

## Goutte de révolution (base fine, ventre bas, pointe effilée). UV.y = hauteur normalisée.
static func _get_flame_mesh() -> ArrayMesh:
	if _flame_mesh != null:
		return _flame_mesh
	var seg := 10
	var ring := 9
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in ring + 1:
		var h := float(j) / ring
		var r := _flame_radius(h)
		var dr := (_flame_radius(h + 0.02) - _flame_radius(h - 0.02)) / (0.04 * FLAME_H)
		for i in seg + 1:
			var a := TAU * float(i) / seg
			var cs := cos(a)
			var sn := sin(a)
			verts.append(Vector3(cs * r, h * FLAME_H, sn * r))
			norms.append(Vector3(cs, -dr, sn).normalized())
			uvs.append(Vector2(float(i) / seg, h))
	for j in ring:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			idx.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-0.2, -0.02, -0.2), Vector3(0.4, FLAME_H + 0.1, 0.4))   # le shader déplace les sommets
	_flame_mesh = mesh
	return mesh

static func _particle_material(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

static func _get_smoke_mat() -> StandardMaterial3D:
	if _smoke_mat == null:
		_smoke_mat = _particle_material(ProceduralTextures.smoke(), false)
	return _smoke_mat

static func _get_spark_mat() -> StandardMaterial3D:
	if _spark_mat == null:
		_spark_mat = _particle_material(ProceduralTextures.glow(), true)
	return _spark_mat

static func _hex(v: int) -> Color:
	return Color.hex((v << 8) | 0xff)

# ---------------------------------------------------------------- modèle 3D de la torche

static func _shaft_axis() -> Vector3:
	return (SH_TOP - SH_BOT).normalized()

## Centre du dessus de la tête (prolongement du manche).
static func _head_top() -> Vector3:
	return SH_TOP + _shaft_axis() * HEAD_LEN

## Centre de la braise : juste au-dessus de la calotte carbonisée.
static func _ember_center() -> Vector3:
	return _head_top() + _shaft_axis() * 0.012

static func _get_torch_mesh() -> ArrayMesh:
	if _torch_mesh != null:
		return _torch_mesh
	var wood := Color(0.27, 0.17, 0.09)
	var cloth := Color(0.36, 0.27, 0.15)
	var char_ := Color(0.07, 0.05, 0.035)
	var iron := Color(0.17, 0.17, 0.18)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ax := _shaft_axis()
	# plaque murale + quatre rivets
	_box(st, Vector3(0.0, 0.0, WALL_Z + 0.014 + 0.002), Vector3(0.055, 0.11, 0.014), iron)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector3(0.03 * sx, 0.07 * sy, WALL_Z + 0.032)
			_frustum(st, c, c + Vector3(0.0, 0.0, 0.008), 0.009, 0.006, 6, iron.lightened(0.12), true)
	# bras horizontal, renfort en diagonale et anneau qui tient le manche
	var ring_c := SH_BOT + ax * (0.21 / ax.y)         # point du manche à y = -0.03
	_box(st, Vector3(0.0, -0.03, (WALL_Z + 0.03 + ring_c.z) * 0.5), Vector3(0.012, 0.012, (ring_c.z - WALL_Z - 0.03) * 0.5), iron)
	_frustum(st, Vector3(0.0, -0.16, WALL_Z + 0.03), Vector3(0.0, -0.05, ring_c.z - 0.012), 0.010, 0.009, 6, iron, true)
	_frustum(st, ring_c - ax * 0.016, ring_c + ax * 0.016, 0.033, 0.033, 12, iron, false)
	# manche de bois, bagues de fer et pommeau
	_frustum(st, SH_BOT - ax * 0.025, SH_BOT, 0.012, 0.021, 10, wood, true)
	_frustum(st, SH_BOT, SH_TOP, 0.021, 0.026, 12, wood, true)
	for k in [0.18, 0.4]:
		var pc := SH_BOT.lerp(SH_TOP, k)
		_frustum(st, pc - ax * 0.007, pc + ax * 0.007, 0.029, 0.029, 12, iron, false)
	# tête : étoffe enroulée qui s'évase, cerclage de fer, calotte carbonisée
	var h0 := SH_BOT.lerp(SH_TOP, 0.8)
	var top := _head_top()
	var mid := h0.lerp(top, 0.55)
	_frustum(st, h0, mid, 0.029, 0.047, 12, cloth, true)
	_frustum(st, mid, top, 0.047, 0.057, 12, cloth.darkened(0.25), true)
	_frustum(st, top - ax * 0.026, top - ax * 0.012, 0.060, 0.060, 12, iron, false)
	_frustum(st, top, top + ax * 0.012, 0.057, 0.050, 12, char_, true)
	var body := st.commit()
	# braise (surface lumineuse) : petit dôme horizontal au sommet de la tête
	var em := SurfaceTool.new()
	em.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e0 := _ember_center()
	_frustum(em, e0, e0 + Vector3(0.0, EMBER_Y, 0.0), 0.046, 0.026, 10, Color.WHITE, true)
	em.commit(body)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.82
	mat.metallic_specular = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.surface_set_material(0, mat)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.45, 0.12)
	body.surface_set_material(1, glow)
	_torch_mesh = body
	return body

static func _v(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)

## Tronc de cône d'axe a→b (rayons ra, rb). Sens horaire vu de l'extérieur (face avant de Godot).
static func _frustum(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, seg: int, c: Color, caps: bool) -> void:
	var axis := (b - a)
	var len_ := axis.length()
	axis = axis / len_
	var u := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.UP).normalized()
	var v := axis.cross(u)      # (u, v, axis) direct
	u = v.cross(axis)
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		var r0 := u * cos(a0) + v * sin(a0)
		var r1 := u * cos(a1) + v * sin(a1)
		var n0 := (r0 * len_ + axis * (ra - rb)).normalized()
		var n1 := (r1 * len_ + axis * (ra - rb)).normalized()
		var pa0 := a + r0 * ra
		var pa1 := a + r1 * ra
		var pb0 := b + r0 * rb
		var pb1 := b + r1 * rb
		_v(st, pa0, n0, c); _v(st, pb0, n0, c); _v(st, pb1, n1, c)
		_v(st, pa0, n0, c); _v(st, pb1, n1, c); _v(st, pa1, n1, c)
		if caps:
			_v(st, b, axis, c); _v(st, pb1, axis, c); _v(st, pb0, axis, c)
			_v(st, a, -axis, c); _v(st, pa0, -axis, c); _v(st, pa1, -axis, c)

## Boîte alignée sur les axes locaux (centre, demi-dimensions).
static func _box(st: SurfaceTool, center: Vector3, h: Vector3, c: Color) -> void:
	for n in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var up := Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
		var r: Vector3 = up.cross(n)
		var hr := absf(r.x) * h.x + absf(r.y) * h.y + absf(r.z) * h.z
		var hu := absf(up.x) * h.x + absf(up.y) * h.y + absf(up.z) * h.z
		var hn := absf(n.x) * h.x + absf(n.y) * h.y + absf(n.z) * h.z
		var o: Vector3 = center + n * hn
		var bl := o - r * hr - up * hu
		var tl := o - r * hr + up * hu
		var tr := o + r * hr + up * hu
		var br := o + r * hr - up * hu
		_v(st, bl, n, c); _v(st, tl, n, c); _v(st, tr, n, c)
		_v(st, bl, n, c); _v(st, tr, n, c); _v(st, br, n, c)
