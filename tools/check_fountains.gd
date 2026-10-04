extends SceneTree
## Vérifie que chaque fontaine générée dispose d'un mur où creuser son décroché.
func _init() -> void:
	await process_frame
	var cfg: Dictionary = root.get_node("Data").config
	var Gen = load("res://scripts/rules/dungeon_generator.gd")
	var Grid = load("res://scripts/dungeon/dungeon_grid.gd")
	var LB = load("res://scripts/dungeon/level_builder.gd")
	var total := 0
	var niche := 0
	for run in 8:
		var gen = Gen.new(cfg, "normal", 1, [])
		for lv in gen.levels(6, 21, 21):
			var g = Grid.new(lv)
			for it in lv.items:
				if str(it.type) == "fountain":
					total += 1
					if LB.fountain_niche_dir(g, int(it.x), int(it.y), str(it.id)) != Vector2i.ZERO:
						niche += 1
	print("fontaines : %d, avec décroché : %d" % [total, niche])
	quit()
