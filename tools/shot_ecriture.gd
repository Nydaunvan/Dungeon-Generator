extends Control
## Séquence d'images de l'écriture à l'encre du carnet : godot --path . res://tools/shot_ecriture.tscn -- w=1920 h=1080 out=/chemin/dossier
## Ajoute quatre événements puis enregistre le carnet à plusieurs instants (<out>/ecriture_N.png) et note le nombre de caractères visibles (<out>/ecriture.txt).
## Outil de contrôle, jamais chargé par le jeu.
func _ready() -> void:
	var a := {"w": "1920", "h": "1080", "out": "/tmp/ecriture"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	DirAccess.make_dir_recursive_absolute(a.out)
	get_window().size = Vector2i(int(a.w), int(a.h))
	await get_tree().process_frame
	var m: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await get_tree().create_timer(2.0).timeout
	var lay: GameLayout = m.layout
	var gs: GameState = m.gs
	var lp: LogPanel = lay.log_panel
	gs.log_lines.clear()
	lp.text.clear()
	lp._shown = 0
	lp._target = 0
	lp.text.visible_characters = -1
	await get_tree().process_frame
	var f := FileAccess.open("%s/ecriture.txt" % a.out, FileAccess.WRITE)
	gs.add_log("Épine venimeuse sur Crache-Os pour 13 dégâts.", true)
	gs.add_log("Crache-Os s'effondre, vaincu !")
	gs.add_log("XP répartie selon la contribution au combat : Ulric +6, Joren +6.")
	gs.add_log("Le groupe récupère 5 pièces d'or.")
	var t0 := Time.get_ticks_msec()
	for i in 6:
		await get_tree().create_timer([0.15, 0.5, 0.5, 0.6, 0.8, 1.5][i]).timeout
		var r: Rect2 = lay.panel_log.get_global_rect()
		var img := get_viewport().get_texture().get_image()
		var sc := float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var rr := Rect2i(Vector2i(r.position * sc), Vector2i(r.size * sc)).grow(int(6.0 * sc)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(rr).save_png("%s/ecriture_%d.png" % [a.out, i])
		f.store_line("image %d : t=%d ms, caractères écrits %d / %d" % [i, Time.get_ticks_msec() - t0, lp._shown, lp._target])
	f.close()
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("%s/interface.png" % a.out)
	var r2: Rect2 = lay.panel_log.get_global_rect()
	print("ECRITURE ", r2)
	get_tree().quit()
