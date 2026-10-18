extends Node
## Un monstre ne franchit pas un piège actif (même dans sa zone de patrouille) : test de Wanderers._free sur une case piégée.
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	var w = main.wand
	var g: DungeonGrid = main.grid
	var cell := Vector2i(-1, -1)
	for y in 40:
		for x in 40:
			if g.is_walkable(x, y) and Vector2i(x, y) != Vector2i(main.rig.gx, main.rig.gy):
				cell = Vector2i(x, y)
				break
		if cell.x >= 0:
			break
	var ok := true
	ok = ok and w._free(cell, "") == true
	var trap := {"id": "t_test", "type": "trap", "x": cell.x, "y": cell.y}
	w.level.items.append(trap)
	var blocked: bool = w._free(cell, "") == false
	main.gs.item_state(str(w.level.id), "t_test")["disarmed"] = true
	var freed: bool = w._free(cell, "") == true
	print("RESULTAT piège monstre : libre=%s bloqué par piège actif=%s libre après désamorçage=%s -> %s" % [ok, blocked, freed, "OK" if ok and blocked and freed else "ECHEC"])
	get_tree().quit()
