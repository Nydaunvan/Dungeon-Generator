class_name SpellBar
extends HBoxContainer
## Emplacements de sorts (1 à 6) du personnage actif + disque d'attaque, en bronze rivé.
## Grisé tant que ce n'est pas le tour du personnage ; infobulle de sort au survol / appui long.

signal spell_pressed(spell_id: String)
signal attack_pressed

const SLOTS := 6
var gs: GameState
var ctrl: CombatController
var slot_size: float = 52.0
var _slots: Array[SpellDisc] = []
var _attack: SpellDisc
var _ids: Array = []

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack = SpellDisc.new()
	_attack.tone = "attack"
	_attack.tooltip_text = "Attaquer (X / Espace)"
	_attack.pressed.connect(func(): attack_pressed.emit())
	add_child(_attack)
	for i in SLOTS:
		var b := SpellDisc.new()
		var idx := i
		b.pressed.connect(func(): _slot_pressed(idx))
		b.tip_show.connect(func(): _show_tip(idx))
		b.tip_hide.connect(SpellTip.hide_tip)
		add_child(b)
		_slots.append(b)
	resized.connect(_apply_size)
	ctrl.changed.connect(_refresh)
	_apply_size()

func _exit_tree() -> void:
	SpellTip.hide_tip()

func _slot_pressed(i: int) -> void:
	SpellTip.hide_tip()
	if i < _ids.size():
		spell_pressed.emit(str(_ids[i]))

func _show_tip(i: int) -> void:
	if i >= _ids.size() or ctrl.combat == null:
		return
	var c := gs.char_by_id(gs.active_char_id)
	var sid := str(_ids[i])
	SpellTip.show_for(_slots[i], ctrl.combat.spell_def(sid), ceili(ctrl.combat.cooldown_left(c, sid)))

func _apply_size() -> void:
	var s := clampf(size.y * 0.92, 30.0, 70.0)
	slot_size = s
	add_theme_constant_override("separation", int(maxf(6.0, (size.x - s * float(SLOTS + 1)) / float(SLOTS))))   # space-between
	_attack.custom_minimum_size = Vector2(s, s)
	for b in _slots:
		b.custom_minimum_size = Vector2(s, s)

func _process(_d: float) -> void:
	if ctrl != null and ctrl.combat != null:
		_refresh()

func _refresh() -> void:
	var c := gs.char_by_id(gs.active_char_id)
	_ids = [] if c.is_empty() else c.get("spellsKnown", [])
	var ended := gs.game_over or gs.won
	var dead := c.is_empty() or int(c.hp) <= 0
	var waiting := not dead and ctrl.combat != null and ctrl.in_combat() and not ctrl.combat.can_act(c)
	var base := 0.6 if waiting else 1.0
	_attack.disabled = ended or dead or waiting
	_attack.set_state("⚔", null, "", base * (0.4 if dead else 1.0))
	for i in SLOTS:
		var b := _slots[i]
		if c.is_empty() or i >= _ids.size() or ctrl.combat == null:
			b.tone = "empty"
			b.disabled = true
			b.set_state(str(i + 1), null, "", 1.0)
			continue
		b.tone = "spell"
		var sid := str(_ids[i])
		var sp := ctrl.combat.spell_def(sid)
		var left := ctrl.combat.cooldown_left(c, sid)
		var icon := str(sp.get("icon", "✨"))
		var t: Texture2D = null
		if icon.begins_with("@icon:"):
			t = IconResolver.texture(icon)
			icon = "" if t != null else "✨"
		b.disabled = dead or waiting
		var dimmed := base
		if left > 0.0 or int(c.get("stamina", 0)) < int(sp.get("staminaCost", 0)):
			dimmed *= 0.65
		b.set_state(icon, t, ("%d" % ceili(left)) if left > 0.0 else "", dimmed, ctrl.pending_spell == sid)
