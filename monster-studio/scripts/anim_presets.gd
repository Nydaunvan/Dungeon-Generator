class_name AnimPresets
extends RefCounted
## Animations procédurales selon le rôle des os (repos, marche, attaque, coup reçu, mort), plus les clés posées à la main.
## Convention : un os pend le long de -Y ; une rotation autour de +X le fait aller vers l'arrière, donc « avant » = X négatif.
## Les repères sont ceux du monde (tous les os ont une pose de repos sans rotation).

const NAMES := ["idle", "walk", "attack", "hit", "death"]
const LOOPS := {"idle": true, "walk": true, "attack": false, "hit": false, "death": false}
const LENGTHS := {"idle": 2.0, "walk": 1.0, "attack": 0.9, "hit": 0.6, "death": 1.4}

static func label(n: String) -> String:
	return {"idle": "Repos", "walk": "Marche", "attack": "Attaque", "hit": "Coup reçu", "death": "Mort"}.get(n, n)

static func _quat(deg: Vector3) -> Quaternion:
	return Quaternion.from_euler(deg * PI / 180.0)

static func _pos(b: Dictionary) -> Vector3:
	var p: Array = b.pos
	return Vector3(p[0], p[1], p[2])

## Enveloppe douce passant par les points (t, valeur) — interpolation cosinus.
static func _env(u: float, pts: Array) -> float:
	if u <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		var t0: float = pts[i - 1][0]
		var t1: float = pts[i][0]
		if u <= t1:
			var k := (u - t0) / maxf(t1 - t0, 0.0001)
			k = (1.0 - cos(k * PI)) * 0.5
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), k)
	return float(pts[pts.size() - 1][1])

## Rotation (degrés, repères monde) d'un os à l'instant normalisé u (0..1) de l'animation `anim`.
## `rank` : rang de l'os parmi ceux de même rôle (déphase les chaînes : queue, ailes, serpent).
static func _rot(anim: String, role: String, bone: String, rank: int, u: float) -> Vector3:
	var ph := TAU * u
	var side := 1.0 if role.ends_with("_l") else -1.0
	var base := role.trim_suffix("_l").trim_suffix("_r")
	var r := Vector3.ZERO
	match anim:
		"idle":
			match base:
				"spine":
					r.x = 1.5 * sin(ph - 0.4 * rank)
				"head":
					r.x = 2.0 * sin(ph - 1.0)
					r.y = 3.0 * sin(ph)
				"tail":
					r.y = 9.0 * sin(ph + 0.8 * rank)
				"arm":
					r.z = side * -(3.0 + 1.5 * sin(ph - 0.5 * rank))
					r.x = -2.0 * sin(ph + 0.5 * rank)
				"wing":
					r.z = side * -(6.0 + 6.0 * sin(ph + 0.6 * rank))
		"walk":
			match base:
				"leg":
					var s := sin(ph if side > 0.0 else ph + PI)
					if rank == 0:
						r.x = -32.0 * s
					elif rank == 1:
						r.x = 40.0 * maxf(0.0, sin((ph if side > 0.0 else ph + PI) + 1.2))
					else:
						r.x = 12.0 * s
				"arm":
					var s2 := sin(ph + PI if side > 0.0 else ph)
					if rank == 0:
						r.x = -22.0 * s2
					elif rank == 1:
						r.x = -18.0 * maxf(0.0, s2)
					else:
						r.x = 8.0 * s2
				"spine":
					r.y = 5.0 * sin(ph - 0.5 * rank)
					r.z = 2.0 * sin(ph)
				"head":
					r.y = -3.0 * sin(ph)
				"tail":
					r.y = 14.0 * sin(ph + 0.8 * rank)
				"wing":
					r.z = side * -(8.0 + 8.0 * sin(2.0 * ph + 0.5 * rank))
		"attack":
			# e : armement (+1, bras en arrière/en haut) puis frappe (-0,6, bras vers l'avant) ; g : élan du corps (0 → 1 au moment du coup).
			var e := _env(u, [[0.0, 0.0], [0.35, 1.0], [0.5, -0.6], [0.75, -0.25], [1.0, 0.0]])
			var g := _env(u, [[0.0, 0.0], [0.35, -0.3], [0.5, 1.0], [0.75, 0.4], [1.0, 0.0]])
			match base:
				"spine":
					r.x = -8.0 * e
					r.y = 12.0 * e * (1.0 if rank == 0 else 0.6)
				"head":
					r.x = -5.0 * e
				"arm":
					if side < 0.0:       # bras qui frappe (côté droit) : armer puis abattre, avant-bras et main suivent
						r.x = 105.0 * e * (1.0 if rank == 0 else (0.55 if rank == 1 else 0.3))
						r.z = 10.0 * e
					else:                # bras libre : léger contrepoids
						r.x = -14.0 * e * (1.0 if rank == 0 else 0.4)
				"leg":
					if rank == 0:
						r.x = -9.0 * g if side > 0.0 else 7.0 * g
				"tail":
					r.y = 24.0 * e * (1.0 + 0.3 * rank)
				"wing":
					r.z = side * -(10.0 + 25.0 * absf(e))
		"hit":
			var h := _env(u, [[0.0, 0.0], [0.2, 1.0], [0.5, 0.35], [1.0, 0.0]])
			match base:
				"spine":
					r.x = 16.0 * h
				"head":
					r.x = 24.0 * h
					r.y = 12.0 * h
				"arm":
					r.x = 22.0 * h if rank == 0 else 8.0 * h
				"leg":
					r.x = -6.0 * h if rank == 0 else 0.0
				"tail":
					r.y = -18.0 * h
				"wing":
					r.z = side * -(15.0 * h)
		"death":
			var d := _env(u, [[0.0, 0.0], [0.45, 0.55], [1.0, 1.0]])
			match base:
				"root":
					r.z = 90.0 * d
				"head":
					r.x = 25.0 * d
				"arm":
					r.z = side * -20.0 * d
					r.x = 10.0 * d
				"leg":
					r.x = -8.0 * d
				"tail":
					r.y = 15.0 * d
				"wing":
					r.z = side * -(20.0 * d)
	if role == "root":
		return r if anim == "death" else Vector3.ZERO
	return r

