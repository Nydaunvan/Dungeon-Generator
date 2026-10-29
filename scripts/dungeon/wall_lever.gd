class_name WallLever
extends RefCounted
## Interrupteur mural à levier : plaque de fer rivetée fixée au mur, rainure verticale entre deux butées et grand levier à manche de bois
## (tige de fer, collier de laiton, poignée cerclée). Au repos le manche pointe vers le HAUT ; actionné, il bascule vers le BAS.
## Repère local : l'origine est sur la face du mur, +Z va vers le couloir, +Y vers le haut ; le nœud se pose à hauteur d'yeux.

const UP := 0.61         ## inclinaison de l'axe du levier au repos (rad, ≈ 35°) : le manche regarde vers le haut et vers la pièce
const DOWN := 2.53       ## inclinaison une fois actionné (≈ 145°) : le manche regarde vers le bas
const HEIGHT := 1.2      ## hauteur du centre de la plaque au-dessus du sol (m)

static var _mats: Dictionary = {}
static var _texs: Dictionary = {}

## Texture procédurale (bruit) : `kind` « iron » (acier martelé, rayures), « wood » (fil du bois). Albedo + normale + rugosité, générées une fois.
static func _noise_tex(kind: String, normal: bool) -> ImageTexture:
	var key := kind + ("_n" if normal else "")
	if _texs.has(key):
		return _texs[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 7 if kind == "iron" else 21
	n.fractal_octaves = 5
	n.frequency = 0.022 if kind == "iron" else 0.018
	var w := 512
	var img := Image.create(w, w, false, Image.FORMAT_RGB8)
	for y in w:
		for x in w:
			var v: float
			if kind == "iron":
				v = n.get_noise_2d(x, y) * 0.5 + 0.5
				v = 0.42 + v * 0.38 + (0.06 if (x * 7 + y * 13) % 97 < 2 else 0.0)      # grain martelé + fines rayures
			else:
				var fy := n.get_noise_2d(x * 0.18, y * 3.0) * 0.5 + 0.5       # fibres allongées le long du manche (axe y)
				v = 0.34 + fy * 0.5 + n.get_noise_2d(x * 2.0, y * 0.4) * 0.06
			img.set_pixel(x, y, Color(v, v, v))
	if normal:
		img.bump_map_to_normal_map(5.0 if kind == "iron" else 3.0)
	var t := ImageTexture.create_from_image(img)
	_texs[key] = t
	return t

static func _mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match kind:
		"iron":
			m.albedo_color = Color("8c8f9a")
			m.albedo_texture = _noise_tex("iron", false)
			m.normal_enabled = true
			m.normal_texture = _noise_tex("iron", true)
			m.normal_scale = 0.7
			m.metallic = 0.3
			m.roughness = 0.6
			m.roughness_texture = _noise_tex("iron", false)
		"iron_l":
			m.albedo_color = Color("b4b7c2")
			m.albedo_texture = _noise_tex("iron", false)
			m.metallic = 0.35
			m.roughness = 0.45
		"brass":
			m.albedo_color = Color("e0b552")
			m.metallic = 0.5
			m.roughness = 0.34
			m.emission_enabled = true
			m.emission = Color("6b4a14")
			m.emission_energy_multiplier = 0.35
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
		"wood":
			m.albedo_color = Color("b07a42")
			m.albedo_texture = _noise_tex("wood", false)
			m.normal_enabled = true
			m.normal_texture = _noise_tex("wood", true)
			m.normal_scale = 0.8
			m.roughness = 0.72
		"wood_d":
			m.albedo_color = Color("4a3219")
			m.albedo_texture = _noise_tex("wood", false)
			m.roughness = 0.8
		_:
			m.albedo_color = Color("0b0907")
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
	c.radial_segments = 48
	c.rings = 2
	return _add(parent, c, pos, kind, rot)

static func _ball(parent: Node3D, r: float, pos: Vector3, kind: String, flat: float = 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 * flat
	s.radial_segments = 40
	s.rings = 20
	return _add(parent, s, pos, kind)

static func _ring(parent: Node3D, r_in: float, r_out: float, pos: Vector3, kind: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r_in
	t.outer_radius = r_out
	t.rings = 40
	t.ring_segments = 14
	return _add(parent, t, pos, kind, rot)

static func make() -> Node3D:
	var root := Node3D.new()
	root.set_meta("wall_lever", true)
	var rx := Vector3(PI / 2.0, 0, 0)
	# plaque de fer martelé : fond, cadre en relief, liteaux et angles
	_box(root, Vector3(0.36, 1.04, 0.05), Vector3(0, 0, 0.025), "iron")
	_box(root, Vector3(0.30, 0.98, 0.02), Vector3(0, 0, 0.058), "iron")
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.025, 1.0, 0.045), Vector3(sx * 0.165, 0, 0.065), "iron_l")      # montants du cadre
	for sy in [-1.0, 1.0]:
		_box(root, Vector3(0.40, 0.045, 0.07), Vector3(0, sy * 0.52, 0.035), "iron_l")        # liteaux
		_box(root, Vector3(0.33, 0.02, 0.05), Vector3(0, sy * 0.47, 0.07), "iron_l")
	# rivets bombés (dôme + fente) aux quatre angles et au milieu des montants
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 0.0, 1.0]:
			var rp := Vector3(sx * 0.14, sy * 0.44, 0.08)
			_ball(root, 0.026, rp, "brass", 0.6)
			_box(root, Vector3(0.03, 0.006, 0.006), rp + Vector3(0, 0, 0.012), "dark")
	# rainure : fente sombre bordée de deux rails de laiton, butées haute et basse
	_box(root, Vector3(0.07, 0.80, 0.02), Vector3(0, 0, 0.052), "dark")
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.008, 0.80, 0.012), Vector3(sx * 0.04, 0, 0.066), "brass")
	for sy in [-1.0, 1.0]:
		_box(root, Vector3(0.14, 0.05, 0.06), Vector3(0, sy * 0.42, 0.075), "iron_l")
		_ball(root, 0.02, Vector3(0, sy * 0.42, 0.108), "brass", 0.6)
	# flèches gravées (haut / bas) pour lire le sens du levier
	for sy in [-1.0, 1.0]:
		var ap := Vector3(0.0, sy * 0.30, 0.066)
		_box(root, Vector3(0.012, 0.07, 0.006), ap, "dark")
		_box(root, Vector3(0.05, 0.012, 0.006), ap + Vector3(0, sy * 0.045, 0), "dark")
	# moyeu : rondelle, écrou, pivot de laiton
	_cyl(root, 0.095, 0.095, 0.02, Vector3(0, 0, 0.085), "iron_l", rx)
	_cyl(root, 0.075, 0.075, 0.05, Vector3(0, 0, 0.1), "brass", rx)
	_ring(root, 0.052, 0.082, Vector3(0, 0, 0.126), "brass", rx)
	_cyl(root, 0.04, 0.04, 0.03, Vector3(0, 0, 0.135), "iron_l", rx)
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 0, 0.115)
	arm.rotation.x = UP
	root.add_child(arm)
	_cyl(arm, 0.02, 0.028, 0.27, Vector3(0, 0.135, 0), "iron_l")                  # tige d'acier
	_cyl(arm, 0.032, 0.032, 0.02, Vector3(0, 0.04, 0), "brass")                   # bague basse
	_ring(arm, 0.018, 0.034, Vector3(0, 0.275, 0), "brass", Vector3(PI / 2.0, 0, 0))   # collier de laiton
	_cyl(arm, 0.045, 0.045, 0.02, Vector3(0, 0.30, 0), "iron_l")                  # embase du manche
	_cyl(arm, 0.05, 0.036, 0.18, Vector3(0, 0.39, 0), "wood")                     # manche de bois tourné (fil du bois)
	for yy in [0.335, 0.39, 0.445]:
		_ring(arm, 0.044, 0.056, Vector3(0, yy, 0), "wood_d", Vector3(PI / 2.0, 0, 0))      # cerclages gravés
	_ball(arm, 0.058, Vector3(0, 0.49, 0), "wood")                                # pommeau
	_ring(arm, 0.02, 0.05, Vector3(0, 0.455, 0), "brass", Vector3(PI / 2.0, 0, 0))
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
