shader_type canvas_item;
render_mode blend_add;
// Faisceaux de lumière obliques qui balayent lentement la fenêtre (lumière traversant un vitrail).
uniform vec4 col : source_color = vec4(0.75, 0.82, 1.0, 1.0);
uniform float strength = 0.25;
void fragment() {
	float x = UV.x + UV.y * 0.55 - TIME * 0.018;
	float b = sin(x * 11.0) * 0.5 + sin(x * 4.3 + 1.7) * 0.5;
	b = smoothstep(0.35, 1.0, b);
	float fade = smoothstep(1.0, 0.0, UV.y) * 0.9 + 0.1;
	float pulse = 0.75 + 0.25 * sin(TIME * 0.6);
	COLOR = vec4(col.rgb * b * fade * pulse * strength, 1.0);
}
