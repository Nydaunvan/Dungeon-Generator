extends Control
## Capture du carnet (panneau « Journal ») et mesure de son rectangle : godot --path . res://tools/shot_carnet.tscn -- w=1920 h=1080 out=/chemin/nom [lines=court|long|vide|combat]
## Écrit <out>.png (écran entier), <out>_carnet.png (recadrage) et <out>.txt (rectangle global du panneau). Outil de contrôle, jamais chargé par le jeu.
func _ready() -> void:
	var a := {"w": "1920", "h": "1080", "out": "/tmp/carnet", "lines": "combat"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	get_window().size = Vector2i(int(a.w), int(a.h))
	await get_tree().process_frame
	var m: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
	await get_tree().create_timer(2.0).timeout
	var lay: GameLayout = m.layout
	var gs: GameState = m.gs
	if a.lines != "vide":
		gs.log_lines.clear()
		lay.log_panel.text.clear()      # le texte de départ de la partie est retiré pour que la capture ne montre que les lignes d'essai
		lay.log_panel._shown = 0
		lay.log_panel._target = 0
		lay.log_panel.text.visible_characters = -1
	match a.lines:
		"vide":
			pass
		"court":
			gs.add_log("Vous entrez dans la salle.")
		"long":
			for i in 60:
				gs.add_log("Événement n°%d : le groupe avance prudemment dans le couloir et note un détail." % i)
		_:
			gs.add_log("Épine venimeuse sur Crache-Os pour 13 dégâts.", true)
			gs.add_log("Crache-Os s'effondre, vaincu !")
			gs.add_log("XP répartie selon la contribution au combat : Ulric +6, Joren +6.")
			gs.add_log("Le groupe récupère 5 pièces d'or.")
	await get_tree().create_timer(float(a.get("wait", "4.0"))).timeout
	var r: Rect2 = lay.panel_log.get_global_rect()
	var f := FileAccess.open("%s.txt" % a.out, FileAccess.WRITE)
	f.store_line("fenetre %s" % str(get_viewport().get_visible_rect().size))
	f.store_line("carnet %s %s" % [str(r.position), str(r.size)])
	f.store_line("parchemin_texte %s" % str(Rect2(lay.log_panel.global_position + lay.log_panel.text.position, lay.log_panel.text.size)))
	f.close()
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s.png" % a.out)
	var sc := float(img.get_width()) / get_viewport().get_visible_rect().size.x      # capture en pixels, rectangle en unités d'interface
	var rr := Rect2i(Vector2i(r.position * sc), Vector2i(r.size * sc)).grow(int(6.0 * sc)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(rr).save_png("%s_carnet.png" % a.out)
	print("CARNET ", r)
	get_tree().quit()
