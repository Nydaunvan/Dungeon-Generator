extends Node
## Mort d'un membre de groupe : le membre tombé s'effondre seul, les autres glissent vers leur nouvelle place (captures à t = 0,15 / 0,3 / 1,2 s).
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var stage = main.level_node.stage
	var def := {"id": "tst", "name": "Gobelins", "icon": "@icon:mon_cavegoblin", "isGroup": true, "groupSize": 3}
	var st := {"alive": true, "enraged": false, "hp": 30.0, "maxHp": 30.0,
		"members": [{"alive": true, "hp": 10.0}, {"alive": true, "hp": 10.0}, {"alive": true, "hp": 10.0}]}
	var eng_pos := Vector2i(main.rig.gx, main.rig.gy)
	var dir := int(main.rig.dir) if "dir" in main.rig else 0
	main.layout.sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.enter("stone", eng_pos, dir, def, st, 1)
	await get_tree().create_timer(1.0).timeout
	var out := str(args.get("out", "/tmp/g"))
	get_viewport().get_texture().get_image().save_png(out + "_0.png")
	st.members[1].alive = false
	stage.enter("stone", eng_pos, dir, def, st, 0)
	var t0 := Time.get_ticks_msec()
	var shots := [300, 900, 3500]
	var n := 1
	for ms in shots:
		while Time.get_ticks_msec() - t0 < ms:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, n])
		n += 1
	print("RESULTAT noeuds restants : ", stage._nodes.size())
	get_tree().quit()
