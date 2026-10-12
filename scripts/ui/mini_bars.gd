class_name MiniBars
extends Control
## Petit histogramme (une barre par jour) pour les statistiques d'activité de l'administration : valeur maximale à gauche,
## première et dernière date en dessous, valeur de chaque barre au survol.

var values: Array = []
var labels: Array = []
var color := Color("d4a24c")
var _hover := -1

func _init() -> void:
	custom_minimum_size = Vector2(0, 74)
	mouse_filter = Control.MOUSE_FILTER_PASS

func setup(v: Array, l: Array, c: Color) -> MiniBars:
	values = v
	labels = l
	color = c
	tooltip_text = ""
	queue_redraw()
	return self

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and not values.is_empty():
		var area := _area()
		var i := int((e.position.x - area.position.x) / (area.size.x / values.size()))
		i = clampi(i, 0, values.size() - 1)
		if i != _hover:
			_hover = i
			tooltip_text = "%s : %d" % [str(labels[i]), int(values[i])]
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()

func _area() -> Rect2:
	return Rect2(34, 4, maxf(10.0, size.x - 38), size.y - 22)

func _draw() -> void:
	if values.is_empty():
		return
	var font := ThemeDB.fallback_font
	var area := _area()
	var top := 1.0
	for v in values:
		top = maxf(top, float(v))
	draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), Color(1, 1, 1, 0.25))
	draw_string(font, Vector2(0, area.position.y + 10), str(int(top)), HORIZONTAL_ALIGNMENT_LEFT, 32, 11, Color(1, 1, 1, 0.6))
	var w := area.size.x / values.size()
	for i in values.size():
		var h := area.size.y * float(values[i]) / top
		var c := color.lightened(0.25) if i == _hover else color
		draw_rect(Rect2(area.position.x + i * w + 1, area.end.y - h, maxf(1.0, w - 2), h), c)
	draw_string(font, Vector2(area.position.x, size.y - 4), str(labels[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(area.end.x - 60, size.y - 4), str(labels[labels.size() - 1]), HORIZONTAL_ALIGNMENT_RIGHT, 60, 11, Color(1, 1, 1, 0.6))
