extends SceneTree
## Affiche la structure des modèles de maisons du village (surfaces, matériaux, dimensions).
func _walk(n: Node, depth: int) -> void:
	var s := "  ".repeat(depth) + n.name + " (" + n.get_class() + ")"
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var bb := mi.get_aabb()
		s += " aabb pos %s size %s surfaces %d" % [str(bb.position), str(bb.size), mi.mesh.get_surface_count()]
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			s += "\n" + "  ".repeat(depth + 1) + "surf %d : %s %s" % [i, m.resource_name if m != null else "-", str((m as StandardMaterial3D).albedo_texture) if m is StandardMaterial3D else ""]
	print(s)
	for c in n.get_children():
		_walk(c, depth + 1)
func _init() -> void:
	for p in ["res://assets/village_models/maison_brique.fbx", "res://assets/village_models/maison_beton.fbx"]:
		print("=== ", p)
		var sc: PackedScene = load(p)
		if sc == null:
			print("échec")
			continue
		var n := sc.instantiate()
		_walk(n, 0)
	quit()
