class_name StatTip
extends PanelContainer
## Fenêtre de survol d'une statistique, aux couleurs du jeu : une carte par statistique (titre + valeur, règle, calcul ligne à ligne,
## formules chiffrées, sources de modification avec leurs icônes). Plusieurs cartes se placent côte à côte et passent à la ligne
## selon la largeur de l'écran ; la fenêtre reste toujours entière dans l'écran (au-dessus du contrôle survolé, sinon dessous).
## Usage : `StatTip.attach(controle, func(): return StatExplain.many_data(c, cfg, ["force"]))` — le contenu est relu à chaque survol.

const GOLD := Color("e8b45c")
const DIM := Color("b9a880")
const PARCH := Color("f5ecd8")
const POS := Color("8fd18f")
const NEG := Color("e07a6a")
const GAP := 10.0
const CARD_MIN := 240.0
const CARD_MAX := 320.0

static var _inst: StatTip
static var _layer: CanvasLayer
static var _sig := ""
static var _enter_frame := -1
static var _host: Control = null

var _root: HFlowContainer

## Branche l'infobulle sur `ctrl` (et le rend sensible à la souris). `provider` : Callable sans argument qui renvoie un Array de sections.
static func attach(ctrl: Control, provider: Callable) -> void:
	if ctrl.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS
	ctrl.mouse_entered.connect(func(): _enter(ctrl, provider))
	ctrl.mouse_exited.connect(func(): _leave(ctrl))
	ctrl.tree_exiting.connect(func(): if _host == ctrl: hide_tip())

static func hide_tip() -> void:
	_sig = ""
	_host = null
	if _inst != null and is_instance_valid(_inst):
		_inst.visible = false

static func _leave(ctrl: Control) -> void:
	var frame := Engine.get_process_frames()
	await ctrl.get_tree().process_frame
	# on ne masque que si aucune autre cellule du même groupe n'a été survolée entre-temps (pas de clignotement d'une cellule à l'autre)
	if _enter_frame < frame and _host == ctrl:
		hide_tip()

static func _enter(ctrl: Control, provider: Callable) -> void:
	_enter_frame = Engine.get_process_frames()
	var sections: Array = provider.call()
	if sections.is_empty():
		return
	var sig := str(sections.hash())
	if _inst != null and is_instance_valid(_inst) and _inst.visible and sig == _sig and _host == ctrl:
		return
	_host = ctrl
	_sig = sig
	var t := _inst_for(ctrl)
	await t._show(ctrl, sections)

static func _inst_for(host: Control) -> StatTip:
	if _inst == null or not is_instance_valid(_inst):
		_inst = StatTip.new()
		_inst.name = "StatTip"
		_inst.visible = false
		_inst.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst.add_theme_stylebox_override("panel", FloatingTip.TipBox.new())
		_inst._root = HFlowContainer.new()
		_inst._root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inst._root.add_theme_constant_override("h_separation", int(GAP))
		_inst._root.add_theme_constant_override("v_separation", int(GAP))
		_inst.add_child(_inst._root)
		_layer = CanvasLayer.new()
		_layer.name = "StatTipLayer"
		_layer.layer = 215
		_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		_layer.add_child(_inst)
		host.get_tree().root.add_child(_layer)
	return _inst

