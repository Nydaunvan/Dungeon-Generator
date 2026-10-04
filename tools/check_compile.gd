extends Node
## Charge tous les scripts du jeu avec les autoloads actifs : godot --headless res://tools/check_compile.tscn
func _ready() -> void:
	var n := 0
	var stack := ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				n += 1
				if s == null:
					print("ECHEC ", d, "/", f)
	print("scripts chargés : ", n)
	get_tree().quit()
