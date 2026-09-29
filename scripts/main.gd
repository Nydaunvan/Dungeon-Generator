extends Node3D
## Scène principale : couloir 3D, équipe, combat au tour par tour.
## Clavier (touches physiques, libellés AZERTY) :
##   ↑/Z avancer · ↓/S reculer · Q/D pas de côté · ←/A et →/E tourner
##   X ou Espace : attaquer (ou interagir s'il n'y a rien à frapper) · F/Entrée : interagir · C : fuir

var level_index: int = 0
var gs: GameState
var grid: DungeonGrid
var level_node: LevelView
var rig: PlayerRig
var ctrl: CombatController
var env: Environment
var hud: PartyHud
var spell_bar: SpellBar
var message_label: Label
var log_label: Label
var _message_tween: Tween
var _popup_layer: Control

func _ready() -> void:
	var cfg: Dictionary = Data.config
	print("Donjon : ", cfg.get("title", "?"))
	gs = GameState.create(cfg)
	gs.log_added.connect(_on_log)
	for c in gs.party:
		print("%s -> PV %d, ATK %d-%d, vitesse %d" % [c.name, c.maxHp, c.atkMin, c.atkMax, c.effSpeed])

	_setup_input()
	_setup_environment()
	rig = PlayerRig.new()
	add_child(rig)
	rig.camera.current = true
	rig.blocked.connect(_on_blocked)
	rig.moved.connect(_on_moved)
	rig.extra_block = func(x, y): return ctrl != null and not ctrl.monster_at(x, y).is_empty()

	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.setup(gs, rig)
	ctrl.popup.connect(_show_popup)
	ctrl.game_over.connect(func(): show_message("☠️ Toute l'équipe a péri…", 6.0))

	var ui := CanvasLayer.new()
	add_child(ui)
	_popup_layer = Control.new()
	_popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_popup_layer)
	hud = PartyHud.new()
	ui.add_child(hud)
	hud.setup(gs, ctrl)
	hud.card_pressed.connect(ctrl.card_pressed)
	spell_bar = SpellBar.new()
	ui.add_child(spell_bar)
	spell_bar.setup(gs, ctrl)
	spell_bar.spell_pressed.connect(func(id): ctrl.cast(id))
	var pad := TouchControls.new()
	pad.command.connect(_on_command)
	ui.add_child(pad)
	log_label = Label.new()
	log_label.position = Vector2(8, 0)
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.add_theme_color_override("font_outline_color", Color.BLACK)
	log_label.add_theme_constant_override("outline_size", 4)
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(log_label)
	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate.a = 0.0
	ui.add_child(message_label)
	get_viewport().size_changed.connect(_layout_labels)

	load_level(level_index)
	_layout_labels()

func _layout_labels() -> void:
	var vp := get_viewport().get_visible_rect().size
	var hud_h := clampf(vp.y * 0.16, 96.0, 170.0) + 16.0
	spell_bar.position = Vector2(0, hud_h)
	spell_bar.size = Vector2(vp.x, 56)
	log_label.position = Vector2(8, hud_h + 60)
	message_label.position = Vector2(vp.x * 0.5 - message_label.size.x * 0.5, vp.y * 0.30)
	message_label.custom_minimum_size = Vector2(vp.x * 0.9, 0)
	message_label.size = Vector2(vp.x * 0.9, 40)
	message_label.position = Vector2(vp.x * 0.05, vp.y * 0.30)

func load_level(index: int) -> void:
	var level: Dictionary = Data.config.levels[index]
	if level_node:
		level_node.queue_free()
	level_index = index
	grid = DungeonGrid.new(level)
	# portes déjà ouvertes lors d'un précédent passage
	var ls := gs.level_state(level)
	level_node = LevelBuilder.build(level, grid)
	add_child(level_node)
	rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
	ctrl.bind_level(level, grid, level_node)
	for id in ls.get("opened_doors", {}):
		level_node.open_door(str(id), true)
	show_message(str(level.name))

