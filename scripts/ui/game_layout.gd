class_name GameLayout
extends MarginContainer
## Interface adaptative : paysage (vue 3D + colonne de panneaux à droite) ou portrait
## (vue 3D, cartes, panneaux en onglets). Les mêmes contrôles sont déplacés d'une disposition à l'autre.

signal command(cmd: String)
signal menu_pressed(name: String)

const PORTRAIT_RATIO := 1.05   # largeur / hauteur en dessous : mode portrait

var gs: GameState
var ctrl: CombatController

# monde 3D
var world: Node3D
var sub_viewport: SubViewport
var sub_container: SubViewportContainer
# éléments partagés
var header: HBoxContainer
var frame: PanelContainer
var stage: Control
var popup_layer: Control
var message_label: Label
var level_label: Label
var compass: Label
var pad: TouchControls
var act_box: VBoxContainer
var btn_interact: Button
var btn_flee: Button
var initiative: InitiativeBar
var spell_bar: SpellBar
var hud: PartyHud
var minimap: Minimap
var bag: BagPanel
var log_panel: LogPanel
var panel_map: OrnatePanel
var panel_bag: OrnatePanel
var panel_log: OrnatePanel
var panel_menu: OrnatePanel

var _root: Control
var _portrait: bool = false
var _built_mode: int = -1
var rig: PlayerRig

func setup(state: GameState, controller: CombatController, r: PlayerRig) -> void:
	gs = state
	ctrl = controller
	rig = r
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 8)
	var bgr := ColorRect.new()   # fond opaque derrière toute l'interface
	bgr.color = UiTheme.BG
	bgr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgr.top_level = true
	add_child(bgr)
	bgr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_parts()
	resized.connect(_update_mode)
	_update_mode()

# ------------------------------------------------------------------ pièces

func _build_parts() -> void:
	# en-tête
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = str(Data.config.get("title", "Donjon"))
	title.clip_text = true
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	header.add_child(title)
	for n in ["Accueil", "Admin", "Guide"]:
		var b := Button.new()
		b.text = n
		b.focus_mode = Control.FOCUS_NONE
		var nn: String = n
		b.pressed.connect(func(): menu_pressed.emit(nn))
		header.add_child(b)

	# cadre de la vue 3D
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color.BLACK, UiTheme.BRONZE, 5, 6))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(200, 160)
	stage = Control.new()
	stage.clip_contents = true
	frame.add_child(stage)
	sub_container = SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sub_container)
	sub_viewport = SubViewport.new()
	sub_viewport.own_world_3d = true
	sub_viewport.handle_input_locally = false
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_container.add_child(sub_viewport)
	world = Node3D.new()
	sub_viewport.add_child(world)

	level_label = Label.new()
	level_label.position = Vector2(10, 6)
	level_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	level_label.add_theme_font_size_override("font_size", 15)
	level_label.add_theme_color_override("font_color", UiTheme.GOLD)
	level_label.add_theme_constant_override("outline_size", 6)
	stage.add_child(level_label)

	compass = Label.new()
	compass.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	compass.offset_left = -50
	compass.offset_top = 6
	compass.offset_right = -8
	compass.offset_bottom = 48
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compass.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	compass.add_theme_font_size_override("font_size", 22)
	compass.add_theme_color_override("font_color", UiTheme.GOLD)
	compass.add_theme_stylebox_override("normal", UiTheme.round_button_style(UiTheme.BRONZE, Color(0, 0, 0, 0.6)))
	stage.add_child(compass)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(popup_layer)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message_label.offset_top = 52
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate.a = 0.0
	stage.add_child(message_label)

	pad = TouchControls.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	pad.command.connect(func(c): command.emit(c))
	stage.add_child(pad)

	act_box = VBoxContainer.new()
	act_box.add_theme_constant_override("separation", 4)
	act_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	btn_interact = Button.new()
	btn_interact.text = "✋"
	btn_flee = Button.new()
	btn_flee.text = "🏃"
	for b in [btn_interact, btn_flee]:
		b.focus_mode = Control.FOCUS_NONE
		act_box.add_child(b)
	btn_interact.pressed.connect(func(): command.emit("interact"))
	btn_flee.pressed.connect(func(): command.emit("flee"))
	stage.add_child(act_box)
	frame.resized.connect(_size_overlays)

	# chaîne d'initiative, sorts, cartes
	initiative = InitiativeBar.new()
	initiative.setup(gs, ctrl)
	spell_bar = SpellBar.new()
	spell_bar.setup(gs, ctrl)
	spell_bar.attack_pressed.connect(func(): command.emit("attack"))
	spell_bar.spell_pressed.connect(func(id): ctrl.cast(id))
	hud = PartyHud.new()
	hud.setup(gs, ctrl)
	hud.card_pressed.connect(ctrl.card_pressed)

	# panneaux latéraux
	panel_map = OrnatePanel.new("Carte")
	panel_map.name = "Carte"
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(120, 160)
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_map.body.add_child(minimap)
	panel_bag = OrnatePanel.new("Besace")
	panel_bag.name = "Besace"
	bag = BagPanel.new()
	bag.setup(gs)
	panel_bag.body.add_child(bag)
	panel_log = OrnatePanel.new("Journal")
	panel_log.name = "Journal"
	log_panel = LogPanel.new()
	log_panel.setup(gs)
	panel_log.body.add_child(log_panel)
	panel_menu = OrnatePanel.new("Sauvegarde")
	panel_menu.name = "Menu"
	for n in ["Sauvegarder", "Charger"]:
		var b := Button.new()
		b.text = n
		b.focus_mode = Control.FOCUS_NONE
		var nn: String = n
		b.pressed.connect(func(): menu_pressed.emit(nn))
		panel_menu.body.add_child(b)

