class_name StatusAura
extends Node3D
## Effets visuels PERSISTANTS des statuts : tant qu'un statut dure, son effet reste sur le monstre ou sur la carte du héros (sommeil : des « Z » qui montent,
## poison : bulles vertes, brûlure : flammes, gel : givre et flocons, étourdissement : étoiles qui tournent, etc.).
## Un seul nœud par combattant : `set_looks` ajoute ou retire les effets selon les statuts actifs ; tout est dessiné avec quelques sprites
## face caméra animés par le temps (aucune particule GPU), donc léger. `ext` = taille (monde) de la zone à habiller, centrée sur le nœud.

const LOOKS := ["sleep", "stun", "poison", "burn", "freeze", "slow", "weaken", "warcry", "haste", "vigor", "weaponfire", "lifedrain"]

var mix_mode := false      ## vrai dans la couche transparente des cartes : le mélange additif n'y laisserait aucune opacité (invisible une fois posé sur l'interface)
var ext := Vector2(1.0, 1.0)
var _t := 0.0
var _fx: Dictionary = {}          # look -> {"nodes": Array, "fns": Array}

static var _tex_cache: Dictionary = {}

## Aspect d'un statut : `look` du statut s'il en a un (sommeil = étourdissement « endormi »), sinon son type.
static func look_of(e: Dictionary) -> String:
	var lk := str(e.get("look", ""))
	return lk if lk != "" else str(e.get("type", ""))

## Aspects à afficher pour un combattant (monstre, groupe ou héros).
static func looks_for(holder: Dictionary) -> Array:
	var out: Array = []
	for e in Statuses.active(holder):
		var lk := look_of(e)
		if LOOKS.has(lk) and not out.has(lk):
			out.append(lk)
	return out

func set_looks(list: Array) -> void:
	for lk in _fx.keys():
		if not list.has(lk):
			for n in _fx[lk].nodes:
				if is_instance_valid(n):
					n.queue_free()
			_fx.erase(lk)
	for lk in list:
		if not _fx.has(lk) and LOOKS.has(lk):
			_fx[lk] = {"nodes": [], "fns": []}
			call("_build_" + str(lk), _fx[lk])

func is_empty() -> bool:
	return _fx.is_empty()

func _process(delta: float) -> void:
	_t += minf(delta, 0.05)
	for lk in _fx:
		for f in _fx[lk].fns:
			f.call(_t)

# ------------------------------------------------------------------------------------------ briques

func _spr(fx: Dictionary, kind: String, col: Color, additive: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive and not mix_mode else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 5
	m.albedo_texture = _tex(kind)
	m.albedo_color = Color(col, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	fx.nodes.append(mi)
	return mi

## Place un sprite : position locale, taille (monde, x puis y), rotation, opacité.
func _put(mi: MeshInstance3D, pos: Vector2, size: Vector2, alpha: float, rot: float = 0.0) -> void:
	if not is_instance_valid(mi):
		return
	mi.visible = alpha > 0.01
	mi.position = Vector3(pos.x, pos.y, 0.0)
	mi.scale = Vector3(size.x, size.y, 1.0)
	mi.rotation.z = rot
	(mi.material_override as StandardMaterial3D).albedo_color.a = clampf(alpha * (1.8 if mix_mode else 1.0), 0.0, 1.0)

func _g() -> float:
	return maxf(ext.y * (0.5 if mix_mode else 0.30), 0.001)         # taille d'un glyphe

static func _h(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 4.1414) * 43758.5453, 1.0)

# ------------------------------------------------------------------------------------------ effets

func _build_sleep(fx: Dictionary) -> void:
	for i in 3:
		var z := _spr(fx, "z", Color(0.82, 0.78, 1.0))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.42 + float(i) / 3.0, 1.0)
			var x := ext.x * 0.2 + float(i) * ext.x * 0.05 + sin(t * 1.7 + float(i) * 2.0) * ext.x * 0.03
			var y := lerpf(ext.y * 0.28, ext.y * 0.95, k)
			var s := _g() * (0.55 + 0.75 * k)
			_put(z, Vector2(x, y), Vector2(s, s), pow(sin(k * PI), 0.7), sin(t * 1.3 + float(i)) * 0.18))

