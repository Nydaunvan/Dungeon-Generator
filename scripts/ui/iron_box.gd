class_name IronBox
extends StyleBox
## Bouton de fer riveté de l'original (.sound-toggle / .dpad-btn / .flee-btn) : dégradé, bordure noire 2 px,
## liseré bronze extérieur, reflets, quatre rivets aux coins. `top`/`bottom` = dégradé vertical ; `ring` = liseré extérieur.

var top: Color = Color("342a1f")
var mid: Color = Color("1f1812")
var bottom: Color = Color("120d09")
var ring: Color = Color("4a3a28")
var inner_ring: Color = Color(0, 0, 0, 0)
var glow: Color = Color(0, 0, 0, 0)
var rivets: bool = true
var radius_css: float = 3.0
var border_css: float = 2.0

func _draw(ci: RID, rect: Rect2) -> void:
	var r := UiMetrics.css(radius_css)
	var b := maxf(1.0, UiMetrics.css(border_css))
	var o := maxf(1.0, UiMetrics.css(1.0))
	# lueur (survol / actif)
	if glow.a > 0.0:
		for i in 3:
			_rr(ci, rect.grow(o + UiMetrics.css(3.0 * (i + 1))), r + 4.0, Color(glow.r, glow.g, glow.b, glow.a * (0.5 - 0.15 * i)))
	_rr(ci, rect.grow(o), r + o, ring)
	_rr(ci, rect, r, Color("070504"))
	var inner := rect.grow(-b)
	# dégradé vertical 0 / 55 / 100 %
	var n := 10
	for i in n:
		var t := float(i) / float(n - 1)
		var c := top.lerp(mid, t / 0.55) if t < 0.55 else mid.lerp(bottom, (t - 0.55) / 0.45)
		var y0 := inner.position.y + inner.size.y * i / n
		RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x, y0, inner.size.x, inner.size.y / n + 0.6), c)
	# reflet haut / ombre bas
	RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position, Vector2(inner.size.x, maxf(1.0, o))), Color(1, 0.86, 0.67, 0.14))
	RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x, inner.end.y - 2.0 * o, inner.size.x, 2.0 * o), Color(0, 0, 0, 0.6))
	if inner_ring.a > 0.0:
		var ir := inner.grow(-o)
		for e in [Rect2(ir.position, Vector2(ir.size.x, o)), Rect2(Vector2(ir.position.x, ir.end.y - o), Vector2(ir.size.x, o)), Rect2(ir.position, Vector2(o, ir.size.y)), Rect2(Vector2(ir.end.x - o, ir.position.y), Vector2(o, ir.size.y))]:
			RenderingServer.canvas_item_add_rect(ci, e, inner_ring)
	if rivets and inner.size.x > UiMetrics.css(14.0) and inner.size.y > UiMetrics.css(14.0):
		var d := UiMetrics.css(4.0)
		for p in [inner.position + Vector2(d, d), Vector2(inner.end.x - d, inner.position.y + d), Vector2(inner.position.x + d, inner.end.y - d), inner.end - Vector2(d, d)]:
			RenderingServer.canvas_item_add_circle(ci, p, UiMetrics.css(2.8), Color("050403"))
			RenderingServer.canvas_item_add_circle(ci, p, UiMetrics.css(1.9), Color("4a3826"))
			RenderingServer.canvas_item_add_circle(ci, p - Vector2(o * 0.4, o * 0.4), UiMetrics.css(0.9), Color("b09068"))

func _rr(ci: RID, rect: Rect2, radius: float, col: Color) -> void:
	var p := PackedVector2Array()
	var rr := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [[rect.end - Vector2(rr, rr), 0.0], [Vector2(rect.position.x + rr, rect.end.y - rr), PI * 0.5], [rect.position + Vector2(rr, rr), PI], [Vector2(rect.end.x - rr, rect.position.y + rr), PI * 1.5]]
	for c in corners:
		for i in 5:
			var a: float = c[1] + float(i) / 4.0 * PI * 0.5
			p.append(c[0] + Vector2(cos(a), sin(a)) * rr)
	RenderingServer.canvas_item_add_polygon(ci, p, PackedColorArray([col]))

static func button_styles(glow_hover := Color("e8b45c"), variant := "iron") -> Dictionary:
	var n := IronBox.new()
	var h := IronBox.new()
	var p := IronBox.new()
	h.top = Color("43352a")
	h.mid = Color("2c221a")
	h.bottom = Color("221a12")
	h.ring = Color("c9a15a")
	h.glow = Color(glow_hover.r, glow_hover.g, glow_hover.b, 0.35)
	p.top = Color("120d09")
	p.mid = Color("1a140f")
	p.bottom = Color("2a2018")
	if variant == "flee":
		for b in [n, h, p]:
			b.top = Color("3d140e")
			b.mid = Color("2a0f0a")
			b.bottom = Color("1a0805")
			b.inner_ring = Color("7a2c1e")
			b.ring = Color("070504")
		h.top = Color("5a1d14")
	return {"normal": n, "hover": h, "pressed": p, "focus": n, "disabled": n}

## Boutons de fenêtre (.modal-actions>button) : fer riveté ; « primary » = filet or et texte or vif.
static func modal_styles(primary: bool) -> Dictionary:
	var n := IronBox.new()
	var h := IronBox.new()
	var p := IronBox.new()
	if primary:
		for b in [n, h, p]:
			b.top = Color("5a4526")
			b.mid = Color("3f3018")
			b.bottom = Color("2a1f10")
			b.ring = Color("a9793a")
		h.top = Color("6c5530")
		h.mid = Color("4a3a1e")
		p.top = Color("2a1f10")
		p.mid = Color("3a2c16")
		p.bottom = Color("5a4526")
	else:
		h.top = Color("43352a")
		h.mid = Color("2c221a")
		h.bottom = Color("221a12")
		p.top = Color("120d09")
		p.mid = Color("1a140f")
		p.bottom = Color("2a2018")
	h.glow = Color(0.91, 0.7, 0.36, 0.25)
	return {"normal": n, "hover": h, "pressed": p, "focus": n, "disabled": n}
