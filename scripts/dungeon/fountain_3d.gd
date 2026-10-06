class_name Fountain3D
extends Node3D
## Fontaine en vrai 3D (PROPOSITION, pas encore branchée dans le jeu) : grand bassin octogonal, colonne, vasque haute,
## nappe d'eau qui déborde de la vasque, gerbes qui retombent du sommet, éclaboussures, brume et lumière bleutée.
## Tout est généré par le code (aucun fichier d'image) et l'eau est animée par des shaders.
##
## set_active(true)  : l'eau coule, le bassin se remplit, la lumière s'allume.
## set_active(false) : le débit s'arrête, la nappe s'amincit puis disparaît, le niveau baisse, l'eau devient trouble.
## Dans le jeu, ce sera piloté par l'état de la fontaine : actif tant que « maintenant >= usedAt + délai de recharge »
## (fountainCooldownMinutes, 10 min par défaut), puis désactivé jusqu'à la fin du minuteur.

const POOL_Y_ON := 0.44          # niveau d'eau du grand bassin, fontaine active
const POOL_Y_OFF := 0.235        # niveau d'eau quand elle est tarie
const BOWL_Y := 1.345            # niveau d'eau de la vasque haute
const BOWL_R := 0.53             # rayon intérieur de la vasque
const LIP_Y := 1.40              # hauteur du bord de la vasque, d'où tombe la nappe
const LIP_R := 0.60
const TIP_Y := 1.74              # sommet du fleuron, d'où partent les gerbes
const BASIN_R := 0.91            # rayon (aux sommets) de l'intérieur du bassin octogonal
const FALL_R := 0.665            # rayon où la nappe touche l'eau du bassin
const JET_LAND_R := 0.34         # rayon où les gerbes retombent dans la vasque
const FILL_TIME := 5.0           # secondes pour que le niveau monte / descende
const START_TIME := 1.4          # secondes pour que l'eau se mette à couler
const STOP_TIME := 0.9

var active := true
var _flow := 1.0                 # 0..1, débit courant
var _level := 1.0                # 0..1, niveau d'eau du grand bassin
var _t := 0.0
var _pool: MeshInstance3D
var _pool_up: MeshInstance3D
var _pool_mat: ShaderMaterial
var _pool_up_mat: ShaderMaterial
var _fall_mat: ShaderMaterial
var _splash: CPUParticles3D
var _splash_up: CPUParticles3D
var _mist: CPUParticles3D
var _drops: CPUParticles3D
var _light: OmniLight3D
var _falls: MeshInstance3D

static var _stone_mat: StandardMaterial3D

## Textures de la pierre : deux jeux, 2048 px (Windows) et 1024 px (Web et mobile). Chaque export ne garde que le sien
## (filtres d'exclusion dans export_presets.cfg) ; dans l'éditeur, le choix dépend de la plateforme.
const STONE_HD := "res://assets/themes/fountain_hd/"
const STONE_LITE := "res://assets/themes/fountain_lite/"
const STONE_TILE := 0.7            # répétitions par mètre : la texture couvre ~1,4 m de pierre

# ------------------------------------------------------------------ shaders

