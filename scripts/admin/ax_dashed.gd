class_name AxDashed
extends PanelContainer
## Cadre à bordure pointillée (bouton « Ajouter un niveau », emplacement vide…) : StyleBoxFlat ne sait pas tracer de pointillés.

var color := Color("6b5430")
var radius := 12.0

func _init(c: Color = Color("6b5430"), r: float = 12.0) -> void:
	color = c
	radius = r
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _draw() -> void:
	var w := size.x
	var h := size.y
	var r := minf(radius, minf(w, h) * 0.5)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + i * (PI / 2.0) / 8.0
		pts.append(Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
	for i in 9:
		var a := 1.5 * PI + i * (PI / 2.0) / 8.0
		pts.append(Vector2(w - r, r) + Vector2(cos(a), sin(a)) * r)
	for i in 9:
		var a := i * (PI / 2.0) / 8.0
		pts.append(Vector2(w - r, h - r) + Vector2(cos(a), sin(a)) * r)
	for i in 9:
		var a := 0.5 * PI + i * (PI / 2.0) / 8.0
		pts.append(Vector2(r, h - r) + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	# tirets de 4 px, trous de 3 px, le long du tracé
	var acc := 0.0
	var on := true
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var d := 0.0
		while d < seg:
			var len := (4.0 if on else 3.0) - acc
			var step := minf(len, seg - d)
			if on:
				draw_line(a.lerp(b, d / seg), a.lerp(b, (d + step) / seg), color, 1.0, true)
			d += step
			acc += step
			if acc >= (4.0 if on else 3.0) - 0.001:
				acc = 0.0
				on = not on
