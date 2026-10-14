extends SpellFxStyles
## Effets arcaniques avancés (Forward+ / Vulkan) : cristal, orbe de mana, rayon. Choisis dans l'éditeur de sorts (voir SpellFxLibrary).
## Par rapport à l'effet d'origine (sprites additifs et particules CPU) : lumière HDR qui nourrit le halo, particules GPU (traînées en
## ruban, étincelles filantes), onde de choc et distorsion en shader, rune qui se grave au sol, lumière dynamique qui éclaire la brume,
## légère secousse de caméra. Tout se règle avec la teinte et l'intensité du sort et se réduit selon le niveau graphique :
##   palier 1 : particules GPU + halo · palier 2 : + lumière, brume éclairée, rune au sol · palier 3 : + distorsion de l'écran.

const BASE_HUE := 0.74       # teinte d'origine (violet) : `fxTint` la remplace en conservant les nuances

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
	float width = mix(0.16, 0.05, progress);
	float ring = smoothstep(width, 0.0, abs(r - radius + wob));
	float fade = (1.0 - progress) * (1.0 - progress);
	float core = smoothstep(0.5, 0.0, r) * (1.0 - progress) * 0.6;
	ALBEDO = col.rgb * (ring * 2.6 + core * 1.4) * power;
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
var _tint_h: float = BASE_HUE

## Point d'entrée (appelé par SpellFxLibrary). `ctx` : style, mode, fx, fxTint, fxPower…
func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_tier = SpellFxLibrary.tier()
	_pw = clampf(float(ctx.get("fxPower", 1.0)), 0.4, 2.0)
	_g = 0.6 + 0.4 * _pw
	_s = 0.8 + 0.2 * _pw
	if _tier >= 2:
		_rune_tex()      # la texture se génère au premier lancer (préchauffage) : pas d'à-coup au premier vrai sort
	var t := str(ctx.get("fxTint", ""))
	if t != "" and Color.html_is_valid(t):
		_tinted = true
		_tint_h = Color.html(t).h
	match str(ctx.get("fx", "arcane_crystal")):
		"arcane_orb":
			_orb_cast(target)
		"arcane_beam":
			_beam_cast(target)
		_:
			_crystal_cast(target)

# ------------------------------------------------------------------------------------------ outils

## Couleur de la palette d'origine (violet), tournée vers la teinte choisie en gardant saturation et luminosité.
func _c(r: float, g: float, b: float, a: float = 1.0) -> Color:
	var base := Color(r, g, b, a)
	if not _tinted:
		return base
	return Color.from_hsv(fposmod(base.h - BASE_HUE + _tint_h, 1.0), base.s, base.v, a)

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

## Rune gravée au sol sous le monstre visé (palier 2 et plus, option « décalques »), qui tourne et s'éteint.
func _rune_decal(target: Dictionary, col: Color, size: float) -> void:
	if _tier < 2 or target.is_empty() or not VisualFx.is_forward() or not bool(Settings.opt("fx_decals")):
		return
	var d := Decal.new()
	d.size = Vector3(2.6 * size, 1.2, 2.6 * size)
	d.texture_albedo = _rune_tex()
	d.texture_emission = _rune_tex()
	d.albedo_mix = 1.0
	d.position = Vector3(target.pos.x, 0.05, target.pos.z)
	add_child(d)
	var energy := 3.0 * _g
	_add({"node": d}, 1.1, func(u: float):
		var fade := minf(1.0, u * 8.0) * (1.0 - u) * (1.0 - u)
		d.modulate = Color(col.r, col.g, col.b, fade)
		d.emission_energy = energy * fade
		d.rotation.y = u * 1.4)

# ------------------------------------------------------------------------------------------ impact commun

