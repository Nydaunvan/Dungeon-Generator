extends Node
## Rendu réel de l'infobulle de l'attaque de base : /tmp/claude-0/atk_tip.png
func _find(n: Node, out: Array) -> void:
	if n is SpellBar:
		out.append(n)
	for c in n.get_children():
		_find(c, out)
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	var bars: Array = []
	_find(main, bars)
	print("BARS ", bars.size())
	if not bars.is_empty():
		bars[0]._attack.tip_show.emit()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/atk_tip.png")
	get_tree().quit()
