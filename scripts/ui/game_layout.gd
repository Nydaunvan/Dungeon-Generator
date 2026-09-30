class_name GameLayout
extends MarginContainer
## Interface adaptative : paysage (vue 3D + colonne de panneaux à droite) ou portrait
## (vue 3D, cartes, panneaux en onglets). Les mêmes contrôles sont déplacés d'une disposition à l'autre.

signal command(cmd: String)
signal menu_pressed(name: String)
signal item_pressed(index: int)
signal card_opened(char_id: String)
signal card_pressed(char_id: String)

const PORTRAIT_RATIO := 1.05   # largeur / hauteur en dessous : mode portrait

var gs: GameState
var ctrl: CombatController
var rig: PlayerRig

# monde 3D
var world: Node3D
var sub_viewport: SubViewport
var sub_container: SubViewportContainer
# éléments partagés
var header: PanelContainer
var frame: PanelContainer
var stage: Control
var popup_layer: Control
var message_label: Label
var level_label: Label
var compass_letters: Array[Label] = []
var pad: TouchControls
var act_box: VBoxContainer
var btn_interact: Button
var btn_flee: Button
var initiative: InitiativeBar
var strip: PanelContainer
var spell_bar: SpellBar
var rail: ColorRect
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
var _title: Label

func setup(state: GameState, controller: CombatController, r: PlayerRig) -> void:
	clip_contents = true
	gs = state
	ctrl = controller
	rig = r
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 6)
	_build_parts()
	resized.connect(_update_mode)
	_update_mode()

# ------------------------------------------------------------------ pièces

func _plaque(text: String, font_size: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiTheme.tbox("plaque", [10, 10, 10, 10], [10, 3, 10, 3]))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("e0c48a"))
	p.add_child(l)
	return p

