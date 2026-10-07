class_name LevelView
extends Node3D
## Le niveau affiché : mesh statique, torches, portes (ouvrables) et arches d'escalier.

var grid: DungeonGrid
var doors: Dictionary = {}   # id de porte -> Array[MeshInstance3D]
var entities: EntityLayer
var torches: TorchLayer
var stage: CombatStage

var opening: Dictionary = {}  # id -> true pendant l'animation : la porte reste infranchissable
var locks: Dictionary = {}   # id de porte -> Sprite3D (cadenas)

## Ouvre une porte / grille : le cadenas disparaît, le vantail remonte toujours vers le haut
## (750 ms, décélération, hauteur CELL × 1,15 — comme updateDoorStates de l'original).
func open_door(id: String, instant: bool = false) -> void:
	if (grid.opened.has(id) or opening.has(id)) and not instant:
		return
	if instant:
		grid.opened[id] = true
	else:
		opening[id] = true
	if locks.has(id) and is_instance_valid(locks[id]):
		(locks[id] as Node3D).hide()
	var dur := 0.75
	if not instant:
		dur = Sound.door_open_length()
		Sound.door_open()
	for leaf in doors.get(id, []):
		if not is_instance_valid(leaf):
			continue
		if instant:
			leaf.hide()
			continue
		var y0: float = LevelBuilder.CELL * 0.5
		var t := create_tween()
		t.tween_property(leaf, "position:y", y0 + LevelBuilder.CELL * 1.15, dur) \
				.set_trans(Tween.TRANS_LINEAR)
		t.finished.connect(leaf.hide)
	if not instant:
		get_tree().create_timer(dur).timeout.connect(func():
			opening.erase(id)
			grid.opened[id] = true)