const WATER_COMMON := """
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

## Surface de l'eau (bassin et vasque) : rides qui partent de l'impact de la nappe, reflets, écume le long des parois.
const POOL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, specular_schlick_ggx;

uniform float flow = 1.0;
uniform float impact_r = 0.665;
uniform float edge_r = 0.9;
uniform float sides = 8.0;
uniform vec4 shallow : source_color = vec4(0.14, 0.46, 0.52, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.16, 0.24, 1.0);
uniform vec4 murk : source_color = vec4(0.09, 0.15, 0.09, 1.0);
varying vec3 v_pos;
varying vec3 v_ax;
varying vec3 v_ay;
varying vec3 v_az;
""" + WATER_COMMON + """
float height(vec2 p, float act) {
	float d = length(p) - impact_r;
	float rings = sin(abs(d) * 46.0 - TIME * 5.0) * exp(-abs(d) * 3.5);
	float tiny = vn(p * 9.0 + vec2(TIME * 0.5, -TIME * 0.35)) - 0.5;
	float tiny2 = vn(p * 17.0 + vec2(-TIME * 0.7, TIME * 0.4)) - 0.5;
	return (rings * 0.010 + tiny * 0.006 + tiny2 * 0.003) * act;
}
float poly_metric(vec2 p) {
	if (sides < 3.0) {
		return length(p) / edge_r;
	}
	float apothem = edge_r * cos(3.14159265 / sides);
	float m = 0.0;
	for (int k = 0; k < 12; k++) {
		if (float(k) >= sides) { break; }
		float a = (float(k) + 0.5) * 6.2831853 / sides;
		m = max(m, dot(p, vec2(cos(a), sin(a))));
	}
	return m / apothem;
}
void vertex() {
	v_pos = VERTEX;
	v_ax = (MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	v_ay = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	v_az = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
}
void fragment() {
	float act = flow;
	vec2 p = v_pos.xz;
	float e = 0.012;
	float h0 = height(p, act);
	float hx = height(p + vec2(e, 0.0), act);
	float hz = height(p + vec2(0.0, e), act);
	vec3 n_model = normalize(vec3(-(hx - h0) / e, 1.0, -(hz - h0) / e));
	NORMAL = normalize(v_ax * n_model.x + v_ay * n_model.y + v_az * n_model.z);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float m = poly_metric(p);
	vec3 clear = mix(shallow.rgb, deep.rgb, smoothstep(0.15, 0.95, m));
	vec3 col = mix(murk.rgb, clear, smoothstep(0.0, 1.0, act));
	// écume le long des parois et là où la nappe tombe
	float edge = smoothstep(0.88, 1.0, m) * (0.35 + 0.65 * vn(p * 14.0 + TIME * 0.2));
	float ring = exp(-pow((length(p) - impact_r) / 0.045, 2.0)) * (0.4 + 0.6 * vn(p * 22.0 - TIME * 0.8));
	float foam = clamp(edge * (0.25 + 0.5 * act) + ring * act * 0.9, 0.0, 1.0);
	col = mix(col, vec3(0.86, 0.95, 1.0), foam);
	ALBEDO = col;
	EMISSION = clear * 0.07 * act + vec3(0.8, 0.95, 1.0) * foam * 0.08;
	ROUGHNESS = mix(0.32, 0.03, act);
	SPECULAR = 0.9;
	ALPHA = clamp(mix(0.93, 0.80, act) + fres * 0.2 + foam * 0.3, 0.0, 1.0);
}
"""

