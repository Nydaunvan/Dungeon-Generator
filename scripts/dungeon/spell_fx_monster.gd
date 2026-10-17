extends "res://scripts/dungeon/spell_fx_nature.gd"
## Capacités des monstres (Forward+ / Vulkan) : le sort part du monstre et frappe le héros visé (sa place dans le groupe, en bas de l'écran).
## Même palette et même esprit que l'école du sort, mais quatre familles de mise en scène, choisies d'après l'effet du sort :
##   projectile (boule, éclat de glace, épine, orbe…), pluie (plusieurs projectiles qui tombent du haut sur le groupe),
##   éclat (pilier ou explosion sur le héros visé), griffes (traits de lame et gerbe d'étincelles).
## Contexte : `style`, `fx`, `fxTint`, `fxPower` comme pour un sort de héros, plus `fromMonster: true` et `victim` (place du héros, 0 à 3).
## Le monstre « charge » le sort un instant (lueur et onde à sa position) avant que le coup ne parte.

const RAIN_FX := ["fire_meteor", "ice_hail", "shadow_apocalypse", "holy_judgment"]
const BURST_FX := ["fire_column", "holy_light", "holy_smite", "holy_aura", "holy_purify", "holy_anathema", "nature_vines", "nature_lightning",
	"shadow_curse", "shadow_pact", "shadow_drain", "shadow_orb"]
const CLAW_FX := ["shadow_fatal", "shadow_step", "shadow_execute", "shadow_blade", "shadow_ambush", "shadow_flurry"]

func play(_spell_id: String, target: Dictionary, ctx: Dictionary) -> void:
	_begin(ctx)
	var school := str(ctx.get("style", "arcane"))
	var fx := str(ctx.get("fx", ""))
	var pal := _palette(school)
	var src := _toward_cam(target.pos) if not target.is_empty() else cam.global_position + _fwd() * 4.5
	var victim := clampi(int(ctx.get("victim", 1)), 0, 3)
	var dst := _slot_pos(victim, 1.5)
	# charge du sort sur le monstre
	_flash(_w_soft(), _hdr(pal.mid, 0.9 * _g), src, 0.3, 1.7 * _s, 0.4)
	_shock(src, pal.mid, 1.6 * _s, 0.4)
	match _family(school, fx):
		"claw": _claw(dst, pal, school)
		"rain": _rain(src, dst, pal, school, victim)
		"burst": _burst_on(dst, pal, school, src)
		_: _m_bolt(src, dst, pal, school, 1.0, 0.0)
	_keep(2.0)

func _family(school: String, fx: String) -> String:
	if school == "physical" or fx.begins_with("phys_") or CLAW_FX.has(fx):
		return "claw"
	if RAIN_FX.has(fx):
		return "rain"
	if BURST_FX.has(fx):
		return "burst"
	return "bolt"

## Palette de l'école (la teinte choisie dans l'éditeur la fait tourner).
func _palette(school: String) -> Dictionary:
	match school:
		"fire":
			_base_hue = 0.06
			return {"hot": _c(1.0, 0.9, 0.55), "mid": _c(1.0, 0.5, 0.1), "deep": _c(0.5, 0.1, 0.02)}
		"ice":
			_base_hue = 0.55
			return {"hot": _c(0.9, 0.98, 1.0), "mid": _c(0.45, 0.8, 1.0), "deep": _c(0.15, 0.4, 0.9)}
		"holy", "bard":
			_base_hue = 0.12
			return {"hot": _c(1.0, 0.97, 0.85), "mid": _c(1.0, 0.82, 0.4), "deep": _c(0.8, 0.5, 0.15)}
		"shadow":
			_base_hue = 0.75
			return {"hot": _c(0.9, 0.7, 1.0), "mid": _c(0.55, 0.25, 0.95), "deep": _c(0.22, 0.05, 0.42)}
		"nature":
			_base_hue = 0.3
			return {"hot": _n_hot(), "mid": _n_mid(), "deep": _n_deep()}
		"physical":
			_base_hue = 0.0
			return {"hot": _c(1.0, 0.88, 0.8), "mid": _c(1.0, 0.35, 0.22), "deep": _c(0.4, 0.05, 0.05)}
		_:
			_base_hue = 0.74
			return {"hot": _c(0.93, 0.88, 1.0), "mid": _c(0.65, 0.4, 1.0), "deep": _c(0.3, 0.15, 0.8)}

