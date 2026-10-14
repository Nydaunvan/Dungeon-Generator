extends "res://scripts/dungeon/spell_fx_kit.gd"
## Effets de feu (Forward+ / Vulkan) : boule de feu, météore, colonne de feu. Palette orange et rouge, la teinte du sort la fait tourner.
## Feu = plasma qui bouillonne (bruit 3D), flammes volumétriques, fumée sombre qui assombrit vraiment l'image, braises à traînée,
## brûlure incandescente au sol, lumière chaude qui éclaire la brume, onde de chaleur qui déforme l'écran.

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	_base_hue = 0.075
	if _tier >= 2:
		GLYPHS.scorch()
	match str(ctx.get("fx", "fire_ball")):
		"fire_meteor":
			_meteor(target, ctx)
		"fire_column":
			_column(target)
		_:
			_ball(target)

func _hot() -> Color:
	return _c(1.0, 0.95, 0.72)

func _mid() -> Color:
	return _c(1.0, 0.5, 0.1)

func _rim() -> Color:
	return _c(0.62, 0.08, 0.02)

func _flame_trail(n: int, life: float, sz: Array, v: Array, rise: float, radius: float) -> Dictionary:
	return {"c": [_c(1, 0.9, 0.5, 0.0), _c(1, 0.5, 0.12, 0.9), _c(0.45, 0.05, 0.02, 0.0)], "n": n, "life": life, "sz": sz, "v": v,
		"grav": Vector3(0, rise, 0), "turb": 0.8, "k": 1.1, "radius": radius, "tex": _flame_puff(), "damp": 0.8}

func _smoke_trail(n: int, life: float, sz: Array, radius: float) -> Dictionary:
	return {"c": [_c(0.4, 0.35, 0.3, 0.0), _c(0.22, 0.18, 0.16, 0.5), _c(0.08, 0.07, 0.06, 0.0)], "n": n, "life": life, "sz": sz, "v": [0.1, 0.4],
		"grav": Vector3(0, 0.7, 0), "mix": true, "radius": radius, "turb": 0.5, "tex": _smoke_puff()}

func _ember_trail(n: int, life: float) -> Dictionary:
	return {"c": [_c(1, 0.95, 0.7, 1.0), _c(1, 0.6, 0.2, 0.9), _c(1, 0.3, 0.05, 0.0)], "n": n, "life": life, "sz": [0.04, 0.09], "v": [0.3, 1.3],
		"grav": Vector3(0, 0.6, 0), "k": 1.6, "radius": 0.1}

## Impact de feu : éclair, boule de plasma qui gonfle, ondes, braises à traînée, flammèches, fumée, brûlure, lumière, secousse.
func _fire_hit(at: Vector3, target: Dictionary, big: float = 1.0, debris: bool = false) -> void:
	var size := _tsize(target) * big * _s
	var p := {
		"size": big,
		"flash": [_c(1.0, 0.92, 0.65), 1.2],
		"shocks": [[_c(1.0, 0.5, 0.12), 2.8, 0.5], [_c(1.0, 0.8, 0.4), 1.8, 0.35, 0.07]],
		"ground": [_c(1.0, 0.45, 0.1), 3.2, 0.6],
		"lens": [3.4, 0.09],
		"ribbons": {"c": [_c(1, 0.95, 0.75, 1.0), _c(1, 0.55, 0.15, 0.9), _c(0.9, 0.2, 0.05, 0.0)], "n": 22, "v": [2.0, 5.5], "grav": Vector3(0, -3.0, 0), "life": 0.8},
		"sparks": {"c": [_c(1, 0.95, 0.7, 1.0), _c(1, 0.6, 0.2, 0.9), _c(0.9, 0.25, 0.05, 0.0)], "n": 28, "v": [0.8, 3.2], "grav": Vector3(0, 0.4, 0), "life": 0.9},
		"smoke": [
			{"c": [_c(1, 0.8, 0.4, 0.0), _c(1, 0.45, 0.1, 0.55), _c(0.5, 0.06, 0.02, 0.0)], "n": 8, "sz": [0.6, 1.1], "rise": 1.2, "life": 0.9, "add": true},
			{"c": [_c(0.34, 0.3, 0.27, 0.0), _c(0.22, 0.19, 0.17, 0.5), _c(0.05, 0.05, 0.05, 0.0)], "n": 14, "sz": [0.5, 0.95], "rise": 0.9, "life": 1.5, "y": 0.2},
		],
		"decal": [GLYPHS.scorch(), _c(1.0, 0.5, 0.12), 1.2 * big, 1.5],
		"lamp": [_c(1.0, 0.55, 0.2), 3.4, 6.5, 0.6],
		"shake": 0.045 * big,
	}
	if debris:
		var mesh := _shard_pal("fxf_debris_%d" % (int(_tint_h * 100.0) if _tinted else -1), _c(1.0, 0.8, 0.4), _c(0.55, 0.22, 0.08), _c(0.12, 0.06, 0.04))
		p["shards"] = {"mesh": mesh, "n": 12, "v": [2.5, 6.0], "sz": [0.25, 0.6]}
	_hit_fx(at, target, p)
	_bloom(at, 1.8 * size, 0.6, _hot(), _mid(), _rim(), false, 0.3)
	_bloom(at + Vector3(0.18, 0.12, 0.0) * size, 1.2 * size, 0.5, _hot(), _mid(), _rim(), false, 0.5, 0.05)

