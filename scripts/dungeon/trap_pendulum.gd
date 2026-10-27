class_name TrapPendulum
extends Node3D
## Piège « hache pendulaire » : une grande hache à double tranchant, suspendue au plafond par une tige, qui balaie le couloir
## d'un mur à l'autre. À chaque extrémité de sa course, la lame s'enfonce dans une fente verticale ménagée dans le mur.
## Repère local : l'origine est au centre de la case, au sol ; le plan d'oscillation est perpendiculaire au sens de marche
## (X = latéral, Y = haut). Le nœud se tourne comme le joueur (`rotation.y = -PI/2 * dir`).
## `lock(side)` : le mécanisme se bloque, la lame reste prise dans la fente de ce côté (piège désactivé).

const CELL := 4.0                    ## largeur de la case : les murs sont à ±2 m
const CEILING := 4.0
const ARM := 2.95                    ## pivot → centre de la tête de hache
const MAX_ANGLE := deg_to_rad(42.0)  ## amplitude : à ce moment la lame est dans la fente
const PERIOD := 3.2                  ## durée d'un aller-retour (s)
const SLIT_W := 0.34                 ## largeur de la fente, dans le sens du couloir
const SLIT_H := 2.1

var t := 0.0
var playing := true
var amp := 1.0                       ## 1 = pleine course ; réduit jusqu'à 0 quand le mécanisme s'arrête
var locked := 0                      ## 0 actif, ±1 bloqué dans la fente de ce côté
var _pivot: Node3D
var _tw: Tween

static var _head_mesh: ArrayMesh
static var _mat_iron: StandardMaterial3D
static var _mat_blade: StandardMaterial3D
static var _mat_dark: StandardMaterial3D


static func make() -> TrapPendulum:
	var p := TrapPendulum.new()
	p.name = "Pendulum"
	p._build()
	return p


func _build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(0.0, CEILING, 0.0)
	add_child(_pivot)
	# support au plafond : platine, boulon et chape
	_box(_pivot, Vector3(0.5, 0.12, 0.5), Vector3(0, 0.0, 0), _iron())
	_cyl(_pivot, 0.13, 0.13, 0.32, Vector3(0, -0.12, 0), Vector3(PI * 0.5, 0, 0), _iron(), 12)   # axe du pivot (horizontal sur Z)
	for sx in [-1, 1]:
		_box(_pivot, Vector3(0.06, 0.34, 0.34), Vector3(sx * 0.14, -0.14, 0), _iron())
	# tige à bagues, de la chape à la tête
	_cyl(_pivot, 0.045, 0.045, ARM - 0.55, Vector3(0, -(ARM - 0.55) * 0.5 - 0.1, 0), Vector3.ZERO, _iron(), 8)
	for i in 5:
		_cyl(_pivot, 0.085, 0.085, 0.07, Vector3(0, -0.45 - i * 0.42, 0), Vector3.ZERO, _iron(), 10)
	# tête de hache
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, -ARM, 0)
	_pivot.add_child(head)
	var hm := MeshInstance3D.new()
	hm.mesh = _head()
	hm.material_override = _blade_mat()
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hm.scale = Vector3(1.15, 1.15, 1.0)
	head.add_child(hm)
	_cyl(head, 0.2, 0.2, 0.2, Vector3.ZERO, Vector3(PI * 0.5, 0, 0), _iron(), 14)          # moyeu
	_cyl(head, 0.0, 0.11, 0.42, Vector3(0, 0.55, 0), Vector3.ZERO, _blade_mat(), 8)       # pointe haute
	_cyl(head, 0.0, 0.11, 0.30, Vector3(0, -0.5, 0), Vector3(PI, 0, 0), _blade_mat(), 8)  # pointe basse
	# fentes dans les deux murs, à hauteur de la lame en bout de course
	var cy := CEILING - ARM * cos(MAX_ANGLE)
	for s in [-1.0, 1.0]:
		_slit(s, cy)
	_apply(0.0)


## Cadre de fer + fond noir d'une fente dans le mur du côté `s` (±1).
func _slit(s: float, cy: float) -> void:
	var w := CELL * 0.5
	var fr := Node3D.new()
	fr.position = Vector3(s * w, cy, 0)
	add_child(fr)
	var inner := _dark()
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(SLIT_W, SLIT_H)
	q.mesh = qm
	q.material_override = inner
	q.rotation.y = -s * PI * 0.5          # la face regarde vers le couloir
	q.position.x = -s * 0.012
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fr.add_child(q)
	var t := 0.07
	var d := 0.09
	_box(fr, Vector3(d, t, SLIT_W + 2.0 * t), Vector3(-s * d * 0.5, SLIT_H * 0.5 + t * 0.5, 0), _iron())
	_box(fr, Vector3(d, t, SLIT_W + 2.0 * t), Vector3(-s * d * 0.5, -SLIT_H * 0.5 - t * 0.5, 0), _iron())
	for sz in [-1.0, 1.0]:
		_box(fr, Vector3(d, SLIT_H, t), Vector3(-s * d * 0.5, 0, sz * (SLIT_W * 0.5 + t * 0.5)), _iron())
	for k in 4:      # rivets
		var ry := -SLIT_H * 0.5 + (k + 0.5) * SLIT_H / 4.0
		for sz in [-1.0, 1.0]:
			_cyl(fr, 0.025, 0.025, 0.03, Vector3(-s * (d + 0.005), ry, sz * (SLIT_W * 0.5 + t * 0.5)), Vector3(0, 0, PI * 0.5), _iron(), 6)


