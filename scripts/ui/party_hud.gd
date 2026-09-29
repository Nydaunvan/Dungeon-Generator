class_name PartyHud
extends VBoxContainer
## Cartes de l'équipe (portrait, nom/niveau, PV, endurance, jauge de tour) + chronomètre de tour.
## S'adapte à la taille de l'écran (mobile portrait/paysage, PC).

var gs: GameState
var ctrl: CombatController
var _row: HBoxContainer
var _timer_bar: ProgressBar
signal card_pressed(char_id: String)

var _cards: Dictionary = {}

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 4)
	add_child(_row)
	_timer_bar = _make_bar(Color("d8a840"), 6)
	add_child(_timer_bar)
	for c in gs.party:
		_add_card(c)
	ctrl.changed.connect(refresh)
	get_viewport().size_changed.connect(_resize)
	_resize()
	refresh()

func _on_card_input(ev: InputEvent, char_id: String) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(char_id)

func _make_bar(fill: Color, h: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b

func _add_card(c: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_input.bind(str(c.id)))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.03, 0.78)
	style.set_border_width_all(2)
	style.border_color = Color("5a4630")
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel", style)
	_row.add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	panel.add_child(v)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pp := IconResolver.portrait_path(c, gs.cfg)
	if pp != "":
		pic.texture = load(pp)
	else:
		pic.texture = IconResolver.texture(str(c.get("icon", "")))
	v.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.clip_text = true
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)
	var hp := _make_bar(Color("c0392b"), 8)
	var sta := _make_bar(Color("3aa0d8"), 5)
	var gauge := _make_bar(Color("e8b45c"), 4)
	v.add_child(hp)
	v.add_child(sta)
	v.add_child(gauge)
	_cards[str(c.id)] = {"panel": panel, "style": style, "name": name_lbl, "hp": hp, "sta": sta,
		"gauge": gauge, "pic": pic}

func _resize() -> void:
	var vp := get_viewport_rect().size
	var card_h := clampf(vp.y * 0.16, 96.0, 170.0)
	var font := int(clampf(card_h * 0.11, 10.0, 16.0))
	for id in _cards:
		var cd: Dictionary = _cards[id]
		cd.panel.custom_minimum_size = Vector2(0, card_h)
		cd.name.add_theme_font_size_override("font_size", font)
		cd.pic.custom_minimum_size = Vector2(0, card_h * 0.5)

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.name.text = "%s  Niv.%d" % [c.name, c.level]
		cd.hp.max_value = int(c.maxHp)
		cd.hp.value = int(c.hp)
		cd.sta.max_value = int(c.maxStamina)
		cd.sta.value = int(c.stamina)
		var dead: bool = int(c.hp) <= 0
		cd.panel.modulate = Color(0.45, 0.45, 0.45) if dead else Color.WHITE
		var my_turn: bool = ctrl.in_combat() and gs.active_char_id == str(c.id) \
				and float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0)) >= 100.0
		var selected: bool = not ctrl.in_combat() and gs.active_char_id == str(c.id)
		var targeting: bool = ctrl.pending_spell != "" and not dead
		cd.style.border_color = Color("f5d060") if (my_turn or selected) else (Color("7fd17f") if targeting else Color("5a4630"))
		cd.style.set_border_width_all(4 if (my_turn or selected or targeting) else 2)

func _process(_delta: float) -> void:
	if ctrl.combat == null:
		return
	var in_fight := ctrl.in_combat()
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.gauge.visible = in_fight
		if in_fight:
			cd.gauge.value = float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0))
	var f := ctrl.turn_timer_fraction()
	_timer_bar.visible = f >= 0.0
	if f >= 0.0:
		_timer_bar.value = f * 100.0
