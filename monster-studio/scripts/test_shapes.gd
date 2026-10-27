class_name TestShapes
extends RefCounted
## Silhouettes 3D simples pour essayer toute la chaîne (squelette, poids, animations, export) sans modèle d'IA.

static func _add(st: SurfaceTool, mesh: Mesh, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot * PI / 180.0).scaled(scale)
	st.append_from(mesh, 0, Transform3D(b, pos))

static func _caps(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m

static func _sph(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m

static func mesh_for(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"quadruped":
			_add(st, _caps(0.32, 1.5), Vector3(0, 1.0, 0), Vector3.ONE, Vector3(90, 0, 0))
			_add(st, _sph(0.3), Vector3(0, 1.25, 0.95))
			for sx in [-0.3, 0.3]:
				for sz in [-0.55, 0.55]:
					_add(st, _caps(0.1, 0.9), Vector3(sx, 0.45, sz))
			_add(st, _caps(0.07, 0.8), Vector3(0, 0.95, -1.0), Vector3.ONE, Vector3(70, 0, 0))
		"serpent":
			for i in 9:
				var t := float(i) / 8.0
				_add(st, _sph(0.3 - 0.18 * t), Vector3(0, 0.3 - 0.0 * t, -1.0 + 2.0 * t))
		_:
			_add(st, _caps(0.32, 1.0), Vector3(0, 1.15, 0))                  # torse
			_add(st, _sph(0.26), Vector3(0, 1.75, 0.05))                     # tête
			for sx in [-0.5, 0.5]:
				_add(st, _caps(0.09, 0.75), Vector3(sx, 1.15, 0))            # bras
				_add(st, _caps(0.12, 0.95), Vector3(sx * 0.45, 0.45, 0))     # jambes
	st.generate_normals()
	return st.commit()

## Écrit la silhouette dans un .glb et renvoie le chemin.
static func write(kind: String, path: String) -> String:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Corps"
	mi.mesh = mesh_for(kind)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.6, 0.45)
	mi.material_override = mat
	root.add_child(mi)
	var err := ModelIO.save_glb(root, path)
	root.free()
	return path if err == OK else ""
