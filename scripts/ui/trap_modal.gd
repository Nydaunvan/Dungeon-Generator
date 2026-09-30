class_name TrapModal
extends Control
## Fenêtre du piège (#trapOverlay de l'original) : détail du calcul de chance, dé à 20 faces en 3D qui roule,
## verdict (or / réussi / échec / critique) avec halo pulsé, secousses, étincelles et flash rouge.

signal skipped
signal resolved(outcome: String, hit: Dictionary)

const GOLD_BRIGHT := Color("ffd88a")
const W := 400.0

var _item: Dictionary
var _bd: Dictionary
var _pick_victim: Callable
var _thr: int = 20
var _outcome: String = ""
var _hit: Dictionary = {}
var _rolled: bool = false

var _shaker: Control
var _panel: PanelContainer
var _glow: Panel
var _glow_sb: StyleBoxFlat
var _die: TrapDie
var _hint: Label
var _roll_info: Label
var _victim: Label
var _result: Label
var _pick: Button
var _skip: Button
var _cont: Button
var _sparks: Control
var _flash: TextureRect
var _fx: Tween
var _t_glow: Tween

static func open(host: Node, item: Dictionary, breakdown: Dictionary, pick_victim: Callable) -> TrapModal:
	var m := TrapModal.new()
	m._item = item
	m._bd = breakdown
	m._pick_victim = pick_victim
	m._thr = Interactions.trap_threshold(int(breakdown.chance))
	m._build()
	host.add_child(m)
	return m

func _lbl(text: String, size: int, color: Color, font: String = "", center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != "":
		l.add_theme_font_override("font", UiTheme.font(font))
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build() -> void:
	add_to_group("modal")
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dimr := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.07, 0.047, 0.027, 0.62), Color(0, 0, 0, 0.88)])
	gt.gradient = gr
	dimr.texture = gt
	dimr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dimr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimr)
	_shaker = Control.new()
	_shaker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shaker)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shaker.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(W, 0)
	_panel.add_theme_stylebox_override("panel", FrameBox.new(18.0, Vector4(24, 22, 24, 22)))
	center.add_child(_panel)
	# halo (box-shadow) derrière le cadre
	_glow = Panel.new()
	_glow.show_behind_parent = true
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_sb = StyleBoxFlat.new()
	_glow_sb.bg_color = Color(0, 0, 0, 0)
	_glow_sb.shadow_color = Color(0, 0, 0, 0.65)
	_glow_sb.shadow_size = 34
	_glow_sb.shadow_offset = Vector2(0, 12)
	_glow_sb.set_expand_margin_all(18.0)
	_glow.add_theme_stylebox_override("panel", _glow_sb)
	_panel.add_child(_glow)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_panel.add_child(v)
	# titre + filet
	var title := _lbl("⚠️ Piège : " + str(_item.get("name", "")), 20, GOLD_BRIGHT, UiTheme.F_TITLE_BOLD)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color("070504")
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	var chance := _lbl("Chance : %d %%" % int(_bd.chance), 19, GOLD_BRIGHT, UiTheme.F_BODY_BOLD)
	v.add_child(chance)
	v.add_child(_calc_box())
	_hint = _lbl("Toute l'équipe participe. Une seule tentative.", 13, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
	v.add_child(_hint)
	_die = TrapDie.new()
	v.add_child(_die)
	_roll_info = _lbl(" ", 15, Color("efe1c2"))
	_roll_info.custom_minimum_size.y = 26
	v.add_child(_roll_info)
	_victim = _lbl(" ", 16, Color("ff9a8a"))
	_victim.custom_minimum_size.y = 26
	v.add_child(_victim)
	_result = _lbl(" ", 20, Color("efe1c2"), UiTheme.F_BODY_BOLD)
	_result.custom_minimum_size.y = 32
	v.add_child(_result)
	var acts := VBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	acts.custom_minimum_size = Vector2(0, 92)
	v.add_child(acts)
	_pick = _button("🔓 Crocheter", true)
	_pick.pressed.connect(_do_pick)
	acts.add_child(_pick)
	_skip = _button("🚶 Passer", false)
	_skip.pressed.connect(func():
		queue_free()
		skipped.emit())
	acts.add_child(_skip)
	_cont = _button("Continuer", true)
	_cont.visible = false
	_cont.pressed.connect(func():
		queue_free()
		resolved.emit(_outcome, _hit))
	acts.add_child(_cont)
	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.clip_contents = true
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_sparks)
	_sparks.top_level = false
	_flash = TextureRect.new()
	var ft := GradientTexture2D.new()
	ft.fill = GradientTexture2D.FILL_RADIAL
	ft.fill_from = Vector2(0.5, 0.46)
	ft.fill_to = Vector2(1.0, 1.0)
	var fg := Gradient.new()
	fg.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	fg.colors = PackedColorArray([Color(1, 0.235, 0.196, 0.85), Color(0.6, 0, 0.04, 0.55), Color(0.235, 0, 0, 0.2), Color(0.235, 0, 0, 0.2)])
	ft.gradient = fg
	_flash.texture = ft
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)
	call_deferred("_lock_size")
	UiFx.pop_in(_panel, 0.18)

