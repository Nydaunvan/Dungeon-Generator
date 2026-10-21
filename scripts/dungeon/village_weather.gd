class_name VillageWeather
extends Node
## Heure et météo du village : cycle jour/nuit (soleil, lune, étoiles, ciel, brume, fenêtres allumées) et pluie.
## Purement visuel : n'utilise ni GameRng ni les entrées enregistrées, donc sans effet sur les rediffusions.
## L'état (heure, météo) est statique : il continue d'un passage à l'autre dans le village.

const DAY_SECONDS := 1200.0        ## durée d'une journée complète en mode automatique (20 min)
const TIME_FIXED := {"dawn": 0.27, "day": 0.5, "dusk": 0.73, "night": 0.0}
const SUN_YAW := -32.0

# clefs de ciel : [heure 0..1, zénith, milieu, horizon, lumière du soleil]
const KEYS := [
	[0.00, Color(0.010, 0.020, 0.070), Color(0.030, 0.050, 0.130), Color(0.060, 0.090, 0.180), Color(0.55, 0.65, 1.00)],
	[0.20, Color(0.010, 0.020, 0.070), Color(0.030, 0.050, 0.130), Color(0.060, 0.090, 0.180), Color(0.55, 0.65, 1.00)],
	[0.26, Color(0.25, 0.30, 0.55), Color(0.80, 0.55, 0.62), Color(1.00, 0.72, 0.50), Color(1.00, 0.62, 0.38)],
	[0.33, Color(0.14, 0.36, 0.78), Color(0.34, 0.58, 0.88), Color(0.75, 0.84, 0.93), Color(1.00, 0.88, 0.70)],
	[0.50, Color(0.10, 0.30, 0.74), Color(0.30, 0.55, 0.88), Color(0.72, 0.82, 0.93), Color(1.00, 0.94, 0.82)],
	[0.67, Color(0.12, 0.32, 0.74), Color(0.34, 0.56, 0.86), Color(0.78, 0.82, 0.88), Color(1.00, 0.90, 0.72)],
	[0.74, Color(0.20, 0.22, 0.50), Color(0.75, 0.40, 0.38), Color(1.00, 0.55, 0.28), Color(1.00, 0.55, 0.30)],
	[0.80, Color(0.05, 0.07, 0.20), Color(0.12, 0.14, 0.30), Color(0.35, 0.25, 0.35), Color(0.70, 0.45, 0.45)],
	[0.88, Color(0.010, 0.020, 0.070), Color(0.030, 0.050, 0.130), Color(0.060, 0.090, 0.180), Color(0.55, 0.65, 1.00)],
	[1.00, Color(0.010, 0.020, 0.070), Color(0.030, 0.050, 0.130), Color(0.060, 0.090, 0.180), Color(0.55, 0.65, 1.00)],
]

static var clock := 0.36           ## heure du jour 0..1 (0 = minuit, 0.5 = midi)
static var rain := 0.0             ## intensité de pluie actuelle 0..1
static var _rain_target := 0.0
static var _rain_timer := 150.0
static var _rng := RandomNumberGenerator.new()

var env: Environment
var sun: DirectionalLight3D
var camera: Camera3D
var torch: Light3D
var _sky: ShaderMaterial
var _drops: GPUParticles3D
var _ground: Array = []
var _splash_t := 0.0

func setup(e: Environment, s: DirectionalLight3D, cam: Camera3D, torch_light: Light3D) -> void:
	name = "VillageWeather"
	env = e
	sun = s
	camera = cam
	torch = torch_light
	var sky: Sky = env.sky
	if sky != null and sky.sky_material is ShaderMaterial:
		_sky = sky.sky_material
	for m in [VillageKit.grass(), VillageKit.dirt(), VillageKit.plaza()]:
		if m is StandardMaterial3D:
			_ground.append(m)
			if not m.has_meta("dry_roughness"):
				m.set_meta("dry_roughness", m.roughness)
				m.set_meta("dry_albedo", m.albedo_color)
	_build_rain()
	_rng.randomize()
	_update(0.0)

