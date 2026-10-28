class_name SlantBox
extends StyleBox
## Fond ou remplissage de barre en parallélogramme (extrémité droite en biais), comme les barres de PV / endurance de la maquette.

var color: Color = Color.WHITE
var border: Color = Color(0, 0, 0, 0)
var slant: float = 0.6      ## décalage du biais, en fraction de la hauteur

func _draw(ci: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	var s := minf(rect.size.y * slant, rect.size.x)
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - s, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([color]))
	if border.a > 0.0:
		var line := pts.duplicate()
		line.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, line, PackedColorArray([border]), 1.0, true)
