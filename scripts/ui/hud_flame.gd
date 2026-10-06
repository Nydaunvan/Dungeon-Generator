class_name HudFlame
extends Control
## Flamme de torche en vrai 3D pour le bandeau des cartouches : même maillage et même shader que les torches du donjon
## (TorchLayer), rendus dans un petit SubViewport transparent, avec un halo qui vacille et quelques étincelles.
## `place()` cale la flamme sur la vasque de la torche ; tout est dimensionné par l'échelle du bandeau.

const FLAME_COL := Color(1.0, 0.42, 0.08)
const VIEW_H := 0.5          # hauteur visible (m) de la caméra orthogonale
const BASE_UP := 0.05        # le pied de la flamme (y = 0) est à 5 cm du bas de la vue
const ASPECT := 0.8          # largeur / hauteur de la vue
const FLAME_PX := 96.0       # hauteur à l'écran de la flamme (px de l'image d'origine)

static var _mat_outer: ShaderMaterial
static var _mat_inner: ShaderMaterial

var _vc: SubViewportContainer
var _vp: SubViewport
var _glow: TextureRect
var _sparks: CPUParticles3D
var _frame_t := 0.0
var _phase := 0.0
var _sc := 1.0
var _base := Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	z_index = 50          # au-dessus du décor et des cartes : la flamme ne doit jamais être recouverte
	_phase = randf() * 10.0
	_glow = TextureRect.new()
	_glow.texture = ProceduralTextures.glow()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = cm
	_glow.modulate = Color(1.0, 0.55, 0.22, 0.5)
	add_child(_glow)
	_vc = SubViewportContainer.new()
	_vc.stretch = true
	_vc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	_vc.add_child(_vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = VIEW_H
	cam.position = Vector3(0.0, VIEW_H * 0.5 - BASE_UP, 1.0)
	cam.current = true
	_vp.add_child(cam)
	var outer := MeshInstance3D.new()
	outer.mesh = TorchLayer._get_flame_mesh()
	outer.material_override = _mat(false)
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(outer)
	var inner := MeshInstance3D.new()
	inner.mesh = TorchLayer._get_flame_mesh()
	inner.material_override = _mat(true)
	inner.scale = Vector3(0.52, 0.72, 0.52)
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(inner)
	_vp.add_child(_make_sparks())
	Settings.changed.connect(func(): _sparks.amount = Settings.pc(4))

## Copie du shader de flamme du donjon en mélange normal : l'additif ne laisse pas d'alpha dans un fond transparent.
static func _mat(inner: bool) -> ShaderMaterial:
	if inner and _mat_inner != null:
		return _mat_inner
	if not inner and _mat_outer != null:
		return _mat_outer
	var sh := Shader.new()
	sh.code = TorchLayer.FLAME_SHADER.replace("blend_add", "blend_mix")
	var m := ShaderMaterial.new()
	m.shader = sh
	if inner:
		m.set_shader_parameter("flame_color", _disp(FLAME_COL.lerp(Color(1.0, 0.8, 0.35), 0.7)))
		m.set_shader_parameter("core_color", _disp(Color(1.0, 0.9, 0.55)))
		m.set_shader_parameter("gain", 1.0)
		_mat_inner = m
	else:
		m.set_shader_parameter("flame_color", _disp(FLAME_COL))
		m.set_shader_parameter("core_color", _disp(FLAME_COL.lerp(Color(1.0, 0.7, 0.25), 0.55)))
		m.set_shader_parameter("gain", 1.0)
		_mat_outer = m
	return m

## Le SubViewport 2D n'encode pas en sRGB : on fournit la couleur pour qu'elle s'affiche telle quelle.
static func _disp(c: Color) -> Color:
	return c

func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = Settings.pc(4)
	_sparks = p
	p.lifetime = 1.6
	p.lifetime_randomness = 0.6
	p.explosiveness = 0.8
	p.randomness = 1.0
	p.local_coords = false
	p.fixed_fps = 30
	p.position = Vector3(0.0, TorchLayer.FLAME_H * 0.55, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 30.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0.0, 0.02, 0.0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.05
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.5, 0.12, 0.8), Color(0.8, 0.2, 0.05, 0.0)])
	p.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = TorchLayer._particle_material(ProceduralTextures.glow(), false)
	p.mesh = qm
	p.emitting = true
	return p

## Pose la flamme : `base` = centre de la vasque (px de conception, repère du parent), `sc` = px de conception par px d'image.
func place(base: Vector2, sc: float) -> void:
	_base = base
	_sc = sc
	var hc := VIEW_H / TorchLayer.FLAME_H * FLAME_PX * sc
	var wc := hc * ASPECT
	position = Vector2.ZERO
	_vc.size = Vector2(wc, hc)
	_vc.position = Vector2(base.x - wc * 0.5, base.y + BASE_UP / VIEW_H * hc - hc)
	var gs := 90.0 * sc   # reste dans le bandeau : un halo plus large serait coupé net par le bord
	_glow.size = Vector2(gs, gs)
	_glow.position = base - Vector2(gs, gs) * 0.5 + Vector2(0, -18.0 * sc)
	queue_redraw()

func _process(d: float) -> void:
	_phase += d
	var k := 0.5 + (sin(_phase * 7.1) * 0.08 + sin(_phase * 11.3 + 1.0) * 0.06) * Settings.motion_k()
	_glow.modulate = Color(1.0, 0.55, 0.22, k)
	# cadence de la flamme (réglage « Flammes du bandeau ») : 60 = rendu à chaque image, sinon une image tous les 1/n s
	var fps := Settings.flame_fps()
	if fps >= 60:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_frame_t += d
		if _frame_t >= 1.0 / float(maxi(fps, 1)):
			_frame_t = 0.0
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _draw() -> void:
	# braises au fond de la vasque (le dessin d'origine a été vidé de sa flamme)
	if _sc <= 0.0:
		return
	var pts := PackedVector2Array()
	var rx := 27.0 * _sc
	var ry := 7.0 * _sc
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(_base + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, Color(0.42, 0.16, 0.05))
	var pts2 := PackedVector2Array()
	for i in 24:
		var a2 := TAU * float(i) / 24.0
		pts2.append(_base + Vector2(cos(a2) * rx * 0.62, sin(a2) * ry * 0.6))
	draw_colored_polygon(pts2, Color(0.95, 0.5, 0.15))
