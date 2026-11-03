extends Control
## Capture de la carte des liens (rose des vents) avec tous les types de lien : godot --path . res://tools/shot_liens.tscn -- out=/chemin/nom [n=6]
func _ready() -> void:
	var a := {"out": "/tmp/liens", "n": "6"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	get_window().size = Vector2i(1280, 900)
	await get_tree().process_frame
	var bg := ColorRect.new()
	bg.color = Color("14171c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var all := [
		{"name": "Éclat de Givre (Zael)", "type": "complementaire", "level": 2},
		{"name": "Soin (Sable)", "type": "protectrice", "level": 1},
		{"name": "Cri de Guerre (Mira)", "type": "rivale", "level": 3},
		{"name": "Lumière Sacrée (Sable)", "type": "antagoniste", "level": 1},
		{"name": "Brasier (Thane)", "type": "fusionnelle", "level": 3},
		{"name": "Rempart (Mira)", "type": "complementaire", "level": 1},
	]
	var v := LivingViz.web("Lumière Sacrée", all.slice(0, int(a.n)))
	v.position = Vector2(380, 200)
	v.size = Vector2(520, 390)
	add_child(v)
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(str(a.out) + ".png")
	get_tree().quit()
