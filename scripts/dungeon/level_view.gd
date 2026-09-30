class_name LevelView
extends Node3D
## Le niveau affiché : mesh statique, torches, portes (ouvrables) et arches d'escalier.

var grid: DungeonGrid
var doors: Dictionary = {}   # id de porte -> Array[MeshInstance3D]
var entities: EntityLayer
var stage: CombatStage

var locks: Dictionary = {}   # id de porte -> Sprite3D (cadenas)

## Ouvre une porte / grille : le cadenas disparaît, le vantail remonte toujours vers le haut
## (750 ms, décélération, hauteur CELL × 1,15 — comme updateDoorStates de l'original).
func open_door(id: String, instant: bool = false) -> void:
	if grid.opened.has(id) and not instant:
		return
	grid.opened[id] = true
	if locks.has(id) and is_instance_valid(locks[id]):
		(locks[id] as Node3D).hide()
	for leaf in doors.get(id, []):
		if not is_instance_valid(leaf):
			continue
		if instant:
			leaf.hide()
			continue
		var y0: float = LevelBuilder.CELL * 0.5
		var t := create_tween()
		t.tween_property(leaf, "position:y", y0 + LevelBuilder.CELL * 1.15, 0.75) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.finished.connect(leaf.hide)
