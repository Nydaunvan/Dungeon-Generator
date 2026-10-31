extends SceneTree
## Chronologie de la mort du dernier monstre d'un combat, avec un monstre Atlas Noir :
##   coup -> la barre de vie se vide -> pose de mort -> disparition -> (seulement ensuite) fin du combat et écran de victoire.
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --script res://tools/check_death_sequence.gd -- icon=mon_moine_decharne [mode=attack|spell]
## Affiche chaque événement avec son instant (ms après le coup) et « RESULTAT mort : OK » si l'ordre et les délais sont respectés.
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(960, 540)
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
	for mm in main.level.monsters:
		mm["icon"] = "@icon:" + str(args.get("icon", "mon_moine_decharne"))
		if str(mm["icon"]).begins_with("@icon:boss_"):
			mm["isBoss"] = true            # boss Atlas Noir : on garde (ou pose) le drapeau boss
		else:
			mm.erase("isBoss")
	main.load_level(main.level_index)
	await create_timer(1.5).timeout
	var g: DungeonGrid = main.grid
	var lst: Dictionary = main.ctrl.combat.lstate().monsters
	var target := ""
	for m in main.level.monsters:
		var st0: Dictionary = lst.get(str(m.id), {})
		if st0.is_empty() or not st0.alive or m.get("isGroup", false):
			continue
		for d in 4:
			var v: Vector2i = DungeonGrid.DIRS[d]
			var from := Vector2i(int(st0.x), int(st0.y)) - v
			if g.is_walkable(from.x, from.y):
				main.rig.place(g, from.x, from.y, d)
				st0["hp"] = 1.0
				st0["atkMin"] = 0.0
				st0["atkMax"] = 0.0
				target = str(m.id)
				break
		if target != "":
			break
	main.ctrl.refresh()
	await create_timer(3.0).timeout
	var stage = main.level_node.stage
	print("monstre ", target, " ; salle de combat active=", stage.active)
	var ev := {}
	var t0 := Time.get_ticks_msec()
	var log := func(what: String):
		print("  t=%5d ms  %s" % [Time.get_ticks_msec() - t0, what])
	main.ctrl.monster_death_started.connect(func(_i): ev["mort demandée"] = Time.get_ticks_msec() - t0; log.call("mort demandée (événement monster_died)"))
	main.ctrl.combat_won.connect(func(_s): ev["victoire"] = Time.get_ticks_msec() - t0; log.call("ÉCRAN DE VICTOIRE demandé"))
	var hero := ""
	for i in 60:
		while main.ctrl._busy:
			await process_frame
		hero = str(main.gs.active_char_id)
		if hero != "" and not main.ctrl.in_combat() == false:
			break
		await create_timer(0.1).timeout
	t0 = Time.get_ticks_msec()
	print("héros actif : ", hero, " ; combat=", main.ctrl.in_combat())
	if str(args.get("mode", "attack")) == "spell":
		var spell := "spell_fire1"
		for c in main.gs.party:
			if str(c.id) == hero:
				c["stamina"] = 100
				var ks: Array = c.get("spellsKnown", [])
				if not ks.has(spell): ks.append(spell)
				c["spellsKnown"] = ks
		main.ctrl.cast(spell)
	else:
		main.ctrl.attack()
	log.call("coup du héros lancé")
	var ents = main.level_node.entities
	var dead_mat = ents._pose_mat(str(stage.mon_id) if false else "", "dead")
	var st := {"bar": "", "pose": "", "alpha": -1.0, "active": stage.active, "n": -1, "modal": 0, "inc": true}
	var first := {}
	while Time.get_ticks_msec() - t0 < 25000 and not (ev.has("victoire") and Time.get_ticks_msec() - t0 > int(ev["victoire"]) + 1500):
		await process_frame
		var bars := 0
		var frac := -1.0
		for c in stage.get_children():
			if c is MeshInstance3D and str(c.name).begins_with("HpBar"):
				bars += 1
				frac = float((c.material_override as ShaderMaterial).get_shader_parameter("frac"))
		var bar_s := "absente" if bars == 0 else ("pleine" if frac > 0.95 else ("vide" if frac < 0.02 else "se vide %.2f" % frac))
		var pose := "aucun sprite"
		var alpha := -1.0
		for c in stage.get_children():
			if c is MeshInstance3D and c.has_meta("atlas") and is_instance_valid(c):
				var mt = c.material_override
				var did = ents._pose_mat(str(c.get_meta("pose_id", "")), "dead")
				pose = "pose de mort" if (did != null and mt.albedo_texture == did.albedo_texture) else "pose debout"
				alpha = float(mt.albedo_color.a)
		if bar_s.begins_with("se vide") : bar_s = "se vide"
		if bar_s != st.bar: st.bar = bar_s; log.call("barre de vie : " + bar_s)
		var ps := pose + (" (s'estompe)" if alpha >= 0.0 and alpha < 0.98 else "")
		if ps != st.pose: st.pose = ps; log.call("sprite : " + ps)
		if stage.active != st.active: st.active = stage.active; log.call("salle de combat active = " + str(stage.active))
		var inc: bool = main.ctrl.model_in_combat()
		if st.get("inc", true) != inc: st["inc"] = inc; log.call("combat dans le modèle = " + str(inc))
	log.call("fin de l'observation")
	var mort: int = int(ev.get("mort demandée", -1))
	var vic: int = int(ev.get("victoire", -1))
	print("RESULTAT mort : mort demandée t=%d ms, victoire t=%d ms (écart %d ms, attendu %d ms)" % [mort, vic, vic - mort, int(ents.death_seconds(target) * 1000.0)])
	quit()
