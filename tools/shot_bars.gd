extends SceneTree
## Capture de MiniBars seul (usage : --script res://tools/shot_bars.gd -- <sortie.png>)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(700, 260)
	await process_frame
	var bg := ColorRect.new()
	bg.color = Color("1c1814")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	var vals := []
	var labs := []
	for i in 14:
		vals.append(5 + (i * 5) % 11)
		labs.append("09-%02d" % (i + 1))
	v.add_child(MiniBars.new().setup(vals, labs, Color("d4a24c")))
	v.add_child(MiniBars.new().setup([0, 0, 0], ["a", "b", "c"], Color("9cc79a")))
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/bars.png")
	quit()
