extends Control
## Vérifie la mise en page mobile : aucun contrôle visible ne dépasse la largeur de l'écran (accueil, partie, fenêtres),
## la carte quitte l'écran de jeu et le bouton 🗺 la remplace.
## Usage : godot --headless --path . res://tools/check_mobile.tscn

var bad := 0

func fail(msg: String) -> void:
	bad += 1
	print("ÉCART : ", msg)

func _over(n: Node, w: float, tag: String) -> void:
	if n is Control and (n as Control).is_visible_in_tree():
		var c := n as Control
		var r := c.get_global_rect()
		if r.end.x > w + 1.5 and r.size.x > 4.0 and c.get_class() != "SubViewportContainer":
			fail("%s : %s (%s) dépasse à droite (%.0f > %.0f)" % [tag, c.name, c.get_class(), r.end.x, w])
	for ch in n.get_children():
		_over(ch, w, tag)

func _ready() -> void:
	for sz in [Vector2i(390, 844), Vector2i(360, 640)]:
		get_window().size = sz
		await get_tree().process_frame
		for scene in ["home", "main"]:
			var s: Node = load("res://scenes/%s.tscn" % scene).instantiate()
			get_tree().root.add_child(s)
			get_tree().current_scene = s
			await get_tree().create_timer(1.5).timeout
			var w := get_viewport().get_visible_rect().size.x
			_over(s, w, "%s %dx%d" % [scene, sz.x, sz.y])
			if scene == "main":
				var lay: GameLayout = s.layout
				# la largeur minimale de l'interface ne doit jamais suivre sa largeur actuelle (sinon elle reste « bloquée » trop large)
				if lay.spell_bar.get_combined_minimum_size().x > lay.size.x * 0.85:
					fail("barre de sorts : largeur minimale %.0f trop proche de la largeur affichée %.0f" % [lay.spell_bar.get_combined_minimum_size().x, lay.size.x])
				if lay.panel_map.is_visible_in_tree():
					fail("mobile : la carte doit être masquée")
				if not lay.map_btn.is_visible_in_tree():
					fail("mobile : le bouton carte doit être visible")
				lay.menu_pressed.emit("Carte")
				await get_tree().create_timer(0.5).timeout
				if get_tree().get_nodes_in_group("modal").is_empty():
					fail("le bouton carte n'ouvre pas la carte")
				_over(s, w, "carte")
				lay.menu_pressed.emit("Carte")
				await get_tree().create_timer(0.5).timeout
			s.queue_free()
			await get_tree().process_frame
	print("MOBILE OK" if bad == 0 else "MOBILE %d écart(s)" % bad)
	get_tree().quit(1 if bad else 0)