## Eau qui tombe : nappe festonnée (autour de la vasque) et gerbes en rubans. UV.y = progression le long de l'écoulement.
const FALL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform float flow = 1.0;
uniform float sheet = 1.0;
uniform float streaks = 48.0;
uniform float speed = 1.7;
uniform vec4 tint : source_color = vec4(0.86, 0.95, 1.0, 1.0);
""" + WATER_COMMON + """
float vnp(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(mix(hash(vec2(x0, i.y)), hash(vec2(x1, i.y)), f.x), mix(hash(vec2(x0, i.y + 1.0)), hash(vec2(x1, i.y + 1.0)), f.x), f.y);
}
void fragment() {
	float v = UV.y;
	float t = TIME * speed;
	// front d'eau : monte à mesure que le débit augmente (v = 0 en haut, 1 en bas)
	float reach = flow * 1.12;
	float front = (1.0 - smoothstep(reach - 0.16, reach, v)) * step(0.002, flow);
	float n1 = vnp(vec2(UV.x * streaks, v * 3.2 - t), streaks);
	float n2 = vnp(vec2(UV.x * streaks * 2.0 + 3.0, v * 7.0 - t * 1.6), streaks * 2.0);
	float body = smoothstep(0.32, 0.72, n1 * 0.62 + n2 * 0.38);
	float a;
	float edge = 1.0;
	if (sheet > 0.5) {
		// nappe : bord supérieur épais et continu, trous qui s'ouvrent vers le bas, retombée en gouttes festonnées
		float lobes = vnp(vec2(UV.x * 24.0, 0.0), 24.0);
		float thin = smoothstep(0.55 + lobes * 0.35, 1.0, v);
		a = (0.10 + 0.62 * body) * (1.0 - thin * 0.6);
		a = max(a, (1.0 - smoothstep(0.0, 0.10, v)) * 0.8);
	} else {
		edge = smoothstep(0.0, 0.32, UV.x) * (1.0 - smoothstep(0.68, 1.0, UV.x));
		a = (0.35 + 0.6 * body) * edge;
	}
	a *= front;
	ALBEDO = tint.rgb * (0.78 + 0.35 * body);
	EMISSION = tint.rgb * (0.04 + 0.16 * body) * front;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	ALPHA = clamp(a * (0.5 + 0.5 * flow), 0.0, 0.88);
}
"""

# ------------------------------------------------------------------ cycle de vie

func _ready() -> void:
	_build_stone()
	_build_water()
	_build_falls()
	_build_fx()
	_apply(true)

func set_active(on: bool, instant: bool = false) -> void:
	active = on
	if instant:
		_flow = 1.0 if on else 0.0
		_level = 1.0 if on else 0.0
		_apply(true)

func _process(delta: float) -> void:
	_t += delta
	var flow_speed := 1.0 / START_TIME if active else 1.0 / STOP_TIME
	_flow = move_toward(_flow, 1.0 if active else 0.0, delta * flow_speed)
	# le niveau d'eau suit : il monte dès que l'eau coule, il ne baisse qu'une fois le débit coupé
	if active or _flow <= 0.001:
		_level = move_toward(_level, 1.0 if active else 0.0, delta / FILL_TIME)
	_apply(false)

func _apply(force: bool) -> void:
	if _pool == null:
		return
	var f := smoothstep(0.0, 1.0, _flow)
	var lvl := smoothstep(0.0, 1.0, _level)
	var y := lerpf(POOL_Y_OFF, POOL_Y_ON, lvl)
	_pool.position.y = y
	_pool_mat.set_shader_parameter("flow", f)
	_pool_up_mat.set_shader_parameter("flow", f)
	_fall_mat.set_shader_parameter("flow", f)
	_jet_mat.set_shader_parameter("flow", f)
	_pool_up.visible = _flow > 0.01
	_falls.visible = _flow > 0.01
	_splash.position.y = y + 0.01
	_mist.position.y = y + 0.02
	_splash.emitting = _flow > 0.2
	_splash_up.emitting = _flow > 0.35
	_drops.emitting = _flow > 0.3
	_mist.emitting = _flow > 0.25
	_light.light_energy = 0.9 * f * (1.0 + 0.05 * sin(_t * 2.3))
	_light.visible = f > 0.01

# ------------------------------------------------------------------ pierre

static func _stone_dir() -> String:
	var small := not Settings.texture_hd()
	var order := [STONE_LITE, STONE_HD] if small else [STONE_HD, STONE_LITE]
	for d in order:
		if ResourceLoader.exists(d + "albedo.jpg"):
			return d
	return ""

static func _stone_material() -> StandardMaterial3D:
	if _stone_mat != null:
		return _stone_mat
	var dir := _stone_dir()
	if dir != "":
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = load(dir + "albedo.jpg")
		pm.vertex_color_use_as_albedo = true     # mousse et humidité au pied, ligne d'eau
		pm.normal_enabled = true
		pm.normal_texture = load(dir + "normal.png")
		pm.normal_scale = 1.0
		var orm: Texture2D = load(dir + "orm.jpg")   # R = occlusion, G = rugosité
		pm.ao_enabled = true
		pm.ao_texture = orm
		pm.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		pm.ao_light_affect = 0.6
		pm.roughness = 1.0
		pm.roughness_texture = orm
		pm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		pm.metallic_specular = 0.4
		pm.texture_repeat = true
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_stone_mat = pm
		return pm
	# repli : pierre générée à partir d'un bruit (si les textures sont absentes)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.035
	noise.seed = 11
	var img := noise.get_seamless_image(512, 512)
	var bump := img.duplicate() as Image
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.32, 0.42, 1.0)
	img.generate_mipmaps()
	bump.convert(Image.FORMAT_RGB8)
	bump.bump_map_to_normal_map(3.0)
	bump.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(1.0, 0.95, 0.85)
	m.vertex_color_use_as_albedo = true
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(bump)
	m.normal_scale = 0.7
	m.roughness = 0.86
	m.metallic_specular = 0.35
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_stone_mat = m
	return m

## Teinte de la pierre : mousse et humidité au pied, sombre près de la ligne d'eau, légère variation de ton.
static func _stone_color(p: Vector3) -> Color:
	var c := Color(1, 1, 1)
	var wet := clampf(1.0 - (p.y - 0.07) / 0.42, 0.0, 1.0)
	c = c.lerp(Color(0.5, 0.6, 0.4), wet * 0.6)
	var line := clampf(1.0 - absf(p.y - POOL_Y_ON) / 0.05, 0.0, 1.0)
	c = c.darkened(line * 0.22)
	var v := sin(p.x * 11.0 + p.z * 7.0 + p.y * 5.0) * 0.02 + sin(p.x * 23.0 - p.z * 19.0) * 0.012
	return Color(c.r + v, c.g + v, c.b + v, 1.0)

func _build_stone() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# grand bassin octogonal (contour de la section, sens anti-horaire : la matière est à gauche du parcours)
	var basin := [Vector2(1.10, 0.0), Vector2(1.15, 0.05), Vector2(1.15, 0.08), Vector2(1.06, 0.08), Vector2(1.06, 0.27), Vector2(1.10, 0.28), Vector2(1.10, 0.33), Vector2(1.06, 0.34), Vector2(1.06, 0.46),
		Vector2(1.13, 0.50), Vector2(1.13, 0.60), Vector2(0.93, 0.60), Vector2(0.91, 0.58), Vector2(0.91, 0.20),
		Vector2(0.88, 0.16), Vector2(0.40, 0.16)]
	_lathe(st, basin, 8, true, Vector3.ZERO, STONE_TILE)
	# colonne, vasque haute et fleuron
	var col := [Vector2(0.38, 0.16), Vector2(0.38, 0.24), Vector2(0.31, 0.29), Vector2(0.20, 0.34), Vector2(0.17, 0.40),
		Vector2(0.17, 0.68), Vector2(0.22, 0.72), Vector2(0.22, 0.79), Vector2(0.17, 0.83), Vector2(0.17, 1.00),
		Vector2(0.25, 1.07), Vector2(0.40, 1.12), Vector2(0.52, 1.22), Vector2(0.58, 1.32), Vector2(LIP_R, 1.38),
		Vector2(LIP_R, 1.41), Vector2(0.56, 1.42), Vector2(BOWL_R, 1.40), Vector2(0.50, 1.30), Vector2(0.40, 1.24),
		Vector2(0.20, 1.215), Vector2(0.09, 1.21), Vector2(0.09, 1.50), Vector2(0.13, 1.53), Vector2(0.14, 1.59),
		Vector2(0.11, 1.65), Vector2(0.06, 1.70), Vector2(0.0, TIP_Y)]
	_lathe(st, col, 28, false, Vector3.ZERO, STONE_TILE)
	# huit bornes sculptées aux angles du bassin, coiffées d'une boule
	for i in 8:
		var a := TAU * float(i) / 8.0
		var o := Vector3(cos(a) * 1.13, 0.0, sin(a) * 1.13)
		var post := [Vector2(0.075, 0.08), Vector2(0.075, 0.55), Vector2(0.095, 0.58), Vector2(0.095, 0.62), Vector2(0.06, 0.64)]
		for k in 7:
			var ang := float(k) / 6.0 * PI * 0.5
			post.append(Vector2(0.075 * cos(ang), 0.64 + 0.075 * sin(ang) + 0.02))
		_lathe(st, post, 10, false, o, STONE_TILE * 1.5)
	st.generate_tangents()
	var mesh := st.commit()
	mesh.surface_set_material(0, _stone_material())
	var mi := MeshInstance3D.new()
	mi.name = "Pierre"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Surface de révolution : profil (rayon, hauteur) parcouru dans le sens anti-horaire autour de la matière.
## flat : faces planes (octogone) ; sinon normales lissées.
static func _lathe(st: SurfaceTool, prof: Array, seg: int, flat: bool, origin: Vector3, tex_scale: float) -> void:
	var cum := [0.0]
	for j in range(1, prof.size()):
		cum.append(cum[j - 1] + (prof[j] as Vector2).distance_to(prof[j - 1]))
	for j in prof.size() - 1:
		var p0: Vector2 = prof[j]
		var p1: Vector2 = prof[j + 1]
		var t := p1 - p0
		if t.length() < 0.0001:
			continue
		var n2 := Vector2(t.y, -t.x).normalized()
		var rm := maxf((p0.x + p1.x) * 0.5, 0.05)
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var v00 := origin + Vector3(d0.x * p0.x, p0.y, d0.z * p0.x)
			var v10 := origin + Vector3(d1.x * p0.x, p0.y, d1.z * p0.x)
			var v01 := origin + Vector3(d0.x * p1.x, p1.y, d0.z * p1.x)
			var v11 := origin + Vector3(d1.x * p1.x, p1.y, d1.z * p1.x)
			var n00: Vector3
			var n10: Vector3
			var n01: Vector3
			var n11: Vector3
			if flat:
				var dm := (d0 + d1).normalized()
				n00 = dm * n2.x + Vector3.UP * n2.y
				n10 = n00
				n01 = n00
				n11 = n00
			else:
				n00 = d0 * n2.x + Vector3.UP * n2.y
				n10 = d1 * n2.x + Vector3.UP * n2.y
				n01 = n00
				n11 = n10
			var circ := TAU * rm * tex_scale
			var u0 := float(i) / seg * circ
			var u1 := float(i + 1) / seg * circ
			var w0: float = cum[j] * tex_scale
			var w1: float = cum[j + 1] * tex_scale
			_tri(st, v00, v01, v11, n00, n01, n11, Vector2(u0, w0), Vector2(u0, w1), Vector2(u1, w1))
			_tri(st, v00, v11, v10, n00, n11, n10, Vector2(u0, w0), Vector2(u1, w1), Vector2(u1, w0))

## Triangle dont le sens est corrigé pour que la face avant (horaire dans Godot) regarde du côté des normales.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var tp := b
		b = c
		c = tp
		var tn := nb
		nb = nc
		nc = tn
		var tu := ub
		ub = uc
		uc = tu
	_vtx(st, a, na, ua)
	_vtx(st, b, nb, ub)
	_vtx(st, c, nc, uc)

static func _vtx(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_color(_stone_color(p))
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)

# ------------------------------------------------------------------ eau (surfaces)

func _water_shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s

func _disc(radius: float, seg: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
	return st.commit()

func _build_water() -> void:
	var shader := _water_shader(POOL_SHADER)
	# grand bassin : octogone, juste à l'intérieur de la paroi
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = shader
	_pool_mat.set_shader_parameter("impact_r", FALL_R)
	_pool_mat.set_shader_parameter("edge_r", BASIN_R - 0.01)
	_pool_mat.set_shader_parameter("sides", 8.0)
	_pool = MeshInstance3D.new()
	_pool.name = "EauBassin"
	_pool.mesh = _disc(BASIN_R - 0.01, 8)
	_pool.material_override = _pool_mat
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	# vasque haute : disque
	_pool_up_mat = ShaderMaterial.new()
	_pool_up_mat.shader = shader
	_pool_up_mat.set_shader_parameter("impact_r", JET_LAND_R)
	_pool_up_mat.set_shader_parameter("edge_r", BOWL_R - 0.01)
	_pool_up_mat.set_shader_parameter("sides", 0.0)
	_pool_up_mat.set_shader_parameter("shallow", Color(0.2, 0.56, 0.62))
	_pool_up_mat.set_shader_parameter("deep", Color(0.08, 0.34, 0.42))
	_pool_up = MeshInstance3D.new()
	_pool_up.name = "EauVasque"
	_pool_up.mesh = _disc(BOWL_R - 0.01, 32)
	_pool_up.material_override = _pool_up_mat
	_pool_up.position = Vector3(0.0, BOWL_Y, 0.0)
	_pool_up.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool_up)

# ------------------------------------------------------------------ eau qui tombe

func _build_falls() -> void:
	_fall_mat = ShaderMaterial.new()
	_fall_mat.shader = _water_shader(FALL_SHADER)
	var sheet_mat := _fall_mat
	var jet_mat := ShaderMaterial.new()
	jet_mat.shader = _fall_mat.shader
	jet_mat.set_shader_parameter("sheet", 0.0)
	jet_mat.set_shader_parameter("streaks", 8.0)
	jet_mat.set_shader_parameter("speed", 2.4)
	_falls = MeshInstance3D.new()
	_falls.name = "EauQuiTombe"
	# nappe : surface de révolution mince qui s'évase en tombant (UV.x = tour complet, UV.y = 0 en haut → 1 en bas)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 14
	var seg := 72
	var y_top := LIP_Y - 0.01
	var y_bot := POOL_Y_ON + 0.005
	for j in rows:
		var s0 := float(j) / rows
		var s1 := float(j + 1) / rows
		var r0 := lerpf(LIP_R + 0.005, FALL_R, pow(s0, 1.6))
		var r1 := lerpf(LIP_R + 0.005, FALL_R, pow(s1, 1.6))
		var y0 := lerpf(y_top, y_bot, s0)
		var y1 := lerpf(y_top, y_bot, s1)
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var p00 := Vector3(d0.x * r0, y0, d0.z * r0)
			var p10 := Vector3(d1.x * r0, y0, d1.z * r0)
			var p01 := Vector3(d0.x * r1, y1, d0.z * r1)
			var p11 := Vector3(d1.x * r1, y1, d1.z * r1)
			var uu0 := float(i) / seg
			var uu1 := float(i + 1) / seg
			_fall_tri(st, p00, p01, p11, d0, d0, d1, Vector2(uu0, s0), Vector2(uu0, s1), Vector2(uu1, s1))
			_fall_tri(st, p00, p11, p10, d0, d1, d1, Vector2(uu0, s0), Vector2(uu1, s1), Vector2(uu1, s0))
	var sheet_mesh := st.commit()
	sheet_mesh.surface_set_material(0, sheet_mat)
	# gerbes : huit arcs qui partent du fleuron et retombent dans la vasque (deux rubans croisés par arc)
	var js := SurfaceTool.new()
	js.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	for k in 8:
		var ang := TAU * (float(k) + 0.5) / 8.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var side := Vector3(-dir.z, 0.0, dir.x)
		for cross in 2:
			for q in steps:
				var sa := float(q) / steps
				var sb := float(q + 1) / steps
				var pa := _jet_point(dir, sa)
				var pb := _jet_point(dir, sb)
				var wa := 0.016 + 0.020 * sa
				var wb := 0.016 + 0.020 * sb
				var ax: Vector3 = side if cross == 0 else Vector3.UP
				var oa := ax * wa
				var ob := ax * wb
				var n := dir
				_fall_tri(js, pa - oa, pb - ob, pb + ob, n, n, n, Vector2(0.0, sa), Vector2(0.0, sb), Vector2(1.0, sb))
				_fall_tri(js, pa - oa, pb + ob, pa + oa, n, n, n, Vector2(0.0, sa), Vector2(1.0, sb), Vector2(1.0, sa))
	var jet_mesh := js.commit()
	jet_mesh.surface_set_material(0, jet_mat)
	# les deux maillages dans un même nœud
	var merged := ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sheet_mesh.surface_get_arrays(0))
	merged.surface_set_material(0, sheet_mat)
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, jet_mesh.surface_get_arrays(0))
	merged.surface_set_material(1, jet_mat)
	_falls.mesh = merged
	_falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_falls)
	_jet_mat = jet_mat

var _jet_mat: ShaderMaterial

static func _jet_point(dir: Vector3, s: float) -> Vector3:
	var r := JET_LAND_R * s
	var y := lerpf(TIP_Y, BOWL_Y + 0.01, s) + 4.0 * 0.17 * s * (1.0 - s)
	return Vector3(dir.x * r, y, dir.z * r)

static func _fall_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(na)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(nb)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(nc)
	st.set_uv(uc)
	st.add_vertex(c)

# ------------------------------------------------------------------ éclaboussures, brume, lumière

func _particle_mat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
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

func _ring_particles(radius: float, amount: int, life: float, vmin: float, vmax: float, size_min: float, size_max: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Settings.pc(amount)
	p.lifetime = life
	p.randomness = 0.6
	p.local_coords = false
	p.fixed_fps = 30
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.0
	p.emission_ring_radius = radius + 0.02
	p.emission_ring_inner_radius = radius - 0.03
	p.direction = Vector3.UP
	p.spread = 32.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.0, -3.6, 0.0)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(0.85, 0.95, 1.0, 0.0), Color(0.85, 0.95, 1.0, 0.9), Color(0.7, 0.88, 1.0, 0.0)])
	p.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = _particle_mat(ProceduralTextures.glow(), true)
	p.mesh = qm
	return p

func _build_fx() -> void:
	_splash = _ring_particles(FALL_R, 90, 0.8, 0.35, 0.95, 0.018, 0.034)
	_splash.name = "Eclaboussures"
	add_child(_splash)
	_splash_up = _ring_particles(JET_LAND_R, 26, 0.6, 0.25, 0.6, 0.014, 0.026)
	_splash_up.position = Vector3(0.0, BOWL_Y + 0.01, 0.0)
	_splash_up.name = "EclaboussuresVasque"
	add_child(_splash_up)
	# brume légère au pied de la nappe
	_mist = _ring_particles(FALL_R - 0.05, 12, 2.6, 0.06, 0.14, 0.34, 0.55)
	_mist.name = "Brume"
	_mist.spread = 14.0
	_mist.gravity = Vector3(0.0, 0.03, 0.0)
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = _particle_mat(ProceduralTextures.smoke(), false)
	_mist.mesh = qm
	var mg := Gradient.new()
	mg.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	mg.colors = PackedColorArray([Color(0.8, 0.92, 1.0, 0.0), Color(0.8, 0.92, 1.0, 0.13), Color(0.75, 0.88, 0.98, 0.0)])
	_mist.color_ramp = mg
	add_child(_mist)
	# gouttes qui giclent du fleuron
	_drops = CPUParticles3D.new()
	_drops.name = "Gouttes"
	_drops.amount = Settings.pc(36)
	_drops.lifetime = 0.9
	_drops.randomness = 0.7
	_drops.local_coords = false
	_drops.fixed_fps = 30
	_drops.emitting = false
	_drops.position = Vector3(0.0, TIP_Y, 0.0)
	_drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_drops.emission_sphere_radius = 0.02
	_drops.direction = Vector3.UP
	_drops.spread = 55.0
	_drops.initial_velocity_min = 0.6
	_drops.initial_velocity_max = 1.4
	_drops.gravity = Vector3(0.0, -5.2, 0.0)
	_drops.scale_amount_min = 0.014
	_drops.scale_amount_max = 0.03
	var dg := Gradient.new()
	dg.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	dg.colors = PackedColorArray([Color(0.9, 0.97, 1.0, 0.0), Color(0.9, 0.97, 1.0, 0.95), Color(0.8, 0.92, 1.0, 0.0)])
	_drops.color_ramp = dg
	var dq := QuadMesh.new()
	dq.size = Vector2.ONE
	dq.material = _particle_mat(ProceduralTextures.glow(), true)
	_drops.mesh = dq
	add_child(_drops)
	_light = OmniLight3D.new()
	_light.name = "LumiereEau"
	_light.light_color = Color(0.5, 0.86, 1.0)
	_light.omni_range = 3.6
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 1.0, 0.0)
	_light.light_energy = 0.0
	add_child(_light)
