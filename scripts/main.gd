extends Node3D
## Scène principale : couloir 3D, équipe, combat au tour par tour.
## Clavier :
##   ↑/Z/W avancer · ↓/S reculer · ←/Q/A et →/D tourner (touches logiques : AZERTY et QWERTY sans réglage)
##   X ou Espace : attaquer (ou interagir s'il n'y a rien à frapper) · F/Entrée : interagir · C : fuir

var level_index: int = 0
var level: Dictionary = {}
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

func _exit_tree() -> void:
	Data.game_scale_mode = false

func _ready() -> void:
	Data.game_scale_mode = true
	var cfg: Dictionary = Data.active()
	print("Donjon : ", cfg.get("title", "?"))
	var resume := not Data.pending_save.is_empty()
	# Pendant la construction (répartie sur plusieurs images derrière l'écran de chargement), la scène reste figée.
	process_mode = Node.PROCESS_MODE_DISABLED
	await Loader.step(0.08, L.t("loading.etape_sauvegarde") if resume else L.t("loading.etape_equipe_nouvelle"))
	var pend_log := Data.pending_log
	var pend_transient := Data.pending_transient
	if resume:
		var sv: Dictionary = Saves.normalize(Data.pending_save)
		Saves.migrate_save(sv, cfg)
		gs = GameState.from_save(cfg, sv)
		level_index = clampi(gs.level_index, 0, (cfg.levels as Array).size() - 1)
		Data.pending_save = {}
		Data.pending_log = ""
		Data.pending_transient = {}
	else:
		gs = GameState.create(cfg)
		if (cfg.levels as Array).size() > 0:
			gs.level_state(cfg.levels[0])["stairsPromptShown"] = true
	for c in gs.party:
		print("%s -> PV %d, ATK %d-%d, vitesse %d" % [c.name, c.maxHp, c.atkMin, c.atkMax, c.effSpeed])

	await Loader.step(0.2, L.t("loading.etape_equipe"))
	_setup_environment()
	rig = PlayerRig.new()
	rig.blocked.connect(_on_blocked)
	rig.moved.connect(_on_moved)
	rig.turned.connect(_on_turned)
	rig.extra_block = func(x, y): return (ctrl != null and not ctrl.monster_at(x, y).is_empty()) or (inter != null and inter.blocks_cell(x, y))

	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.setup(gs, rig)
	ctrl.popup.connect(_show_popup)
	ctrl.game_over.connect(_on_game_over)
	ctrl.combat_won.connect(_show_combat_summary)
	ctrl.fx.connect(_on_fx)
	ctrl.fx3d.connect(_on_fx3d)

	await Loader.step(0.32, L.t("loading.etape_interface"))
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
	layout.monster_pressed.connect(func(d, s): MonsterInfoModal.open(_modals(), d, s))
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
	wand.paused_if = is_game_paused
	inter.wand = wand
	inter.message.connect(func(t): show_message(t))
	inter.bag_changed.connect(layout.bag.refresh)
	layout.item_pressed.connect(_on_bag_item)
	layout.potion_quick.connect(func(i): inter.use_potion_at(gs.active_char_id, i))
	layout.scrolls_quick.connect(func(): inter.open_scroll_picker(gs.active_char_id))
	layout.card_pressed.connect(_on_card_pressed)
	layout.chest_pressed.connect(_on_chest_pressed)
	layout.card_opened.connect(inter.open_sheet)
	_popup_layer = layout.popup_layer
	message_label = layout.message_label

	ctrl.changed.connect(_check_choices)
	ctrl.changed.connect(_update_music)
	ctrl.changed.connect(_sync_stage)
	layout.stage.gui_input.connect(_on_stage_input)
	await Loader.step(0.55, L.t("loading.etape_donjon"))
	load_level(level_index, resume)
	await Loader.step(0.92, L.t("loading.etape_reprise") if resume else "")
	if resume:
		if not pend_transient.is_empty():
			_restore_transient(pend_transient)
		if pend_log != "":
			gs.add_log(pend_log)
		if ctrl.in_combat():
			ctrl.refresh.call_deferred()    # reprise au milieu d'un combat (retour de l'administration)
	process_mode = Node.PROCESS_MODE_INHERIT
	Loader.finish()

