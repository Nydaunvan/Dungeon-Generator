class_name HomeToolsPanel
extends Control
## Encadré « OUTILS » de l'accueil : cadre à filet fin dont la ligne du haut s'interrompt autour du mot « OUTILS », petits boutons en grille de deux colonnes.

var label: String = "":
	set(v):
		label = v
		queue_redraw()
var buttons: Array[HomeMenuButton] = []
var _u := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)

func add_tool(b: HomeMenuButton) -> void:
	b.compact = true
	buttons.append(b)
	add_child(b)
	_relayout()

## Hauteur de référence (unités de la maquette) pour `n` boutons de 50 de haut.
static func design_height(n: int) -> float:
	var rows := ceili(n / 2.0)
	return 28.0 + rows * 50.0 + maxf(0.0, rows - 1.0) * 12.0 + 16.0

func _relayout() -> void:
	if buttons.is_empty():
		return
	var rows := ceili(buttons.size() / 2.0)
	_u = size.y / design_height(buttons.size())
	var pad := 16.0 * _u
	var gap := 12.0 * _u
	var bw := (size.x - 2.0 * pad - gap) * 0.5
	var bh := 50.0 * _u
	for i in buttons.size():
		var col := i % 2
		var row := i / 2
		var b := buttons[i]
		b.position = Vector2(pad + col * (bw + gap), 28.0 * _u + row * (bh + gap))
		b.size = Vector2(bw, bh)
	queue_redraw()

func _draw() -> void:
	var u := _u
	var r := Rect2(Vector2(0, 8.0 * u), Vector2(size.x, size.y - 8.0 * u))
	var cut := 8.0 * u
	var pts := Atlas.chamfer(r.grow(-0.5), cut, Vector4(0, 1, 0, 1))
	var col := Color(Atlas.COPPER, 0.75)
	var f := Atlas.title_font(false, int(roundf(3.0 * u)))
	var fs := int(roundf(13.0 * u))
	var tw := f.get_string_size(label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gx0 := (size.x - tw) * 0.5 - 14.0 * u
	var gx1 := (size.x + tw) * 0.5 + 14.0 * u
	# contour : le filet du haut s'interrompt autour du mot
	var n := pts.size()
	var loop := PackedVector2Array(pts)
	loop.append(pts[0])
	for i in n:
		var a := loop[i]
		var b := loop[i + 1]
		if absf(a.y - r.position.y) < 1.5 and absf(b.y - r.position.y) < 1.5:
			var x0 := minf(a.x, b.x)
			var x1 := maxf(a.x, b.x)
			if x0 < gx0:
				draw_line(Vector2(x0, a.y), Vector2(minf(x1, gx0), a.y), col, 1.0 * u, true)
			if x1 > gx1:
				draw_line(Vector2(maxf(x0, gx1), a.y), Vector2(x1, a.y), col, 1.0 * u, true)
		else:
			draw_line(a, b, col, 1.0 * u, true)
	draw_string(f, Vector2((size.x - tw) * 0.5, r.position.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.IVORY)
