class_name AtlasBox
extends StyleBox
## Fond de panneau Atlas Noir : surface sombre, filet fin, angles coupés. Se règle avec les variables ci-dessous ;
## s'utilise comme n'importe quel StyleBox (`add_theme_stylebox_override("panel", AtlasBox.new())`).

var fill_top: Color = Atlas.OBSIDIAN
var fill_bottom: Color = Atlas.OBSIDIAN
var border: Color = Atlas.COPPER_DIM
var width: float = 1.0
var cut: float = 6.0
var corners := Vector4(1, 0, 1, 0)
var marks: Color = Color(0, 0, 0, 0)   ## si l'alpha > 0 : petits repères d'angle doublés (équerres) à l'intérieur du cadre
var mark_len: float = 9.0

func _init(pad: float = 8.0) -> void:
	content_margin_left = pad
	content_margin_right = pad
	content_margin_top = pad
	content_margin_bottom = pad

## Variante « sélection / action » : filet ambre.
func accent() -> AtlasBox:
	border = Atlas.AMBER
	return self

func _draw(ci: RID, rect: Rect2) -> void:
	var pts := Atlas.chamfer(rect.grow(-width * 0.5), cut, corners)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(fill_top.lerp(fill_bottom, clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(ci, pts, cols)
	if border.a > 0.0 and width > 0.0:
		var line := pts.duplicate()
		line.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, line, PackedColorArray([border]), width, true)
	if marks.a > 0.0:
		var m := width + 3.0
		var l := mark_len
		var x0 := rect.position.x + m
		var y0 := rect.position.y + m
		var x1 := rect.end.x - m
		var y1 := rect.end.y - m
		var col := PackedColorArray([marks])
		for q in [[Vector2(x0, y0), 1.0, 1.0], [Vector2(x1, y0), -1.0, 1.0], [Vector2(x1, y1), -1.0, -1.0], [Vector2(x0, y1), 1.0, -1.0]]:
			var o: Vector2 = q[0]
			var sx: float = q[1]
			var sy: float = q[2]
			RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([o + Vector2(sx * l, 0), o, o + Vector2(0, sy * l)]), col, 1.0, true)
