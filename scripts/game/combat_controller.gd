class_name CombatController
extends Node
## Fait le lien entre le moteur de combat (Combat) et le jeu : délais entre les tours,
## chronomètre de tour, mort des monstres à l'écran, portes ouvertes par les monstres vaincus.

signal changed
signal popup(text: String, color: Color)
signal game_over
signal combat_won(summary: Dictionary)
signal fx(type: String)
signal fx3d(spell_id: String, ctx: Dictionary)

const MONSTER_DELAY := 0.85

var gs: GameState
var combat: Combat
var rig: PlayerRig
var view: LevelView
var _busy: bool = false
var _turn_elapsed: float = 0.0
# --- porte de présentation : le combat ne s'affiche qu'une fois le reste terminé (piège, fenêtre, effet visuel),
# --- et ne se retire qu'une fois l'effet visuel du dernier coup terminé.
var _combat_live: bool = false     # le combat est « affiché » (la porte est franchie)
var _gate_pending: bool = false    # un combat attend que la porte s'ouvre
var _hold_until: int = 0           # petite respiration après la dernière fenêtre / le dernier effet
var _draining: bool = false

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

## Le jeu est « au repos » : ni animation de déplacement, ni tour de monstre, ni effet visuel, ni combat en attente d'affichage.
## Une partie classée n'accepte (et ne rejoue) une commande qu'à ce moment-là : l'ordre des événements est alors le même en direct et en rejeu.
func is_settled() -> bool:
	if combat == null or _busy or _draining or _gate_pending or rig.is_busy() or SpellFx3D.busy():
		return false
	if model_in_combat() and not _combat_live:
		return false
	return Time.get_ticks_msec() >= _hold_until

func sync_position() -> void:
	combat.pos = Vector2i(rig.gx, rig.gy)
	combat.dir = rig.dir

## Le moteur de combat est-il engagé ? (logique, sans délai de présentation)
func model_in_combat() -> bool:
	return combat != null and combat.in_combat()

## Fenêtres ouvertes ou effet visuel en cours : on laisse finir avant d'enchaîner.
func _gate_busy() -> bool:
	if SpellFx3D.busy() or not get_tree().get_nodes_in_group("modal").is_empty():
		_hold_until = Time.get_ticks_msec() + 350
		return true
	return Time.get_ticks_msec() < _hold_until

## Le combat est-il à l'écran ? Il apparaît quand piège / fenêtre / effet visuel sont terminés,
## et reste affiché jusqu'à la fin de l'effet visuel du dernier coup.
func in_combat() -> bool:
	if combat == null:
		return false
	if combat.in_combat():
		if _combat_live:
			return true
		if _gate_busy():
			_gate_pending = true
			return false
		_combat_live = true
		return true
	if _combat_live and (_draining or SpellFx3D.busy()):
		return true
	_combat_live = false
	return false

func monster_at(x: int, y: int) -> Dictionary:
	return combat.monster_at(x, y) if combat != null else {}

## À appeler après chaque déplacement du joueur.
func refresh() -> void:
	sync_position()
	if not model_in_combat():
		combat.gauges.clear()
		changed.emit()
		return
	if not _combat_live and _gate_busy():
		_gate_pending = true      # un piège, une fenêtre ou un effet est en cours : le combat se lancera ensuite
		changed.emit()
		return
	_combat_live = true
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
	if model_in_combat():
		return
	for c in gs.party:
		combat.tick_char(c)
	await _drain()
	changed.emit()

func attack() -> void:
	if combat == null or _busy:
		return
	if RunLog.ranked() and not RunLog.replaying and not is_settled():
		return
	sync_position()
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	RunLog.rec("atk")
	if combat.player_attack(c):
		_after_action()
	else:
		changed.emit()

## Sort en attente d'une cible alliée (clic sur une carte de personnage).
var pending_spell: String = ""

