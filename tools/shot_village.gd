extends SceneTree
## Capture du village en 3D. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_village.gd -- <sortie.png> [dir] [x] [y]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	m._enter_village()
	await create_timer(4.0).timeout
	var views: Array = a.slice(1)
	var out := str(a[0]) if a.size() > 0 else "/tmp/claude-0/village.png"
	var lv: Dictionary = m.gs.cfg.levels[0]
	var tm: Dictionary = lv.travelingMerchant
	print("marchand en ", tm.x, ",", tm.y, " forgeron ", lv.blacksmith.x, ",", lv.blacksmith.y, " talents ", lv.talentMaster.x, ",", lv.talentMaster.y)
	var shots := [[0, 7, 22], [2, 7, 22], [0, 7, 40], [1, 7, 12], [3, 7, 33], [0, 7, 3]]
	if a.size() >= 4:
		shots = []
		var k := 1
		while k + 2 < a.size() + 0:
			shots.append([int(a[k]), int(a[k + 1]), int(a[k + 2])])
			k += 3
	var i := 0
	for s in shots:
		m.rig.place(m.grid, s[1], s[2], s[0])
		await create_timer(1.5).timeout
		root.get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%d.png" % i))
		i += 1
	quit()
