class_name Dialogs
extends RefCounted
## Fenêtres usuelles : confirmation, avis, guide, victoire, défaite.

static func notice(host: Node, title: String, text: String) -> Modal:
	var m := Modal.open(host, title, 420.0)
	m.add_text(text, UiTheme.PARCH, 15)
	m.set_buttons([{"text": L.t("common.ok"), "cb": func(): m.close()}])
	return m

static func _then(m: Modal, cb: Callable) -> Callable:
	return func():
		m.close()
		if cb.is_valid():
			cb.call()

static func confirm(host: Node, title: String, text: String, on_yes: Callable, yes_text: String = "", no_text: String = "") -> Modal:
	if yes_text == "":
		yes_text = L.t("common.confirmer")
	if no_text == "":
		no_text = L.t("common.annuler")
	var m := Modal.open(host, title, 460.0)
	m.add_text(text, UiTheme.PARCH, 15)
	m.set_buttons([{"text": yes_text, "cb": _then(m, on_yes)}, {"text": no_text, "cb": _then(m, Callable())}])
	return m

## Confirmation qui est une DÉCISION du journal (flux `flow`) : 1 = oui, 0 = non (Échap comprise).
static func confirm_flow(host: Node, flow: String, title: String, text: String, on_yes: Callable, yes_text: String = "", no_text: String = "") -> Modal:
	var m := Modal.open(host, title, 460.0)
	m.add_text(text, UiTheme.PARCH, 15)
	m.set_buttons([{"text": yes_text, "cb": func(): Flows.choose(flow, 1)}, {"text": no_text, "cb": func(): Flows.choose(flow, 0)}])
	var handler := func(c: Variant):
		if int(c) == 1 and on_yes.is_valid():
			on_yes.call()
	Flows.open(flow, m, handler, 0)
	return m

static func guide(host: Node) -> Modal:
	return DocModal.guide(host)

static func _stats_lines(m: Modal, gs: GameState) -> void:
	var st := gs.stats
	m.add_text("Monstres vaincus : %d   ·   Boss : %d" % [int(st.get("monstersKilled", 0)), int(st.get("bossesKilled", 0))], UiTheme.DIM, 14)
	m.add_text(L.fa(L.t("ui.dialogs.or_gagne_xp_gagnee_objets"), [int(st.get("goldEarnedTotal", 0)), int(st.get("xpEarnedTotal", 0)), int(st.get("itemsFound", 0))]), UiTheme.DIM, 14)
	for c in gs.party:
		m.add_text(L.fa(L.t("ui.dialogs.niveau"), [c.name, int(c.level), L.t("ui.dialogs.tombe") if int(c.hp) <= 0 else ""]), UiTheme.PARCH, 14)

static func victory(host: Node, gs: GameState, on_restart: Callable, on_home: Callable, on_next: Callable = Callable(), on_village: Callable = Callable()) -> Modal:
	var m := Modal.open(host, L.t("common.victoire"), 480.0)
	m.esc_closes = false
	var maxed := true
	for c in gs.party:
		if int(c.level) < Characters.MAX_LEVEL:
			maxed = false
	m.add_text(L.fa(L.t("ui.dialogs.le_groupe_emerge_de_triomphant"), [str(gs.cfg.get("title", "")), L.fa(L.t("ui.dialogs.vos_heros_ont_atteint_le"), Characters.MAX_LEVEL) if maxed else ""]), UiTheme.PARCH, 16, true)
	_stats_lines(m, gs)
	var btns: Array = []
	if on_village.is_valid():
		btns.append({"text": L.t("ui.dialogs.aller_au_village"), "cb": func(): Flows.choose("victoire", "village")})
	if on_next.is_valid():
		btns.append({"text": L.t("ui.dialogs.continuer_dans_un_donjon_plus"), "primary": true, "cb": func(): Flows.choose("victoire", "next")})
	btns.append({"text": L.t("ui.dialogs.repartir_de_zero"), "cb": _then(m, on_restart)})
	btns.append({"text": L.t("ui.dialogs.retour_a_l_accueil"), "cb": _then(m, on_home)})
	m.set_buttons(btns)
	if on_village.is_valid() or on_next.is_valid():
		# « repartir de zéro » / accueil ferment la fenêtre sans décision : la partie classée est déjà soumise à ce stade
		Flows.open("victoire", m, func(c: Variant):
			if str(c) == "village" and on_village.is_valid():
				on_village.call()
			elif str(c) == "next" and on_next.is_valid():
				on_next.call())
	return m

static func defeat(host: Node, gs: GameState, on_restart: Callable, on_home: Callable) -> Modal:
	var m := Modal.open(host, L.t("ui.dialogs.le_groupe_est_tombe"), 480.0)
	m.esc_closes = false
	m.add_text(L.t("ui.dialogs.les_tenebres_ont_eu_raison"), UiTheme.PARCH, 16, true)
	_stats_lines(m, gs)
	var specs: Array = [{"text": L.t("ui.dialogs.nouvelle_partie"), "primary": true, "cb": _then(m, on_restart)}, {"text": L.t("ui.dialogs.retour_a_l_accueil"), "cb": _then(m, on_home)}]
	for i in Saves.SLOTS:
		if not Saves.summary(i).is_empty():
			specs.push_front({"text": L.t("ui.dialogs.charger_une_sauvegarde"), "primary": false, "cb": func(): SlotsModal.open(host, Callable(), Data.launch_save)})
			break
	m.set_buttons(specs)
	return m
