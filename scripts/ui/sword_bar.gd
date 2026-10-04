class_name SwordBar
extends Control
## Barre de chargement « épée en feu » : l'épée du jeu, posée à l'horizontale (pommeau à gauche, pointe à droite),
## s'embrase de la garde vers la pointe, sur la lame seulement, au fil du chargement. La lame rougit puis rayonne, des flammes montent sur toute
## la partie chauffée, un front de feu plus vif avance, des braises et des étincelles s'échappent, de la fumée s'élève.
## À 100 %, la lame jette une gerbe d'étincelles.

const SIZE_PX := Vector2(880, 330)
const SWORD_POS := Vector2(40, 108)
const SWORD_W := 800.0
const BLADE_Y := 203.0            # axe de la lame dans le contrôle
const BLADE_HALF := 35.0
const BLADE_X0 := 0.30            # début de la lame (juste au-dessus de la garde), en fraction de la longueur de l'épée
const BLADE_LEN := SWORD_W * (1.0 - BLADE_X0)
const BLADE_PX := 40.0 + SWORD_W * BLADE_X0

const SWORD_SHADER := """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float time_s = 0.0;
uniform float x0 = 0.30;
float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p){
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++){ s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.7); a *= 0.5; }
	return s;
}
void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	float n = fbm(vec2(UV.x * 16.0 - time_s * 0.7, UV.y * 6.0 + time_s * 0.35));
	float f = x0 + progress * (1.0 - x0) + (n - 0.5) * 0.03;
	float inblade = smoothstep(x0 - 0.004, x0 + 0.008, UV.x);          // la garde et la poignée ne brûlent pas
	float lit = (1.0 - smoothstep(f - 0.03, f + 0.008, UV.x)) * inblade;
	float behind = max(f - UV.x, 0.0);
	float edge = exp(-abs(UV.x - f) * 34.0) * step(0.004, progress) * inblade;
	vec3 col = tex.rgb;
	vec3 cold = col * vec3(0.8, 0.82, 0.9);
	col = mix(col, mix(cold, col, lit), inblade);                      // lame froide un peu éteinte
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	vec3 heat = mix(vec3(0.1, 0.3, 0.95), vec3(0.65, 0.88, 1.0), clamp(lum * 1.3 + n * 0.5 - 0.25, 0.0, 1.0));
	float hot = lit * (0.28 * exp(-behind * 2.6) + 0.2 + 0.06 * sin(time_s * 6.0 + UV.x * 18.0));
	col = mix(col, col * heat * 1.3 + heat * 0.14, hot);              // le métal s'embrase en bleu
	col += vec3(0.5, 0.78, 1.0) * edge * 0.95;                         // front incandescent
	COLOR = vec4(col, tex.a);
}
"""

