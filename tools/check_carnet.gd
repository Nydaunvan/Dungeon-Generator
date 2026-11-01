extends Control
## Carnet en parchemin : le rectangle du panneau ne change pas (valeurs mesurées AVANT la refonte, en unités d'interface), rien du parchemin
## (papier, ombre, coins, titre, texte, bouton) ne dépasse de ce rectangle, l'historique garde son ordre, la file d'écriture absorbe les rafales.
## godot --path . res://tools/check_carnet.tscn   (écran requis : xvfb-run -a -s "-screen 0 3840x2160x24" ... --rendering-method gl_compatibility)
var fails := 0
## fenêtre (px) -> rectangle du carnet avant la refonte : position, taille
const BEFORE := {Vector2i(1920, 1080): Rect2(1440, 402, 307, 240), Vector2i(2560, 1600): Rect2(1290, 390, 280, 240), Vector2i(3840, 2160): Rect2(1440, 402, 307, 240)}

func check(label: String, cond: bool) -> void:
	print(("ok     " if cond else "ÉCHEC  "), label)
	if not cond:
		fails += 1

func _inside(r: Rect2, outer: Rect2, tol: float = 0.51) -> bool:
	return r.position.x >= outer.position.x - tol and r.position.y >= outer.position.y - tol and r.end.x <= outer.end.x + tol and r.end.y <= outer.end.y + tol

