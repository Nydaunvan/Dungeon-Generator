extends Node
## Capture de l'écran « Préparer l'expédition » (fenêtre complète, puis avec des choix faits).
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/shot_expedition.tscn   (images dans /tmp/exp_*.png)
func _ready() -> void:
	var root := get_tree().root
	root.size = Vector2i(1280, 800)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("120d09")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	add_child(layer)
	await get_tree().create_timer(2.0).timeout
	GeneratorDialog.open(layer, func(cfg): print("lancé : ", (cfg.party as Array).map(func(h): return str(h.classId) + ":" + str(h.portrait))))
	await get_tree().create_timer(1.2).timeout
	root.get_texture().get_image().save_png("/tmp/exp_0.png")
	var scr: ExpeditionScreen = null
	for m in get_tree().get_nodes_in_group("modal"):
		scr = m.get_meta("screen")
		var sc: ScrollContainer = m._scroll
		sc.scroll_vertical = 600
	await get_tree().create_timer(0.5).timeout
	root.get_texture().get_image().save_png("/tmp/exp_1.png")
	scr._mods = ["mod_horde", "mod_crit"]
	scr._diff = "hard"
	scr._levels = 6
	scr._width = 40
	scr._height = 40
	scr._active = 2
	scr._slots[2].c = 5
	scr._slots[2].p = 1
	scr._refresh_all()
	await get_tree().create_timer(0.6).timeout
	root.get_texture().get_image().save_png("/tmp/exp_2.png")
	for m in get_tree().get_nodes_in_group("modal"):
		m._scroll.scroll_vertical = 600
	await get_tree().create_timer(0.4).timeout
	root.get_texture().get_image().save_png("/tmp/exp_3.png")
	get_tree().quit()