# ------------------------------------------------------------------------------------------ BOULE DE FEU

func _ball(target: Dictionary) -> void:
	var start := _start_point() + cam.global_transform.basis.x * 0.15
	var end := _end_point(target)
	var dur := clampf(0.38 + start.distance_to(end) * 0.035, 0.42, 0.6)
	_fly(start, end, dur, {
		"body": {"kind": "plasma", "size": 0.42, "hot": _hot(), "mid": _mid(), "rim": _rim()},
		"halo": [_c(1.0, 0.5, 0.12, 0.5), 1.4],
		"core": 0.1, "arc": 0.16, "lift": 0.18, "ease": "accel", "grow": 0.45, "orient": false,
		"trails": [_flame_trail(60, 0.42, [0.22, 0.5], [0.1, 0.6], 1.1, 0.1), _smoke_trail(14, 0.7, [0.3, 0.55], 0.1), _ember_trail(22, 0.5)],
		"lamp": [_c(1.0, 0.55, 0.2), 2.4, 5.0], "lens": [1.8, 0.05],
	}, func(): _fire_hit(end, target))

# ------------------------------------------------------------------------------------------ MÉTÉORE

func _meteor(target: Dictionary, ctx: Dictionary) -> void:
	var pts: Array = ctx.get("targets", [])
	if pts.is_empty():
		pts = [target]
	var i := 0
	for t in pts:
		var tt: Dictionary = t
		_later(0.16 * float(i), func(): _meteor_one(tt))
		i += 1

func _meteor_one(target: Dictionary) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	var end := _end_point(target)
	var start := end + up * 6.0 - right * 3.2 + _fwd() * 2.2
	var node := Node3D.new()
	var rm := _smat("rock", SH_ROCK, 5).duplicate() as ShaderMaterial
	rm.set_shader_parameter("stone", _c(0.12, 0.07, 0.05))
	rm.set_shader_parameter("lava", _mid())
	rm.set_shader_parameter("power", _g)
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_mesh(5)
	rock.material_override = rm
	rock.scale = Vector3.ONE * 1.0
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(rock)
	var dur := 0.55
	_fly(start, end, dur, {
		"body": {"kind": "mesh", "node": node, "size": 0.9},
		"halo": [_c(1.0, 0.5, 0.12, 0.7), 2.4],
		"core": 0.0, "arc": 0.0, "lift": 0.0, "ease": "accel", "grow": 0.2, "orient": false, "spin": 5.0,
		"trails": [_flame_trail(90, 0.7, [0.45, 1.0], [0.1, 0.7], 0.8, 0.2), _smoke_trail(26, 1.0, [0.6, 1.1], 0.2), _ember_trail(34, 0.7)],
		"lamp": [_c(1.0, 0.5, 0.15), 3.0, 7.0], "lens": [2.6, 0.06],
	}, func(): _fire_hit(end, target, 1.35, true))

# ------------------------------------------------------------------------------------------ COLONNE DE FEU

func _column(target: Dictionary) -> void:
	var at := _end_point(target)
	var base := Vector3(at.x, 0.04, at.z)
	var size := _tsize(target) * _s
	var tall := 4.6
	# 1. la brûlure se grave au sol, des braises montent du cercle
	_glyph_decal(target, GLYPHS.scorch(), _c(1.0, 0.5, 0.12), 1.3 * size, 1.5, 0.6, 4.0)
	_ground_shock(base, _c(1.0, 0.45, 0.1), 2.6 * size, 0.5)
	var ring_pm := _pmat(0.05, Vector3.UP, 12.0, 0.5, 1.6, Vector3(0, 0.8, 0), 0.05, 0.1, _ramp(_c(1, 0.9, 0.5, 1.0), _c(1, 0.5, 0.12, 0.9), _c(0.8, 0.2, 0.05, 0.0)), 0.5, 0.5)
	ring_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	ring_pm.emission_ring_axis = Vector3.UP
	ring_pm.emission_ring_radius = 1.0 * size
	ring_pm.emission_ring_inner_radius = 0.7 * size
	ring_pm.emission_ring_height = 0.05
	_free_after(_gpu(40, 0.8, true, _soft_mesh(_mid(), 1.5 * _g, _w_spark()), ring_pm, base), 1.0)
	var lamp := _lamp_node(base + Vector3(0, 1.6, 0), _c(1.0, 0.5, 0.15), 0.5, 9.0)
	# 2. la colonne jaillit : trois langues de flamme qui se superposent, plus un tourbillon de braises
	_later(0.3, func(): _column_burst(base, size, tall, lamp))
	_shake(0.0, 0.01)

