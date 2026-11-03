shader_type canvas_item;
render_mode blend_add;
// Lueur de bougie additive, vacillante (somme de sinus : aucun hasard, rejouable).
uniform vec2 center = vec2(0.5, 0.95);
uniform vec4 col : source_color = vec4(1.0, 0.62, 0.25, 1.0);
uniform float radius = 0.6;
uniform float strength = 0.5;
uniform vec2 squash = vec2(1.0, 1.5);
uniform float phase = 0.0;
void fragment() {
	float t = TIME * 6.0 + phase;
	float fl = 0.72 + 0.28 * (sin(t) * 0.5 + sin(t * 2.3 + 1.0) * 0.3 + sin(t * 5.1 + 2.0) * 0.2);
	float d = length((UV - center) * squash);
	float g = smoothstep(radius, 0.0, d);
	COLOR = vec4(col.rgb * g * g * strength * fl, 1.0);
}
