extends Node
## Plein écran : le jeu démarre en plein écran sur PC (réglage du projet) ; F11 ou Alt+Entrée bascule fenêtre ↔ plein écran.

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