# ------------------------------------------------------------------ dispositions

func _update_mode() -> void:
	var portrait := size.x < size.y * PORTRAIT_RATIO
	var mode := 1 if portrait else 0
	if mode != _built_mode:
		_built_mode = mode
		_portrait = portrait
		_rebuild()
	_size_widgets()

func _detach(n: Node) -> void:
	if n.get_parent() != null:
		n.get_parent().remove_child(n)

func _rebuild() -> void:
	for n in [header, frame, initiative, spell_bar, hud, panel_map, panel_bag, panel_log, panel_menu]:
		_detach(n)
	if _root != null:
		_root.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_root = v
	add_child(v)
	v.add_child(header)
	if _portrait:
		frame.size_flags_stretch_ratio = 3.0
		v.add_child(frame)
		v.add_child(initiative)
		v.add_child(spell_bar)
		v.add_child(hud)
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tabs.size_flags_stretch_ratio = 2.0
		tabs.custom_minimum_size = Vector2(0, 120)
		v.add_child(tabs)
		for p in [panel_map, panel_bag, panel_log, panel_menu]:
			tabs.add_child(p)
	else:
		frame.size_flags_stretch_ratio = 1.0
		var h := HBoxContainer.new()
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 6)
		h.add_child(left)
		left.add_child(frame)
		left.add_child(initiative)
		left.add_child(spell_bar)
		left.add_child(hud)
		var right := VBoxContainer.new()
		right.name = "Right"
		right.custom_minimum_size = Vector2(clampf(size.x * 0.24, 220.0, 360.0), 0)
		right.add_theme_constant_override("separation", 6)
		h.add_child(right)
		for p in [panel_map, panel_bag, panel_log, panel_menu]:
			right.add_child(p)
		panel_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_map.size_flags_stretch_ratio = 1.4
		panel_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_bag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	spell_bar.custom_minimum_size = Vector2(0, 60)
	call_deferred("_size_widgets")

func _size_widgets() -> void:
	var w := size.x
	var s := clampf(w * (0.07 if _portrait else 0.035), 30.0, 44.0)
	initiative.icon_size = s
	initiative.custom_minimum_size = Vector2(0, s + 10.0)
	var right: Node = null
	if _root != null:
		right = _root.get_node_or_null("HBoxContainer/Right")
	if right:
		right.custom_minimum_size = Vector2(clampf(w * 0.24, 220.0, 360.0), 0)
	_size_overlays()

func _size_overlays() -> void:
	var fs := frame.size
	var side := clampf(minf(fs.x, fs.y) * 0.16, 40.0, 84.0)
	pad.set_side(side)
	btn_interact.custom_minimum_size = Vector2(side, side)
	btn_flee.custom_minimum_size = Vector2(side, side)
	for b in [btn_interact, btn_flee]:
		b.add_theme_font_size_override("font_size", int(side * 0.5))
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)

# ------------------------------------------------------------------ mises à jour

func set_level_name(text: String) -> void:
	level_label.text = text

func _process(_d: float) -> void:
	if rig != null:
		compass.text = ["N", "E", "S", "O"][rig.dir]

## Diagnostic : tailles et visibilité des éléments principaux.
func debug_report() -> String:
	var parts: Array[String] = []
	parts.append("layout size=%s pos=%s visible=%s" % [size, position, visible_in_tree()])
	for pair in [["header", header], ["frame", frame], ["stage", stage], ["sub_container", sub_container], ["hud", hud], ["spell_bar", spell_bar], ["minimap", minimap]]:
		var c: Control = pair[1]
		parts.append("%s size=%s in_tree=%s parent=%s" % [pair[0], c.size, c.is_inside_tree(), c.get_parent().name if c.get_parent() else "AUCUN"])
	parts.append("root children=%d, viewport=%s" % [_root.get_child_count() if _root else -1, get_viewport().get_visible_rect().size])
	return "\n".join(parts)