func cast(spell_id: String, ally_id: String = "") -> void:
	if combat == null or _busy or gs.game_over:
		return
	if RunLog.ranked() and not RunLog.replaying and not is_settled():
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
		gs.add_log(L.fa(L.t("game.combat_controller.choisissez_l_allie_a_cibler"), spell.name))
		changed.emit()
		return
	pending_spell = ""
	RunLog.rec("cast", spell_id, ally_id if ally_id != "" else null)
	if combat.cast_spell(c, spell_id, ally_id):
		_after_action()
	else:
		changed.emit()

## Lit un parchemin de la besace (sort gratuit, usage unique). Le lecteur est aussi la cible des sorts alliés.
func read_scroll(char_id: String, inv_idx: int) -> void:
	if combat == null or _busy or gs.game_over:
		return
	if RunLog.ranked() and not RunLog.replaying and not is_settled():
		return
	if inv_idx < 0 or inv_idx >= gs.inventory.size():
		return
	var it: Dictionary = gs.inventory[inv_idx]
	var c := gs.char_by_id(char_id)
	if c.is_empty() or int(c.hp) <= 0 or str(it.get("type", "")) != "scroll":
		return
	if Statuses.has(c, "freeze"):
		gs.add_log(L.fa(L.t("game.combat_controller.est_gele_impossible_de_lui"), c.name))
		changed.emit()
		return
	sync_position()
	var spell := combat.spell_def(str(it.get("spellId", "")))
	if spell.is_empty():
		gs.add_log(L.fa(L.t("game.combat_controller.est_illisible_son_contenu_est"), it.get("name", L.t("game.combat_controller.le_parchemin"))))
		changed.emit()
		return
	if int(c.get("stamina", 0)) < int(spell.get("staminaCost", 15)):
		gs.add_log(L.fa(L.t("game.combat_controller.n_a_plus_assez_endurance"), c.name))
		changed.emit()
		return
	RunLog.rec("scroll", char_id, inv_idx)
	gs.active_char_id = char_id
	gs.add_log(L.fa(L.t("game.combat_controller.lit_le_parchemin_et_invoque"), [c.name, spell.get("icon", ""), spell.name]), true)
	if combat.cast_spell(c, str(spell.id), char_id, true):
		gs.inventory.remove_at(inv_idx)
		_after_action()
	else:
		changed.emit()

## Un potion a été bue : les soins comptent dans la contribution au combat.
func potion_drunk(char_id: String, healed: int) -> void:
	if combat != null and healed > 0:
		Sound.sfx("heal")
		var c := gs.char_by_id(char_id)
		if not c.is_empty():
			combat._credit_heal(c, healed, false)
	changed.emit()

## Clic sur la carte d'un personnage : cible du sort en attente, sinon sélection du personnage actif (hors combat).
func card_pressed(char_id: String) -> void:
	if pending_spell != "":
		cast(pending_spell, char_id)
	elif not in_combat():
		select_char(char_id)
		changed.emit()

## Choisit le personnage actif (hors combat) : journalisé quand il change.
func select_char(char_id: String) -> void:
	if gs.active_char_id != char_id:
		RunLog.rec("sel", char_id)
		gs.active_char_id = char_id

func flee() -> void:
	if not model_in_combat() or _busy:
		return
	do_flee()

func do_flee() -> void:
	if not model_in_combat() or _busy:
		return
	if RunLog.ranked() and not RunLog.replaying and not is_settled():
		return
	sync_position()
	RunLog.rec("flee")
	var dest := combat.flee()
	if dest.x >= 0:
		rig.teleport(dest)
	sync_position()
	await _drain()
	changed.emit()

func skip_active_turn(reason: String) -> void:
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	if RunLog.ranked() and not RunLog.replaying and not is_settled():
		return
	RunLog.rec("skip")
	gs.add_log(reason % c.name, true)
	combat.skip_turn(c)
	_after_action()

