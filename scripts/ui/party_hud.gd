class_name PartyHud
extends HBoxContainer
## Cartes de l'équipe en arche : bandeau de classe, portrait rond, nom, PV / endurance / XP,
## jauge de tour en combat, chronomètre de tour. Cliquer une carte = choisir le personnage / la cible.

signal card_pressed(char_id: String)

var gs: GameState
var ctrl: CombatController
var _cards: Dictionary = {}

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_card_input.bind(str(c.id)))
	var style := UiTheme.box(Color("15100b"), UiTheme.BRONZE, 3, 40)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var banner := ColorRect.new()
	banner.color = accent
	banner.custom_minimum_size = Vector2(0, 5)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(banner)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	var tex: Texture2D = load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", "")))
	var pic := UiTheme.portrait(tex, accent, 64)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	v.add_child(name_lbl)
	var cls_lbl := Label.new()
	cls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cls_lbl.clip_text = true
	cls_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cls_lbl.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	cls_lbl.add_theme_color_override("font_color", UiTheme.DIM)
	v.add_child(cls_lbl)
	var hp := TextBar.new(UiTheme.HP_GREEN, 16, 11)
	var sta := TextBar.new(UiTheme.STA_CYAN, 14, 10)
	var xp := TextBar.new(Color("b8963a"), 12, 9)
	var gauge := TextBar.new(UiTheme.GOLD, 6, 1)
	for b in [hp, sta, xp, gauge]:
		v.add_child(b)
	_cards[str(c.id)] = {"panel": panel, "style": style, "name": name_lbl, "cls": cls_lbl, "hp": hp, "sta": sta,
		"xp": xp, "gauge": gauge, "pic": pic, "cls_name": cls_name}

func _on_card_input(ev: InputEvent, char_id: String) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_pressed.emit(char_id)

func _resize() -> void:
	var w := maxf(60.0, size.x / maxf(1.0, float(_cards.size())) - 6.0)
	var pic_size := clampf(w * 0.5, 36.0, 96.0)
	var font := int(clampf(w * 0.085, 9.0, 16.0))
	for id in _cards:
		var cd: Dictionary = _cards[id]
		cd.pic.custom_minimum_size = Vector2(pic_size, pic_size)
		cd.name.add_theme_font_size_override("font_size", font + 1)
		cd.cls.add_theme_font_size_override("font_size", font - 1)
		cd.hp.set_font_size(font - 1)
		cd.sta.set_font_size(font - 2)
		cd.xp.set_font_size(font - 3)

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.name.text = str(c.name)
		cd.cls.text = "%s · Nv.%d" % [cd.cls_name, int(c.level)]
		cd.hp.set_values(int(c.hp), int(c.maxHp), "%d/%d PV" % [int(c.hp), int(c.maxHp)])
		cd.sta.set_values(int(c.stamina), int(c.maxStamina), "End. %d/%d" % [int(c.stamina), int(c.maxStamina)])
		cd.xp.set_values(int(c.get("xp", 0)), int(c.get("xpToNext", 1)), "XP %d/%d" % [int(c.get("xp", 0)), int(c.get("xpToNext", 1))])
		var dead: bool = int(c.hp) <= 0
		cd.panel.modulate = Color(0.45, 0.45, 0.45) if dead else Color.WHITE
		var my_turn: bool = ctrl.in_combat() and gs.active_char_id == str(c.id) \
				and float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0)) >= 100.0
		var selected: bool = not ctrl.in_combat() and gs.active_char_id == str(c.id)
		var targeting: bool = ctrl.pending_spell != "" and not dead
		cd.style.border_color = UiTheme.GOLD if (my_turn or selected) else (Color("7fd17f") if targeting else UiTheme.BRONZE)
		cd.style.set_border_width_all(5 if (my_turn or selected or targeting) else 3)

func _process(_delta: float) -> void:
	if ctrl.combat == null:
		return
	var in_fight := ctrl.in_combat()
	var tf := ctrl.turn_timer_fraction()
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.gauge.visible = in_fight
		if in_fight:
			var key := "char_" + str(c.id)
			var g := float(ctrl.combat.gauges.get(key, 0.0))
			# à son tour : la barre montre le temps restant
			if g >= 100.0 and gs.active_char_id == str(c.id) and tf >= 0.0:
				cd.gauge.set_values(tf * 100.0, 100.0, "")
			else:
				cd.gauge.set_values(g, 100.0, "")
