extends Control
## Captures de la visibilité des compétences vivantes : disques de sorts (paliers 0-4, évolutions, marqueur) et présentation guidée.
## godot --path . res://tools/shot_visibilite.tscn -- out=/chemin/nom case=disques|intro page=0..3
func _ready() -> void:
	var a := {"w": "1280", "h": "720", "out": "/tmp/vis", "case": "disques", "page": "0"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	get_window().size = Vector2i(int(a.w), int(a.h))
	await get_tree().process_frame
	var bg := ColorRect.new()
	bg.color = Color("14100c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if str(a.case) == "disques":
		var row := HBoxContainer.new()
		row.position = Vector2(60, 80)
		row.add_theme_constant_override("separation", 14)
		add_child(row)
		var specs := [[0, 0, false], [1, 0, false], [2, 0, true], [3, 1, false], [4, 1, true], [4, 2, true]]
		for sp in specs:
			var d := SpellDisc.new()
			d.custom_minimum_size = Vector2(110, 130)
			d.set_state("⚔", null, "", 1.0)
			d.set_living(sp[0], sp[1], sp[2])
			row.add_child(d)
	else:
		var host := Control.new()
		host.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(host)
		var li := LivingIntro.open(host)
		li.page = int(a.page)
		li._render()
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(str(a.out) + ".png")
	get_tree().quit()
