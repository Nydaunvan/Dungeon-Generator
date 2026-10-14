extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets arcaniques avancés (Forward+ / Vulkan) : cristal, orbe de mana, rayon. Choisis dans l'éditeur de sorts (voir SpellFxLibrary).
## Par rapport à l'effet d'origine (sprites additifs et particules CPU) : lumière HDR qui nourrit le halo, particules GPU (traînées en
## ruban, étincelles filantes), onde de choc et distorsion en shader, rune qui se grave au sol, lumière dynamique qui éclaire la brume,
## légère secousse de caméra. Tout se règle avec la teinte et l'intensité du sort et se réduit selon le niveau graphique :
##   palier 1 : particules GPU + halo · palier 2 : + lumière, brume éclairée, rune au sol · palier 3 : + distorsion de l'écran.

const DEFAULT_HUE := 0.615    # teinte par défaut : bleu et blanc, comme l'icône 💠 d'Éclat Arcanique


## Point d'entrée (appelé par SpellFxLibrary). `ctx` : style, mode, fx, fxTint, fxPower…
func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	if _tier >= 2:
		_rune_tex()      # la texture se génère au premier lancer (préchauffage) : pas d'à-coup au premier vrai sort
	if not _tinted:      # la palette de base est violette : sans teinte choisie, on la tourne vers le bleu de l'icône
		_tinted = true
		_tint_h = DEFAULT_HUE
	match str(ctx.get("fx", "arcane_crystal")):
		"arcane_orb":
			_orb_cast(target)
		"arcane_beam":
			_beam_cast(target)
		_:
			_crystal_cast(target)

# ------------------------------------------------------------------------------------------ impact commun

