class_name Dialogs
extends RefCounted
## Fenêtres usuelles : confirmation, avis, guide, victoire, défaite.

static func notice(host: Node, title: String, text: String) -> Modal:
	var m := Modal.open(host, title, 420.0)
	m.add_text(text, UiTheme.PARCH, 15)
	m.set_buttons([{"text": "Fermer", "cb": func(): m.close()}])
	return m

static func _then(m: Modal, cb: Callable) -> Callable:
	return func():
		m.close()
		if cb.is_valid():
			cb.call()

static func confirm(host: Node, title: String, text: String, on_yes: Callable, yes_text: String = "Confirmer", no_text: String = "Annuler") -> Modal:
	var m := Modal.open(host, title, 460.0)
	m.add_text(text, UiTheme.PARCH, 15)
	m.set_buttons([{"text": yes_text, "cb": _then(m, on_yes)}, {"text": no_text, "cb": _then(m, Callable())}])
	return m

static func guide(host: Node) -> Modal:
	return DocModal.guide(host)

static func _stats_lines(m: Modal, gs: GameState) -> void:
	var st := gs.stats
	m.add_text("Monstres vaincus : %d   ·   Boss : %d" % [int(st.get("monstersKilled", 0)), int(st.get("bossesKilled", 0))], UiTheme.DIM, 14)
	m.add_text("Or gagné : %d   ·   XP gagnée : %d   ·   Objets trouvés : %d" % [int(st.get("goldEarnedTotal", 0)), int(st.get("xpEarnedTotal", 0)), int(st.get("itemsFound", 0))], UiTheme.DIM, 14)
	for c in gs.party:
		m.add_text("%s — niveau %d%s" % [c.name, int(c.level), "  (tombé)" if int(c.hp) <= 0 else ""], UiTheme.PARCH, 14)

static func victory(host: Node, gs: GameState, on_restart: Callable, on_home: Callable, on_next: Callable = Callable(), on_village: Callable = Callable()) -> Modal:
	var m := Modal.open(host, "Victoire !", 480.0)
	m.esc_closes = false
	var maxed := true
	for c in gs.party:
		if int(c.level) < Characters.MAX_LEVEL:
			maxed = false
	m.add_text("Le groupe émerge de %s, triomphant.%s" % [str(gs.cfg.get("title", "")), (" Vos héros ont atteint le sommet de leur puissance (niveau %d)." % Characters.MAX_LEVEL) if maxed else ""], UiTheme.PARCH, 16, true)
	_stats_lines(m, gs)
	var btns: Array = []
	if on_village.is_valid():
		btns.append({"text": "🏘️ Aller au village", "cb": _then(m, on_village)})
	if on_next.is_valid():
		btns.append({"text": "⚔️ Continuer dans un donjon plus difficile", "primary": true, "cb": _then(m, on_next)})
	btns.append({"text": "🔄 Repartir de zéro", "cb": _then(m, on_restart)})
	btns.append({"text": "🏠 Retour à l'accueil", "cb": _then(m, on_home)})
	m.set_buttons(btns)
	return m

static func defeat(host: Node, gs: GameState, on_restart: Callable, on_home: Callable) -> Modal:
	var m := Modal.open(host, "Le groupe est tombé...", 480.0)
	m.esc_closes = false
	m.add_text("Les ténèbres ont eu raison de vos héros. Une nouvelle troupe devra tenter sa chance.", UiTheme.PARCH, 16, true)
	_stats_lines(m, gs)
	var specs: Array = [{"text": "🔄 Nouvelle partie", "primary": true, "cb": _then(m, on_restart)}, {"text": "🏠 Retour à l'accueil", "cb": _then(m, on_home)}]
	for i in Saves.SLOTS:
		if not Saves.summary(i).is_empty():
			specs.push_front({"text": "📂 Charger une sauvegarde", "primary": false, "cb": func(): SlotsModal.open(host, Callable(), Data.launch_save)})
			break
	m.set_buttons(specs)
	return m
