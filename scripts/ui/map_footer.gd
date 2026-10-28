class_name MapFooter
extends Control
## Pied du panneau de la carte : rose des vents centrée entre deux filets effilés (maquette Atlas Noir).

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 40)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.y * 0.42, 15.0)
	draw_arc(c, r, 0.0, TAU, 40, Atlas.COPPER, 1.0, true)
	draw_arc(c, r * 0.55, 0.0, TAU, 28, Color(Atlas.COPPER, 0.6), 1.0, true)
	for i in 4:
		var a := float(i) * PI * 0.5 - PI * 0.5
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var tip := c + d * r * 1.45
		draw_colored_polygon(PackedVector2Array([tip, c + n * r * 0.2, c - n * r * 0.2]), Atlas.AMBER if i == 0 else Atlas.COPPER)
	var y := c.y
	Atlas.draw_taper(self, Vector2(6.0, y), Vector2(c.x - r * 2.0, y), 0.4, 1.6, Color(Atlas.COPPER, 0.8))
	Atlas.draw_taper(self, Vector2(size.x - 6.0, y), Vector2(c.x + r * 2.0, y), 0.4, 1.6, Color(Atlas.COPPER, 0.8))

## Indicateur du nord (en-tête du panneau) : « N », petit cercle et flèche, comme sur la maquette.
class North extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(20, 26)
	func _draw() -> void:
		var c := size * 0.5
		var f := Atlas.font(Atlas.F_BODY_BOLD)
		draw_string(f, Vector2(c.x - 3.5, 8.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Atlas.IVORY_DIM)
		draw_arc(c + Vector2(0, 3), 7.0, 0.0, TAU, 24, Atlas.COPPER, 1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(3, 7), c + Vector2(-3, 7)]), Atlas.IVORY)
