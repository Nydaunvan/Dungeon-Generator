class_name TorchLayer
extends Node3D
## Torches murales : bougeoir illustré + flamme et halo animés (billboards additifs), comme le JS.

const SHEET := "res://assets/sheets/wall_torches.webp"
const SHEET_COUNT := 5
const THEME_MODEL := {"stone": 0, "dirt": 1, "damp": 2, "ruins": 3, "ice": 2, "lava": 0, "temple": 4}
const FLAME_ANCHOR := [Vector2(0.088, 0.273), Vector2(0.063, 0.273), Vector2(0.085, 0.273),
	Vector2(0.092, 0.273), Vector2(0.088, 0.234)]

var _flames: Array = []
var _time: float = 0.0
static var _bowl_mats: Dictionary = {}

func add_torch(pos: Vector3, rot: float, theme: String) -> void:
	var cfg: Dictionary = Data.constants.get("CANDELABRA_THEME", {})
	var c: Dictionary = cfg.get(theme, cfg.get("stone", {}))
	var idx: int = THEME_MODEL.get(theme, 0)
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	# décalage latéral exprimé dans le repère du mur (même rotation que le JS)
	var side := func(x: float, y: float) -> Vector3:
		return Vector3(x * cos(rot), y, -x * sin(rot))
	# bougeoir (sprite ancré près du bas)
	var bowl := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.36, 0.36)
	bowl.mesh = q
	bowl.material_override = _bowl_material(idx)
	bowl.position = side.call(0.09, -0.04 + (0.5 - 0.08) * 0.36)
	root.add_child(bowl)
	# flamme + halo
	var anchor: Vector2 = FLAME_ANCHOR[idx]
	var group := Node3D.new()
	group.position = side.call(anchor.x, anchor.y)
	root.add_child(group)
	var glow := _billboard(ProceduralTextures.glow(), Vector2(0.5, 0.5),
		_hex(int(c.get("glow", 0xffb060))), true, float(c.get("glowOpacity", 0.75)))
	var flame := _billboard(ProceduralTextures.flame(), Vector2(0.26, 0.34),
		_hex(int(c.get("flame", 0xffb050))), false, 1.0)
	group.add_child(glow)
	group.add_child(flame)
	_flames.append({"flame": flame, "glow": glow, "group": group, "base_pos": group.position,
		"phase": randf() * TAU, "speed": 0.85 + randf() * 0.5, "opacity": float(c.get("glowOpacity", 0.75))})

func _process(delta: float) -> void:
	_time += delta
	for f in _flames:
		var p: float = _time * f["speed"] + f["phase"]
		var flick := 1.0 + sin(p) * 0.10 + sin(p * 2.7) * 0.05
		f["flame"].scale = Vector3(flick, 1.0 + sin(p * 1.8 + 1.0) * 0.14, 1.0)
		var g_scale := (0.45 + sin(p) * 0.08) / 0.5
		f["glow"].scale = Vector3(g_scale, g_scale, 1.0)
		var m: StandardMaterial3D = f["glow"].material_override
		m.albedo_color.a = clampf(0.55 + sin(p * 1.3) * 0.2, 0.0, 1.0)
		f["group"].position = f["base_pos"] + Vector3(sin(p * 0.7) * 0.015, 0, 0)

static func _hex(v: int) -> Color:
	return Color.hex((v << 8) | 0xff)

static func _billboard(tex: Texture2D, size: Vector2, color: Color, additive: bool, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	return mi

static func _bowl_material(idx: int) -> StandardMaterial3D:
	if _bowl_mats.has(idx):
		return _bowl_mats[idx]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = load(SHEET)
	m.uv1_scale = Vector3(1.0 / SHEET_COUNT, 1.0, 1.0)
	m.uv1_offset = Vector3(float(idx) / SHEET_COUNT, 0.0, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bowl_mats[idx] = m
	return m
