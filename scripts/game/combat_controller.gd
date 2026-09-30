class_name CombatController
extends Node
## Fait le lien entre le moteur de combat (Combat) et le jeu : délais entre les tours,
## chronomètre de tour, mort des monstres à l'écran, portes ouvertes par les monstres vaincus.

signal changed
signal popup(text: String, color: Color)
signal game_over

const MONSTER_DELAY := 0.85

var gs: GameState
var combat: Combat
var rig: PlayerRig
var view: LevelView
var _busy: bool = false
var _turn_elapsed: float = 0.0

func setup(state: GameState, r: PlayerRig) -> void:
	gs = state
	rig = r

func bind_level(level: Dictionary, grid: DungeonGrid, v: LevelView) -> void:
	view = v
	combat = Combat.new(gs, level, grid)
	sync_position()
	# retire de l'écran ce qui a déjà été vaincu ou ramassé
	var ls := combat.lstate()
	for m in level.get("monsters", []):
		var st: Dictionary = ls.monsters.get(str(m.id), {})
		if not st.is_empty() and not st.alive:
			view.entities.remove_monster(str(m.id))
	for id in ls.taken_items:
		view.entities.remove_item(str(id))
	changed.emit()

func sync_position() -> void:
	combat.pos = Vector2i(rig.gx, rig.gy)
	combat.dir = rig.dir

func in_combat() -> bool:
	return combat != null and combat.in_combat()

func monster_at(x: int, y: int) -> Dictionary:
	return combat.monster_at(x, y) if combat != null else {}

## À appeler après chaque déplacement du joueur.
func refresh() -> void:
	sync_position()
	if not in_combat():
		combat.gauges.clear()
		changed.emit()
		return
	# se tourner vers l'adversaire s'il n'est pas en face
	var eng := combat.engaged()
	if int(eng.dir) != rig.dir:
		rig.face(int(eng.dir))
		sync_position()
	_run_turns()

## À chaque pas hors combat, les statuts des personnages avancent d'un tour (poison, brûlure…).
func step_tick() -> void:
	if combat == null or gs.game_over:
		return
	sync_position()
	if in_combat():
		return
	for c in gs.party:
		combat.tick_char(c)
	_drain()
	changed.emit()

func attack() -> void:
	if combat == null or _busy:
		return
	sync_position()
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	if combat.player_attack(c):
		_after_action()
	else:
		changed.emit()

## Sort en attente d'une cible alliée (clic sur une carte de personnage).
var pending_spell: String = ""

func cast(spell_id: String, ally_id: String = "") -> void:
	if combat == null or _busy or gs.game_over:
		return
	sync_position()
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	var spell := combat.spell_def(spell_id)
	if spell.is_empty():
		return
	if combat.spell_needs_ally(spell) and ally_id == "":
		pending_spell = spell_id
		gs.add_log("👆 Choisissez l'allié à cibler pour %s." % spell.name)
		changed.emit()
		return
	pending_spell = ""
	if combat.cast_spell(c, spell_id, ally_id):
		_after_action()
	else:
		changed.emit()

## Lit un parchemin de la besace (sort gratuit, usage unique). Le lecteur est aussi la cible des sorts alliés.
func read_scroll(char_id: String, inv_idx: int) -> void:
	if combat == null or _busy or gs.game_over:
		return
	if inv_idx < 0 or inv_idx >= gs.inventory.size():
		return
	var it: Dictionary = gs.inventory[inv_idx]
	var c := gs.char_by_id(char_id)
	if c.is_empty() or int(c.hp) <= 0 or str(it.get("type", "")) != "scroll":
		return
	sync_position()
	var spell := combat.spell_def(str(it.get("spellId", "")))
	if spell.is_empty():
		gs.add_log("📜 %s est illisible, son contenu s'est effacé..." % it.get("name", "le parchemin"))
		changed.emit()
		return
	gs.active_char_id = char_id
	gs.add_log("📜 %s lit le parchemin et invoque %s %s !" % [c.name, spell.get("icon", ""), spell.name], true)
	if combat.cast_spell(c, str(spell.id), char_id, true):
		gs.inventory.remove_at(inv_idx)
		_after_action()
	else:
		changed.emit()

## Un potion a été bue : les soins comptent dans la contribution au combat.
func potion_drunk(char_id: String, healed: int) -> void:
	gs.stats["potionsUsed"] = int(gs.stats.get("potionsUsed", 0)) + 1
	if combat != null and healed > 0:
		Sound.sfx("heal")
		var c := gs.char_by_id(char_id)
		if not c.is_empty():
			combat._credit_heal(c, healed)
	changed.emit()

## Clic sur la carte d'un personnage : cible du sort en attente, sinon sélection du personnage actif (hors combat).
func card_pressed(char_id: String) -> void:
	if pending_spell != "":
		cast(pending_spell, char_id)
	elif not in_combat():
		gs.active_char_id = char_id
		changed.emit()

func flee() -> void:
	if not in_combat() or _busy:
		return
	sync_position()
	var dest := combat.flee()
	if dest.x >= 0:
		rig.teleport(dest)
	sync_position()
	_drain()
	changed.emit()

func skip_active_turn(reason: String) -> void:
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	gs.add_log(reason % c.name, true)
	combat.skip_turn(c)
	_after_action()

func _after_action() -> void:
	_drain()
	_turn_elapsed = 0.0
	changed.emit()
	if in_combat():
		_run_turns()

func _run_turns() -> void:
	if _busy:
		return
	_busy = true
	while in_combat():
		var r := combat.advance()
		_drain()
		if r.kind != "monster":
			break
		changed.emit()
		await get_tree().create_timer(MONSTER_DELAY).timeout
		if not in_combat():
			break
		combat.monster_act(str(r.key))
		_drain()
		changed.emit()
	_busy = false
	_turn_elapsed = 0.0
	changed.emit()

func _drain() -> void:
	var evs := combat.events.duplicate()
	combat.events.clear()
	for e in evs:
		match str(e.type):
			"popup":
				popup.emit(str(e.text), e.color)
			"monster_died":
				view.entities.remove_monster(str(e.id))
			"door_open":
				combat.lstate().get_or_add("opened_doors", {})[str(e.id)] = true
				view.open_door(str(e.id))
			"game_over":
				game_over.emit()

## Part (0..1) du temps de réflexion restant pour le personnage dont c'est le tour.
func turn_timer_fraction() -> float:
	if not _timer_enabled() or not in_combat() or _busy:
		return -1.0
	return clampf(1.0 - _turn_elapsed / _timer_seconds(), 0.0, 1.0)

func _timer_enabled() -> bool:
	return bool(gs.cfg.get("turnTimerEnabled", true))

func _timer_seconds() -> float:
	return clampf(float(gs.cfg.get("turnTimerSeconds", 5)), 3.0, 10.0)

func _process(delta: float) -> void:
	if combat == null or _busy or gs.game_over or not _timer_enabled() or not in_combat():
		return
	if not get_tree().get_nodes_in_group("modal").is_empty():
		return   # fenêtre ouverte : le chronomètre de tour est en pause
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty() or float(combat.gauges.get("char_" + str(c.id), 0.0)) < 100.0:
		return
	_turn_elapsed += delta
	if _turn_elapsed >= _timer_seconds():
		skip_active_turn("⏳ %s n'a pas agi à temps et laisse passer son tour.")