## Champs non sauvegardés de la partie suspendue (jauges de combat, ordre des tours, membre visé) : rétablis à la reprise
## depuis l'administration, comme le STATE unique de l'original qui ne les perdait pas.
func _transient() -> Dictionary:
	var g: Dictionary = {}
	var seq := 0
	if ctrl != null and ctrl.combat != null:
		g = ctrl.combat.gauges.duplicate()
		seq = ctrl.combat.turn_seq
	return {"gauges": g, "turn_seq": seq, "selected_member": gs.selected_member.duplicate(), "level_id": str(level.get("id", ""))}

func _restore_transient(tr: Dictionary) -> void:
	gs.selected_member = (tr.get("selected_member", {}) as Dictionary).duplicate()
	if ctrl.combat != null and str(tr.get("level_id", "")) == str(level.get("id", "")):
		ctrl.combat.turn_seq = int(tr.get("turn_seq", 0))
		var g: Dictionary = tr.get("gauges", {})
		for k in g:
			ctrl.combat.gauges[k] = float(g[k])
		ctrl.combat.ensure_gauges()

## Case d'arrivée d'un escalier (resolveStairs de l'original) : coordonnées de l'action si elles existent, sinon départ du niveau ;
## jamais dans un mur ni sur un escalier (on se décale sur une case voisine) et on ne regarde jamais un mur / un escalier.
func _arrival(target: Dictionary, action: Dictionary) -> Dictionary:
	var g := DungeonGrid.new(target)
	var has := func(k: String) -> bool:
		return action.has(k) and action[k] != null and str(action[k]) != ""
	var x: int = int(action.targetX) if has.call("targetX") else int(target.get("startX", 1))
	var y: int = int(action.targetY) if has.call("targetY") else int(target.get("startY", 1))
	var d: int = int(action.targetDir) if has.call("targetDir") else int(target.get("startDir", 0))
	var ch := func(cx: int, cy: int) -> String:
		return g.cell(cx, cy) if (cx >= 0 and cy >= 0 and cx < g.width and cy < g.height) else "#"
	if ch.call(x, y) == "S" or ch.call(x, y) == "#":
		for o in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var c: String = ch.call(x + o.x, y + o.y)
			if c != "S" and c != "#":
				x += o.x
				y += o.y
				break
	var blocked := func(dd: int) -> bool:
		var v: Vector2i = DungeonGrid.DIRS[dd]
		var c: String = ch.call(x + v.x, y + v.y)
		return c == "#" or c == "S"
	if d < 0 or d > 3 or blocked.call(d):
		for dd in 4:
			if not blocked.call(dd):
				d = dd
				break
	return {"x": x, "y": y, "dir": d}

func load_level(index: int, at_saved: bool = false, arrival: Dictionary = {}) -> void:
	level = gs.cfg.levels[index]
	if level_node:
		level_node.queue_free()
	level_index = index
	grid = DungeonGrid.new(level)
	# portes déjà ouvertes lors d'un précédent passage
	var ls := gs.level_state(level)
	level_node = LevelBuilder.build(level, grid)
	layout.world.add_child(level_node)
	if at_saved:
		rig.place(grid, gs.px, gs.py, gs.pdir)
	elif not arrival.is_empty():
		rig.place(grid, int(arrival.x), int(arrival.y), int(arrival.dir))
	else:
		rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
	ctrl.bind_level(level, grid, level_node)
	inter.bind_level(level, grid, level_node)
	wand.bind_level(level, grid, level_node)
	for id in ls.get("opened_doors", {}):
		level_node.open_door(str(id), true)
	for it in level.get("items", []):
		var ist := gs.item_state(str(level.id), str(it.id))
		if ist.get("taken", false) or ist.get("disarmed", false):
			level_node.entities.remove_item(str(it.id))
		elif bool(it.get("startHidden", false)) and not ist.get("hidden", true):
			level_node.entities.set_item_visible(str(it.id), true)
	var lvl_id := str(level.id)
	level_node.entities.fountain_ready = func(fid: String) -> bool:
		var fst := gs.item_state(lvl_id, fid)
		if not fst.has("usedAt"):
			return true
		var cd := maxf(5.0, float(gs.cfg.get("fountainCooldownMinutes", 10))) * 60000.0
		return Time.get_unix_time_from_system() * 1000.0 >= float(fst.usedAt) + cd
	level_node.entities.refresh_fountains(true)
	for m in level.get("monsters", []):
		var mst: Dictionary = ls.monsters.get(str(m.id), {})
		if bool(m.get("startHidden", false)) and not mst.is_empty() and not mst.get("hidden", true):
			level_node.entities.set_monster_visible(str(m.id), true)
	_apply_outdoor(bool(level.get("outdoor", false)))
	if not bool(level.get("outdoor", false)):
		env.ambient_light_energy = float(level.get("lightAmbient", 1.1))
		rig.torch.light_energy = 2.0 * float(level.get("lightTorch", 1.4)) / 1.4
		level_node.torches.light_scale = float(level.get("lightTorch", 1.4)) / 1.4
	layout.set_level_name(str(level.name))
	layout.minimap.bind(grid, rig, gs)
	layout.minimap.merchant_cell = func():
		var mm := wand.merchant()
		return Vector2i(int(mm.x), int(mm.y)) if (not mm.is_empty() and mm.discovered) else Vector2i(-1, -1)
	if not wand.merchant_moved.is_connected(layout.minimap.queue_redraw):
		wand.merchant_moved.connect(layout.minimap.queue_redraw)
		wand.monsters_moved.connect(layout.minimap.queue_redraw)
		ctrl.changed.connect(layout.minimap.queue_redraw)
	show_message(str(level.name))
	_update_music()
	_sync_stage()