# ------------------------------------------------------------------------------------------ impact sur le héros

func _m_hit(at: Vector3, pal: Dictionary, school: String, big: float = 1.0, shake: float = 0.03) -> void:
	var hot: Color = pal.hot
	var mid: Color = pal.mid
	var deep: Color = pal.deep
	_hit_fx(at, {}, {
		"size": big,
		"flash": [Color(hot, 0.9), 0.9],
		"shocks": [[mid, 2.2, 0.38], [hot, 1.4, 0.26, 0.06]],
		"lens": [2.2, 0.04],
		"sparks": {"c": [Color(hot, 1.0), Color(mid, 0.9), Color(deep, 0.0)], "n": 22, "v": [0.8, 3.0], "grav": Vector3(0, -3.0, 0), "life": 0.7},
		"lamp": [mid, 1.8, 4.0, 0.35],
		"shake": shake,
	})
	if school == "nature":
		_n_leaves(at, 0.9 * big * _s, 7)
	elif school == "shadow":
		_hit_fx(at, {}, {"size": big, "smoke": [{"c": [Color(0.3, 0.15, 0.5, 0.0), Color(0.15, 0.07, 0.25, 0.65), Color(0.02, 0.0, 0.04, 0.0)], "n": 8, "sz": [0.4, 0.8], "rise": 0.5, "life": 1.1, "turb": 0.9}]})
	elif school == "ice":
		_hit_fx(at, {}, {"size": big, "shards": {"mesh": _shard_pal("fxm_ice_hit", Color(0.95, 1.0, 1.0), Color(0.5, 0.8, 1.0), Color(0.2, 0.4, 0.9)), "n": 9, "v": [1.5, 3.4], "sz": [0.12, 0.26]}})
	elif school == "fire":
		_hit_fx(at, {}, {"size": big, "smoke": [{"c": [Color(1.0, 0.5, 0.1, 0.0), Color(1.0, 0.35, 0.05, 0.7), Color(0.2, 0.05, 0.0, 0.0)], "n": 8, "sz": [0.4, 0.8], "rise": 0.7, "life": 0.8, "add": true, "turb": 0.7}]})
	elif school == "bard":
		_m_notes(at, hot, 4)

## Notes de musique qui jaillissent (écoles de barde).
func _m_notes(at: Vector3, col: Color, n: int) -> void:
	var up := cam.global_transform.basis.y
	var right := cam.global_transform.basis.x
	for i in n:
		var s := _sprite(_note_tex(), _hdr(col, 1.4 * _g), 0.26 * _s, at)
		(s.mat as StandardMaterial3D).no_depth_test = true
		var ang := randf() * TAU
		var vel := Vector3(cos(ang), sin(ang) * 0.8 + 0.5, 0.0) * randf_range(0.9, 1.6)
		_add(s, 0.8, func(u: float):
			(s.node as Node3D).position = at + right * vel.x * u * 0.7 + up * (vel.y * u * 0.7 + u * u * 0.2)
			(s.node as Node3D).rotation.z = ang * 0.2 + u * 1.2
			(s.mat as StandardMaterial3D).albedo_color.a = 1.0 - u * u)

# ------------------------------------------------------------------------------------------ projectile

