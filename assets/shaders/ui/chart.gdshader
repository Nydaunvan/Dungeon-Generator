shader_type canvas_item;
// Carte d'atlas : papier noir bleuté, graticule, rose des vents et cercles de portée, parallaxe à la souris.
// `reveal` (0 → 1) fait apparaître la carte à l'encre, avec un bord incandescent.
uniform vec4 paper_a : source_color = vec4(0.045, 0.06, 0.09, 1.0);
uniform vec4 paper_b : source_color = vec4(0.1, 0.12, 0.16, 1.0);
uniform vec4 ink : source_color = vec4(0.72, 0.6, 0.38, 1.0);
uniform vec2 parallax = vec2(0.0);
uniform float reveal = 1.0;
uniform float aspect = 0.7;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float line(float v, float w) { return smoothstep(w, 0.0, abs(v)); }
void fragment() {
	vec2 uv = UV;
	float grain = n(uv * vec2(7.0, 9.0) * 3.0) * 0.6 + n(uv * 55.0) * 0.4;
	vec3 c = mix(paper_a.rgb, paper_b.rgb, grain);
	vec2 q = (uv - 0.5 + parallax * 0.02) * vec2(1.0, 1.0 / aspect);
	// graticule fin et plus marqué toutes les 5 cases
	vec2 g = uv * vec2(14.0, 14.0 / aspect) + parallax * 0.4;
	float gl = max(line(fract(g.x) - 0.5, 0.012), line(fract(g.y) - 0.5, 0.012)) * 0.12;
	float gm = max(line(fract(g.x / 5.0) - 0.5, 0.006), line(fract(g.y / 5.0) - 0.5, 0.006)) * 0.2;
	float r = length(q + parallax * 0.01);
	float rings = line(fract(r * 3.2) - 0.5, 0.01) * 0.18 * smoothstep(1.2, 0.1, r);
	float a = atan(q.y, q.x);
	float spokes = line(fract(a / 6.2831853 * 16.0) - 0.5, 0.012) * smoothstep(0.7, 0.05, r) * 0.2;
	float star = smoothstep(0.1, 0.0, abs(r - 0.34)) * 0.35;
	float draw = gl + gm + rings + spokes + star;
	c += ink.rgb * draw * (0.8 + 0.2 * sin(TIME * 0.7));
	float vig = smoothstep(1.2, 0.2, length((uv - 0.5) * vec2(1.0, 0.85)));
	c *= 0.5 + 0.7 * vig;
	// apparition à l'encre : seuil sur un bruit, front incandescent
	float front = uv.y * 0.5 + n(uv * 6.0) * 0.5;
	float k = reveal * 1.25 - 0.1;
	float shown = smoothstep(k, k - 0.05, front);
	float burn = smoothstep(0.09, 0.0, abs(front - k)) * step(reveal, 0.999);
	c = mix(vec3(0.0), c, shown) + vec3(1.0, 0.55, 0.15) * burn * 1.4;
	COLOR = vec4(c, 1.0);
}
