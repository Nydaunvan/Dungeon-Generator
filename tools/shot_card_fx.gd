extends Node
## Rendu réel (xvfb + opengl3) de plusieurs sorts lancés depuis la carte 1 : captures /tmp/claude-0/sp_NN_{a,b}.png. godot --path . --rendering-driver opengl3 res://tools/shot_card_fx.tscn
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var found := false
	for m in main.level.monsters:
		var stt: Dictionary = lst.get(str(m.id), {})
		if stt.is_empty() or not stt.alive:
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(stt.x), int(stt.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				found = true
				break
		if found:
			break
	main.ctrl.refresh()
	await get_tree().create_timer(2.5).timeout
	print("REAL placed=", found)
	var hud = main.layout.hud
	print("REAL party=", main.gs.party.size(), " centers=", hud.card_centers(), " bottoms=", hud.card_bottoms())
	print("REAL overlay size=", main.card_fx.size, " visible=", main.card_fx.visible, " view=", main.layout.sub_container.size, " vp=", main.layout.sub_viewport.size, " win=", get_window().size, " usable=", CardFxOverlay.usable())
	var st = main.level_node.stage if main.level_node != null else null
	print("REAL stage=", st != null, " active=", st != null and st.active)
	var ids := ["spell_nature1", "spell_arc1", "spell_fire1", "spell_frost1", "spell_warlock1", "spell_bard2", "spell_magearcher1", "spell_holy1", "spell_archer1", "spell_assassin1", "spell_nature3", "spell_elementalist1"]
	var sp_by := {}
	for sp in main.gs.cfg.get("spells", []):
		sp_by[str(sp.id)] = sp
	var k := 0
	for sid in ids:
		await get_tree().create_timer(1.8).timeout
		var c: Dictionary = SpellFxLibrary.ctx_for(sp_by[sid])
		c["caster"] = 0
		c["ally"] = 0
		c["solo"] = false
		main._on_fx3d(sid, c)
		await get_tree().create_timer(0.07).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sp_%02d_a.png" % k)
		await get_tree().create_timer(0.09).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/sp_%02d_b.png" % k)
		k += 1
	var ov: CardFxOverlay = main.card_fx
	print("REAL vp=", ov._vp.size, " svc=", ov._svc.size, " ovpos=", ov.global_position, " cam fov=", ov._cam.fov, " main fov=", main.rig.camera.fov)
	var want: Vector2 = hud.card_bottoms()[0] - ov.global_position
	var best := 1e9
	var lowest := Vector2.ZERO
	var stack: Array = [ov._world]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		for ch in nd.get_children():
			stack.append(ch)
		if nd is Node3D and not nd is Camera3D and nd != ov._world:
			var p3 := (nd as Node3D).global_position
			if not ov._cam.is_position_behind(p3):
				var q := ov._cam.unproject_position(p3)
				if q.distance_to(want) < best:
					best = q.distance_to(want)
					lowest = q
	print("REAL voulu=", want, " plus_proche=", lowest, " ecart=", best)
	get_tree().quit()
