extends Node
## Plein écran : le jeu démarre en plein écran sur PC (réglage du projet) ; F11 ou Alt+Entrée bascule fenêtre ↔ plein écran.

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	Settings.set_fullscreen(not Settings.is_fullscreen())   # applique et mémorise le choix
