extends Node
## Rendu réel des statuts persistants : /tmp/claude-0/status_N.png. godot --path . --rendering-driver opengl3 res://tools/shot_status.tscn
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var stt: Dictionary = lst.get(str(m.id), {})
		if stt.is_empty() or not stt.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(stt.x), int(stt.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				found = true
				break
		if found:
			break
	main.ctrl.refresh()
	await get_tree().create_timer(2.5).timeout
	var eng: Dictionary = main.ctrl.combat.engaged()
	print("ENGAGED ", not eng.is_empty())
	var st: Dictionary = main.ctrl.combat.lstate().monsters[str(eng.monster.id)]
	var sets := [
		[["burn", ""], ["burn"]],
		[["stun", "sleep"], ["poison"]],
		[["burn", ""], ["freeze"]],
		[["poison", ""], ["weaken", ""]],
	]
	var n := 0
	for s in sets:
		st["statusEffects"] = [{"type": s[0][0], "remaining": 3, "power": 2, "casterId": "x", "look": s[0][1]}]
		for h in main.gs.party:
			h["statusEffects"] = [{"type": s[1][0], "remaining": 3, "power": 2, "casterId": "x", "look": ""}]
		main.ctrl.refresh()
		await get_tree().create_timer(1.4).timeout
		for k in main.card_fx._auras: var a = main.card_fx._auras[k]; print("AURA ", a.position, a.ext, a.get_child_count(), a.is_inside_tree(), main.card_fx._cam.fov)
		print("DBG entries=", main._hero_status_entries().size(), " auras=", main.card_fx._auras.size(), " vis=", main.card_fx.visible, " size=", main.card_fx.size, " ref=", main.card_fx.ref_cam != null, main.card_fx.ref_view != null)
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/status_%d.png" % n)
		n += 1
	get_tree().quit()