## Un projectile du monstre vers le héros. `k` : échelle (pluie : plus petit), `delay` : départ différé.
func _m_bolt(src: Vector3, dst: Vector3, pal: Dictionary, school: String, k: float, delay: float) -> void:
	_later(delay, func():
		var hot: Color = pal.hot
		var mid: Color = pal.mid
		var deep: Color = pal.deep
		var dur := clampf(0.3 + src.distance_to(dst) * 0.04, 0.36, 0.6)
		var p := {
			"arc": 0.15 * k, "lift": 0.1 * k, "ease": "accel", "grow": 0.5, "orient": true,
			"lamp": [mid, 1.4 * k, 4.0],
			"halo": [Color(mid, 0.5), 1.1 * k],
		}
		match school:
			"fire", "arcane":
				p["body"] = {"kind": "plasma", "size": 0.5 * k, "hot": hot, "mid": mid, "rim": deep}
				p["orient"] = false
				p["trails"] = [{"c": [Color(hot, 0.0), Color(mid, 0.85), Color(deep, 0.0)], "n": 30, "life": 0.4, "sz": [0.16, 0.34], "v": [0.1, 0.5], "radius": 0.12, "turb": 0.6, "tex": _flame_puff()},
					{"c": [Color(hot, 0.0), Color(hot, 1.0), Color(mid, 0.0)], "n": 20, "life": 0.3, "sz": [0.04, 0.1], "v": [0.2, 0.8], "k": 1.4, "radius": 0.12}]
			"shadow":
				p["body"] = {"kind": "plasma", "size": 0.45 * k, "hot": Color(0.02, 0.0, 0.05), "mid": deep, "rim": hot, "mix": true}
				p["orient"] = false
				p["trails"] = [{"c": [Color(mid, 0.0), Color(deep, 0.7), Color(0.05, 0.0, 0.12, 0.0)], "n": 22, "life": 0.6, "sz": [0.3, 0.55], "v": [0.1, 0.4], "mix": true, "radius": 0.12, "turb": 0.6, "tex": _smoke_puff()},
					{"c": [Color(hot, 0.0), Color(mid, 0.9), Color(deep, 0.0)], "n": 24, "life": 0.3, "sz": [0.05, 0.12], "v": [0.1, 0.5], "k": 1.4, "radius": 0.12}]
			"ice":
				p["body"] = {"kind": "shard", "mesh": _shard_pal("fxm_ice_bolt", hot, mid, deep), "size": 1.0 * k}
				p["trails"] = [{"c": [Color(hot, 0.0), Color(mid, 0.9), Color(deep, 0.0)], "n": 30, "life": 0.35, "sz": [0.05, 0.12], "v": [0.05, 0.3], "k": 1.4, "radius": 0.06}]
			"nature":
				var node := Node3D.new()
				var mi := MeshInstance3D.new()
				mi.mesh = _thorn_mesh()
				mi.material_override = _vcol_mat(1.25 * _g)
				mi.scale = Vector3(1.0, 1.0, 1.6)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.add_child(mi)
				p["body"] = {"kind": "mesh", "node": node, "size": 0.9 * k}
				p["trails"] = [{"c": [Color(hot, 0.0), Color(mid, 0.9), Color(deep, 0.0)], "n": 28, "life": 0.3, "sz": [0.05, 0.12], "v": [0.05, 0.3], "k": 1.3, "radius": 0.05}]
			_:
				p["core"] = 0.14 * k
				p["body"] = {"kind": "none"}
				p["trails"] = [{"c": [Color(hot, 0.0), Color(mid, 0.95), Color(deep, 0.0)], "n": 36, "life": 0.35, "sz": [0.06, 0.16], "v": [0.05, 0.4], "k": 1.4, "radius": 0.08}]
				p["halo"] = [Color(mid, 0.6), 1.5 * k]
		_fly(src, dst, dur, p, func(): _m_hit(dst, pal, school, 0.85 * k + 0.15, 0.03 * k)))

# ------------------------------------------------------------------------------------------ pluie

