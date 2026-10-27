extends Node
## Captures de l'interface (/tmp/studio_*.png) : modèle, squelette, animation.
func _ready() -> void:
	get_window().size = Vector2i(1360, 800)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(0.5).timeout
	var src := ProjectSettings.globalize_path("res://").path_join("../assets/monsters/boss_golem.webp")
	app.import_paths([src])
	await get_tree().create_timer(0.5).timeout
	app.converter.use_test(app.cur, "biped")
	await get_tree().create_timer(0.8).timeout
	app.place_skeleton("biped")
	app.tabs.current_tab = 1
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/studio_1.png")
	await app.compute_skin()
	app.tabs.current_tab = 2
	await get_tree().create_timer(0.3).timeout
	app._play("walk")
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/studio_2.png")
	get_tree().quit()
