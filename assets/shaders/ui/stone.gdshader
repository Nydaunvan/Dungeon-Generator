shader_type canvas_item;
// Maçonnerie froide d'ardoise : appareil de pierre, grain, vignette. Sert de fond aux fenêtres gothic Atlas Noir.
uniform vec4 base_a : source_color = vec4(0.075, 0.085, 0.11, 1.0);
uniform vec4 base_b : source_color = vec4(0.16, 0.18, 0.23, 1.0);
uniform vec2 blocks = vec2(5.0, 11.0);
uniform float mortar_k = 0.4;
uniform float vignette = 0.75;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(6.0, 9.0);
	float v = n(p * 2.0) * 0.5 + n(p * 5.0) * 0.3 + n(p * 13.0) * 0.2;
	vec2 bp = UV * blocks;
	float row = floor(bp.y);
	bp.x += mod(row, 2.0) * 0.5;
	vec2 g = abs(fract(bp) - 0.5);
	float mortar = smoothstep(0.43, 0.5, max(g.x * 0.85, g.y));
	vec3 c = mix(base_a.rgb, base_b.rgb, v);
	c *= 1.0 - mortar * mortar_k;
	c += (h(floor(UV * 420.0)) - 0.5) * 0.02;
	float vig = smoothstep(1.15, 0.15, length((UV - 0.5) * vec2(1.0, 0.85)));
	c *= (1.0 - vignette) + vignette * vig * 1.25;
	COLOR = vec4(c, 1.0);
}
