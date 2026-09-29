extends Node3D
## Scène principale : couloir 3D du niveau 1, déplacement case par case.
## Clavier (touches physiques, valables en AZERTY et QWERTY) :
##   ↑ / Z : avancer   ↓ / S : reculer   Q / D : pas de côté   ← / A : tourner à gauche   → / E : tourner à droite

var level_index: int = 0
var grid: DungeonGrid
var level_node: LevelView
var message_label: Label
var _message_tween: Tween
var rig: PlayerRig
var env: Environment

func _ready() -> void:
	var cfg: Dictionary = Data.config
	print("Donjon : ", cfg.get("title", "?"))
	print("Niveaux: %d | Classes: %d | Sorts: %d" % [cfg.levels.size(), cfg.classes.size(), cfg.spells.size()])
	for c in cfg.party:
		var b := Stats.char_base(c)
		print("%s -> PV %d, ATK %d-%d" % [c.name, b.maxHp, b.baseAtkMin, b.baseAtkMax])

	_setup_input()
	_setup_environment()
	rig = PlayerRig.new()
	add_child(rig)
	rig.camera.current = true
	rig.blocked.connect(_on_blocked)
	rig.moved.connect(_on_moved)
	rig.extra_block = func(x, y): return level_node != null and not level_node.entities.monster_at(x, y).is_empty()

	var ui := CanvasLayer.new()
	add_child(ui)
	var pad := TouchControls.new()
	pad.command.connect(_on_command)
	ui.add_child(pad)
	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message_label.offset_top = 16
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.modulate.a = 0.0
	ui.add_child(message_label)

	load_level(level_index)

func load_level(index: int) -> void:
	var level: Dictionary = Data.config.levels[index]
	if level_node:
		level_node.queue_free()
	level_index = index
	grid = DungeonGrid.new(level)
	level_node = LevelBuilder.build(level, grid)
	add_child(level_node)
	rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
	show_message(str(level.name))
	print("Niveau : %s (thème %s, %dx%d)" % [level.name, level.get("theme", "stone"), grid.width, grid.height])

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
		"interact": [KEY_F, KEY_SPACE, KEY_ENTER],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	for action in ["forward", "back", "left", "right", "turn_left", "turn_right", "interact"]:
		if event.is_action_pressed(action):
			_on_command(action)
			return

func _on_command(cmd: String) -> void:
	match cmd:
		"forward": rig.step(0)
		"right": rig.step(1)
		"back": rig.step(2)
		"left": rig.step(3)
		"turn_left": rig.turn(false)
		"turn_right": rig.turn(true)
		"interact": _interact()

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
			level_node.open_door(str(d.id))   # provisoire : sera déclenché par clé / ennemi vaincu
			show_message("La porte s'ouvre")
	elif ch == "S":
		_use_stairs(f)

func _on_moved() -> void:
	# provisoire : l'inventaire n'est pas encore porté, on se contente de retirer l'objet
	for it in level_node.entities.take_items_at(rig.gx, rig.gy):
		show_message("Ramassé : %s" % it.get("name", "objet"))

func _on_blocked(x: int, y: int) -> void:
	var mon := level_node.entities.monster_at(x, y)
	if not mon.is_empty():
		show_message("%s vous barre la route (combat à venir)" % mon.get("name", "Un monstre"))
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
			show_message("Victoire ! Vous avez terminé le donjon.")
		_:
			show_message("Escalier")

func show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.8)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)
