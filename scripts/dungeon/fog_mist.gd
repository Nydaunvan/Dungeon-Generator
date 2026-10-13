class_name FogMist
extends Node3D
## Masses de brouillard bas qui dérivent lentement dans certains donjons (purement visuel, aucune règle n'en dépend).
## Le choix des niveaux est déterministe (graine de la partie + identifiant du niveau, sans toucher au hasard du jeu) :
## une même partie retrouve son brouillard, et les parties classées se rejouent à l'identique.
## Des bancs de brume (quads face à la caméra, bruit procédural) se déplacent dans les cases praticables autour du joueur ;
## la densité du brouillard de l'environnement « respire » doucement.

const CELL := LevelBuilder.CELL
const SHARE := 30                  # % des niveaux de donjon concernés
const MAX_BANKS := 26
const RADIUS := 7.0                # cases autour du joueur où vivent les bancs
const BASE_DENSITY := 0.035        # densité du brouillard de l'environnement (voir main._apply_outdoor)

static var force: int = -1         # outils : 1 = toujours, 0 = jamais, -1 = règle normale

## Ce niveau a-t-il du brouillard dans cette partie ? Jamais en extérieur ; dépend uniquement de la graine et du niveau.
static func level_has_mist(run_seed: String, level_id: String, outdoor: bool) -> bool:
	if outdoor:
		return false
	if force >= 0:
		return force == 1
	return absi(("%s|mist|%s" % [run_seed, level_id]).hash()) % 100 < SHARE

var grid: DungeonGrid
var env: Environment
var _banks: Array = []             # {node, mat, vel, phase}
var _rng := RandomNumberGenerator.new()
var _t := 0.0
static var _shader: Shader

func setup(g: DungeonGrid, e: Environment, level_id: String, run_seed: String) -> void:
	grid = g
	env = e
	name = "FogMist"
	_rng.seed = absi(("%s|mistfx|%s" % [run_seed, level_id]).hash())
	Settings.changed.connect(_rebuild)
	_rebuild()

func _exit_tree() -> void:
	if Settings.changed.is_connected(_rebuild):
		Settings.changed.disconnect(_rebuild)

func _count() -> int:
	return clampi(roundi(float(MAX_BANKS) * maxf(0.6, float(Settings.opt("particles")))), 0, MAX_BANKS) if float(Settings.opt("particles")) > 0.0 else 0

func _rebuild() -> void:
	var want := _count()
	while _banks.size() > want:
		var b = _banks.pop_back()
		b.node.queue_free()
	while _banks.size() < want:
		_banks.append(_make_bank())
	set_process(want > 0)

func _make_bank() -> Dictionary:
	var node := MeshInstance3D.new()
	var q := QuadMesh.new()
	var w := CELL * _rng.randf_range(0.9, 1.5)       # pas plus larges qu'un couloir : peu de coupures contre les murs
	var h := CELL * _rng.randf_range(0.7, 1.05)
	q.size = Vector2(w, h)
	node.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _get_shader()
	mat.set_shader_parameter("seed", _rng.randf() * 50.0)
	mat.set_shader_parameter("tint", Color(0.52, 0.56, 0.62))
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var ang := _rng.randf() * TAU
	var b := {"node": node, "mat": mat, "h": h, "vel": Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(0.25, 0.6), "phase": _rng.randf() * TAU}
	_place(b, _player_pos())
	return b

func _player_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else Vector3.ZERO

func _walkable_at(p: Vector3) -> bool:
	return grid.is_walkable(roundi(p.x / CELL), roundi(p.z / CELL))

## Place un banc sur une case praticable proche du joueur (essais bornés, déterministes).
func _place(b: Dictionary, around: Vector3) -> void:
	var c := Vector2i(roundi(around.x / CELL), roundi(around.z / CELL))
	for i in 24:
		var x := c.x + _rng.randi_range(-int(RADIUS), int(RADIUS))
		var y := c.y + _rng.randi_range(-int(RADIUS), int(RADIUS))
		if grid.is_walkable(x, y):
			(b.node as Node3D).position = Vector3(x * CELL + _rng.randf_range(-1.0, 1.0), float(b.h) * 0.5 + 0.05, y * CELL + _rng.randf_range(-1.0, 1.0))
			return
	(b.node as Node3D).position = Vector3(around.x, float(b.h) * 0.5 + 0.05, around.z)

func _process(delta: float) -> void:
	var k := Settings.motion_k()
	_t += delta * k
	var pp := _player_pos()
	for b in _banks:
		var n: Node3D = b.node
		var step: Vector3 = (b.vel as Vector3) * delta * k
		var np := n.position + step
		if _walkable_at(np):
			n.position = np
		else:
			b.vel = -(b.vel as Vector3).rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))   # un mur : la brume repart de l'autre côté
		n.position.y = float(b.h) * 0.5 + 0.05 + 0.12 * sin(_t * 0.4 + float(b.phase))
		if n.position.distance_to(pp) > RADIUS * CELL:
			_place(b, pp)
	if env != null:
		env.fog_density = BASE_DENSITY * (1.25 + 0.2 * sin(_t * 0.23))      # le brouillard général épaissit et s'éclaircit

static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(0.34, 0.37, 0.41, 1.0);
uniform float opacity = 0.65;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return s;
}

varying float v_dist;

void vertex() {
	// face à la caméra, mais reste debout (rotation autour de l'axe vertical seulement)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.06;
	float n = fbm(uv * vec2(3.0, 2.0) + vec2(t, -t * 0.6) + seed);
	n = smoothstep(0.25, 0.75, n);
	// bords doux : le banc se fond dans le décor
	vec2 e = (uv - 0.5) * 2.0;
	float edge = 1.0 - smoothstep(0.15, 1.0, length(e));
	// pas de mur de brume collé à l'écran
	float near = smoothstep(1.2, 5.0, v_dist);
	ALBEDO = tint.rgb;
	ALPHA = n * edge * near * opacity;
}
"""
	return _shader
