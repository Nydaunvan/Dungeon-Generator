class_name LevelView
extends Node3D
## Le niveau affiché : mesh statique, torches, portes (ouvrables) et arches d'escalier.

var grid: DungeonGrid
var doors: Dictionary = {}   # id de porte -> Array[MeshInstance3D]
var entities: EntityLayer

func open_door(id: String, instant: bool = false) -> void:
	if grid.opened.has(id):
		return
	grid.opened[id] = true
	for leaf in doors.get(id, []):
		if instant:
			leaf.hide()
			continue
		var t := create_tween()
		t.tween_property(leaf, "position:y", leaf.position.y + LevelBuilder.CELL, 0.9) \
				.set_trans(Tween.TRANS_SINE)
		t.finished.connect(leaf.hide)
