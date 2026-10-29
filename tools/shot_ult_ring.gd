extends SceneTree
## Capture de l'anneau lumineux de l'ultime à plusieurs niveaux de charge, sur fond noir, à deux instants de la pulsation.
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_ult_ring.gd
func _init() -> void:
	root.size = Vector2i(760, 220)
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("07090a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var discs: Array = []
	var x := 20.0
	for spec in [[0.0, true], [0.0, false], [0.35, false], [0.75, false], [1.0, false]]:
		var d := SpellDisc.new()
		d.tone = "ult"
		d.custom_minimum_size = Vector2(110, 110)
		d.size = Vector2(110, 110)
		d.position = Vector2(x, 45)
		d.set_caption("8")
		bg.add_child(d)
		d.set_ult(float(spec[0]), bool(spec[1]))
		discs.append(d)
		x += 144.0
	for i in 2:
		await create_timer(0.35 + 0.5 * i).timeout
		await process_frame
		root.get_texture().get_image().save_png("/tmp/ult_ring_%d.png" % i)
	quit()
