extends Node
## Répartition des raretés de l'équipement au sol pour le défi solitaire (rare minimum) et en partie normale.
func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	for ids in [["mod_solo", "mod_legend"], []]:
		var cnt := {}
		for n in 40:
			var c: Dictionary = DungeonGenerator.build_config(Data.original_config, 2, 15, 15, "normal", ids, 1, 900 + n)
			for lv in c.levels:
				for it in lv.items:
					if ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
						cnt[Rarity.of(it)] = int(cnt.get(Rarity.of(it), 0)) + 1
		print("RARETES ", ids, " ", cnt)
	get_tree().quit()
