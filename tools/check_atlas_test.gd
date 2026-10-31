extends Node
## Vérifie que le test « Atlas Noir » n'engendre que des monstres Atlas Noir : godot --headless --path . res://tools/check_atlas_test.tscn
func _ready() -> void:
	await get_tree().process_frame
	var pool := DungeonGenerator.atlas_pool().map(func(e): return str(e[1]))
	print("MODAL ", load("res://scripts/ui/super_admin_modal.gd") != null)
	print("pool Atlas Noir : ", pool)
	DungeonGenerator.atlas_only = true
	var cfg: Dictionary = DungeonGenerator.build_config(Data.config, 4, 15, 13, "normal", [])
	DungeonGenerator.atlas_only = false
	var seen := {}
	var bad := 0
	var n := 0
	for lv in cfg.levels:
		for m in lv.monsters:
			var id := str(m.icon).replace("@icon:", "")
			if m.get("isBoss", false):
				continue
			n += 1
			seen[id] = true
			if not pool.has(id):
				bad += 1
	print("monstres : ", n, " ; hors Atlas Noir : ", bad, " ; présents : ", seen.keys())
	print("ATLAS_TEST ", "OK" if bad == 0 and n > 0 else "ECHEC")
	get_tree().quit(0 if bad == 0 and n > 0 else 1)