func _build_stun(fx: Dictionary) -> void:
	for i in 3:
		var st := _spr(fx, "star", Color(1.0, 0.9, 0.4))
		fx.fns.append(func(t: float):
			var a := t * 3.0 + float(i) * TAU / 3.0
			var s := _g() * (0.62 + 0.1 * sin(t * 6.0 + float(i)))
			_put(st, Vector2(cos(a) * ext.x * 0.3, ext.y * 0.52 + sin(a) * ext.y * 0.07), Vector2(s, s), 0.95, t * 2.0 + float(i)))

func _build_poison(fx: Dictionary) -> void:
	var glow := _spr(fx, "glow", Color(0.35, 0.95, 0.3))
	fx.fns.append(func(t: float):
		_put(glow, Vector2.ZERO, ext * 1.15, 0.2 + 0.08 * sin(t * 2.2)))
	for i in 7:
		var b := _spr(fx, "bubble", Color(0.55, 1.0, 0.45))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.3 + float(i) * 0.143, 1.0)
			var x := ext.x * (-0.36 + 0.72 * _h(i)) + sin(t * 2.0 + float(i)) * ext.x * 0.025
			var s := _g() * (0.3 + 0.3 * _h(i + 9))
			_put(b, Vector2(x, lerpf(-ext.y * 0.45, ext.y * 0.5, k)), Vector2(s, s), sin(k * PI) * 0.9))

func _build_burn(fx: Dictionary) -> void:
	var glow := _spr(fx, "glow", Color(1.0, 0.38, 0.08))
	fx.fns.append(func(t: float):
		_put(glow, Vector2(0, -ext.y * 0.1), ext * 1.1, 0.2 + 0.07 * sin(t * 9.0)))
	for i in 6:
		var f := _spr(fx, "flame", Color(1.0, 0.55, 0.12))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.9 + float(i) * 0.17, 1.0)
			var x := ext.x * (-0.36 + 0.72 * fposmod(float(i) * 0.618, 1.0)) + sin(t * 7.0 + float(i)) * ext.x * 0.02
			var s := _g() * (1.1 - 0.5 * k)
			(f.material_override as StandardMaterial3D).albedo_color = Color(1.0, lerpf(0.85, 0.25, k), lerpf(0.3, 0.05, k), 0.0)
			_put(f, Vector2(x, lerpf(-ext.y * 0.45, ext.y * 0.4, k)), Vector2(s * 0.75, s), pow(1.0 - k, 0.6) * minf(k * 8.0, 1.0)))

func _build_freeze(fx: Dictionary) -> void:
	var glow := _spr(fx, "glow", Color(0.45, 0.8, 1.0))
	fx.fns.append(func(t: float):
		_put(glow, Vector2.ZERO, ext * 1.2, 0.3 + 0.06 * sin(t * 1.8)))
	var ring := _spr(fx, "ring", Color(0.7, 0.92, 1.0))
	fx.fns.append(func(t: float):
		_put(ring, Vector2.ZERO, ext * 1.05, 0.5 + 0.15 * sin(t * 2.5)))
	for i in 4:
		var sn := _spr(fx, "snow", Color(0.85, 0.97, 1.0))
		fx.fns.append(func(t: float):
			var a := t * 0.5 + float(i) * TAU / 4.0
			var s := _g() * 0.6
			_put(sn, Vector2(cos(a) * ext.x * 0.4, sin(a) * ext.y * 0.4), Vector2(s, s), 0.9, t * 0.8 + float(i)))

func _build_slow(fx: Dictionary) -> void:
	var glow := _spr(fx, "glow", Color(0.35, 0.45, 0.85))
	fx.fns.append(func(t: float):
		_put(glow, Vector2(0, -ext.y * 0.25), Vector2(ext.x * 1.1, ext.y * 0.7), 0.2 + 0.05 * sin(t * 1.2)))
	for i in 5:
		var d := _spr(fx, "bubble", Color(0.5, 0.6, 0.95))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.22 + float(i) * 0.2, 1.0)
			var s := _g() * 0.34
			_put(d, Vector2(ext.x * (-0.3 + 0.15 * float(i)), lerpf(ext.y * 0.55, -ext.y * 0.5, k)), Vector2(s, s * 1.3), sin(k * PI) * 0.85))