func _after_action() -> void:
	var was_busy := _busy
	_busy = true            # pas d'autre action tant que l'effet visuel n'est pas terminé
	await _drain()
	_busy = was_busy
	_turn_elapsed = 0.0
	changed.emit()
	if model_in_combat():
		_run_turns()

func _run_turns() -> void:
	if _busy:
		return
	_busy = true
	while model_in_combat():
		var r := combat.advance()
		await _drain()
		if r.kind != "monster":
			break
		changed.emit()
		await get_tree().create_timer(MONSTER_DELAY).timeout
		if not model_in_combat():
			break
		combat.monster_act(str(r.key))
		await _drain()
		changed.emit()
	_busy = false
	_turn_elapsed = 0.0
	changed.emit()

const SUPPORT_MODES := ["healSingle", "healParty", "staminaRestoreSingle", "shieldSingle", "dispelSingle", "selfBuff", "partyUtility"]

func _drain() -> void:
	var evs := combat.events.duplicate()
	combat.events.clear()
	# 1) les effets visuels partent tout de suite
	var rest: Array = []
	for e in evs:
		match str(e.type):
			"fx":
				fx.emit(str(e.fx))
			"fx3d":
				fx3d.emit(str(e.spell), e.get("ctx", {}))
			_:
				rest.append(e)
	# Un sort de soutien (soin, endurance, bouclier, buff…) s'applique à l'instant : jauges et chiffres sans attendre l'effet visuel
	# (qui continue de jouer ; les autres actions attendent toujours sa fin).
	var support_only := false
	for e in evs:
		if str(e.type) == "fx3d":
			support_only = SUPPORT_MODES.has(str(e.get("ctx", {}).get("mode", "")))
			if not support_only:
				break
	if support_only:
		support_only = rest.all(func(r): return str(r.type) == "popup")
	if support_only:
		for e in rest:
			popup.emit(str(e.text), e.color)
		rest = []
		changed.emit()
	# 2) le reste (chiffres, mort d'un monstre, porte, fin de partie) attend la fin de l'effet visuel
	if SpellFx3D.busy():
		_draining = true
		await SpellFx3D.wait_idle(get_tree())
		_draining = false
	for e in rest:
		match str(e.type):
			"popup":
				popup.emit(str(e.text), e.color)
			"monster_died":
				view.entities.remove_monster(str(e.id))
				if not model_in_combat() and not combat.summary.is_empty():
					combat_won.emit(combat.take_summary())
			"door_open":
				combat.lstate().get_or_add("opened_doors", {})[str(e.id)] = true
				view.open_door(str(e.id))
			"game_over":
				game_over.emit()

## Part (0..1) du temps de réflexion restant pour le personnage dont c'est le tour.
func turn_timer_fraction() -> float:
	if not _timer_enabled() or not model_in_combat() or _busy:
		return -1.0
	return clampf(1.0 - _turn_elapsed / _timer_seconds(), 0.0, 1.0)

func _timer_enabled() -> bool:
	return bool(gs.cfg.get("turnTimerEnabled", true))

func _timer_seconds() -> float:
	return clampf(float(gs.cfg.get("turnTimerSeconds", 5)), 3.0, 10.0)

func _process(delta: float) -> void:
	if _gate_pending and combat != null and not _gate_busy():
		_gate_pending = false
		refresh()
	if combat == null or _busy or gs.game_over or not _timer_enabled() or not model_in_combat() or RunLog.replaying:
		return        # (en rejeu, le chronomètre de tour n'existe pas : un tour passé vient du journal)
	if not get_tree().get_nodes_in_group("modal").is_empty():
		return   # fenêtre ouverte : le chronomètre de tour est en pause
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty() or float(combat.gauges.get("char_" + str(c.id), 0.0)) < 100.0:
		return
	_turn_elapsed += delta
	if _turn_elapsed >= _timer_seconds():
		skip_active_turn(L.t("game.combat_controller.n_a_pas_agi_a"))
