extends SpellFxStyles
## Boîte à outils des effets de sorts avancés (Forward+ / Vulkan) : shaders (onde de choc, lentille, orbe, rayon, pilier, flamme…), particules GPU,
## lumière dynamique, secousse de caméra, décalques au sol. Les effets de chaque école (arcane, feu, sacré, givre, ombre, barde, physique)
## héritent de cette classe et composent ces briques ; voir SpellFxLibrary pour le catalogue.
## Palier 1 : particules GPU + halo · palier 2 : + lumière, brume éclairée, décalque au sol · palier 3 : + distorsion de l'écran.

# En-tête et billboard communs : le quad fait toujours face à la caméra, en gardant son échelle.
const SH_ADD := "shader_type spatial;\nrender_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled;\n"
const SH_BILLBOARD := "\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);\n\tMODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));\n"

## Onde de choc : anneau ondulé qui s'élargit, avec un cœur lumineux qui s'éteint.
const SH_SHOCK := SH_ADD + """
uniform vec4 col : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float power = 1.0;
varying vec2 uvp;
void vertex() {
	uvp = UV * 2.0 - 1.0;
""" + SH_BILLBOARD + """
}
void fragment() {
	float r = length(uvp);
	float ang = atan(uvp.y, uvp.x);
	float wob = sin(ang * 7.0 + progress * 9.0) * 0.025 + sin(ang * 13.0 - progress * 14.0) * 0.015;
	float radius = 0.15 + progress * 0.8;
	float width = mix(0.09, 0.04, progress);
	float ring = smoothstep(width, 0.0, abs(r - radius + wob));
	float fade = (1.0 - progress) * (1.0 - progress);
	float core = smoothstep(0.5, 0.0, r) * (1.0 - progress) * 0.6;
	ALBEDO = col.rgb * (ring * 1.9 + core * 0.9) * power;
	ALPHA = clamp((ring + core) * fade, 0.0, 1.0);
}
"""

## Lentille : déforme l'image derrière elle (air chauffé autour du sort), bords fondus.
const SH_LENS := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.04;
uniform float fade = 1.0;
varying vec2 uvp;
void vertex() {
	uvp = UV * 2.0 - 1.0;
""" + SH_BILLBOARD + """
}
void fragment() {
	float r = length(uvp);
	float mask = smoothstep(1.0, 0.2, r);
	vec2 dir = uvp / max(r, 0.001);
	vec2 off = dir * mask * strength * fade;
	ALBEDO = texture(screen_tex, SCREEN_UV - off).rgb;
	ALPHA = mask;
}
"""

## Orbe de mana : sphère lumineuse (bord brillant façon fresnel, motif qui ondule).
const SH_ORB := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 col_a : source_color = vec4(0.45, 0.25, 1.0, 1.0);
uniform vec4 col_b : source_color = vec4(0.9, 0.8, 1.0, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float n = 0.5 + 0.5 * sin(UV.x * 24.0 + time_s * 8.0) * sin(UV.y * 18.0 - time_s * 6.0);
	ALBEDO = mix(col_a.rgb, col_b.rgb, f) * (1.2 + n * 0.8 + f * 2.0) * power;
	ALPHA = clamp(0.55 + f, 0.0, 1.0);
}
"""

## Rayon : bande lumineuse entre `tail` et `head` (0..1 le long du rayon), plus fine au départ qu'à l'arrivée.
const SH_BEAM := SH_ADD + """
uniform vec4 col : source_color = vec4(0.7, 0.5, 1.0, 1.0);
uniform float progress = 0.0;
uniform float power = 1.0;
uniform float head = 1.0;
uniform float tail = 0.0;
void fragment() {
	float x = UV.x;
	float y = abs(UV.y * 2.0 - 1.0) / mix(0.3, 1.0, x);
	float body = smoothstep(1.0, 0.0, y);
	float core = smoothstep(0.35, 0.0, y);
	float along = smoothstep(tail - 0.05, tail + 0.15, x) * smoothstep(head + 0.05, head - 0.15, x);
	float flick = 0.85 + 0.15 * sin(x * 40.0 - progress * 60.0);
	ALBEDO = (col.rgb * body * 2.0 + vec3(1.0) * core * 1.5) * flick * power;
	ALPHA = clamp(along * body, 0.0, 1.0);
}
"""

static var _shaders: Dictionary = {}
static var _rune_t: Texture2D

var _tier: int = 1
var _pw: float = 1.0           # intensité du sort
var _g: float = 1.0            # multiplicateur de lumière (dérivé de l'intensité)
var _s: float = 1.0            # multiplicateur de taille (dérivé de l'intensité)
var _tinted: bool = false
var _base_hue: float = 0.74   # teinte d'origine de la palette de l'effet : `fxTint` la remplace en conservant les nuances
var _tint_h: float = 0.74

# ------------------------------------------------------------------------------------------ outils

## Couleur de la palette d'origine (violet), tournée vers la teinte choisie en gardant saturation et luminosité.
func _c(r: float, g: float, b: float, a: float = 1.0) -> Color:
	var base := Color(r, g, b, a)
	if not _tinted:
		return base
	return Color.from_hsv(fposmod(base.h - _base_hue + _tint_h, 1.0), base.s, base.v, a)

## Couleur HDR (composantes au-delà de 1) : c'est ce qui allume le halo de l'environnement.
func _hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

static func _w_soft() -> Texture2D:
	return _radial("fxa_soft", [[0.0, Color(1, 1, 1, 1)], [0.35, Color(1, 1, 1, 0.65)], [0.7, Color(1, 1, 1, 0.18)], [1.0, Color(1, 1, 1, 0)]])

static func _w_spark() -> Texture2D:
	return _radial("fxa_spark", [[0.0, Color(1, 1, 1, 1)], [0.2, Color(1, 1, 1, 0.9)], [1.0, Color(1, 1, 1, 0)]])

