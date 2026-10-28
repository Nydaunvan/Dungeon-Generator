class_name ViewRule
extends Control
## Filets de la vue 3D pleine largeur (Atlas Noir) : le bord haut « décroche » au-dessus de la colonne de la carte
## (marche en biais), et un filet fin ferme la vue en bas. Ne reçoit aucun clic.

var step_x: float = 0.0      ## fin de la colonne de gauche (0 = pas de décroché)
var step_h: float = 14.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var col := Color(Atlas.COPPER, 0.75)
	var w := size.x
	var h := size.y
	if step_x > 0.0 and step_x < w - 40.0:
		var d := step_h
		# le coin haut-gauche de la vue est découpé : on le recouvre de noir, puis on trace la marche
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(step_x + d, 0), Vector2(step_x, step_h), Vector2(0, step_h)]), Color("07090a"))
		draw_polyline(PackedVector2Array([Vector2(0, step_h), Vector2(step_x, step_h), Vector2(step_x + d, 0.5), Vector2(w, 0.5)]), col, 1.0, true)
		Atlas.draw_diamond(self, Vector2(2.0, step_h), 2.5, Atlas.COPPER)
	else:
		draw_line(Vector2(0, 0.5), Vector2(w, 0.5), col, 1.0, true)
	draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(Atlas.COPPER_DIM, 0.8), 1.0, true)
