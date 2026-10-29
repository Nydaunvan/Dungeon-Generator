class_name MapFooter
extends Control
## Pied du panneau de la carte : rose des vents centrée entre deux filets effilés (maquette Atlas Noir).

static var _tex: Texture2D

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	custom_minimum_size = Vector2(0, 56)

func _draw() -> void:
	# massifs très pâles en arrière-plan (simples traits), puis la rose des vents au bas du panneau
	var mc := Color(Atlas.COPPER, 0.18)
	var base := size.y - 26.0
	if base > 30.0:
		var pts := PackedVector2Array()
		var n := 14
		for i in n + 1:
			var x := size.x * float(i) / n
			var hgt := (0.55 + 0.45 * sin(float(i) * 1.7 + 0.6) * sin(float(i) * 0.6 + 1.1)) * minf(base, 90.0) * (1.0 if i % 2 == 0 else 0.55)
			pts.append(Vector2(x, base - absf(hgt)))
		draw_polyline(pts, mc, 1.0, true)
		draw_line(Vector2(0, base), Vector2(size.x, base), mc, 1.0)
	if _tex == null:
		_tex = load("res://assets/ui/compass.png")
	var d := 52.0
	var c := Vector2(size.x * 0.5, size.y - d * 0.5 + 6.0)
	var r := d * 0.5 * 0.55
	draw_texture_rect(_tex, Rect2(c - Vector2(d, d) * 0.5, Vector2(d, d)), false)
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