## Alphabet runique (futhark ancien, 24 signes) : chaque rune est une suite de traits dans un carré 1 x 1 (x vers la droite, y vers le bas).
const RUNES := [
	[[[0.2, 1], [0.2, 0]], [[0.2, 0.3], [0.85, 0]], [[0.2, 0.6], [0.85, 0.3]]],
	[[[0.15, 1], [0.15, 0], [0.8, 0.3], [0.8, 1]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0.25], [0.8, 0.5], [0.2, 0.75]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0.1], [0.8, 0.35]], [[0.2, 0.4], [0.8, 0.65]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0], [0.8, 0.25], [0.2, 0.55], [0.85, 1]]],
	[[[0.8, 0.2], [0.2, 0.5], [0.8, 0.8]]],
	[[[0.15, 0], [0.85, 1]], [[0.85, 0], [0.15, 1]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0], [0.8, 0.3], [0.2, 0.6]]],
	[[[0.2, 0], [0.2, 1]], [[0.8, 0], [0.8, 1]], [[0.2, 0.35], [0.8, 0.65]]],
	[[[0.5, 0], [0.5, 1]], [[0.2, 0.3], [0.8, 0.6]]],
	[[[0.5, 0], [0.5, 1]]],
	[[[0.25, 0.1], [0.5, 0.3], [0.25, 0.5]], [[0.75, 0.5], [0.5, 0.7], [0.75, 0.9]]],
	[[[0.5, 0], [0.5, 1]], [[0.5, 0], [0.8, 0.25]], [[0.5, 1], [0.2, 0.75]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0], [0.75, 0.3], [0.4, 0.5], [0.75, 0.7], [0.2, 1]]],
	[[[0.5, 0], [0.5, 1]], [[0.15, 0.15], [0.5, 0.5], [0.85, 0.15]]],
	[[[0.7, 0], [0.3, 0.35], [0.7, 0.65], [0.3, 1]]],
	[[[0.5, 0], [0.5, 1]], [[0.15, 0.3], [0.5, 0], [0.85, 0.3]]],
	[[[0.2, 0], [0.2, 1]], [[0.2, 0], [0.75, 0.25], [0.2, 0.5], [0.75, 0.75], [0.2, 1]]],
	[[[0.2, 0], [0.2, 1]], [[0.8, 0], [0.8, 1]], [[0.2, 0], [0.5, 0.35], [0.8, 0]]],
	[[[0.2, 0], [0.2, 1]], [[0.8, 0], [0.8, 1]], [[0.2, 0], [0.8, 0.5]], [[0.8, 0], [0.2, 0.5]]],
	[[[0.3, 0], [0.3, 1]], [[0.3, 0], [0.8, 0.3]]],
	[[[0.5, 0], [0.85, 0.5], [0.5, 1], [0.15, 0.5], [0.5, 0]]],
	[[[0.2, 0], [0.2, 1]], [[0.8, 0], [0.8, 1]], [[0.2, 0], [0.8, 1]], [[0.8, 0], [0.2, 1]]],
	[[[0.5, 0], [0.8, 0.35], [0.2, 1]], [[0.5, 0], [0.2, 0.35], [0.8, 1]]],
]

## Pose un point doux (pinceau) de rayon `rad` pixels ; on garde la valeur la plus forte.
static func _dab(img: PackedFloat32Array, n: int, x: float, y: float, rad: float) -> void:
	var x0 := maxi(int(x - rad - 1.0), 0)
	var x1 := mini(int(x + rad + 1.0), n - 1)
	var y0 := maxi(int(y - rad - 1.0), 0)
	var y1 := mini(int(y + rad + 1.0), n - 1)
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var d := Vector2(float(px) + 0.5 - x, float(py) + 0.5 - y).length()
			var v := clampf(rad + 0.5 - d, 0.0, 1.0)
			if v > img[py * n + px]:
				img[py * n + px] = v

static func _stroke(img: PackedFloat32Array, n: int, a: Vector2, b: Vector2, rad: float) -> void:
	var steps := maxi(int(a.distance_to(b) / 0.8), 1)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / float(steps))
		_dab(img, n, p.x, p.y, rad)

static func _rune_ring(img: PackedFloat32Array, n: int, r: float, rad: float) -> void:
	var c := float(n) * 0.5
	var steps := int(TAU * r * c / 0.8)
	for i in steps:
		var ang := float(i) / float(steps) * TAU
		_dab(img, n, c + cos(ang) * r * c, c + sin(ang) * r * c, rad)

## Cercle magique : double anneau extérieur portant les 24 runes du futhark, anneau intérieur, hexagramme, cercles et point central.
## Les couleurs sont multipliées par l'opacité : l'émission du décalque ignore l'alpha, sinon tout le carré brillerait.
static func _rune_tex() -> Texture2D:
	if _rune_t == null:
		var n := 512
		var c := float(n) * 0.5
		var img := PackedFloat32Array()
		img.resize(n * n)
		_rune_ring(img, n, 0.975, 2.6)
		_rune_ring(img, n, 0.93, 1.3)
		_rune_ring(img, n, 0.79, 1.3)
		_rune_ring(img, n, 0.765, 2.0)
		# runes, têtes vers l'extérieur
		var rm := 0.862
		var rh := 0.088 * c
		var rw := 0.056 * c
		for i in RUNES.size():
			var ang := float(i) / float(RUNES.size()) * TAU - PI * 0.5
			var u := Vector2(cos(ang), sin(ang))
			var t := Vector2(-u.y, u.x)
			var mid := Vector2(c, c) + u * rm * c
			for st in RUNES[i]:
				var prev := Vector2.ZERO
				for k in (st as Array).size():
					var q: Array = st[k]
					var p := mid + t * (float(q[0]) - 0.5) * rw + u * (0.5 - float(q[1])) * rh
					if k > 0:
						_stroke(img, n, prev, p, 1.7)
					prev = p
		# hexagramme (deux triangles) et points aux sommets
		var hr := 0.70 * c
		for tri in 2:
			var pts: Array = []
			for k in 3:
				var ang := -PI * 0.5 + float(tri) * PI + float(k) * TAU / 3.0
				pts.append(Vector2(c, c) + Vector2(cos(ang), sin(ang)) * hr)
			for k in 3:
				_stroke(img, n, pts[k], pts[(k + 1) % 3], 1.8)
			for k in 3:
				var p: Vector2 = pts[k]
				_dab(img, n, p.x, p.y, 4.0)
		_rune_ring(img, n, 0.35, 1.5)
		_rune_ring(img, n, 0.10, 1.5)
		_dab(img, n, c, c, 5.0)
		var bytes := PackedByteArray()
		bytes.resize(n * n * 4)
		for i in n * n:
			var b := int(clampf(img[i], 0.0, 1.0) * 255.0)
			bytes[i * 4] = b
			bytes[i * 4 + 1] = b
			bytes[i * 4 + 2] = b
			bytes[i * 4 + 3] = b
		_rune_t = ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, bytes))
	return _rune_t

static func _shader(key: String, code: String) -> Shader:
	if _shaders.has(key):
		return _shaders[key]
	var sh := Shader.new()
	sh.code = code
	_shaders[key] = sh
	return sh

