extends SceneTree
## Deux monstres adjacents (devant et derrière) : une fois le premier tué, le groupe doit se tourner vers le second.

func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	var ctrl = m.ctrl
	var combat = ctrl.combat
	var fails := 0
	# on cherche deux monstres vivants et on les range autour de la position du groupe (devant et derrière)
	var mons: Array = (combat.level.get("monsters", []) as Array).filter(func(x): return combat.lstate().monsters.get(str(x.id), {}).get("alive", false))
	var pos: Vector2i = combat.pos
	var d: int = combat.dir
	var fwd: Vector2i = DungeonGrid.DIRS[d]
	var a: Dictionary = mons[0]
	var b: Dictionary = mons[1]
	var sa: Dictionary = combat.lstate().monsters[str(a.id)]
	var sb: Dictionary = combat.lstate().monsters[str(b.id)]
	sa.x = pos.x + fwd.x
	sa.y = pos.y + fwd.y
	sb.x = pos.x - fwd.x
	sb.y = pos.y - fwd.y
	sa.hidden = false
	sb.hidden = false
	sa.hp = 1
	ctrl.refresh()
	for i in 200:
		if not ctrl.model_in_combat():
			break
		if not sa.alive and ctrl.rig.dir != d:
			break
		if ctrl.in_combat() and not ctrl._busy:
			ctrl.attack()
		await create_timer(0.3).timeout
	print("premier mort : ", not sa.alive, " | second vivant : ", sb.alive)
	if sb.alive:
		print("regard : ", ctrl.rig.dir, " attendu : ", (d + 2) % 4)
		if ctrl.rig.dir != (d + 2) % 4:
			fails += 1
		var front: Dictionary = combat.front_monster()
		if front.is_empty():
			fails += 1
			print("  ÉCHEC : plus personne en face")
	else:
		fails += 1
		print("  ÉCHEC : le second est déjà mort/non engagé")
	print("RÉSULTAT : ", fails, " échec(s)")
	quit()
