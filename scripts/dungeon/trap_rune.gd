class_name TrapRune
extends RefCounted
## Piège « rune de flammes » : cercle magique gravé dans le sol (anneaux, 24 runes du futhark, hexagramme : le dessin du sort Éclat Arcanique)
## qui rougeoie en pulsant, avec des braises qui montent et une lueur orangée. Déclenché, il crache une gerbe de flammes puis se rallume ;
## désamorcé, les runes s'éteignent (elles restent gravées, froides et sombres) et les braises cessent.
## Repère local : l'origine est au centre de la case, au niveau du sol.

const ARCANE := preload("res://scripts/dungeon/spell_fx_arcane.gd")   # son dessin de cercle magique (texture mise en cache)
const SIZE := 2.3                       ## côté du carré du dessin (m)
const LIT := Color(1.0, 0.34, 0.07)     ## couleur des runes allumées
const LIT_K := 2.4                      ## intensité (HDR : nourrit le halo de l'environnement)
const DEAD := Color(0.30, 0.09, 0.05)   ## runes éteintes

static var _scorch: Texture2D

static func make() -> Node3D:
	var root := Node3D.new()
	root.set_meta("trap_rune", true)
	# trace de brûlure sous le dessin (le sol paraît noirci)
	var sc := MeshInstance3D.new()
	sc.name = "Scorch"
	var sq := QuadMesh.new()
	sq.size = Vector2(SIZE * 1.15, SIZE * 1.15)
	sc.mesh = sq
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _scorch_tex()
	sm.render_priority = 1
	sc.material_override = sm
	sc.rotation.x = -PI * 0.5
	sc.position.y = 0.012
	sc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sc)
	# dessin des runes, additif
	var rn := MeshInstance3D.new()
	rn.name = "Runes"
	var rq := QuadMesh.new()
	rq.size = Vector2(SIZE, SIZE)
	rn.mesh = rq
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_texture = ARCANE._rune_tex()
	rm.albedo_color = _lit(1.0)
	rm.render_priority = 2
	rm.no_depth_test = false
	rn.material_override = rm
	rn.rotation.x = -PI * 0.5
	rn.position.y = 0.02
	rn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rn)
	# lueur douce au ras du sol
	var gl := MeshInstance3D.new()
	gl.name = "Halo"
	var gq := QuadMesh.new()
	gq.size = Vector2(SIZE * 1.5, SIZE * 1.5)
	gl.mesh = gq
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = TrapGas._puff_tex()
	gm.albedo_color = Color(1.0, 0.3, 0.06, 0.34)
	gm.render_priority = 2
	gl.material_override = gm
	gl.rotation.x = -PI * 0.5
	gl.position.y = 0.018
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gl)
	# braises qui montent le long des anneaux
	var em := _embers()
	root.add_child(em)
	# lueur orangée pulsante
	var l := OmniLight3D.new()
	l.name = "Lamp"
	l.light_color = Color(1.0, 0.45, 0.15)
	l.light_energy = 0.9
	l.omni_range = 4.6
	l.light_specular = 0.0
	l.shadow_enabled = false
	l.position = Vector3(0, 0.5, 0)
	root.add_child(l)
	_pulse(root)
	return root

static func _lit(k: float) -> Color:
	return Color(LIT.r * LIT_K * k, LIT.g * LIT_K * k, LIT.b * LIT_K * k, 1.0)

