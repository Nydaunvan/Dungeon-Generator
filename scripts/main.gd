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
var layout: GameLayout
var inter: Interactions
var wand: Wanderers
var dock: EquipDock
var _we: WorldEnvironment
var message_label: Label
var _message_tween: Tween
var _popup_layer: Control
var _modal_layer: CanvasLayer

func _ready() -> void:
	var cfg: Dictionary = Data.active()
	print("Donjon : ", cfg.get("title", "?"))
	gs = GameState.create(cfg)
	for c in gs.party:
		print("%s -> PV %d, ATK %d-%d, vitesse %d" % [c.name, c.maxHp, c.atkMin, c.atkMax, c.effSpeed])

	_setup_input()
	_setup_environment()
	rig = PlayerRig.new()
	rig.blocked.connect(_on_blocked)
	rig.moved.connect(_on_moved)
	rig.extra_block = func(x, y): return ctrl != null and not ctrl.monster_at(x, y).is_empty()

	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.setup(gs, rig)
	ctrl.popup.connect(_show_popup)
	ctrl.game_over.connect(_on_game_over)

	var ui := CanvasLayer.new()
	add_child(ui)
	var bg := TextureRect.new()
	bg.texture = UiTheme.tex("bg_tile")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	layout = GameLayout.new()
	ui.add_child(layout)
	layout.setup(gs, ctrl, rig)
	layout.command.connect(_on_command)
	layout.menu_pressed.connect(_on_menu)
	# le monde 3D vit dans la vue encadrée
	layout.world.add_child(rig)
	rig.camera.current = true
	layout.world.add_child(_we)
	var dock_layer := CanvasLayer.new()
	dock_layer.layer = 15
	add_child(dock_layer)
	dock = EquipDock.new()
	dock_layer.add_child(dock)
	dock.setup(gs, ctrl)
	dock.bag_changed.connect(layout.bag.refresh)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)
	inter = Interactions.new()
	add_child(inter)
	inter.setup(gs, ctrl, rig, layout, _modal_layer)
	wand = Wanderers.new()
	add_child(wand)
	wand.setup(gs, ctrl, rig)
	wand.paused_if = func(): return not get_tree().get_nodes_in_group("modal").is_empty() or dock.visible
	inter.wand = wand
	inter.message.connect(func(t): show_message(t))
	inter.bag_changed.connect(layout.bag.refresh)
	layout.item_pressed.connect(_on_bag_item)
	layout.card_pressed.connect(_on_card_pressed)
	layout.card_opened.connect(inter.open_sheet)
	_popup_layer = layout.popup_layer
	message_label = layout.message_label

	load_level(level_index)

func load_level(index: int) -> void:
	var level: Dictionary = gs.cfg.levels[index]
	if level_node:
		level_node.queue_free()
	level_index = index
	grid = DungeonGrid.new(level)
	# portes déjà ouvertes lors d'un précédent passage
	var ls := gs.level_state(level)
	level_node = LevelBuilder.build(level, grid)
	layout.world.add_child(level_node)
	rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
	ctrl.bind_level(level, grid, level_node)
	inter.bind_level(level, grid, level_node)
	wand.bind_level(level, grid, level_node)
	for id in ls.get("opened_doors", {}):
		level_node.open_door(str(id), true)
	for it in level.get("items", []):
		if gs.item_state(str(level.id), str(it.id)).get("taken", false):
			level_node.entities.remove_item(str(it.id))
	layout.set_level_name(str(level.name))
	layout.minimap.bind(grid, rig)
	layout.minimap.merchant_cell = func():
		var mm := wand.merchant()
		return Vector2i(int(mm.x), int(mm.y)) if (not mm.is_empty() and mm.discovered) else Vector2i(-1, -1)
	if not wand.merchant_moved.is_connected(layout.minimap.queue_redraw):
		wand.merchant_moved.connect(layout.minimap.queue_redraw)
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
	_we = WorldEnvironment.new()
	_we.environment = env

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
	if not get_tree().get_nodes_in_group("modal").is_empty():
		return
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
		if grid.opened.has(str(grid.door_at(f.x, f.y).get("id", ""))):
			show_message("La porte est déjà ouverte")
		else:
			inter.try_door(f.x, f.y)
	elif ch == "S":
		_use_stairs(f)
	else:
		show_message("Rien à faire ici")

## Clic sur une carte : cible d'un sort, fiche (en combat) ou volet d'équipement (hors combat).
func _on_card_pressed(id: String) -> void:
	if ctrl.pending_spell != "":
		ctrl.card_pressed(id)
	elif ctrl.in_combat():
		inter.open_sheet(id)
	else:
		dock.toggle_for(id)

## Clic sur un objet de la besace : le volet d'équipement l'affiche ; en combat, menu rapide.
func _on_bag_item(idx: int) -> void:
	if idx < 0 or idx >= gs.inventory.size():
		return
	if ctrl.in_combat():
		inter.open_item_menu(idx)
		return
	var who := gs.active_char_id
	var c := gs.char_by_id(who)
	if c.is_empty() or int(c.hp) <= 0:
		var alive := gs.alive_party()
		if alive.is_empty():
			return
		who = str(alive[0].id)
	dock.open_for(who, gs.inventory[idx])

func _on_moved() -> void:
	inter.on_step()
	layout.minimap.reveal()
	ctrl.step_tick()
	ctrl.refresh()

func _on_blocked(x: int, y: int) -> void:
	var mon := ctrl.monster_at(x, y)
	if not mon.is_empty():
		ctrl.refresh()   # engage le combat
		return
	match grid.cell(x, y):
		"D": inter.try_door(x, y)
		"S": _use_stairs(Vector2i(x, y))

func _use_stairs(p: Vector2i) -> void:
	var st := grid.stairs_at(p.x, p.y)
	if st.is_empty():
		return
	if not inter.stairs_open(st):
		return
	var action: Dictionary = st.get("action", {})
	match str(action.get("type", "")):
		"level":
			var levels: Array = gs.cfg.levels
			for i in levels.size():
				if levels[i].id == action.get("targetId"):
					load_level(i)
					return
			show_message("Niveau introuvable : %s" % action.get("targetId"))
		"victory":
			gs.won = true
			_show_victory()
		_:
			show_message("Escalier")

func _on_menu(name: String) -> void:
	match name:
		"Accueil":
			Dialogs.confirm(_modals(), "Retour à l'accueil", "Quitter la partie en cours ? La progression non sauvegardée sera perdue.",
				Data.go_home, "Quitter")
		"Guide": Dialogs.guide(_modals())
		_: show_message("« %s » : à venir" % name)

func _modals() -> Node:
	return _modal_layer

func _restart() -> void:
	Data.launch(Data.active(), Data.play_origin)

func _on_game_over() -> void:
	show_message("☠️ Toute l'équipe a péri…", 4.0)
	await get_tree().create_timer(1.6).timeout
	Dialogs.defeat(_modals(), gs, _restart, Data.go_home)

func _show_victory() -> void:
	show_message("Victoire !", 3.0)
	await get_tree().create_timer(0.8).timeout
	Dialogs.victory(_modals(), gs, _restart, Data.go_home)

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
	var vp := _popup_layer.size
	lbl.position = Vector2(vp.x * 0.5 - 40 + randf_range(-30, 30), vp.y * 0.5)
	_popup_layer.add_child(lbl)
	var t := create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 70, 1.0)
	t.tween_property(lbl, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(lbl.queue_free)
