class_name MapLegend
extends Control
## Légende de la carte (sous le plan) : une ligne par élément réellement dessiné par `Minimap`, avec le filet vertical orné
## et le petit repère en croix de la maquette Atlas Noir.

const ITEMS := [
	["you", "ui.atlas.leg_you"], ["cell", "ui.atlas.leg_cell"], ["door", "ui.atlas.leg_door"], ["stairs", "ui.atlas.leg_stairs"],
	["chest", "ui.atlas.leg_chest"], ["fountain", "ui.atlas.leg_fountain"], ["monster", "ui.atlas.leg_monster"],
]
const X0 := 26.0     # début des symboles (à droite du filet vertical)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiMetrics.register(self)
	rescale()

func rescale() -> void:
	custom_minimum_size = Vector2(0, ITEMS.size() * _row() + 10.0)
	queue_redraw()

func _row() -> float:
	return UiMetrics.css(21.0)

func _draw() -> void:
	var rh := _row()
	var f := Atlas.font(Atlas.F_BODY_MED)
	var fs := int(UiMetrics.css(12.0))
	var h := ITEMS.size() * rh
	# filet vertical orné, en retrait
	draw_line(Vector2(6.0, 6.0), Vector2(6.0, h), Color(Atlas.COPPER, 0.5), 1.0)
	Atlas.draw_diamond(self, Vector2(6.0, 4.0), 3.0, Atlas.COPPER)
	draw_line(Vector2(6.0, 4.0), Vector2(16.0, 4.0), Color(Atlas.COPPER, 0.5), 1.0)
	for i in ITEMS.size():
		var cy := 10.0 + i * rh + rh * 0.5
		var s := Vector2(X0, cy)
		match ITEMS[i][0]:
			"you":
				draw_colored_polygon(PackedVector2Array([s + Vector2(-4, -5.5), s + Vector2(5.5, 0), s + Vector2(-4, 5.5)]), Atlas.AMBER)
			"cell":
				draw_rect(Rect2(s - Vector2(5.5, 5.5), Vector2(11, 11)), Color("3c4140"))
				draw_rect(Rect2(s - Vector2(5.5, 5.5), Vector2(11, 11)), Color("8a8f88"), false, 1.0)
			"door":
				draw_rect(Rect2(s - Vector2(5.5, 5.5), Vector2(11, 11)), Color("4a3a28"))
				draw_rect(Rect2(s - Vector2(5.5, 5.5), Vector2(11, 11)), Atlas.AMBER, false, 1.0)
				draw_rect(Rect2(s - Vector2(2, 2), Vector2(4, 4)), Atlas.AMBER)
			"stairs":
				draw_colored_polygon(PackedVector2Array([s + Vector2(0, -5.5), s + Vector2(5.5, 4.5), s + Vector2(-5.5, 4.5)]), Color("ffe08a"))
			"chest":
				draw_rect(Rect2(s - Vector2(4.5, 4.5), Vector2(9, 9)), Color("e0a93a"))
			"fountain":
				draw_arc(s, 5.0, 0.0, TAU, 20, Color("6fd0e8"), 1.4, true)
				draw_circle(s, 2.0, Color("6fd0e8"))
			"monster":
				draw_arc(s, 5.0, 0.0, TAU, 20, Color("c23b3b"), 1.4, true)
				draw_circle(s, 2.2, Color("c23b3b"))
		draw_string(f, Vector2(X0 + 18.0, cy + fs * 0.34), L.t(str(ITEMS[i][1])), HORIZONTAL_ALIGNMENT_LEFT, size.x - X0 - 20.0, fs, Atlas.IVORY)
