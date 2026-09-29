class_name PlayerRig
extends Node3D
## Caméra + torche du joueur. Déplacement case par case (comme le JS : DIRS / YAW).
## dir : 0 = Nord (-z), 1 = Est (+x), 2 = Sud (+z), 3 = Ouest (-x).

signal moved
signal blocked(x: int, y: int)

const MOVE_TIME := 0.18
const TURN_TIME := 0.16

var grid: DungeonGrid
var gx: int = 0
var gy: int = 0
var dir: int = 0
var camera: Camera3D
var torch: OmniLight3D
var _yaw: float = 0.0
var extra_block: Callable = Callable()   # (x, y) -> bool : case occupée (monstre…)
var _busy: bool = false

func _init() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	torch = OmniLight3D.new()
	torch.light_color = Color("ffb060")
	torch.light_energy = 2.0
	torch.omni_range = LevelBuilder.CELL * 6.0
	torch.omni_attenuation = 1.0
	torch.position = Vector3(0, LevelBuilder.CELL * 0.05, 0)
	add_child(torch)

func place(g: DungeonGrid, x: int, y: int, d: int) -> void:
	grid = g
	gx = x
	gy = y
	dir = posmod(d, 4)
	_yaw = -PI * 0.5 * dir
	position = _cell_pos(gx, gy)
	rotation.y = _yaw

func _cell_pos(x: int, y: int) -> Vector3:
	return Vector3(x * LevelBuilder.CELL, LevelBuilder.CELL * 0.5, y * LevelBuilder.CELL)

## rel : 0 avancer, 1 droite, 2 reculer, 3 gauche (relatif à la direction du regard)
func step(rel: int) -> void:
	if _busy or grid == null:
		return
	var d := posmod(dir + rel, 4)
	var v: Vector2i = DungeonGrid.DIRS[d]
	var nx := gx + v.x
	var ny := gy + v.y
	if not grid.is_walkable(nx, ny) or (extra_block.is_valid() and extra_block.call(nx, ny)):
		blocked.emit(nx, ny)
		return
	gx = nx
	gy = ny
	_busy = true
	var t := create_tween()
	t.tween_property(self, "position", _cell_pos(gx, gy), MOVE_TIME).set_trans(Tween.TRANS_SINE)
	t.finished.connect(_on_step_done)

func turn(right: bool) -> void:
	if _busy or grid == null:
		return
	dir = posmod(dir + (1 if right else -1), 4)
	_yaw += -PI * 0.5 if right else PI * 0.5
	_busy = true
	var t := create_tween()
	t.tween_property(self, "rotation:y", _yaw, TURN_TIME).set_trans(Tween.TRANS_SINE)
	t.finished.connect(_on_step_done)

func _on_step_done() -> void:
	_busy = false
	moved.emit()
