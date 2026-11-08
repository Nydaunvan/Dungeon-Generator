shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;
// Magma décorative des Forges du monde brisé. Animation = temps d'affichage seulement (jamais d'effet sur le jeu).
// state : 0 presque refroidie, 1 active, 2 très incandescente. COLOR.rg = position réduite dans le quad (-1..1), UV en mètres.
uniform float state = 1.0;
uniform float speed = 0.09;
uniform vec3 hot : source_color = vec3(1.0, 0.27, 0.035);
uniform vec3 white_hot : source_color = vec3(1.0, 0.58, 0.16);
uniform float energy = 1.9;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	float t = TIME * speed;
	float n = fbm(UV * 1.6 + vec2(t, -t * 0.6));
	float edge = 1.0 - max(abs(COLOR.r), abs(COLOR.g));          // 1 au centre, 0 au bord
	float wob = edge + (n - 0.5) * 0.9;
	if (wob < 0.10) discard;                                      // contour déchiqueté
	float cr = fbm(UV * 2.3 + vec2(t * 0.5, t * 0.35) + n * 0.8);
	float veins = 1.0 - smoothstep(0.0, 0.115, abs(cr - 0.5));     // veines incandescentes entre les plaques de croûte
	float heat = state < 0.5 ? 0.30 : (state < 1.5 ? 0.78 : 1.35);
	float pulse = 0.88 + 0.12 * sin(TIME * 0.55 + n * 7.0);
	float rim = smoothstep(0.10, 0.34, wob);                      // bord refroidi : croûte noire
	float core = clamp(veins * (0.55 + 0.45 * state * 0.5) + (state > 1.5 ? 0.25 * (1.0 - cr) : 0.0), 0.0, 1.0);
	vec3 crust = mix(vec3(0.020, 0.016, 0.016), vec3(0.075, 0.050, 0.040), cr);
	vec3 glow = mix(hot, white_hot, clamp(core * (0.35 + 0.3 * state), 0.0, 1.0));
	float em = core * heat * rim * pulse;
	ALBEDO = crust;
	ROUGHNESS = 0.9;
	float under = (1.0 - smoothstep(0.30, 0.62, cr)) * 0.22;      // lueur diffuse sous la croûte
	EMISSION = glow * em * energy + hot * (0.04 + under) * heat * rim;
}
