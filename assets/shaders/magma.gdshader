shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;
// Magma des Forges du monde brisé : dense et visqueuse. Le contour est porté par la GÉOMÉTRIE (rubans irréguliers), jamais par un masque rectangulaire :
// aucun discard. Animation lente, sur TIME seulement (jamais d'effet sur le jeu).
// COLOR.r = position en travers du ruban (-1..1 : 0 au cœur, ±1 au bord refroidi), COLOR.g = abscisse réduite ; UV en mètres (x le long, y en travers).
// state : 0 presque refroidie, 1 active, 2 très chaude.
uniform float state = 1.0;
uniform float speed = 0.028;
uniform float energy = 1.35;
uniform vec3 deep_red : source_color = vec3(0.20, 0.010, 0.004);
uniform vec3 orange : source_color = vec3(1.0, 0.24, 0.03);
uniform vec3 yellow : source_color = vec3(1.0, 0.58, 0.14);

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

varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * speed;
	float across = abs(COLOR.r);
	// bruit en coordonnées monde (centimétrique) : le grain est isotrope même sur un ruban de 10 cm de large, sur un mur comme sur le sol
	vec2 q = vec2(wp.x * 0.8 + wp.z * 0.6 + wp.y * 0.3, wp.y * 0.9 + wp.z * 0.5 - wp.x * 0.4) * 5.0;
	vec2 warp = vec2(fbm(q * 0.35 + vec2(t, 0.0)), fbm(q * 0.35 + vec2(3.1, -t))) - 0.5;      // déformation lente : écoulement visqueux
	float plates = fbm(q * 0.9 + warp * 1.4 + vec2(t * 0.7, t * 0.15));                    // plaques de croûte
	float fine = fbm(q * 2.4 + warp * 0.9);
	float core = 1.0 - pow(across, 1.6);                                                    // 1 au centre, 0 au bord
	float pn = clamp((plates - 0.30) / 0.36, 0.0, 1.0);                                      // bruit normalisé 0..1
	float crust = smoothstep(0.68, 0.90, pn + (across - 0.4) * 0.35);                       // plaques de croûte noire qui flottent sur le cœur
	float k = state < 0.5 ? 0.38 : (state < 1.5 ? 0.68 : 0.95);
	float heat = core * (1.18 - 0.9 * pn) * (1.0 - crust) * k;
	vec3 col = mix(vec3(0.0), deep_red, smoothstep(0.04, 0.24, heat));
	col = mix(col, orange, smoothstep(0.30, 0.58, heat));
	col = mix(col, yellow, smoothstep(0.74, 0.92, heat) * smoothstep(0.50, 0.72, fine));    // zones jaune-orangé : minoritaires
	float pulse = 0.94 + 0.06 * sin(TIME * 0.35 + plates * 5.0);
	float rim = smoothstep(0.0, 0.5, core);
	ALBEDO = mix(vec3(0.020, 0.017, 0.016), vec3(0.060, 0.047, 0.040), fine);               // croûte : basalte noir, pas de couleur chaude
	ROUGHNESS = 0.85;
	EMISSION = col * energy * pulse * rim;
}