## Décalage de position de l'os racine (en unités du modèle, hauteur 2).
static func _root_offset(anim: String, u: float, rest: Vector3) -> Vector3:
	var ph := TAU * u
	match anim:
		"idle":
			return Vector3(0, 0.012 * sin(ph), 0)
		"walk":
			return Vector3(0, 0.035 * absf(sin(ph)), 0)
		"attack":
			return Vector3(0, 0, 0.12 * _env(u, [[0.0, 0.0], [0.35, -0.3], [0.5, 1.0], [0.75, 0.4], [1.0, 0.0]]))
		"hit":
			return Vector3(0, 0, -0.1 * _env(u, [[0.0, 0.0], [0.2, 1.0], [0.5, 0.3], [1.0, 0.0]]))
		"death":
			var d := _env(u, [[0.0, 0.0], [0.45, 0.55], [1.0, 1.0]])
			return Vector3(0, -(rest.y - 0.16) * d, 0)
	return Vector3.ZERO

## Construit l'animation `anim` pour les os de `bones` (liste {name,parent,role,pos}). `custom` : {os: [[t, [x,y,z]], …]} remplace la piste de l'os.
static func build(bones: Array, anim: String, custom: Dictionary = {}) -> Animation:
	var a := Animation.new()
	a.length = float(LENGTHS.get(anim, 1.0))
	a.loop_mode = Animation.LOOP_LINEAR if bool(LOOPS.get(anim, false)) else Animation.LOOP_NONE
	var samples := 16 if anim in ["idle", "walk"] else 12
	var ranks := {}
	var counts := {}
	for b0 in bones:
		counts[str(b0.role)] = int(counts.get(str(b0.role), 0)) + 1
	var idx := {}
	for i in bones.size():
		idx[str(bones[i].name)] = i
	for b in bones:
		var nm := str(b.name)
		var role := str(b.role)
		var rank := int(ranks.get(role, 0))
		ranks[role] = rank + 1
		var path := NodePath("Skeleton3D:" + nm)
		var tr := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, path)
		if custom.has(nm) and not (custom[nm] as Array).is_empty():
			var keys: Array = (custom[nm] as Array).duplicate()
			keys.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
			for k in keys:
				var v: Array = k[1]
				a.rotation_track_insert_key(tr, clampf(float(k[0]), 0.0, a.length), _quat(Vector3(v[0], v[1], v[2])))
		else:
			for i in samples + 1:
				var u := float(i) / float(samples)
				var rv := _rot(anim, role, nm, rank, u)
				var cnt := int(counts.get(role, 1))
				if cnt > 3 and role in ["spine", "tail"]:
					rv *= 3.0 / float(cnt)          # longue chaîne (serpent) : l'amplitude se répartit sur les maillons
				a.rotation_track_insert_key(tr, u * a.length, _quat(rv))
		if role == "root":
			var pt := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(pt, path)
			var parent_pos := Vector3.ZERO
			var rest := _pos(b)
			for i in samples + 1:
				var u2 := float(i) / float(samples)
				a.position_track_insert_key(pt, u2 * a.length, rest - parent_pos + _root_offset(anim, u2, rest))
	return a