func _exit_tree() -> void:
	for m in _ground:
		m.roughness = float(m.get_meta("dry_roughness", 1.0))
		m.albedo_color = m.get_meta("dry_albedo", Color.WHITE)
	var glass := VillageKit.glass_material()
	if glass != null:
		glass.emission_energy_multiplier = 0.12

func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_update(minf(delta, 0.25))

# ------------------------------------------------------------------ état

func _update(delta: float) -> void:
	# heure
	var mode := str(Settings.village_time)
	if mode == "auto" or not TIME_FIXED.has(mode):
		clock = fposmod(clock + delta / DAY_SECONDS, 1.0)
	else:
		var d: float = float(TIME_FIXED[mode]) - clock
		d = fposmod(d + 0.5, 1.0) - 0.5      # chemin le plus court sur le cercle
		clock = fposmod(clock + clampf(d, -delta * 0.12, delta * 0.12), 1.0)
	# météo
	var wmode := str(Settings.village_weather)
	var speed := 1.0 / 25.0
	if wmode == "clear":
		_rain_target = 0.0
		speed = 1.0 / 6.0
	elif wmode == "rain":
		_rain_target = 1.0
		speed = 1.0 / 6.0
	else:
		_rain_timer -= delta
		if _rain_timer <= 0.0:
			if _rain_target < 0.5:
				_rain_target = _rng.randf_range(0.55, 1.0)
				_rain_timer = _rng.randf_range(90.0, 240.0)
			else:
				_rain_target = 0.0
				_rain_timer = _rng.randf_range(150.0, 420.0)
	rain = move_toward(rain, _rain_target, delta * speed)
	_apply()