func _smat(key: String, code: String, prio: int = 6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	m.render_priority = prio
	return m

func _quad_node(m: Material, size: float, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = m
	mi.scale = Vector3.ONE * size
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Matériau « couleurs de sommets » sans éclairage, en HDR (cristaux).
func _vcol_mat(k: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(k, k, k, 1.0)
	m.disable_receive_shadows = true
	return m

## Maillage de particules : quad additif face caméra, couleur HDR.
func _soft_mesh(col: Color, k: float, tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := _fx_mat(tex, true)
	m.albedo_color = _hdr(col, k)
	q.material = m
	return q

func _pmat(radius: float, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3, smin: float, smax: float,
		ramp: Gradient, damp: float = 0.0, turb: float = 0.0) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = vmin
	m.initial_velocity_max = vmax
	m.gravity = grav
	m.scale_min = smin
	m.scale_max = smax
	m.damping_min = damp
	m.damping_max = damp
	var ct := CurveTexture.new()
	ct.curve = _shrink_curve()
	m.scale_curve = ct
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	m.color_ramp = gt
	if turb > 0.0:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = turb
		m.turbulence_noise_scale = 3.0
	return m

## Émetteur de particules GPU placé en `at` (éclat unique ou flux continu), libéré par `_free_after`.
func _gpu(amount: int, life: float, one_shot: bool, mesh: Mesh, pm: ParticleProcessMaterial, at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, Settings.pc(amount))
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.randomness = 0.4
	p.local_coords = false
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	p.emitting = false
	add_child(p)
	p.emitting = true
	return p

func _free_after(n: Node, sec: float) -> void:
	_keep(sec + 0.1)
	get_tree().create_timer(sec).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())

## Lumière dynamique (palier 2 et plus) : elle éclaire aussi la brume volumétrique. Renvoie null si elle est désactivée.
func _lamp_node(at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	if _tier < 2:
		return null
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.light_volumetric_fog_energy = 2.0
	l.shadow_enabled = false
	l.position = at
	add_child(l)
	return l

func _fade_lamp(l: OmniLight3D, dur: float) -> void:
	if l == null or not is_instance_valid(l):
		return
	_keep(dur + 0.1)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

## Secousse brève de la caméra (désactivée par « mouvement réduit »). Le nœud reste en vie jusqu'à la fin, caméra recentrée.
func _shake(amp: float, dur: float) -> void:
	if Settings.reduced_motion or cam == null:
		return
	_keep(dur + 0.2)
	var n := 5
	var tw := create_tween()
	for i in n:
		var a := amp * (1.0 - float(i) / float(n))
		tw.tween_property(cam, "h_offset", randf_range(-a, a), dur / float(n))
		tw.parallel().tween_property(cam, "v_offset", randf_range(-a, a), dur / float(n))
	tw.tween_property(cam, "h_offset", 0.0, 0.03)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.03)

## Onde de choc en shader (face caméra), éventuellement retardée.
func _shock(at: Vector3, col: Color, size: float, dur: float, delay: float = 0.0) -> void:
	var m := _smat("shock", SH_SHOCK)
	m.set_shader_parameter("col", Color(col.r, col.g, col.b, 1.0))
	m.set_shader_parameter("power", _g)
	m.set_shader_parameter("progress", 0.0)
	var mi := _quad_node(m, size, at)
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		m.set_shader_parameter("progress", w))

## Lentille de distorsion (palier 3) : suit `follow` ou reste en place, s'éteint en `dur` secondes.
func _lens(at: Vector3, size: float, strength: float, dur: float) -> MeshInstance3D:
	if _tier < 3:
		return null
	var m := _smat("lens", SH_LENS, 4)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("fade", 1.0)
	var mi := _quad_node(m, size, at)
	if dur > 0.0:
		_add({"node": mi}, dur, func(u: float):
			m.set_shader_parameter("fade", 1.0 - u))
	return mi

## Décalque lumineux gravé au sol sous le monstre visé (palier 2 et plus, option « décalques ») : tourne et s'éteint.
## `tex` : motif en niveaux de gris (couleurs déjà multipliées par l'opacité, l'émission du décalque ignorant l'alpha).
func _glyph_decal(target: Dictionary, tex: Texture2D, col: Color, size: float, dur: float = 1.1, spin: float = 1.4, energy: float = 3.0) -> void:
	if _tier < 2 or target.is_empty() or not VisualFx.is_forward() or not bool(Settings.opt("fx_decals")):
		return
	var d := Decal.new()
	d.size = Vector3(2.6 * size, 1.2, 2.6 * size)
	d.texture_albedo = tex
	d.texture_emission = tex
	d.albedo_mix = 1.0
	d.position = Vector3(target.pos.x, 0.05, target.pos.z)
	add_child(d)
	var en := energy * _g
	_add({"node": d}, dur, func(u: float):
		var fade := minf(1.0, u * 8.0) * (1.0 - u) * (1.0 - u)
		d.modulate = Color(col.r, col.g, col.b, fade)
		d.emission_energy = en * fade
		d.rotation.y = u * spin)

func _rune_decal(target: Dictionary, col: Color, size: float) -> void:
	_glyph_decal(target, _rune_tex(), col, size)


# =====================================================================================================
# BRIQUES COMMUNES AUX EFFETS D'ÉCOLE : bruit, plasma, flamme, pilier, trait de lame, dôme ; projectile et impact pilotés par dictionnaire.
# =====================================================================================================

## Bruit de valeur (2D / 3D) et fractal, réutilisés par les shaders ci-dessous.
const GLYPHS := preload("res://scripts/dungeon/spell_glyphs.gd")

const SH_NOISE := """
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; } return v; }
float hash31(vec3 p) { p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm3(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise3(p); p = p * 2.02 + vec3(5.2, 1.3, 7.7); a *= 0.5; } return v; }
"""

## Billboard qui reste vertical (flammes, piliers) : pivote autour de Y seulement.
const SH_BILLBOARD_Y := "\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);\n\tMODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));\n"

## Plasma : sphère dont la surface bouillonne (bruit 3D qui défile), cœur chaud, bord brillant. `erode` la ronge jusqu'à disparition.
## Sert aux boules de feu, aux orbes de givre et d'ombre (variante mélangée, non additive).
const SH_PLASMA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec4 rim : source_color = vec4(0.7, 0.1, 0.02, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
uniform float erode = 0.0;
uniform float speed = 1.6;
uniform float noise_scale = 2.2;
uniform float rim_pow = 1.8;
varying vec3 lp;
void vertex() { lp = VERTEX; }
""" + SH_NOISE + """
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_pow);
	vec3 q = lp * noise_scale * 2.0 + vec3(0.0, -time_s * speed, 0.0);
	float n = fbm3(q) + 0.35 * fbm3(q * 2.3 + vec3(time_s * 0.7, 0.0, 0.0));
	float dens = clamp(n * 1.15 + (1.0 - f) * 0.35 - 0.15 - erode * 1.1, 0.0, 1.0);
	vec3 c = mix(rim.rgb, mid.rgb, smoothstep(0.1, 0.45, dens));
	c = mix(c, hot.rgb, smoothstep(0.75, 0.98, dens) * 0.8);
	ALBEDO = c * (0.5 + dens * 0.7 + f * 0.6) * power;
	ALPHA = clamp(dens * 1.4 + f * 0.35, 0.0, 1.0) * (1.0 - erode * 0.7);
}
"""

## Roche en fusion : pierre sombre fendillée de lignes incandescentes (crêtes du bruit 3D).
const SH_ROCK := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4 stone : source_color = vec4(0.1, 0.06, 0.05, 1.0);
uniform vec4 lava : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
""" + SH_NOISE + """
void fragment() {
	float n = fbm3(lp * 5.0);
	float crack = smoothstep(0.1, 0.0, abs(n - 0.5)) ;
	float crack2 = smoothstep(0.08, 0.0, abs(fbm3(lp * 9.0 + 3.0) - 0.5));
	float lit = clamp(crack + crack2 * 0.6, 0.0, 1.0) * (0.75 + 0.25 * sin(time_s * 14.0 + lp.y * 9.0));
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = stone.rgb * (0.6 + n) + lava.rgb * (lit * 2.4 + f * 0.8) * power;
}
"""

## Flamme verticale (billboard Y) : langue effilée, rongée par le bruit qui monte, cœur chaud → bord sombre.
const SH_FLAME := SH_ADD + """
uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform vec4 edge : source_color = vec4(0.6, 0.08, 0.02, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform float taper = 1.2;
varying vec2 uvp;
void vertex() {
	uvp = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
""" + SH_BILLBOARD_Y + """
}
""" + SH_NOISE + """
void fragment() {
	float y = uvp.y;
	float x = uvp.x;
	float n = fbm(vec2(x * 1.7 + seed, y * 2.1 - time_s * 2.3));
	float n2 = fbm(vec2(x * 3.3 - seed, y * 4.2 - time_s * 3.7));
	float wid = (1.0 - pow(y, taper)) * (0.5 + 0.5 * n);
	float d = abs(x + (n2 - 0.5) * 0.55 * y);
	float body = smoothstep(wid, wid * 0.3, d);
	float tip = 1.0 - smoothstep(0.5, 1.0, y + (n - 0.5) * 0.4);
	float dens = body * tip;
	float heat = clamp(dens * 1.2 - y * 0.45 + (n2 - 0.5) * 0.3 + 0.2, 0.0, 1.0);
	vec3 c = mix(edge.rgb, mid.rgb, smoothstep(0.1, 0.5, heat));
	c = mix(c, hot.rgb, smoothstep(0.62, 1.0, heat) * 0.8);
	ALBEDO = c * (0.65 + heat * 1.0) * power;
	ALPHA = clamp(dens, 0.0, 1.0) * fade;
}
"""

## Pilier de lumière (billboard Y) : bords doux, cœur blanc, rais qui montent. `drop` : front de descente (0 = rien, 1 = tout le pilier).
const SH_PILLAR := SH_ADD + """
uniform vec4 col : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 core : source_color = vec4(1.0, 1.0, 0.95, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
uniform float fade = 1.0;
uniform float drop = 1.0;
uniform float flow = 3.0;
varying vec2 uvp;
void vertex() {
	uvp = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
""" + SH_BILLBOARD_Y + """
}
""" + SH_NOISE + """
void fragment() {
	float x = abs(uvp.x);
	float edge = smoothstep(1.0, 0.0, x);
	float coreW = smoothstep(0.32, 0.0, x);
	float rays = fbm(vec2(uvp.x * 8.0, uvp.y * 0.9 - time_s * flow));
	float streak = 0.7 + 0.3 * sin(uvp.x * 26.0 + rays * 7.0);
	float vf = smoothstep(1.0, 0.6, uvp.y) * smoothstep(0.0, 0.02, uvp.y);
	float glow = smoothstep(0.3, 0.0, uvp.y) * 0.8;
	float reveal = smoothstep(drop, drop - 0.08, 1.0 - uvp.y);
	vec3 c = col.rgb * edge * (0.5 + rays * 1.1) + core.rgb * coreW * 1.7 + col.rgb * glow;
	ALBEDO = c * streak * power;
	ALPHA = clamp((edge * 0.85 + glow) * vf, 0.0, 1.0) * fade * reveal;
}
"""

## Trait de lame : croissant effilé (courbure `bend`), qui se révèle de `tail` à `head` ; `ang` : angle du trait dans le plan de l'écran.
const SH_STREAK := SH_ADD + """
uniform vec4 col : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float head = 1.0;
uniform float tail = 0.0;
uniform float power = 1.0;
uniform float ang = 0.0;
uniform float bend = 0.25;
uniform float thick = 0.16;
varying vec2 uvp;
void vertex() {
	uvp = UV * 2.0 - 1.0;
""" + SH_BILLBOARD + """
}
void fragment() {
	vec2 p = vec2(uvp.x * cos(ang) + uvp.y * sin(ang), -uvp.x * sin(ang) + uvp.y * cos(ang));
	float x = clamp(p.x * 0.5 + 0.5, 0.0, 1.0);
	float yb = p.y + bend * (p.x * p.x - 0.35);
	float w = max(thick * pow(sin(3.14159 * x), 0.75), 0.002);
	float d = abs(yb) / w;
	float body = smoothstep(1.0, 0.0, d);
	float core = smoothstep(0.32, 0.0, d);
	float along = smoothstep(tail - 0.02, tail + 0.14, x) * smoothstep(head + 0.02, head - 0.14, x);
	float edge_in = step(abs(p.x), 1.0);
	ALBEDO = (col.rgb * body * 2.2 + vec3(1.0) * core * 1.8) * power;
	ALPHA = clamp(body * along * edge_in, 0.0, 1.0);
}
"""

## Dôme / bulle protectrice : bord brillant et trame hexagonale qui s'allume par vagues.
const SH_DOME := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 col : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float time_s = 0.0;
uniform float power = 1.0;
uniform float fade = 1.0;
uniform float wave = 0.0;
uniform float cells = 9.0;
varying vec2 uvs;
void vertex() { uvs = UV; }
float hexd(vec2 p) { p = abs(p); return max(dot(p, vec2(0.5, 0.866025)), p.x); }
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	vec2 p = vec2(uvs.x * cells * 2.0, uvs.y * cells);
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 gv = dot(a, a) < dot(b, b) ? a : b;
	float edge = smoothstep(0.40, 0.5, hexd(gv));
	float sweep = smoothstep(0.18, 0.0, abs(uvs.y - wave)) * 1.6;
	float tw = 0.5 + 0.5 * sin(time_s * 3.0 + floor(p.x) * 1.7 + floor(p.y) * 2.3);
	ALBEDO = col.rgb * (edge * (0.5 + sweep + tw * 0.35) + f * 2.2 + 0.12 + sweep * 0.2) * power;
	ALPHA = clamp(edge * 0.55 + f * 0.8 + 0.08 + sweep * 0.2, 0.0, 1.0) * fade;
}
"""

## Anneau d'onde de choc posé à plat sur le sol (même motif que l'onde de choc face caméra).
static func _ground_shock_code() -> String:
	return SH_SHOCK.replace(SH_BILLBOARD, "")

static var _puff_cache: Dictionary = {}

## Bouffée à bords bruités (fumée, flamme) : alpha = disque fondu rongé par un bruit fractal. `hard` : contraste du bruit.
static func _puff_tex(key: String, seed_i: int, hard: float, freq: float = 0.035) -> Texture2D:
	if _puff_cache.has(key):
		return _puff_cache[key]
	var n := 128
	var fn := FastNoiseLite.new()
	fn.seed = seed_i
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.fractal_type = FastNoiseLite.FRACTAL_FBM
	fn.fractal_octaves = 4
	fn.frequency = freq
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var dy := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var mask := pow(clampf(1.0 - r, 0.0, 1.0), 0.8)
			var v := fn.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var a := clampf(mask * 1.7 - 0.45 + (v - 0.5) * hard, 0.0, 1.0) * clampf((1.0 - r) / 0.25, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_puff_cache[key] = t
	return t

static func _smoke_puff() -> Texture2D:
	return _puff_tex("smoke", 11, 1.5)

static func _flame_puff() -> Texture2D:
	return _puff_tex("flame", 23, 1.1)

## Particules de fumée ordinaire (non additives : elles assombrissent) : maillage de quads texturés.
func _smoke_mesh(col: Color, tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := _fx_mat(tex, true)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.render_priority = 4
	m.albedo_color = col
	q.material = m
	return q

static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 0.35))
	c.add_point(Vector2(0.4, 1.0))
	c.add_point(Vector2(1, 1.35))
	return c

## Variante de `_pmat` dont les particules grossissent au lieu de rétrécir (fumée, vapeur).
func _pmat_grow(radius: float, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3, smin: float, smax: float,
		ramp: Gradient, damp: float = 0.0, turb: float = 0.0) -> ParticleProcessMaterial:
	var m := _pmat(radius, dir, spread, vmin, vmax, grav, smin, smax, ramp, damp, turb)
	var ct := CurveTexture.new()
	ct.curve = _grow_curve()
	m.scale_curve = ct
	return m

# ------------------------------------------------------------------------------------------ préparation

## À appeler en tête de `play` : palier de qualité, intensité, teinte choisie dans l'éditeur.
func _begin(ctx: Dictionary) -> void:
	_tier = SpellFxLibrary.tier()
	_pw = clampf(float(ctx.get("fxPower", 1.0)), 0.4, 2.0)
	_g = 0.6 + 0.4 * _pw
	_s = 0.8 + 0.2 * _pw
	_tinted = false
	var t := str(ctx.get("fxTint", ""))
	if t != "" and Color.html_is_valid(t):
		_tinted = true
		_tint_h = Color.html(t).h

# ------------------------------------------------------------------------------------------ outils d'objets

func _node_at(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	return n

func _mesh_node(mesh: Mesh, mat: Material, at: Vector3, scl: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = Vector3.ONE * scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

static var _sphere_m: SphereMesh

static func _unit_sphere() -> SphereMesh:
	if _sphere_m == null:
		_sphere_m = SphereMesh.new()
		_sphere_m.radius = 0.5
		_sphere_m.height = 1.0
		_sphere_m.radial_segments = 28
		_sphere_m.rings = 14
	return _sphere_m

## Matériau de plasma (`mixed` : mélange normal, pour les sphères sombres).
func _plasma_mat(hot: Color, mid: Color, rim: Color, mixed: bool = false) -> ShaderMaterial:
	var code: String = SH_PLASMA.replace("blend_add", "blend_mix") if mixed else SH_PLASMA
	var m := _smat("plasma_mix" if mixed else "plasma", code, 5)
	m = m.duplicate()
	m.set_shader_parameter("hot", hot)
	m.set_shader_parameter("mid", mid)
	m.set_shader_parameter("rim", rim)
	m.set_shader_parameter("power", _g)
	return m

## Sphère de plasma qui gonfle puis se ronge (explosion de feu, orbe qui éclate…). `rise` : montée en mètres.
func _bloom(at: Vector3, size: float, dur: float, hot: Color, mid: Color, rim: Color, mixed: bool = false, rise: float = 0.0, delay: float = 0.0) -> void:
	var m := _plasma_mat(hot, mid, rim, mixed)
	var mi := _mesh_node(_unit_sphere(), m, at, 0.01)
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		mi.scale = Vector3.ONE * size * (0.25 + (1.0 - pow(1.0 - w, 2.5)) * 0.9)
		mi.position = at + Vector3(0, rise * w, 0)
		m.set_shader_parameter("time_s", w * dur)
		m.set_shader_parameter("erode", clampf((w - 0.3) / 0.7, 0.0, 1.0)))

## Pilier vertical de lumière ou de flamme (shader `SH_PILLAR` / `SH_FLAME`), centré sur `base` (pied au sol), de hauteur `h`.
func _pillar(base: Vector3, width: float, h: float, code: String, key: String, params: Dictionary, dur: float, life_fn: Callable) -> void:
	var m := _smat(key, code, 5).duplicate() as ShaderMaterial
	for k in params:
		m.set_shader_parameter(k, params[k])
	var mi := _mesh_node(QuadMesh.new(), m, base + Vector3(0, h * 0.5, 0), 1.0)
	(mi.mesh as QuadMesh).size = Vector2.ONE
	mi.scale = Vector3(width, h, 1.0)
	_add({"node": mi}, dur, func(u: float):
		m.set_shader_parameter("time_s", u * dur)
		life_fn.call(u, mi, m))

## Trait de lame qui balaie (shader `SH_STREAK`), face caméra, retardé de `delay`.
func _streak(at: Vector3, ang: float, length: float, col: Color, dur: float, delay: float = 0.0, thick: float = 0.16, bend: float = 0.25) -> void:
	var m := _smat("streak", SH_STREAK, 6).duplicate() as ShaderMaterial
	m.set_shader_parameter("col", Color(col.r, col.g, col.b, 1.0))
	m.set_shader_parameter("power", _g)
	m.set_shader_parameter("ang", ang)
	m.set_shader_parameter("thick", thick)
	m.set_shader_parameter("bend", bend)
	m.set_shader_parameter("head", 0.0)
	m.set_shader_parameter("tail", -0.2)
	var mi := _quad_node(m, length, at)
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		m.set_shader_parameter("head", clampf(w / 0.45, 0.0, 1.0) * 1.15)
		m.set_shader_parameter("tail", clampf((w - 0.3) / 0.7, 0.0, 1.0) * 1.2 - 0.2))

## Onde de choc posée à plat sur le sol.
func _ground_shock(at: Vector3, col: Color, size: float, dur: float, delay: float = 0.0) -> void:
	var m := _smat("gshock", _ground_shock_code()).duplicate() as ShaderMaterial
	m.set_shader_parameter("col", Color(col.r, col.g, col.b, 1.0))
	m.set_shader_parameter("power", _g)
	m.set_shader_parameter("progress", 0.0)
	var mi := _quad_node(m, size, Vector3(at.x, 0.06, at.z))
	mi.rotation.x = -PI * 0.5
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		m.set_shader_parameter("progress", w))

## Lueur sphérique de dôme / bulle (shader `SH_DOME`) autour de `at`.
func _dome(at: Vector3, radius: float, col: Color, dur: float, power: float = 1.0) -> void:
	var m := _smat("dome", SH_DOME, 5).duplicate() as ShaderMaterial
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("power", _g * power)
	var mi := _mesh_node(_unit_sphere(), m, at, 0.01)
	_add({"node": mi}, dur, func(u: float):
		var grow := 1.0 - pow(1.0 - clampf(u / 0.25, 0.0, 1.0), 3.0)
		mi.scale = Vector3.ONE * radius * 2.0 * (0.4 + grow * 0.6)
		var a := minf(u / 0.12, 1.0) * (1.0 if u < 0.6 else (1.0 - (u - 0.6) / 0.4))
		m.set_shader_parameter("fade", a)
		m.set_shader_parameter("wave", u * 1.3)
		m.set_shader_parameter("time_s", u * dur))

# ------------------------------------------------------------------------------------------ projectile piloté par dictionnaire

func _pk(p: Dictionary, key: String, def: Variant) -> Variant:
	return p[key] if p.has(key) else def

## Émetteur de traînée décrit par `t` : {c: [c0, c1, c2], n, life, sz: [a, b], v: [a, b], grav, turb, k, radius, tex, mix}.
func _trail_emitter(t: Dictionary, at: Vector3) -> GPUParticles3D:
	var cs: Array = t.c
	var tex: Texture2D = _pk(t, "tex", _w_spark())
	var mesh: Mesh = _smoke_mesh(Color.WHITE, tex) if bool(_pk(t, "mix", false)) else _soft_mesh(cs[1], float(_pk(t, "k", 1.2)) * _g, tex)
	var sz: Array = _pk(t, "sz", [0.12, 0.28])
	var v: Array = _pk(t, "v", [0.05, 0.4])
	var pm := _pmat(float(_pk(t, "radius", 0.05)), Vector3.UP, 180.0, float(v[0]), float(v[1]), _pk(t, "grav", Vector3.ZERO),
		float(sz[0]) * _s, float(sz[1]) * _s, _ramp(cs[0], cs[1], cs[2]), float(_pk(t, "damp", 1.0)), float(_pk(t, "turb", 0.0)))
	return _gpu(int(_pk(t, "n", 40)), float(_pk(t, "life", 0.3)), false, mesh, pm, at)

## Projectile de `start` à `end` en `dur` s. `p` : body {kind: plasma|shard|mesh|none, …}, halo [couleur, taille], core taille, trail {…},
## motes {n, c, rad}, arc, lift, ease (accel|smooth|lin), spin, lamp [couleur, énergie, portée], lens [taille, force].
func _fly(start: Vector3, end: Vector3, dur: float, p: Dictionary, on_hit: Callable) -> void:
	on_hit = _track_hit(on_hit)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var arc := float(_pk(p, "arc", 0.2)) * (1.0 if randf() < 0.5 else -1.0)
	var lift := float(_pk(p, "lift", 0.1))
	var ease_k := str(_pk(p, "ease", "accel"))
	var holder := Node3D.new()
	holder.position = start
	add_child(holder)
	if end.distance_to(start) > 0.05 and bool(_pk(p, "orient", true)):
		holder.look_at(end, up)
	var body: Dictionary = _pk(p, "body", {})
	var body_node: Node3D = null
	var body_mat: ShaderMaterial = null
	var bsize := float(body.get("size", 0.3)) * _s
	match str(body.get("kind", "none")):
		"plasma":
			body_mat = _plasma_mat(body.hot, body.mid, body.rim, bool(body.get("mix", false)))
			body_node = _mesh_node(_unit_sphere(), body_mat, Vector3.ZERO, bsize)
			body_node.reparent(holder, false)
		"shard":
			var mi := MeshInstance3D.new()
			mi.mesh = body.mesh
			mi.material_override = _vcol_mat(1.25 * _g)
			mi.scale = Vector3.ONE * bsize
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			body_node = mi
		"mesh":
			body_node = body.node
			holder.add_child(body_node)
			body_node.scale = Vector3.ONE * bsize
	var halo_def: Array = _pk(p, "halo", [])
	var halo: Dictionary = {}
	if not halo_def.is_empty():
		halo = _sprite(_w_soft(), _hdr(halo_def[0], 0.9 * _g), float(halo_def[1]) * _s, start)
	var core_size := float(_pk(p, "core", 0.0))
	var core: Dictionary = {}
	if core_size > 0.0:
		core = _sprite(_w_soft(), Color(1.1, 1.1, 1.1, 1.0), core_size * _s, start)
	var trails: Array = []
	for t in _pk(p, "trails", []):
		trails.append(_trail_emitter(t, start))
	var motes: Array = []
	var md: Dictionary = _pk(p, "motes", {})
	for i in int(md.get("n", 0)):
		motes.append(_sprite(_w_spark(), _hdr(md.c, 1.3 * _g), 0.12 * _s, start))
	var lens_def: Array = _pk(p, "lens", [])
	var lens: MeshInstance3D = null
	if not lens_def.is_empty():
		lens = _lens(start, float(lens_def[0]) * _s, float(lens_def[1]) * _pw, 0.0)
	var lamp_def: Array = _pk(p, "lamp", [])
	var lamp: OmniLight3D = null
	if not lamp_def.is_empty():
		lamp = _lamp_node(start, lamp_def[0], float(lamp_def[1]) * _g, float(lamp_def[2]))
	var spin_k := float(_pk(p, "spin", 0.0))
	var grow := float(_pk(p, "grow", 0.25))
	var seed_f := randf() * TAU
	_add({"node": holder}, dur, func(u: float):
		var k := u
		match ease_k:
			"accel": k = u * u * (1.5 - 0.5 * u)
			"smooth": k = u * u * (3.0 - 2.0 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc) + up * (sin(k * PI) * lift)
		holder.position = pos
		if body_node != null:
			body_node.rotation.z = u * spin_k
			if body_mat != null:
				body_mat.set_shader_parameter("time_s", u * dur + seed_f)
				body_node.scale = Vector3.ONE * bsize * (1.0 + grow * k) * (1.0 + sin(u * 38.0 + seed_f) * 0.05)
		if not halo.is_empty():
			(halo.node as Node3D).position = pos
			(halo.node as Node3D).scale = Vector3.ONE * float(halo_def[1]) * _s * (1.0 + sin(u * 40.0) * 0.1) * (1.0 + grow * k)
		if not core.is_empty():
			(core.node as Node3D).position = pos
		for t in trails:
			(t as GPUParticles3D).position = pos
		for i in motes.size():
			var ang := u * 24.0 + float(i) * TAU / float(motes.size())
			var rad := float(md.get("rad", 0.14)) * _s * (1.0 - u * 0.4)
			(motes[i].node as Node3D).position = pos + right * cos(ang) * rad + up * sin(ang) * rad
		if lens != null:
			lens.position = pos
		if lamp != null:
			lamp.position = pos
		if u >= 1.0:
			holder.queue_free()
			for t in trails:
				(t as GPUParticles3D).emitting = false
				_free_after(t, 0.6)
			if not halo.is_empty():
				(halo.node as Node).queue_free()
			if not core.is_empty():
				(core.node as Node).queue_free()
			for m in motes:
				(m.node as Node).queue_free()
			if lens != null:
				lens.queue_free()
			_fade_lamp(lamp, 0.2)
			on_hit.call())

# ------------------------------------------------------------------------------------------ impact piloté par dictionnaire

## Couleurs [c0, c1, c2] d'une rampe de particules → Gradient.
func _ramp_of(cs: Array) -> Gradient:
	return _ramp(cs[0], cs[1], cs[2])

## Éclats / étincelles / fumée / ruban : voir les clés ci-dessous. Toutes les couleurs sont déjà passées par `_c`.
##   size   : multiplicateur de taille            flash  : [couleur, taille]       shocks : [[couleur, taille, durée, retard], …]
##   ground : [couleur, taille, durée, retard]    sparks : {c, n, v, grav, sz, life}
##   ribbons: {c, n, v, grav, life, w}            shards : {mesh, n, v, grav, sz}  smoke : {c, n, sz, rise, life, add, turb}
##   decal  : [texture, couleur, taille, durée]   lamp   : [couleur, énergie, portée, durée]   shake : amplitude   lens : [taille, force]
func _hit_fx(at: Vector3, target: Dictionary, p: Dictionary) -> void:
	var size := _tsize(target) * float(_pk(p, "size", 1.0)) * _s
	if p.has("flash"):
		var f: Array = p.flash
		_flash(_w_soft(), _hdr(f[0], 1.3 * _g), at, 0.4 * size * float(f[1]), 1.9 * size * float(f[1]), 0.3)
	for sh in _pk(p, "shocks", []):
		_shock(at, sh[0], float(sh[1]) * size, float(sh[2]), float(sh[3]) if sh.size() > 3 else 0.0)
	if p.has("ground"):
		var g: Array = p.ground
		_ground_shock(at, g[0], float(g[1]) * size, float(g[2]), float(g[3]) if g.size() > 3 else 0.0)
	if p.has("lens"):
		_lens(at, float(p.lens[0]) * size, float(p.lens[1]) * _pw, 0.35)
	if p.has("shards"):
		var d: Dictionary = p.shards
		var mesh: ArrayMesh = d.mesh
		mesh.surface_set_material(0, _vcol_mat(1.3 * _g))
		var v: Array = _pk(d, "v", [2.0, 4.2])
		var sz: Array = _pk(d, "sz", [0.18, 0.38])
		var spm := _pmat(0.06, Vector3.UP, 180.0, float(v[0]) * size, float(v[1]) * size, _pk(d, "grav", Vector3(0, -4.5, 0)), float(sz[0]), float(sz[1]),
			_ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
		spm.angle_min = -180.0
		spm.angle_max = 180.0
		spm.angular_velocity_min = -540.0
		spm.angular_velocity_max = 540.0
		_free_after(_gpu(int(_pk(d, "n", 10)), 0.6, true, mesh, spm, at), 0.8)
	if p.has("ribbons"):
		var d2: Dictionary = p.ribbons
		var cs2: Array = d2.c
		var rib := RibbonTrailMesh.new()
		rib.shape = RibbonTrailMesh.SHAPE_CROSS
		rib.size = float(_pk(d2, "w", 0.06))
		rib.sections = 4
		rib.section_length = 0.12
		rib.section_segments = 2
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		rm.vertex_color_use_as_albedo = true
		rm.use_particle_trails = true
		rm.albedo_color = _hdr(cs2[1], 1.5 * _g)
		rib.material = rm
		var v2: Array = _pk(d2, "v", [1.6, 4.0])
		var rpm := _pmat(0.05, Vector3.UP, 180.0, float(v2[0]) * size, float(v2[1]) * size, _pk(d2, "grav", Vector3(0, -2.2, 0)), 1.0, 1.0,
			_ramp_of(cs2), 1.1)
		var rp := _gpu(int(_pk(d2, "n", 16)), float(_pk(d2, "life", 0.7)), true, rib, rpm, at)
		rp.trail_enabled = true
		rp.trail_lifetime = 0.35
		_free_after(rp, 1.1)
	if p.has("sparks"):
		var d3: Dictionary = p.sparks
		var cs3: Array = d3.c
		var v3: Array = _pk(d3, "v", [1.0, 3.0])
		var sz3: Array = _pk(d3, "sz", [0.08, 0.18])
		var gpm := _pmat(0.1, Vector3.UP, 180.0, float(v3[0]) * size, float(v3[1]) * size, _pk(d3, "grav", Vector3(0, -1.0, 0)), float(sz3[0]), float(sz3[1]),
			_ramp_of(cs3), 1.0, 0.8)
		_free_after(_gpu(int(_pk(d3, "n", 26)), float(_pk(d3, "life", 0.8)), true, _soft_mesh(cs3[1], 1.4 * _g, _w_spark()), gpm, at), 1.0)
	var smokes: Array = []
	if p.has("smoke"):
		smokes = p.smoke if p.smoke is Array else [p.smoke]
	for d4 in smokes:
		var cs4: Array = d4.c
		var sz4: Array = _pk(d4, "sz", [0.5, 0.9])
		var add := bool(_pk(d4, "add", false))
		var mesh4: Mesh = _soft_mesh(cs4[1], 0.7 * _g, _flame_puff()) if add else _smoke_mesh(Color.WHITE, _smoke_puff())
		var fpm := _pmat_grow(0.2 * size, Vector3.UP, 60.0, 0.2, 0.7, Vector3(0, float(_pk(d4, "rise", 0.5)), 0), float(sz4[0]) * size, float(sz4[1]) * size,
			_ramp_of(cs4), 0.8, float(_pk(d4, "turb", 0.6)))
		_free_after(_gpu(int(_pk(d4, "n", 8)), float(_pk(d4, "life", 1.0)), true, mesh4, fpm, at + Vector3(0, float(_pk(d4, "y", 0.0)), 0)), float(_pk(d4, "life", 1.0)) + 0.2)
	if p.has("decal"):
		var dc: Array = p.decal
		_glyph_decal(target, dc[0], dc[1], float(dc[2]) * size, float(dc[3]) if dc.size() > 3 else 1.1)
	if p.has("lamp"):
		var lp: Array = p.lamp
		_fade_lamp(_lamp_node(at, lp[0], float(lp[1]) * _g, float(lp[2])), float(lp[3]) if lp.size() > 3 else 0.45)
	if p.has("shake"):
		_shake(float(p.shake) * _pw, 0.22)


static var _rock_m: Dictionary = {}

## Bloc de roche (icosaèdre subdivisé, rayon déformé par un bruit 3D, facettes planes) : météore, débris. Rayon 0,5.
static func _rock_mesh(seed_i: int = 3) -> ArrayMesh:
	if _rock_m.has(seed_i):
		return _rock_m[seed_i]
	var t := (1.0 + sqrt(5.0)) * 0.5
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var fn := FastNoiseLite.new()
	fn.seed = seed_i
	fn.frequency = 1.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: Array = []
	for tri in f:
		var a: Vector3 = (v[tri[0]] as Vector3).normalized()
		var b: Vector3 = (v[tri[1]] as Vector3).normalized()
		var c: Vector3 = (v[tri[2]] as Vector3).normalized()
		var ab := ((a + b) * 0.5).normalized()
		var bc := ((b + c) * 0.5).normalized()
		var ca := ((c + a) * 0.5).normalized()
		tris.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
	for tri in tris:
		for p in tri:
			var d: Vector3 = p
			var r := 0.5 * (1.0 + 0.3 * fn.get_noise_3dv(d * 2.4))
			st.add_vertex(d * r)
	st.generate_normals()
	_rock_m[seed_i] = st.commit()
	return _rock_m[seed_i]

# ------------------------------------------------------------------------------------------ autres briques

## Étoile à quatre branches (éclat de lentille) : cœur lumineux et deux traits fins en croix.
static func _flare4_tex() -> Texture2D:
	if _tex.has("flare4"):
		return _tex["flare4"]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := absf((float(x) + 0.5) / float(n) * 2.0 - 1.0)
			var dy := absf((float(y) + 0.5) / float(n) * 2.0 - 1.0)
			var arms := maxf(exp(-dx * 26.0 - dy * 2.4), exp(-dy * 26.0 - dx * 2.4))
			var core := exp(-sqrt(dx * dx + dy * dy) * 7.0)
			var edge := clampf((1.0 - maxf(dx, dy)) / 0.15, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(arms * 0.95 + core * 0.8, 0.0, 1.0) * edge))
	var t := ImageTexture.create_from_image(img)
	_tex["flare4"] = t
	return t

## Éclat de lentille à quatre branches qui gonfle puis s'éteint.
func _flare4(at: Vector3, col: Color, size: float, dur: float, spin: float = 0.0) -> void:
	var f := _sprite(_flare4_tex(), _hdr(col, 1.3 * _g), size * 0.3, at)
	(f.mat as StandardMaterial3D).no_depth_test = true
	_add(f, dur, func(u: float):
		var e := 1.0 - pow(1.0 - minf(u * 2.5, 1.0), 2.0)
		(f.node as Node3D).scale = Vector3.ONE * size * (0.3 + 0.7 * e)
		(f.node as Node3D).rotation.z = u * spin
		(f.mat as StandardMaterial3D).albedo_color.a = (1.0 - u) * (1.0 - u))

## Rayon de lumière entre deux points (shader `SH_BEAM`), qui apparaît de `a` vers `b` puis s'efface dans le même sens.
func _beam(a: Vector3, b: Vector3, col: Color, width: float, dur: float, delay: float = 0.0) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.05:
		return
	var x := axis / length
	var mid := (a + b) * 0.5
	var to_cam := cam.global_position - mid
	var z := (to_cam - x * to_cam.dot(x)).normalized()
	var y := z.cross(x)
	var m := _smat("beam", SH_BEAM, 5).duplicate() as ShaderMaterial
	m.set_shader_parameter("col", Color(col.r, col.g, col.b, 1.0))
	m.set_shader_parameter("power", _g)
	var mi := _mesh_node(QuadMesh.new(), m, mid, 1.0)
	(mi.mesh as QuadMesh).size = Vector2.ONE
	mi.transform = Transform3D(Basis(x * length, y * width, z), mid)
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		m.set_shader_parameter("head", clampf(w / 0.3, 0.0, 1.0))
		m.set_shader_parameter("tail", clampf((w - 0.45) / 0.55, 0.0, 1.0))
		m.set_shader_parameter("progress", w)
		mi.transform = Transform3D(Basis(x * length, y * width * (1.0 - clampf((w - 0.6) / 0.4, 0.0, 1.0) * 0.6), z), mid))

## Hélice de particules qui montent en tournant autour de `at` (soins, protections, bonus). Retourne l'émetteur (déjà programmé pour s'arrêter).
func _helix(at: Vector3, cs: Array, radius: float, rise: float, orbit: float, n: int, dur: float, tex: Texture2D = null, sz: Array = [0.05, 0.11]) -> GPUParticles3D:
	var pm := _pmat(0.05, Vector3.UP, 6.0, rise * 0.8, rise * 1.2, Vector3.ZERO, float(sz[0]) * _s, float(sz[1]) * _s, _ramp(cs[0], cs[1], cs[2]), 0.0, 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.85
	pm.emission_ring_height = 0.05
	pm.orbit_velocity_min = orbit * 0.8
	pm.orbit_velocity_max = orbit * 1.2
	var p := _gpu(n, 1.0, false, _soft_mesh(cs[1], 1.5 * _g, tex if tex != null else _w_spark()), pm, at)
	_later(dur, func():
		p.emitting = false
		_free_after(p, 1.2))
	return p

## Anneau incliné (auréole, cercle de lumière) qui s'élargit et s'éteint, autour de `at`.
func _halo_ring(at: Vector3, col: Color, size: float, dur: float, tilt: float = 1.1, delay: float = 0.0) -> void:
	var m := _smat("gshock", _ground_shock_code()).duplicate() as ShaderMaterial
	m.set_shader_parameter("col", Color(col.r, col.g, col.b, 1.0))
	m.set_shader_parameter("power", _g)
	m.set_shader_parameter("progress", 0.0)
	var mi := _quad_node(m, size, at)
	mi.rotation.x = -tilt
	mi.visible = delay <= 0.0
	_add({"node": mi}, dur + delay, func(u: float):
		var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
		mi.visible = delay <= 0.0 or w > 0.0
		m.set_shader_parameter("progress", w))