## Salle de combat scellée : active pendant un combat (monstre ou groupe entier visible), sinon le couloir normal.
func _sync_stage() -> void:
	if level_node == null or level_node.stage == null or ctrl == null or ctrl.combat == null:
		return
	var stage := level_node.stage
	stage.camera = rig.camera
	if not ctrl.in_combat():
		stage.exit()
		return
	if not ctrl.model_in_combat():
		return       # dernier coup en cours d'affichage : la scène reste telle quelle jusqu'à la fin de l'effet
	var eng := ctrl.combat.engaged()
	var def: Dictionary = eng.monster
	var mst: Dictionary = ctrl.combat.lstate().monsters[str(def.id)]
	var sel := -1
	if bool(def.get("isGroup", false)) and mst.has("members"):
		sel = gs.selected_member_idx(str(def.id), mst)
	stage.enter(str(level.get("theme", "stone")), Vector2i(rig.gx, rig.gy), int(eng.dir), def, mst, sel)

## Clic sur un monstre du groupe pendant le combat : il devient la cible.
func _on_stage_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	if level_node == null or level_node.stage == null or not level_node.stage.active:
		return
	var idx := level_node.stage.pick(ev.position)
	if idx < 0:
		return
	var eng_now := ctrl.combat.engaged()
	if eng_now.is_empty():
		return
	var def: Dictionary = eng_now.monster
	gs.selected_member[str(def.id)] = idx
	ctrl.changed.emit()

## Ciel, brouillard clair et pas de torche dans le village ; ténèbres dans les donjons.
func _apply_outdoor(outdoor: bool) -> void:
	env.background_color = Outdoor.SKY if outdoor else Color("030201")
	env.fog_light_color = Outdoor.SKY if outdoor else Color("030201")
	env.fog_density = 0.012 if outdoor else 0.035
	env.ambient_light_color = Color("d8e4f0") if outdoor else Color("40342a")
	env.ambient_light_energy = 1.5 if outdoor else 1.1
	rig.torch.visible = not outdoor

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