static func _sample(idx: int, t: float) -> Color:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var w := (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			w = w * w * (3.0 - 2.0 * w)
			return (a[idx] as Color).lerp(b[idx], w)
	return KEYS[0][idx]

static func _grey(c: Color, amount: float, dark: float) -> Color:
	var g := c.get_luminance()
	return c.lerp(Color(g, g, g * 1.04) * dark, amount)

## Hauteur du soleil au-dessus de l'horizon, en degrés (négative la nuit).
static func sun_elevation() -> float:
	return 62.0 * sin((clock - 0.25) * TAU)

## 0 = plein jour, 1 = nuit noire.
static func night_amount() -> float:
	return 1.0 - smoothstep(-6.0, 6.0, sun_elevation())

func _apply() -> void:
	var elev := sun_elevation()
	var w := rain
	var day_w := smoothstep(-3.0, 8.0, elev)
	var moon_w := smoothstep(-3.0, -14.0, elev)
	var night := night_amount()
	var top := _grey(_sample(1, clock), w * 0.8, 0.55)
	var mid := _grey(_sample(2, clock), w * 0.8, 0.62)
	var hor := _grey(_sample(3, clock), w * 0.75, 0.70)
	var sun_col := _sample(4, clock)
	# lumière directionnelle : soleil le jour, lune la nuit (jamais les deux : l'énergie s'annule au changement)
	if sun != null and is_instance_valid(sun):
		if elev > -3.0:
			# l'orientation n'est mise à jour que par paliers : une rotation continue ferait ramper les ombres (texels de la carte d'ombres)
			var want := Vector3(-snappedf(maxf(elev, 1.0), 0.5), snappedf(SUN_YAW + (clock - 0.5) * 140.0, 0.5), 0)
			if want.distance_to(sun.rotation_degrees) > 0.01:
				sun.rotation_degrees = want
			sun.light_color = sun_col
			sun.light_energy = 1.9 * day_w * (1.0 - 0.82 * w)
		else:
			if sun.rotation_degrees.distance_to(Vector3(-42.0, 150.0, 0)) > 0.01:
				sun.rotation_degrees = Vector3(-42.0, 150.0, 0)
			sun.light_color = Color(0.55, 0.68, 1.0)
			sun.light_energy = 0.32 * moon_w * (1.0 - 0.6 * w)
		sun.shadow_opacity = 1.0 - 0.7 * w
	# ciel
	if _sky != null:
		_sky.set_shader_parameter("top_color", top)
		_sky.set_shader_parameter("mid_color", mid)
		_sky.set_shader_parameter("horizon_color", hor)
		_sky.set_shader_parameter("ground_color", hor.darkened(0.45))
		_sky.set_shader_parameter("cloud_cover", lerpf(0.5, 0.92, w))
		_sky.set_shader_parameter("overcast", smoothstep(0.1, 0.7, w))
		var yaw := deg_to_rad(SUN_YAW + (clock - 0.5) * 140.0)
		var el := deg_to_rad(elev)
		_sky.set_shader_parameter("sun_dir", Vector3(sin(yaw) * cos(el), sin(el), cos(yaw) * cos(el)))
		var my := deg_to_rad(150.0)
		var mel := deg_to_rad(42.0)
		_sky.set_shader_parameter("moon_dir", Vector3(sin(my) * cos(mel), sin(mel), cos(my) * cos(mel)))
		_sky.set_shader_parameter("sun_color", sun_col)
		_sky.set_shader_parameter("sun_amount", day_w * (1.0 - w))
		_sky.set_shader_parameter("moon_amount", moon_w * (1.0 - w))
		_sky.set_shader_parameter("star_amount", moon_w * (1.0 - w) * 1.2)
		var lit := Color(1.0, 0.98, 0.95).lerp(sun_col, 0.45)
		var cl := _grey(lit * lerpf(0.10, 1.0, day_w), w * 0.8, 0.55)
		var cs := _grey(Color(0.60, 0.65, 0.74) * lerpf(0.06, 1.0, day_w), w * 0.8, 0.5)
		_sky.set_shader_parameter("cloud_light", cl)
		_sky.set_shader_parameter("cloud_shade", cs)
	# ambiance, brume, exposition
	if env != null:
		env.ambient_light_energy = lerpf(0.75, 2.3, night) * (1.0 - 0.15 * w)
		env.fog_light_color = hor.lerp(mid, 0.25)
		env.fog_density = lerpf(0.0035, 0.0125, w) * lerpf(1.0, 1.4, night)
		env.fog_sun_scatter = 0.25 * (1.0 - w) * day_w
		env.tonemap_exposure = lerpf(1.0, 1.25, night)
	# sol mouillé : plus lisse et plus sombre sous la pluie
	for m in _ground:
		m.roughness = lerpf(float(m.get_meta("dry_roughness", 1.0)), 0.55, w)
		var base: Color = m.get_meta("dry_albedo", Color.WHITE)
		m.albedo_color = base.darkened(0.30 * w)
	# fenêtres chaudes la nuit (et sous un ciel couvert)
	var glass := VillageKit.glass_material()
	if glass != null:
		glass.emission_energy_multiplier = 0.12 + maxf(night, w * 0.35) * 2.6
	# torche du héros : allumée quand il fait nuit
	if torch != null and is_instance_valid(torch):
		torch.visible = night > 0.45
		if torch.visible:
			torch.light_energy = 2.0 * clampf((night - 0.45) / 0.4, 0.0, 1.0)
	# pluie
	if _drops != null:
		_drops.emitting = w > 0.04
		_drops.amount_ratio = clampf(w, 0.05, 1.0)
		if camera != null and is_instance_valid(camera):
			_drops.global_position = camera.global_position + Vector3(0, 9.0, 0)

# ------------------------------------------------------------------ pluie

func _build_rain() -> void:
	_drops = GPUParticles3D.new()
	_drops.name = "Rain"
	var count := int(clampf(float(Settings.opt("particles")), 0.25, 1.0) * 1600.0)
	_drops.amount = count
	_drops.lifetime = 0.9
	_drops.preprocess = 0.9
	_drops.local_coords = false
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drops.visibility_aabb = AABB(Vector3(-16, -14, -16), Vector3(32, 16, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 0.1, 13)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3(0, -4, 0)
	pm.particle_flag_align_y = true
	_drops.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.85, 0.95, 0.38)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	quad.material = mat
	_drops.draw_pass_1 = quad
	_drops.emitting = false
	add_child(_drops)
