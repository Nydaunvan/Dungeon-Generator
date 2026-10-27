class_name ModelIO
extends RefCounted
## Chargement d'un .glb et mise au format du logiciel : toutes les surfaces cuites dans le repère du modèle,
## centré en X/Z, pieds à y = 0, hauteur 2. Façade du monstre = +Z (convention glTF).

const HEIGHT := 2.0

static func load_scene(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
	if doc.append_from_file(abs_path, st) != OK:
		return null
	var n := doc.generate_scene(st)
	return n as Node3D

static func _rel_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

static func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)

## Renvoie {surfaces: [{arrays, material}], aabb: AABB} ou {} si le fichier ne contient aucun maillage.
static func load_normalized(path: String, orient := Vector3.ZERO) -> Dictionary:
	var root := load_scene(path)
	if root == null:
		return {}
	var mis: Array = []
	_meshes(root, mis)
	var rot := Transform3D(Basis.from_euler(orient * PI / 180.0), Vector3.ZERO)
	var surfs: Array = []
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for mi: MeshInstance3D in mis:
		var xf := rot * _rel_xf(mi, root)
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nv := PackedVector3Array()
			nv.resize(v.size())
			for i in v.size():
				var p := xf * v[i]
				nv[i] = p
				lo = lo.min(p)
				hi = hi.max(p)
			arr[Mesh.ARRAY_VERTEX] = nv
			if arr[Mesh.ARRAY_NORMAL] != null:
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				var out := PackedVector3Array()
				out.resize(nn.size())
				for i in nn.size():
					out[i] = (nb * nn[i]).normalized()
				arr[Mesh.ARRAY_NORMAL] = out
			arr[Mesh.ARRAY_TANGENT] = null
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			var mat: Material = mi.get_active_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if arr[Mesh.ARRAY_COLOR] != null:
				# couleurs de sommets (cas de TripoSR) : le matériau les utilise, sinon le modèle s'affiche tout blanc
				if mat == null:
					mat = StandardMaterial3D.new()
				elif mat is BaseMaterial3D:
					mat = mat.duplicate()
				if mat is BaseMaterial3D:
					(mat as BaseMaterial3D).vertex_color_use_as_albedo = true
			surfs.append({"arrays": arr, "material": mat})
	root.free()
	if surfs.is_empty():
		return {}
	var size := hi - lo
	var k := HEIGHT / maxf(size.y, 0.0001)
	var shift := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	for sf in surfs:
		var v2: PackedVector3Array = sf.arrays[Mesh.ARRAY_VERTEX]
		for i in v2.size():
			v2[i] = (v2[i] - shift) * k
		sf.arrays[Mesh.ARRAY_VERTEX] = v2
	var box := AABB(Vector3(-size.x * k * 0.5, 0.0, -size.z * k * 0.5), size * k)
	return {"surfaces": surfs, "aabb": box}

static func vertex_count(model: Dictionary) -> int:
	var n := 0
	for sf in model.get("surfaces", []):
		n += (sf.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n

## Enregistre une scène en .glb (squelette et animations compris).
static func save_glb(root: Node, path: String) -> int:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(root, st)
	if err != OK:
		return err
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	return doc.write_to_filesystem(st, abs_path)
