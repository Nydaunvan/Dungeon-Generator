extends Node
## Rendu réel du sceau de l'accueil hors ligne puis connecté (session simulée) : /tmp/claude-0/home_off.png, home_on.png
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var home: Node = load("res://scenes/home.tscn").instantiate()
	add_child(home)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/home_off.png")
	Cloud.session = {"refresh_token": "fake", "pseudo": "Test"}
	Cloud.session_changed.emit()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/home_on.png")
	Cloud.session = {}
	Cloud.session_changed.emit()
	await get_tree().create_timer(0.5).timeout
	print("TITRE ", home.screen._seal_title.text)
	get_tree().quit()
