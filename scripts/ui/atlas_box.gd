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