## Carte plein écran (M) ; un second appui la referme.
func _toggle_map() -> void:
	for n in get_tree().get_nodes_in_group("modal"):
		if not n.is_queued_for_deletion():
			if n.has_meta("full_map"):
				n.close()
			return
	var mc := layout.minimap.merchant_cell
	var m := FullMapModal.open(_modals(), grid, rig, gs, mc)
	m.set_meta("full_map", true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var lk: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		var dk: Key = event.physical_keycode
		if dk >= KEY_1 and dk <= KEY_7:
			lk = dk
		match lk:
			KEY_M:
				_toggle_map()
				get_viewport().set_input_as_handled()
				return
			KEY_I:
				if get_tree().get_nodes_in_group("modal").is_empty():
					var who := gs.active_char_id
					if ctrl.in_combat():
						inter.open_sheet(who)
					else:
						dock.toggle_for(who)
				get_viewport().set_input_as_handled()
				return
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
				if get_tree().get_nodes_in_group("modal").is_empty() and ctrl.in_combat():
					var slot: int = int(lk) - int(KEY_1)
					if slot == 0:
						ctrl.attack()
					else:
						var c := gs.char_by_id(gs.active_char_id)
						var known: Array = c.get("spellsKnown", []) if not c.is_empty() else []
						if slot - 1 < known.size():
							ctrl.cast(str(known[slot - 1]))
				get_viewport().set_input_as_handled()
				return
	if not get_tree().get_nodes_in_group("modal").is_empty():
		return
	if event is InputEventKey and event.pressed:
		# Touches « logiques » (celles qui s'impriment sur la touche) : Z/Q/S/D sur AZERTY, W/A/S/D sur QWERTY, sans réglage.
		var k: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		var cmd := ""
		match k:
			KEY_UP, KEY_Z, KEY_W: cmd = "forward"
			KEY_DOWN, KEY_S: cmd = "back"
			KEY_LEFT, KEY_Q, KEY_A: cmd = "turn_left"
			KEY_RIGHT, KEY_D: cmd = "turn_right"
			KEY_SPACE, KEY_X: cmd = "attack"
			KEY_F, KEY_ENTER, KEY_KP_ENTER: cmd = "interact"
			KEY_C: cmd = "flee"
		if cmd != "" and (not event.echo or cmd in ["forward", "back", "turn_left", "turn_right"]):
			_on_command(cmd)
			get_viewport().set_input_as_handled()

## Équivalent de isGamePaused() de l'original : volet d'inventaire déployé ou fenêtre bloquante ouverte
## (piège, fontaine, marchand, sauvegarde, évolution, fiche…). Plus rien n'avance pendant ce temps.
func is_game_paused() -> bool:
	return (dock != null and dock.is_open) or not get_tree().get_nodes_in_group("modal").is_empty()

func _on_command(cmd: String) -> void:
	if gs.game_over:
		return
	if is_game_paused() and cmd in ["forward", "right", "back", "left", "turn_left", "turn_right"]:
		return
	match cmd:
		"forward", "right", "back", "left", "turn_left", "turn_right":
			if ctrl.in_combat():
				show_message(L.t("main.en_combat_attaquez_ou_fuyez"))
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
				if get_tree().get_nodes_in_group("modal").is_empty():
					Dialogs.confirm(_modals(), L.t("main.fuir_le_combat"), L.t("main.fuir_permet_echapper_immediatement"),
							ctrl.do_flee, L.t("main.flee_btn"), L.t("common.annuler"))
			else:
				show_message(L.t("main.personne_ne_vous_menace"))

## Case juste devant le joueur.
func _front() -> Vector2i:
	var v: Vector2i = DungeonGrid.DIRS[rig.dir]
	return Vector2i(rig.gx + v.x, rig.gy + v.y)

func _interact() -> void:
	var f := _front()
	var ch := grid.cell(f.x, f.y)
	if ch == "D":
		if grid.opened.has(str(grid.door_at(f.x, f.y).get("id", ""))):
			show_message(L.t("main.la_porte_est_deja_ouverte"))
		else:
			inter.try_door(f.x, f.y)
	elif ch == "S":
		_use_stairs(f)
	else:
		show_message(L.t("main.rien_a_faire_ici"))

## Clic sur une carte : cible d'un sort, fiche (en combat) ou volet d'équipement (hors combat).
func _on_card_pressed(id: String) -> void:
	ctrl.card_pressed(id)   # choisit le héros actif (ou la cible d'un sort) ; l'inventaire ne s'ouvre que par le coffre

## Icône coffre d'un portrait : inventaire du héros (hors combat) ; en combat, sa fiche de groupe.
func _on_chest_pressed(id: String) -> void:
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

func _on_turned() -> void:
	# Un simple quart de tour ne déclenche ni objet, ni tour de jeu (comme l'original).
	layout.minimap.reveal()
	ctrl.refresh()

func _on_moved() -> void:
	Sound.sfx("footstep")
	inter.step_stamina()
	layout.minimap.mark_visited()
	layout.minimap.reveal()
	ctrl.step_tick()
	inter.step_items()
	_refresh_when_free()
	ctrl.combat.end_turn_gain()

var _waiting_refresh: bool = false

## Un combat qui devait s'engager sur cette case attend la fin de la fenêtre ouverte (piège, fontaine, marchand…).
func _refresh_when_free() -> void:
	if get_tree().get_nodes_in_group("modal").is_empty():
		ctrl.refresh()
		return
	if _waiting_refresh:
		return
	_waiting_refresh = true
	while not get_tree().get_nodes_in_group("modal").is_empty():
		await get_tree().process_frame
	_waiting_refresh = false
	ctrl.refresh()

func _on_blocked(x: int, y: int) -> void:
	var mon := ctrl.monster_at(x, y)
	if not mon.is_empty():
		gs.add_log(L.fa(L.t("main.vous_barre_la_route"), str(mon.get("name", L.t("main.un_monstre")))))
		Sound.sfx("blocked")
		ctrl.refresh()   # engage le combat
		ctrl.combat.end_turn_gain()
		return
	if inter.bump_village(x, y):
		Sound.sfx("blocked")
		return
	if grid.cell(x, y) == "#":
		if inter.bump_fountain(x, y):
			return
		Sound.sfx("blocked")
		inter.bump_wall(x, y)
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
	var going_up := true
	if str(action.get("type", "")) == "level":
		for i in (gs.cfg.levels as Array).size():
			if gs.cfg.levels[i].id == action.get("targetId"):
				going_up = i <= gs.level_index
	Sound.sfx("stairs", going_up)
	StairsDust.pulse(layout.world, rig.camera, going_up)
	match str(action.get("type", "victory")) if not action.is_empty() else "victory":
		"level":
			var levels: Array = gs.cfg.levels
			for i in levels.size():
				if levels[i].id == action.get("targetId"):
					_transition_regen(levels[i])
					load_level(i, false, _arrival(levels[i], action))
					gs.add_log(L.fa(L.t("main.le_groupe_se_deplace_vers"), levels[i].get("name", "")))
					_prompt_save_on_level(levels[i])
					return
			gs.add_log(L.t("main.l_escalier_semble_mener_nulle"))
			_victory_by_stairs()
		"victory":
			gs.add_log(L.t("main.le_groupe_decouvre_l_escalier"))
			_victory_by_stairs()
		"villageExit":
			Dialogs.confirm(_modals(), L.t("main.sortie_du_village"), L.t("main.voulez_vous_rester_au_village"),
				_continue_next, L.t("main.aller_vers_un_donjon_plus"), L.t("main.rester_au_village"))
		"villageReturn":
			if gs.village_prev.is_empty():
				gs.add_log(L.t("main.il_n_y_a_nulle"))
				show_message(L.t("main.nulle_part_ou_revenir"))
			else:
				Dialogs.confirm(_modals(), L.t("main.retour_au_donjon"), L.t("main.voulez_vous_revenir_au_donjon"),
					_return_to_dungeon, L.t("main.revenir_au_donjon_precedent"), L.t("main.rester_au_village"))
		_:
			show_message(L.t("main.escalier"))

func _victory_by_stairs() -> void:
	var before := gs.inventory.size()
	gs.inventory = gs.inventory.filter(func(it): return str(it.get("type", "")) != "key")
	if gs.inventory.size() < before:
		gs.add_log(L.fa(L.t("main.cle_devenue_inutile_ont_ete"), (before - gs.inventory.size())))
	gs.won = true
	gs.stats["dungeonsCompleted"] = int(gs.stats.get("dungeonsCompleted", 0)) + 1
	_show_victory()

## Premier passage dans un niveau : le groupe reprend son souffle (PV et endurance en pourcentage du maximum).
func _transition_regen(target: Dictionary) -> void:
	var tls := gs.level_state(target)
	if tls.get("transitionRegenDone", false):
		return
	tls["transitionRegenDone"] = true
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var hp_pct := int(sta.get("levelTransitionHpPct", 25))
	var st_pct := int(sta.get("levelTransitionStaPct", 35))
	if hp_pct <= 0 and st_pct <= 0:
		return
	for c in gs.alive_party():
		if hp_pct > 0:
			c["hp"] = mini(int(c.maxHp), int(c.hp) + int(round(int(c.maxHp) * hp_pct / 100.0)))
		if st_pct > 0:
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + int(round(int(c.get("maxStamina", 100)) * st_pct / 100.0)))
	gs.add_log(L.t("main.le_groupe_reprend_son_souffle"))

