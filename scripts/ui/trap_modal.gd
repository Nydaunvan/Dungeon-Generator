class_name TrapModal
extends Control
## Fenêtre du piège : le jeu propose quelques façons de s'en sortir (désarmer, forcer, dissiper, sonder, sacrifier un objet,
## se dévouer, contourner) et parfois un puzzle (runes, fils, énigme, dalles). Chaque méthode se joue au dé à 20 faces en 3D
## ou par le puzzle ; verdict avec halo, secousses, étincelles et flash rouge ; butin éventuel à la fin.
## Résultat : `resolved(res)` avec {disarm, hits, reward, sta, sac_idx}. `skipped` si le groupe passe son chemin (le piège frappe).

signal skipped
signal resolved(res: Dictionary)

const GOLD_BRIGHT := Color("ffd88a")
const W := 470.0
const RIGHT_W := 84.0   # colonne de droite des cartes (chance, mention) : largeur fixe, texte réduit pour y tenir
const BODY_H := 330.0

var _item: Dictionary
var _ctx: Dictionary
var _gs: GameState
var _s: Dictionary
var _offer: Dictionary
var _methods: Array = []
var _puzzle := ""
var _probe := 0.0
var _res: Dictionary = {"disarm": false, "hits": [], "reward": {}, "sta": {}, "sac_idx": -1}
var _busy := false
var _stage := "choose"            # choose | sacrifice | roll | puzzle | after : étape en cours (sert à accepter ou refuser une entrée)
var _pz: TrapPuzzle = null

var _shaker: Control
var _panel: PanelContainer
var _glow: Panel
var _glow_sb: StyleBoxFlat
var _flavor: Label
var _body: VBoxContainer
var _foot: HBoxContainer
var _status: Label
var _sparks: Control
var _flash: TextureRect
var _fx: Tween
var _t_glow: Tween
var _die: TrapDie
var _roll_info: Label
var _victim: Label
var _result: Label
var _cont: Button
var _skip: Button
var _back: Button
var _next := Callable()

static func open(host: Node, item: Dictionary, ctx: Dictionary) -> TrapModal:
	var m := TrapModal.new()
	m._item = item
	m._ctx = ctx
	m._gs = ctx.gs
	m._s = ctx.s
	m._offer = ctx.offer
	m._methods = (ctx.offer.methods as Array).duplicate()
	m._puzzle = str(ctx.offer.puzzle)
	m._build()
	host.add_child(m)
	return m

## Réduit la police jusqu'à ce que le texte tienne dans `avail` (px de conception) ; au pire il est coupé par « … ».
static func fit_font(c: Control, text: String, font: Font, base: int, min_size: int, avail: float) -> void:
	var sz := base
	while sz > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > avail:
		sz -= 1
	c.add_theme_font_size_override("font_size", sz)

## Un bouton dont le texte tient toujours dedans (police réduite si besoin).
static func fit_button(b: Button, base: int = 15, min_size: int = 10) -> void:
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var refit := func():
		fit_font(b, b.text, b.get_theme_font("font"), base, min_size, maxf(10.0, b.size.x - 30.0))
	b.resized.connect(refit)
	refit.call()

## Garde-fou : tout texte d'un bouton ou d'une étiquette sans retour à la ligne doit tenir dans sa boîte.
## Passe régulière sur toute la fenêtre (les textes changent à chaque étape) : police réduite jusqu'à 8 puis coupe « … ».
var _guard_t := 0.0

func _process(d: float) -> void:
	_guard_t -= d
	if _guard_t <= 0.0:
		_guard_t = 0.15
		_guard(self)

static func _guard(n: Node) -> void:
	for c in n.get_children():
		if c is Button:
			_guard_one(c, c.text, 24.0 + (c.icon.get_width() if c.icon != null else 0.0))
		elif c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and c.clip_text:
			_guard_one(c, c.text, 2.0)
		if c is Control and (c as Control).size.x > 0.0:
			_guard(c)

