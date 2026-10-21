shader_type sky;
// Ciel du village : dégradé zénith → horizon, soleil et lune (disques et halos), étoiles, nuages cotonneux qui dérivent lentement.
// Heure et météo : les uniforms sont pilotés par VillageWeather (couleurs, direction du soleil et de la lune, couverture nuageuse).
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_color : source_color = vec3(0.10, 0.30, 0.74);
uniform vec3 mid_color : source_color = vec3(0.30, 0.55, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.82, 0.93);
uniform vec3 ground_color : source_color = vec3(0.38, 0.46, 0.38);
uniform float cloud_cover = 0.52;
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.5);
uniform vec3 moon_dir = vec3(-0.4, -0.6, -0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.94, 0.82);
uniform float sun_amount = 1.0;
uniform float moon_amount = 0.0;
uniform float star_amount = 0.0;
uniform float overcast = 0.0;      // 0 = ciel dégagé, 1 = couvert d'un bord à l'autre (pluie)
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.60, 0.65, 0.74);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

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
	float sd = max(dot(dir, normalize(sun_dir)), 0.0);
	col += sun_color * sun_amount * (smoothstep(0.99955, 0.99985, sd) * 12.0 + pow(sd, 180.0) * 0.8 + pow(sd, 12.0) * 0.22);
	float md = max(dot(dir, normalize(moon_dir)), 0.0);
	col += vec3(0.80, 0.88, 1.0) * moon_amount * (smoothstep(0.9993, 0.99955, md) * 2.4 + pow(md, 220.0) * 0.25 + pow(md, 16.0) * 0.05);
	if (star_amount > 0.01 && h > 0.0) {
		vec3 sp = floor(dir * 120.0);
		float r = hash13(sp);
		float tw = 0.75 + 0.25 * sin(TIME * 2.0 + r * 40.0);
		col += vec3(0.9, 0.93, 1.0) * step(0.9965, r) * star_amount * tw * smoothstep(0.0, 0.15, h) * (AT_CUBEMAP_PASS ? 0.0 : 1.0);
	}
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.28) * 0.85;
		if (!AT_CUBEMAP_PASS) {
			uv += vec2(TIME * 0.0035, TIME * 0.0012);
		}
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, n);
		c = mix(c * smoothstep(0.015, 0.22, h), smoothstep(0.0, 0.03, h), overcast);
		// face éclairée vers le soleil, dessous plus gris
		float lit = mix(clamp(n * 1.6 - 0.55 + sd * 0.35, 0.0, 1.0), clamp(n * 1.1 - 0.15, 0.0, 0.6), overcast);
		vec3 ccol = mix(cloud_shade, cloud_light, lit);
		col = mix(col, ccol, c * mix(0.92, 1.0, overcast));
	}
	COLOR = col;
}
