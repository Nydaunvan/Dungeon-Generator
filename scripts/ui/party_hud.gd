class_name PartyHud
extends HBoxContainer
## Cartes de l'équipe en arche : ruban de classe, portrait rond, nom, classe, niveau, PV / endurance / XP,
## jauge de tour en combat. Cliquer une carte = choisir le personnage / la cible d'un sort.

signal card_pressed(char_id: String)
signal card_opened(char_id: String)

var gs: GameState
var ctrl: CombatController
var _cards: Dictionary = {}
var _st_normal: StyleBox
var _st_active: StyleBox
var _st_target: StyleBox

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	clip_contents = true
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_st_normal = UiTheme.tbox("card_arch", [62, 62, 62, 14], [12, 8, 12, 10])
	_st_active = UiTheme.tbox("card_arch_active", [62, 62, 62, 14], [12, 8, 12, 10])
	_st_target = UiTheme.tbox("card_arch_target", [62, 62, 62, 14], [12, 8, 12, 10])
	for c in gs.party:
		_add_card(c)
	ctrl.changed.connect(refresh)
	resized.connect(_resize)
	_resize()
	refresh()

func _add_card(c: Dictionary) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var cls_name := str(cls.get("name", ""))
	var base := str(cls.get("evolvesFrom", cls_name))
	var accent := UiTheme.class_color(base)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_input.bind(str(c.id)))
	panel.add_theme_stylebox_override("panel", _st_normal)
	add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	panel.add_child(v)
	var ribbon := TextureRect.new()
	ribbon.texture = UiTheme.tex("ribbon")
	ribbon.modulate = accent
	ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ribbon.stretch_mode = TextureRect.STRETCH_SCALE
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ribbon)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	var tex: Texture2D = load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", "")))
	var pic := UiTheme.portrait(tex, UiTheme.BRONZE_LIGHT.lerp(accent, 0.5), 64)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.text = str(c.name).to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	v.add_child(name_lbl)
	var cls_lbl := Label.new()
	cls_lbl.text = cls_name
	cls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_lbl.clip_text = true
	cls_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cls_lbl.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	cls_lbl.add_theme_color_override("font_color", Color("b8843e"))
	v.add_child(cls_lbl)
	var lvl_row := HBoxContainer.new()
	lvl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lvl_lbl := Label.new()
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_lbl.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	var chest := TextureRect.new()
	chest.texture = UiTheme.tex("chest")
	chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_row.add_child(lvl_lbl)
	lvl_row.add_child(chest)
	v.add_child(lvl_row)
	var hp := TextBar.new(UiTheme.HP_GREEN, 16, 11)
	var sta := TextBar.new(UiTheme.STA_CYAN, 14, 10)
	var xp := TextBar.new(Color("2b2114"), 14, 10)
	var gauge := TextBar.new(UiTheme.GOLD, 5, 1)
	for b in [hp, sta, xp, gauge]:
		v.add_child(b)
	_cards[str(c.id)] = {"panel": panel, "name": name_lbl, "cls": cls_lbl, "lvl": lvl_lbl, "chest": chest,
		"ribbon": ribbon, "hp": hp, "sta": sta, "xp": xp, "gauge": gauge, "pic": pic, "state": "normal"}

func _on_card_input(ev: InputEvent, char_id: String) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(char_id)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			card_opened.emit(char_id)

func _resize() -> void:
	# tout est dimensionné à partir de la hauteur réellement disponible : les cartes ne peuvent pas déborder
	var inner := maxf(80.0, size.y - 24.0)
	var w := maxf(80.0, size.x / maxf(1.0, float(_cards.size())) - 10.0)
	var pic_size := clampf(minf(inner * 0.25, w * 0.42), 28.0, 96.0)
	var line := func(frac: float) -> float: return maxf(9.0, inner * frac)
	var name_h: float = line.call(0.11)
	var small_h: float = line.call(0.085)
	var bar_h: float = inner * 0.10
	for id in _cards:
		var cd: Dictionary = _cards[id]
		cd.pic.custom_minimum_size = Vector2(pic_size, pic_size)
		cd.ribbon.custom_minimum_size = Vector2(clampf(w * 0.55, 60.0, 130.0), clampf(inner * 0.06, 8.0, 18.0))
		cd.name.custom_minimum_size = Vector2(0, name_h)
		cd.name.add_theme_font_size_override("font_size", int(clampf(name_h / 1.5, 8.0, 22.0)))
		cd.cls.custom_minimum_size = Vector2(0, small_h)
		cd.cls.add_theme_font_size_override("font_size", int(clampf(small_h / 1.5, 8.0, 17.0)))
		cd.lvl.custom_minimum_size = Vector2(0, small_h)
		cd.lvl.add_theme_font_size_override("font_size", int(clampf(small_h / 1.5, 8.0, 17.0)))
		cd.chest.custom_minimum_size = Vector2(small_h * 0.8, small_h * 0.8)
		cd.hp.set_height(bar_h * 1.05)
		cd.sta.set_height(bar_h * 0.95)
		cd.xp.set_height(bar_h * 0.95)
		cd.gauge.set_height(maxf(4.0, inner * 0.03))
		cd.gauge.set_font_size(1)

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.lvl.text = "Nv.%d" % int(c.level)
		cd.hp.set_values(int(c.hp), int(c.maxHp), "%d/%d PV" % [int(c.hp), int(c.maxHp)])
		cd.sta.set_values(int(c.stamina), int(c.maxStamina), "%d/%d End." % [int(c.stamina), int(c.maxStamina)])
		cd.xp.set_values(int(c.get("xp", 0)), int(c.get("xpToNext", 1)), "%d/%d XP" % [int(c.get("xp", 0)), int(c.get("xpToNext", 1))])
		var dead: bool = int(c.hp) <= 0
		cd.panel.modulate = Color(0.45, 0.45, 0.45) if dead else Color.WHITE
		var my_turn: bool = ctrl.in_combat() and gs.active_char_id == str(c.id) \
				and float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0)) >= 100.0
		var selected: bool = not ctrl.in_combat() and gs.active_char_id == str(c.id)
		var targeting: bool = ctrl.pending_spell != "" and not dead
		var want := "active" if (my_turn or selected) else ("target" if targeting else "normal")
		if want != cd.state:
			cd.state = want
			cd.panel.add_theme_stylebox_override("panel", _st_active if want == "active" else (_st_target if want == "target" else _st_normal))

func _process(_delta: float) -> void:
	if ctrl.combat == null:
		return
	var in_fight := ctrl.in_combat()
	var tf := ctrl.turn_timer_fraction()
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.gauge.visible = in_fight
		if in_fight:
			var g := float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0))
			if g >= 100.0 and gs.active_char_id == str(c.id) and tf >= 0.0:
				cd.gauge.set_values(tf * 100.0, 100.0, "")
			else:
				cd.gauge.set_values(g, 100.0, "")
