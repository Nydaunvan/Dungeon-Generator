shader_type canvas_item;
// Rosace de vitrail procédurale : secteurs et anneaux plombés, couleurs qui respirent.
uniform float sectors = 12.0;
uniform float glow = 1.0;
float hash(float x) { return fract(sin(x * 12.9898) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	if (r > 1.0) { COLOR = vec4(0.0); discard; }
	float a = atan(p.y, p.x) + 3.14159265;
	float u = a / 6.2831853 * sectors;
	float sector = floor(u);
	float band = floor(r * 4.0);
	float id = hash(sector * 3.1 + band * 17.7);
	vec3 deep = vec3(0.07, 0.14, 0.42);
	vec3 amber = vec3(0.95, 0.62, 0.18);
	vec3 ruby = vec3(0.62, 0.08, 0.12);
	vec3 teal = vec3(0.1, 0.5, 0.55);
	vec3 c = id < 0.3 ? deep : (id < 0.55 ? amber : (id < 0.8 ? ruby : teal));
	float breathe = 0.7 + 0.3 * sin(TIME * 0.9 + id * 6.28);
	c *= breathe * glow;
	float lead = max(smoothstep(0.43, 0.5, abs(fract(u) - 0.5)), smoothstep(0.07, 0.0, abs(fract(r * 4.0) - 0.5) - 0.42) * 0.0);
	lead = max(lead, smoothstep(0.035, 0.0, abs(fract(r * 4.0)) - 0.0) + smoothstep(0.035, 0.0, 1.0 - fract(r * 4.0)));
	float centre = smoothstep(0.17, 0.12, r);
	c = mix(c, vec3(1.0, 0.82, 0.45) * (0.8 + 0.2 * sin(TIME * 1.3)), centre);
	c = mix(c, vec3(0.02, 0.02, 0.03), clamp(lead, 0.0, 1.0) * 0.9);
	float edge = smoothstep(1.0, 0.94, r);
	COLOR = vec4(c, edge);
}
