class_name UiFx
extends RefCounted
## Petites animations d'interface (équivalents des transitions CSS du HTML).

## Grossit légèrement au survol.
static func hover_pop(c: Control, scale_to: float = 1.06) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.mouse_entered.connect(func():
		c.pivot_offset = c.size * 0.5
		var t := c.create_tween()
		t.tween_property(c, "scale", Vector2(scale_to, scale_to), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
	c.mouse_exited.connect(func():
		var t := c.create_tween()
		t.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

## Apparition d'une fenêtre : fondu + léger zoom arrière (keyframe « combatModalIn » : opacity 0→1, scale 1.06→1).
static func pop_in(c: Control, seconds: float = 0.18) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.06, 1.06)
	c.modulate.a = 0.0
	var t := c.create_tween().set_parallel(true)
	t.tween_property(c, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "modulate:a", 1.0, seconds)

## Pulsation lente de la transparence (emplacements cibles).
static func pulse(c: CanvasItem, lo: float = 0.15, hi: float = 0.85, seconds: float = 1.1) -> Tween:
	var t := c.create_tween().set_loops()
	t.tween_property(c, "modulate:a", hi, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "modulate:a", lo, seconds * 0.5).set_trans(Tween.TRANS_SINE)
	return t