## Impact : flash, ondes de choc, éclats de cristal, étincelles filantes (rubans GPU), fumée lumineuse, rune au sol, lumière, secousse.
func _burst(at: Vector3, target: Dictionary, big: float = 1.0) -> void:
	var size := _tsize(target) * big * _s
	_flash(_w_soft(), _hdr(_c(0.9, 0.82, 1.0), 1.3 * _g), at, 0.4 * size, 1.9 * size, 0.3)
	_shock(at, _c(0.78, 0.6, 1.0), 2.6 * size, 0.5)
	_later(0.08, func(): _shock(at, _c(0.92, 0.82, 1.0), 1.7 * size, 0.35))
	_lens(at, 3.0 * size, 0.07 * _pw, 0.35)
	# éclats de cristal projetés
	var key := "fxa_shard_%d" % (int(_tint_h * 100.0) if _tinted else -1)
	var shard := _shard_pal(key, _c(1.0, 1.0, 1.0), _c(0.78, 0.62, 1.0), _c(0.42, 0.22, 0.85))
	shard.surface_set_material(0, _vcol_mat(1.3 * _g))
	var spm := _pmat(0.06, Vector3.UP, 180.0, 2.0 * size, 4.2 * size, Vector3(0, -4.5, 0), 0.18, 0.38, _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
	spm.angle_min = -180.0
	spm.angle_max = 180.0
	spm.angular_velocity_min = -540.0
	spm.angular_velocity_max = 540.0
	_free_after(_gpu(10, 0.6, true, shard, spm, at), 0.8)
	# étincelles filantes : chacune laisse un ruban de lumière
	var rib := RibbonTrailMesh.new()
	rib.shape = RibbonTrailMesh.SHAPE_CROSS
	rib.size = 0.06
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
	rm.albedo_color = _hdr(_c(0.85, 0.72, 1.0), 1.5 * _g)
	rib.material = rm
	var rpm := _pmat(0.05, Vector3.UP, 180.0, 1.6 * size, 4.0 * size, Vector3(0, -2.2, 0), 1.0, 1.0,
		_ramp(_c(1.0, 0.95, 1.0, 1.0), _c(0.75, 0.55, 1.0, 0.9), _c(0.45, 0.25, 1.0, 0.0)), 1.1)
	var rib_p := _gpu(16, 0.7, true, rib, rpm, at)
	rib_p.trail_enabled = true
	rib_p.trail_lifetime = 0.35
	_free_after(rib_p, 1.1)
	# étincelles et fumée lumineuse
	var gpm := _pmat(0.1, Vector3.UP, 180.0, 1.0 * size, 3.0 * size, Vector3(0, -1.0, 0), 0.08, 0.18,
		_ramp(_c(1.0, 0.95, 1.0, 1.0), _c(0.78, 0.6, 1.0, 0.9), _c(0.5, 0.3, 1.0, 0.0)), 1.0, 0.8)
	_free_after(_gpu(26, 0.8, true, _soft_mesh(_c(0.85, 0.7, 1.0), 1.4 * _g, _w_spark()), gpm, at), 1.0)
	var fpm := _pmat(0.2 * size, Vector3.UP, 60.0, 0.2, 0.7, Vector3(0, 0.5, 0), 0.5 * size, 0.9 * size,
		_ramp(_c(0.6, 0.4, 1.0, 0.0), _c(0.5, 0.3, 0.95, 0.35), _c(0.3, 0.15, 0.7, 0.0)), 0.8, 0.6)
	_free_after(_gpu(8, 0.9, true, _soft_mesh(_c(0.55, 0.35, 1.0), 0.6 * _g, _w_soft()), fpm, at), 1.1)
	_rune_decal(target, _c(0.7, 0.5, 1.0), size)
	var lamp := _lamp_node(at, _c(0.7, 0.5, 1.0), 2.0 * _g, 5.0)
	_fade_lamp(lamp, 0.45)
	_shake(0.03 * _pw, 0.2)

# ------------------------------------------------------------------------------------------ CRISTAL

## Cristal arcanique : un cristal HDR tournoie vers le monstre, traînée de particules GPU, éclats en orbite, distorsion de l'air.
func _crystal_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var dur := clampf(0.30 + start.distance_to(end) * 0.035, 0.34, 0.5)
	var arc := 0.28 * (1.0 if randf() < 0.5 else -1.0)
	var holder := Node3D.new()
	holder.position = start
	add_child(holder)
	if end.distance_to(start) > 0.05:
		holder.look_at(end, up)
	var key := "fxa_crystal_%d" % (int(_tint_h * 100.0) if _tinted else -1)
	var body := MeshInstance3D.new()
	body.mesh = _shard_pal(key, _c(1.0, 1.0, 1.0), _c(0.78, 0.62, 1.0), _c(0.42, 0.22, 0.85))
	body.material_override = _vcol_mat(1.25 * _g)
	body.scale = Vector3.ONE * 1.6 * _s
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	var halo := _sprite(_w_soft(), _hdr(_c(0.72, 0.55, 1.0, 0.55), 0.9 * _g), 0.6 * _s, start)
	var core := _sprite(_w_soft(), Color(1.5, 1.5, 1.7, 1.0), 0.16 * _s, start)
	var tr_ramp := _ramp(_c(0.85, 0.7, 1.0, 0.0), _c(0.65, 0.45, 1.0, 0.85), _c(0.4, 0.2, 0.9, 0.0))
	var trail := _gpu(40, 0.28, false, _soft_mesh(_c(0.8, 0.6, 1.0), 1.2 * _g, _w_spark()),
		_pmat(0.05, Vector3.UP, 180.0, 0.05, 0.4, Vector3.ZERO, 0.12 * _s, 0.28 * _s, tr_ramp, 1.0), start)
	var motes: Array = []
	for i in 3:
		motes.append(_sprite(_w_spark(), _hdr(_c(0.85, 0.75, 1.0, 0.9), 1.3 * _g), 0.12 * _s, start))
	var lens := _lens(start, 1.4 * _s, 0.05 * _pw, 0.0)
	var lamp := _lamp_node(start, _c(0.6, 0.4, 1.0), 1.6 * _g, 4.0)
	_add({"node": holder}, dur, func(u: float):
		var k := u * u * (1.5 - 0.5 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc) + up * (sin(k * PI) * 0.1)
		holder.position = pos
		body.rotation.z = u * TAU * 3.0
		(halo.node as Node3D).position = pos
		(halo.node as Node3D).scale = Vector3.ONE * 0.6 * _s * (1.0 + sin(u * 40.0) * 0.12)
		(core.node as Node3D).position = pos
		trail.position = pos
		for i in motes.size():
			var ang := u * 24.0 + float(i) * TAU / 3.0
			var rad := 0.17 * (1.0 - u * 0.4)
			(motes[i].node as Node3D).position = pos + right * cos(ang) * rad + up * sin(ang) * rad
		if lens != null:
			lens.position = pos
		if lamp != null:
			lamp.position = pos
		if u >= 1.0:
			trail.emitting = false
			_free_after(trail, 0.5)
			(halo.node as Node).queue_free()
			(core.node as Node).queue_free()
			for m in motes:
				(m.node as Node).queue_free()
			if lens != null:
				lens.queue_free()
			_fade_lamp(lamp, 0.2)
			_burst(end, target))

# ------------------------------------------------------------------------------------------ ORBE

## Orbe de mana : sphère pulsante, plus lente, entourée de volutes ; l'impact est plus ample.
func _orb_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var dur := clampf(0.42 + start.distance_to(end) * 0.045, 0.5, 0.7)
	var arc := 0.18 * (1.0 if randf() < 0.5 else -1.0)
	var om := _smat("orb", SH_ORB, 5)
	om.set_shader_parameter("col_a", _c(0.45, 0.25, 1.0))
	om.set_shader_parameter("col_b", _c(0.9, 0.8, 1.0))
	om.set_shader_parameter("power", _g)
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 12
	sphere.mesh = sm
	sphere.material_override = om
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere.position = start
	add_child(sphere)
	var halo := _sprite(_w_soft(), _hdr(_c(0.6, 0.4, 1.0, 0.6), 1.0 * _g), 1.0 * _s, start)
	var wisp_ramp := _ramp(_c(0.8, 0.65, 1.0, 0.0), _c(0.7, 0.5, 1.0, 0.8), _c(0.4, 0.2, 0.9, 0.0))
	var wisps := _gpu(36, 0.5, false, _soft_mesh(_c(0.75, 0.6, 1.0), 1.6 * _g, _w_spark()),
		_pmat(0.28, Vector3.UP, 180.0, 0.1, 0.5, Vector3.ZERO, 0.1 * _s, 0.24 * _s, wisp_ramp, 1.5, 1.2), start)
	var lens := _lens(start, 1.8 * _s, 0.05 * _pw, 0.0)
	var lamp := _lamp_node(start, _c(0.55, 0.35, 1.0), 2.0 * _g, 4.5)
	_add({"node": sphere}, dur, func(u: float):
		var k := u * u * (3.0 - 2.0 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc) + up * (sin(k * PI) * 0.12)
		sphere.position = pos
		var pulse := 1.0 + sin(u * 30.0) * 0.1
		sphere.scale = Vector3.ONE * 0.42 * _s * pulse * (1.0 + 0.3 * k)
		om.set_shader_parameter("time_s", u * dur)
		(halo.node as Node3D).position = pos
		(halo.node as Node3D).scale = Vector3.ONE * 1.0 * _s * pulse
		wisps.position = pos
		if lens != null:
			lens.position = pos
		if lamp != null:
			lamp.position = pos
		if u >= 1.0:
			wisps.emitting = false
			_free_after(wisps, 0.6)
			(halo.node as Node).queue_free()
			if lens != null:
				lens.queue_free()
			_fade_lamp(lamp, 0.25)
			_flash(_w_soft(), _hdr(_c(0.8, 0.7, 1.0), 1.3 * _g), end, 0.5 * _s, 2.4 * _s, 0.5)
			_burst(end, target, 1.25))

# ------------------------------------------------------------------------------------------ RAYON

## Rayon arcanique : un trait de lumière jaillit du bas de l'écran jusqu'au monstre, puis s'efface de l'origine vers la cible.
func _beam_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var axis := end - start
	var length := axis.length()
	if length < 0.1:
		_burst(end, target)
		return
	var x := axis / length
	var mid := (start + end) * 0.5
	var to_cam := cam.global_position - mid
	var z := (to_cam - x * to_cam.dot(x)).normalized()
	var y := z.cross(x)
	var dur := 0.38
	var bm := _smat("beam", SH_BEAM, 5)
	bm.set_shader_parameter("col", _c(0.7, 0.5, 1.0))
	bm.set_shader_parameter("power", _g)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(x * length, y * 0.6 * _s, z), mid)
	add_child(mi)
	_flash(_w_soft(), _hdr(_c(0.85, 0.75, 1.0), 1.3 * _g), start, 0.3 * _s, 1.2 * _s, 0.3)
	var lamp := _lamp_node(mid, _c(0.6, 0.4, 1.0), 2.2 * _g, 6.0)
	_add({"node": mi}, dur, func(u: float):
		bm.set_shader_parameter("head", clampf(u / 0.3, 0.0, 1.0))
		bm.set_shader_parameter("tail", clampf((u - 0.45) / 0.55, 0.0, 1.0))
		bm.set_shader_parameter("progress", u)
		var w := 0.6 * _s * (1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0) * 0.6)
		mi.transform = Transform3D(Basis(x * length, y * w, z), mid))
	_fade_lamp(lamp, dur)
	_later(0.1, func(): _burst(end, target))