func _ready() -> void:
	for sz in BEFORE:
		get_window().size = sz
		await get_tree().process_frame
		var m: Node = load("res://scenes/main.tscn").instantiate()
		get_tree().root.add_child(m)
		get_tree().current_scene = m
		await get_tree().create_timer(2.0).timeout
		var lay: GameLayout = m.layout
		var gs: GameState = m.gs
		var lp: LogPanel = lay.log_panel
		var tag := "%dx%d" % [sz.x, sz.y]
		var r := lay.panel_log.get_global_rect()
		var want: Rect2 = BEFORE[sz]
		check("%s : rectangle du carnet inchangé %s (avant %s)" % [tag, str(r), str(want)], r.position.distance_to(want.position) < 1.0 and r.size.distance_to(want.size) < 1.0)
		for state in ["vide", "court", "long", "combat"]:
			lp.text.clear()
			lp._shown = 0
			lp._target = 0
			lp.text.visible_characters = -1
			var n_before := 0
			match state:
				"court":
					gs.add_log("Vous entrez dans la salle.")
					n_before = 1
				"long":
					for i in 60:
						gs.add_log("Événement n°%d : le groupe avance prudemment dans le couloir." % i)
					n_before = 60
				"combat":
					gs.add_log("Épine venimeuse sur Crache-Os pour 13 dégâts.", true)
					gs.add_log("Crache-Os s'effondre, vaincu !")
					gs.add_log("XP répartie selon la contribution au combat : Ulric +6, Joren +6.")
					gs.add_log("Le groupe récupère 5 pièces d'or.")
					n_before = 4
			await get_tree().create_timer(0.5).timeout
			var rl := lay.panel_log.get_global_rect()
			check("%s %s : panneau toujours %s" % [tag, state, str(rl)], rl.position.distance_to(want.position) < 1.0 and rl.size.distance_to(want.size) < 1.0)
			var box := Rect2(Vector2.ZERO, lp.size)
			var bounds := Rect2(lp._poly[0], Vector2.ZERO)
			for p in lp._poly:
				bounds = bounds.expand(p)
			var off := Vector2(lp._m * 0.32, lp._m * 0.38)
			bounds = bounds.merge(Rect2(bounds.position + off, bounds.size))      # ombre portée
			check("%s %s : papier et ombre dans le rectangle" % [tag, state], _inside(bounds, box, 0.0))
			check("%s %s : texte dans le papier" % [tag, state], _inside(Rect2(lp.text.position, lp.text.size), Rect2(Vector2(lp._m, lp._m), lp.size - Vector2(lp._m, lp._m) * 2.0)))
			check("%s %s : bouton d'historique dans le rectangle" % [tag, state], not lp._hist.visible or _inside(Rect2(lp._hist.position, lp._hist.size), box))
			check("%s %s : titre dans la largeur (police %d)" % [tag, state, int(lp._title_h)], lp._title_h >= 8.0)
			check("%s %s : contenu rogné (carnet et parchemin)" % [tag, state], lay.panel_log.clip_contents and lp.clip_contents and lp.text.clip_contents)
			if state == "long":
				check("%s long : tout le texte reste dans le journal, dans l'ordre" % tag, lp.text.get_parsed_text().find("n°0 ") < lp.text.get_parsed_text().find("n°59 ") and lp.text.get_total_character_count() > 2000)
				check("%s long : la file a rattrapé son retard (ou accélère)" % tag, lp._shown >= lp._target - 1 or lp._target - lp._shown < LogPanel.BACKLOG_INSTANT)
			if state == "combat":
				await get_tree().create_timer(6.0).timeout
				check("%s combat : écriture terminée, tout visible" % tag, lp.text.visible_characters == -1 or lp._shown >= lp._target)
				var t := lp.text.get_parsed_text()
				check("%s combat : ordre chronologique conservé" % tag, t.find("Épine") < t.find("s'effondre") and t.find("s'effondre") < t.find("XP") and t.find("XP") < t.find("pièces"))
		# finition : zone du titre, marges, couloir du curseur
		check("%s titre : le texte commence sous le filet décoratif (filet %.1f, texte %.1f)" % [tag, lp._rule_y, lp.text.position.y], lp.text.position.y >= lp._rule_y + 4.0 and lp._title_y > lp._m + lp._title_h * 0.5)
		check("%s marges : gauche %.1f, droite %.1f, bas %.1f (papier à %.1f)" % [tag, lp.text.position.x, lp.size.x - (lp.text.position.x + lp.text.size.x), lp.size.y - lp.text.position.y - lp.text.size.y, lp._m], lp.text.position.x >= lp._m * 2.5 and lp.size.x - (lp.text.position.x + lp.text.size.x) >= lp._m * 2.5 and lp.size.y - lp.text.position.y - lp.text.size.y >= lp._m + 4.0)
		check("%s curseur : couloir dans la marge droite, hors du texte et dans le papier" % tag, lp._gutter.position.x >= (lp.text.position.x + lp.text.size.x) and lp._gutter.end.x <= lp.size.x - lp._m - 3.0 and lp._gutter.end.y <= lp.size.y - lp._m)
		check("%s curseur : la barre du RichTextLabel ne prend aucune largeur (%s)" % [tag, str(lp._vs.get_combined_minimum_size().x)], lp._vs.get_combined_minimum_size().x < 1.0)
		# dix événements successifs : écriture progressive, croissante, sans perte
		lp.text.clear()
		lp._shown = 0
		lp._target = 0
		for i in 10:
			gs.add_log("Événement %d : un court message du carnet." % i)
		var total := lp._target
		var samples: Array = []
		for i in 8:
			await get_tree().create_timer(0.05).timeout
			samples.append(lp._shown)
		var mono := true
		for i in range(1, samples.size()):
			mono = mono and samples[i] >= samples[i - 1]
		check("%s dix événements : écriture progressive %s sur %d caractères" % [tag, str(samples), total], mono and samples[0] < total and samples[-1] > samples[0])
		await get_tree().create_timer(6.0).timeout
		check("%s dix événements : tout est écrit, rien n'est perdu" % tag, lp.text.get_parsed_text().count("Événement") == 10 and lp._shown >= lp._target)
		# défilement manuel pendant l'arrivée d'un événement
		lp.text.clear()
		lp._shown = 0
		lp._target = 0
		for i in 60:
			gs.add_log("Ligne %d : le groupe avance prudemment dans le couloir et note un détail." % i)
		await get_tree().create_timer(1.5).timeout
		var vs := lp._vs
		var mx := vs.max_value - vs.page
		check("%s défilement : suivi automatique en bas (%.0f / %.0f)" % [tag, vs.value, mx], vs.value >= mx - 3.0)
		var wheel := InputEventMouseButton.new()      # le joueur remonte dans l'historique, avec la molette
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = lp.size * 0.5
		wheel.factor = 40.0
		lp._gui_input(wheel)
		await get_tree().create_timer(1.0).timeout
		var held := vs.value
		check("%s défilement : la molette a remonté dans l'historique (%.0f)" % [tag, held], held < mx - 100.0)
		gs.add_log("Nouvel événement pendant la lecture de l'historique.")
		await get_tree().create_timer(2.5).timeout
		check("%s défilement : le joueur n'est pas ramené en bas (%.0f, tenu à %.0f)" % [tag, vs.value, held], absf(vs.value - held) < 3.0)
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.factor = 400.0      # retour en bas
		lp._gui_input(wheel)
		await get_tree().create_timer(1.5).timeout
		gs.add_log("Retour en bas : le suivi reprend.")
		await get_tree().create_timer(2.5).timeout
		check("%s défilement : le suivi reprend en bas (%.0f / %.0f)" % [tag, vs.value, vs.max_value - vs.page], vs.value >= vs.max_value - vs.page - 3.0)
		# molette : défilement fluide (pas de saut), borné
		lp._follow = true
		lp._stick()
		await get_tree().process_frame
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = true
		ev.position = lp.size * 0.5
		var v0 := vs.value
		lp._gui_input(ev)
		await get_tree().process_frame
		var v1 := vs.value
		await get_tree().create_timer(1.0).timeout
		check("%s molette : défilement fluide vers le haut (%.1f -> %.1f -> %.1f)" % [tag, v0, v1, vs.value], v1 < v0 and vs.value < v1 - 1.0 and vs.value > 0.0)
		# chargement d'une sauvegarde : l'historique apparaît d'un coup, sans rejouer l'écriture
		var gs2 := GameState.new()
		for i in 40:
			gs2.log_lines.append("Entrée sauvegardée %d : le groupe se souvient de ce qui s'est passé." % i)
		var lp2 := LogPanel.new()
		lp2.size = lp.size
		add_child(lp2)
		lp2.setup(gs2)
		check("%s sauvegarde : historique affiché immédiatement, aucune animation" % tag, lp2.text.visible_characters == -1 and lp2._shown == lp2._target and lp2._target > 1000 and not lp2.is_processing())
		lp2.queue_free()
		# rafale : très en retard -> affichage immédiat ; sinon l'écriture accélère
		for i in 120:
			gs.add_log("Rafale %d : le monstre attaque, le groupe riposte avec vigueur et détermination." % i)
		await get_tree().process_frame
		check("%s rafale : l'écriture ne prend pas de retard sans fin" % tag, lp._target - lp._shown <= LogPanel.BACKLOG_INSTANT)
		m.queue_free()
		await get_tree().process_frame
	print("CARNET ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)
