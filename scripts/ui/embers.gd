class_name Embers
extends Control
## Braises qui s'élèvent de la torche de l'accueil (coordonnées de la scène 1280×800, mises à l'échelle par `k`).

const DEFS := [   # x, dx, durée, délai
	[70.0, 26.0, 5.2, 0.0], [105.0, -20.0, 6.4, 1.1], [55.0, 14.0, 4.6, 2.2], [130.0, -28.0, 6.8, 0.4], [90.0, 20.0, 5.6, 1.7],
]
const START_Y := 474.0
const RISE := 760.0
var k: float = 1.0
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

func _draw() -> void:
	for d in DEFS:
		var ph := fposmod(_t - float(d[3]), float(d[2])) / float(d[2])
		var alpha := ph / 0.1 if ph < 0.1 else 1.0 - (ph - 0.1) / 0.9
		var sc := lerpf(1.0, 0.25, ph)
		var p := Vector2(float(d[0]) + float(d[1]) * ph, START_Y - RISE * ph) * k
		draw_circle(p, 9.0 * sc * k, Color(1.0, 0.59, 0.2, 0.22 * alpha))
		draw_circle(p, 4.5 * sc * k, Color(0.89, 0.41, 0.12, 0.6 * alpha))
		draw_circle(p, 2.4 * sc * k, Color(1.0, 0.81, 0.54, alpha))