static func _guard_one(c: Control, text: String, pad: float) -> void:
	if text == "" or c.size.x < 12.0:
		return
	if not c.has_meta("g_done"):
		c.set_meta("g_done", true)
		c.set("clip_text", true)
		c.set("text_overrun_behavior", TextServer.OVERRUN_TRIM_ELLIPSIS)
	var base: int = c.get_theme_font_size("font_size")
	var font: Font = c.get_theme_font("font")
	var sz := base
	var avail := c.size.x - pad
	while sz > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > avail:
		sz -= 1
	if sz != base:
		c.add_theme_font_size_override("font_size", sz)

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
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	var title := _lbl(L.t("ui.trap_modal.piege") + L.c(str(_item.get("name", ""))), 20, GOLD_BRIGHT, UiTheme.F_TITLE_BOLD)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color("070504")
	rule.custom_minimum_size = Vector2(0, 2)
	v.add_child(rule)
	_flavor = _lbl("", 13, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
	_flavor.custom_minimum_size = Vector2(0, 38)
	v.add_child(_flavor)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(0, BODY_H)
	_body.add_theme_constant_override("separation", 6)
	v.add_child(_body)
	_status = _lbl(" ", 13, Color("cdb98a"), UiTheme.F_BODY_ITALIC)
	_status.custom_minimum_size = Vector2(0, 22)
	v.add_child(_status)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 8)
	_foot.custom_minimum_size = Vector2(0, 42)
	v.add_child(_foot)
	var pen := float(_s.skipDmgPct) / 100.0
	var pen_txt := str(int(pen)) if is_equal_approx(pen, round(pen)) else str(snappedf(pen, 0.1))
	_skip = _button(L.fa(L.t("ui.trap_modal.passer_penalite"), pen_txt), false)
	_skip.tooltip_text = L.fa(L.t("ui.trap_modal.passer_tip"), pen_txt)
	_skip.pressed.connect(func(): Flows.input("trap", ["skip"]))
	_foot.add_child(_skip)
	_back = _button(L.t("ui.trap_modal.retour"), false)
	_back.visible = false
	_back.pressed.connect(func(): Flows.input("trap", ["back"]))
	_foot.add_child(_back)
	_cont = _button(L.t("common.continuer"), true)
	_cont.visible = false
	_cont.pressed.connect(func(): Flows.input("trap", ["next"]))
	_foot.add_child(_cont)
	_sparks = Control.new()
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.clip_contents = true
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_sparks)
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
	_stage_choose()
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
	fit_button(b, 15, 10)
	return b

func _lock_size() -> void:
	await get_tree().process_frame
	var natural := _panel.get_combined_minimum_size()
	_panel.custom_minimum_size = natural
	_panel.pivot_offset = natural * 0.5
	var avail := get_viewport_rect().size.y - 24.0
	if natural.y > avail:
		var z := avail / natural.y
		_panel.scale = Vector2(z, z)

func _clear_body() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_status.text = " "
	_die = null
	_victim = null
	_roll_info = null
	_result = null
	_skip.visible = false
	_back.visible = false
	_cont.visible = false

func _foot_show(skip: bool, back: bool, cont: bool) -> void:
	_skip.visible = skip
	_back.visible = back
	_cont.visible = cont

# ------------------------------------------------------------------ étape 1 : le choix

## L'entrée du joueur est-elle acceptable à cet instant ? (sinon elle n'est ni journalisée ni appliquée)
func can_input(a: Array) -> bool:
	if a.is_empty():
		return false
	match str(a[0]):
		"skip":
			return _stage == "choose" and not _busy
		"method":
			return _stage == "choose" and not _busy and a.size() > 1 and _methods.has(str(a[1])) \
				and not (str(a[1]) == "sacrifice" and TrapRules.sacrifice_candidates(_gs).is_empty())
		"puzzle":
			return _stage == "choose" and not _busy and _puzzle != ""
		"sac":
			return _stage == "sacrifice" and not _busy and a.size() > 1 and TrapRules.sacrifice_candidates(_gs).has(int(a[1]))
		"back":
			return _stage == "sacrifice" and not _busy
		"next":
			return _stage == "after" and _next.is_valid()
		"pz":
			return _stage == "puzzle" and _pz != null and a.size() > 1 and _pz.accepts()
	return false

## Applique une entrée acceptée (voir can_input) ; appelé par Flows, en direct comme au rejeu.
func apply_input(a: Array) -> void:
	match str(a[0]):
		"skip":
			Flows.close("trap")
			queue_free()
			skipped.emit()
		"method": _pick_method(str(a[1]))
		"puzzle": _stage_puzzle()
		"sac":
			var idx := int(a[1])
			_do_sacrifice(idx, _gs.inventory[idx])
		"back": _stage_choose()
		"next":
			var cb := _next
			_next = Callable()
			cb.call()
		"pz": _pz.inject(int(a[1]))