## Première arrivée dans un niveau : proposition de sauvegarde.
func _prompt_save_on_level(target: Dictionary) -> void:
	var tls := gs.level_state(target)
	if tls.get("stairsPromptShown", false):
		return
	tls["stairsPromptShown"] = true
	Dialogs.confirm(_modals(), L.t("main.nouveau_niveau_du_donjon"), L.t("main.c_est_le_bon_moment"),
		func(): SlotsModal.open(_modals(), snapshot, Data.launch_save, Callable(), _slot_opts()), L.t("main.save_now"), L.t("main.continue_without_saving"))

func _on_menu(name: String) -> void:
	match name:
		"Accueil": _leave_game()
		"Guide": Dialogs.guide(_modals())
		"Quitter": Dialogs.confirm(_modals(), "", L.t("ui.app_header.quitter_confirm"), func(): get_tree().quit(), L.t("ui.app_header.quitter"))
		"Son": SoundModal.open(_modals())
		"Lang":
			Sound.stop_ambient()
			Data.reload_game(snapshot())
		"Carte": _toggle_map()
		"Journal": _open_full_log()
		"Stats": StatsModal.open(_modals(), gs)
		"Admin":
			Data.resume_game = snapshot()
			Sound.stop_ambient()
			Data.open_admin()
		"Slots":
			if not ctrl.in_combat():
				SlotsModal.open(_modals(), snapshot, Data.launch_save, Callable(), _slot_opts())
		"Nouveau":
			Dialogs.confirm(_modals(), "", L.t("main.commencer_une_nouvelle_partie"), _restart)
		"Exporter":
			var snap := snapshot()
			Files.save_text(_modals(), Data.export_name(str(gs.cfg.get("title", "")), "_sauvegarde"), Saves.export_text(snap.config, snap.save, snap.origin))
		"Importer": Files.pick_text(_modals(), _import_text)
		"Sauvegarder": SlotsModal.open(_modals(), snapshot, Data.launch_save, Callable(), _slot_opts())
		"Charger": SlotsModal.open(_modals(), Callable(), Data.launch_save)
		_: show_message(L.fa(L.t("main.a_venir"), name))

