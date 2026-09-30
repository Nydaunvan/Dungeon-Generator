extends SceneTree
# Traverse tous les escaliers « level » d'un donjon aléatoire (aller et retour) : arrivée toujours sur une case libre.
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(1.5).timeout
	var m = current_scene
	for round in 2:
		for i in cfg.levels.size():
			var lvl: Dictionary = cfg.levels[i]
			for st in lvl.stairs:
				var a: Dictionary = st.get("action", {})
				if str(a.get("type", "")) != "level":
					continue
				m.load_level(i)
				var tgt: Dictionary = {}
				var ti := -1
				for j in cfg.levels.size():
					if cfg.levels[j].id == a.targetId:
						tgt = cfg.levels[j]
						ti = j
				var arr: Dictionary = m._arrival(tgt, a)
				m.load_level(ti, false, arr)
				var ok: bool = m.grid.is_walkable(m.rig.gx, m.rig.gy)
				var vv: Vector2i = m.grid.DIRS[m.rig.dir]
				print("L%d -> L%d arrive (%d,%d) dir %d walkable=%s front=%s" % [i, ti, m.rig.gx, m.rig.gy, m.rig.dir, ok, m.grid.cell(m.rig.gx + vv.x, m.rig.gy + vv.y)])
	quit()