## Prêt à recevoir la prochaine entrée (le rejeu attend ce moment, comme un joueur qui attend que les boutons soient actifs).
func ready_for_input() -> bool:
	match _stage:
		"choose", "sacrifice":
			return not _busy
		"after":
			return _next.is_valid()
		"puzzle":
			return _pz != null and _pz.accepts()
	return false

func _stage_choose() -> void:
	_stage = "choose"
	_busy = false
	_clear_body()
	_set_glow(Color(0, 0, 0), 34, 0.65, 34, 0.65, false)
	var kind: Dictionary = _offer.kind
	_flavor.text = "%s  %s\n%s" % [kind.icon, L.t("ui.trap_kind.%s" % str(str(kind.id))), L.t("ui.trap_kind.%s" % str(str(kind.id)) + "_txt")]
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := _lbl(L.t("ui.trap_modal.que_faites_vous"), 16, GOLD_BRIGHT, UiTheme.F_BODY_BOLD)
	_body.add_child(head)
	if _probe > 0.0:
		_body.add_child(_lbl(L.fa(L.t("ui.trap_modal.sonde_bonus"), int(_probe)), 12, Color("b8e08a"), UiTheme.F_BODY_ITALIC))
	var i := 0
	for m in _methods:
		_body.add_child(_method_card(str(m), i))
		i += 1
	if _puzzle != "":
		_body.add_child(_puzzle_card(i))
	_foot_show(true, false, false)

func _chance_color(ch: int) -> Color:
	if ch >= 65:
		return Color("9be07a")
	if ch >= 40:
		return Color("ffd88a")
	return Color("ff9a52")

func _card(icon: String, name: String, sub: String, right_top: String, right_bot: String, col: Color, tip: String, idx: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.clip_contents = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := IronBox.button_styles()
	for k in st:
		b.add_theme_stylebox_override(k, st[k])
	b.tooltip_text = tip
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	# l'emoji est plus haut que sa ligne : boîte fixe, découpée, pour qu'il ne dépasse jamais de la carte
	var icb := Control.new()
	icb.custom_minimum_size = Vector2(34, 34)
	icb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icb.clip_contents = true
	icb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := _lbl(icon, 22, GOLD_BRIGHT, "", true)
	ic.autowrap_mode = TextServer.AUTOWRAP_OFF
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icb.add_child(ic)
	h.add_child(icb)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", -1)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := _lbl(name, 15, GOLD_BRIGHT, UiTheme.F_BODY_BOLD, false)
	nl.autowrap_mode = TextServer.AUTOWRAP_OFF
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nl)
	var sl := _lbl(sub, 12, UiTheme.DIM, "", false)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sl)
	tv.resized.connect(func():
		var w := maxf(10.0, tv.size.x - 2.0)
		fit_font(nl, nl.text, nl.get_theme_font("font"), 15, 10, w)
		fit_font(sl, sl.text, sl.get_theme_font("font"), 12, 9, w))
	h.add_child(tv)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", -3)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rt := _lbl(right_top, 20, col, UiTheme.F_BODY_BOLD, false)
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rt.autowrap_mode = TextServer.AUTOWRAP_OFF
	rv.add_child(rt)
	var rb := _lbl(right_bot, 11, UiTheme.DIM, "", false)
	rb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rb.autowrap_mode = TextServer.AUTOWRAP_OFF
	rv.add_child(rb)
	rv.custom_minimum_size = Vector2(RIGHT_W, 0)
	fit_font(rt, right_top, rt.get_theme_font("font"), 20, 12, RIGHT_W)
	fit_font(rb, right_bot, rb.get_theme_font("font"), 11, 8, RIGHT_W)
	h.add_child(rv)
	b.modulate.a = 0.0
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.05 + idx * 0.08)
	t.tween_callback(func():
		if b.disabled:
			b.modulate.a = 0.5)
	return b

