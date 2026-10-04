class_name SwordBar
extends Control
## Barre de chargement « sabre d'énergie » : l'épée du jeu, posée à l'horizontale (pommeau à gauche, pointe à droite).
## Au fil du chargement, la lame (jamais la garde ni la poignée) s'enveloppe d'une aura d'énergie bleue qui épouse sa forme,
## du blanc brûlant au bord de l'acier jusqu'au bleu profond, avec des filets d'énergie qui courent vers la pointe.
## Un seul shader dessine tout (aucune particule) : léger, même sur mobile. À 100 %, un éclat illumine la lame.

const SIZE_PX := Vector2(880, 340)
const SWORD_POS := Vector2(40, 75)
const SWORD_W := 800.0
const BLADE_X0 := 0.30            # début de la lame (juste au-dessus de la garde), en fraction de la longueur de l'épée
const PAD := 160                  # marge transparente (pixels de texture) où déborde l'aura

const SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float progress = 0.0;
uniform float time_s = 0.0;
uniform float flash = 0.0;
uniform float x0 = 0.30;
uniform vec2 rect_px = vec2(900.0, 330.0);   // taille du rectangle en pixels d'écran
uniform vec2 pad_map = vec2(0.0, 1.0);    // x = marge (fraction de la largeur), y = largeur de l'épée (fraction de la largeur du rectangle)

float hash(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment(){
	vec4 tex = texture(TEXTURE, UV);
	float xs = (UV.x - pad_map.x) / pad_map.y;                         // 0..1 le long de l'épée
	float n = vnoise(vec2(xs * 22.0 - time_s * 0.8, UV.y * 9.0)) * 0.65 + vnoise(vec2(xs * 50.0 - time_s * 1.7, UV.y * 17.0)) * 0.35;
	float f = x0 + progress * (1.0 - x0) + (n - 0.5) * 0.02;
	float inblade = smoothstep(x0 - 0.004, x0 + 0.01, xs);
	float lit = (1.0 - smoothstep(f - 0.035, f + 0.006, xs)) * inblade;
	float behind = max(f - xs, 0.0);
	float edge = exp(-abs(xs - f) * 30.0) * step(0.004, progress) * inblade;

	// l'acier : froid et un peu éteint, puis gagné par l'énergie bleue
	vec3 col = tex.rgb;
	col = mix(col, mix(col * vec3(0.8, 0.82, 0.9), col, lit), inblade);
	vec3 energy = mix(vec3(0.12, 0.34, 1.0), vec3(0.7, 0.92, 1.0), clamp(dot(tex.rgb, vec3(0.3, 0.59, 0.11)) * 1.2 + n * 0.4 - 0.2, 0.0, 1.0));
	float hot = lit * (0.2 * exp(-behind * 2.4) + 0.1 + 0.04 * sin(time_s * 6.0 + xs * 18.0));
	col = mix(col, col * energy * 1.3 + energy * 0.14, hot);

	// aura : l'alpha de l'épée, flouté à plusieurs échelles (mipmaps), épouse la lame
	float g1 = textureLod(TEXTURE, UV, 1.6).a;
	float g2 = textureLod(TEXTURE, UV, 3.0).a;
	float g3 = textureLod(TEXTURE, UV, 4.6).a;
	float dy = (UV.y - 0.5) * rect_px.y;                                  // distance à l'axe de la lame (pixels)
	float g4 = exp(-dy * dy / (2.0 * 17.0 * 17.0));                       // halo serré, autour de l'axe
	float g5 = exp(-dy * dy / (2.0 * 46.0 * 46.0));                       // halo large
	float stream = 0.75 + 0.5 * vnoise(vec2(xs * 34.0 - time_s * 3.2, UV.y * 7.0));
	float pulse = 0.92 + 0.08 * sin(time_s * 9.0) * sin(time_s * 2.3 + 1.0);
	float aura = (g1 * 1.25 + g2 * 1.0 * stream + g3 * 0.85 + g4 * 0.7 * stream + g5 * 0.85) * (1.0 + flash * 0.9);
	aura *= mix(1.0, 0.16, tex.a);                                      // sur le métal l'aura reste discrète
	aura *= lit * pulse * inblade;
	aura += edge * (g1 + g2) * 0.9 * (1.0 + flash) * mix(1.0, 0.2, tex.a);
	vec3 a_col = mix(vec3(0.03, 0.14, 0.8), vec3(0.2, 0.58, 1.0), smoothstep(0.15, 0.8, aura));
	a_col = mix(a_col, vec3(0.78, 0.94, 1.0), smoothstep(1.35, 2.3, aura));
	vec3 glow = a_col * clamp(aura, 0.0, 1.8) * 0.9;

	// filets d'énergie sur le métal
	float vein = smoothstep(0.62, 0.95, vnoise(vec2(xs * 40.0 - time_s * 2.6, UV.y * 30.0))) * lit * tex.a;
	col += vec3(0.5, 0.82, 1.0) * vein * 0.28;
	col += vec3(0.55, 0.8, 1.0) * edge * tex.a * 0.9;

	float sa = tex.a;
	COLOR = vec4(col * sa + glow * (1.0 - sa * 0.55), sa);
}
"""

var value := 0.0
var _t := 0.0
var _rect: TextureRect
var _mat: ShaderMaterial
var _flash := 0.0
var _done := false

func _init() -> void:
	custom_minimum_size = SIZE_PX
	size = SIZE_PX
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var src: Texture2D = load("res://assets/ui/sword_loading.png")
	var img: Image = src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var padded := Image.create(w + 2 * PAD, h + 2 * PAD, false, Image.FORMAT_RGBA8)
	padded.fill(Color(0, 0, 0, 0))
	padded.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(PAD, PAD))
	padded.generate_mipmaps()
	var tex := ImageTexture.create_from_image(padded)
	var k := SWORD_W / float(w)                  # pixels d'écran par pixel de texture
	_rect = TextureRect.new()
	_rect.texture = tex
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rect.size = Vector2(padded.get_width(), padded.get_height()) * k
	_rect.position = SWORD_POS - Vector2(PAD, PAD) * k
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("rect_px", _rect.size)
	_mat.set_shader_parameter("x0", BLADE_X0)
	_mat.set_shader_parameter("pad_map", Vector2(float(PAD) / padded.get_width(), float(w) / padded.get_width()))
	_rect.material = _mat
	add_child(_rect)

func _process(delta: float) -> void:
	_t += delta
	if _mat == null:
		return
	var v := clampf(value, 0.0, 1.0)
	if v >= 0.999 and not _done:
		_done = true
		_flash = 1.0
	elif v < 0.5:
		_done = false
	_flash = maxf(_flash - delta * 1.1, 0.0)
	_mat.set_shader_parameter("progress", v)
	_mat.set_shader_parameter("time_s", _t)
	_mat.set_shader_parameter("flash", _flash)
