class_name MapLegend
extends Control
## Légende compacte de la carte : un symbole par élément réellement dessiné par `Minimap`, sur deux colonnes.

const ITEMS := [
	["you", "ui.atlas.leg_you"], ["cell", "ui.atlas.leg_cell"], ["door", "ui.atlas.leg_door"], ["stairs", "ui.atlas.leg_stairs"],
	["chest", "ui.atlas.leg_chest"], ["fountain", "ui.atlas.leg_fountain"], ["monster", "ui.atlas.leg_monster"],
]
const ROW_H := 18.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, ceilf(ITEMS.size() / 2.0) * ROW_H)

func _draw() -> void:
	var col_w := size.x * 0.5
	var f := Atlas.font(Atlas.F_BODY)
	for i in ITEMS.size():
		var cx := float(i % 2) * col_w
		var cy := float(i / 2) * ROW_H + ROW_H * 0.5
		var s := Vector2(cx + 8.0, cy)
		match ITEMS[i][0]:
			"you":
				draw_colored_polygon(PackedVector2Array([s + Vector2(0, -5), s + Vector2(4.5, 4), s + Vector2(-4.5, 4)]), Atlas.AMBER)
			"cell":
				draw_rect(Rect2(s - Vector2(4.5, 4.5), Vector2(9, 9)), Color("343b36"))
				draw_rect(Rect2(s - Vector2(4.5, 4.5), Vector2(9, 9)), Atlas.IVORY_DIM, false, 1.0)
			"door":
				draw_rect(Rect2(s - Vector2(3, 4.5), Vector2(6, 9)), Atlas.AMBER_DIM)
				draw_rect(Rect2(s - Vector2(3, 4.5), Vector2(6, 9)), Atlas.AMBER, false, 1.0)
			"stairs":
				draw_colored_polygon(PackedVector2Array([s + Vector2(0, -4.5), s + Vector2(4.5, 3.5), s + Vector2(-4.5, 3.5)]), Color("ffe08a"))
			"chest":
				draw_rect(Rect2(s - Vector2(4, 4), Vector2(8, 8)), Color("e0a93a"))
			"fountain":
				draw_circle(s, 4.2, Color("6fd0e8"))
			"monster":
				draw_circle(s, 4.0, Color("c23b3b"))
		var fs := 11
		draw_string(f, Vector2(cx + 20.0, cy + fs * 0.34), L.t(str(ITEMS[i][1])), HORIZONTAL_ALIGNMENT_LEFT, col_w - 22.0, fs, Atlas.IVORY_DIM)
