class_name SpellBar
extends GridContainer
## Emplacements de sorts (1 à 6) du personnage actif + disque d'attaque + 7e disque (technique ultime, jauge), en bronze rivé.
## Grisé tant que ce n'est pas le tour du personnage ; infobulle de sort au survol / appui long.

signal spell_pressed(spell_id: String)
signal attack_pressed

const SLOTS := 6
var gs: GameState
var ctrl: CombatController
var slot_size: float = 52.0
var _slots: Array[SpellDisc] = []
var _attack: SpellDisc
var _ult: SpellDisc
var _ids: Array = []

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	columns = SLOTS + 2
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack = SpellDisc.new()
	_attack.tone = "attack"
	_attack.tip_show.connect(func():
		var cost := mini(int((gs.cfg.get("staminaSettings", {}) as Dictionary).get("attackCost", 0)), 2)
		SpellTip.show_attack(_attack, gs.char_by_id(gs.active_char_id), cost))
	_attack.tip_hide.connect(SpellTip.hide_tip)
	_attack.pressed.connect(func(): attack_pressed.emit())
	_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack.set_caption(Keybinds.text("attack").get_slice(" ", 0))
	add_child(_attack)
	for i in SLOTS:
		var b := SpellDisc.new()
		var idx := i
		b.pressed.connect(func(): _slot_pressed(idx))
		b.tip_show.connect(func(): _show_tip(idx))
		b.tip_hide.connect(SpellTip.hide_tip)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_caption(Keybinds.text("slot_%d" % (i + 2)))
		add_child(b)
		_slots.append(b)
	_ult = SpellDisc.new()
	_ult.tone = "ult"
	_ult.pressed.connect(func():
		SpellTip.hide_tip()
		var u := Characters.ultimate_id(gs.cfg, gs.char_by_id(gs.active_char_id))
		if u != "":
			spell_pressed.emit(u))
	_ult.tip_show.connect(_show_ult_tip)
	_ult.tip_hide.connect(SpellTip.hide_tip)
	_ult.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ult.set_caption(Keybinds.text("slot_%d" % (SLOTS + 2)).get_slice(" ", 0))
	add_child(_ult)
	resized.connect(_apply_size)
	ctrl.changed.connect(_refresh)
	_apply_size()

## Allume le disque de la touche pressée (0 = attaque, 1… = sorts).
func flash(slot: int) -> void:
	if slot == 0:
		_attack.flash()
	elif slot == SLOTS + 1:
		_ult.flash()
	elif slot - 1 < _slots.size():
		_slots[slot - 1].flash()

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
	SpellTip.show_for(_slots[i], ctrl.combat.spell_def(sid), ceili(ctrl.combat.cooldown_left(c, sid)), c)

func _show_ult_tip() -> void:
	var c := gs.char_by_id(gs.active_char_id)
	if c.is_empty():
		return
	var sid := Characters.ultimate_id(gs.cfg, c)
	if sid == "" or ctrl.combat == null:
		SpellTip.show_locked(_ult)
		return
	SpellTip.show_for(_ult, ctrl.combat.spell_def(sid), 0, c)

var _last_w := -1.0

## Disques plus gros qu'à l'origine : sur une seule rangée quand la largeur le permet (portrait), sinon sur deux rangées
## (attaque + 3 sorts, puis 3 sorts) pour garder des disques de 42 à 54 px dans une colonne étroite.
func _apply_size() -> void:
	var w := roundf(size.x)
	if w == _last_w or w <= 0.0:
		return
	_last_w = w
	var single := w >= UiMetrics.css(8.0 * 46.0)
	columns = (SLOTS + 2) if single else 4
	var s := UiMetrics.css(clampf((w - 24.0) / float(columns), 40.0, 64.0 if single else 48.0))
	slot_size = s
	var cap := floorf(clampf(minf(s, 60.0) * 0.26, 9.0, 14.0)) + 4.0    # place du numéro de touche sous le disque
	_attack.custom_minimum_size = Vector2(s, s + cap)
	_ult.custom_minimum_size = Vector2(s, s + cap)
	for b in _slots:
		b.custom_minimum_size = Vector2(s, s + cap)
	var rows := 1 if single else 2
	custom_minimum_size = Vector2(0, rows * (s + cap) + (rows - 1) * 2.0)

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
	_refresh_ult(c, dead, waiting, base)
	for i in SLOTS:
		var b := _slots[i]
		if c.is_empty() or i >= _ids.size() or ctrl.combat == null:
			b.tone = "empty"
			b.disabled = true
			b.set_state("", null, "", 1.0)
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
		var no_stamina := int(c.get("stamina", 0)) < int(sp.get("staminaCost", 0))     # plus assez d'endurance : le sort est grisé
		if left > 0.0 or no_stamina:
			dimmed *= 0.65
		b.set_state(icon, t, ("%d" % ceili(left)) if left > 0.0 else "", dimmed, ctrl.pending_spell == sid, no_stamina and not dead)
		var se := str(sp.get("statusEffect", ""))
		if se != "" and int(sp.get("statusChance", 0)) > 0:
			b.set_badge(Statuses.icon_of({"type": se}), Statuses.is_harmful({"type": se}))
		else:
			b.set_badge("")

## 7e disque : technique ultime de la classe évoluée. Cadenas tant que le héros est de classe de base ; sinon jauge dorée, pleine = prête.
func _refresh_ult(c: Dictionary, dead: bool, waiting: bool, base: float) -> void:
	var sid := Characters.ultimate_id(gs.cfg, c)
	if c.is_empty() or sid == "":
		_ult.disabled = true
		_ult.set_ult(0.0, true)
		_ult.set_state("", null, "", 0.75, false)
		_ult.set_badge("")
		return
	var sp := ctrl.combat.spell_def(sid) if ctrl.combat != null else {}
	var mx := float(Characters.ult_cfg(gs.cfg).max)
	var ready := Characters.ult_ready(gs.cfg, c)
	var icon := str(sp.get("icon", "✨"))
	var t: Texture2D = null
	if icon.begins_with("@icon:"):
		t = IconResolver.texture(icon)
		icon = "" if t != null else "✨"
	_ult.disabled = dead or waiting or not ready
	_ult.set_ult(Characters.ult_charge(c) / mx, false)
	_ult.set_state(icon, t, "", base * (1.0 if ready else 0.55), ctrl.pending_spell == sid, false)
	_ult.set_badge("")
