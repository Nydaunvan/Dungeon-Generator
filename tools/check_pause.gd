extends SceneTree
## Pause de test : le jeu se fige, puis REPART à chaque fois (clic, P, Échap, Espace, bouton), le temps de jeu avance, le joueur peut bouger.
## Lancer (Xvfb requis) : xvfb-run -a godot --path . --script res://tools/check_pause.gd
var fails := 0
var PO: GDScript
func check(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
		print("ÉCHEC : ", label)

func key(code: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = p
		Input.parse_input_event(e)

func click() -> void:
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = root.get_visible_rect().size / 2.0
		e.global_position = e.position
		e.pressed = p
		Input.parse_input_event(e)

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	PO = load("res://scripts/ui/pause_overlay.gd")
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(8.0).timeout
	var m = current_scene
	var gs = m.gs
	check("partie chargée", gs != null)
	m._on_command("turn_left")
	await create_timer(1.0).timeout
	var ways := ["bouton", "clic", "P", "Échap", "Espace", "bouton"]
	for i in ways.size():
		var way: String = ways[i]
		PO.toggle(self)
		await process_frame
		check("[%s] jeu figé" % way, paused and PO.active())
		var t0 := float(gs.stats.get("playSeconds", 0.0))
		await create_timer(1.0).timeout
		check("[%s] temps de jeu figé" % way, absf(float(gs.stats.get("playSeconds", 0.0)) - t0) < 0.05)
		match way:
			"bouton": PO.toggle(self)
			"clic": click()
			"P": key(KEY_P)
			"Échap": key(KEY_ESCAPE)
			"Espace": key(KEY_SPACE)
		for k in 4: await process_frame
		check("[%s] jeu repris" % way, not paused and not PO.active())
		var t1 := float(gs.stats.get("playSeconds", 0.0))
		await create_timer(1.2).timeout
		check("[%s] temps de jeu repart (%.2f → %.2f)" % [way, t1, float(gs.stats.get("playSeconds", 0.0))], float(gs.stats.get("playSeconds", 0.0)) - t1 > 0.8)
		var rot0: float = m.rig.rotation_degrees.y
		m._on_command("turn_right")
		await create_timer(0.8).timeout
		check("[%s] le joueur répond aux commandes" % way, absf(m.rig.rotation_degrees.y - rot0) > 1.0 or m.ctrl.in_combat())      # un monstre peut engager le combat : les déplacements sont alors refusés
	# la pause ne fige pas à jamais si la scène est libérée en pleine pause
	PO.toggle(self)
	await process_frame
	PO._inst.queue_free()
	for k in 3: await process_frame
	check("overlay libéré : l'arbre n'est plus en pause", not paused)
	print("check_pause : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
