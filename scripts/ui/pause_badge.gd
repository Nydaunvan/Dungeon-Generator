class_name PauseBadge
extends CanvasLayer
## Pastille « pause » en haut de l'écran de jeu : visible dès que quelque chose fige la partie (volet d'inventaire déployé, fenêtre
## ouverte : marchand, piège, fiche…). Purement informative, ne capte jamais la souris. La pause manuelle (PauseOverlay) a son propre symbole.

var host: Node
var _pill: PanelContainer

func setup(h: Node) -> void:
	host = h
	layer = 118
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.82)
	sb.border_color = Color(0.96, 0.9, 0.75, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(row)
	var bars := HBoxContainer.new()                 # symbole dessiné : aucune dépendance à une police
	bars.add_theme_constant_override("separation", 5)
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bars)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.96, 0.9, 0.75, 0.95)
		bar.custom_minimum_size = Vector2(6, 18)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
	var lab := Label.new()
	lab.text = L.t("ui.pause.label")
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(0.96, 0.9, 0.75, 0.95))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	_pill.visible = false
	_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pill.position.y = 8
	add_child(_pill)

func _process(_d: float) -> void:
	var on: bool = is_instance_valid(host) and host.has_method("is_game_paused") and host.is_game_paused() and not PauseOverlay.active()
	if _pill.visible != on:
		_pill.visible = on