func _method_card(id: String, idx: int) -> Button:
	var d: Dictionary = TrapRules.METHODS[id]
	var info := TrapRules.method_chance(_gs, _s, id, int(_ctx.bd.chance), _probe)
	var ch: int = info.chance
	var who: Dictionary = info.who
	var sub := L.t("ui.trap_method.stat_%s" % str(id))
	if not who.is_empty():
		sub += " · " + str(who.name)
	if id == "sacrifice":
		sub = L.fa(L.t("ui.trap_method.stat_sacrifice_n"), TrapRules.sacrifice_candidates(_gs).size())
	var tip := L.t("ui.trap_method.risk_%s" % str(id))
	if id == "disarm":
		tip = _disarm_tip() + "\n" + tip
	elif id == "dispel":
		tip += "\n" + L.fa(L.t("ui.trap_method.cout_endurance"), int(_s.dispelStaCost))
	var b := _card(str(d.icon), L.t("ui.trap_method.name_%s" % str(id)), sub, "%d %%" % ch, L.t("ui.trap_modal.chance_court"), _chance_color(ch), tip, idx)
	b.pressed.connect(func(): Flows.input("trap", ["method", id]))
	if id == "sacrifice" and TrapRules.sacrifice_candidates(_gs).is_empty():
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.5)
		b.tooltip_text = L.t("ui.trap_modal.sacrifice_aucun")
	return b

func _puzzle_card(idx: int) -> Button:
	var b := _card(str(TrapRules.PUZZLE_ICONS[_puzzle]), L.t("ui.trap_puzzle.name_%s" % str(_puzzle)), L.t("ui.trap_puzzle.sub_%s" % str(_puzzle)),
		L.t("ui.trap_modal.puzzle"), L.t("ui.trap_modal.recompense_plus"), Color("8fd0ff"), L.t("ui.trap_puzzle.tip_%s" % str(_puzzle)), idx)
	b.pressed.connect(func(): Flows.input("trap", ["puzzle"]))
	return b

func _disarm_tip() -> String:
	var bd: Dictionary = _ctx.bd
	var s: Dictionary = bd.s
	var fmt := func(x: float) -> String:
		var r := snappedf(x, 0.1)
		return str(int(r)) if is_equal_approx(r, round(r)) else str(r)
	var lines: Array = ["Base : %s %%" % fmt.call(float(s.base))]
	var grp := {}
	for l in bd.lines:
		var g: Dictionary = grp.get(l.cls, {"n": 0, "val": 0.0})
		g.n += 1
		g.val += float(l.val)
		grp[l.cls] = g
	for k in grp:
		lines.append("🗡️ %s%s : +%s %%" % [L.c(str(k)), (" ×%d" % grp[k].n) if grp[k].n > 1 else "", fmt.call(grp[k].val)])
	lines.append(L.t("ui.trap_modal.dexterite_10") + " : +" + fmt.call(float(bd.dexTotal)) + " %")
	lines.append(L.t("ui.trap_modal.chance_finale") + " : %d %%" % int(bd.chance))
	return "\n".join(lines)

func _pick_method(id: String) -> void:
	if _busy:
		return
	if id == "sacrifice":
		_stage_sacrifice()
	else:
		_stage_roll(id)

# ------------------------------------------------------------------ étape : sacrifice

func _stage_sacrifice() -> void:
	_stage = "sacrifice"
	_clear_body()
	_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	_body.add_child(_lbl(L.t("ui.trap_modal.sacrifice_choisir"), 15, GOLD_BRIGHT, UiTheme.F_BODY_BOLD))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 4)
	sc.add_child(lv)
	_body.add_child(sc)
	for idx in TrapRules.sacrifice_candidates(_gs):
		var it: Dictionary = _gs.inventory[idx]
		var b := _card(_item_icon(it), L.c(str(it.get("name", "?"))), L.t("ui.trap_modal.sacrifice_consomme"), "", "", GOLD_BRIGHT, "", 0)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func(): Flows.input("trap", ["sac", idx]))
		lv.add_child(b)
	_foot_show(false, true, false)

func _item_icon(it: Dictionary) -> String:
	return "🧪" if str(it.get("type", "")) == "potion" else "📜"

func _do_sacrifice(idx: int, it: Dictionary) -> void:
	_stage = "roll"
	_busy = true
	_res.sac_idx = idx
	_res.disarm = true
	_clear_body()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var big := _lbl(_item_icon(it), 64, GOLD_BRIGHT)
	big.pivot_offset = Vector2(220, 40)
	_body.add_child(big)
	_body.add_child(_lbl(L.c(str(it.get("name", "?"))), 16, Color("efe1c2"), UiTheme.F_BODY_BOLD))
	var t := create_tween()
	t.tween_property(big, "scale", Vector2(1.35, 1.35), 0.35).set_trans(Tween.TRANS_BACK)
	t.tween_property(big, "modulate", Color(1, 0.5, 0.2, 0.0), 0.7)
	Sound.sfx("fountain")
	_spark_burst()
	_set_glow(Color("ffd76a"), 18, 0.5, 40, 0.9, true)
	_end_with(L.t("ui.trap_modal.sacrifice_ok"), Color("ffe08a"), "", "none")

