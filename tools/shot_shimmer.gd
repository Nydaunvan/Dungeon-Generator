extends SceneTree
## Mesure du scintillement d'un sprite de monstre : 24 images consécutives du monstre à distance dans le couloir ; on compare chaque image
## à la précédente sur la zone du sprite (différence moyenne ; plus c'est bas, plus c'est calme).
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script res://tools/shot_shimmer.gd -- out=/tmp/sh icon=mon_veilleur_os
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1600, 900)
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	for mm in main.level.monsters:
		mm["icon"] = "@icon:" + str(args.get("icon", "mon_veilleur_os"))
		mm.erase("isBoss")
	main.load_level(main.level_index)
	await create_timer(1.5).timeout
	main.wand.paused_if = func(): return true
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var placed := false
	for m in main.level.monsters:
		var st: Dictionary = lst.get(str(m.id), {})
		if st.is_empty() or not st.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var p := Vector2i(int(st.x), int(st.y))
			if main.grid.is_walkable(p.x - v.x, p.y - v.y) and main.grid.is_walkable(p.x - 2 * v.x, p.y - 2 * v.y):
				main.rig.place(main.grid, p.x - 2 * v.x, p.y - 2 * v.y, d)
				placed = true
				break
		if placed:
			break
	print("PLACED ", placed)
	await create_timer(2.0).timeout
	var frames: Array = []
	for i in 60:
		await create_timer(0.05).timeout
		frames.append(root.get_texture().get_image())
	frames[0].save_png(str(args.get("out", "/tmp/sh")) + ".png")
	var w := 1600
	var h := 900
	var r := Rect2i(int(w * 0.38), int(h * 0.2), int(w * 0.24), int(h * 0.6))
	var tot := 0.0
	for i in range(1, frames.size()):
		var a: Image = frames[i - 1].get_region(r)
		var b: Image = frames[i].get_region(r)
		var s := 0.0
		for y in range(0, r.size.y, 2):
			for x in range(0, r.size.x, 2):
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				s += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
		tot += s / float((r.size.x / 2) * (r.size.y / 2))
	print("SHIMMER ", tot / float(frames.size() - 1))
	quit()
