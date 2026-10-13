class_name FogMist
extends Node3D
## Brouillard mouvant dans certains donjons (purement visuel, aucune règle n'en dépend).
## Le choix des niveaux est déterministe (graine de la partie + identifiant du niveau, sans toucher au hasard du jeu) :
## une même partie retrouve son brouillard, et les parties classées se rejouent à l'identique.
## Forward+ : vrai brouillard VOLUMÉTRIQUE (un volume de brume bas qui dérive, éclairé par les torches et le groupe) ; la résolution
## du volume suit le niveau graphique. Repli OpenGL : seule la densité du brouillard général « respire » (pas de carrés de brume).

const CELL := LevelBuilder.CELL
const SHARE := 30                  # % des niveaux de donjon concernés
const BASE_DENSITY := 0.035        # densité du brouillard de l'environnement (voir main._apply_outdoor)
const HEIGHT := 2.8                # hauteur de la nappe (le sol en haut du volume s'éclaircit)

static var force: int = -1         # outils : 1 = toujours, 0 = jamais, -1 = règle normale
static var _shader: Shader
static var _noise: NoiseTexture3D

## Ce niveau a-t-il du brouillard dans cette partie ? Jamais en extérieur ; dépend uniquement de la graine et du niveau.
static func level_has_mist(run_seed: String, level_id: String, outdoor: bool) -> bool:
	if outdoor:
		return false
	if force >= 0:
		return force == 1
	return absi(("%s|mist|%s" % [run_seed, level_id]).hash()) % 100 < SHARE

var grid: DungeonGrid
var env: Environment
var volume: FogVolume
var _t := 0.0

func setup(g: DungeonGrid, e: Environment, _level_id: String, _run_seed: String) -> void:
	grid = g
	env = e
	name = "FogMist"
	if VisualFx.is_forward() and bool(Settings.opt("fx_volfog")):
		_build_volume()
	Settings.changed.connect(_on_quality)

func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_quality):
		Settings.changed.disconnect(_on_quality)
	# le niveau suivant a pu reprendre l'environnement avant la libération de celui-ci : on ne coupe que ce qui nous appartient
	if env != null and env.has_meta("mist_owner") and int(env.get_meta("mist_owner")) == get_instance_id():
		env.volumetric_fog_enabled = false
		env.remove_meta("mist_owner")

func _on_quality() -> void:
	var want: bool = VisualFx.is_forward() and bool(Settings.opt("fx_volfog"))
	if want and volume == null:
		_build_volume()
	elif not want and volume != null:
		volume.queue_free()
		volume = null
		env.volumetric_fog_enabled = false
	elif want:
		VisualFx.apply_volumetric_quality()

func _build_volume() -> void:
	env.set_meta("mist_owner", get_instance_id())
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0                         # seul le volume de brume ci-dessous épaissit l'air
	env.volumetric_fog_albedo = Color(0.62, 0.66, 0.72)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_anisotropy = 0.35                     # la lumière traverse la brume vers l'avant : halos autour des torches
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85
	VisualFx.apply_volumetric_quality()
	volume = FogVolume.new()
	volume.name = "MistVolume"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = Vector3(float(grid.width) * CELL, HEIGHT, float(grid.height) * CELL)
	volume.position = Vector3(float(grid.width - 1) * CELL * 0.5, HEIGHT * 0.5, float(grid.height - 1) * CELL * 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("noise", _get_noise())
	volume.material = mat
	add_child(volume)

func _process(delta: float) -> void:
	_t += delta * Settings.motion_k()
	if env != null:
		env.fog_density = BASE_DENSITY * (1.25 + 0.2 * sin(_t * 0.23))      # le brouillard général épaissit et s'éclaircit

static func _get_noise() -> NoiseTexture3D:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 3
		_noise = NoiseTexture3D.new()
		_noise.noise = n
		_noise.width = 64
		_noise.height = 32
		_noise.depth = 64
		_noise.seamless = true
		_noise.normalize = true
	return _noise

## Shader de volume : nappe de brume basse, découpée par un bruit 3D qui défile lentement (dérive) et qui évolue.
static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type fog;
uniform sampler3D noise : repeat_enable, filter_linear;
uniform float density = 0.9;
uniform vec3 tint : source_color = vec3(0.62, 0.66, 0.72);
uniform float top = 2.6;

void fog() {
	vec3 p = WORLD_POSITION * vec3(0.030, 0.050, 0.030) + vec3(TIME * 0.012, TIME * 0.004, TIME * 0.009);
	float n = texture(noise, p).r;
	float mass = smoothstep(0.36, 0.78, n);
	float low = 1.0 - smoothstep(0.0, top, WORLD_POSITION.y);
	DENSITY = mass * (0.35 + 0.65 * low) * density;
	ALBEDO = tint;
}
"""
	return _shader