# ------------------------------------------------------------------ étape : jet de dé

func _stage_roll(id: String) -> void:
	_stage = "roll"
	_busy = true
	_clear_body()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var info := TrapRules.method_chance(_gs, _s, id, int(_ctx.bd.chance), _probe)
	var ch: int = info.chance
	var thr := TrapRules.threshold(ch)
	_body.add_child(_lbl("%s %s — %d %%" % [TrapRules.METHODS[id].icon, L.t("ui.trap_method.name_%s" % str(id)), ch], 17, GOLD_BRIGHT, UiTheme.F_BODY_BOLD))
	_body.add_child(_lbl(L.fa(L.t("ui.trap_modal.d20_court"), [thr, 21 - thr]), 12, Color("cdb98a")))
	_die = TrapDie.new()
	_body.add_child(_die)
	_roll_info = _lbl(" ", 15, Color("efe1c2"))
	_roll_info.custom_minimum_size.y = 26
	_body.add_child(_roll_info)
	_victim = _lbl(" ", 16, Color("ff9a8a"))
	_victim.custom_minimum_size.y = 26
	_body.add_child(_victim)
	_result = _lbl(" ", 20, Color("efe1c2"), UiTheme.F_BODY_BOLD)
	_result.custom_minimum_size.y = 32
	_body.add_child(_result)
	_foot_show(false, false, false)
	var roll := GameRng.range_i("trap", 1, 20)
	var ok := roll == 20 or (roll != 1 and roll >= thr)
	if ch >= 100:
		ok = true
	var crit := roll == 1 and id == "disarm"
	var outcome := "perfect" if (roll == 20 and id == "disarm") else ("crit" if crit else ("success" if ok else "fail"))
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return
	_die.finished.connect(func(): _roll_outcome(id, roll, thr, outcome, info), CONNECT_ONE_SHOT)
	_die.roll(roll)

