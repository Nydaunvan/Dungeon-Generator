extends Node
## Capture de l'interrupteur mural (levier haut puis bas) posé sur le mur le plus proche du départ. Usage : … res://tools/shot_wall_lever.tscn -- <préfixe>
func _ready() -> void:
	var root := get_tree().root
	root.size = Vector2i(1280, 800)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var rig = main.rig
	var pre: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/lever"
	# mur latéral de la case située devant le joueur : le levier s'y pose, à hauteur d'yeux
	var fwd: Vector2i = DungeonGrid.DIRS[rig.dir]
	var cell := Vector2i(rig.gx, rig.gy) + fwd
	var side := Vector2i(-fwd.y, fwd.x)
	if main.grid.cell(cell.x + side.x, cell.y + side.y) != "#":
		side = -side
	var lv := WallLever.make()
	lv.position = Vector3((cell.x + side.x * 0.5) * LevelBuilder.CELL, WallLever.HEIGHT, (cell.y + side.y * 0.5) * LevelBuilder.CELL)
	lv.rotation.y = TrapDart.yaw_for(side)
	main.level_node.add_child(lv)
	await get_tree().create_timer(0.5).timeout
	root.get_texture().get_image().save_png(pre + "_up.png")
	WallLever.pull(lv, true)
	await get_tree().create_timer(0.9).timeout
	root.get_texture().get_image().save_png(pre + "_down.png")
	get_tree().quit()