## Impact : flash, ondes de choc, éclats de cristal, étincelles filantes (rubans GPU), fumée lumineuse, rune au sol, lumière, secousse.
func _burst(at: Vector3, target: Dictionary, big: float = 1.0) -> void:
	var size := _tsize(target) * big * _s
	_flash(_w_soft(), _hdr(_c(0.9, 0.82, 1.0), 1.3 * _g), at, 0.4 * size, 1.9 * size, 0.3)
	_shock(at, _c(0.78, 0.6, 1.0), 2.6 * size, 0.5)
	_later(0.08, func(): _shock(at, _c(0.92, 0.82, 1.0), 1.7 * size, 0.35))
	_lens(at, 3.0 * size, 0.07 * _pw, 0.35)
	# éclats de cristal projetés
	var key := "fxa_shard_%d" % (int(_tint_h * 100.0) if _tinted else -1)
	var shard := _shard_pal(key, _c(1.0, 1.0, 1.0), _c(0.78, 0.62, 1.0), _c(0.42, 0.22, 0.85))
	shard.surface_set_material(0, _vcol_mat(1.3 * _g))
	var spm := _pmat(0.06, Vector3.UP, 180.0, 2.0 * size, 4.2 * size, Vector3(0, -4.5, 0), 0.18, 0.38, _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
	spm.angle_min = -180.0
	spm.angle_max = 180.0
	spm.angular_velocity_min = -540.0
	spm.angular_velocity_max = 540.0
	_free_after(_gpu(10, 0.6, true, shard, spm, at), 0.8)
	# étincelles filantes : chacune laisse un ruban de lumière
	var rib := RibbonTrailMesh.new()
	rib.shape = RibbonTrailMesh.SHAPE_CROSS
	rib.size = 0.06
	rib.sections = 4
	rib.section_length = 0.12
	rib.section_segments = 2
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.vertex_color_use_as_albedo = true
	rm.use_particle_trails = true
	rm.albedo_color = _hdr(_c(0.85, 0.72, 1.0), 1.5 * _g)
	rib.material = rm
	var rpm := _pmat(0.05, Vector3.UP, 180.0, 1.6 * size, 4.0 * size, Vector3(0, -2.2, 0), 1.0, 1.0,
		_ramp(_c(1.0, 0.95, 1.0, 1.0), _c(0.75, 0.55, 1.0, 0.9), _c(0.45, 0.25, 1.0, 0.0)), 1.1)
	var rib_p := _gpu(16, 0.7, true, rib, rpm, at)
	rib_p.trail_enabled = true
	rib_p.trail_lifetime = 0.35
	_free_after(rib_p, 1.1)
	# étincelles et fumée lumineuse
	var gpm := _pmat(0.1, Vector3.UP, 180.0, 1.0 * size, 3.0 * size, Vector3(0, -1.0, 0), 0.08, 0.18,
		_ramp(_c(1.0, 0.95, 1.0, 1.0), _c(0.78, 0.6, 1.0, 0.9), _c(0.5, 0.3, 1.0, 0.0)), 1.0, 0.8)
	_free_after(_gpu(26, 0.8, true, _soft_mesh(_c(0.85, 0.7, 1.0), 1.4 * _g, _w_spark()), gpm, at), 1.0)
	var fpm := _pmat(0.2 * size, Vector3.UP, 60.0, 0.2, 0.7, Vector3(0, 0.5, 0), 0.5 * size, 0.9 * size,
		_ramp(_c(0.6, 0.4, 1.0, 0.0), _c(0.5, 0.3, 0.95, 0.35), _c(0.3, 0.15, 0.7, 0.0)), 0.8, 0.6)
	_free_after(_gpu(8, 0.9, true, _soft_mesh(_c(0.55, 0.35, 1.0), 0.6 * _g, _w_soft()), fpm, at), 1.1)
	_rune_decal(target, _c(0.7, 0.5, 1.0), size)
	var lamp := _lamp_node(at, _c(0.7, 0.5, 1.0), 2.0 * _g, 5.0)
	_fade_lamp(lamp, 0.45)
	_shake(0.03 * _pw, 0.2)

# ------------------------------------------------------------------------------------------ CRISTAL

## Cristal arcanique : un cristal HDR tournoie vers le monstre, traînée de particules GPU, éclats en orbite, distorsion de l'air.
func _crystal_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var dur := clampf(0.30 + start.distance_to(end) * 0.035, 0.34, 0.5)
	var arc := 0.28 * (1.0 if randf() < 0.5 else -1.0)
	var holder := Node3D.new()
	holder.position = start
	add_child(holder)
	if end.distance_to(start) > 0.05:
		holder.look_at(end, up)
	var key := "fxa_crystal_%d" % (int(_tint_h * 100.0) if _tinted else -1)
	var body := MeshInstance3D.new()
	body.mesh = _shard_pal(key, _c(1.0, 1.0, 1.0), _c(0.78, 0.62, 1.0), _c(0.42, 0.22, 0.85))
	body.material_override = _vcol_mat(1.25 * _g)
	body.scale = Vector3.ONE * 1.05 * _s
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(body)
	var halo := _sprite(_w_soft(), _hdr(_c(0.72, 0.55, 1.0, 0.5), 0.9 * _g), 0.4 * _s, start)
	var core := _sprite(_w_soft(), Color(1.5, 1.5, 1.7, 1.0), 0.12 * _s, start)
	var tr_ramp := _ramp(_c(0.85, 0.7, 1.0, 0.0), _c(0.65, 0.45, 1.0, 0.85), _c(0.4, 0.2, 0.9, 0.0))
	var trail := _gpu(40, 0.28, false, _soft_mesh(_c(0.8, 0.6, 1.0), 1.2 * _g, _w_spark()),
		_pmat(0.05, Vector3.UP, 180.0, 0.05, 0.4, Vector3.ZERO, 0.12 * _s, 0.28 * _s, tr_ramp, 1.0), start)
	var motes: Array = []
	for i in 3:
		motes.append(_sprite(_w_spark(), _hdr(_c(0.85, 0.75, 1.0, 0.9), 1.3 * _g), 0.12 * _s, start))
	var lens := _lens(start, 1.4 * _s, 0.05 * _pw, 0.0)
	var lamp := _lamp_node(start, _c(0.6, 0.4, 1.0), 1.6 * _g, 4.0)
	_add({"node": holder}, dur, func(u: float):
		var k := u * u * (1.5 - 0.5 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc) + up * (sin(k * PI) * 0.1)
		holder.position = pos
		body.rotation.z = u * TAU * 3.0
		(halo.node as Node3D).position = pos
		(halo.node as Node3D).scale = Vector3.ONE * 0.4 * _s * (1.0 + sin(u * 40.0) * 0.12)
		(core.node as Node3D).position = pos
		trail.position = pos
		for i in motes.size():
			var ang := u * 24.0 + float(i) * TAU / 3.0
			var rad := 0.12 * (1.0 - u * 0.4)
			(motes[i].node as Node3D).position = pos + right * cos(ang) * rad + up * sin(ang) * rad
		if lens != null:
			lens.position = pos
		if lamp != null:
			lamp.position = pos
		if u >= 1.0:
			trail.emitting = false
			_free_after(trail, 0.5)
			(halo.node as Node).queue_free()
			(core.node as Node).queue_free()
			for m in motes:
				(m.node as Node).queue_free()
			if lens != null:
				lens.queue_free()
			_fade_lamp(lamp, 0.2)
			_burst(end, target))

# ------------------------------------------------------------------------------------------ ORBE

## Orbe de mana : sphère pulsante, plus lente, entourée de volutes ; l'impact est plus ample.
func _orb_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var dur := clampf(0.42 + start.distance_to(end) * 0.045, 0.5, 0.7)
	var arc := 0.18 * (1.0 if randf() < 0.5 else -1.0)
	var om := _smat("orb", SH_ORB, 5)
	om.set_shader_parameter("col_a", _c(0.45, 0.25, 1.0))
	om.set_shader_parameter("col_b", _c(0.9, 0.8, 1.0))
	om.set_shader_parameter("power", _g)
	var sphere := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 12
	sphere.mesh = sm
	sphere.material_override = om
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere.position = start
	add_child(sphere)
	var halo := _sprite(_w_soft(), _hdr(_c(0.6, 0.4, 1.0, 0.6), 1.0 * _g), 0.7 * _s, start)
	var wisp_ramp := _ramp(_c(0.8, 0.65, 1.0, 0.0), _c(0.7, 0.5, 1.0, 0.8), _c(0.4, 0.2, 0.9, 0.0))
	var wisps := _gpu(36, 0.5, false, _soft_mesh(_c(0.75, 0.6, 1.0), 1.6 * _g, _w_spark()),
		_pmat(0.28, Vector3.UP, 180.0, 0.1, 0.5, Vector3.ZERO, 0.1 * _s, 0.24 * _s, wisp_ramp, 1.5, 1.2), start)
	var lens := _lens(start, 1.8 * _s, 0.05 * _pw, 0.0)
	var lamp := _lamp_node(start, _c(0.55, 0.35, 1.0), 2.0 * _g, 4.5)
	_add({"node": sphere}, dur, func(u: float):
		var k := u * u * (3.0 - 2.0 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc) + up * (sin(k * PI) * 0.12)
		sphere.position = pos
		var pulse := 1.0 + sin(u * 30.0) * 0.1
		sphere.scale = Vector3.ONE * 0.3 * _s * pulse * (1.0 + 0.25 * k)
		om.set_shader_parameter("time_s", u * dur)
		(halo.node as Node3D).position = pos
		(halo.node as Node3D).scale = Vector3.ONE * 0.7 * _s * pulse
		wisps.position = pos
		if lens != null:
			lens.position = pos
		if lamp != null:
			lamp.position = pos
		if u >= 1.0:
			wisps.emitting = false
			_free_after(wisps, 0.6)
			(halo.node as Node).queue_free()
			if lens != null:
				lens.queue_free()
			_fade_lamp(lamp, 0.25)
			_flash(_w_soft(), _hdr(_c(0.8, 0.7, 1.0), 1.3 * _g), end, 0.5 * _s, 2.4 * _s, 0.5)
			_burst(end, target, 1.25))

# ------------------------------------------------------------------------------------------ RAYON

## Rayon arcanique : un trait de lumière jaillit du bas de l'écran jusqu'au monstre, puis s'efface de l'origine vers la cible.
func _beam_cast(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var axis := end - start
	var length := axis.length()
	if length < 0.1:
		_burst(end, target)
		return
	var x := axis / length
	var mid := (start + end) * 0.5
	var to_cam := cam.global_position - mid
	var z := (to_cam - x * to_cam.dot(x)).normalized()
	var y := z.cross(x)
	var dur := 0.38
	var bm := _smat("beam", SH_BEAM, 5)
	bm.set_shader_parameter("col", _c(0.7, 0.5, 1.0))
	bm.set_shader_parameter("power", _g)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	mi.material_override = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis(x * length, y * 0.6 * _s, z), mid)
	add_child(mi)
	_flash(_w_soft(), _hdr(_c(0.85, 0.75, 1.0), 1.3 * _g), start, 0.3 * _s, 1.2 * _s, 0.3)
	var lamp := _lamp_node(mid, _c(0.6, 0.4, 1.0), 2.2 * _g, 6.0)
	_add({"node": mi}, dur, func(u: float):
		bm.set_shader_parameter("head", clampf(u / 0.3, 0.0, 1.0))
		bm.set_shader_parameter("tail", clampf((u - 0.45) / 0.55, 0.0, 1.0))
		bm.set_shader_parameter("progress", u)
		var w := 0.6 * _s * (1.0 - clampf((u - 0.6) / 0.4, 0.0, 1.0) * 0.6)
		mi.transform = Transform3D(Basis(x * length, y * w, z), mid))
	_fade_lamp(lamp, dur)
	_later(0.1, func(): _burst(end, target))
