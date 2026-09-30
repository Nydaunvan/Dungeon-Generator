class_name GameLayout
extends MarginContainer
## Interface adaptative : paysage (vue 3D + colonne de panneaux à droite) ou portrait
## (vue 3D, cartes, panneaux en onglets). Les mêmes contrôles sont déplacés d'une disposition à l'autre.

signal command(cmd: String)
signal menu_pressed(name: String)
signal monster_pressed(def: Dictionary, st: Dictionary)
signal item_pressed(index: int)
signal card_opened(char_id: String)
signal card_pressed(char_id: String)
signal potion_quick(idx: int)
signal scrolls_quick

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
var queue: QueueBar
var banner: CombatBanner
var fx_layer: FxLayer
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
var _comp: Control
var _plaque_lvl: Control
var _vignette: TextureRect
var _timer_track: ColorRect
var _timer_fill: ColorRect
var _was_combat: bool = false
var _flash: ColorRect
var pouch: HBoxContainer
var _pouch_sig: String = ""

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
	for n in ["Accueil", "Admin", "Guide", "Stats", "Son"]:
		var b := Button.new()
		b.text = "🔊" if n == "Son" else ("📊" if n == "Stats" else n.to_upper())
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
	_plaque_lvl = lp

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
	_comp = comp

	# file d'initiative : chaîne sous la vue 3D (placée par _rebuild)
	queue = QueueBar.new()
	queue.setup(gs, ctrl)

	# lueur rouge en bord de vue pendant le combat
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.05, 0.03, 0.0), Color(0.75, 0.05, 0.03, 0.0), Color(0.75, 0.05, 0.03, 0.42)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.85)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	stage.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.12, 0.08, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_flash)
	# piste du chronomètre de tour (bas de la vue)
	_timer_track = ColorRect.new()
	_timer_track.color = Color(0, 0, 0, 0.55)
	_timer_track.anchor_top = 1.0
	_timer_track.anchor_bottom = 1.0
	_timer_track.anchor_right = 1.0
	_timer_track.offset_top = -7
	_timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_track.visible = false
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color("e8b45c")
	_timer_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_fill.anchor_right = 1.0
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_track.add_child(_timer_fill)
	stage.add_child(_timer_track)

	# barre rapide potions / parchemins (combat)
	pouch = HBoxContainer.new()
	pouch.add_theme_constant_override("separation", 8)
	pouch.anchor_left = 0.5
	pouch.anchor_right = 0.5
	pouch.anchor_top = 1.0
	pouch.anchor_bottom = 1.0
	pouch.offset_top = -62
	pouch.offset_bottom = -12
	pouch.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pouch.visible = false
	stage.add_child(pouch)

	banner = CombatBanner.new()
	banner.setup(ctrl)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = 104
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.pressed.connect(func(d, s): monster_pressed.emit(d, s))
	stage.add_child(banner)

	fx_layer = FxLayer.new()
	stage.add_child(fx_layer)

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
	btn_flee.text = "🏃 FUITE"
	_style_flee()
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
	if panel_map.header_row != null:
		var fb := Button.new()
		fb.text = "🗺️"
		fb.flat = true
		fb.focus_mode = Control.FOCUS_NONE
		fb.tooltip_text = "Carte en plein écran (touche M)"
		fb.pressed.connect(func(): menu_pressed.emit("Carte"))
		panel_map.header_row.add_child(fb)
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
	if panel_log.header_row != null:
		var lb := Button.new()
		lb.text = "📜"
		lb.flat = true
		lb.focus_mode = Control.FOCUS_NONE
		lb.tooltip_text = "Historique complet du journal"
		lb.pressed.connect(func(): menu_pressed.emit("Journal"))
		panel_log.header_row.add_child(lb)
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
	for n in [header, frame, queue, strip, rail, hud, panel_map, panel_bag, panel_log, panel_menu]:
		_detach(n)
	if _root != null:
		_root.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_root = v
	add_child(v)
	v.add_child(header)
	_title.add_theme_font_size_override("font_size", 15 if _portrait else 26)
	for b in _title.get_parent().get_children():
		if b is Button:
			b.add_theme_font_size_override("font_size", 10 if _portrait else 16)
			b.custom_minimum_size = Vector2(0, 0)
	if _portrait:
		frame.size_flags_stretch_ratio = 3.0
		v.add_child(frame)
		v.add_child(queue)
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
		left.add_child(queue)
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
	queue.set_target_height(44.0 if _portrait else clampf(h * 0.08, 36.0, 70.0))
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
	btn_interact.add_theme_font_size_override("font_size", int(side * 0.5))
	btn_flee.custom_minimum_size = Vector2(side * 2.6, side * 0.8)
	btn_flee.add_theme_font_size_override("font_size", int(side * 0.3))
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)

