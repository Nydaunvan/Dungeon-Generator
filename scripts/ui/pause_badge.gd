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
	var sb := AtlasBox.new(0.0)
	sb.fill_top = Color(Atlas.OBSIDIAN, 0.92)
	sb.fill_bottom = Color(Atlas.OBSIDIAN, 0.92)
	sb.border = Atlas.AMBER
	sb.cut = 5.0
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
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
		bar.color = Atlas.AMBER
		bar.custom_minimum_size = Vector2(4, 12)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)
	var lab := Label.new()
	lab.text = L.t("ui.pause.label")
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_font_override("font", Atlas.title_font())
	lab.add_theme_color_override("font_color", Atlas.IVORY)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	_pill.visible = false
	add_child(_pill)

func _process(_d: float) -> void:
	var on: bool = is_instance_valid(host) and host.has_method("is_game_paused") and host.is_game_paused() and not PauseOverlay.active()
	if _pill.visible != on:
		_pill.visible = on
	if on:
		# tout en haut de l'écran, au centre, au-dessus du titre du donjon
		var vw: float = host.get_viewport().get_visible_rect().size.x
		_pill.position = Vector2((vw - _pill.size.x) * 0.5, 3.0)
