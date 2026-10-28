class_name SkeletonTemplates
extends RefCounted
## Gabarits de squelette. Les positions sont des fractions de la boîte englobante du modèle normalisé
## (x : gauche-droite, y : bas-haut, z : arrière-avant ; façade = +Z, « gauche » = +X).
## Rôles : root, spine, head, tail, arm_l/arm_r (bras ou pattes avant), leg_l/leg_r (jambes ou pattes arrière), wing_l/wing_r.

const IDS := ["biped", "quadruped", "winged", "serpent", "blob"]

static func label(id: String) -> String:
	return {"biped": "Bipède", "quadruped": "Quadrupède", "winged": "Ailé (bipède + ailes)", "serpent": "Serpent / ver", "blob": "Corps souple (toute forme)"}.get(id, id)

## Un os : [nom, parent, rôle, fx, fy, fz]. Les os finissant par « _l » sont dupliqués en « _r » (fx → 1 − fx).
static func _def(id: String) -> Array:
	match id:
		"quadruped":
			return [
				["hips", "", "root", 0.5, 0.55, 0.28], ["spine", "hips", "spine", 0.5, 0.58, 0.5], ["chest", "spine", "spine", 0.5, 0.62, 0.72],
				["neck", "chest", "head", 0.5, 0.72, 0.86], ["head", "neck", "head", 0.5, 0.78, 0.95],
				["tail1", "hips", "tail", 0.5, 0.55, 0.12], ["tail2", "tail1", "tail", 0.5, 0.5, 0.04],
				["front_upper_l", "chest", "arm_l", 0.72, 0.5, 0.74], ["front_lower_l", "front_upper_l", "arm_l", 0.72, 0.26, 0.74], ["front_foot_l", "front_lower_l", "arm_l", 0.72, 0.04, 0.78],
				["hind_upper_l", "hips", "leg_l", 0.72, 0.5, 0.26], ["hind_lower_l", "hind_upper_l", "leg_l", 0.72, 0.26, 0.26], ["hind_foot_l", "hind_lower_l", "leg_l", 0.72, 0.04, 0.3],
			]
		"blob":
			# Chaîne verticale au centre du corps : convient à toute forme sans membres (œil flottant, gelée, plante, golem rond…).
			return [
				["base", "", "root", 0.5, 0.08, 0.5], ["body1", "base", "body", 0.5, 0.3, 0.5],
				["body2", "body1", "body", 0.5, 0.55, 0.5], ["body3", "body2", "body", 0.5, 0.8, 0.5],
			]
		"serpent":
			var out: Array = []
			var n := 8
			for i in n:
				var t := float(i) / float(n - 1)
				var nm := "seg%d" % i
				var role := "tail" if i < 3 else ("head" if i == n - 1 else "spine")
				out.append([nm, "" if i == 0 else "seg%d" % (i - 1), "root" if i == 0 else role, 0.5, 0.2 + 0.1 * t, 0.06 + 0.88 * t])
			return out
		_:
			var b: Array = [
				["hips", "", "root", 0.5, 0.5, 0.5], ["spine", "hips", "spine", 0.5, 0.6, 0.5], ["chest", "spine", "spine", 0.5, 0.72, 0.5],
				["neck", "chest", "head", 0.5, 0.85, 0.5], ["head", "neck", "head", 0.5, 0.92, 0.52],
				["upper_arm_l", "chest", "arm_l", 0.7, 0.8, 0.5], ["forearm_l", "upper_arm_l", "arm_l", 0.82, 0.62, 0.5], ["hand_l", "forearm_l", "arm_l", 0.9, 0.46, 0.5],
				["thigh_l", "hips", "leg_l", 0.58, 0.48, 0.5], ["shin_l", "thigh_l", "leg_l", 0.58, 0.26, 0.5], ["foot_l", "shin_l", "leg_l", 0.58, 0.04, 0.56],
			]
			if id == "winged":
				b.append(["wing1_l", "chest", "wing_l", 0.7, 0.82, 0.42])
				b.append(["wing2_l", "wing1_l", "wing_l", 0.85, 0.88, 0.38])
				b.append(["wing3_l", "wing2_l", "wing_l", 0.97, 0.92, 0.34])
			return b

## Construit la liste d'os {name, parent, role, pos} pour la boîte `aabb` (os « _l » + miroirs « _r »).
static func build(id: String, aabb: AABB) -> Array:
	var bones: Array = []
	var defs := _def(id)
	for d in defs:
		bones.append(_bone(d, aabb, false))
		if str(d[0]).ends_with("_l"):
			bones.append(_bone(d, aabb, true))
	return _ordered(bones)

static func _mirror_name(s: String) -> String:
	return s.trim_suffix("_l") + "_r" if s.ends_with("_l") else s

static func _bone(d: Array, aabb: AABB, mirror: bool) -> Dictionary:
	var fx: float = d[3]
	if mirror:
		fx = 1.0 - fx
	var p := aabb.position + Vector3(aabb.size.x * fx, aabb.size.y * float(d[4]), aabb.size.z * float(d[5]))
	var nm := str(d[0])
	var par := str(d[1])
	var role := str(d[2])
	if mirror:
		nm = _mirror_name(nm)
		par = _mirror_name(par)
		role = role.trim_suffix("_l") + "_r" if role.ends_with("_l") else role
	return {"name": nm, "parent": par, "role": role, "pos": [p.x, p.y, p.z]}

## Garantit qu'un parent précède toujours ses enfants (exigé par Skeleton3D).
static func _ordered(bones: Array) -> Array:
	var out: Array = []
	var seen := {}
	var guard := 0
	while out.size() < bones.size() and guard < 1000:
		guard += 1
		for b in bones:
			if seen.has(b.name):
				continue
			if str(b.parent) == "" or seen.has(str(b.parent)):
				out.append(b)
				seen[b.name] = true
	return out

static func ordered(bones: Array) -> Array:
	return _ordered(bones)