func _rain(src: Vector3, dst: Vector3, pal: Dictionary, school: String, victim: int) -> void:
	var up := cam.global_transform.basis.y
	var slots: Array = [victim, clampi(victim - 1, 0, 3), clampi(victim + 1, 0, 3), victim, clampi(victim + 1, 0, 3)]
	if not slot_px.is_empty():          # sur les cartes : seule la carte de la victime est touchée
		slots = [victim, victim, victim, victim, victim]
	for i in slots.size():
		var to := _slot_pos(int(slots[i]), 1.5) + cam.global_transform.basis.x * randf_range(-0.25, 0.25) * (0.4 if not slot_px.is_empty() else 1.0)
		var from := to + up * randf_range(2.6, 3.4) + cam.global_transform.basis.x * randf_range(-0.6, 0.6)
		_m_bolt(from, to, pal, school, 0.65, 0.1 + 0.09 * float(i))

# ------------------------------------------------------------------------------------------ éclat sur le héros

func _burst_on(dst: Vector3, pal: Dictionary, school: String, src: Vector3) -> void:
	var up := cam.global_transform.basis.y
	var hot: Color = pal.hot
	var mid: Color = pal.mid
	var deep: Color = pal.deep
	_later(0.25, func():
		if school == "fire":
			_pillar(dst - up * 1.0, 1.8, 3.2, SH_FLAME, "flame", {"hot": hot, "mid": mid, "edge": deep, "power": 0.5 * _g, "seed": 2.0, "fade": 0.0, "taper": 1.1}, 1.0,
				func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
					var rise := 1.0 - pow(1.0 - clampf(u / 0.25, 0.0, 1.0), 3.0)
					var fall := 1.0 - clampf((u - 0.65) / 0.35, 0.0, 1.0)
					mi.scale = Vector3(1.8 * (0.6 + 0.4 * fall), 3.2 * rise * (0.3 + 0.7 * fall), 1.0)
					mi.position = Vector3(dst.x, dst.y - 1.0 + mi.scale.y * 0.5, dst.z)
					m.set_shader_parameter("fade", minf(1.0, u * 8.0) * fall))
		elif school == "nature":
			var top := dst + up * 3.4
			_bolt_line(top, dst, hot, mid)
		else:
			_pillar(dst - up * 1.0, 1.5, 3.2, SH_PILLAR, "pillar", {"col": mid, "core": hot, "power": 0.5 * _g, "fade": 0.0, "drop": 1.0, "flow": 2.2}, 1.0,
				func(u: float, mi: MeshInstance3D, m: ShaderMaterial):
					m.set_shader_parameter("fade", sin(u * PI) * 0.9))
		_flare4(dst, hot, 2.8, 0.45, 0.2)
		_m_hit(dst, pal, school, 1.2, 0.05))

## Éclair vertical (nature).
func _bolt_line(top: Vector3, to: Vector3, hot: Color, mid: Color) -> void:
	var pts := _zigzag(top, to, 8, 0.3)
	_bolt(pts, mid, 0.45, 0.3)
	_bolt(pts, hot, 0.15, 0.28)

# ------------------------------------------------------------------------------------------ griffes

func _claw(dst: Vector3, pal: Dictionary, school: String) -> void:
	var hot: Color = pal.hot
	var mid: Color = pal.mid
	var deep: Color = pal.deep
	_later(0.2, func():
		for i in 3:
			var off := cam.global_transform.basis.x * (float(i) - 1.0) * 0.22 + cam.global_transform.basis.y * (float(i) - 1.0) * -0.1
			_streak(dst + off, 0.95, 2.6, mid, 0.26, 0.07 * float(i), 0.16, 0.2)
			_streak(dst + off, 0.95, 2.3, hot, 0.24, 0.07 * float(i) + 0.015, 0.05, 0.2)
		_later(0.2, func():
			_flare4(dst, hot, 2.4, 0.4, 0.15)
			_m_hit(dst, pal, school, 1.0, 0.045)))
