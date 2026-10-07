class_name KeyCapture
extends Node
## Écoute la prochaine touche pressée (réassignation d'une commande). Échap annule ; un clic ailleurs annule aussi.
## Placé en dernier enfant de la fenêtre : il reçoit les touches avant elle, donc Échap n'a pas à fermer la fenêtre.

signal captured(code: int)
signal cancelled

func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null:
		if not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		if k.keycode == KEY_ESCAPE:
			cancelled.emit()
			return
		var c := Keybinds.code_of(k)
		if c == 0 or Keybinds.is_modifier(c):
			return
		captured.emit(c)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		cancelled.emit()