func _roll_outcome(id: String, roll: int, thr: int, outcome: String, info: Dictionary) -> void:
	var line := L.fa(L.t("ui.trap_modal.jet_20_il_fallait_ou"), [roll, thr])
	if roll == 20:
		line = L.t("ui.trap_modal.jet_20_reussite_automatique")
	elif roll == 1:
		line = L.t("ui.trap_modal.jet_1_echec_critique_automatique") if id == "disarm" else L.t("ui.trap_modal.jet_1_echec")
	_roll_info.text = line
	var good := outcome == "success" or outcome == "perfect"
	var who: Dictionary = info.who
	var s := _s
	var msg := ""
	var reward_src := ""
	match id:
		"disarm":
			if good:
				_res.disarm = true
				msg = L.t("ui.trap_modal.crochetage_parfait") if outcome == "perfect" else L.t("ui.trap_modal.piege_desamorce")
				reward_src = "perfect" if outcome == "perfect" else "dice"
			else:
				msg = L.t("ui.trap_modal.echec_critique") if outcome == "crit" else L.t("ui.trap_modal.le_crochetage_echoue")
				_hit_random(1.0 + float(s.critExtraDmg) / 100.0 if outcome == "crit" else 1.0)
		"force":
			if good:
				_res.disarm = true
				msg = L.t("ui.trap_modal.force_ok")
				reward_src = "perfect" if roll == 20 else "dice"
			else:
				msg = L.t("ui.trap_modal.force_ko")
				_hit_random(float(s.forceFailPct) / 100.0)
		"dispel":
			var cost := mini(int(who.get("stamina", 0)), int(s.dispelStaCost))
			_res.sta = {"id": str(who.get("id", "")), "amt": cost}
			if good:
				_res.disarm = true
				msg = L.t("ui.trap_modal.dissipe_ok")
				reward_src = "perfect" if roll == 20 else "dice"
			else:
				msg = L.t("ui.trap_modal.dissipe_ko")
				_hit_random(1.0)
			_roll_info.text += "   ·   💧 " + L.fa(L.t("ui.trap_modal.perd_endurance"), [who.get("name", "?"), cost])
		"probe":
			if good:
				_probe = float(s.probeBonus)
				msg = L.fa(L.t("ui.trap_modal.sonde_ok"), int(_probe))
			else:
				msg = L.t("ui.trap_modal.sonde_ko")
			_methods.erase("probe")
		"volunteer":
			if good:
				msg = L.fa(L.t("ui.trap_modal.volontaire_ok"), who.get("name", "?"))
				_hit_char(str(who.get("id", "")), float(s.volunteerDmgPct) / 100.0)
			else:
				msg = L.fa(L.t("ui.trap_modal.volontaire_ko"), who.get("name", "?"))
				_hit_char(str(who.get("id", "")), 1.0)
		"bypass":
			if good:
				_res.disarm = true
				msg = L.t("ui.trap_modal.contourne_ok")
				reward_src = "perfect" if roll == 20 else "dice"
			else:
				msg = L.t("ui.trap_modal.contourne_ko")
				_hit_all(float(s.bypassDmgPct) / 100.0)
	var col := Color("c7dd85") if good else (Color("ff5a5a") if outcome == "crit" else Color("b5b5b5"))
	if id == "probe":
		col = Color("9ad0ff")
	_result.text = msg
	_result.add_theme_color_override("font_color", col)
	match outcome:
		"perfect":
			_die.glow = Color("ffd76a")
			_set_glow(Color("ffd76a"), 18, 0.55, 44, 0.95, true)
			_spark_burst()
			Sound.sfx("level_up")
			Sound.sfx_later(0.38, "pickup")
			Sound.sfx_later(0.62, "level_up")
		"success":
			_die.glow = Color("b9d066")
			_die.glow.a = 0.6
			_set_glow(Color("96c85a"), 22, 0.5, 22, 0.5, false)
			Sound.sfx("door_locked")
			Sound.sfx_later(0.11, "pickup")
		"fail":
			_die.dim = Color(0.45, 0.45, 0.45)
			_set_glow(Color("969696"), 20, 0.4, 20, 0.4, false)
			_shake([Vector2(-4, 0), Vector2(4, 0), Vector2(-3, 0), Vector2(2, 0)], 0.5)
			Sound.sfx("hit")
		_:
			_die.dim = Color(0.6, 0.55, 0.55)
			_die.glow = Color("b3111a")
			_die.glow.a = 0.7
			_shake([Vector2(-11, 4), Vector2(10, -5), Vector2(-9, 3), Vector2(7, -3), Vector2(-4, 2)], 0.6)
			_set_glow(Color(0.59, 0.04, 0.08), 16, 0.6, 42, 0.95, true)
			_red_flash()
			Sound.sfx("hit")
			Sound.sfx_later(0.13, "hit")
	_die.queue_redraw()
	if id == "probe":
		_busy = false
		_stage = "after"
		_foot_show(false, false, true)
		_next = func(): _stage_choose()
		return
	_end_with("", col, reward_src, "dice", true)

## Fin d'une méthode qui résout le piège : récompense éventuelle, puis « Continuer » → résultat renvoyé au jeu.
func _end_with(msg: String, col: Color, reward_src: String, _kind: String, keep_text: bool = false) -> void:
	_stage = "after"
	_pz = null
	if not keep_text:
		_status.text = msg
		_status.add_theme_color_override("font_color", col)
	if reward_src != "":
		_res.reward = TrapRules.roll_reward(_s, reward_src)
	_foot_show(false, false, true)
	_next = func(): _finish()
	if not (_res.reward as Dictionary).is_empty():
		_next = func(): _stage_reward()

func _finish() -> void:
	Flows.close("trap")
	queue_free()
	resolved.emit(_res)

# ------------------------------------------------------------------ coups portés (affichage du blessé)

func _hit_random(mult: float) -> void:
	var h: Dictionary = _ctx.hit_random.call(mult)
	_res.hits = [h]
	_show_hits()

func _hit_char(id: String, mult: float) -> void:
	var h: Dictionary = _ctx.hit_char.call(id, mult)
	_res.hits = [h]
	_show_hits()

func _hit_all(mult: float) -> void:
	_res.hits = _ctx.hit_all.call(mult)
	_show_hits()

