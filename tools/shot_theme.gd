extends Node
## Rendu réel (xvfb + opengl3) d'un niveau en thème « THEME » (variable d'environnement, défaut damp) : /tmp/claude-0/theme_<thème>.png
## godot --path . --rendering-driver opengl3 res://tools/shot_theme.tscn
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var theme := OS.get_environment("THEME") if OS.get_environment("THEME") != "" else "damp"
	for lv in Data.active().levels:
		lv["theme"] = theme
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(6.0).timeout
	var mats: Dictionary = ThemeMaterials.for_theme(theme)
	print("THEME ", theme, " mur=", (mats.wall as StandardMaterial3D).albedo_texture.resource_path)
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/theme_%s.png" % theme)
	get_tree().quit()
