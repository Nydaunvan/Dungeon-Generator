class_name Chest3D
extends Node3D
## Coffre en 3D (modèle « Poor chest big » : caisse de bois cerclée de fer et couvercle séparé, textures PBR). `set_open(true, true)` fait
## basculer le couvercle sur sa charnière (avec un petit rebond), révèle le tas de pièces et lance un éclat doré. Face avant (serrure) =
## +Z local ; le pied est au sol (y = 0). Purement visuel : l'état « ouvert » est tenu par la partie (état de l'objet), pas par ce nœud.
##
## Le fichier FBX contient cinq niveaux de détail du corps (BOT) et du couvercle (TOP) : on garde LOD 1 (de près), LOD 3 et LOD 4
## (de loin), commutés par la distance à la caméra (plages de visibilité), pour rester léger sur le Web.

const MODEL := preload("res://assets/models/chest/chest.fbx")
const LONG_SIDE := 1.4             ## longueur du coffre (m) le long du mur
## Le fichier montre le couvercle dressé à la verticale (rotation 0) : fermé = -90° (rabattu vers l'avant), ouvert = +17° (renversé vers l'arrière).
const CLOSED_ANGLE := -90.0
const OPEN_ANGLE := 17.0
const BODY := "POOR_CHEST_BIG_BOT_VAR_1"
const TOP := "POOR_CHEST_BIG_TOP_VAR_1"
## niveau de détail -> [distance min, distance max] en mètres (0 = sans limite)
const LODS := {1: [0.0, 7.0], 3: [7.0, 16.0], 4: [16.0, 0.0]}

static var _outer: StandardMaterial3D
static var _inner: StandardMaterial3D
static var _glow: StandardMaterial3D
static var _gold: StandardMaterial3D

var is_open := false
var _lid: Node3D
var _coins: MeshInstance3D
var _glow_node: MeshInstance3D
var _tween: Tween

static func _pbr(base: String, normal: String, orm: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(base)
	m.normal_enabled = true
	m.normal_texture = load(normal)
	var t: Texture2D = load(orm)
	m.ao_enabled = true
	m.ao_texture = t
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = t
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = 1.0
	m.metallic_texture = t
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	return m

static func _mats() -> void:
	if _outer != null:
		return
	_outer = _pbr("res://assets/models/chest/chest_base.jpg", "res://assets/models/chest/chest_normal.png", "res://assets/models/chest/chest_orm.png")
	_inner = _pbr("res://assets/models/chest/chest_in_base.jpg", "res://assets/models/chest/chest_in_normal.png", "res://assets/models/chest/chest_in_orm.png")
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(0.95, 0.72, 0.2)
	_gold.metallic = 0.8
	_gold.roughness = 0.35
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.2)
	_gold.emission_energy_multiplier = 0.6
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.albedo_texture = ProceduralTextures.glow()
	_glow.albedo_color = Color(1.0, 0.8, 0.35, 0.8)

## Garde les niveaux de détail utiles d'un groupe (corps ou couvercle), pose les matériaux et les plages de visibilité.
static func _prepare(group: Node3D) -> void:
	for c in group.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var lod := int(str(mi.name).split("_LOD_")[1].substr(0, 1)) if "_LOD_" in str(mi.name) else 0
		if not LODS.has(lod):
			group.remove_child(mi)
			mi.free()
			continue
		mi.set_surface_override_material(0, _inner)
		mi.set_surface_override_material(1, _outer)
		var rng: Array = LODS[lod]
		mi.visibility_range_begin = float(rng[0])
		mi.visibility_range_end = float(rng[1])
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _init() -> void:
	_mats()
	var src: Node3D = MODEL.instantiate()
	var body: Node3D = src.get_node(BODY)
	var top: Node3D = src.get_node(TOP)
	src.remove_child(body)
	src.remove_child(top)
	body.owner = null
	top.owner = null
	_prepare(body)
	_prepare(top)
	# charnière = origine du maillage du couvercle (déjà posé fermé sur le corps dans le fichier)
	var hinge_local: Vector3 = (top.get_child(0) as Node3D).position
	var hinge: Vector3 = top.transform * hinge_local
	# échelle : le grand côté du corps mesure LONG_SIDE ; le modèle est couché sur Z, on le tourne pour que la longueur suive X et la serrure +Z
	var probe := body.get_child(0) as MeshInstance3D
	var box: AABB = body.transform * probe.get_aabb()
	var k := LONG_SIDE / maxf(box.size.x, box.size.z)
	var model := Node3D.new()
	model.name = "Model"
	model.rotation.y = -PI * 0.5
	model.scale = Vector3.ONE * k
	add_child(model)
	# centre du corps au sol (x, z), pied à y = 0
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	var shift := Vector3(-cx, -box.position.y, -cz)
	body.position += shift
	model.add_child(body)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = hinge + shift
	model.add_child(_lid)
	top.position = -hinge
	_lid.add_child(top)
	src.free()
	var body_h := box.size.y * k
	# tas de pièces (caché par le couvercle fermé)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.42
	cm.height = 0.12
	cm.radial_segments = 14
	cm.material = _gold
	_coins = MeshInstance3D.new()
	_coins.mesh = cm
	_coins.position = Vector3(0, body_h * 0.62, 0)
	_coins.scale = Vector3(1.5, 1.0, 0.95)
	_coins.visible = false
	add_child(_coins)
	# éclat doré (apparaît à l'ouverture)
	var gq := QuadMesh.new()
	gq.size = Vector2(1.8, 1.8)
	gq.material = _glow
	_glow_node = MeshInstance3D.new()
	_glow_node.mesh = gq
	_glow_node.position = Vector3(0, body_h + 0.4, 0)
	_glow_node.visible = false
	add_child(_glow_node)
	_lid.rotation.z = deg_to_rad(CLOSED_ANGLE)

## Ouvre ou referme le couvercle. `animate` : bascule en douceur (avec rebond) et éclat doré ; sinon, position finale immédiate.
func set_open(open: bool, animate: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	is_open = open
	var target := deg_to_rad(OPEN_ANGLE if open else CLOSED_ANGLE)
	if not animate:
		_lid.rotation.z = target
		_coins.visible = open
		_glow_node.visible = open
		(_glow_node.mesh as QuadMesh).size = Vector2(1.2, 1.2)
		return
	_coins.visible = open
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:z", target, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if open:
		_glow_node.visible = true
		var gq := _glow_node.mesh as QuadMesh
		gq.size = Vector2(0.3, 0.3)
		_tween.parallel().tween_method(func(s: float): gq.size = Vector2(s, s), 0.3, 2.2, 0.35).set_delay(0.12)
		_tween.tween_method(func(s: float): gq.size = Vector2(s, s), 2.2, 1.2, 0.5)
	else:
		_glow_node.visible = false
