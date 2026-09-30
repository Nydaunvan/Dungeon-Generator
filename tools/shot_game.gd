extends SceneTree
## Captures du jeu en situation. Usage :
## godot --path . --rendering-driver opengl3 --script res://tools/shot_game.gd -- out=/tmp/x size=1280x800 steps=play,combat,dock
## Chaque étape enregistre <out>_<étape>.png
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var sz := str(args.get("size", "1280x800")).split("x")
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	var out := str(args.get("out", "/tmp/g"))
	for step in str(args.get("steps", "play")).split(","):
		match step:
			"combat", "group":
				# place le groupe devant un monstre (un groupe pour "group"), errants figés
				main.wand.paused_if = func(): return true
				var g: DungeonGrid = main.grid
				var found := false
				var lst: Dictionary = main.ctrl.combat.lstate().monsters
				for m in main.level.monsters:
					var st: Dictionary = lst.get(str(m.id), {})
					if st.is_empty() or not st.alive or (step == "group" and not m.get("isGroup", false)):
						continue
					for d in 4:
						var v: Vector2i = DungeonGrid.DIRS[d]
						var from := Vector2i(int(st.x), int(st.y)) - v
						if g.is_walkable(from.x, from.y):
							main.rig.place(g, from.x, from.y, d)
							found = true
							break
					if found:
						break
				if args.has("potions"):
					for i in 3:
						main.gs.inventory.append({"type": "potion", "name": "Potion de soin", "icon": "@icon:spr_12", "heal": 30})
					main.gs.inventory.append({"type": "potion", "name": "Élixir", "icon": "@icon:spr_13", "staminaRestore": 40})
				main.ctrl.refresh()
				await create_timer(2.5).timeout
			"fx":
				for sid in ["spell_fire1", "spell_arc1", "spell_holy1"]:
					main._on_fx3d(sid)
					await create_timer(0.42).timeout
					root.get_texture().get_image().save_png(out + "_fx_" + sid + ".png")
					await create_timer(0.8).timeout
			"sheet", "sheet2":
				main.inter.open_sheet(str(main.gs.party[3].id))
				await create_timer(0.6).timeout
				if step == "sheet2":
					for b in root.find_children("*", "Button", true, false):
						if (b as Button).text.contains("Sorts"):
							(b as Button).pressed.emit()
							break
					await create_timer(0.4).timeout
			"trap":
				main.wand.paused_if = func(): return true
				var done := false
				for it in main.level.items:
					if str(it.get("type", "")) != "trap" or done:
						continue
					for d in 4:
						var v: Vector2i = DungeonGrid.DIRS[d]
						var from := Vector2i(int(it.x), int(it.y)) - v
						if main.grid.is_walkable(from.x, from.y) and main.grid.is_walkable(from.x, from.y):
							main.rig.place(main.grid, from.x, from.y, d)
							done = true
							print("trap kind ", it.get("trapKind"))
							break
				await create_timer(1.0).timeout
			"dock":
				main.dock.open_for(str(main.gs.party[0].id))
				await create_timer(1.0).timeout
			"closedock":
				main.dock.close()
				await create_timer(0.5).timeout
		await _snap(out + "_" + step + ".png")
	quit()

func _snap(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(path)