## Options de la fenêtre des emplacements : journal, état du menu 💾, provenance de la partie en cours.
func _slot_opts() -> Dictionary:
	return {"log": func(t: String): gs.add_log(t), "status": layout.save_menu.set_status,
		"current_origin": "" if (gs.game_over or gs.won) else Data.play_origin}

## « ⬆ Importer » du menu 💾 : fichier de sauvegarde ou de configuration (`importSaveFile`).
func _import_text(text: String) -> void:
	if not Saves.is_valid_json(text):
		Form.alert(_modals(), L.t("common.ce_fichier_n_est_pas"))
		return
	if not Data.launch_import(Saves.parse_import(text)):
		Form.alert(_modals(), L.t("common.ce_fichier_ne_contient_pas"))

## « 📖 Grimoire complet de l'aventure » (`openFullLogModal`) : tout le journal, séparateurs d'expédition compris.
func _open_full_log() -> void:
	var lm := Modal.open_framed(_modals(), L.t("main.grimoire_complet_de_l_aventure"), 640.0)
	if gs.full_log.is_empty():
		lm.add_text(L.t("main.rien_a_afficher_pour_le"), UiTheme.DIM, 14, true)
	var first := true
	for e in gs.full_log:
		if str(e.get("type", "entry")) == "divider":
			var d := Label.new()
			d.text = "⚔️ " + L.u(str(e.get("text", "")))
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
			d.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.82)))
			d.add_theme_color_override("font_color", Color("ffd88a"))
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
			if not first:
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(0, UiMetrics.css(18.0))
				box.add_child(sp)
			box.add_child(d)
			var ln := ColorRect.new()
			ln.color = Color(0.66, 0.47, 0.23, 0.35)
			ln.custom_minimum_size = Vector2(0, 1)
			box.add_child(ln)
			lm.content.add_child(box)
		else:
			var l := Label.new()
			l.text = _strip_tags(str(e.get("text", "")))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size = Vector2(120, 0)
			l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
			var hit := bool(e.get("playerHit", false))
			l.add_theme_color_override("font_color", Color("ffb4b4") if hit else UiTheme.PARCH)
			if hit:
				l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
			lm.content.add_child(l)
		first = false
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(lm):
		var sc: ScrollContainer = lm._scroll
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)

## Bouton de fenêtre au style de `.modal-actions > button`.
func _modal_button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UiMetrics.css(40.0))
	var st := IronBox.modal_styles(primary)
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.9)))
	b.add_theme_color_override("font_color", Color("ffd88a") if primary else Color("e2d2b0"))
	b.pressed.connect(cb)
	return b