# ------------------------------------------------------------------ mises à jour

func set_level_name(text: String) -> void:
	level_label.text = text.to_upper()

func _refresh_pouch(on: bool) -> void:
	var potions: Array = []
	var scrolls := 0
	if on:
		for i in gs.inventory.size():
			var it: Dictionary = gs.inventory[i]
			var t := str(it.get("type", ""))
			if t == "potion":
				var key := "%s|%d|%d" % [it.get("name", ""), int(it.get("heal", 0)), int(it.get("staminaRestore", 0))]
				var hit := false
				for g in potions:
					if g.key == key:
						g.count += 1
						hit = true
						break
				if not hit:
					potions.append({"key": key, "it": it, "idx": i, "count": 1})
			elif t == "scroll":
				scrolls += 1
	var sig := str(on) + "|" + str(potions.map(func(g): return "%s%d" % [g.key, g.count])) + "|" + str(scrolls)
	if sig == _pouch_sig:
		return
	_pouch_sig = sig
	for c in pouch.get_children():
		c.queue_free()
	pouch.visible = on and (not potions.is_empty() or scrolls > 0)
	for g in potions:
		var it2: Dictionary = g.it
		var detail := "+%d PV" % int(it2.heal) if int(it2.get("heal", 0)) > 0 else ("+%d End." % int(it2.get("staminaRestore", 0)) if int(it2.get("staminaRestore", 0)) > 0 else "")
		var idx: int = g.idx
		pouch.add_child(_pouch_button(IconResolver.texture(str(it2.get("icon", ""))), "🧪", detail, int(g.count), str(it2.get("name", "")), func(): potion_quick.emit(idx)))
	if scrolls > 0:
		pouch.add_child(_pouch_button(null, "📜", "Parchemins", scrolls, "Parchemins", func(): scrolls_quick.emit()))

func _pouch_button(tex: Texture2D, glyph: String, detail: String, count: int, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(64, 46)
	b.add_theme_font_size_override("font_size", 11)
	b.text = "" if tex != null else glyph
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 26)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.text = detail if tex != null else glyph + "\n" + detail
	b.pressed.connect(cb)
	if count > 1:
		var l := Label.new()
		l.text = "×%d" % count
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("1a1108"))
		var bs := UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 9)
		bs.content_margin_left = 5
		bs.content_margin_right = 5
		bs.content_margin_top = 0
		bs.content_margin_bottom = 0
		l.add_theme_stylebox_override("normal", bs)
		l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		l.offset_right = 6
		l.offset_top = -7
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	return b

func _style_flee() -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("5a1712") if st != "hover" else Color("7a2018")
		sb.border_color = Color("c9a25c")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(0, 0, 0, 0.8)
		sb.shadow_size = 3
		sb.set_content_margin_all(6)
		btn_flee.add_theme_stylebox_override(st, sb)
	btn_flee.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	btn_flee.add_theme_color_override("font_color", Color("f3dcae"))

func _process(_d: float) -> void:
	var on := ctrl != null and ctrl.in_combat()
	if on != _was_combat:
		_was_combat = on
		if on:
			_flash.color.a = 0.55
			create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	_refresh_pouch(on)
	pad.visible = not on
	_comp.visible = not on
	_plaque_lvl.visible = not on
	btn_interact.visible = not on
	btn_flee.visible = on
	_vignette.visible = on
	var tf := ctrl.turn_timer_fraction() if on else -1.0
	_timer_track.visible = tf >= 0.0
	if on:
		_timer_fill.anchor_right = clampf(tf, 0.0, 1.0)
		_timer_fill.color = Color("e8b45c") if tf > 0.3 else Color("d8452e")
		_vignette.modulate.a = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 400.0)
	if rig != null:
		for i in compass_letters.size():
			# ordre affiché : N E S O = directions 0 1 2 3
			compass_letters[i].add_theme_color_override("font_color", UiTheme.GOLD if i == rig.dir else Color("6f5e44"))
