class_name TrapGas
extends RefCounted
## Piège « vapeur » en vrai volume : bouche d'aération de fer et nuage vert épais qui s'en échappe en continu (particules GPU en
## volutes, nappe rasante, halo lumineux vert, brume volumétrique éclairée en Forward+). Désamorcé, le piège cesse de cracher.

const SIZE := 1.3
const PLATE_H := 0.05

static var _mesh: ArrayMesh
static var _mat: StandardMaterial3D
static var _puff: Texture2D

static func make() -> MeshInstance3D:
	_build_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _vent_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.set_meta("trap_gas", true)
	var cloud := Node3D.new()
	cloud.name = "Cloud"
	cloud.position.y = PLATE_H
	mi.add_child(cloud)
	# colonne de vapeur : grosses volutes qui montent, tournent et s'étalent
	_emitter(cloud, "Column", Settings.pc(46), 3.4, Vector3(0.45, 0.02, 0.45), Vector3(0, 1, 0), 24.0, 0.35, 0.95,
		Vector3(0, 0.10, 0), 1.5, 3.4, 0.55, Color(1.15, 1.5, 1.0), _ramp(Color(0.35, 1.0, 0.25, 0.0), Color(0.40, 1.0, 0.28, 0.62), Color(0.22, 0.75, 0.18, 0.0)))
	# nappe rasante qui coule sur le sol
	_emitter(cloud, "Ground", Settings.pc(26), 4.2, Vector3(0.5, 0.02, 0.5), Vector3(1, 0.05, 0), 180.0, 0.25, 0.6,
		Vector3(0, 0.0, 0), 2.2, 4.2, 0.9, Color(1.05, 1.4, 0.95), _ramp(Color(0.3, 0.9, 0.22, 0.0), Color(0.34, 0.95, 0.24, 0.5), Color(0.2, 0.65, 0.16, 0.0)))
	# cœur lumineux : volutes plus claires, en HDR (nourrit le halo de l'environnement)
	var glow := _emitter(cloud, "Glow", Settings.pc(16), 2.4, Vector3(0.3, 0.02, 0.3), Vector3(0, 1, 0), 18.0, 0.5, 1.1,
		Vector3(0, 0.15, 0), 0.9, 1.9, 0.4, Color(0.7, 2.3, 0.55), _ramp(Color(0.5, 1.0, 0.4, 0.0), Color(0.6, 1.0, 0.5, 0.35), Color(0.3, 0.9, 0.2, 0.0)))
	(glow.draw_pass_1 as QuadMesh).material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# lueur verte pulsante
	var l := OmniLight3D.new()
	l.name = "Lamp"
	l.light_color = Color(0.35, 1.0, 0.3)
	l.light_energy = 1.3
	l.omni_range = 5.5
	l.shadow_enabled = false
	l.position = Vector3(0, 0.55, 0)
	cloud.add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "light_energy", 0.8, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 1.6, 1.3).set_trans(Tween.TRANS_SINE)
	# brume volumétrique verte (rendu Forward+, si le brouillard volumétrique est actif)
	if VisualFx.is_forward():
		var fv := FogVolume.new()
		fv.name = "Fog"
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		fv.size = Vector3(3.6, 2.0, 3.6)
		fv.position = Vector3(0, 0.9, 0)
		var fm := FogMaterial.new()
		fm.albedo = Color(0.3, 0.9, 0.25)
		fm.emission = Color(0.04, 0.32, 0.03)
		fm.density = 0.9
		fm.edge_fade = 0.6
		fv.material = fm
		cloud.add_child(fv)
	return mi

## Le piège est désamorcé : le nuage se dissipe (ou disparaît d'un coup au chargement du niveau).
static func stop(root: Node, animate: bool = true) -> void:
	var cloud := root.get_node_or_null("Cloud") as Node3D
	if cloud == null:
		return
	if not animate or not root.is_inside_tree():
		cloud.queue_free()
		return
	for n in cloud.get_children():
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = false
	var lamp := cloud.get_node_or_null("Lamp") as OmniLight3D
	if lamp != null:
		for t in lamp.get_children():
			t.queue_free()
	var tw := cloud.create_tween().set_parallel(true)
	if lamp != null:
		tw.tween_property(lamp, "light_energy", 0.0, 1.5)
	var fog := cloud.get_node_or_null("Fog") as FogVolume
	if fog != null:
		tw.tween_property(fog.material, "density", 0.0, 2.5)
	tw.chain().tween_interval(3.0)
	tw.chain().tween_callback(func():
		if is_instance_valid(cloud):
			cloud.queue_free())

static func _emitter(parent: Node3D, nm: String, amount: int, life: float, box: Vector3, dir: Vector3, spread: float, vmin: float, vmax: float,
		grav: Vector3, smin: float, smax: float, turb: float, tint: Color, ramp: GradientTexture1D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-3, -0.5, -3), Vector3(6, 4, 6))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.damping_min = 0.15
	pm.damping_max = 0.4
	pm.scale_min = smin * 0.5
	pm.scale_max = smax * 0.5
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(0.45, 0.85))
	grow.add_point(Vector2(1, 1.25))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -25.0
	pm.angular_velocity_max = 25.0
	pm.color_ramp = ramp
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = turb
	pm.turbulence_noise_scale = 1.4
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.25
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_tex()
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true        # Forward+ : les bouffées s'estompent là où elles touchent le sol et les murs
	m.proximity_fade_distance = 0.6
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)
	return p

static func _ramp(a: Color, b: Color, c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([a, b, c])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

## Bouffée : disque doux dont les bords sont rongés par du bruit (aspect de nuage).
static func _puff_tex() -> Texture2D:
	if _puff == null:
		var n := 96
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 3
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0).length()
				var f := clampf(1.0 - d, 0.0, 1.0)
				var nz := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
				var a := clampf(f * (0.55 + 0.9 * nz), 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_puff = ImageTexture.create_from_image(img)
	return _puff

static func _vent_mat() -> StandardMaterial3D:
	if _mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.metallic = 0.6
		m.roughness = 0.5
		_mat = m
	return _mat

## Bouche d'aération : cadre de fer, grille de fentes sombres teintées de vert, coins rivetés.
static func _build_mesh() -> void:
	if _mesh != null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := SIZE * 0.5
	var iron := Color(0.17, 0.16, 0.15)
	var edge := Color(0.26, 0.25, 0.21)
	TrapSpikes.add_box(st, Vector3(0, PLATE_H * 0.25, 0), Vector3(h, PLATE_H * 0.25, h), edge)
	TrapSpikes.add_box(st, Vector3(0, PLATE_H * 0.75, 0), Vector3(h - 0.05, PLATE_H * 0.25, h - 0.05), iron)
	for i in 7:
		var x := (float(i) - 3.0) * 0.14
		TrapSpikes.add_box(st, Vector3(x, PLATE_H + 0.003, 0), Vector3(0.035, 0.003, h - 0.16), Color(0.03, 0.14, 0.03))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			TrapSpikes.add_prism(st, Vector3(sx * (h - 0.1), PLATE_H, sz * (h - 0.1)), 0.03, 0.02, 8, edge)
	_mesh = st.commit()
