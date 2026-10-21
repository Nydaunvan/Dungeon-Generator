shader_type sky;
// Ciel du village : dégradé zénith → horizon, soleil (disque et halo) et nuages cotonneux qui dérivent lentement.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_color : source_color = vec3(0.10, 0.30, 0.74);
uniform vec3 mid_color : source_color = vec3(0.30, 0.55, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.93);
uniform vec3 ground_color : source_color = vec3(0.38, 0.46, 0.38);
uniform float cloud_cover = 0.52;

float fbm(vec2 uv) {
	return texture(noise_tex, uv).r * 0.55 + texture(noise_tex, uv * 2.17 + 3.1).r * 0.30 + texture(noise_tex, uv * 4.7 + 7.7).r * 0.15;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.5);
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.45, t));
		col = mix(col, top_color, smoothstep(0.35, 1.0, t));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	float sd = max(dot(dir, LIGHT0_DIRECTION), 0.0);
	vec3 sun_col = LIGHT0_COLOR * 1.0;
	col += sun_col * (smoothstep(0.99955, 0.99985, sd) * 12.0 + pow(sd, 180.0) * 0.8 + pow(sd, 12.0) * 0.22);
	if (h > 0.015) {
		vec2 uv = dir.xz / (h + 0.28) * 0.85;
		if (!AT_CUBEMAP_PASS) {
			uv += vec2(TIME * 0.0035, TIME * 0.0012);
		}
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
		c *= smoothstep(0.015, 0.22, h);
		// face éclairée vers le soleil, dessous plus gris
		float lit = clamp(n * 1.6 - 0.55 + sd * 0.35, 0.0, 1.0);
		vec3 ccol = mix(vec3(0.60, 0.65, 0.74), vec3(1.0, 0.98, 0.95), lit);
		col = mix(col, ccol, c * 0.92);
	}
	COLOR = col;
}
