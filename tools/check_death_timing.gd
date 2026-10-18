extends Node
## L'animation de mort d'un monstre part à la FIN de l'effet de sort (pas à l'impact ni pendant le fondu).
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(2.5).timeout
	main.wand.paused_if = func(): return true
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
	await get_tree().create_timer(1.0).timeout
	var caster := str(main.gs.party[3].id)
	var spell := str(OS.get_environment("SPELL")) if OS.get_environment("SPELL") != "" else "spell_fire1"
	main.gs.party[3]["stamina"] = 100
	var ks: Array = main.gs.party[3].get("spellsKnown", [])
	if not ks.has(spell): ks.append(spell)
	main.gs.party[3]["spellsKnown"] = ks
	print("sort ", spell, " par ", caster)
	main.gs.active_char_id = caster
	var died := {"t": -1}
	main.ctrl.monster_death_started.connect(func(_i): died.t = Time.get_ticks_msec())
	var t0 := Time.get_ticks_msec()
	for i in 40:
		while main.ctrl._busy:
			await get_tree().process_frame
		if main.gs.active_char_id == caster and not main.ctrl.in_combat() == false:
			t0 = Time.get_ticks_msec()
			main.ctrl.cast(spell)
			if main.ctrl._busy or SpellFx3D.busy():
				break
		main.ctrl.skip_active_turn("%s passe")
		await get_tree().create_timer(0.3).timeout
	var idle_t := -1
	var seen_busy := false
	while Time.get_ticks_msec() - t0 < 14000 and (died.t < 0 or idle_t < 0):
		await get_tree().process_frame
		if SpellFx3D.busy(): seen_busy = true
		elif seen_busy and idle_t < 0: idle_t = Time.get_ticks_msec()
	var busy_at_death: bool = died.t < idle_t - 80 and idle_t > 0   # mort avant la fin de l effet
	print("fin effet t=%d ms ; mort t=%d ms" % [idle_t - t0, died.t - t0])
	print("RESULTAT mort : t=%d ms, effet encore actif=%s, effet vu=%s -> %s" % [died.t - t0, busy_at_death, seen_busy, "OK" if died.t > 0 and not busy_at_death else "ECHEC"])
	get_tree().quit()
