shader_type canvas_item;
render_mode blend_add;
// Brume basse qui dérive (bruit fractal à trois octaves).
uniform vec4 col : source_color = vec4(0.38, 0.5, 0.68, 1.0);
uniform float strength = 0.35;
uniform float from_y = 0.55;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(3.0, 2.0);
	float m = n(p + vec2(TIME * 0.06, -TIME * 0.02)) * 0.55 + n(p * 2.1 + vec2(-TIME * 0.09, TIME * 0.03)) * 0.3 + n(p * 4.3 + vec2(TIME * 0.12, 0.0)) * 0.15;
	float mask = smoothstep(from_y, 1.0, UV.y);
	COLOR = vec4(col.rgb * m * m * mask * strength * 2.0, 1.0);
}