## Pulsation lente des runes, de la lueur et du halo (tween en boucle porté par le nœud ; coupé quand le piège est désamorcé).
static func _pulse(root: Node3D) -> void:
	var rn := root.get_node("Runes") as MeshInstance3D
	var l := root.get_node("Lamp") as OmniLight3D
	var m := rn.material_override as StandardMaterial3D
	var tw := root.create_tween().set_loops()
	tw.set_parallel(true)
	tw.tween_property(m, "albedo_color", _lit(0.62), 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "light_energy", 0.55, 1.3).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(m, "albedo_color", _lit(1.0), 1.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(l, "light_energy", 1.1, 1.5).set_trans(Tween.TRANS_SINE)
	root.set_meta("pulse", tw)

## Gerbe de flammes (échec du jet) : flammes en colonne, éclair de lumière et runes en surbrillance ; puis la rune se rallume.
static func fire(root: Node3D) -> void:
	if not root.is_inside_tree() or bool(root.get_meta("trap_rune_off", false)):
		return
	var f := _flames()
	f.position.y = 0.05
	root.add_child(f)
	f.emitting = true
	var kill := root.create_tween()
	kill.tween_interval(2.2)
	kill.tween_callback(func():
		if is_instance_valid(f):
			f.queue_free())
	var l := root.get_node_or_null("Lamp") as OmniLight3D
	var fx: Array = root.get_meta("fire_tweens", [])
	fx = fx.filter(func(t): return t is Tween and (t as Tween).is_valid())
	root.set_meta("fire_tweens", fx)
	if l != null:
		var fl := root.create_tween()
		fx.append(fl)
		fl.tween_property(l, "light_energy", 6.0, 0.08)
		fl.tween_property(l, "light_energy", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var rn := root.get_node_or_null("Runes") as MeshInstance3D
	if rn != null:
		var m := rn.material_override as StandardMaterial3D
		var fr := root.create_tween()
		fx.append(fr)
		fr.tween_property(m, "albedo_color", _lit(2.6), 0.08)
		fr.tween_property(m, "albedo_color", _lit(1.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Désamorcé : les runes s'éteignent (immédiat au chargement du niveau), les braises et la lueur cessent.
static func stop(root: Node, animate: bool = true) -> void:
	if bool(root.get_meta("trap_rune_off", false)):
		return
	root.set_meta("trap_rune_off", true)
	var tw = root.get_meta("pulse", null)
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	for t in root.get_meta("fire_tweens", []):      # une gerbe en cours ne doit pas rallumer les runes
		if t is Tween and (t as Tween).is_valid():
			(t as Tween).kill()
	var rn := root.get_node_or_null("Runes") as MeshInstance3D
	var l := root.get_node_or_null("Lamp") as OmniLight3D
	var halo := root.get_node_or_null("Halo")
	var em := root.get_node_or_null("Embers") as GPUParticles3D
	if em != null:
		em.emitting = false
	if not animate or not root.is_inside_tree():
		if rn != null:
			(rn.material_override as StandardMaterial3D).albedo_color = DEAD
		if l != null:
			l.queue_free()
		if halo != null:
			halo.queue_free()
		if em != null:
			em.queue_free()
		return
	var t := root.create_tween().set_parallel(true)
	if rn != null:
		t.tween_property(rn.material_override, "albedo_color", DEAD, 1.4)
	if l != null:
		t.tween_property(l, "light_energy", 0.0, 1.4)
	if halo != null:
		t.tween_property((halo as MeshInstance3D).material_override, "albedo_color:a", 0.0, 1.4)
	t.chain().tween_callback(func():
		if is_instance_valid(l):
			l.queue_free()
		if is_instance_valid(halo):
			halo.queue_free()
		if is_instance_valid(em):
			em.queue_free())

static func _embers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Embers"
	p.amount = Settings.pc(22)
	p.lifetime = 2.2
	p.preprocess = 2.2
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-2, -0.2, -2), Vector3(4, 3, 4))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = SIZE * 0.42
	pm.emission_ring_inner_radius = SIZE * 0.2
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.025
	pm.scale_max = 0.06
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 1.8
	pm.color_ramp = _ramp(Color(1.0, 0.7, 0.2, 0.0), Color(1.0, 0.45, 0.1, 1.0), Color(0.6, 0.1, 0.05, 0.0))
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = TrapGas._puff_tex()
	m.albedo_color = Color(2.2, 1.2, 0.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	return p

static func _flames() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Flames"
	p.amount = Settings.pc(46)
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.55
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-2, -0.2, -2), Vector3(4, 5, 4))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = SIZE * 0.38
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.02
	pm.direction = Vector3.UP
	pm.spread = 16.0
	pm.initial_velocity_min = 2.6
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -1.2, 0)
	pm.damping_min = 0.4
	pm.damping_max = 1.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1, 0.3))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color_ramp = _ramp(Color(1.0, 0.85, 0.35, 0.9), Color(1.0, 0.4, 0.08, 0.8), Color(0.35, 0.05, 0.02, 0.0))
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = TrapGas._puff_tex()
	m.albedo_color = Color(1.9, 1.1, 0.5)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	return p

static func _ramp(a: Color, b: Color, c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([a, b, c])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func _scorch_tex() -> Texture2D:
	if _scorch == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0).length()
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.04, 0.025, 0.02, 0.6 * a * a * (3.0 - 2.0 * a)))
		_scorch = ImageTexture.create_from_image(img)
	return _scorch
