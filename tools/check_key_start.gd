extends SceneTree
## Vérifie qu'aucune clé de porte n'est générée sur la case de départ d'un niveau. Lancer : godot --headless --path . --script res://tools/check_key_start.gd
func _init() -> void:
	await process_frame
	var base: Dictionary = root.get_node("Data").original_config
	var gen = load("res://scripts/rules/dungeon_generator.gd")
	var bad := 0
	var keys := 0
	var doors := 0
	var total := 0
	for seed_i in 120:
		for diff in ["easy", "hardcore"]:
			var cfg: Dictionary = gen.build_config(base, 4, 13 if seed_i % 2 == 0 else 9, 11 if seed_i % 2 == 0 else 9, diff, [], 1, seed_i * 7919 + 13)
			for lv in cfg.levels:
				total += 1
				doors += (lv.doors as Array).size()
				for it in lv.items:
					if str(it.get("id", "")).begins_with("key_gen_"):
						keys += 1
						if int(it.x) == int(lv.startX) and int(it.y) == int(lv.startY):
							bad += 1
					if str(it.get("type", "")) == "key" and not bool(it.get("startHidden", false)) and int(it.x) == int(lv.startX) and int(it.y) == int(lv.startY):
						bad += 1
	print("niveaux ", total, " portes ", doors, " clés ", keys, " clés sur la case de départ : ", bad, " → ", "OK" if bad == 0 and keys > 0 else "ÉCHEC")
	quit()
