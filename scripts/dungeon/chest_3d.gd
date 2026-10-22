class_name Chest3D
extends Node3D
## Coffre en 3D dessiné par code : caisse de bois cerclée de fer, couvercle sur charnière, serrure dorée. `set_open(true, true)` fait
## basculer le couvercle (avec un petit rebond), révèle le tas de pièces et lance un éclat doré. Face avant = +Z local ; le pied est
## au sol (y = 0). Purement visuel : l'état « ouvert » est tenu par la partie (état de l'objet), pas par ce nœud.

const W := 1.5
const D := 0.95
const BODY_H := 0.62
const OPEN_ANGLE := -112.0         ## degrés (rotation autour de X : l'avant du couvercle monte)

static var _wood: StandardMaterial3D
static var _iron: StandardMaterial3D
static var _gold: StandardMaterial3D
static var _glow: StandardMaterial3D

var is_open := false
var _lid: Node3D
var _coins: MeshInstance3D
var _glow_node: MeshInstance3D
var _tween: Tween

static func _mats() -> void:
	if _wood != null:
		return
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.35
	for y in 64:
		for x in 64:
			var plank := (x / 16) % 4                       # quatre planches verticales
			var base := 0.34 + 0.05 * float(plank % 2)
			var n := noise.get_noise_2d(float(x) * 0.4, float(y) * 2.2) * 0.07
			var seam := 0.0 if (x % 16) > 0 else -0.12      # joint entre planches
			var v := clampf(base + n + seam, 0.1, 0.6)
			img.set_pixel(x, y, Color(v * 1.05, v * 0.66, v * 0.34))
	_wood = StandardMaterial3D.new()
	_wood.albedo_texture = ImageTexture.create_from_image(img)
	_wood.roughness = 0.9
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.13, 0.12, 0.12)
	_iron.metallic = 0.7
	_iron.roughness = 0.45
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

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi

func _init() -> void:
	_mats()
	# caisse
	_box(self, Vector3(W, BODY_H, D), Vector3(0, BODY_H * 0.5, 0), _wood)
	for sx in [-0.5, 0.5]:
		_box(self, Vector3(0.13, BODY_H + 0.02, D + 0.04), Vector3(sx, BODY_H * 0.5, 0), _iron)
	_box(self, Vector3(W + 0.04, 0.1, D + 0.04), Vector3(0, 0.05, 0), _iron)          # soubassement
	# tas de pièces (caché par le couvercle fermé)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.52
	cm.bottom_radius = 0.55
	cm.height = 0.04
	cm.radial_segments = 14
	cm.material = _gold
	_coins = MeshInstance3D.new()
	_coins.mesh = cm
	_coins.position = Vector3(0, BODY_H + 0.012, 0)
	_coins.scale = Vector3(1.2, 1.0, 0.8)
	_coins.visible = false
	add_child(_coins)
	# couvercle sur charnière (arrière)
	_lid = Node3D.new()
	_lid.position = Vector3(0, BODY_H + 0.04, -D * 0.5)
	add_child(_lid)
	_box(_lid, Vector3(W, 0.2, D), Vector3(0, 0.1, D * 0.5), _wood)
	_box(_lid, Vector3(W - 0.14, 0.12, D - 0.12), Vector3(0, 0.25, D * 0.5), _wood)
	for sx in [-0.5, 0.5]:
		_box(_lid, Vector3(0.13, 0.22, D + 0.04), Vector3(sx, 0.11, D * 0.5), _iron)
		_box(_lid, Vector3(0.13, 0.14, D - 0.1), Vector3(sx, 0.25, D * 0.5), _iron)
	_box(_lid, Vector3(0.2, 0.22, 0.06), Vector3(0, 0.0, D + 0.02), _gold)           # serrure
	# éclat doré (apparaît à l'ouverture)
	var gq := QuadMesh.new()
	gq.size = Vector2(1.8, 1.8)
	gq.material = _glow
	_glow_node = MeshInstance3D.new()
	_glow_node.mesh = gq
	_glow_node.position = Vector3(0, BODY_H + 0.45, 0)
	_glow_node.visible = false
	add_child(_glow_node)

## Ouvre ou referme le couvercle. `animate` : bascule en douceur (avec rebond) et éclat doré ; sinon, position finale immédiate.
func set_open(open: bool, animate: bool = false) -> void:
	if _tween != null:
		_tween.kill()
	is_open = open
	var target := deg_to_rad(OPEN_ANGLE) if open else 0.0
	if not animate:
		_lid.rotation.x = target
		_coins.visible = open
		_glow_node.visible = open
		(_glow_node.mesh as QuadMesh).size = Vector2(1.2, 1.2)
		return
	_coins.visible = open
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", target, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if open:
		_glow_node.visible = true
		var gq := _glow_node.mesh as QuadMesh
		gq.size = Vector2(0.3, 0.3)
		_tween.parallel().tween_method(func(s: float): gq.size = Vector2(s, s), 0.3, 2.2, 0.35).set_delay(0.12)
		_tween.tween_method(func(s: float): gq.size = Vector2(s, s), 2.2, 1.2, 0.5)
	else:
		_glow_node.visible = false
