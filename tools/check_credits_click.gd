extends Node
## Pied de page du jeu : seul un clic sur « Made by Claude & Nydaunvan » ouvre la page de remerciements (pas sur toute la largeur).
## Usage : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/check_credits_click.tscn

var _n := 0

func _click(vp: Viewport, p: Vector2) -> void:
	p = vp.get_final_transform() * p     # coordonnées de la fenêtre (la mise à l'échelle du contenu déplace les positions)
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	vp.push_input(mv)
	await get_tree().process_frame
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		vp.push_input(ev)
	await get_tree().process_frame
	await get_tree().process_frame

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var lay = main.layout
	lay.credits_pressed.connect(func(): _n += 1)
	var vp := get_viewport()
	lay._scroll.scroll_vertical = 100000
	await get_tree().create_timer(0.5).timeout
	print("fenêtre ", vp.get_visible_rect())
	var made: Button = lay.footer.get_child(1)
	var fr: Rect2 = lay.footer.get_global_rect()
	var br: Rect2 = made.get_global_rect()
	print("pied de page ", fr, " ; bouton ", br)
	await _click(vp, Vector2(fr.position.x + 20.0, br.get_center().y))
	var bad := 0
	if _n != 0:
		print("ÉCHEC : un clic loin du texte ouvre les remerciements")
		bad += 1
	await _click(vp, Vector2(fr.position.x + 20.0, fr.position.y + 4.0))
	if _n != 0:
		print("ÉCHEC : un clic sur la ligne de version ouvre les remerciements")
		bad += 1
	await _click(vp, br.get_center())
	print("survolé : ", vp.gui_get_hovered_control(), " visible=", made.is_visible_in_tree(), " n=", _n)
	if _n != 1:
		print("ÉCHEC : un clic sur « Made by » n'ouvre pas les remerciements (", _n, ")")
		bad += 1
	print("OK" if bad == 0 else "%d échec(s)" % bad)
	get_tree().quit(1 if bad else 0)
