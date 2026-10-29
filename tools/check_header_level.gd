extends SceneTree
## Repère central de l'en-tête : numéro et nom suivent le niveau affiché (pas figés sur le niveau 1).
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/check_header_level.gd
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5)
	data.launch(cfg, "random")
	await create_timer(1.5).timeout
	var m = current_scene
	while m._loading:
		await create_timer(0.2).timeout
	var ok := true
	for i in cfg.levels.size():
		await m.load_level(i)
		await create_timer(0.2).timeout
		var crest = m.layout.header._crest
		var cur: int = m.level_index      # le joueur peut avoir pris un escalier à l'arrivée : on compare au niveau réellement affiché
		var want_num: String = L.fa(L.t("ui.atlas.level_n"), cur + 1)
		var want_name := str(cfg.levels[cur].name)
		var good: bool = crest.num_text == want_num and crest.name_text == want_name
		print("niveau %d : '%s' / '%s' (attendu '%s' / '%s') -> %s" % [i + 1, crest.num_text, crest.name_text, want_num, want_name, "OK" if good else "ECHEC"])
		ok = ok and good
	print("RESULTAT : ", "OK" if ok else "ECHEC")
	quit(0 if ok else 1)
