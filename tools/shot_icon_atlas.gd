extends Node
## Catégorie d'icônes « Monstres Atlas Noir » du sélecteur (et vignettes à 40 et 160 px).
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("17130e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var names: Array = []
	for c in IconPicker.catalog():
		names.append(str(c[0]))
	print("CATEGORIES: ", names)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 20)
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	for sz in [40.0, 160.0]:
		row.add_child(IconPicker.icon_control("@icon:mon_veilleur_os", sz))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/97f20bf3-1ee6-5379-b46f-c57472fef5c6/scratchpad/icon_atlas.png")
	get_tree().quit()