func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := IronBox.button_styles()
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	if primary:
		b.add_theme_color_override("font_color", GOLD_BRIGHT)
		b.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	return b

func _calc_box() -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.border_color = Color(0.706, 0.549, 0.235, 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	box.add_child(v)
	var fmt := func(x: float) -> String:
		var r := snappedf(x, 0.1)
		return str(int(r)) if is_equal_approx(r, round(r)) else str(r)
	var row := func(label: String, val: String, total: bool = false):
		var h := HBoxContainer.new()
		var a := _lbl(label, 14, GOLD_BRIGHT if total else Color("efe1c2"), "", false)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		var b := _lbl(val, 14, GOLD_BRIGHT if total else Color("efe1c2"), UiTheme.F_BODY_BOLD, false)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(b)
		if total:
			var line := ColorRect.new()
			line.color = Color(0.706, 0.549, 0.235, 0.35)
			line.custom_minimum_size = Vector2(0, 1)
			v.add_child(line)
		v.add_child(h)
	var s: Dictionary = _bd.s
	row.call("Base", fmt.call(float(s.base)) + " %")
	var grp := {}
	for l in _bd.lines:
		var g: Dictionary = grp.get(l.cls, {"n": 0, "val": 0.0})
		g.n += 1
		g.val += float(l.val)
		grp[l.cls] = g
	for k in grp:
		row.call("🗡️ " + str(k) + (" ×%d" % grp[k].n if grp[k].n > 1 else ""), "+" + fmt.call(grp[k].val) + " %")
	var capped := false
	for p in _bd.dexParts:
		capped = capped or bool(p.capped)
	row.call("🏃 Dextérité au-dessus de 10" + (" (plafonnée)" if capped else ""), "+" + fmt.call(float(_bd.dexTotal)) + " %")
	if int(_bd.raw) != int(_bd.chance):
		row.call("⚖️ Plafond appliqué (%s – %s %%)" % [fmt.call(float(s.min)), fmt.call(float(s.max))], "%d %% → %d %%" % [int(_bd.raw), int(_bd.chance)])
	row.call("Chance finale", "%d %%" % int(_bd.chance), true)
	var note := "🎲 d20 : il faut %d ou plus (%d faces sur 20). 20 naturel = réussite automatique · 1 naturel = échec critique (+%s %% dégâts).%s" % [
		_thr, 21 - _thr, fmt.call(float(s.critExtraDmg)), " Les personnages à terre ne comptent pas." if int(_bd.down) > 0 else ""]
	var n1 := _lbl(note, 12, Color("cdb98a"), "", false)
	v.add_child(n1)
	var n2 := _lbl("💥 Si le piège se déclenche : %s à %s %% des PV max d'un personnage tiré au sort." % [fmt.call(float(s.dmgPctMin)), fmt.call(float(s.dmgPctMax))], 12, Color("cdb98a"), "", false)
	v.add_child(n2)
	return box

## Taille figée à l'ouverture (mesure avec le contenu le plus long), réduite si l'écran est trop petit.
func _lock_size() -> void:
	await get_tree().process_frame
	var natural := _panel.get_combined_minimum_size()
	_panel.custom_minimum_size = natural
	_panel.pivot_offset = natural * 0.5
	var avail := get_viewport_rect().size.y - 24.0
	if natural.y > avail:
		var z := avail / natural.y
		_panel.scale = Vector2(z, z)

func _do_pick() -> void:
	if _rolled:
		return
	_rolled = true
	_pick.disabled = true
	_skip.disabled = true
	_hint.modulate.a = 0.0
	var roll := randi_range(1, 20)
	_outcome = "perfect" if roll == 20 else ("crit" if roll == 1 else ("success" if roll >= _thr else "fail"))
	_die.finished.connect(func(): _show_outcome(roll), CONNECT_ONE_SHOT)
	_die.roll(roll)

func _set_glow(col: Color, size_from: float, a_from: float, size_to: float, a_to: float, pulse: bool) -> void:
	if _t_glow:
		_t_glow.kill()
	_glow_sb.shadow_color = Color(col.r, col.g, col.b, a_from)
	_glow_sb.shadow_size = int(size_from)
	_glow_sb.shadow_offset = Vector2(0, 12) if col == Color(0, 0, 0) else Vector2.ZERO
	if pulse:
		_t_glow = create_tween().set_loops()
		_t_glow.tween_method(func(k: float):
			_glow_sb.shadow_color = Color(col.r, col.g, col.b, lerpf(a_from, a_to, k))
			_glow_sb.shadow_size = int(lerpf(size_from, size_to, k))
			_glow.queue_redraw(), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		_t_glow.tween_method(func(k: float):
			_glow_sb.shadow_color = Color(col.r, col.g, col.b, lerpf(a_to, a_from, k))
			_glow_sb.shadow_size = int(lerpf(size_to, size_from, k))
			_glow.queue_redraw(), 0.0, 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	_glow.queue_redraw()

func _shake(seq: Array, dur: float) -> void:
	if _fx:
		_fx.kill()
	_fx = create_tween()
	var step := dur / float(seq.size() + 1)
	for o in seq:
		_fx.tween_property(_shaker, "position", o, step)
	_fx.tween_property(_shaker, "position", Vector2.ZERO, step)

func _show_outcome(roll: int) -> void:
	var info := "Jet : %d / 20 — il fallait %d ou plus" % [roll, _thr]
	if roll == 20:
		info = "Jet : 20 — réussite automatique"
	elif roll == 1:
		info = "Jet : 1 — échec critique automatique"
	_roll_info.text = info
	match _outcome:
		"perfect":
			_result.text = "✨ Crochetage parfait !"
			_result.add_theme_color_override("font_color", Color("ffe08a"))
			_die.glow = Color("ffd76a")
			_set_glow(Color("ffd76a"), 18, 0.55, 44, 0.95, true)
			_spark_burst()
			Sound.sfx("level_up")
			Sound.sfx_later(0.38, "pickup")
			Sound.sfx_later(0.62, "level_up")
		"success":
			_result.text = "🔓 Piège désamorcé"
			_result.add_theme_color_override("font_color", Color("c7dd85"))
			_die.glow = Color("b9d066")
			_die.glow.a = 0.6
			_set_glow(Color("96c85a"), 22, 0.5, 22, 0.5, false)
			Sound.sfx("door_locked")
			Sound.sfx_later(0.11, "pickup")
		"fail":
			_result.text = "❌ Le crochetage échoue"
			_result.add_theme_color_override("font_color", Color("b5b5b5"))
			_die.dim = Color(0.45, 0.45, 0.45)
			_set_glow(Color("969696"), 20, 0.4, 20, 0.4, false)
			_shake([Vector2(-4, 0), Vector2(4, 0), Vector2(-3, 0), Vector2(2, 0)], 0.5)
			Sound.sfx("hit")
		_:
			_result.text = "💥 Échec critique !"
			_result.add_theme_color_override("font_color", Color("ff5a5a"))
			_die.dim = Color(0.6, 0.55, 0.55)
			_die.glow = Color("b3111a")
			_die.glow.a = 0.7
			_shake([Vector2(-11, 4), Vector2(10, -5), Vector2(-9, 3), Vector2(7, -3), Vector2(-4, 2)], 0.6)
			_set_glow(Color(0.59, 0.04, 0.08), 16, 0.6, 42, 0.95, true)
			var t := create_tween()
			t.tween_property(_flash, "modulate:a", 1.0, 0.1)
			t.tween_property(_flash, "modulate:a", 0.0, 0.6)
			Sound.sfx("hit")
			Sound.sfx_later(0.13, "hit")
	_die.queue_redraw()
	if _outcome == "fail" or _outcome == "crit":
		var mult := 1.0 + float(_bd.s.critExtraDmg) / 100.0 if _outcome == "crit" else 1.0
		_hit = _pick_victim.call(mult)
		_victim.text = "🎯 %s subira %d dégâts" % [_hit.victim.name, int(_hit.dmg)]
	_pick.visible = false
	_skip.visible = false
	_cont.visible = true

func _spark_burst() -> void:
	for ch in _sparks.get_children():
		ch.queue_free()
	var sz := _panel.size
	for i in 22:
		var l := Label.new()
		l.text = "✦" if randf() < 0.5 else "✧"
		l.add_theme_color_override("font_color", Color("ffe08a"))
		l.add_theme_font_size_override("font_size", int(10 + randf() * 12))
		l.modulate.a = 0.0
		l.position = Vector2(sz.x * (0.08 + randf() * 0.84), sz.y * 0.8)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sparks.add_child(l)
		var dx := randf() * 60.0 - 30.0
		var t := create_tween()
		t.tween_interval(randf() * 0.7)
		t.tween_property(l, "modulate:a", 1.0, 0.24)
		t.parallel().tween_property(l, "position", l.position + Vector2(dx, -230.0), 1.6).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(l, "modulate:a", 0.0, 1.36).set_delay(0.24)
