shader_type canvas_item;
render_mode blend_add;
// Traits d'atlas en filigrane (graticule, cercles de portée, rose des vents), additifs : posés sur la pierre.
// `reveal` (0 → 1) : les traits se tracent comme de l'encre, du haut vers le bas, avec un front incandescent.
uniform vec4 ink : source_color = vec4(0.72, 0.6, 0.38, 1.0);
uniform float strength = 1.0;
uniform float reveal = 1.0;
uniform float aspect = 0.7;
uniform vec2 parallax = vec2(0.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float line(float v, float w) { return smoothstep(w, 0.0, abs(v)); }
void fragment() {
	vec2 uv = UV;
	vec2 q = (uv - vec2(0.5, 0.55) + parallax * 0.012) * vec2(1.0, 1.0 / aspect);
	vec2 g = uv * vec2(16.0, 16.0 / aspect) + parallax * 0.3;
	float gl = max(line(fract(g.x) - 0.5, 0.01), line(fract(g.y) - 0.5, 0.01)) * 0.07;
	float gm = max(line(fract(g.x / 4.0) - 0.5, 0.005), line(fract(g.y / 4.0) - 0.5, 0.005)) * 0.12;
	float r = length(q);
	float rings = line(fract(r * 3.0) - 0.5, 0.008) * 0.14 * smoothstep(1.1, 0.1, r);
	float a = atan(q.y, q.x);
	float spokes = line(fract(a / 6.2831853 * 16.0) - 0.5, 0.01) * smoothstep(0.65, 0.05, r) * 0.15;
	float draw = (gl + gm + rings + spokes) * (0.8 + 0.2 * sin(TIME * 0.7));
	float front = uv.y * 0.6 + n(uv * 5.0) * 0.4;
	float k = reveal * 1.3 - 0.1;
	float shown = smoothstep(k, k - 0.06, front);
	float burn = smoothstep(0.07, 0.0, abs(front - k)) * step(reveal, 0.999);
	vec3 c = ink.rgb * draw * shown * strength + vec3(1.0, 0.55, 0.15) * burn * 0.35 * strength;
	COLOR = vec4(c, 1.0);
}