## « Quitter la partie en cours » (leaveGameOverlay de l'original).
func _leave_game() -> void:
	if gs.game_over or gs.won:
		Data.go_home()
		return
	var m := Modal.open(_modals(), L.t("common.quitter_la_partie_en_cours"), 440.0)
	m.add_text(L.t("common.voulez_vous_sauvegarder_votre"), UiTheme.PARCH, 14, true)
	var origin: String = Data.play_origin
	if origin == "custom":
		m.add_text(L.t("main.cette_creation_repartira_une"), UiTheme.PARCH, 14, true)
	var btns: Array = [
		{"text": L.t("common.sauvegarder_et_quitter"), "primary": true, "cb": func():
			m.close()
			SlotsModal.open(_modals(), snapshot, Data.launch_save, func(_i): Data.go_home(), _slot_opts())},
	]
	if origin != "original":
		btns.append({"text": L.t("common.exporter_le_donjon_fichier_json"), "primary": false, "cb": func():
			m.close()
			var snap := snapshot()
			Files.save_text(_modals(), Data.export_name(str(gs.cfg.get("title", "")), "_sauvegarde"), Saves.export_text(snap.config, snap.save, snap.origin), func(_t): Data.go_home())})
	btns.append({"text": L.t("common.quitter_sans_sauvegarder"), "primary": false, "cb": func():
		m.close()
		Data.go_home()})
	btns.append({"text": L.t("common.annuler_rester_dans_la_partie"), "primary": false, "cb": func(): m.close()})
	m.set_buttons(btns)
	if origin == "custom":
		# section « 📋 Générer un code à partager » (donjons personnalisés), entre l'export et « Quitter sans sauvegarder »
		var sec := VBoxContainer.new()
		var out: TextEdit = null
		var status: Label = null
		var gen := _modal_button(L.t("common.generer_un_code_a_partager"), func():
			Form.generate_code(gs.cfg, out, status))
		sec.add_child(gen)
		out = Form.code_area(sec, "", true, 70.0, 6.0)
		out.visible = false
		status = Form.status_label(sec)
		var row: Node = m._buttons_row
		row.add_child(sec)
		row.move_child(sec, 2 if origin != "original" else 1)

## Instantané de la partie pour une sauvegarde.
func snapshot() -> Dictionary:
	gs.level_index = level_index
	gs.px = rig.gx
	gs.py = rig.gy
	gs.pdir = rig.dir
	return {"config": gs.cfg, "save": gs.to_save(), "origin": Data.play_origin, "transient": _transient()}

func _modals() -> Node:
	return _modal_layer

func _restart() -> void:
	Data.launch(Data.active(), Data.play_origin, Data.ADMIN_KEEP)

static func _strip_tags(s: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]+>|\\[/?[a-z_]+[^\\]]*\\]")
	return re.sub(s, "", true)

func _on_fx(type: String) -> void:
	if SpellFxStyles.has_action(type):       # coups, piège, interrupteur, fontaine : effets 3D
		var st: CombatStage = level_node.stage if level_node != null else null
		SpellFxStyles.cast_action(layout.world, rig.camera, type, st.target_point() if st != null and st.active else {})
	else:
		layout.fx_layer.play(type)
	if type == "hit" or type == "trap":
		_shake()

func _on_fx3d(spell_id: String, ctx: Dictionary = {}) -> void:
	var st: CombatStage = level_node.stage if level_node != null else null
	var active: bool = st != null and st.active
	var tgt: Dictionary = st.target_point() if active else {}
	var c := ctx.duplicate()
	if not c.has("style"):       # appel hors combat (outils) : on retrouve style / mode dans la définition du sort
		for sp in gs.cfg.get("spells", []):
			if str(sp.get("id", "")) == spell_id:
				c["style"] = str(sp.get("style", "arcane"))
				c["mode"] = str(sp.get("mode", "damage"))
				c["status"] = str(sp.get("statusEffect", ""))
				break
	c["targets"] = st.target_points() if active else []
	SpellFxStyles.cast_spell(layout.world, rig.camera, spell_id, tgt, c)

func layout_stage_target() -> Dictionary:
	var st: CombatStage = level_node.stage if level_node != null else null
	return st.target_point() if st != null and st.active else {}

## Secousse de la caméra (impact subi).
func _shake() -> void:
	var cam := rig.camera
	var tw := create_tween()
	for i in 6:
		var amp := 0.06 * (1.0 - i / 6.0)
		tw.tween_property(cam, "h_offset", randf_range(-amp, amp), 0.05)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-amp, amp), 0.05)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)

