class_name Outdoor
extends Node3D
## Décor extérieur du village : herbe, chemins, arbres et nuages qui dérivent (createProceduralTree / spawnClouds du JS).

const SKY := Color("9cc8e8")
static var _cache: Dictionary = {}

static func _noise_material(base: String, dark: String, light: String, count: int, dot: float, repeat: float) -> StandardMaterial3D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(base))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in count:
		var c := Color(dark if rng.randf() < 0.5 else light)
		var x := rng.randi_range(0, 127)
		var y := rng.randi_range(0, 127)
		for dx in int(ceil(dot)):
			for dy in int(ceil(dot)):
				img.set_pixel(mini(127, x + dx), mini(127, y + dy), c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(repeat, repeat, 1)
	m.texture_repeat = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 1.0
	m.metallic_specular = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func grass() -> Material:
	var vg := VillageKit.grass()
	if vg != null:
		return vg
	if not _cache.has("grass"):
		_cache["grass"] = _noise_material("#4a8a3a", "#3d7830", "#5a9a48", 900, 2.0, 2.0)
	return _cache["grass"]

static func path() -> Material:
	var vd := VillageKit.dirt()
	if vd != null:
		return vd
	if not _cache.has("path"):
		_cache["path"] = _noise_material("#9a7a4a", "#8a6a3a", "#ab8a56", 700, 2.0, 1.5)
	return _cache["path"]

## Arbre unique (tronc + 3 massifs de feuillage), 4 surfaces colorées.
static func tree_mesh() -> ArrayMesh:
	var vt := VillageKit.tree_mesh()
	if vt != null:
		return vt
	if _cache.has("tree"):
		return _cache["tree"]
	var mesh := ArrayMesh.new()
	var parts: Array = []
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.13
	trunk.height = 1.1
	trunk.radial_segments = 6
	trunk.rings = 1
	parts.append([trunk, Transform3D(Basis(), Vector3(0, 0.55, 0)), Color("6a4a28")])
	for f in [[0.65, Vector3(0, 1.1, 0), "2f6a2a"], [0.45, Vector3(0.2, 1.3, 0.1), "387a32"], [0.4, Vector3(-0.25, 1.2, -0.15), "285c24"]]:
		var s := SphereMesh.new()
		s.radius = f[0]
		s.height = f[0] * 2.0
		s.radial_segments = 6
		s.rings = 3
		parts.append([s, Transform3D(Basis(), f[1]), Color(f[2])])
	for p in parts:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(p[0], 0, p[1])
		st.generate_normals()
		st.commit(mesh)
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = 1.0
		m.metallic_specular = 0.0
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	_cache["tree"] = mesh
	return mesh

static func cloud_texture() -> Texture2D:
	if _cache.has("cloud"):
		return _cache["cloud"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_cache["cloud"] = t
	return t

## Ciel et lumière du village : ciel procédural (dégradé, soleil, nuages), ambiance tirée du ciel, brume d'horizon légère, rendu « filmique ».
## `on` = false remet l'environnement du donjon (fond uni, lumière ambiante unie, rendu linéaire).
static func apply_environment(env: Environment, on: bool) -> void:
	if not on:
		env.background_mode = Environment.BG_COLOR
		env.sky = null
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
		env.fog_sky_affect = 1.0
		env.fog_aerial_perspective = 0.0
		env.fog_sun_scatter = 0.0
		return
	if not _cache.has("sky"):
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.012
		fn.fractal_octaves = 3
		var img := fn.get_seamless_image(512, 512)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://scripts/dungeon/village_sky.gdshader")
		sm.set_shader_parameter("noise_tex", ImageTexture.create_from_image(img))
		var sky := Sky.new()
		sky.sky_material = sm
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		_cache["sky"] = sky
	env.background_mode = Environment.BG_SKY
	env.sky = _cache["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 5.0
	env.fog_light_color = Color(0.70, 0.80, 0.92)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.fog_sun_scatter = 0.25

## Ajoute arbres et soleil à la vue d'un niveau extérieur.
static func decorate(view: Node3D, level: Dictionary) -> void:
	if view is LevelView and (view as LevelView).grid != null:
		VillageKit.decorate(view, level, (view as LevelView).grid)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.9
	sun.light_angular_distance = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.0
	view.add_child(sun)
	for key in level.get("treeCells", []):
		var p := str(key).split(",")
		var mi := MeshInstance3D.new()
		mi.mesh = tree_mesh()
		mi.position = Vector3(int(p[0]) * LevelBuilder.CELL, 0, int(p[1]) * LevelBuilder.CELL)
		mi.rotation.y = float((int(p[0]) * 7 + int(p[1]) * 13) % 6)
		mi.scale = Vector3.ONE * (1.41 + float((int(p[0]) * 31 + int(p[1]) * 17) % 10) / 10.0 * 0.56)
		view.add_child(mi)


