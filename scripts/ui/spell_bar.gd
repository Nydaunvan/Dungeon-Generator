class_name SpellBar
extends HBoxContainer
## Sorts du personnage actif : un bouton par sort, avec le temps de recharge restant.

signal spell_pressed(spell_id: String)

var gs: GameState
var ctrl: CombatController
var _buttons: Dictionary = {}   # spell_id -> Button
var _shown_char: String = ""
var _shown_spells: Array = []

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	ctrl.changed.connect(rebuild)

func rebuild() -> void:
	var c := gs.char_by_id(gs.active_char_id)
	var spells: Array = [] if c.is_empty() else c.get("spellsKnown", [])
	var cid := "" if c.is_empty() else str(c.id)
	if c.is_empty() or ctrl.combat == null:
		return
	if cid == _shown_char and spells == _shown_spells:
		return
	_shown_char = cid
	_shown_spells = spells.duplicate()
	for b in _buttons.values():
		b.queue_free()
	_buttons.clear()
	for sid in spells:
		var sp := ctrl.combat.spell_def(str(sid))
		if sp.is_empty():
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 52)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): spell_pressed.emit(str(sid)))
		add_child(b)
		_buttons[str(sid)] = b
	_refresh_texts()

func _process(_delta: float) -> void:
	if ctrl == null or ctrl.combat == null:
		return
	rebuild()
	_refresh_texts()

func _refresh_texts() -> void:
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	for sid in _buttons:
		var sp := ctrl.combat.spell_def(sid)
		var left := ctrl.combat.cooldown_left(c, sid)
		var b: Button = _buttons[sid]
		var icon := str(sp.get("icon", ""))
		if icon.begins_with("@icon:"):
			icon = "✨"
		b.text = "%s\n%s" % [icon, (("%d s" % int(ceil(left))) if left > 0.0 else str(sp.get("name", "")).left(9))]
		var not_ready := left > 0.0 or int(c.get("stamina", 0)) < int(sp.get("staminaCost", 0))
		b.modulate = Color(1, 1, 1, 0.5) if not_ready else Color.WHITE
		b.tooltip_text = "%s — endurance %d, recharge %d s" % [sp.get("name", ""), int(sp.get("staminaCost", 0)), int(sp.get("cooldownSec", 0))]
