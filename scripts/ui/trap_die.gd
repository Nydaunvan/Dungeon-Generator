class_name TrapDie
extends Control
## Dé à 20 faces du piège : icosaèdre projeté en perspective (640 px), mêmes maths que le CSS 3D de l'original
## (matrices de faces, rotation autour de deux axes obliques, rebonds, ombrage des faces, ombre au sol).

const PERSP := 640.0
const RR := 54.0
const STAGE_H := 150.0
const LIGHT := Vector3(-0.4, -0.6, 0.7)

class Face:
	var ex: Vector3
	var ey: Vector3
	var ez: Vector3
	var c: Vector3
	var num: int = 0

static var _faces: Array = []
static var _by_num: Dictionary = {}
static var _w: float = 0.0
static var _h: float = 0.0

var rot: Basis = Basis.IDENTITY     # M : espace du dé -> écran
var lift: float = 0.0               # translateY du dé (px, négatif = vers le haut)
var glow: Color = Color(0, 0, 0, 0)
var dim: Color = Color.WHITE        # « filtre » brightness / grayscale selon le résultat
var _font: Font
var _tween: Tween
var rolling: bool = false

signal finished

func _init() -> void:
	custom_minimum_size = Vector2(0, STAGE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(UiTheme.F_BODY_BOLD)
	_build()
	pose(20)

static func _build() -> void:
	if not _faces.is_empty():
		return
	var p := (1.0 + sqrt(5.0)) / 2.0
	var raw: Array[Vector3] = [Vector3(0, 1, p), Vector3(0, -1, p), Vector3(0, 1, -p), Vector3(0, -1, -p), Vector3(1, p, 0), Vector3(-1, p, 0),
		Vector3(1, -p, 0), Vector3(-1, -p, 0), Vector3(p, 0, 1), Vector3(-p, 0, 1), Vector3(p, 0, -1), Vector3(-p, 0, -1)]
	var v: Array[Vector3] = []
	for r in raw:
		v.append(r.normalized() * RR)
	var edge := 2.0 / Vector2(1, p).length() * RR
	_w = edge
	_h = edge * sqrt(3.0) / 2.0
	for i in 12:
		for j in range(i + 1, 12):
			if absf(v[i].distance_to(v[j]) - edge) > 0.01:
				continue
			for k in range(j + 1, 12):
				if absf(v[j].distance_to(v[k]) - edge) > 0.01 or absf(v[i].distance_to(v[k]) - edge) > 0.01:
					continue
				var f := Face.new()
				f.c = (v[i] + v[j] + v[k]) / 3.0
				f.ez = f.c.normalized()
				f.ey = (f.c - v[i]).normalized()
				f.ex = f.ey.cross(f.ez)
				_faces.append(f)
	var k2 := 1
	for f in _faces:
		if f.num != 0:
			continue
		for g in _faces:
			if g.num == 0 and g != f and g.ez.dot(f.ez) < -0.99:
				g.num = 21 - k2
				break
		f.num = k2
		k2 += 1
	for f in _faces:
		_by_num[f.num] = f

static func _rows(a: Vector3, b: Vector3, c: Vector3) -> Basis:
	return Basis(a, b, c).transposed()

func pose(num: int) -> void:
	var f: Face = _by_num[num]
	rot = _rows(f.ex, f.ey, f.ez)
	lift = 0.0
	queue_redraw()

## Lance le dé : tours fixes (8,5 et 5,5 demi-tours), axes toujours de travers, 3,4 s, retombe sur `roll`.
func roll(result: int, dur: float = 3.4) -> void:
	if _tween:
		_tween.kill()
	rolling = true
	var f: Face = _by_num[result]
	var rf := _rows(f.ex, f.ey, f.ez)
	var sg := func(): return -1.0 if randf() < 0.5 else 1.0
	var ang := randf() * TAU
	var ax_a := Vector3(cos(ang), sin(ang), (randf() - 0.5) * 0.5).normalized()
	var ax_b := Vector3(-sin(ang), cos(ang), (randf() - 0.5) * 0.5).normalized()
	var ta: float = 8.5 * PI * sg.call()
	var tb: float = 5.5 * PI * sg.call()
	_tween = create_tween()
	_tween.tween_method(func(p: float):
		var e := 1.0 - pow(1.0 - p, 3.2)
		var rem := 1.0 - e
		rot = Basis(ax_a, ta * rem) * Basis(ax_b, tb * rem) * rf
		lift = -absf(sin(p * PI * 5.0)) * 50.0 * pow(1.0 - p, 1.5)
		queue_redraw(), 0.0, 1.0, dur)
	_tween.tween_callback(func():
		rolling = false
		pose(result)
		finished.emit())

func _proj(m_p: Vector3, center: Vector2) -> Vector2:
	var s := PERSP / (PERSP - m_p.z)
	return center + Vector2(m_p.x, m_p.y) * s

func _grad(local: Vector2) -> Color:
	# linear-gradient(165deg, #f6e0a4, #c39a45) sur la boîte w×h
	var d := Vector2(sin(deg_to_rad(165.0)), -cos(deg_to_rad(165.0)))
	var glen := absf(_w * d.x) + absf(_h * d.y)
	var t := clampf(0.5 + (local - Vector2(_w, _h) * 0.5).dot(d) / glen, 0.0, 1.0)
	return Color("f6e0a4").lerp(Color("c39a45"), t)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, 75.0)
	# halo (états or / réussite / critique)
	if glow.a > 0.0:
		for i in 10:
			var k := float(i) / 10.0
			draw_circle(center, 78.0 * (1.0 - k * 0.8), Color(glow.r, glow.g, glow.b, glow.a * 0.07))
	# ombre au sol
	var u := clampf(-lift / 60.0, 0.0, 1.0)
	var sh_a := (0.55 - u * 0.3) * 0.55
	var sh_c := Vector2(size.x * 0.5, STAGE_H - 4.0 - 6.0)
	draw_set_transform(sh_c, 0.0, Vector2(1.0 - u * 0.45, 1.0))
	for i in 5:
		var k := float(i) / 5.0
		draw_set_transform(sh_c, 0.0, Vector2((1.0 - u * 0.45) * (1.0 - k * 0.45), (1.0 - k * 0.45) * 0.18))
		draw_circle(Vector2.ZERO, 44.0, Color(0.04, 0.016, 0.008, sh_a * 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cx := _w * 0.5
	var cy := 2.0 * _h / 3.0
	var lv := LIGHT.normalized()
	var lift_v := Vector3(0, lift, 0)
	for fa in _faces:
		var f: Face = fa
		var t0 := f.c - f.ex * cx - f.ey * cy
		var loc := func(x: float, y: float) -> Vector2:
			return _proj(rot * (t0 + f.ex * x + f.ey * y) + lift_v, center)
		var p0: Vector2 = loc.call(cx, 0.0)
		var p1: Vector2 = loc.call(_w, _h)
		var p2: Vector2 = loc.call(0.0, _h)
		if (p1 - p0).cross(p2 - p0) <= 0.0:
			continue
		var outer := PackedVector2Array([p0, p1, p2])
		draw_polygon(outer, PackedColorArray([Color("4a300c").darkened(0.0) * dim]))
		# face dorée intérieure (échelle .92 autour du centre de gravité)
		var lv0 := Vector2(cx, 0.0)
		var lv1 := Vector2(_w, _h)
		var lv2 := Vector2(0.0, _h)
		var cc := Vector2(cx, cy)
		var ins: Array[Vector2] = [cc + (lv0 - cc) * 0.92, cc + (lv1 - cc) * 0.92, cc + (lv2 - cc) * 0.92]
		var pin := PackedVector2Array()
		var cols := PackedColorArray()
		for q in ins:
			pin.append(loc.call(q.x, q.y))
			cols.append(_grad(q) * dim)
		draw_polygon(pin, cols)
		# numéro (repère affine local de la face autour du centre de gravité)
		var pc: Vector2 = loc.call(cx, cy)
		var ax: Vector2 = ((loc.call(cx + 10.0, cy) as Vector2) - pc) / 10.0
		var ay: Vector2 = ((loc.call(cx, cy + 10.0) as Vector2) - pc) / 10.0
		var sc := 0.25
		draw_set_transform_matrix(Transform2D(ax * sc, ay * sc, pc))
		var txt := str(f.num) + ("." if f.num == 6 or f.num == 9 else "")
		draw_string(_font, Vector2(-100.0, 60.0 * 0.33), txt, HORIZONTAL_ALIGNMENT_CENTER, 200.0, 60, Color("2a1a08") * dim)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# ombrage selon la lumière
		var nw: Vector3 = rot * f.ez
		var op := clampf(0.42 - 0.5 * nw.dot(lv), 0.0, 0.7)
		draw_polygon(outer, PackedColorArray([Color(0.039, 0.016, 0.0, op)]))
