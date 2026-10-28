class_name WallLever
extends RefCounted
## Interrupteur mural à levier : plaque de fer rivetée fixée au mur, rainure verticale entre deux butées et grand levier à manche de bois
## (tige de fer, collier de laiton, poignée cerclée). Au repos le manche pointe vers le HAUT ; actionné, il bascule vers le BAS.
## Repère local : l'origine est sur la face du mur, +Z va vers le couloir, +Y vers le haut ; le nœud se pose à hauteur d'yeux.

const UP := 0.61         ## inclinaison de l'axe du levier au repos (rad, ≈ 35°) : le manche regarde vers le haut et vers la pièce
const DOWN := 2.53       ## inclinaison une fois actionné (≈ 145°) : le manche regarde vers le bas
const HEIGHT := 1.2      ## hauteur du centre de la plaque au-dessus du sol (m)

static var _mats: Dictionary = {}

static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"iron":
			m.albedo_color = Color("34343a")
			m.metallic = 0.6
			m.roughness = 0.55
		"iron_l":
			m.albedo_color = Color("5a5a62")
			m.metallic = 0.7
			m.roughness = 0.45
		"brass":
			m.albedo_color = Color("b08a30")
			m.metallic = 0.85
			m.roughness = 0.35
		"wood":
			m.albedo_color = Color("7a5430")
			m.roughness = 0.85
		"wood_d":
			m.albedo_color = Color("4a3219")
			m.roughness = 0.9
		_:
			m.albedo_color = Color("0e0b08")
			m.roughness = 1.0
	_mats[kind] = m
	return m

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, kind: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(kind)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, pos: Vector3, kind: String) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, pos, kind)

static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, kind: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return _add(parent, c, pos, kind, rot)

static func _ball(parent: Node3D, r: float, pos: Vector3, kind: String) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return _add(parent, s, pos, kind)

static func make() -> Node3D:
	var root := Node3D.new()
	root.set_meta("wall_lever", true)
	_box(root, Vector3(0.36, 1.04, 0.05), Vector3(0, 0, 0.025), "iron")
	_box(root, Vector3(0.40, 0.04, 0.07), Vector3(0, 0.52, 0.03), "iron_l")      # liteaux de la plaque
	_box(root, Vector3(0.40, 0.04, 0.07), Vector3(0, -0.52, 0.03), "iron_l")
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_cyl(root, 0.022, 0.022, 0.03, Vector3(sx * 0.14, sy * 0.44, 0.065), "brass", Vector3(PI / 2.0, 0, 0))      # rivets
	_box(root, Vector3(0.07, 0.80, 0.02), Vector3(0, 0, 0.052), "dark")           # rainure
	_box(root, Vector3(0.14, 0.05, 0.06), Vector3(0, 0.42, 0.07), "iron_l")       # butées haute et basse
	_box(root, Vector3(0.14, 0.05, 0.06), Vector3(0, -0.42, 0.07), "iron_l")
	_cyl(root, 0.075, 0.075, 0.05, Vector3(0, 0, 0.085), "brass", Vector3(PI / 2.0, 0, 0))      # moyeu
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 0, 0.105)
	arm.rotation.x = UP
	root.add_child(arm)
	_cyl(arm, 0.02, 0.025, 0.26, Vector3(0, 0.13, 0), "iron_l")                  # tige
	_cyl(arm, 0.04, 0.04, 0.04, Vector3(0, 0.27, 0), "brass")                     # collier
	_cyl(arm, 0.05, 0.036, 0.17, Vector3(0, 0.37, 0), "wood")                     # manche de bois
	_cyl(arm, 0.052, 0.052, 0.014, Vector3(0, 0.33, 0), "wood_d")                 # cerclages
	_cyl(arm, 0.047, 0.047, 0.014, Vector3(0, 0.41, 0), "wood_d")
	_ball(arm, 0.056, Vector3(0, 0.47, 0), "wood")                                # pommeau
	return root

## Actionne le levier : le manche bascule vers le bas (immédiat au chargement du niveau).
static func pull(root: Node, animate: bool = true) -> void:
	var arm := root.get_node_or_null("Arm") as Node3D
	if arm == null or root.has_meta("pulled"):
		return
	root.set_meta("pulled", true)
	if not animate or not root.is_inside_tree():
		arm.rotation.x = DOWN
		return
	var tw := arm.create_tween()
	tw.tween_property(arm, "rotation:x", DOWN, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