func _process(delta: float) -> void:
	if playing and locked == 0:
		t += delta
		_apply(sin(TAU * t / PERIOD) * amp)


## Angle du pendule : -1 … +1 (fraction de l'amplitude).
func _apply(k: float) -> void:
	if _pivot != null:
		_pivot.rotation.z = -k * MAX_ANGLE


## Désactive le mécanisme : la lame ralentit puis reste coincée dans la fente du côté `side` (±1).
func lock(side: int = 1, animate: bool = true) -> void:
	locked = signi(side) if side != 0 else 1
	playing = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if not animate or not is_inside_tree():
		_apply(float(locked))
		return
	var from := sin(TAU * t / PERIOD) * amp
	_tw = create_tween()
	_tw.tween_method(_apply, from, float(locked), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_method(_apply, float(locked), float(locked) * 0.93, 0.18).set_trans(Tween.TRANS_SINE)     # petit rebond : la lame se cale
	_tw.tween_method(_apply, float(locked) * 0.93, float(locked), 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ maillages

## Tête de hache à double tranchant : deux lames en éventail (tranchant lumineux, dos épais), vue de face dans le plan d'oscillation.
static func _head() -> ArrayMesh:
	if _head_mesh != null:
		return _head_mesh
	# demi-lame droite : [x, y, épaisseur] ; épaisseur 0 = fil du tranchant
	var half: Array = [[0.12, -0.20, 0.07], [0.40, -0.40, 0.06], [0.64, -0.60, 0.0], [0.90, -0.32, 0.0], [0.99, 0.0, 0.0],
		[0.90, 0.32, 0.0], [0.64, 0.60, 0.0], [0.40, 0.40, 0.06], [0.12, 0.20, 0.07]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mirror in [1.0, -1.0]:
		var pts: Array = []
		for p in half:
			pts.append(Vector3(p[0] * mirror, p[1], p[2]))
		var c := Vector3(0.52 * mirror, 0.0, 0.085)
		var n := pts.size()
		for face in [1.0, -1.0]:
			for i in n - 1:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i + 1]
				var tri := [Vector3(c.x, c.y, c.z * face), Vector3(a.x, a.y, a.z * face), Vector3(b.x, b.y, b.z * face)]
				var cols := [Color(0.52, 0.54, 0.60), _edge_col(half[i][2]), _edge_col(half[i + 1][2])]
				if (face * mirror) < 0.0:
					tri.reverse()
					cols.reverse()
				for k in 3:
					st.set_color(cols[k])
					st.add_vertex(tri[k])
		# flancs épais (dos de la lame, entre les points non tranchants)
		for i in n - 1:
			var a2: Vector3 = pts[i]
			var b2: Vector3 = pts[i + 1]
			if a2.z <= 0.0 or b2.z <= 0.0:
				continue
			var q := [Vector3(a2.x, a2.y, a2.z), Vector3(b2.x, b2.y, b2.z), Vector3(b2.x, b2.y, -b2.z), Vector3(a2.x, a2.y, -a2.z)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(Color(0.36, 0.37, 0.41))
				st.add_vertex(q[idx])
	# barre centrale (le manche traverse la tête)
	var bx := 0.13
	var by := 0.26
	var bz := 0.08
	var corners := [Vector3(-bx, -by, -bz), Vector3(bx, -by, -bz), Vector3(bx, by, -bz), Vector3(-bx, by, -bz),
		Vector3(-bx, -by, bz), Vector3(bx, -by, bz), Vector3(bx, by, bz), Vector3(-bx, by, bz)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color(0.42, 0.43, 0.47))
			st.add_vertex(corners[f[idx]])
	st.generate_normals()
	_head_mesh = st.commit()
	return _head_mesh


static func _edge_col(thick: float) -> Color:
	return Color(1.0, 1.0, 1.0) if thick <= 0.0 else Color(0.52, 0.54, 0.60)


static func _blade_mat() -> StandardMaterial3D:
	if _mat_blade == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color.WHITE
		m.metallic = 0.35
		m.roughness = 0.38
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_blade = m
	return _mat_blade


static func _iron() -> StandardMaterial3D:
	if _mat_iron == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.40, 0.40, 0.44)
		m.metallic = 0.3
		m.roughness = 0.55
		_mat_iron = m
	return _mat_iron


static func _dark() -> StandardMaterial3D:
	if _mat_dark == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.0, 0.0, 0.0)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_dark = m
	return _mat_dark


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, rot: Vector3, mat: Material, seg: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