## Bilan affiché à la fin d'un combat gagné.
func _show_combat_summary(s: Dictionary) -> void:
	if gs.won:
		return
	Sound.sfx("victory")
	var m := Modal.open(_modals(), L.t("main.victoire"), 420.0)
	var names: Array = []
	for n in s.order:
		var c := int(s.counts[n])
		names.append("%s ×%d" % [n, c] if c > 1 else str(n))
	m.add_text(", ".join(names), UiTheme.GOLD, 17)
	if int(s.xp) > 0:
		m.add_text("⭐ +%d XP" % int(s.xp), UiTheme.PARCH, 15)
	if int(s.gold) > 0:
		m.add_text("💰 +%d or" % int(s.gold), UiTheme.PARCH, 15)
	if not (s.loot as Array).is_empty():
		m.add_text("🎁 " + ", ".join(s.loot), UiTheme.PARCH, 15)
	var recap: Array = []
	for c in gs.party:
		recap.append("%s %d/%d" % [c.name, int(c.hp), int(c.maxHp)])
	m.add_text("❤️ " + " · ".join(recap), UiTheme.DIM, 13)
	m.set_buttons([{"text": L.t("common.continuer"), "cb": func(): m.close()}])

func _on_game_over() -> void:
	show_message(L.t("main.toute_l_equipe_a_peri"), 4.0)
	await get_tree().create_timer(1.6).timeout
	Dialogs.defeat(_modals(), gs, _restart, Data.go_home)

func _show_victory() -> void:
	Sound.sfx("victory")
	show_message(L.t("common.victoire"), 3.0)
	await get_tree().create_timer(0.8).timeout
	var maxed := gs.party.all(func(c): return int(c.level) >= Characters.MAX_LEVEL)
	var random_run := Data.play_origin == "random" and not maxed
	Dialogs.victory(_modals(), gs, _restart, Data.go_home,
		_continue_next if random_run else Callable(), _enter_village if random_run else Callable())

# ------------------------------------------------------------------ village et expéditions successives

func _enter_village() -> void:
	gs.level_index = level_index
	gs.px = rig.gx
	gs.py = rig.gy
	gs.pdir = rig.dir
	gs.enter_village()
	load_level(0)

func _return_to_dungeon() -> void:
	if gs.village_prev.is_empty():
		return
	var prev: Dictionary = gs.village_prev
	gs.cfg["levels"] = prev.levels
	gs.px = int(prev.x)
	gs.py = int(prev.y)
	gs.pdir = int(prev.dir)
	gs.in_village = false
	gs.village_prev = {}
	load_level(int(prev.level_index), true)

func _continue_next() -> void:
	var go := func(mods: Array):
		Village.next_dungeon(gs, mods)
		# séparateur « Expédition n°N — titre » du journal complet, juste avant la ligne d'annonce
		gs.full_log.insert(maxi(0, gs.full_log.size() - 1), {"type": "divider", "text": L.fa(L.t("common.expedition_n"), [gs.run_number, str(gs.cfg.get("title", ""))])})
		load_level(0)
	if gs.run_mods_chosen:
		go.call((gs.cfg.get("runModifierIds", []) as Array).duplicate())
	else:
		GeneratorDialog.pick_modifiers(_modals(), go)

## Présente les talents et évolutions en attente dès que le groupe n'est plus en combat.
func _check_choices() -> void:
	if gs.choice_queue.is_empty() or ctrl.in_combat() or gs.game_over:
		return
	TalentModals.process_queue.call_deferred(_modals(), gs, func():
		ctrl.changed.emit()
		layout.bag.refresh())

## Ambiance du thème du niveau ; musique de boss pendant un combat contre un boss.
var _was_combat := false

func _update_music() -> void:
	var lvl: Dictionary = gs.cfg.levels[level_index]
	var theme := "ruins" if bool(lvl.get("outdoor", false)) else str(lvl.get("theme", "stone"))
	var combat := ctrl.in_combat()
	var boss := false
	if combat:
		var eng := ctrl.combat.engaged()
		if not eng.is_empty():
			boss = bool(eng.monster.get("isBoss", false))
	if combat and not _was_combat:
		Sound.sfx("combat_start")
		_pulse_combat_enter()
	_was_combat = combat
	Sound.ambient(theme, boss)

## pulseCombatEnter de l'original : le champ de vision se resserre de 88° à 70° en 380 ms à l'entrée en combat.
func _pulse_combat_enter() -> void:
	if rig == null or rig.camera == null:
		return
	rig.camera.fov = 88.0
	var tw := create_tween()
	tw.tween_property(rig.camera, "fov", 70.0, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
