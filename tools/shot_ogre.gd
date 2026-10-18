extends Node
## Vignettes de monstres de la planche (ogre dont le marteau était rogné, loup, troll) à 64 et 200 px.
func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("23405f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 20)
	row.add_theme_constant_override("separation", 20)
	add_child(row)
	for id in ["mon_ogre", "mon_wolf", "mon_troll"]:
		for sz in [64.0, 220.0]:
			row.add_child(IconPicker.icon_control("@icon:" + id, sz))
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/ogre_shot.png")
	get_tree().quit()
