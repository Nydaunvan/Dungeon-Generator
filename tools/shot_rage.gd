extends Node
## Rendu réel (xvfb + opengl3) d'un monstre en rage : /tmp/claude-0/rage.png. godot --path . --rendering-driver opengl3 res://tools/shot_rage.tscn
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
		if stt.is_empty() or not stt.alive or (OS.get_environment("RAGE_NONBOSS") != "" and bool(m.get("isBoss", false))):
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
	print("REAL placed=", found)
	var eng: Dictionary = main.ctrl.combat.engaged()
	if not eng.is_empty():
		var st: Dictionary = main.ctrl.combat.lstate().monsters[str(eng.monster.id)]
		eng.monster["enrageThreshold"] = 40
		eng.monster["enrageBonusPct"] = 30
	main.ctrl.refresh()
	await get_tree().create_timer(1.0).timeout
	if not eng.is_empty():
		var st2: Dictionary = main.ctrl.combat.lstate().monsters[str(eng.monster.id)]
		st2["enraged"] = true
	main.ctrl.refresh()
	for i in 4:
		await get_tree().create_timer([0.25, 0.35, 0.6, 1.5][i]).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/rage_%d.png" % i)
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/rage.png")
	print("RAGE ", not eng.is_empty())
	get_tree().quit()
