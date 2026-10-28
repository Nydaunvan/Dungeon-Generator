class_name AtlasCompass
extends Control
## Repère d'orientation du bas de la vue 3D : un filet gradué, le cap actuel au centre (losange ambre),
## et les points cardinaux voisins de part et d'autre. Il suit `dir` (0 = N, 1 = E, 2 = S, 3 = O).

const LETTERS := ["N", "E", "S", "O"]
var dir: int = 0:
	set(v):
		if v != dir:
			dir = v
			queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 38)

func _draw() -> void:
	var c := size * 0.5
	var y := c.y + 4.0
	var half := size.x * 0.5 - 4.0
	var col := Color(Atlas.IVORY, 0.55)
	# filet qui s'estompe vers les extrémités
	var steps := 24
	for i in steps:
		var a0 := float(i) / steps
		var a1 := float(i + 1) / steps
		var al := 0.15 + 0.5 * (1.0 - absf(a0 * 2.0 - 1.0))
		draw_line(Vector2(c.x - half + a0 * half * 2.0, y), Vector2(c.x - half + a1 * half * 2.0, y), Color(Atlas.IVORY, al), 1.0, true)
	var step := size.x / 4.0
	for k in range(-2, 3):
		var x := c.x + k * step
		var d := posmod(dir + k, 4)
		var cur := k == 0
		var f := Atlas.title_font(true, 1)
		var fs := 13 if cur else 11
		var ts := f.get_string_size(LETTERS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2(x - ts.x * 0.5, y - 11.0), LETTERS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.AMBER if cur else Color(Atlas.IVORY, 0.7))
		draw_line(Vector2(x, y), Vector2(x, y - 6.0), Atlas.AMBER if cur else col, 1.0)
		if k < 2:
			for t in range(1, 4):
				var tx := x + step * float(t) / 4.0
				draw_line(Vector2(tx, y), Vector2(tx, y - (4.0 if t == 2 else 2.5)), Color(Atlas.IVORY, 0.35), 1.0)
	Atlas.draw_diamond(self, Vector2(c.x, y + 7.0), 4.5, Atlas.AMBER)
	Atlas.draw_diamond(self, Vector2(c.x - half, y), 3.0, Atlas.COPPER)
	Atlas.draw_diamond(self, Vector2(c.x + half, y), 3.0, Atlas.COPPER)