func _show_hits() -> void:
	var hits: Array = _res.hits
	if _victim == null or hits.is_empty():
		return
	if hits.size() == 1:
		_victim.text = L.fa(L.t("ui.trap_modal.subira_degats"), [hits[0].victim.name, int(hits[0].dmg)])
	else:
		_victim.text = L.t("ui.trap_modal.tout_le_groupe_subit")

# ------------------------------------------------------------------ étape : puzzle

func _stage_puzzle() -> void:
	_stage = "puzzle"
	_busy = true
	_clear_body()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(_lbl("%s %s" % [TrapRules.PUZZLE_ICONS[_puzzle], L.t("ui.trap_puzzle.name_%s" % str(_puzzle))], 17, Color("8fd0ff"), UiTheme.F_BODY_BOLD))
	var pz := TrapPuzzle.make(_puzzle, _s)
	_pz = pz
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(pz)
	_body.add_child(holder)
	pz.status.connect(func(t: String): _status.text = t)
	pz.hurt.connect(func(strong: bool):
		_shake([Vector2(-6, 2), Vector2(6, -2), Vector2(-4, 1), Vector2(3, 0)], 0.35)
		if strong:
			_red_flash())
	pz.finished.connect(func(ok: bool): _puzzle_done(ok))
	_foot_show(false, false, false)
	pz.begin()

func _puzzle_done(ok: bool) -> void:
	_status.text = " "
	if ok:
		_res.disarm = true
		_set_glow(Color("8fd0ff"), 20, 0.5, 40, 0.9, true)
		_spark_burst()
		Sound.sfx("level_up")
		_victim_msg(L.t("ui.trap_modal.puzzle_ok"), Color("8fd0ff"))
		_end_with("", Color("8fd0ff"), "puzzle", "puzzle", true)
	else:
		_hit_random(1.0)
		_set_glow(Color(0.59, 0.04, 0.08), 16, 0.6, 42, 0.95, true)
		_red_flash()
		var h: Array = _res.hits
		var extra := ""
		if not h.is_empty():
			extra = "\n" + L.fa(L.t("ui.trap_modal.subira_degats"), [h[0].victim.name, int(h[0].dmg)])
		_victim_msg(L.t("ui.trap_modal.puzzle_ko") + extra, Color("ff9a8a"))
		_end_with("", Color("ff9a8a"), "", "puzzle", true)

## Message de fin de puzzle : affiché en bandeau à la place du puzzle.
func _victim_msg(text: String, col: Color) -> void:
	_status.text = text.replace("\n", "  ·  ")
	_status.add_theme_color_override("font_color", col)

# ------------------------------------------------------------------ étape : butin

func _stage_reward() -> void:
	_clear_body()
	_body.alignment = BoxContainer.ALIGNMENT_CENTER
	var r: Dictionary = _res.reward
	_set_glow(Color("ffd76a"), 22, 0.6, 50, 1.0, true)
	var ttl := _lbl(L.t("ui.trap_modal.butin"), 20, Color("ffe08a"), UiTheme.F_TITLE_BOLD)
	_body.add_child(ttl)
	var icon := "💰" if r.kind == "gold" else ("✨" if r.kind == "xp" else "💖")
	var big := _lbl(icon, 72, Color.WHITE)
	big.custom_minimum_size = Vector2(0, 100)
	big.pivot_offset = Vector2((W - 90.0) * 0.5, 50.0)
	big.scale = Vector2.ZERO
	_body.add_child(big)
	var amount := _lbl("", 22, Color("efe1c2"), UiTheme.F_BODY_BOLD)
	_body.add_child(amount)
	var sub := _lbl(L.t("ui.trap_modal.butin_%s" % str(str(r.kind))), 13, UiTheme.DIM, UiTheme.F_BODY_ITALIC)
	_body.add_child(sub)
	ttl.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(ttl, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(big, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_spark_burst()
		if r.kind == "gold":
			Sound.coins()
		else:
			Sound.sfx("pickup"))
	var fmt: String = {"gold": "+%d 💰", "xp": "+%d XP", "heal": "+%d %% PV"}[r.kind]
	t.tween_method(func(v: float): amount.text = fmt % int(round(v)), 0.0, float(r.amount), 0.8)
	_foot_show(false, false, true)
	_next = func(): _finish()

# ------------------------------------------------------------------ effets

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

func _red_flash() -> void:
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 1.0, 0.1)
	t.tween_property(_flash, "modulate:a", 0.0, 0.6)

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
