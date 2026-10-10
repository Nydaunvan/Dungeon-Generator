class_name GeneratorDialog
extends RefCounted
## Fenêtres du donjon aléatoire : réglages (niveaux, taille, difficulté) puis modificateurs d'expédition.

const BLURBS := {
	"easy": "ui.generator_dialog.une_aventure_paisible_ideale",
	"normal": "ui.generator_dialog.un_defi_equilibre_pour_une",
	"hard": "ui.generator_dialog.des_ennemis_nettement_plus_coriaces",
	"hardcore": "ui.generator_dialog.une_veritable_epreuve_les_ennemis",
}
const DIFFS := [["easy", "ui.generator_dialog.facile"], ["normal", "ui.generator_dialog.normale"], ["hard", "ui.generator_dialog.difficile"], ["hardcore", "Hardcore"]]

static func _row(m: Modal, label: String, field: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	h.add_child(field)
	m.content.add_child(h)

static func _spin(lo: int, hi: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = value
	s.custom_minimum_size = Vector2(110, 0)
	return s

## Ouvre la fenêtre de réglages ; `on_launch(cfg)` reçoit la configuration générée.
static func open(host: Node, on_launch: Callable) -> void:
	var m := Modal.open(host, L.t("ui.generator_dialog.generation_aleatoire"), 500.0)
	m.add_text(L.t("ui.generator_dialog.tout_est_genere_automatiquement"), UiTheme.DIM, 14, true)
	var levels := _spin(1, 8, 3)
	var width := _spin(7, 60, 13)
	var height := _spin(7, 60, 11)
	_row(m, L.t("ui.generator_dialog.nombre_de_niveaux_max_8"), levels)
	_row(m, L.t("ui.generator_dialog.largeur_par_niveau_max_60"), width)
	_row(m, L.t("ui.generator_dialog.hauteur_par_niveau_max_60"), height)
	var diff := OptionButton.new()
	for d in DIFFS:
		diff.add_item(str(d[1]))
	diff.select(1)
	diff.custom_minimum_size = Vector2(150, 0)
	_row(m, L.t("ui.generator_dialog.difficulte"), diff)
	var blurb := m.add_text(str(BLURBS["normal"]), UiTheme.DIM, 13, true)
	diff.item_selected.connect(func(i: int): blurb.text = str(BLURBS[DIFFS[i][0]]))
	var go := func():
		var params := {"levels": int(levels.value), "width": int(width.value), "height": int(height.value), "diff": str(DIFFS[diff.selected][0])}
		m.close()
		_pick_modifiers(host, params, on_launch)
	m.set_buttons([{"text": L.t("ui.generator_dialog.generer_et_jouer"), "cb": go}, {"text": L.t("common.annuler"), "cb": func(): m.close()}])

static func _pick_modifiers(host: Node, params: Dictionary, on_launch: Callable) -> void:
	pick_modifiers(host, func(mods: Array): _generate(host, params, mods, on_launch))

## Choix de 0 à 2 modificateurs d'expédition ; `on_chosen(mods)` reçoit les ids.
static func pick_modifiers(host: Node, on_chosen: Callable) -> void:
	var m := Modal.open(host, L.t("ui.generator_dialog.modificateurs_expedition"), 500.0)
	m.add_text(L.t("ui.generator_dialog.facultatif_jusqu_a_2_modificateurs"), UiTheme.DIM, 14, true)
	var chosen: Array = []
	var buttons := {}
	var refs := {}
	var refresh := func():
		for id in buttons:
			var b: Button = buttons[id]
			b.disabled = not chosen.has(id) and chosen.size() >= 2
			b.modulate = Color(1.25, 1.15, 0.85) if chosen.has(id) else Color.WHITE
		(refs.validate as Button).disabled = chosen.is_empty()
	for mod in DungeonGenerator.run_modifiers():
		var id: String = str(mod.id)
		var b := Button.new()
		b.text = "%s %s\n%s" % [mod.icon, mod.labelFr, mod.descFr]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 62)
		b.pressed.connect(func():
			if chosen.has(id):
				chosen.erase(id)
			elif chosen.size() < 2:
				chosen.append(id)
			refresh.call())
		buttons[id] = b
		m.content.add_child(b)
	var launch := func(mods: Array):
		Flows.choose("mods", mods)
	# la liste reçue est assainie (journal falsifié) : au plus 2 modificateurs distincts et connus
	Flows.open("mods", m, func(mods: Variant):
		var valid: Array = DungeonGenerator.run_modifiers().map(func(x): return str(x.id))
		var clean: Array = []
		if mods is Array:
			for id in mods:
				if valid.has(str(id)) and not clean.has(str(id)) and clean.size() < 2:
					clean.append(str(id))
		on_chosen.call(clean))
	m.set_buttons([
		{"text": L.t("common.valider"), "cb": func(): launch.call(chosen.duplicate())},
		{"text": L.t("ui.generator_dialog.aucun_modificateur"), "cb": func(): launch.call([])},
	])
	refs["validate"] = m._buttons_row.get_child(0)
	refresh.call()

static func _generate(host: Node, params: Dictionary, mods: Array, on_launch: Callable) -> void:
	var wait := Modal.open(host, L.t("ui.generator_dialog.creation_du_donjon"), 380.0)
	wait.add_text(L.t("ui.generator_dialog.generation_des_couloirs_et_du"), UiTheme.PARCH, 16, true)
	await host.get_tree().create_timer(0.35).timeout
	var cfg := DungeonGenerator.build_config(Data.config, int(params.levels), int(params.width), int(params.height), str(params.diff), mods)
	wait.close()
	on_launch.call(cfg)
