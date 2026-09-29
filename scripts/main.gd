extends Node3D
## Scène principale : couloir 3D du niveau 1, déplacement case par case.
## Clavier (touches physiques, valables en AZERTY et QWERTY) :
##   ↑ / Z : avancer   ↓ / S : reculer   Q / D : pas de côté   ← / A : tourner à gauche   → / E : tourner à droite

var level_index: int = 0
var grid: DungeonGrid
var level_node: Node3D
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
	rig.blocked.connect(func(x, y): print("Bloqué par '%s' en (%d,%d)" % [grid.cell(x, y), x, y]))

	var ui := CanvasLayer.new()
	add_child(ui)
	var pad := TouchControls.new()
	pad.command.connect(_on_command)
	ui.add_child(pad)

	load_level(level_index)

func load_level(index: int) -> void:
	var level: Dictionary = Data.config.levels[index]
	if level_node:
		level_node.queue_free()
	grid = DungeonGrid.new(level.mapRows)
	level_node = LevelBuilder.build(level, grid)
	add_child(level_node)
	rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
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
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	for action in ["forward", "back", "left", "right", "turn_left", "turn_right"]:
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
