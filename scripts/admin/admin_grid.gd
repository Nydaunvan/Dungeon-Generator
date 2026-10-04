class_name AdminGrid
extends GridContainer
## Grille de `AdminTable` qui trace les filets du `.data-table` : sous l'en-tête (couleur de bordure du panneau) puis,
## très discret, sous chaque ligne (rgba(255,255,255,0.04)).

const HEAD_RULE := Color("5a4526")
const ROW_RULE := Color(1, 1, 1, 0.04)

func _draw() -> void:
	var n := get_child_count()
	if columns <= 0 or n == 0:
		return
	var vsep := float(get_theme_constant("v_separation"))
	var row := 0
	while row * columns < n:
		var bottom := 0.0
		for c in range(row * columns, mini(n, (row + 1) * columns)):
			var ch := get_child(c) as Control
			if ch != null and ch.visible:
				bottom = maxf(bottom, ch.position.y + ch.size.y)
		var y := bottom + vsep * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), HEAD_RULE if row == 0 else ROW_RULE, 1.0)
		row += 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		queue_redraw()
