class_name DiceRoller
extends SubViewportContainer
## Deux dés 3D qui roulent au survol du sceau « Donjon aléatoire » (portage de l'animation du HTML).

const FACES := {   # position des points (grille 3×3) par face
	1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8],
}
const O := [0.0, 0.18, 0.42, 0.55, 0.68, 0.79, 0.88, 1.0]      # instants
const RP := [0.0, 0.30, 0.68, 0.82, 0.92, 0.97, 0.995, 1.0]    # progression de la rotation
const XP := [0.0, 0.25, 0.60, 0.78, 0.90, 0.96, 0.99, 1.0]     # progression latérale
const Y := [0.0, -1.0, 0.0, -0.55, 0.0, -0.25, 0.0, 0.0]       # hauteur relative
const EASE_OUT := [true, false, true, false, true, false, true]

static var _face_mats: Array = []

var _dice: Array = []   # {pivot, cube, rest: Vector3, x: float, busy: bool, anim: Dictionary}
var _time := 0.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.size = Vector2i(296, 184)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 11.96
	cam.position = Vector3(0, 0, 220.0 / 24.0)
	vp.add_child(cam)
	var rests := [Vector3(0, 90, 0), Vector3(90, 180, 0)]
	for i in 2:
		var pivot := Node3D.new()
		pivot.position = Vector3((-0.73 if i == 0 else 0.73), 0, 0)
		var tilt := Node3D.new()
		tilt.rotation_degrees = Vector3(-24, -30, 0)
		pivot.add_child(tilt)
		var cube := Node3D.new()
		tilt.add_child(cube)
		_build_cube(cube)
		vp.add_child(pivot)
		_dice.append({"pivot": pivot, "cube": cube, "rest": rests[i], "x": 0.0, "busy": false, "anim": {}})
		_apply(_dice[i], rests[i], 0.0, 0.0)

func _build_cube(cube: Node3D) -> void:
	if _face_mats.is_empty():
		for v in range(1, 7):
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = _face_texture(v)
			_face_mats.append(m)
	# (valeur, normale, rotation du quad) : 1 devant, 6 derrière, 3 droite, 4 gauche, 2 dessus, 5 dessous
	var defs := [[1, Vector3(0, 0, 1), Vector3(0, 0, 0)], [6, Vector3(0, 0, -1), Vector3(0, 180, 0)],
		[3, Vector3(1, 0, 0), Vector3(0, 90, 0)], [4, Vector3(-1, 0, 0), Vector3(0, -90, 0)],
		[2, Vector3(0, 1, 0), Vector3(-90, 0, 0)], [5, Vector3(0, -1, 0), Vector3(90, 0, 0)]]
	for d in defs:
		var q := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		q.mesh = mesh
		q.material_override = _face_mats[int(d[0]) - 1]
		q.position = (d[1] as Vector3) * 0.5
		q.rotation_degrees = d[2]
		cube.add_child(q)

static func _face_texture(v: int) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(Vector2(n * 0.35, n * 0.30)) / (n * 0.9)
			var base := Color("f7e8cb").lerp(Color("cdb082"), clampf(d, 0.0, 1.0))
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			if edge < 2:
				base = Color("b9976a")
			img.set_pixel(x, y, base)
	for cell in FACES[v]:
		var c := Vector2((cell % 3) * 0.5 + 0.0, floorf(cell / 3.0) * 0.5) * (n - 26) + Vector2(13, 13)
		for y in range(int(c.y) - 4, int(c.y) + 5):
			for x in range(int(c.x) - 4, int(c.x) + 5):
				if Vector2(x, y).distance_to(c) <= 4.2:
					img.set_pixel(x, y, Color("5e1710"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _apply(d: Dictionary, rot: Vector3, x: float, y: float) -> void:
	(d.cube as Node3D).rotation_degrees = rot
	var p: Node3D = d.pivot
	var base := -0.73 if p == _dice[0].pivot else 0.73 if _dice.size() > 1 else -0.73
	p.position = Vector3(base + x / 24.0, -y / 24.0, 0)

## Lance les deux dés (ignoré pour un dé déjà en mouvement).
func roll() -> void:
	for i in 2:
		var d: Dictionary = _dice[i]
		if d.busy:
			continue
		d.busy = true
		var amp := randf_range(11.0, 17.0) * (1.12 if i == 1 else 1.0)
		var dur := (1500.0 + i * 220.0 + randf_range(0.0, 150.0)) / 1000.0
		var sgn := func(): return -1.0 if randf() < 0.5 else 1.0
		var tx := clampf(float(d.x) + sgn.call() * randf_range(3.0, 9.0), -9.0, 9.0)
		var tot := Vector3(sgn.call(), sgn.call(), sgn.call()) * 90.0
		tot *= Vector3(roundf(randf_range(6, 11)), roundf(randf_range(6, 11)), roundf(randf_range(6, 11)))
		d.anim = {"t": -i * 0.07, "dur": dur, "amp": amp, "tx": tx, "x0": d.x, "from": d.rest, "tot": tot}

func _seg(t: float) -> Array:
	var k := 0
	while k < O.size() - 2 and t > O[k + 1]:
		k += 1
	var u := clampf((t - O[k]) / (O[k + 1] - O[k]), 0.0, 1.0)
	u = 1.0 - (1.0 - u) * (1.0 - u) if EASE_OUT[k] else u * u
	return [k, u]

func _process(delta: float) -> void:
	for d in _dice:
		if not d.busy:
			continue
		var a: Dictionary = d.anim
		a.t = float(a.t) + delta
		var t := clampf(float(a.t) / float(a.dur), 0.0, 1.0)
		if float(a.t) < 0.0:
			continue
		var s := _seg(t)
		var k: int = s[0]
		var u: float = s[1]
		var rp: float = lerpf(RP[k], RP[k + 1], u)
		var xp: float = lerpf(XP[k], XP[k + 1], u)
		var y: float = lerpf(Y[k], Y[k + 1], u) * float(a.amp)
		var rot: Vector3 = (a.from as Vector3) + (a.tot as Vector3) * rp
		var x: float = float(a.x0) + (float(a.tx) - float(a.x0)) * xp
		_apply(d, rot, x, y)
		if t >= 1.0:
			d.busy = false
			d.x = float(a.tx)
			d.rest = Vector3(fposmod(rot.x, 360.0), fposmod(rot.y, 360.0), fposmod(rot.z, 360.0))
