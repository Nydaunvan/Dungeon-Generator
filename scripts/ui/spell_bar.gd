class_name SpellBar
extends HBoxContainer
## Emplacements de sorts ronds (1 à 6) du personnage actif + bouton d'attaque rouge.

signal spell_pressed(spell_id: String)
signal attack_pressed

const SLOTS := 6
var gs: GameState
var ctrl: CombatController
var slot_size: float = 52.0
var _slots: Array[Button] = []
var _attack: Button
var _ids: Array = []

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack = Button.new()
	_attack.focus_mode = Control.FOCUS_NONE
	_attack.tooltip_text = "Attaquer (X / Espace)"
	_tex_button(_attack, "attack", "attack", "attack_p")
	_attack.pressed.connect(func(): attack_pressed.emit())
	add_child(_attack)
	for i in SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		_tex_button(b, "slot", "slot_active", "slot_active")
		b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
		var idx := i
		b.pressed.connect(func(): _slot_pressed(idx))
		add_child(b)
		UiFx.hover_pop(b, 1.08)
		_slots.append(b)
	resized.connect(_apply_size)
	ctrl.changed.connect(_refresh)
	_apply_size()

func _tex_button(b: Button, normal: String, hover: String, pressed: String) -> void:
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", normal]]:
		var st := StyleBoxTexture.new()
		st.texture = UiTheme.tex(pair[1])
		b.add_theme_stylebox_override(pair[0], st)

func _slot_pressed(i: int) -> void:
	if i < _ids.size():
		spell_pressed.emit(str(_ids[i]))

func _apply_size() -> void:
	var s := clampf(size.y * 0.86, 30.0, 64.0)
	slot_size = s
	add_theme_constant_override("separation", int(clampf(size.x * 0.045, 8.0, 70.0)))
	_attack.custom_minimum_size = Vector2(s * 1.1, s * 1.1)
	for b in _slots:
		b.custom_minimum_size = Vector2(s, s)
		b.add_theme_font_size_override("font_size", int(s * 0.34))

func _process(_d: float) -> void:
	if ctrl != null and ctrl.combat != null:
		_refresh()

func _refresh() -> void:
	var c := gs.char_by_id(gs.active_char_id)
	_ids = [] if c.is_empty() else c.get("spellsKnown", [])
	for i in SLOTS:
		var b := _slots[i]
		if c.is_empty() or i >= _ids.size() or ctrl.combat == null:
			b.text = str(i + 1)
			b.modulate = Color(1, 1, 1, 0.4)
			b.tooltip_text = ""
			continue
		var sid := str(_ids[i])
		var sp := ctrl.combat.spell_def(sid)
		var left := ctrl.combat.cooldown_left(c, sid)
		var icon := str(sp.get("icon", "✨"))
		if icon.begins_with("@icon:"):
			icon = "✨"
		b.text = ("%d" % int(ceil(left))) if left > 0.0 else icon
		var not_ready := left > 0.0 or int(c.get("stamina", 0)) < int(sp.get("staminaCost", 0))
		b.modulate = Color(1, 1, 1, 0.5) if not_ready else Color.WHITE
		if ctrl.pending_spell == sid:
			b.modulate = Color(1.3, 1.2, 0.7)
		b.tooltip_text = "%d. %s — endurance %d, recharge %d s" % [i + 1, sp.get("name", ""), int(sp.get("staminaCost", 0)), int(sp.get("cooldownSec", 0))]