func _build_weaken(fx: Dictionary) -> void:
	for i in 3:
		var a := _spr(fx, "arrow_down", Color(0.9, 0.42, 0.36))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.34 + float(i) / 3.0, 1.0)
			var s := _g() * 0.55
			_put(a, Vector2(ext.x * (-0.2 + 0.2 * float(i)), lerpf(ext.y * 0.62, ext.y * 0.02, k)), Vector2(s, s), sin(k * PI) * 0.9))

func _build_warcry(fx: Dictionary) -> void:
	var ring := _spr(fx, "ring", Color(1.0, 0.25, 0.2))
	fx.fns.append(func(t: float):
		var s := 1.0 + 0.07 * sin(t * 5.0)
		_put(ring, Vector2.ZERO, Vector2(ext.x * 1.05, ext.y * 1.05) * s, 0.55 + 0.3 * sin(t * 5.0)))
	for i in 3:
		var sp := _spr(fx, "star", Color(1.0, 0.3, 0.2))
		fx.fns.append(func(t: float):
			var a := float(i) * TAU / 3.0 + 0.6
			var s := _g() * 0.35
			_put(sp, Vector2(cos(a) * ext.x * 0.46, sin(a) * ext.y * 0.46), Vector2(s, s), maxf(0.0, sin(t * 8.0 + float(i) * 2.0)), t))

func _build_haste(fx: Dictionary) -> void:
	for i in 4:
		var s_ := _spr(fx, "streak", Color(0.7, 0.97, 1.0))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 1.5 + float(i) * 0.25, 1.0)
			_put(s_, Vector2(lerpf(ext.x * 0.6, -ext.x * 0.6, k), ext.y * (-0.3 + 0.2 * float(i))), Vector2(_g() * 1.8, _g() * 0.3), sin(k * PI) * 0.8))

func _build_vigor(fx: Dictionary) -> void:
	for i in 3:
		var n := _spr(fx, "note", Color(1.0, 0.85, 0.45))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.4 + float(i) / 3.0, 1.0)
			var s := _g() * 0.7
			_put(n, Vector2(ext.x * (-0.25 + 0.25 * float(i)) + sin(t * 2.0 + float(i)) * ext.x * 0.03, lerpf(-ext.y * 0.3, ext.y * 0.8, k)), Vector2(s, s), sin(k * PI) * 0.9))

func _build_weaponfire(fx: Dictionary) -> void:
	for i in 5:
		var f := _spr(fx, "flame", Color(1.0, 0.6, 0.2))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 1.1 + float(i) * 0.2, 1.0)
			var s := _g() * 0.5
			_put(f, Vector2(ext.x * (-0.35 + 0.7 * fposmod(float(i) * 0.37, 1.0)), lerpf(-ext.y * 0.4, ext.y * 0.3, k)), Vector2(s * 0.7, s), pow(1.0 - k, 0.7) * minf(k * 8.0, 1.0)))

func _build_lifedrain(fx: Dictionary) -> void:
	var glow := _spr(fx, "glow", Color(0.6, 0.15, 0.55))
	fx.fns.append(func(t: float):
		_put(glow, Vector2.ZERO, ext * 1.1, 0.2 + 0.07 * sin(t * 3.0)))
	for i in 5:
		var w := _spr(fx, "glow", Color(0.75, 0.2, 0.5))
		fx.fns.append(func(t: float):
			var k := fposmod(t * 0.35 + float(i) * 0.2, 1.0)
			var s := _g() * 0.45
			_put(w, Vector2(ext.x * (-0.3 + 0.15 * float(i)) + sin(t * 3.0 + float(i)) * ext.x * 0.03, lerpf(-ext.y * 0.4, ext.y * 0.6, k)), Vector2(s, s), sin(k * PI) * 0.8))