func _column_burst(base: Vector3, size: float, tall: float, lamp: OmniLight3D) -> void:
	var flames := [[3.6, 1.0, 0.0, 0.0], [2.6, 0.9, 3.7, 0.06], [4.6, 0.78, 7.3, 0.12]]
	var dur := 1.15
	for fl in flames:
		var w: float = float(fl[0]) * size
		var hh: float = tall * float(fl[1])
		var seed_v: float = fl[2]
		var delay: float = fl[3]
		_pillar(base, w, hh, SH_FLAME, "flame", {"hot": _c(1.0, 0.8, 0.45), "mid": _mid(), "edge": _rim(), "power": 0.5 * _g, "seed": seed_v, "fade": 0.0, "taper": 1.0 + seed_v * 0.05},
			dur + delay, func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
				var t := clampf((u * (dur + delay) - delay) / dur, 0.0, 1.0)
				var rise := 1.0 - pow(1.0 - clampf(t / 0.22, 0.0, 1.0), 3.0)
				var fall := 1.0 - clampf((t - 0.72) / 0.28, 0.0, 1.0)
				var flick := 1.0 + sin(t * 40.0 + seed_v) * 0.04
				mi.scale = Vector3(w * (0.55 + 0.45 * rise) * (0.6 + 0.4 * fall), hh * rise * flick * (0.3 + 0.7 * fall), 1.0)
				mi.position = Vector3(base.x, base.y + mi.scale.y * 0.5, base.z)
				m.set_shader_parameter("fade", minf(1.0, t * 14.0) * fall))
	_bloom(base + Vector3(0, 0.35, 0), 1.5 * size, 0.7, _hot(), _mid(), _rim(), false, 0.4)
	_flash(_w_soft(), _hdr(_c(1.0, 0.85, 0.5), 1.4 * _g), base + Vector3(0, 0.8, 0), 0.6 * size, 3.6 * size, 0.35)
	_shock(base + Vector3(0, 0.5, 0), _c(1.0, 0.55, 0.15), 3.2 * size, 0.5)
	# tourbillon de braises qui monte en spirale, flammes volumétriques, fumée au sommet
	var pm := _pmat(0.05, Vector3.UP, 8.0, 3.0, 5.5, Vector3(0, 0.5, 0), 0.05, 0.11, _ramp(_c(1, 0.95, 0.7, 1.0), _c(1, 0.55, 0.15, 0.9), _c(0.9, 0.25, 0.05, 0.0)), 0.3, 0.7)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.75 * size
	pm.emission_ring_inner_radius = 0.3 * size
	pm.emission_ring_height = 0.1
	pm.orbit_velocity_min = 0.45
	pm.orbit_velocity_max = 0.8
	var embers := _gpu(70, 1.0, false, _soft_mesh(_mid(), 1.7 * _g, _w_spark()), pm, base)
	var vol := _gpu(34, 0.8, false, _soft_mesh(_mid(), 0.7 * _g, _flame_puff()),
		_pmat_grow(0.5 * size, Vector3.UP, 12.0, 1.5, 3.0, Vector3(0, 1.0, 0), 0.7 * size, 1.2 * size, _ramp(_c(1, 0.8, 0.4, 0.0), _c(1, 0.45, 0.1, 0.5), _c(0.5, 0.06, 0.02, 0.0)), 0.3, 0.5), base)
	var smoke := _gpu(14, 1.6, false, _smoke_mesh(Color.WHITE, _smoke_puff()),
		_pmat_grow(0.6 * size, Vector3.UP, 20.0, 0.4, 1.0, Vector3(0, 0.8, 0), 1.0 * size, 1.8 * size, _ramp(_c(0.3, 0.26, 0.23, 0.0), _c(0.16, 0.14, 0.12, 0.7), _c(0.05, 0.05, 0.05, 0.0)), 0.5, 0.6), base + Vector3(0, tall * 0.7, 0))
	_lens(base + Vector3(0, 1.8, 0), 4.0 * size, 0.06 * _pw, dur)
	if lamp != null:
		var tw := create_tween()
		tw.tween_property(lamp, "light_energy", 4.5 * _g, 0.25)
		tw.tween_interval(0.5)
		tw.tween_property(lamp, "light_energy", 0.0, 0.5)
		tw.tween_callback(lamp.queue_free)
		_keep(1.4)
	_shake(0.035 * _pw, 0.5)
	_later(dur * 0.75, func():
		embers.emitting = false
		vol.emitting = false
		smoke.emitting = false
		_free_after(embers, 1.2)
		_free_after(vol, 1.0)
		_free_after(smoke, 2.0))
