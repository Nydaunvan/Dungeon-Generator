extends Node
func _ready() -> void:
	var root := get_tree().root
	root.size = Vector2i(1280, 800)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var rig = main.rig
	var fwd: Vector2i = DungeonGrid.DIRS[rig.dir]
	var c := Vector2i(rig.gx, rig.gy) + fwd
	print("walkable ahead: ", main.grid.is_walkable(c.x, c.y), " dir ", rig.dir)
	var pend := TrapPendulum.make()
	pend.position = Vector3(c.x * LevelBuilder.CELL, 0.0, c.y * LevelBuilder.CELL)
	pend.rotation.y = -PI * 0.5 * rig.dir
	main.level_node.add_child(pend)
	pend.playing = false
	var out := "/tmp/pend"
	var phases := [0.0, 0.12, 0.25, 0.4, 0.5, 0.75]
	for i in phases.size():
		pend.t = phases[i] * TrapPendulum.PERIOD
		pend._apply(sin(TAU * phases[i]))
		await get_tree().create_timer(0.35).timeout
		root.get_texture().get_image().save_png("%s_%d.png" % [out, i])
	pend.playing = true
	pend.lock(1, false)
	await get_tree().create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out + "_lock.png")
	get_tree().quit()
