extends SceneTree
## Recensement des triangles du niveau par type de nœud (pour savoir quoi découper / alléger). Usage : … --script res://tools/prim_census.gd -- 61
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 61
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 1, n, n, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(9.0).timeout
	var m = current_scene
	var guard := 0
	while m.wand.level.is_empty() and guard < 600:
		await create_timer(0.1).timeout
		guard += 1
	await create_timer(2.0).timeout
	var tot := {}
	var cnt := {}
	var stack: Array = [m.level_node]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		var tris := 0
		var key := ""
		if nd is MultiMeshInstance3D and nd.multimesh != null and nd.multimesh.mesh != null:
			var mm: MultiMesh = nd.multimesh
			var t := 0
			for s in mm.mesh.get_surface_count():
				var arr = mm.mesh.surface_get_arrays(s)
				t += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
			tris = t * mm.visible_instance_count if mm.visible_instance_count >= 0 else t * mm.instance_count
			key = "MultiMesh " + str(nd.name) + " (%d inst)" % mm.instance_count
		elif nd is MeshInstance3D and nd.mesh != null and nd.visible:
			var t2 := 0
			for s in nd.mesh.get_surface_count():
				var arr2 = nd.mesh.surface_get_arrays(s)
				t2 += (arr2[Mesh.ARRAY_INDEX].size() if arr2[Mesh.ARRAY_INDEX] != null else arr2[Mesh.ARRAY_VERTEX].size()) / 3
			tris = t2
			key = "Mesh " + str(nd.get_parent().name) + "/" + str(nd.name).rstrip("0123456789@")
		if key != "":
			tot[key] = int(tot.get(key, 0)) + tris
			cnt[key] = int(cnt.get(key, 0)) + 1
		stack.append_array(nd.get_children())
	var keys := tot.keys()
	keys.sort_custom(func(x, y): return tot[x] > tot[y])
	var sum := 0
	for k in tot: sum += tot[k]
	print("TOTAL triangles scène : ", sum)
	for k in keys.slice(0, 14):
		print("%9d  x%-4d %s" % [tot[k], cnt[k], k])
	quit()
