extends SceneTree
# Cycle accueil -> donjon aléatoire -> accueil x3 (vérifie l'absence d'erreur et de fuite d'état).
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	for i in 3:
		var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], i + 1)
		data.launch(cfg, "random")
		await create_timer(1.2).timeout
		var cur := current_scene
		print("run ", i, " scene=", cur.name if cur else "null", " party=", cur.gs.party.size() if cur and "gs" in cur else -1)
		data.go_home()
		await create_timer(0.8).timeout
		print("home ", i, " scene=", current_scene.name if current_scene else "null")
	quit()
