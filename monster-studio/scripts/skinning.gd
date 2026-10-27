class_name Skinning
extends RefCounted
## Poids de peau automatiques : chaque sommet est lié aux (au plus) 4 os dont les segments sont les plus proches.

const POWER := 4.0
const EPS := 0.03

## Segments de chaque os : de sa position à celle de chaque enfant ; un os terminal prolonge la direction de son parent.
static func segments(bones: Array) -> Array:
	var idx := {}
	for i in bones.size():
		idx[str(bones[i].name)] = i
	var kids: Array = []
	for i in bones.size():
		kids.append([])
	for i in bones.size():
		var p := str(bones[i].parent)
		if p != "" and idx.has(p):
			(kids[int(idx[p])] as Array).append(i)
	var segs: Array = []
	for i in bones.size():
		var a := _pos(bones[i])
		var list: Array = []
		for k in kids[i]:
			list.append([a, _pos(bones[k])])
		if list.is_empty():
			var p := str(bones[i].parent)
			var dir := Vector3(0, -0.15, 0)
			if p != "" and idx.has(p):
				dir = (a - _pos(bones[int(idx[p])])) * 0.5
			list.append([a, a + dir])
		segs.append(list)
	return segs

static func _pos(b: Dictionary) -> Vector3:
	var p: Array = b.pos
	return Vector3(p[0], p[1], p[2])

static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.000001 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Renvoie {bones: PackedInt32Array, weights: PackedFloat32Array} (4 valeurs par sommet). `tree` : pour rendre la main de temps en temps.
static func compute(verts: PackedVector3Array, bones: Array, tree: SceneTree = null) -> Dictionary:
	var segs := segments(bones)
	var nb := bones.size()
	var out_b := PackedInt32Array()
	var out_w := PackedFloat32Array()
	out_b.resize(verts.size() * 4)
	out_w.resize(verts.size() * 4)
	var ds := PackedFloat32Array()
	ds.resize(nb)
	for vi in verts.size():
		var p := verts[vi]
		for i in nb:
			var best := INF
			for s in segs[i]:
				var d := _dist_seg(p, s[0], s[1])
				if d < best:
					best = d
			ds[i] = best
		# 4 plus proches
		var top := [-1, -1, -1, -1]
		var topd := [INF, INF, INF, INF]
		for i in nb:
			var d := ds[i]
			for k in 4:
				if d < topd[k]:
					for m in range(3, k, -1):
						topd[m] = topd[m - 1]
						top[m] = top[m - 1]
					topd[k] = d
					top[k] = i
					break
		var sum := 0.0
		var ws := [0.0, 0.0, 0.0, 0.0]
		for k in 4:
			if top[k] >= 0:
				ws[k] = pow(1.0 / (float(topd[k]) + EPS), POWER)
				sum += ws[k]
		for k in 4:
			out_b[vi * 4 + k] = maxi(int(top[k]), 0)
			out_w[vi * 4 + k] = (ws[k] / sum) if sum > 0.0 else (1.0 if k == 0 else 0.0)
		if tree != null and vi % 3000 == 2999:
			await tree.process_frame
	return {"bones": out_b, "weights": out_w}
