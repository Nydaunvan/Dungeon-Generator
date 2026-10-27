class_name RigBuilder
extends RefCounted
## Assemble la scène d'un monstre : Skeleton3D + maillage lié (poids de peau) + AnimationPlayer.
## C'est aussi ce qui est exporté en .glb.

## Poids calculés pour un modèle et une liste d'os (mis en cache par l'appelant : coûteux).
static func compute_weights(model: Dictionary, bones: Array, tree: SceneTree = null) -> Array:
	var out: Array = []
	for sf in model.surfaces:
		out.append(await Skinning.compute(sf.arrays[Mesh.ARRAY_VERTEX], bones, tree))
	return out

static func build_skeleton(bones: Array) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	var idx := {}
	for b in bones:
		var i := sk.add_bone(str(b.name))
		idx[str(b.name)] = i
		var p := str(b.parent)
		var gp := _gpos(b)
		var local := gp
		if p != "" and idx.has(p):
			sk.set_bone_parent(i, int(idx[p]))
			local = gp - _gpos(bones[int(idx[p])])
		sk.set_bone_rest(i, Transform3D(Basis(), local))
	sk.reset_bone_poses()
	return sk

static func _gpos(b: Dictionary) -> Vector3:
	var p: Array = b.pos
	return Vector3(p[0], p[1], p[2])

## `weights` : sortie de compute_weights (liste parallèle à model.surfaces) ou vide → maillage non lié.
static func build(model: Dictionary, rig: Dictionary, weights: Array, anim_keys: Dictionary = {}, with_anims := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Monster"
	var bones: Array = rig.get("bones", [])
	var mesh := ArrayMesh.new()
	for i in model.surfaces.size():
		var sf: Dictionary = model.surfaces[i]
		var arr: Array = (sf.arrays as Array).duplicate()
		if not bones.is_empty() and i < weights.size():
			arr[Mesh.ARRAY_BONES] = weights[i].bones
			arr[Mesh.ARRAY_WEIGHTS] = weights[i].weights
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat: Material = sf.material
		if mat == null:
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.75, 0.7, 0.62)
			mat = sm
		mesh.surface_set_material(i, mat)
	if bones.is_empty() or weights.is_empty():
		var mi0 := MeshInstance3D.new()
		mi0.name = "Corps"
		mi0.mesh = mesh
		root.add_child(mi0)
		return root
	var sk := build_skeleton(bones)
	root.add_child(sk)
	var mi := MeshInstance3D.new()
	mi.name = "Corps"
	mi.mesh = mesh
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sk.create_skin_from_rest_transforms()
	if with_anims:
		var ap := AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		root.add_child(ap)
		var lib := AnimationLibrary.new()
		for an in AnimPresets.NAMES:
			lib.add_animation(an, AnimPresets.build(bones, an, anim_keys.get(an, {})))
		ap.add_animation_library("", lib)
	return root

## Définit les propriétaires pour que l'export glTF enregistre tout l'arbre.
static func set_owners(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		set_owners(c, owner)