func _build_parts() -> void:
	# en-tête
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiTheme.tbox("frame_header", [12, 12, 12, 12], [16, 5, 12, 5]))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	header.add_child(hrow)
	_title = Label.new()
	_title.text = str(Data.active().get("title", "Donjon")).to_upper()
	_title.clip_text = true
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color("e0b070"))
	_title.add_theme_constant_override("outline_size", 4)
	hrow.add_child(_title)
	for n in ["Accueil", "Admin", "Guide", "Son"]:
		var b := Button.new()
		b.text = "🔊" if n == "Son" else n.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		var nn: String = n
		b.pressed.connect(func(): menu_pressed.emit(nn))
		hrow.add_child(b)

	# cadre de la vue 3D
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.tbox("frame_view", [12, 12, 12, 12], [8, 8, 8, 8], false))
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

	# plaque du niveau (haut gauche)
	var lp := _plaque("", 13)
	lp.position = Vector2(8, 8)
	level_label = lp.get_child(0) as Label
	stage.add_child(lp)

	# boussole (haut centre) : N E ☠ S O, la direction actuelle est en or
	var comp := PanelContainer.new()
	comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comp.add_theme_stylebox_override("panel", UiTheme.tbox("plaque", [10, 10, 10, 10], [12, 3, 12, 3]))
	comp.anchor_left = 0.5
	comp.anchor_right = 0.5
	comp.offset_top = 8
	comp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	comp.add_child(crow)
	var letters := ["N", "E", "☠", "S", "O"]
	for l in letters:
		if l == "☠":
			var sk := TextureRect.new()
			sk.texture = UiTheme.tex("medallion")
			sk.custom_minimum_size = Vector2(18, 18)
			sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			crow.add_child(sk)
			continue
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		lb.add_theme_font_size_override("font_size", 14)
		crow.add_child(lb)
		compass_letters.append(lb)
	stage.add_child(comp)

	# chaîne d'initiative (sous la boussole)
	initiative = InitiativeBar.new()
	initiative.setup(gs, ctrl)
	initiative.anchor_left = 0.5
	initiative.anchor_right = 0.5
	initiative.offset_top = 46
	initiative.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stage.add_child(initiative)

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(popup_layer)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message_label.offset_top = 90
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate.a = 0.0
	stage.add_child(message_label)

	pad = TouchControls.new()
	pad.command.connect(func(c): command.emit(c))
	stage.add_child(pad)

	act_box = VBoxContainer.new()
	act_box.add_theme_constant_override("separation", 3)
	act_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_interact = Button.new()
	btn_interact.text = "✋"
	btn_flee = Button.new()
	btn_flee.text = "🏃"
	for b in [btn_interact, btn_flee]:
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color(1, 1, 1, 0.9)
		act_box.add_child(b)
	btn_interact.pressed.connect(func(): command.emit("interact"))
	btn_flee.pressed.connect(func(): command.emit("flee"))
	stage.add_child(act_box)
	frame.resized.connect(_size_overlays)

	# bandeau des sorts + rail, puis cartes
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	spell_bar = SpellBar.new()
	spell_bar.setup(gs, ctrl)
	spell_bar.attack_pressed.connect(func(): command.emit("attack"))
	spell_bar.spell_pressed.connect(func(id): ctrl.cast(id))
	strip.add_child(spell_bar)
	rail = ColorRect.new()
	rail.color = Color("5a4630")
	rail.custom_minimum_size = Vector2(0, 4)
	hud = PartyHud.new()
	hud.setup(gs, ctrl)
	hud.card_pressed.connect(func(id): card_pressed.emit(id))
	hud.card_opened.connect(func(id): card_opened.emit(id))

	# panneaux latéraux
	panel_map = OrnatePanel.new("Carte")
	panel_map.name = "Carte"
	var map_inset := PanelContainer.new()
	map_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_inset.add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [6, 6, 6, 6]))
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(60, 50)
	map_inset.add_child(minimap)
	panel_map.body.add_child(map_inset)
	panel_bag = OrnatePanel.new("Besace commune du groupe")
	panel_bag.name = "Besace"
	bag = BagPanel.new()
	bag.setup(gs)
	bag.item_pressed.connect(func(i): item_pressed.emit(i))
	panel_bag.body.add_child(bag)
	panel_log = OrnatePanel.new("Grimoire des événements")
	panel_log.name = "Journal"
	log_panel = LogPanel.new()
	log_panel.setup(gs)
	panel_log.body.add_child(log_panel)
	panel_menu = OrnatePanel.new("Sauvegarde")
	panel_menu.name = "Menu"
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	panel_menu.body.add_child(srow)
	for n in ["Sauvegarder", "Charger"]:
		var b := Button.new()
		b.text = n.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nn: String = n
		b.pressed.connect(func(): menu_pressed.emit(nn))
		srow.add_child(b)

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
	for n in [header, frame, strip, rail, hud, panel_map, panel_bag, panel_log, panel_menu]:
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
		v.add_child(strip)
		v.add_child(rail)
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
		h.name = "Main"
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 6)
		h.add_child(left)
		left.add_child(frame)
		left.add_child(strip)
		left.add_child(rail)
		left.add_child(hud)
		var right := VBoxContainer.new()
		right.name = "Right"
		right.add_theme_constant_override("separation", 12)
		h.add_child(right)
		for p in [panel_map, panel_bag, panel_log, panel_menu]:
			right.add_child(p)
		panel_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_map.size_flags_stretch_ratio = 1.0
		for p in [panel_map, panel_bag, panel_log]:
			p.custom_minimum_size = Vector2(0, 0)
		panel_bag.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_bag.size_flags_stretch_ratio = 1.15
		panel_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_log.size_flags_stretch_ratio = 1.15
		panel_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	call_deferred("_size_widgets")

func _size_widgets() -> void:
	var w := size.x
	var h := size.y
	if _root == null:
		return
	var hh := clampf(h * 0.225, 120.0, 300.0)
	hud.custom_minimum_size = Vector2(0, hh if not _portrait else clampf(h * 0.2, 110.0, 220.0))
	strip.custom_minimum_size = Vector2(0, clampf(h * 0.07, 36.0, 64.0))
	header.custom_minimum_size = Vector2(0, clampf(h * 0.07, 38.0, 60.0))
	_title.add_theme_font_size_override("font_size", int(clampf(h * 0.034, 15.0, 28.0)))
	var right: Node = _root.get_node_or_null("Main/Right")
	if right:
		(right as Control).custom_minimum_size = Vector2(clampf(w * 0.235, 230.0, 380.0), 0)
	_size_overlays()

func _size_overlays() -> void:
	var fs := stage.size
	var side := clampf(minf(fs.x, fs.y) * 0.11, 38.0, 60.0)
	pad.set_side(side)
	btn_interact.custom_minimum_size = Vector2(side, side)
	btn_flee.custom_minimum_size = Vector2(side, side)
	for b in [btn_interact, btn_flee]:
		b.add_theme_font_size_override("font_size", int(side * 0.5))
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	initiative.icon_size = clampf(fs.x * 0.035, 24.0, 42.0)

# ------------------------------------------------------------------ mises à jour

func set_level_name(text: String) -> void:
	level_label.text = text.to_upper()

func _process(_d: float) -> void:
	if rig != null:
		for i in compass_letters.size():
			# ordre affiché : N E S O = directions 0 1 2 3
			compass_letters[i].add_theme_color_override("font_color", UiTheme.GOLD if i == rig.dir else Color("6f5e44"))
