extends Node
## « Instinct de survie » : héros à 1 PV, le monstre frappe → le coup est suspendu, le bouton rouge apparaît (capture), un appui le résout ;
## un second coup mortel sur le même héros ne propose plus l'instinct (une fois par combat).
## Usage : xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 res://tools/check_instinct.tscn -- out=/tmp/i

var prompts := 0
var outcomes: Array = []

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var out := str(args.get("out", "/tmp/i"))
	var tree := get_tree()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await tree.create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var placed := false
	for m in main.level.monsters:
		var st0: Dictionary = lst.get(str(m.id), {})
		if st0.is_empty() or not st0.alive or m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st0.x), int(st0.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				st0["atkMin"] = 500.0
				st0["atkMax"] = 500.0
				placed = true
				break
		if placed:
			break
	for c in main.gs.party:
		c["hp"] = 1
	main.ctrl.instinct_prompt.connect(func(cid, secs):
		prompts += 1
		print("PROMPT ", cid, " ", secs, " s"))
	main.ctrl.instinct_end.connect(func(o): outcomes.append(o))
	main.ctrl.refresh()
	var t0 := Time.get_ticks_msec()
	var shot := false
	var pressed := 0
	while Time.get_ticks_msec() - t0 < 90000 and pressed < 2:
		await tree.process_frame
		if main.ctrl.instinct_waiting and not shot:
			shot = true
			await tree.create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(out + "_prompt.png")
		if main.ctrl.instinct_waiting:
			await tree.create_timer(2.2).timeout     # appui tardif = « parfait »
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			main.instinct_ui._on_seal_input(ev)
			pressed += 1
			await tree.create_timer(1.5).timeout
			get_viewport().get_texture().get_image().save_png("%s_after%d.png" % [out, pressed])
		elif not main.ctrl._busy and main.gs.active_char_id != "" and main.ctrl.model_in_combat():
			main.ctrl.skip_active_turn("%s passe")
	print("RESULTAT instinct : invites=%d résultats=%s game_over=%s -> %s" % [prompts, str(outcomes), str(main.gs.game_over), "OK" if prompts >= 1 and outcomes.size() >= 1 else "ECHEC"])
	get_tree().quit()
