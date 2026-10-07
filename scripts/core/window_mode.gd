extends Node
## Plein écran : le jeu démarre en plein écran sur PC (réglage du projet) ; la touche réglable (F11 par défaut) ou Alt+Entrée bascule fenêtre ↔ plein écran.

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if Keybinds.matches("fullscreen", e) or (e.keycode == KEY_ENTER and e.alt_pressed):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	Settings.set_fullscreen(not Settings.is_fullscreen())   # applique et mémorise le choix
