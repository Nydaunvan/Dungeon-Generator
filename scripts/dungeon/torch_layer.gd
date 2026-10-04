class_name TorchLayer
extends Node3D
## Torches murales : bougeoir illustré + flamme et halo animés (billboards additifs, comme le JS).
## Les torches les plus proches du joueur reçoivent en plus un « rig » 3D réel : flamme en volume (shader),
## fumée légère qui s'évapore, étincelles rares et vraie lumière vacillante. Les rigs sont mutualisés
## (un petit nombre, réaffectés aux torches proches) pour rester léger sur mobile et en export Web.

const SHEET := "res://assets/sheets/wall_torches.webp"
const SHEET_COUNT := 5
const THEME_MODEL := {"stone": 0, "dirt": 1, "damp": 2, "ruins": 3, "ice": 2, "lava": 0, "temple": 4, "village_forward": 4, "village_return": 2}
const FLAME_ANCHOR := [Vector2(0.088, 0.273), Vector2(0.063, 0.273), Vector2(0.085, 0.273),
	Vector2(0.092, 0.273), Vector2(0.088, 0.234)]

# --- réglages des effets 3D (à ajuster à l'œil) ---
const POOL := 7                  # rigs 3D en tout (dont ceux qui s'éteignent en fondu)
const ACTIVE := 5                # torches les plus proches qui reçoivent un rig
const ACTIVATE_R := 24.0         # distance max (unités) pour recevoir un rig
const REFRESH := 0.15            # secondes entre deux réaffectations
const FADE_SPEED := 2.2          # allumage / extinction d'un rig (≈ 0,45 s) : fondu enchaîné avec la flamme plate
const FLAME_H := 0.34            # hauteur de la flamme (m)
const FLAME_R := 0.085           # rayon max de la flamme
const FLAME_OFFSET := 0.11       # la flamme est tenue en avant du mur (sinon elle le traverse)
const LIGHT_ENERGY := 1.1
const LIGHT_RANGE := 7.5
const SMOKE_ALPHA := 0.45        # opacité max de la fumée (légère mais lisible)

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 flame_color : source_color = vec4(1.0, 0.7, 0.3, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform float gain = 1.1;
uniform float fade = 1.0;

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
	ALPHA = clamp(a, 0.0, 1.0) * fade;
}
"""

## Un rig 3D réutilisable : flamme en volume + fumée + étincelles + lumière.
class TorchFx extends RefCounted:
	var root: Node3D
	var flame_root: Node3D
	var outer: MeshInstance3D
	var inner: MeshInstance3D
	var mat_outer: ShaderMaterial   # matériaux propres à chaque rig (fondu individuel)
	var mat_inner: ShaderMaterial
	var smoke: CPUParticles3D
	var sparks: CPUParticles3D
	var light: OmniLight3D
	var torch := -1          # indice de la torche servie (-1 = libre)
	var target := 0.0        # 1 = allumé, 0 = en train de s'éteindre
	var level := 0.0         # fondu courant 0..1
	var phase := 0.0
	var speed := 1.0

var light_scale := 1.0      # intensité des torches du niveau (réglage « lightTorch » de l'admin / 1,4)

var _flames: Array = []
var _torches: Array = []    # {fpos, rot, theme, flame, glow, light_color, light_k, bb_flame, rig}
var _rigs: Array = []
var _time: float = 0.0
var _tick: float = 0.0
static var _bowl_mats: Dictionary = {}
static var _flame_shader: Shader
static var _flame_mesh: ArrayMesh
static var _smoke_mat: StandardMaterial3D
static var _spark_mat: StandardMaterial3D

func _ready() -> void:
	for i in POOL:
		_rigs.append(_make_rig())

func add_torch(pos: Vector3, rot: float, theme: String) -> void:
	var cfg: Dictionary = Data.constants.get("CANDELABRA_THEME", {})
	var c: Dictionary = cfg.get(theme, cfg.get("stone", {}))
	var idx: int = THEME_MODEL.get(theme, 0)
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# décalage latéral exprimé dans le repère du mur (même rotation que le JS)
	var side := func(x: float, y: float) -> Vector3:
		return Vector3(x * cos(rot), y, -x * sin(rot))
	# bougeoir (sprite ancré près du bas)
	var bowl := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.36, 0.36)
	bowl.mesh = q
	bowl.material_override = _bowl_material(idx)
	bowl.position = side.call(0.09, -0.04 + (0.5 - 0.08) * 0.36)
	root.add_child(bowl)
	# flamme + halo (billboards : version « de loin », la flamme est masquée quand un rig 3D prend le relais)
	var anchor: Vector2 = FLAME_ANCHOR[idx]
	var group := Node3D.new()
	group.position = side.call(anchor.x, anchor.y)
	root.add_child(group)
	var flame_col := _hex(int(c.get("flame", 0xffb050)))
	var glow_col := _hex(int(c.get("glow", 0xffb060)))
	var glow := _billboard(ProceduralTextures.glow(), Vector2(0.5, 0.5),
		glow_col, true, float(c.get("glowOpacity", 0.75)))
	var flame := _billboard(ProceduralTextures.flame(), Vector2(0.26, 0.34), flame_col, false, 1.0)
	group.add_child(glow)
	group.add_child(flame)
	_flames.append({"flame": flame, "glow": glow, "group": group, "base_pos": group.position,
		"phase": randf() * TAU, "speed": 0.85 + randf() * 0.5, "opacity": float(c.get("glowOpacity", 0.75))})
	# point d'ancrage du rig 3D : pied de la flamme, tenu en avant du mur
	var inward := Vector3(sin(rot), 0.0, cos(rot))
	_torches.append({
		"fpos": pos + side.call(anchor.x, anchor.y - FLAME_H * 0.44) + inward * FLAME_OFFSET,
		"rot": rot, "theme": theme, "flame": flame_col,
		"light_color": glow_col.lerp(flame_col, 0.35),
		"light_k": clampf(float(c.get("glowOpacity", 0.75)) / 0.75, 0.6, 1.3),
		"bb_flame": flame, "rig": null})

# ---------------------------------------------------------------- rigs 3D

func _make_rig() -> TorchFx:
	var r := TorchFx.new()
	r.root = Node3D.new()
	r.root.visible = false
	add_child(r.root)
	r.flame_root = Node3D.new()
	r.root.add_child(r.flame_root)
	r.outer = MeshInstance3D.new()
	r.outer.mesh = _get_flame_mesh()
	r.outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.flame_root.add_child(r.outer)
	r.inner = MeshInstance3D.new()
	r.inner.mesh = _get_flame_mesh()
	r.inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.inner.scale = Vector3(0.52, 0.72, 0.52)
	r.mat_outer = ShaderMaterial.new()
	r.mat_outer.shader = _get_flame_shader()
	r.mat_inner = ShaderMaterial.new()
	r.mat_inner.shader = _get_flame_shader()
	r.outer.material_override = r.mat_outer
	r.inner.material_override = r.mat_inner
	r.flame_root.add_child(r.inner)
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
	p.amount = 9
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
	p.amount = 3
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
	_tint_flame_mats(r, flame)
	r.light.light_color = t.light_color
	r.smoke.color = Color.WHITE.lerp(flame, 0.3)
	r.sparks.color = Color.WHITE.lerp(flame, 0.3)
	r.flame_root.scale = Vector3.ONE * 0.001
	r.light.light_energy = 0.0
	r.root.visible = true
	r.smoke.restart()
	r.smoke.emitting = true
	r.sparks.restart()
	r.sparks.emitting = true

func _release(r: TorchFx) -> void:
	if r.torch >= 0:
		var t: Dictionary = _torches[r.torch]
		t["rig"] = null
		_set_bb_alpha(t.bb_flame, 1.0)
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
	for k in mini(ACTIVE, cand.size()):
		want[int(cand[k][1])] = true
	for r in _rigs:
		if r.torch >= 0 and not want.has(r.torch):
			r.target = 0.0      # fondu sortant, puis le rig est libéré
	for ti in want:
		var rig = _torches[ti].rig
		if rig != null:
			rig.target = 1.0
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
	var fx := 1.0 + sin(p) * 0.06
	var fy := 1.0 + sin(p * 1.8 + 1.0) * 0.12 + sin(p * 5.1) * 0.05
	var k := smoothstep(0.0, 1.0, r.level)
	r.mat_outer.set_shader_parameter("fade", k)
	r.mat_inner.set_shader_parameter("fade", k)
	var s := lerpf(0.7, 1.0, k)          # la flamme 3D ne « pousse » pas de zéro : elle apparaît déjà formée
	r.flame_root.scale = Vector3(fx * s, fy * s, fx * s)
	var flick := 1.0 + sin(p) * 0.10 + sin(p * 2.7) * 0.06 + sin(p * 7.3) * 0.04
	r.light.light_energy = LIGHT_ENERGY * light_scale * float(t.light_k) * k * flick
	_set_bb_alpha(t.bb_flame, 1.0 - smoothstep(0.15, 0.85, r.level))   # la flamme plate s'efface pendant que la 3D apparaît

## Opacité de la flamme billboard d'une torche (masquée quand elle devient invisible).
func _set_bb_alpha(bb: MeshInstance3D, a: float) -> void:
	(bb.material_override as StandardMaterial3D).albedo_color.a = a
	bb.visible = a > 0.01

# ---------------------------------------------------------------- ressources partagées

static func _get_flame_shader() -> Shader:
	if _flame_shader == null:
		_flame_shader = Shader.new()
		_flame_shader.code = FLAME_SHADER
	return _flame_shader

static func _tint_flame_mats(r: TorchFx, flame: Color) -> void:
	r.mat_outer.set_shader_parameter("flame_color", flame)
	r.mat_outer.set_shader_parameter("core_color", flame.lerp(Color(1.0, 0.95, 0.75), 0.6))
	r.mat_outer.set_shader_parameter("gain", 1.1)
	r.mat_inner.set_shader_parameter("flame_color", flame.lerp(Color.WHITE, 0.55))
	r.mat_inner.set_shader_parameter("core_color", Color(1.0, 0.97, 0.85).lerp(flame, 0.15))
	r.mat_inner.set_shader_parameter("gain", 1.25)
	r.mat_outer.set_shader_parameter("fade", 0.0)
	r.mat_inner.set_shader_parameter("fade", 0.0)

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

# ---------------------------------------------------------------- billboards « de loin » + boucle

func _process(delta: float) -> void:
	_time += delta
	for f in _flames:
		var p: float = _time * f["speed"] + f["phase"]
		var flick := 1.0 + sin(p) * 0.10 + sin(p * 2.7) * 0.05
		f["flame"].scale = Vector3(flick, 1.0 + sin(p * 1.8 + 1.0) * 0.14, 1.0)
		var g_scale := (0.45 + sin(p) * 0.08) / 0.5
		f["glow"].scale = Vector3(g_scale, g_scale, 1.0)
		var m: StandardMaterial3D = f["glow"].material_override
		m.albedo_color.a = clampf(0.55 + sin(p * 1.3) * 0.2, 0.0, 1.0)
		f["group"].position = f["base_pos"] + Vector3(sin(p * 0.7) * 0.015, 0, 0)
	_tick += delta
	if _tick >= REFRESH:
		_tick = 0.0
		var cam := get_viewport().get_camera_3d()
		if cam != null and not _torches.is_empty():
			_refresh(to_local(cam.global_position))
	for r in _rigs:
		_update_rig(r, delta)

static func _hex(v: int) -> Color:
	return Color.hex((v << 8) | 0xff)

static func _billboard(tex: Texture2D, size: Vector2, color: Color, additive: bool, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	return mi

static func _bowl_material(idx: int) -> StandardMaterial3D:
	if _bowl_mats.has(idx):
		return _bowl_mats[idx]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = load(SHEET)
	m.uv1_scale = Vector3(1.0 / SHEET_COUNT, 1.0, 1.0)
	m.uv1_offset = Vector3(float(idx) / SHEET_COUNT, 0.0, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bowl_mats[idx] = m
	return m