# ------------------------------------------------------------------------------------------ textures (dessinées une fois)

static func _tex(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / float(n), (float(y) + 0.5) / float(n))
			var a := _alpha(kind, p)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[kind] = t
	return t

static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)

static func _line_alpha(p: Vector2, pts: Array, th: float) -> float:
	var d := 9.0
	for i in pts.size() - 1:
		d = minf(d, _seg(p, pts[i], pts[i + 1]))
	return clampf((th - d) / 0.035, 0.0, 1.0)

static func _in_poly(p: Vector2, pts: Array) -> bool:
	var inside := false
	var j := pts.size() - 1
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside

static func _alpha(kind: String, p: Vector2) -> float:
	var c := Vector2(0.5, 0.5)
	var r := p.distance_to(c)
	match kind:
		"glow":
			return pow(clampf(1.0 - r * 2.0, 0.0, 1.0), 1.6)
		"ring":
			return clampf(1.0 - absf(r - 0.4) / 0.07, 0.0, 1.0) * 0.9 + pow(clampf(1.0 - r * 2.0, 0.0, 1.0), 3.0) * 0.1
		"bubble":
			var ring := clampf(1.0 - absf(r - 0.36) / 0.05, 0.0, 1.0)
			var fill := 0.14 if r < 0.36 else 0.0
			var hl := clampf(1.0 - p.distance_to(Vector2(0.36, 0.34)) / 0.08, 0.0, 1.0)
			return maxf(maxf(ring, fill), hl)
		"z":
			return _line_alpha(p, [Vector2(0.2, 0.22), Vector2(0.8, 0.22), Vector2(0.2, 0.78), Vector2(0.8, 0.78)], 0.065)
		"star":
			var pts: Array = []
			for i in 10:
				var ang := -PI * 0.5 + float(i) * PI / 5.0
				var rad := 0.46 if i % 2 == 0 else 0.2
				pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
			var fill2 := 1.0 if _in_poly(p, pts) else 0.0
			return maxf(fill2, pow(clampf(1.0 - r * 2.0, 0.0, 1.0), 2.0) * 0.45)
		"snow":
			var a := 0.0
			for i in 3:
				var ang2 := float(i) * PI / 3.0
				var d := Vector2(cos(ang2), sin(ang2)) * 0.42
				a = maxf(a, _line_alpha(p, [c - d, c + d], 0.03))
				for s in [-1.0, 1.0]:
					var tip: Vector2 = c + d * s
					var back: Vector2 = c + d * s * 0.62
					var side := Vector2(-d.y, d.x).normalized() * 0.1
					a = maxf(a, _line_alpha(p, [back + side, tip, back - side], 0.025))
			return a
		"note":
			var head := clampf(1.0 - (p.distance_to(Vector2(0.36, 0.76)) - 0.15) / 0.04, 0.0, 1.0)
			var stem := _line_alpha(p, [Vector2(0.5, 0.74), Vector2(0.5, 0.18)], 0.04)
			var flag := _line_alpha(p, [Vector2(0.5, 0.18), Vector2(0.72, 0.34), Vector2(0.62, 0.5)], 0.04)
			return maxf(head, maxf(stem, flag))
		"arrow_down":
			var tri: Array = [Vector2(0.15, 0.3), Vector2(0.85, 0.3), Vector2(0.5, 0.88)]
			return 1.0 if _in_poly(p, tri) else clampf(1.0 - _seg(p, Vector2(0.5, 0.1), Vector2(0.5, 0.3)) / 0.07, 0.0, 1.0)
		"flame":
			var t := (p.y - 0.06) / 0.9                       # 0 = pointe, 1 = base
			if t < 0.0 or t > 1.0:
				return 0.0
			var half := 0.4 * sin(pow(t, 0.7) * PI * 0.92 + 0.12)
			var edge := clampf((half - absf(p.x - 0.5)) / 0.08, 0.0, 1.0)
			return edge * (0.35 + 0.65 * t)
		"streak":
			return exp(-pow((p.x - 0.5) / 0.38, 2.0)) * exp(-pow((p.y - 0.5) / 0.09, 2.0))
	return 0.0