static func _lbl(text: String, size: int, col: Color, font: String = UiTheme.F_BODY, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", UiTheme.font(font))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color("5a4630")
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func _tone_color(tone: String) -> Color:
	match tone:
		"pos": return POS
		"neg": return NEG
		"dim": return DIM
		"total": return GOLD
	return PARCH

## Une carte : en-tête, règle, calcul, formules, sources, plafond.
func _card(s: Dictionary, outer: float) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color("4a3a24")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(outer, 0)
	var width := outer - 18.0           # largeur utile à l'intérieur du cadre (marges 8 + filets)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(width, 0)
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# en-tête : icône, titre, valeur
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_lbl(str(s.icon), 20, PARCH))
	var title := _lbl(str(s.title), 17, GOLD, UiTheme.F_TITLE_BOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	head.add_child(_lbl(str(s.value), 22, s.color, UiTheme.F_TITLE_BOLD))
	v.add_child(head)
	v.add_child(_rule())
	if str(s.rule) != "":
		var r := _lbl(str(s.rule), 12, DIM, UiTheme.F_BODY_ITALIC, true)
		r.name = "rule"
		r.custom_minimum_size = Vector2(width, 0)
		v.add_child(r)
	# calcul ligne à ligne
	if not (s.rows as Array).is_empty():
		v.add_child(_section_title("🧮", L.t("ui.stat_explain.calcul")))
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 12)
		g.add_theme_constant_override("v_separation", 2)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for row in s.rows:
			var tone := str(row.tone)
			var k := _lbl(str(row.k), 13, PARCH if tone != "total" else GOLD, UiTheme.F_BODY if tone != "total" else UiTheme.F_BODY_BOLD, true)
			g.add_child(k)
			var val := _lbl(str(row.v), 14, _tone_color(tone), UiTheme.F_BODY_BOLD)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(val)
		v.add_child(g)
	# formules chiffrées
	for res in s.results:
		var rl := _lbl("→ " + str(res), 12, Color("f0d9a0"), UiTheme.F_BODY, true)
		rl.name = "result"
		rl.custom_minimum_size = Vector2(width, 0)
		v.add_child(rl)
	if str(s.note) != "":
		var nl := _lbl(str(s.note), 11, DIM, UiTheme.F_BODY_ITALIC, true)
		nl.custom_minimum_size = Vector2(width, 0)
		v.add_child(nl)
	# sources
	v.add_child(_section_title("🎒", L.t("ui.stat_explain.sources")))
	if (s.sources as Array).is_empty():
		var none := _lbl(L.t("ui.stat_explain.aucune_source"), 12, DIM, UiTheme.F_BODY_ITALIC, true)
		none.custom_minimum_size = Vector2(width, 0)
		v.add_child(none)
	for src in s.sources:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(src.icon) != "":
			h.add_child(IconPicker.icon_control(str(src.icon), 20.0))
		var nm := _lbl(str(src.name), 13, PARCH)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		h.add_child(nm)
		if str(src.tag) != "":
			h.add_child(_lbl(str(src.tag), 11, DIM, UiTheme.F_BODY_ITALIC))
		if str(src.value) != "":
			h.add_child(_lbl(str(src.value), 13, _tone_color(str(src.tone)), UiTheme.F_BODY_BOLD))
		v.add_child(h)
		# un objet qui modifie plusieurs valeurs : une seule entrée, le détail en dessous
		for part in src.get("parts", []):
			var ph := HBoxContainer.new()
			ph.add_theme_constant_override("separation", 6)
			ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(26, 0)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ph.add_child(sp)
			var pl := _lbl("↳ " + str(part.label), 12, DIM)
			pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ph.add_child(pl)
			ph.add_child(_lbl(str(part.value), 13, _tone_color(str(part.tone)), UiTheme.F_BODY_BOLD))
			v.add_child(ph)
	frame.add_child(v)
	return frame

func _section_title(icon: String, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_lbl(icon, 11, DIM))
	h.add_child(_lbl(text.to_upper(), 11, Color("c9a35c"), UiTheme.F_BODY_BOLD))
	return h

func _show(host: Control, sections: Array) -> void:
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	var view := host.get_viewport().get_visible_rect().size
	var avail := view.x * 0.94 - 30.0          # largeur utile (marges du cadre comprises)
	var n := sections.size()
	var cols := clampi(int(floor((avail + GAP) / (CARD_MIN + GAP))), 1, n)
	var cw := clampf((avail - GAP * (cols - 1)) / cols, CARD_MIN, CARD_MAX)
	cols = clampi(int(floor((avail + GAP) / (cw + GAP))), 1, n)
	var total_w := cols * cw + (cols - 1) * GAP
	_root.custom_minimum_size = Vector2(total_w, 0)
	for s in sections:
		_root.add_child(_card(s, cw))
	custom_minimum_size = Vector2(total_w + 24.0, 0)     # + marges du cadre : largeur connue d'emblée, sans dépendre de la mise en page
	size = Vector2(total_w + 24.0, 0)
	modulate.a = 0.0
	visible = true
	await host.get_tree().process_frame
	if not is_instance_valid(host) or _host != host:
		return
	# trop haut pour l'écran : on retire les phrases de règle puis les formules (le calcul chiffré reste)
	for pass_name in ["rule", "result"]:
		if size.y > view.y - 12.0:
			for card in _root.get_children():
				for ch in card.get_child(0).get_children():
					if ch.name == pass_name:
						ch.visible = false
			size = Vector2(custom_minimum_size.x, 0)
			await host.get_tree().process_frame
			if not is_instance_valid(host) or _host != host:
				return
	size = Vector2(custom_minimum_size.x, 0)
	await host.get_tree().process_frame
	if not is_instance_valid(host) or _host != host:
		return
	var r := host.get_global_rect()
	var x := clampf(r.position.x + r.size.x * 0.5 - size.x * 0.5, 6.0, maxf(6.0, view.x - size.x - 6.0))
	var y := r.position.y - size.y - 12.0
	if y < 6.0:
		y = r.end.y + 12.0
	y = clampf(y, 6.0, maxf(6.0, view.y - size.y - 6.0))
	position = Vector2(x, y)
	modulate.a = 1.0