const HALO_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float progress = 0.0;
uniform float time_s = 0.0;
uniform vec4 rect = vec4(0.3, 0.91, 0.62, 0.2);   // x0, x1, y centre, demi-hauteur (en fraction du contrôle)
void fragment(){
	float x = (UV.x - rect.x) / (rect.y - rect.x);
	float front = progress;
	float lit = 1.0 - smoothstep(front - 0.02, front + 0.12, x);
	float dy = (UV.y - rect.z) / rect.w;
	float across = exp(-dy * dy * 1.7);
	float ends = smoothstep(-0.08, 0.04, x) * (1.0 - smoothstep(1.0, 1.1, x));
	float flick = 0.88 + 0.12 * sin(time_s * 7.0) * sin(time_s * 3.1 + 1.0);
	float a = lit * across * ends * flick * step(0.003, progress);
	COLOR = vec4(vec3(0.22, 0.5, 1.0) * a * 0.55, a);
}
"""

var value := 0.0
var _t := 0.0
var _sword: TextureRect
var _sword_mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _body: CPUParticles2D
var _front: CPUParticles2D
var _sparks: CPUParticles2D
var _embers: CPUParticles2D
var _smoke: CPUParticles2D
var _burst: CPUParticles2D
var _done := false

func _init() -> void:
	custom_minimum_size = SIZE_PX
	size = SIZE_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	# halo derrière l'épée
	var halo := ColorRect.new()
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo_mat = ShaderMaterial.new()
	var hs := Shader.new()
	hs.code = HALO_SHADER
	_halo_mat.shader = hs
	_halo_mat.set_shader_parameter("rect", Vector4(BLADE_PX / SIZE_PX.x, (SWORD_POS.x + SWORD_W) / SIZE_PX.x, BLADE_Y / SIZE_PX.y, 75.0 / SIZE_PX.y))
	halo.material = _halo_mat
	add_child(halo)

	_smoke = _emitter(26, 2.2, Vector2(1, 8))
	_smoke.color_ramp = _ramp([[0.0, Color(0.14, 0.18, 0.28, 0.0)], [0.25, Color(0.13, 0.17, 0.27, 0.2)], [1.0, Color(0.07, 0.09, 0.15, 0.0)]])
	_smoke.texture = _soft_disc()
	_smoke.material = null
	_smoke.initial_velocity_min = 18.0
	_smoke.initial_velocity_max = 42.0
	_smoke.gravity = Vector2(10, -18)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 0.9
	_smoke.scale_amount_curve = _curve([[0.0, 0.6], [1.0, 2.2]])
	add_child(_smoke)

	_sword = TextureRect.new()
	_sword.texture = load("res://assets/ui/sword_loading.png")
	_sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sword.stretch_mode = TextureRect.STRETCH_SCALE
	_sword.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tsz: Vector2 = _sword.texture.get_size()
	_sword.position = SWORD_POS
	_sword.size = Vector2(SWORD_W, SWORD_W * tsz.y / tsz.x)
	_sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sword_mat = ShaderMaterial.new()
	var ss := Shader.new()
	ss.code = SWORD_SHADER
	_sword_mat.shader = ss
	_sword_mat.set_shader_parameter("x0", BLADE_X0)
	_sword.material = _sword_mat
	add_child(_sword)

	var flame_tex := _flame_texture()
	var fire_ramp := _ramp([[0.0, Color(0.8, 0.95, 1.0, 0.0)], [0.12, Color(0.55, 0.8, 1.0, 0.45)], [0.45, Color(0.18, 0.45, 1.0, 0.45)], [0.8, Color(0.08, 0.16, 0.75, 0.35)], [1.0, Color(0.03, 0.05, 0.3, 0.0)]])
	_body = _emitter(105, 0.95, Vector2(10, 3))
	_body.texture = flame_tex
	_body.color_ramp = fire_ramp
	_body.initial_velocity_min = 22.0
	_body.initial_velocity_max = 70.0
	_body.gravity = Vector2(0, -75)
	_body.spread = 9.0
	_body.scale_amount_min = 0.3
	_body.scale_amount_max = 0.66
	_body.scale_amount_curve = _curve([[0.0, 0.7], [0.25, 1.0], [1.0, 0.12]])
	add_child(_body)

	_front = _emitter(26, 0.75, Vector2(7, 4))
	_front.texture = flame_tex
	_front.color_ramp = fire_ramp
	_front.initial_velocity_min = 35.0
	_front.initial_velocity_max = 105.0
	_front.gravity = Vector2(0, -110)
	_front.spread = 16.0
	_front.scale_amount_min = 0.3
	_front.scale_amount_max = 0.6
	_front.scale_amount_curve = _curve([[0.0, 0.6], [0.2, 1.0], [1.0, 0.1]])
	add_child(_front)

	_embers = _emitter(48, 2.1, Vector2(20, 5))
	_embers.texture = _soft_disc()
	_embers.color_ramp = _ramp([[0.0, Color(0.7, 0.9, 1.0, 0.0)], [0.1, Color(0.55, 0.85, 1.0, 1.0)], [0.7, Color(0.2, 0.5, 1.0, 0.8)], [1.0, Color(0.05, 0.1, 0.6, 0.0)]])
	_embers.initial_velocity_min = 25.0
	_embers.initial_velocity_max = 95.0
	_embers.gravity = Vector2(14, -22)
	_embers.spread = 40.0
	_embers.damping_min = 4.0
	_embers.damping_max = 14.0
	_embers.scale_amount_min = 0.05
	_embers.scale_amount_max = 0.13
	_embers.scale_amount_curve = _curve([[0.0, 1.0], [1.0, 0.3]])
	add_child(_embers)

	_sparks = _emitter(38, 0.9, Vector2(6, 14))
	_sparks.texture = _soft_disc()
	_sparks.color_ramp = _ramp([[0.0, Color(0.92, 1.0, 1.0, 1.0)], [0.4, Color(0.45, 0.8, 1.0, 0.95)], [1.0, Color(0.1, 0.3, 0.9, 0.0)]])
	_sparks.initial_velocity_min = 90.0
	_sparks.initial_velocity_max = 260.0
	_sparks.gravity = Vector2(30, 190)
	_sparks.spread = 70.0
	_sparks.scale_amount_min = 0.03
	_sparks.scale_amount_max = 0.08
	add_child(_sparks)

	_burst = _emitter(160, 1.4, Vector2(BLADE_LEN * 0.5, 14))
	_burst.one_shot = true
	_burst.explosiveness = 0.9
	_burst.texture = _soft_disc()
	_burst.color_ramp = _sparks.color_ramp
	_burst.initial_velocity_min = 120.0
	_burst.initial_velocity_max = 380.0
	_burst.gravity = Vector2(0, 160)
	_burst.spread = 90.0
	_burst.scale_amount_min = 0.04
	_burst.scale_amount_max = 0.11
	_burst.position = Vector2(BLADE_PX + BLADE_LEN * 0.5, BLADE_Y - 20.0)
	add_child(_burst)

func _emitter(amount: int, life: float, extents: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	p.position = Vector2(BLADE_PX, BLADE_Y)
	return p

func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	g.offsets = offs
	g.colors = cols
	return g

func _curve(pts: Array) -> Curve:
	var c := Curve.new()
	for p in pts:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	return c

static var _flame_tex: Texture2D
static var _disc_tex: Texture2D

## Langue de feu : goutte effilée à bord vaporeux, blanche (la teinte vient du dégradé des particules).
static func _flame_texture() -> Texture2D:
	if _flame_tex != null:
		return _flame_tex
	var w := 96
	var h := 192
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.045
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := 1.0 - float(y) / (h - 1)             # 0 = base, 1 = pointe
		var width := 0.46 * pow(sin(PI * pow(t, 0.62)), 0.9) * (1.0 - 0.25 * t)
		for x in w:
			var dx := (float(x) / (w - 1) - 0.5) + (noise.get_noise_2d(x * 1.0, y * 1.0) * 0.1 * t)
			var a := clampf((width - absf(dx)) / 0.16, 0.0, 1.0)
			a = pow(a, 1.35) * (1.0 - 0.55 * t)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_flame_tex = ImageTexture.create_from_image(img)
	return _flame_tex

static func _soft_disc() -> Texture2D:
	if _disc_tex != null:
		return _disc_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_disc_tex = t
	return t

func _process(delta: float) -> void:
	_t += delta
	if _sword_mat == null:
		return
	var v := clampf(value, 0.0, 1.0)
	_sword_mat.set_shader_parameter("progress", v)
	_sword_mat.set_shader_parameter("time_s", _t)
	_halo_mat.set_shader_parameter("progress", v)
	_halo_mat.set_shader_parameter("time_s", _t)
	var on := v > 0.004
	var len_px := BLADE_LEN * v
	var x0 := BLADE_PX
	var top := BLADE_Y - BLADE_HALF * 0.75
	# flammes sur toute la partie chauffée de la lame (jamais sur la garde ni la poignée)
	_body.emitting = on
	_body.position = Vector2(x0 + len_px * 0.5, top)
	_body.emission_rect_extents = Vector2(maxf(len_px * 0.5, 2.0), 3.0)
	_smoke.emitting = on
	_smoke.position = Vector2(x0 + len_px * 0.5, top - 28.0)
	_smoke.emission_rect_extents = Vector2(maxf(len_px * 0.5, 2.0), 8.0)
	_embers.emitting = on
	_embers.position = Vector2(x0 + len_px * 0.5, top - 10.0)
	_embers.emission_rect_extents = Vector2(maxf(len_px * 0.5, 2.0), 6.0)
	# front de feu
	var fx := x0 + len_px
	_front.emitting = on and v < 0.999
	_front.position = Vector2(fx - 4.0, BLADE_Y - BLADE_HALF * 0.7)
	_sparks.emitting = on and v < 0.999
	_sparks.position = Vector2(fx, BLADE_Y)
	if v >= 0.999 and not _done:
		_done = true
		_burst.restart()
		_burst.emitting = true
	elif v < 0.5:
		_done = false
