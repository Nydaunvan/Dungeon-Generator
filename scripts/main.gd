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
	var resume := not Data.pending_save.is_empty()
	if resume:
		gs = GameState.from_save(cfg, Saves.normalize(Data.pending_save))
		level_index = clampi(gs.level_index, 0, (cfg.levels as Array).size() - 1)
		Data.pending_save = {}
	else:
		gs = GameState.create(cfg)
	for c in gs.party:
		print("%s -> PV %d, ATK %d-%d, vitesse %d" % [c.name, c.maxHp, c.atkMin, c.atkMax, c.effSpeed])

	_setup_input()
	_setup_environment()
	rig = PlayerRig.new()
	rig.blocked.connect(_on_blocked)
	rig.moved.connect(_on_moved)
	rig.extra_block = func(x, y): return (ctrl != null and not ctrl.monster_at(x, y).is_empty()) or (inter != null and inter.blocks_cell(x, y))

	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.setup(gs, rig)
	ctrl.popup.connect(_show_popup)
	ctrl.game_over.connect(_on_game_over)
	ctrl.combat_won.connect(_show_combat_summary)
	ctrl.fx.connect(_on_fx)

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
	wand.paused_if = func(): return not get_tree().get_nodes_in_group("modal").is_empty() or dock.visible
	inter.wand = wand
	inter.message.connect(func(t): show_message(t))
	inter.bag_changed.connect(layout.bag.refresh)
	layout.item_pressed.connect(_on_bag_item)
	layout.card_pressed.connect(_on_card_pressed)
	layout.card_opened.connect(inter.open_sheet)
	_popup_layer = layout.popup_layer
	message_label = layout.message_label

	ctrl.changed.connect(_check_choices)
	ctrl.changed.connect(_update_music)
	load_level(level_index, resume)
	if resume:
		gs.add_log("📂 Partie chargée.")

func load_level(index: int, at_saved: bool = false) -> void:
	var level: Dictionary = gs.cfg.levels[index]
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
	else:
		rig.place(grid, int(level.get("startX", 1)), int(level.get("startY", 1)), int(level.get("startDir", 0)))
	ctrl.bind_level(level, grid, level_node)
	inter.bind_level(level, grid, level_node)
	wand.bind_level(level, grid, level_node)
	for id in ls.get("opened_doors", {}):
		level_node.open_door(str(id), true)
	for it in level.get("items", []):
		if gs.item_state(str(level.id), str(it.id)).get("taken", false):
			level_node.entities.remove_item(str(it.id))
	_apply_outdoor(bool(level.get("outdoor", false)))
	if not bool(level.get("outdoor", false)):
		env.ambient_light_energy = float(level.get("lightAmbient", 1.1))
		rig.torch.light_energy = 2.0 * float(level.get("lightTorch", 1.4)) / 1.4
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
		match event.physical_keycode:
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
					var slot: int = event.physical_keycode - KEY_1
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
				if get_tree().get_nodes_in_group("modal").is_empty():
					Dialogs.confirm(_modals(), "🏃 Fuir le combat ?", "Le groupe s'enfuit vers un endroit proche, hors de vue du monstre. Chacun perd la moitié de son endurance actuelle.",
						ctrl.do_flee, "Fuir", "Rester")
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
	Sound.sfx("footstep")
	inter.on_step()
	layout.minimap.mark_visited()
	layout.minimap.reveal()
	ctrl.step_tick()
	ctrl.refresh()

func _on_blocked(x: int, y: int) -> void:
	var mon := ctrl.monster_at(x, y)
	if not mon.is_empty():
		ctrl.refresh()   # engage le combat
		return
	if inter.bump_village(x, y):
		Sound.sfx("blocked")
		return
	if grid.cell(x, y) == "#":
		Sound.sfx("blocked")
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
	Sound.sfx("stairs", str(action.get("type", "")) == "villageReturn")
	match str(action.get("type", "")):
		"level":
			var levels: Array = gs.cfg.levels
			for i in levels.size():
				if levels[i].id == action.get("targetId"):
					_transition_regen(levels[i])
					load_level(i)
					_prompt_save_on_level(levels[i])
					return
			show_message("Niveau introuvable : %s" % action.get("targetId"))
		"victory":
			gs.won = true
			gs.stats["dungeonsCompleted"] = int(gs.stats.get("dungeonsCompleted", 0)) + 1
			_show_victory()
		"villageExit":
			Dialogs.confirm(_modals(), "🏘️ Sortie du village", "Voulez-vous rester au village, ou repartir affronter un donjon plus puissant ?",
				_continue_next, "⚔️ Aller vers un donjon plus puissant", "Rester au village")
		"villageReturn":
			if gs.village_prev.is_empty():
				gs.add_log("🚪 Il n'y a nulle part où revenir pour l'instant.")
				show_message("Nulle part où revenir")
			else:
				Dialogs.confirm(_modals(), "⬅️ Retour au donjon", "Voulez-vous revenir au donjon que vous veniez de quitter ?",
					_return_to_dungeon, "⬅️ Revenir au donjon précédent", "Rester au village")
		_:
			show_message("Escalier")

