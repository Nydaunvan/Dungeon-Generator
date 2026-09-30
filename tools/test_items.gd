extends SceneTree
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var dups := 0
	var total := 0
	for seed in range(1, 13):
		var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 4, 15, 13, "normal", [], seed)
		for lvl in cfg.levels:
			var seen := {}
			for it in lvl.items:
				total += 1
				var k := "%d,%d" % [it.x, it.y]
				if seen.has(k):
					dups += 1
					print("seed %d lvl %s dup at %s: %s(%s) + %s(%s)" % [seed, lvl.id, k, seen[k].name, seen[k].type, it.name, it.type])
				else:
					seen[k] = it
			for m in lvl.monsters:
				var k2 := "%d,%d" % [m.x, m.y]
				if seen.has(k2):
					print("seed %d lvl %s item/monster on %s: %s" % [seed, lvl.id, k2, seen[k2].name])
	print("items ", total, " dups ", dups)
	quit()