func _setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030201")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("40342a")
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("030201")
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _setup_input() -> void:
	var map := {
		"forward": [KEY_UP, KEY_W],
		"back": [KEY_DOWN, KEY_S],
		"left": [KEY_A],
		"right": [KEY_D],
		"turn_left": [KEY_LEFT, KEY_Q],
		"turn_right": [KEY_RIGHT, KEY_E],
		"attack": [KEY_X, KEY_SPACE],
		"interact": [KEY_F, KEY_ENTER],
		"flee": [KEY_C],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	for action in ["forward", "back", "left", "right", "turn_left", "turn_right", "attack", "interact", "flee"]:
		if event.is_action_pressed(action):
			_on_command(action)
			return

func _on_command(cmd: String) -> void:
	if gs.game_over:
		return
	match cmd:
		"forward", "right", "back", "left", "turn_left", "turn_right":
			if ctrl.in_combat():
				show_message("En combat : attaquez (⚔) ou fuyez (🏃)")
				return
			match cmd:
				"forward": rig.step(0)
				"right": rig.step(1)
				"back": rig.step(2)
				"left": rig.step(3)
				"turn_left": rig.turn(false)
				"turn_right": rig.turn(true)
		"attack":
			if ctrl.in_combat():
				ctrl.attack()
			else:
				_interact()
		"interact": _interact()
		"flee":
			if ctrl.in_combat():
				ctrl.flee()
			else:
				show_message("Personne ne vous menace")

## Case juste devant le joueur.
func _front() -> Vector2i:
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	return Vector2i(rig.gx + v.x, rig.gy + v.y)

func _interact() -> void:
	var f := _front()
	var ch := grid.cell(f.x, f.y)
	if ch == "D":
		var d := grid.door_at(f.x, f.y)
		if not d.is_empty() and not grid.opened.has(str(d.id)):
			_open_door(str(d.id))   # provisoire : sera déclenché par clé / ennemi vaincu
			show_message("La porte s'ouvre")
	elif ch == "S":
		_use_stairs(f)
	else:
		show_message("Rien à faire ici")

func _open_door(id: String) -> void:
	level_node.open_door(id)
	gs.level_state(Data.config.levels[level_index]).get_or_add("opened_doors", {})[id] = true

func _on_moved() -> void:
	# provisoire : l'inventaire n'est pas encore porté, on retire simplement l'objet
	var ls := gs.level_state(Data.config.levels[level_index])
	for it in level_node.entities.take_items_at(rig.gx, rig.gy):
		ls.taken_items[str(it.id)] = true
		show_message("Ramassé : %s" % it.get("name", "objet"))
	ctrl.refresh()

func _on_blocked(x: int, y: int) -> void:
	var mon := ctrl.monster_at(x, y)
	if not mon.is_empty():
		ctrl.refresh()   # engage le combat
		return
	match grid.cell(x, y):
		"D": show_message("Porte fermée — touche F / ✋ pour l'ouvrir (provisoire)")
		"S": _use_stairs(Vector2i(x, y))

func _use_stairs(p: Vector2i) -> void:
	var st := grid.stairs_at(p.x, p.y)
	if st.is_empty():
		return
	var action: Dictionary = st.get("action", {})
	match str(action.get("type", "")):
		"level":
			var levels: Array = Data.config.levels
			for i in levels.size():
				if levels[i].id == action.get("targetId"):
					load_level(i)
					return
			show_message("Niveau introuvable : %s" % action.get("targetId"))
		"victory":
			gs.won = true
			show_message("Victoire ! Vous avez terminé le donjon.", 8.0)
		_:
			show_message("Escalier")

func _on_log(_text: String, _hit: bool) -> void:
	var lines := gs.log_lines.slice(maxi(0, gs.log_lines.size() - 5))
	log_label.text = "\n".join(lines)

func show_message(text: String, seconds: float = 1.8) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)

## Chiffre de dégâts qui monte et s'efface au centre de l'écran.
func _show_popup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport().get_visible_rect().size
	lbl.position = Vector2(vp.x * 0.5 - 40 + randf_range(-30, 30), vp.y * 0.5)
	_popup_layer.add_child(lbl)
	var t := create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 70, 1.0)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(lbl.queue_free)