## Premier passage dans un niveau : le groupe reprend son souffle (PV et endurance en pourcentage du maximum).
func _transition_regen(target: Dictionary) -> void:
	var tls := gs.level_state(target)
	if tls.get("transitionRegenDone", false):
		return
	tls["transitionRegenDone"] = true
	var sta: Dictionary = gs.cfg.get("staminaSettings", {})
	var hp_pct := int(sta.get("levelTransitionHpPct", 0))
	var st_pct := int(sta.get("levelTransitionStaPct", 0))
	if hp_pct <= 0 and st_pct <= 0:
		return
	for c in gs.alive_party():
		if hp_pct > 0:
			c["hp"] = mini(int(c.maxHp), int(c.hp) + int(round(int(c.maxHp) * hp_pct / 100.0)))
		if st_pct > 0:
			c["stamina"] = mini(int(c.get("maxStamina", 100)), int(c.get("stamina", 0)) + int(round(int(c.get("maxStamina", 100)) * st_pct / 100.0)))
	gs.add_log("💤 Le groupe reprend son souffle en chemin : un peu de PV et d'endurance récupérés.")

## Première arrivée dans un niveau : proposition de sauvegarde.
func _prompt_save_on_level(target: Dictionary) -> void:
	var tls := gs.level_state(target)
	if tls.get("stairsPromptShown", false):
		return
	tls["stairsPromptShown"] = true
	Dialogs.confirm(_modals(), "🚪 Nouveau niveau du donjon", "C'est le bon moment pour sauvegarder votre progression.",
		func(): SlotsModal.open(_modals(), snapshot, Data.launch_save), "💾 Sauvegarder maintenant", "Continuer sans sauvegarder")

func _on_menu(name: String) -> void:
	match name:
		"Accueil":
			Dialogs.confirm(_modals(), "Retour à l'accueil", "Quitter la partie en cours ? La progression non sauvegardée sera perdue.",
				Data.go_home, "Quitter")
		"Guide": Dialogs.guide(_modals())
		"Son": SoundModal.open(_modals())
		"Carte": _toggle_map()
		"Journal":
			var lm := Modal.open(_modals(), "📜 Historique du journal", 640.0)
			if gs.log_lines.is_empty():
				lm.add_text("Rien à afficher pour le moment.", UiTheme.DIM, 14)
			for line in gs.log_lines:
				lm.add_text(_strip_tags(str(line)), UiTheme.PARCH, 13)
			lm.set_buttons([{"text": "Fermer", "cb": func(): lm.close()}])
		"Stats": StatsModal.open(_modals(), gs)
		"Admin":
			Data.resume_game = snapshot()
			Sound.stop_ambient()
			Data.open_admin()
		"Sauvegarder": SlotsModal.open(_modals(), snapshot, Data.launch_save)
		"Charger": SlotsModal.open(_modals(), Callable(), Data.launch_save)
		_: show_message("« %s » : à venir" % name)

## Instantané de la partie pour une sauvegarde.
func snapshot() -> Dictionary:
	gs.level_index = level_index
	gs.px = rig.gx
	gs.py = rig.gy
	gs.pdir = rig.dir
	return {"config": gs.cfg, "save": gs.to_save(), "origin": Data.play_origin}

func _modals() -> Node:
	return _modal_layer

func _restart() -> void:
	Data.launch(Data.active(), Data.play_origin)

static func _strip_tags(s: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]+>|\\[/?[a-z_]+[^\\]]*\\]")
	return re.sub(s, "", true)

func _on_fx(type: String) -> void:
	layout.fx_layer.play(type)
	if type == "hit" or type == "trap":
		_shake()

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
	var m := Modal.open(_modals(), "⚔️ Victoire !", 420.0)
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
	m.set_buttons([{"text": "Continuer", "cb": func(): m.close()}])

func _on_game_over() -> void:
	show_message("☠️ Toute l'équipe a péri…", 4.0)
	await get_tree().create_timer(1.6).timeout
	Dialogs.defeat(_modals(), gs, _restart, Data.go_home)

func _show_victory() -> void:
	Sound.sfx("victory")
	show_message("Victoire !", 3.0)
	await get_tree().create_timer(0.8).timeout
	var maxed := gs.party.all(func(c): return int(c.level) >= Characters.MAX_LEVEL)
	var random_run := Data.play_origin == "random" and not maxed
	Dialogs.victory(_modals(), gs, _restart, Data.go_home,
		_continue_next if random_run else Callable(), _enter_village if random_run else Callable())

# ------------------------------------------------------------------ village et expéditions successives

func _enter_village() -> void:
	if not gs.in_village:
		gs.village_prev = {"levels": gs.cfg.levels, "level_index": level_index, "x": rig.gx, "y": rig.gy, "dir": rig.dir}
	gs.cfg["levels"] = [Village.build_level()]
	gs.in_village = true
	gs.won = false
	gs.game_over = false
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
		boss = bool(eng.monster.get("isBoss", false))
	if combat and not _was_combat:
		Sound.sfx("combat_start")
	_was_combat = combat
	Sound.ambient(theme, boss)

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
