class_name GeneratorDialog
extends RefCounted
## Fenêtres du donjon aléatoire : réglages (niveaux, taille, difficulté) puis modificateurs d'expédition.

const BLURBS := {
	"easy": "Une aventure paisible, idéale pour découvrir le jeu ou jouer en toute décontraction.",
	"normal": "Un défi équilibré, pour une aventure classique à la difficulté raisonnable.",
	"hard": "Des ennemis nettement plus coriaces — préparez bien votre groupe avant de vous aventurer. Butin légendaire sur les boss : 50 %.",
	"hardcore": "Une véritable épreuve. Les ennemis frappent fort et vite : la moindre erreur peut être fatale. En contrepartie, le groupe démarre avec le double de PV et des caractéristiques légèrement supérieures. Butin légendaire sur les boss : 100 %.",
}
const DIFFS := [["easy", "Facile"], ["normal", "Normale"], ["hard", "Difficile"], ["hardcore", "Hardcore"]]

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
	var m := Modal.open(host, "Génération aléatoire", 500.0)
	m.add_text("Tout est généré automatiquement : monstres, objets, portes verrouillées, clés et un boss par niveau, en garantissant un chemin toujours accessible jusqu'à la sortie.", UiTheme.DIM, 14, true)
	var levels := _spin(1, 8, 3)
	var width := _spin(7, 60, 13)
	var height := _spin(7, 60, 11)
	_row(m, "Nombre de niveaux (max 8)", levels)
	_row(m, "Largeur par niveau (max 60)", width)
	_row(m, "Hauteur par niveau (max 60)", height)
	var diff := OptionButton.new()
	for d in DIFFS:
		diff.add_item(str(d[1]))
	diff.select(1)
	diff.custom_minimum_size = Vector2(150, 0)
	_row(m, "Difficulté", diff)
	var blurb := m.add_text(str(BLURBS["normal"]), UiTheme.DIM, 13, true)
	diff.item_selected.connect(func(i: int): blurb.text = str(BLURBS[DIFFS[i][0]]))
	var go := func():
		var params := {"levels": int(levels.value), "width": int(width.value), "height": int(height.value), "diff": str(DIFFS[diff.selected][0])}
		m.close()
		_pick_modifiers(host, params, on_launch)
	m.set_buttons([{"text": "Générer et jouer", "cb": go}, {"text": "Annuler", "cb": func(): m.close()}])

static func _pick_modifiers(host: Node, params: Dictionary, on_launch: Callable) -> void:
	var m := Modal.open(host, "Modificateurs d'expédition", 500.0)
	m.add_text("Facultatif : jusqu'à 2 modificateurs cumulables, chacun un vrai compromis pour varier l'expérience. Le choix reste actif pour toute cette expédition.", UiTheme.DIM, 14, true)
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
		m.close()
		_generate(host, params, mods, on_launch)
	m.set_buttons([
		{"text": "Valider", "cb": func(): launch.call(chosen.duplicate())},
		{"text": "Aucun modificateur", "cb": func(): launch.call([])},
	])
	refs["validate"] = m._buttons_row.get_child(0)
	refresh.call()

static func _generate(host: Node, params: Dictionary, mods: Array, on_launch: Callable) -> void:
	var wait := Modal.open(host, "Création du donjon", 380.0)
	wait.add_text("Génération des couloirs et du groupe…", UiTheme.PARCH, 16, true)
	await host.get_tree().create_timer(0.35).timeout
	var cfg := DungeonGenerator.build_config(Data.config, int(params.levels), int(params.width), int(params.height), str(params.diff), mods)
	wait.close()
	on_launch.call(cfg)
