class_name SpellFxStyles
extends SpellFx3D
## Effets 3D de TOUS les sorts, choisis d'après le style (arcane, feu, sacré, givre, ombre, physique, barde, nature)
## et le mode (dégâts, zone, soin, bouclier…). Même recette que SpellFx3D : sprites additifs, un maillage minuscule,
## quelques émetteurs de particules, aucune lumière dynamique sur Web / mobile.
##
## Chaque style a sa signature : arcane = cristal violet · feu = comète orange · sacré = pilier doré ·
## givre = éclats de glace cyan · ombre = sphère sombre qui s'effondre · physique = croissants de lame ·
## barde = ondes sonores et notes · soin = gerbe de lumière sur le héros soigné.

static var _crescent_t: Texture2D
static var _note_t: Texture2D
static var _cross_t: Texture2D
static var _hex_t: Texture2D
static var _shadow_t: Texture2D
static var _shards: Dictionary = {}

## Point d'entrée. `ctx` : {"style", "mode", "ally" (index du héros visé), "caster" (index du lanceur),
## "targets" (points visés de tous les monstres visibles), "status" (effet de statut du sort)}.
static func cast_spell(host: Node, camera: Camera3D, spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	if camera == null:
		return
	var fx := SpellFxStyles.new()
	fx.name = "SpellFx"
	fx.cam = camera
	host.add_child(fx)
	fx._run(spell_id, target, ctx)
	fx._started = true

func _run(spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	var style := str(ctx.get("style", "arcane"))
	var mode := str(ctx.get("mode", "damage"))
	match mode:
		"damage":
			_offense(style, spell_id, target, ctx)
		"damageGroup":
			_group(style, spell_id, target, ctx)
		"healSingle":
			_heal(ctx, false, "haste" if str(ctx.get("status", "")) == "haste" else "heal")
		"healParty":
			_heal(ctx, true, "heal")
		"staminaRestoreSingle":
			_heal(ctx, false, "stamina")
		"shieldSingle":
			_shield(ctx)
		"dispelSingle":
			_dispel(ctx)
		"sleepGroup":
			_sleep(target, ctx)
		"selfBuff":
			_self_buff(ctx)
		"partyUtility":
			_heal(ctx, true, "vigor")
		_:
			_offense(style, spell_id, target, ctx)

# ------------------------------------------------------------------------------------------ outils

func _viewport_size() -> Vector2:
	var vp := cam.get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(960, 640)

## Position monde « sous la caméra » du héros d'index i (les cartes du groupe sont en bas de l'écran, 4 colonnes).
func _slot_pos(i: int, depth: float = 2.2) -> Vector3:
	var vs := _viewport_size()
	var n := 4.0
	return cam.project_position(Vector2(vs.x * (clampf(float(i), 0.0, 3.0) + 0.5) / n, vs.y * 0.8), depth)

func _start_point() -> Vector3:
	return cam.global_position + _fwd() * 0.6 - cam.global_transform.basis.y * 0.42

func _end_point(target: Dictionary) -> Vector3:
	if target.is_empty():
		return _start_point() + _fwd() * 4.0
	return _toward_cam(target.pos)

func _tsize(target: Dictionary, k: float = 0.55, lo: float = 0.7, hi: float = 1.6) -> float:
	return 1.0 if target.is_empty() else clampf(float(target.get("w", 1.0)) * k, lo, hi)

func _flash(tex: Texture2D, col: Color, at: Vector3, s0: float, s1: float, dur: float, nodepth: bool = false) -> void:
	var f := _sprite(tex, col, s0, at)
	if nodepth:
		(f.mat as StandardMaterial3D).no_depth_test = true
	_add(f, dur, func(u: float):
		var e := 1.0 - pow(1.0 - u, 2.0)
		(f.node as Node3D).scale = Vector3.ONE * lerpf(s0, s1, e)
		(f.mat as StandardMaterial3D).albedo_color.a = col.a * (1.0 - u) * (1.0 - u))

## Anneau qui s'étend (face caméra, ou à plat sur le sol).
func _ring(key: String, tint: Color, at: Vector3, s0: float, s1: float, dur: float, flat: bool = false) -> void:
	var tex := _ring_tex_tint(key, tint)
	if not flat:
		var r := _sprite(tex, Color(1, 1, 1, 0.9), s0, at)
		(r.mat as StandardMaterial3D).no_depth_test = true
		_add(r, dur, func(u: float):
			(r.node as Node3D).scale = Vector3.ONE * lerpf(s0, s1, 1.0 - pow(1.0 - u, 3.0))
			(r.mat as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - u))
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := _fx_mat(tex, false)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.rotation.x = -PI * 0.5
	mi.position = at
	add_child(mi)
	_add({"node": mi, "mat": m}, dur, func(u: float):
		mi.scale = Vector3.ONE * lerpf(s0, s1, 1.0 - pow(1.0 - u, 3.0))
		m.albedo_color.a = 0.9 * (1.0 - u))

## Émetteur de particules à usage unique, libéré tout seul.
func _emit(at: Vector3, tex: Texture2D, amount: int, life: float, vmin: float, vmax: float, smin: float, smax: float,
		ramp: Gradient, gravity: Vector3 = Vector3.ZERO, spread: float = 180.0, dir: Vector3 = Vector3.UP,
		radius: float = 0.08, one_shot: bool = true, additive: bool = true) -> CPUParticles3D:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := _fx_mat(tex, true)
	if not additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		mat.render_priority = 4
	q.material = mat
	var p := _particles(amount, life, one_shot, q, ramp)
	p.position = at
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.scale_amount_curve = _shrink_curve()
	add_child(p)
	p.emitting = true
	if one_shot:
		_keep(life + 0.25)
		get_tree().create_timer(life + 0.2).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())
	return p

func _stop_emitter(p: CPUParticles3D, life: float) -> void:
	p.emitting = false
	_keep(life + 0.1)
	get_tree().create_timer(life + 0.05).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

func _lamp(at: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	if not Settings.spell_lamps():
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.position = at
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

# ------------------------------------------------------------------------------------------ textures

static func _crescent_tex() -> Texture2D:
	if _crescent_t == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var px := (float(x) + 0.5) / n * 2.0 - 1.0
				var py := (float(y) + 0.5) / n * 2.0 - 1.0
				var d1 := sqrt(px * px + py * py)
				var d2 := sqrt((px - 0.34) * (px - 0.34) + py * py)
				var outer := clampf((0.96 - d1) / 0.06, 0.0, 1.0)
				var inner := clampf((d2 - 0.78) / 0.08, 0.0, 1.0)
				var a := outer * inner
				var tip := clampf(1.0 - absf(py) * 0.55, 0.0, 1.0)
				img.set_pixel(x, y, Color(1.0, 0.97, 0.85, a * (0.35 + 0.65 * tip)))
		_crescent_t = ImageTexture.create_from_image(img)
	return _crescent_t

static func _note_tex() -> Texture2D:
	if _note_t == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var px := float(x) + 0.5
				var py := float(y) + 0.5
				var a := 0.0
				# tête (ellipse inclinée) centrée en (24, 48)
				var ex := (px - 24.0) / 11.0
				var ey := (py - 48.0) / 8.0
				var rx := ex * 0.9 + ey * 0.35
				var ry := -ex * 0.35 + ey * 0.9
				if rx * rx + ry * ry < 1.0:
					a = 1.0
				# hampe
				if px > 31.0 and px < 36.0 and py > 10.0 and py < 49.0:
					a = 1.0
				# crochet
				if px >= 36.0 and px < 50.0 and py > 10.0 and py < 34.0:
					var t := (px - 36.0) / 14.0
					var cy := 12.0 + t * 20.0 + sin(t * 3.0) * 4.0
					if absf(py - cy) < 4.2:
						a = 1.0
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_note_t = ImageTexture.create_from_image(img)
	return _note_t

static func _cross_tex() -> Texture2D:
	if _cross_t == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var px := absf((float(x) + 0.5) / n * 2.0 - 1.0)
				var py := absf((float(y) + 0.5) / n * 2.0 - 1.0)
				var arm := clampf(1.0 - maxf(px, py) * 0.0, 0.0, 1.0)
				var a := 0.0
				if (px < 0.2 and py < 0.9) or (py < 0.2 and px < 0.9):
					a = clampf(1.0 - (maxf(px, py) - 0.6) / 0.3, 0.0, 1.0) * arm
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cross_t = ImageTexture.create_from_image(img)
	return _cross_t

static func _hex_tex() -> Texture2D:
	if _hex_t == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var px := (float(x) + 0.5) / n * 2.0 - 1.0
				var py := (float(y) + 0.5) / n * 2.0 - 1.0
				var r := sqrt(px * px + py * py)
				var disc := clampf((1.0 - r) / 0.06, 0.0, 1.0)
				# trame hexagonale : distance au centre du nid d'abeille le plus proche
				var q := Vector2(px, py) * 4.2
				var s := Vector2(1.0, 1.7320508)
				var a2 := Vector2(fposmod(q.x, s.x) - s.x * 0.5, fposmod(q.y, s.y) - s.y * 0.5)
				var b2 := Vector2(fposmod(q.x + s.x * 0.5, s.x) - s.x * 0.5, fposmod(q.y + s.y * 0.5, s.y) - s.y * 0.5)
				var dd := minf(a2.length(), b2.length())
				var edge := clampf((dd - 0.36) / 0.1, 0.0, 1.0)
				var rim := clampf((r - 0.84) / 0.1, 0.0, 1.0)
				var a := disc * (0.1 + edge * 0.55 + rim * 0.5)
				img.set_pixel(x, y, Color(0.8, 0.93, 1.0, clampf(a, 0.0, 1.0)))
		_hex_t = ImageTexture.create_from_image(img)
	return _hex_t

static func _shadow_tex() -> Texture2D:
	if _shadow_t == null:
		_shadow_t = _radial("shadow", [[0.0, Color(0.03, 0.0, 0.06, 1.0)], [0.55, Color(0.13, 0.02, 0.26, 0.96)], [0.8, Color(0.45, 0.16, 0.8, 0.55)], [1.0, Color(0.5, 0.2, 0.9, 0)]])
	return _shadow_t

## Éclat de cristal coloré (même forme que le cristal arcanique) : glace, ombre…
static func _shard_pal(key: String, tip: Color, mid: Color, tail: Color) -> ArrayMesh:
	if _shards.has(key):
		return _shards[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ptip := Vector3(0, 0, -0.5)
	var ptail := Vector3(0, 0, 0.3)
	var w := 0.11
	var ring := [Vector3(w, 0, 0), Vector3(0, w, 0), Vector3(-w, 0, 0), Vector3(0, -w, 0)]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for tri in [[ptip, a, b, tip, mid, mid], [ptail, b, a, tail, mid, mid]]:
			for k in 3:
				st.set_color(tri[3 + k])
				st.add_vertex(tri[k])
	var m := st.commit()
	m.surface_set_material(0, _shard_material())
	_shards[key] = m
	return m

func _mesh_sprite(mesh: Mesh, pos: Vector3, scale_v: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Projectile générique : orbe + halo + émetteur de traînée, trajectoire en cloche, puis `on_hit`.
func _orb(start: Vector3, end: Vector3, dur: float, orb_tex: Texture2D, orb_col: Color, orb_size: float, halo_col: Color,
		trail_tex: Texture2D, trail_ramp: Gradient, trail_size: Vector2, arc: float, on_hit: Callable, additive: bool = true) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var halo := _sprite(_arcane_tex(), halo_col, orb_size * 1.6, start)
	var orb := _sprite(orb_tex, orb_col, orb_size, start)
	if not additive:
		(orb.mat as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var trail := _particles(26, 0.3, false, _quad(trail_tex), trail_ramp)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.06
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = trail_size.x
	trail.scale_amount_max = trail_size.y
	trail.scale_amount_curve = _shrink_curve()
	trail.position = start
	add_child(trail)
	trail.emitting = true
	var side := 1.0 if randf() < 0.5 else -1.0
	_add({"node": orb.node}, dur, func(u: float):
		var k := u * u * (1.5 - 0.5 * u)
		var pos := start.lerp(end, k) + right * (sin(k * PI) * arc * side) + up * (sin(k * PI) * 0.1)
		(orb.node as Node3D).position = pos
		(halo.node as Node3D).position = pos
		trail.position = pos
		(orb.node as Node3D).scale = Vector3.ONE * orb_size * (1.0 + 0.2 * k)
		(orb.node as Node3D).rotation.z += 0.1
		if u >= 1.0:
			(orb.node as Node).queue_free()
			(halo.node as Node).queue_free()
			_stop_emitter(trail, 0.4)
			on_hit.call())

# ------------------------------------------------------------------------------------------ dégâts

func _offense(style: String, spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	match style:
		"arcane": _arcane(target)
		"fire": _fire(target)
		"holy": _holy(target)
		"ice": _ice(target)
		"shadow": _shadow(target)
		"physical":
			if spell_id.contains("archer"):
				_arrow(target)
			else:
				_slash(target, spell_id)
		"bard": _sonic(target, Color(1.0, 0.55, 0.78))
		_: _generic(target, _style_color(style))

static func _style_color(style: String) -> Color:
	match style:
		"nature": return Color(0.5, 0.9, 0.45)
		"bard": return Color(1.0, 0.55, 0.78)
		_: return Color(0.9, 0.9, 1.0)

## Sort de zone : pas de projectile unique, une onde balaie la vue et l'impact du style éclate sur chaque monstre.
func _group(style: String, spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty() and not target.is_empty():
		pts = [target]
	if pts.is_empty():
		_offense(style, spell_id, target, ctx)
		return
	var col := _style_tint(style)
	var base := cam.global_position + _fwd() * 2.4 - cam.global_transform.basis.y * 0.7
	_ring("ring_grp_" + style, col, base, 0.6, 7.0, 0.55)
	_flash(_arcane_tex(), Color(col, 0.7), base, 1.0, 5.0, 0.4, true)
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.14 + 0.07 * i, func(): _impact(style, tt, true))
		i += 1

static func _style_tint(style: String) -> Color:
	match style:
		"fire": return Color(1.0, 0.5, 0.12)
		"holy": return Color(1.0, 0.82, 0.4)
		"ice": return Color(0.6, 0.9, 1.0)
		"shadow": return Color(0.6, 0.25, 1.0)
		"bard": return Color(1.0, 0.45, 0.4)
		"physical": return Color(1.0, 0.9, 0.6)
		"nature": return Color(0.5, 0.95, 0.45)
		_: return Color(0.72, 0.5, 1.0)

func _impact(style: String, target: Dictionary, big: bool) -> void:
	var at := _end_point(target)
	match style:
		"arcane": _arcane_burst(at, target)
		"fire": _fire_burst(at, target)
		"holy": _holy(target)
		"ice": _ice_burst(at, target)
		"shadow": _shadow_burst(at, target)
		"bard": _sonic_burst(at, target, Color(1.0, 0.5, 0.4))
		"physical": _hit_sparks(at, target)
		_: _generic_burst(at, target, _style_color(style))

# ------------------------------------------------------------------------------------------ GIVRE

func _ice(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var dur := clampf(0.3 + start.distance_to(end) * 0.035, 0.34, 0.5)
	var holder := Node3D.new()
	holder.position = start
	add_child(holder)
	var mesh := _shard_pal("ice", Color(1, 1, 1), Color(0.7, 0.93, 1.0), Color(0.3, 0.65, 0.95))
	for i in 3:
		var s := _mesh_sprite(mesh, Vector3.ZERO, Vector3(0.7, 0.7, 1.1 - i * 0.2) * 1.2)
		s.reparent(holder, false)
		s.rotation.z = float(i) * TAU / 3.0
		s.position = Vector3(cos(float(i) * TAU / 3.0), sin(float(i) * TAU / 3.0), 0) * 0.07
	var halo := _sprite(_arcane_tex(), Color(0.55, 0.85, 1.0, 0.8), 0.9, start)
	var trail := _particles(28, 0.34, false, _quad(_spark_tex()), _ramp(Color(0.9, 1, 1, 0), Color(0.7, 0.95, 1.0, 0.95), Color(0.5, 0.8, 1.0, 0)))
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.09
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.45
	trail.gravity = Vector3(0, -0.8, 0)
	trail.scale_amount_min = 0.07
	trail.scale_amount_max = 0.16
	trail.position = start
	add_child(trail)
	trail.emitting = true
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var prev := start
	var spin := 0.0
	_add({"node": holder}, dur, func(u: float):
		var k := u * u * (1.5 - 0.5 * u)
		var pos := start.lerp(end, k) + up * (sin(k * PI) * 0.08)
		var d := pos - prev
		if d.length() > 0.0001:
			holder.look_at(pos + d.normalized(), up)
		prev = pos
		holder.position = pos
		spin += 0.35
		for c in holder.get_children():
			if c is Node3D:
				pass
		holder.rotate_object_local(Vector3(0, 0, 1), 0.3)
		(halo.node as Node3D).position = pos
		trail.position = pos
		if u >= 1.0:
			holder.queue_free()
			(halo.node as Node).queue_free()
			_stop_emitter(trail, 0.4)
			_ice_burst(end, target))

func _ice_burst(at: Vector3, target: Dictionary) -> void:
	var size := _tsize(target)
	_flash(_arcane_tex(), Color(0.85, 0.97, 1.0, 1.0), at, 0.5 * size, 2.6 * size, 0.26)
	# étoile de givre : six branches de cristal
	var star := _sprite(_rays_tex(), Color(0.7, 0.93, 1.0, 0.95), 1.0, at)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, 0.55, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.5 + (1.0 - pow(1.0 - u, 2.0)) * 2.1) * size
		(star.node as Node3D).rotation.z = u * 0.5 + 0.4
		(star.mat as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - u))
	_ring("ring_ice", Color(0.6, 0.9, 1.0), at, 0.4 * size, 2.3 * size, 0.4)
	var mesh := _shard_pal("ice", Color(1, 1, 1), Color(0.7, 0.93, 1.0), Color(0.3, 0.65, 0.95))
	var sh := _particles(12, 0.6, true, mesh, _ramp(Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)))
	sh.position = at
	sh.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sh.emission_sphere_radius = 0.06
	sh.direction = Vector3.UP
	sh.spread = 180.0
	sh.initial_velocity_min = 1.8 * size
	sh.initial_velocity_max = 4.0 * size
	sh.gravity = Vector3(0, -5.0, 0)
	sh.angle_min = -180.0
	sh.angle_max = 180.0
	sh.angular_velocity_min = -480.0
	sh.angular_velocity_max = 480.0
	sh.scale_amount_min = 0.16
	sh.scale_amount_max = 0.34
	sh.scale_amount_curve = _shrink_curve()
	add_child(sh)
	sh.emitting = true
	_keep(0.9)
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(sh): sh.queue_free())
	_emit(at, _spark_tex(), 26, 0.9, 0.4, 1.6, 0.05, 0.12,
		_ramp(Color(1, 1, 1, 1), Color(0.7, 0.94, 1.0, 0.9), Color(0.5, 0.8, 1.0, 0)), Vector3(0, -1.6, 0), 180.0, Vector3.UP, 0.25 * size)
	_lamp(at, Color(0.6, 0.88, 1.0), 2.2, 5.0, 0.4)

# ------------------------------------------------------------------------------------------ OMBRE

func _shadow(target: Dictionary) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var dur := clampf(0.34 + start.distance_to(end) * 0.035, 0.38, 0.55)
	_orb(start, end, dur, _shadow_tex(), Color.WHITE, 0.5, Color(0.55, 0.2, 0.95, 0.5),
		_smoke_tex(), _ramp(Color(0.6, 0.4, 1.0, 0.0), Color(0.5, 0.3, 0.9, 0.7), Color(0.2, 0.05, 0.4, 0.0)), Vector2(0.28, 0.5), 0.2,
		func(): _shadow_burst(end, target), false)

func _shadow_burst(at: Vector3, target: Dictionary) -> void:
	var size := _tsize(target)
	# implosion : une sphère sombre se contracte en un point, puis relâche une onde violette
	var core := _sprite(_shadow_tex(), Color.WHITE, 1.3 * size, at)
	(core.mat as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	(core.mat as StandardMaterial3D).no_depth_test = true
	_add(core, 0.5, func(u: float):
		var s := 1.3 * size * (1.0 - u / 0.5) + 0.2 if u < 0.5 else 0.2 + (u - 0.5) / 0.5 * 1.8 * size
		(core.node as Node3D).scale = Vector3.ONE * s
		(core.mat as StandardMaterial3D).albedo_color.a = 1.0 if u < 0.6 else maxf(0.0, 1.0 - (u - 0.6) / 0.4))
	_later(0.2, func():
		_flash(_arcane_tex(), Color(0.7, 0.4, 1.0, 1.0), at, 0.4 * size, 2.4 * size, 0.3, true)
		_ring("ring_shadow", Color(0.6, 0.25, 1.0), at, 0.4 * size, 2.5 * size, 0.42))
	var star := _sprite(_rays_tex(), Color(0.55, 0.25, 0.95, 0.9), 1.0, at)
	_add(star, 0.6, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.4 + u * 2.2) * size
		(star.node as Node3D).rotation.z = -u * 0.8
		(star.mat as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - u) * minf(1.0, u * 6.0))
	# volutes sombres qui s'élèvent
	_emit(at, _smoke_tex(), 9, 0.9, 0.3, 0.9, 0.5, 0.9,
		_ramp(Color(0.5, 0.3, 0.8, 0.0), Color(0.45, 0.25, 0.75, 0.7), Color(0.1, 0.0, 0.2, 0.0)), Vector3(0, 0.5, 0), 70.0, Vector3.UP, 0.2 * size, true, false)
	_emit(at, _spark_tex(), 20, 0.7, 1.2, 3.0, 0.06, 0.14,
		_ramp(Color(0.9, 0.7, 1.0, 1), Color(0.6, 0.3, 1.0, 0.9), Color(0.3, 0.1, 0.7, 0)), Vector3(0, 0.4, 0), 180.0, Vector3.UP, 0.1 * size)
	_lamp(at, Color(0.55, 0.25, 0.95), 1.8, 5.0, 0.45)

# ------------------------------------------------------------------------------------------ PHYSIQUE

func _slash(target: Dictionary, spell_id: String) -> void:
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var n := 2 if (spell_id.contains("blade") or spell_id.contains("assassin") or spell_id.contains("thief") or spell_id.contains("berserker")) else 1
	for i in n:
		var dir_sign := 1.0 if i == 0 else -1.0
		var ang0 := deg_to_rad(-55.0 * dir_sign - 10.0 * i)
		var cr := _sprite(_crescent_tex(), Color(1.0, 0.96, 0.82, 1.0), 1.1 * size, at)
		(cr.mat as StandardMaterial3D).no_depth_test = true
		(cr.node as Node3D).visible = false
		_later(0.09 * i, func():
			if not is_instance_valid(cr.node):
				return
			(cr.node as Node3D).visible = true
			_add(cr, 0.22, func(u: float):
				var e := 1.0 - pow(1.0 - u, 3.0)
				var sweep := (e - 0.5) * 1.4 * size
				var d := right * cos(ang0) * dir_sign + up * sin(ang0)
				(cr.node as Node3D).position = at + d * sweep * 0.0 + right * sweep * 0.55 * dir_sign - up * sweep * 0.45
				(cr.node as Node3D).rotation.z = ang0 + e * deg_to_rad(95.0) * dir_sign
				(cr.node as Node3D).scale = Vector3(1.0 + e * 0.5, 0.8, 1.0) * 1.1 * size
				(cr.mat as StandardMaterial3D).albedo_color.a = (1.0 - u * u)))
	_later(0.1, func(): _hit_sparks(at, target))

func _hit_sparks(at: Vector3, target: Dictionary) -> void:
	var size := _tsize(target)
	_flash(_spark_tex(), Color(1.0, 0.95, 0.8, 1.0), at, 0.4 * size, 1.6 * size, 0.18)
	_emit(at, _spark_tex(), 22, 0.45, 2.0 * size, 4.8 * size, 0.07, 0.15,
		_ramp(Color(1, 1, 0.9, 1), Color(1, 0.8, 0.4, 0.9), Color(1, 0.5, 0.1, 0)), Vector3(0, -4.5, 0), 180.0, Vector3.UP, 0.05)
	_emit(at, _smoke_tex(), 3, 0.5, 0.2, 0.6, 0.4, 0.7,
		_ramp(Color(0.9, 0.85, 0.7, 0), Color(0.8, 0.75, 0.6, 0.35), Color(0.6, 0.55, 0.45, 0)), Vector3.ZERO, 180.0, Vector3.UP, 0.1, true, false)

## Flèche : un trait lumineux rapide, sans cloche.
func _arrow(target: Dictionary) -> void:
	var start := _start_point() + cam.global_transform.basis.x * 1.1     # part du côté : le trait se lit en diagonale
	var end := _end_point(target)
	var up := cam.global_transform.basis.y
	var dur := clampf(0.2 + start.distance_to(end) * 0.025, 0.24, 0.36)
	var mesh := _shard_pal("arrow", Color(1, 1, 0.95), Color(0.95, 0.88, 0.62), Color(0.7, 0.55, 0.3))
	var body := _mesh_sprite(mesh, start, Vector3(1.0, 1.0, 3.4))
	var trail := _particles(36, 0.28, false, _quad(_spark_tex()), _ramp(Color(1, 0.95, 0.7, 0), Color(1, 0.88, 0.5, 0.85), Color(1, 0.7, 0.3, 0)))
	trail.spread = 20.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.2
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.22
	trail.position = start
	add_child(trail)
	trail.emitting = true
	_add({"node": body}, dur, func(u: float):
		var pos := start.lerp(end, u)
		body.position = pos
		body.look_at(end + (end - start), up)
		trail.position = pos
		if u >= 1.0:
			body.queue_free()
			_stop_emitter(trail, 0.3)
			_hit_sparks(end, target))

# ------------------------------------------------------------------------------------------ BARDE

func _sonic(target: Dictionary, col: Color) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	# ondes sonores qui partent du bas de l'écran vers la cible
	for i in 3:
		_later(0.07 * i, func():
			var r := _sprite(_ring_tex_tint("ring_bard", col), Color(1, 1, 1, 0.8), 0.4, start)
			(r.mat as StandardMaterial3D).no_depth_test = true
			_add(r, 0.38, func(u: float):
				(r.node as Node3D).position = start.lerp(end, u)
				(r.node as Node3D).scale = Vector3.ONE * (0.4 + u * 1.3)
				(r.mat as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - u * u)))
	# notes qui filent vers la cible en ondulant
	for i in 4:
		var note := _sprite(_note_tex(), Color(col.lerp(Color(1, 0.9, 0.5), 0.35), 1.0), 0.3, start)
		(note.mat as StandardMaterial3D).no_depth_test = true
		var off := (float(i) - 1.5) * 0.28
		var delay := 0.05 * i
		var ph := randf() * TAU
		_add(note, 0.42 + delay, func(u: float):
			var w := clampf((u * (0.42 + delay) - delay) / 0.42, 0.0, 1.0)
			var k := w * w * (1.4 - 0.4 * w)
			(note.node as Node3D).position = start.lerp(end, k) + right * (off * (1.0 - k)) + up * (sin(k * 9.0 + ph) * 0.12 * (1.0 - k) + sin(k * PI) * 0.15)
			(note.node as Node3D).rotation.z = sin(k * 7.0 + ph) * 0.35
			(note.mat as StandardMaterial3D).albedo_color.a = 1.0 if w < 0.9 else (1.0 - w) * 10.0)
	_later(0.4, func(): _sonic_burst(end, target, col))

func _sonic_burst(at: Vector3, target: Dictionary, col: Color) -> void:
	var size := _tsize(target)
	_flash(_arcane_tex(), Color(col, 0.85), at, 0.4 * size, 2.2 * size, 0.26)
	_ring("ring_bard", col, at, 0.4 * size, 2.2 * size, 0.4)
	_later(0.07, func(): _ring("ring_bard", col, at, 0.3 * size, 1.6 * size, 0.34))
	for i in 5:
		var note := _sprite(_note_tex(), Color(col.lerp(Color(1, 0.9, 0.6), 0.4), 1.0), 0.28, at)
		(note.mat as StandardMaterial3D).no_depth_test = true
		var ang := randf() * TAU
		var vel := Vector3(cos(ang), sin(ang) * 0.8 + 0.4, 0.0) * randf_range(0.9, 1.7) * size
		_add(note, 0.55, func(u: float):
			(note.node as Node3D).position = at + cam.global_transform.basis.x * vel.x * u * 0.55 + cam.global_transform.basis.y * (vel.y * u * 0.55 + u * u * 0.3)
			(note.node as Node3D).rotation.z = ang * 0.2 + u * 1.2
			(note.mat as StandardMaterial3D).albedo_color.a = 1.0 - u * u)

# ------------------------------------------------------------------------------------------ GÉNÉRIQUE

func _generic(target: Dictionary, col: Color) -> void:
	var start := _start_point()
	var end := _end_point(target)
	var dur := clampf(0.3 + start.distance_to(end) * 0.035, 0.34, 0.5)
	_orb(start, end, dur, _arcane_tex(), Color(col.lerp(Color.WHITE, 0.5), 1.0), 0.6, Color(col, 0.6),
		_spark_tex(), _ramp(Color(col, 0.0), Color(col, 0.8), Color(col, 0.0)), Vector2(0.1, 0.22), 0.15,
		func(): _generic_burst(end, target, col))

func _generic_burst(at: Vector3, target: Dictionary, col: Color) -> void:
	var size := _tsize(target)
	_flash(_arcane_tex(), Color(col.lerp(Color.WHITE, 0.6), 1.0), at, 0.4 * size, 2.2 * size, 0.28)
	_ring("ring_gen_%s" % col.to_html(false), col, at, 0.4 * size, 2.0 * size, 0.38)
	_emit(at, _spark_tex(), 22, 0.55, 1.2 * size, 3.2 * size, 0.07, 0.15,
		_ramp(Color(1, 1, 1, 1), Color(col, 0.9), Color(col, 0)), Vector3(0, -1.5, 0), 180.0, Vector3.UP, 0.08)

# ------------------------------------------------------------------------------------------ SOUTIEN

func _tint_for(kind: String) -> Color:
	match kind:
		"fountain": return Color(0.4, 0.82, 1.0)
		"haste": return Color(0.55, 0.95, 1.0)
		"stamina": return Color(0.45, 0.95, 0.85)
		"vigor": return Color(1.0, 0.82, 0.4)
		_: return Color(0.6, 1.0, 0.6)

## Gerbe de lumière qui monte sur le(s) héros ciblé(s) : croix de soin, particules, anneau au sol de la vue.
func _heal(ctx: Dictionary, party: bool, kind: String) -> void:
	var slots: Array = [0, 1, 2, 3] if party else [int(ctx.get("ally", ctx.get("caster", 1)))]
	var col := _tint_for(kind)
	var i := 0
	for s in slots:
		var si: int = s
		_later(0.06 * i, func(): _heal_at(_slot_pos(si), col, kind))
		i += 1
	if party:
		var base := _slot_pos(1, 2.2).lerp(_slot_pos(2, 2.2), 0.5)
		_flash(_arcane_tex(), Color(col, 0.55), base, 1.5, 8.0, 0.6, true)

func _heal_at(at: Vector3, col: Color, kind: String) -> void:
	var up := cam.global_transform.basis.y
	_flash(_arcane_tex(), Color(col.lerp(Color.WHITE, 0.4), 0.9), at, 0.5, 2.0, 0.5, true)
	_ring("ring_heal_" + kind, col, at, 0.3, 1.6, 0.5)
	var fast := kind == "haste"
	_emit(at, _spark_tex(), 24, 0.9, 0.9 if not fast else 2.2, 2.0 if not fast else 4.0, 0.07, 0.16,
		_ramp(Color(col.lerp(Color.WHITE, 0.6), 0.0), Color(col, 0.95), Color(col, 0.0)), Vector3(0, 0.4, 0), 14.0, up, 0.32, true)
	for i in Settings.pc(6):
		var c := _sprite(_cross_tex() if kind != "stamina" else _arcane_tex(), Color(col.lerp(Color.WHITE, 0.5), 1.0), 0.22, at)
		(c.mat as StandardMaterial3D).no_depth_test = true
		var ox := randf_range(-0.45, 0.45)
		var delay := randf() * 0.25
		var ph := randf() * TAU
		_add(c, 0.9 + delay, func(u: float):
			var w := clampf((u * (0.9 + delay) - delay) / 0.9, 0.0, 1.0)
			(c.node as Node3D).position = at + cam.global_transform.basis.x * (ox + sin(w * 5.0 + ph) * 0.06) + up * (w * 1.5)
			(c.node as Node3D).scale = Vector3.ONE * 0.22 * (1.0 - w * 0.4)
			(c.mat as StandardMaterial3D).albedo_color.a = sin(w * PI) * 0.95)
	if kind == "haste":   # traits de vitesse horizontaux
		for i in 4:
			var st := _sprite(_beam_tex(), Color(0.7, 1.0, 1.0, 0.0), 0.01, at)
			(st.mat as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			var oy := randf_range(0.0, 0.8)
			_add(st, 0.35, func(u: float):
				(st.node as Node3D).position = at + up * oy + cam.global_transform.basis.x * ((u - 0.5) * 1.6)
				(st.node as Node3D).scale = Vector3(0.9, 0.05, 1.0)
				(st.node as Node3D).rotation.z = PI * 0.5
				(st.mat as StandardMaterial3D).albedo_color.a = sin(u * PI) * 0.8)
	if kind == "vigor":   # notes dorées
		for i in 3:
			var note := _sprite(_note_tex(), Color(1.0, 0.85, 0.45, 1.0), 0.26, at)
			(note.mat as StandardMaterial3D).no_depth_test = true
			var ox2 := randf_range(-0.4, 0.4)
			_add(note, 0.9, func(u: float):
				(note.node as Node3D).position = at + cam.global_transform.basis.x * (ox2 + sin(u * 6.0) * 0.08) + up * (u * 1.4)
				(note.mat as StandardMaterial3D).albedo_color.a = sin(u * PI))
	_lamp(at + _fwd() * -0.3, col, 1.4, 4.0, 0.5)

func _shield(ctx: Dictionary) -> void:
	var at := _slot_pos(int(ctx.get("ally", ctx.get("caster", 1))), 2.0)
	var col := Color(0.6, 0.85, 1.0)
	var dome := _sprite(_hex_tex(), Color(1, 1, 1, 0.0), 1.0, at + Vector3(0, 0.35, 0))
	(dome.mat as StandardMaterial3D).no_depth_test = true
	_add(dome, 0.8, func(u: float):
		var grow := 1.0 - pow(1.0 - clampf(u / 0.35, 0.0, 1.0), 3.0)
		(dome.node as Node3D).scale = Vector3.ONE * (0.3 + grow * 0.95)
		var a := 0.8 * minf(u / 0.15, 1.0) * (1.0 if u < 0.55 else (1.0 - (u - 0.55) / 0.45))
		(dome.mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, a))
	_flash(_arcane_tex(), Color(col, 0.7), at, 0.4, 2.0, 0.4, true)
	_ring("ring_shield", col, at, 0.4, 2.0, 0.5)
	_emit(at, _spark_tex(), 18, 0.7, 0.6, 1.6, 0.06, 0.13,
		_ramp(Color(1, 1, 1, 1), Color(col, 0.9), Color(col, 0)), Vector3.ZERO, 180.0, Vector3.UP, 0.4)
	_lamp(at, col, 1.4, 4.0, 0.5)

func _dispel(ctx: Dictionary) -> void:
	var at := _slot_pos(int(ctx.get("ally", ctx.get("caster", 1))), 2.1)
	var up := cam.global_transform.basis.y
	_flash(_arcane_tex(), Color(1, 1, 1, 0.9), at, 0.4, 2.2, 0.35, true)
	_ring("ring_dispel", Color(0.8, 0.92, 1.0), at, 0.3, 2.0, 0.45)
	_later(0.1, func(): _ring("ring_dispel", Color(0.8, 0.92, 1.0), at, 0.2, 1.4, 0.4))
	_emit(at, _spark_tex(), 22, 0.8, 0.8, 2.2, 0.06, 0.14,
		_ramp(Color(1, 1, 1, 1), Color(0.8, 0.92, 1.0, 0.9), Color(0.7, 0.85, 1.0, 0)), Vector3(0, 0.3, 0), 180.0, up, 0.15)
	# volutes sombres chassées vers le haut : les maux qui s'en vont
	_emit(at, _smoke_tex(), 7, 0.9, 0.8, 1.6, 0.4, 0.7,
		_ramp(Color(0.5, 0.4, 0.7, 0.0), Color(0.4, 0.3, 0.6, 0.6), Color(0.1, 0.05, 0.2, 0.0)), Vector3(0, 0.8, 0), 30.0, up, 0.2, true, false)

func _self_buff(ctx: Dictionary) -> void:
	var at := _slot_pos(int(ctx.get("caster", 1)), 2.1)
	var up := cam.global_transform.basis.y
	var col := Color(1.0, 0.6, 0.2)
	_flash(_fire_tex(), Color(1.0, 0.8, 0.45, 0.9), at, 0.5, 2.2, 0.5, true)
	_ring("ring_buff", col, at, 0.3, 1.8, 0.45)
	_emit(at, _fire_tex(), 26, 0.7, 0.8, 2.0, 0.22, 0.4,
		_ramp(Color(1, 0.9, 0.5, 0), Color(1, 0.5, 0.12, 0.9), Color(0.5, 0.06, 0.02, 0)), Vector3(0, 1.0, 0), 25.0, up, 0.3)
	_emit(at, _spark_tex(), 10, 0.8, 1.0, 2.4, 0.05, 0.1,
		_ramp(Color(1, 0.95, 0.7, 1), Color(1, 0.6, 0.2, 0.9), Color(1, 0.3, 0.05, 0)), Vector3(0, 0.8, 0), 30.0, up, 0.3)
	_lamp(at, col, 1.6, 4.0, 0.6)

## Berceuse : des « Z » bleutés montent au-dessus des monstres, avec une onde douce depuis le bas de la vue.
func _sleep(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty() and not target.is_empty():
		pts = [target]
	var base := cam.global_position + _fwd() * 2.4 - cam.global_transform.basis.y * 0.7
	var col := Color(0.6, 0.6, 1.0)
	_ring("ring_sleep", col, base, 0.6, 6.0, 0.6)
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	for t in pts:
		var tt: Dictionary = t
		var at := _toward_cam(tt.pos) + up * float(tt.get("h", 1.0)) * 0.3
		_flash(_arcane_tex(), Color(col, 0.6), at, 0.5, 2.0, 0.5)
		for i in 3:
			var lb := Label3D.new()
			lb.text = "Z" if i != 1 else "z"
			lb.font_size = 72
			lb.pixel_size = 0.012
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.no_depth_test = true
			lb.modulate = Color(0.85, 0.88, 1.0, 0.0)
			lb.outline_modulate = Color(0.25, 0.25, 0.7, 0.0)
			lb.outline_size = 10
			lb.position = at
			lb.render_priority = 6
			add_child(lb)
			var delay := 0.18 * i
			var dur := 1.0
			_add({"node": lb}, dur + delay, func(u: float):
				var w := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
				lb.position = at + right * (0.28 * float(i) - 0.2 + sin(w * 4.0) * 0.08) + up * (w * 1.1)
				lb.scale = Vector3.ONE * (0.5 + w * 0.7)
				var a := sin(w * PI)
				lb.modulate.a = a
				lb.outline_modulate.a = a * 0.8)
		_emit(at, _spark_tex(), 8, 0.9, 0.2, 0.7, 0.05, 0.1,
			_ramp(Color(0.8, 0.8, 1, 0), Color(0.7, 0.7, 1.0, 0.8), Color(0.5, 0.5, 1.0, 0)), Vector3(0, 0.3, 0), 180.0, up, 0.3)

# =====================================================================================================
# ACTIONS : coups d'arme, coups reçus, piège, interrupteur, fontaine (remplacent l'ancien emoji animé 2D).
# =====================================================================================================

const ACTIONS := ["sword", "dagger", "axe", "mace", "staff", "bow", "unarmed", "hit", "trap", "switch", "fountain"]

static func has_action(kind: String) -> bool:
	return ACTIONS.has(kind)

static func cast_action(host: Node, camera: Camera3D, kind: String, target: Dictionary) -> void:
	if camera == null or not ACTIONS.has(kind):
		return
	var fx := SpellFxStyles.new()
	fx.name = "ActionFx"
	fx.cam = camera
	host.add_child(fx)
	fx._action(kind, target)
	fx._started = true

func _action(kind: String, target: Dictionary) -> void:
	match kind:
		"sword": _wp_sword(target)
		"dagger": _wp_dagger(target)
		"axe": _wp_axe(target)
		"mace": _wp_mace(target)
		"staff": _wp_staff(target)
		"bow": _arrow(target)
		"unarmed": _wp_punch(target)
		"hit": _party_hit()
		"trap": _trap_fx()
		"switch": _switch_fx()
		"fountain": _heal({"ally": 1}, true, "fountain")

## Croissant de lame : balaie le centre du monstre selon `ang0` (rad), puis étincelles.
func _blade_arc(at: Vector3, size: float, tint: Color, ang0: float, sweep_vec: Vector2, delay: float, dur: float, grow: float) -> void:
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var cr := _sprite(_crescent_tex(), Color(tint, 0.0), 1.1 * size, at)
	(cr.mat as StandardMaterial3D).no_depth_test = true
	_later(delay, func():
		if not is_instance_valid(cr.node):
			return
		_add(cr, dur, func(u: float):
			var e := 1.0 - pow(1.0 - u, 3.0)
			var k := e - 0.5
			(cr.node as Node3D).position = at + right * (sweep_vec.x * k * size) + up * (sweep_vec.y * k * size)
			(cr.node as Node3D).rotation.z = ang0 + e * deg_to_rad(95.0) * signf(sweep_vec.x if sweep_vec.x != 0.0 else 1.0)
			(cr.node as Node3D).scale = Vector3(1.0 + e * grow, 0.8, 1.0) * 1.1 * size
			(cr.mat as StandardMaterial3D).albedo_color = Color(tint, minf(1.0, u * 10.0) * (1.0 - u * u))))

func _wp_sword(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0)
	_blade_arc(at, size, Color(0.88, 0.95, 1.0), deg_to_rad(-55.0), Vector2(0.77, -0.63), 0.0, 0.2, 0.5)
	_later(0.08, func(): _hit_sparks(at, target))

func _wp_dagger(target: Dictionary) -> void:
	# deux estocades rapides en X : petits croissants fins, puis étincelles
	var at := _end_point(target)
	var size := _tsize(target, 0.8, 0.9, 2.0)
	_blade_arc(at, size * 0.7, Color(0.9, 0.97, 1.0), deg_to_rad(-40.0), Vector2(0.9, -0.9), 0.0, 0.14, 0.2)
	_blade_arc(at, size * 0.7, Color(0.9, 0.97, 1.0), deg_to_rad(40.0), Vector2(-0.9, -0.9), 0.09, 0.14, 0.2)
	_later(0.06, func(): _flash(_spark_tex(), Color(1, 1, 1, 1), at, 0.2 * size, 0.9 * size, 0.14))
	_later(0.14, func(): _hit_sparks(at, target))

func _wp_axe(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target, 0.9, 1.0, 2.2)
	_blade_arc(at, size * 1.2, Color(1.0, 0.85, 0.55), deg_to_rad(80.0), Vector2(0.0, -1.7), 0.0, 0.24, 0.4)
	_later(0.1, func():
		_hit_sparks(at, target)
		_flash(_arcane_tex(), Color(1.0, 0.8, 0.5, 0.8), at, 0.5 * size, 2.4 * size, 0.24)
		_emit(at - cam.global_transform.basis.y * 0.5, _smoke_tex(), 4, 0.5, 0.3, 0.8, 0.5, 0.8,
			_ramp(Color(0.8, 0.7, 0.55, 0), Color(0.75, 0.65, 0.5, 0.45), Color(0.5, 0.45, 0.35, 0)), Vector3.ZERO, 180.0, Vector3.UP, 0.2, true, false))

func _wp_mace(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target, 0.9, 1.0, 2.2)
	_flash(_arcane_tex(), Color(1.0, 0.92, 0.7, 1.0), at, 0.5 * size, 2.8 * size, 0.26)
	_ring("ring_mace", Color(1.0, 0.85, 0.5), at, 0.3 * size, 2.2 * size, 0.34)
	_later(0.06, func(): _ring("ring_mace", Color(1.0, 0.85, 0.5), at, 0.2 * size, 1.5 * size, 0.3))
	_emit(at, _spark_tex(), 20, 0.5, 2.0 * size, 4.4 * size, 0.07, 0.16,
		_ramp(Color(1, 1, 0.85, 1), Color(1, 0.75, 0.35, 0.9), Color(1, 0.5, 0.1, 0)), Vector3(0, -5.0, 0), 180.0, Vector3.UP, 0.06)
	_emit(at, _smoke_tex(), 5, 0.6, 0.4, 1.0, 0.6, 1.0,
		_ramp(Color(0.8, 0.7, 0.55, 0), Color(0.75, 0.65, 0.5, 0.5), Color(0.5, 0.45, 0.35, 0)), Vector3.ZERO, 180.0, Vector3.UP, 0.25 * size, true, false)

func _wp_staff(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target)
	_flash(_arcane_tex(), Color(0.85, 0.8, 1.0, 1.0), at, 0.4 * size, 1.9 * size, 0.24)
	var star := _sprite(_rays_tex(), Color(0.8, 0.75, 1.0, 0.9), 1.0, at)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, 0.3, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.4 + u * 1.2) * size
		(star.node as Node3D).rotation.z = u * 0.6
		(star.mat as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - u))
	_ring("ring_staff", Color(0.75, 0.65, 1.0), at, 0.3 * size, 1.6 * size, 0.3)
	_emit(at, _spark_tex(), 10, 0.5, 1.0 * size, 2.6 * size, 0.06, 0.13,
		_ramp(Color(1, 1, 1, 1), Color(0.75, 0.65, 1.0, 0.9), Color(0.5, 0.4, 1.0, 0)), Vector3(0, -1.0, 0), 180.0, Vector3.UP, 0.05)

func _wp_punch(target: Dictionary) -> void:
	var at := _end_point(target)
	var size := _tsize(target)
	var star := _sprite(_rays_tex(), Color(1.0, 0.9, 0.6, 0.95), 1.0, at)
	(star.mat as StandardMaterial3D).no_depth_test = true
	_add(star, 0.28, func(u: float):
		(star.node as Node3D).scale = Vector3.ONE * (0.5 + (1.0 - pow(1.0 - u, 2.0)) * 1.6) * size
		(star.node as Node3D).rotation.z = 0.2
		(star.mat as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - u))
	_flash(_arcane_tex(), Color(1.0, 0.95, 0.8, 1.0), at, 0.4 * size, 1.8 * size, 0.2)
	_ring("ring_punch", Color(1.0, 0.85, 0.5), at, 0.2 * size, 1.4 * size, 0.28)
	_emit(at, _spark_tex(), 8, 0.4, 1.5 * size, 3.5 * size, 0.06, 0.12,
		_ramp(Color(1, 1, 0.9, 1), Color(1, 0.8, 0.45, 0.9), Color(1, 0.5, 0.1, 0)), Vector3(0, -4.0, 0), 180.0, Vector3.UP, 0.04)

## Coup reçu par le groupe : trois griffures rouges en travers de la vue + voile rouge qui s'estompe.
func _party_hit() -> void:
	var right := cam.global_transform.basis.x
	var up := cam.global_transform.basis.y
	var base := cam.global_position + _fwd() * 1.6 - up * 0.15
	var veil := _sprite(_arcane_tex(), Color(1.0, 0.1, 0.05, 0.0), 6.0, cam.global_position + _fwd() * 1.2)
	(veil.mat as StandardMaterial3D).no_depth_test = true
	_add(veil, 0.4, func(u: float):
		(veil.mat as StandardMaterial3D).albedo_color.a = 0.45 * (1.0 - u) * minf(1.0, u * 12.0))
	for i in 3:
		var off := (float(i) - 1.0) * 0.5
		var cr := _sprite(_crescent_tex(), Color(1.0, 0.25, 0.2, 0.0), 1.5, base + right * off)
		(cr.mat as StandardMaterial3D).no_depth_test = true
		var delay := 0.05 * i
		_later(delay, func():
			if not is_instance_valid(cr.node):
				return
			_add(cr, 0.26, func(u: float):
				var e := 1.0 - pow(1.0 - u, 3.0)
				(cr.node as Node3D).position = base + right * (off + (e - 0.5) * 0.5) + up * ((0.5 - e) * 0.9)
				(cr.node as Node3D).rotation.z = deg_to_rad(40.0) + e * 0.3
				(cr.node as Node3D).scale = Vector3(0.55, 1.5, 1.0) * 1.3
				(cr.mat as StandardMaterial3D).albedo_color = Color(1.0, 0.3, 0.22, minf(1.0, u * 8.0) * (1.0 - u * u))))
	_emit(base, _spark_tex(), 10, 0.5, 1.0, 3.0, 0.06, 0.13,
		_ramp(Color(1, 0.7, 0.6, 1), Color(1, 0.25, 0.2, 0.9), Color(0.8, 0.1, 0.05, 0)), Vector3(0, -2.0, 0), 180.0, Vector3.UP, 0.3)

func _trap_fx() -> void:
	var at := cam.global_position + _fwd() * 1.8 - cam.global_transform.basis.y * 0.5
	_flash(_arcane_tex(), Color(1.0, 0.25, 0.15, 0.9), at, 0.6, 4.0, 0.4, true)
	_ring("ring_trap", Color(1.0, 0.3, 0.2), at, 0.4, 3.0, 0.4)
	_emit(at, _spark_tex(), 16, 0.6, 1.5, 4.0, 0.07, 0.15,
		_ramp(Color(1, 0.8, 0.6, 1), Color(1, 0.3, 0.2, 0.9), Color(0.7, 0.1, 0.05, 0)), Vector3(0, -3.0, 0), 180.0, Vector3.UP, 0.1)

func _switch_fx() -> void:
	var at := cam.global_position + _fwd() * 2.0
	var col := Color(0.9, 0.75, 0.4)
	_flash(_arcane_tex(), Color(col, 0.8), at, 0.4, 2.0, 0.35, true)
	_ring("ring_switch", col, at, 0.3, 1.8, 0.4)
	_emit(at, _spark_tex(), 10, 0.5, 0.8, 2.2, 0.06, 0.12,
		_ramp(Color(1, 0.95, 0.7, 1), Color(col, 0.9), Color(col, 0)), Vector3(0, -1.0, 0), 180.0, Vector3.UP, 0.05)
