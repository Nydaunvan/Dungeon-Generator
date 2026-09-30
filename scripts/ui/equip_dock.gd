class_name EquipDock
extends Control
## Volet d'équipement (comme #eqpDock du HTML) : glisse depuis la droite. À gauche, les six emplacements autour du
## portrait + caractéristiques (volet « Détails et sorts » qui se déroule) ; à droite, la besace du groupe
## (onglets, grille, détail de l'objet avec comparaison) et les boutons Équiper / Jeter / Retirer / Utiliser.

signal changed            # équipement, besace ou PV modifiés
signal bag_changed
signal closed

const SLOT_DEFS := [
	{"id": "weapon", "label": "Arme"}, {"id": "head", "label": "Casque"}, {"id": "body", "label": "Armure"},
	{"id": "hands", "label": "Gants"}, {"id": "feet", "label": "Bottes"}, {"id": "accessory", "label": "Bijou"},
]
const TABS := [["items", "@icon:sword_broad"], ["potions", "@icon:potion_heal"], ["keys", "@icon:misc_key"]]

var gs: GameState
var ctrl: CombatController
var is_open: bool = false
var char_id: String = ""
var tab: String = "items"
var sel: Dictionary = {}          # {"src":"bag","key":..} | {"src":"slot","slot":..}
var details_open: bool = false

var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _tween: Tween
var _pulses: Array[Tween] = []

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.tbox("frame_panel", [12, 12, 12, 12], [16, 14, 16, 14]))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	get_viewport().size_changed.connect(_place)
	ctrl.changed.connect(_on_state_changed)

func _on_state_changed() -> void:
	if not is_open:
		return
	if ctrl.in_combat() or gs.game_over:
		close()   # indisponible en combat
		return
	var c := gs.char_by_id(char_id)
	if c.is_empty() or int(c.hp) <= 0:
		close()
		return
	if gs.active_char_id != char_id:
		char_id = gs.active_char_id
		sel = {}
	_render()

# ------------------------------------------------------------------ ouverture / fermeture

func _target_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var w := minf(700.0, vp.x - 16.0)
	var top := clampf(vp.y * 0.09, 40.0, 80.0)
	return Rect2(vp.x - w - 8.0, top, w, vp.y - top - 8.0)

func _place() -> void:
	var r := _target_rect()
	_panel.size = r.size
	_panel.position = r.position if is_open else Vector2(get_viewport_rect().size.x + 30.0, r.position.y)

func toggle_for(id: String) -> void:
	if is_open and char_id == id:
		close()
	else:
		open_for(id)

func open_for(id: String, select_item: Dictionary = {}) -> void:
	var c := gs.char_by_id(id)
	if c.is_empty() or int(c.hp) <= 0 or ctrl.in_combat():
		return
	char_id = id
	gs.active_char_id = id
	sel = {}
	if not select_item.is_empty():
		tab = Inventory.tab_of(select_item)
		sel = {"src": "bag", "key": _key_of(select_item)}
	var was_open := is_open
	is_open = true
	visible = true
	_render()
	var r := _target_rect()
	_panel.size = r.size
	if not was_open:
		_panel.position = Vector2(get_viewport_rect().size.x + 30.0, r.position.y)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position", r.position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ctrl.changed.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	sel = {}
	details_open = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:x", get_viewport_rect().size.x + 30.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = false)
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ données

func _key_of(it: Dictionary) -> String:
	var k := Inventory.stack_key(it)
	return "k:" + k if k != "" else "i:" + str(it.get("uid", it.get("id", "")))

## Entrées de l'onglet : une par pile / objet, {key, it, idx, count}.
func _entries() -> Array:
	var out: Array = []
	var seen := {}
	for idx in gs.inventory.size():
		var it: Dictionary = gs.inventory[idx]
		if Inventory.tab_of(it) != tab:
			continue
		var sk := Inventory.stack_key(it)
		if sk != "":
			if seen.has(sk):
				seen[sk].count += 1
				continue
			var e := {"key": "k:" + sk, "it": it, "idx": idx, "count": 1}
			seen[sk] = e
			out.append(e)
		else:
			out.append({"key": _key_of(it), "it": it, "idx": idx, "count": 1})
	return out

func _resolve_sel(c: Dictionary) -> Dictionary:
	if sel.is_empty():
		return {}
	if sel.src == "bag":
		for e in _entries():
			if e.key == sel.key:
				return {"src": "bag", "it": e.it, "idx": e.idx, "count": e.count}
		sel = {}
		return {}
	var it = c.get("equipment", {}).get(sel.slot)
	if it == null:
		sel = {}
		return {}
	return {"src": "slot", "it": it, "slot": sel.slot}

static func stat_rows(it: Dictionary, force_atk: bool) -> Array:
	var rows: Array = []
	if force_atk:
		rows.append({"key": "atkMin", "label": "Attaque min", "value": int(it.get("bonusAtkMin", 0))})
		rows.append({"key": "atkMax", "label": "Attaque max", "value": int(it.get("bonusAtkMax", 0))})
	if int(it.get("bonusHp", 0)) != 0:
		rows.append({"key": "hp", "label": "PV", "value": int(it.bonusHp)})
	if not force_atk and (int(it.get("bonusAtkMin", 0)) != 0 or int(it.get("bonusAtkMax", 0)) != 0):
		rows.append({"key": "atkMin", "label": "Attaque min", "value": int(it.get("bonusAtkMin", 0))})
		rows.append({"key": "atkMax", "label": "Attaque max", "value": int(it.get("bonusAtkMax", 0))})
	for pair in [["bonusSpellDmg", "spellDmg", "Dégâts de sort"], ["bonusForce", "force", "Force"], ["bonusDex", "dex", "Dextérité"],
			["bonusCon", "con", "Constitution"], ["bonusInt", "int", "Intelligence"], ["bonusSpeed", "speed", "Vitesse"]]:
		if int(it.get(pair[0], 0)) != 0:
			rows.append({"key": pair[1], "label": pair[2], "value": int(it[pair[0]])})
	return rows

static func type_label(it: Dictionary) -> String:
	if bool(it.get("legendary", false)):
		return "✨ Légendaire"
	match str(it.get("type", "")):
		"weapon": return "Arme"
		"jewelry": return "Bijou"
		"armor":
			for s in SLOT_DEFS:
				if s.id == it.get("slot"):
					return str(s.label)
			return "Armure"
		"potion": return "Potion"
		"key": return "Clé"
		"scroll": return "Parchemin"
	return "Objet"

# ------------------------------------------------------------------ rendu

func _render() -> void:
	var c := gs.char_by_id(char_id)
	if c.is_empty():
		return
	var keep := _scroll.scroll_vertical
	for t in _pulses:
		t.kill()
	_pulses.clear()
	for ch in _body.get_children():
		ch.queue_free()
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var resolved := _resolve_sel(c)
	_body.add_child(_build_head(c, cls))
	var sep := ColorRect.new()
	sep.color = Color("6a5030")
	sep.custom_minimum_size = Vector2(0, 1)
	_body.add_child(sep)
	var cols := HFlowContainer.new()
	cols.add_theme_constant_override("h_separation", 14)
	cols.add_theme_constant_override("v_separation", 10)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(cols)
	cols.add_child(_build_left(c, cls, resolved))
	cols.add_child(_build_right(c, resolved))
	_body.add_child(_build_drawer(c))
	await get_tree().process_frame
	_scroll.scroll_vertical = keep

func _label(text: String, size: int = 14, color: Color = UiTheme.PARCH, font_path: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font_path != "":
		l.add_theme_font_override("font", UiTheme.font(font_path))
	return l

func _build_head(c: Dictionary, cls: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ico := UiTheme.portrait(IconResolver.texture(str(cls.get("icon", ""))), UiTheme.BRONZE_LIGHT, 48)
	row.add_child(ico)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	var title := _label("ÉQUIPEMENT — " + str(c.name).to_upper(), 17, UiTheme.GOLD, UiTheme.F_TITLE_BOLD)
	title.clip_text = true
	v.add_child(title)
	v.add_child(_label("%s — Nv.%d" % [cls.get("name", ""), int(c.level)], 13, UiTheme.DIM))
	row.add_child(v)
	for m in gs.party:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(38, 38)
		var pp := IconResolver.portrait_path(m, gs.cfg)
		if pp != "":
			b.icon = load(pp)
		b.expand_icon = true
		b.disabled = int(m.hp) <= 0
		b.tooltip_text = str(m.name)
		var on: bool = str(m.id) == char_id
		b.modulate = Color(1, 1, 1, 1.0 if on else 0.6)
		if on:
			b.add_theme_stylebox_override("normal", UiTheme.round_button_style(UiTheme.GOLD, Color("150f08")))
		var mid: String = str(m.id)
		b.pressed.connect(func():
			gs.active_char_id = mid
			char_id = mid
			sel = {}
			ctrl.changed.emit())
		UiFx.hover_pop(b, 1.1)
		row.add_child(b)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(32, 32)
	x.pressed.connect(close)
	row.add_child(x)
	return row

func _slot_button(c: Dictionary, def: Dictionary, resolved: Dictionary) -> Control:
	var item = c.get("equipment", {}).get(def.id)
	var compat: bool = not resolved.is_empty() and resolved.src == "bag" and Inventory.slot_of(resolved.it) != ""
	var target: bool = compat and Inventory.slot_of(resolved.it) == def.id
	var dim: bool = compat and not target
	var is_sel: bool = not resolved.is_empty() and resolved.src == "slot" and resolved.slot == def.id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 64)
	b.size = Vector2(64, 64)
	var border := Color("3b2d18")
	var fill := Color("120c07")
	if item != null:
		border = Color("5f8f45")
		fill = Color("16200f")
		if bool(item.get("legendary", false)):
			border = Color("ffb84d")
	if is_sel or target:
		border = UiTheme.GOLD
	var sb := UiTheme.box(fill, border, 2, 8)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", UiTheme.box(fill, UiTheme.BRONZE_LIGHT if not (is_sel or target) else UiTheme.GOLD, 2, 8))
	if item != null:
		b.icon = IconResolver.texture(str(item.get("icon", "")))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var lbl := _label(str(def.label).to_upper(), 8, UiTheme.DIM, UiTheme.F_TITLE)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -14
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)
	if dim:
		b.modulate = Color(1, 1, 1, 0.35)
	if target:
		var glow := Panel.new()
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0, 0, 0, 0)
		gsb.border_color = Color("ffd88a")
		gsb.set_border_width_all(3)
		gsb.set_corner_radius_all(8)
		gsb.shadow_color = Color(1.0, 0.85, 0.5, 0.8)
		gsb.shadow_size = 10
		glow.add_theme_stylebox_override("panel", gsb)
		b.add_child(glow)
		_pulses.append(UiFx.pulse(glow, 0.1, 1.0, 1.1))
	var sid: String = str(def.id)
	b.pressed.connect(func(): _slot_clicked(sid))
	UiFx.hover_pop(b, 1.05)
	return b

func _build_left(c: Dictionary, _cls: Dictionary, resolved: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(290, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	# scène des emplacements
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(290, 300)
	stage.draw.connect(func():
		# halo doré derrière la figure
		for i in 8:
			var k := float(i) / 8.0
			stage.draw_circle(stage.size * 0.5, 130.0 * (1.0 - k), Color(0.91, 0.7, 0.36, 0.028)))
	col.add_child(stage)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	var port := UiTheme.portrait(load(pp) if pp != "" else null, UiTheme.BRONZE_LIGHT, 124)
	port.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	port.offset_left = -62
	port.offset_right = 62
	port.offset_top = -62
	port.offset_bottom = 62
	stage.add_child(port)
	var pos := {
		"head": [0.5, 0.0, -32, 4], "weapon": [0.0, 0.5, 6, -32], "body": [1.0, 0.5, -70, -32],
		"accessory": [0.0, 1.0, 34, -78], "hands": [0.5, 1.0, -32, -68], "feet": [1.0, 1.0, -98, -78],
	}
	for d in SLOT_DEFS:
		var sb := _slot_button(c, d, resolved)
		var p: Array = pos[d.id]
		sb.set_anchor(SIDE_LEFT, p[0])
		sb.set_anchor(SIDE_RIGHT, p[0])
		sb.set_anchor(SIDE_TOP, p[1])
		sb.set_anchor(SIDE_BOTTOM, p[1])
		sb.offset_left = p[2]
		sb.offset_right = p[2] + 64
		sb.offset_top = p[3]
		sb.offset_bottom = p[3] + 64
		stage.add_child(sb)
	# caractéristiques
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [10, 8, 10, 8]))
	col.add_child(box)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	box.add_child(bv)
	var hh := HBoxContainer.new()
	hh.add_child(_label("CARACTÉRISTIQUES", 13, UiTheme.GOLD, UiTheme.F_TITLE_BOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(sp)
	var more := Button.new()
	more.text = "Détails et sorts " + ("▴" if details_open else "▾")
	more.focus_mode = Control.FOCUS_NONE
	more.add_theme_font_size_override("font_size", 11)
	more.pressed.connect(_toggle_details)
	hh.add_child(more)
	bv.add_child(hh)
	var rows := [
		["PV", "%d/%d" % [int(c.hp), int(c.maxHp)]],
		["Endurance", "%d/%d" % [int(c.get("stamina", 0)), int(c.get("maxStamina", 100))]],
		["Attaque", "%d – %d" % [int(c.atkMin), int(c.atkMax)]],
		["For / Dex / Con / Int", "%d / %d / %d / %d" % [int(c.get("effForce", 0)), int(c.get("effDex", 0)), int(c.get("effCon", 0)), int(c.get("effInt", 0))]],
		["Vitesse", str(int(c.get("effSpeed", 10)))],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var a := _label(r[0], 14, UiTheme.DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label(r[1], 14, UiTheme.PARCH, UiTheme.F_BODY_BOLD))
		bv.add_child(h)
	return col

func _build_right(c: Dictionary, resolved: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(260, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	var th := HBoxContainer.new()
	var t := _label("BESACE DU GROUPE", 13, UiTheme.GOLD, UiTheme.F_TITLE_BOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(t)
	th.add_child(_label("%d/%d · %d or" % [Inventory.tab_count(gs, tab), Inventory.MAX_PER_TAB, gs.gold], 12, UiTheme.DIM))
	col.add_child(th)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for tdef in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(48, 30)
		b.icon = IconResolver.texture(tdef[1])
		b.expand_icon = true
		b.button_pressed = tab == tdef[0]
		b.tooltip_text = Inventory.TAB_LABELS[tdef[0]]
		var tid: String = tdef[0]
		b.pressed.connect(func():
			tab = tid
			sel = {}
			_render())
		tabs.add_child(b)
	col.add_child(tabs)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	var entries := _entries()
	var total := maxi(Inventory.MAX_PER_TAB, int(ceil(entries.size() / 4.0)) * 4)
	for i in total:
		var cell: Control
		if i < entries.size():
			var e: Dictionary = entries[i]
			var it: Dictionary = e.it
			var tile := Button.new()
			tile.focus_mode = Control.FOCUS_NONE
			tile.icon = IconResolver.texture(str(it.get("icon", "")))
			tile.expand_icon = true
			tile.tooltip_text = str(it.get("name", ""))
			var is_sel: bool = not resolved.is_empty() and resolved.src == "bag" and sel.get("key") == e.key
			var border := Color("3b2d18")
			if bool(it.get("legendary", false)):
				border = Color("ffb84d")
			if is_sel:
				border = UiTheme.GOLD
			var st := UiTheme.box(Color("120c07"), border, 2, 8)
			tile.add_theme_stylebox_override("normal", st)
			tile.add_theme_stylebox_override("pressed", st)
			tile.add_theme_stylebox_override("hover", UiTheme.box(Color("120c07"), UiTheme.GOLD if is_sel else UiTheme.BRONZE_LIGHT, 2, 8))
			if e.count > 1:
				var cnt := _label(str(e.count), 12, UiTheme.GOLD, UiTheme.F_BODY_BOLD)
				cnt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				cnt.offset_left = -24
				cnt.offset_top = -18
				cnt.offset_right = -4
				cnt.offset_bottom = -1
				cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				cnt.add_theme_constant_override("outline_size", 4)
				cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
				tile.add_child(cnt)
			var k: String = e.key
			tile.pressed.connect(func(): _bag_clicked(k))
			UiFx.hover_pop(tile, 1.06)
			cell = tile
		else:
			var empty := Panel.new()
			empty.add_theme_stylebox_override("panel", UiTheme.box(Color("120c07"), Color("3b2d18"), 2, 8))
			empty.modulate = Color(1, 1, 1, 0.3)
			cell = empty
		cell.custom_minimum_size = Vector2(56, 56)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	col.add_child(_build_detail(c, resolved))
	return col

func _build_detail(c: Dictionary, resolved: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [10, 10, 10, 10]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	if resolved.is_empty():
		var hint := "Touchez un objet : les emplacements où il peut être équipé s'illuminent. Touchez un emplacement équipé pour le consulter ou le retirer." if tab == "items" else "Touchez un objet pour voir son détail."
		var l := _label(hint, 13, UiTheme.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(200, 0)
		v.add_child(l)
		return box
	var it: Dictionary = resolved.it
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var ic := PanelContainer.new()
	ic.custom_minimum_size = Vector2(52, 52)
	ic.add_theme_stylebox_override("panel", UiTheme.box(Color("120c07"), Color("3b2d18"), 2, 8))
	var tr := TextureRect.new()
	tr.texture = IconResolver.texture(str(it.get("icon", "")))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.add_child(tr)
	head.add_child(ic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _label(str(it.get("name", "")).to_upper() + (" ×%d" % resolved.count if resolved.get("count", 1) > 1 else ""), 14, UiTheme.GOLD, UiTheme.F_TITLE_BOLD)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(120, 0)
	hv.add_child(nm)
	hv.add_child(_label(type_label(it), 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC))
	head.add_child(hv)
	v.add_child(head)
	var type := str(it.get("type", ""))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	if resolved.src == "slot":
		_add_stat_lines(v, it, c, "", false)
		actions.add_child(_action_button("Retirer", "neutral", func(): _unequip(str(resolved.slot))))
	elif Inventory.can_equip(it):
		var slot := Inventory.slot_of(it)
		_add_stat_lines(v, it, c, slot, true)
		actions.add_child(_action_button("Équiper", "go", func(): _equip(int(resolved.idx))))
		actions.add_child(_action_button("Jeter", "del", func(): _discard(int(resolved.idx))))
	elif type == "potion":
		for line in Inventory.describe(it, gs.cfg):
			var fl := _label(line, 13, UiTheme.PARCH)
			v.add_child(fl)
		actions.add_child(_action_button("Utiliser", "go", func(): _use_potion(int(resolved.idx))))
		actions.add_child(_action_button("Jeter", "del", func(): _discard(int(resolved.idx))))
	else:
		for line in Inventory.describe(it, gs.cfg):
			v.add_child(_label(line, 13, UiTheme.PARCH))
		if type == "scroll":
			v.add_child(_label("S'utilise en combat.", 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC))
		if type != "key":
			actions.add_child(_action_button("Jeter", "del", func(): _discard(int(resolved.idx))))
	if actions.get_child_count() > 0:
		v.add_child(actions)
	return box

func _add_stat_lines(v: VBoxContainer, it: Dictionary, c: Dictionary, slot: String, with_diff: bool) -> void:
	var is_w := str(it.get("type", "")) == "weapon"
	var rn := stat_rows(it, is_w)
	var eq = c.get("equipment", {}).get(slot) if (with_diff and slot != "") else null
	var re: Array = stat_rows(eq, is_w) if eq != null else []
	var emap := {}
	for r in re:
		emap[r.key] = r.value
	var keys: Array = []
	var seen := {}
	for r in rn + re:
		if not seen.has(r.key):
			seen[r.key] = true
			keys.append(r)
	for r in keys:
		var val := 0
		for x in rn:
			if x.key == r.key:
				val = int(x.value)
		var h := HBoxContainer.new()
		var a := _label(str(r.label), 13, UiTheme.PARCH)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label("%s%d" % ["+" if val > 0 else "", val], 13, UiTheme.PARCH))
		if eq != null:
			var d := val - int(emap.get(r.key, 0))
			var col := Color("8fd46a") if d > 0 else (Color("e58a8a") if d < 0 else UiTheme.DIM)
			h.add_child(_label(" (%s)" % (("+%d" % d) if d > 0 else (str(d) if d < 0 else "=")), 13, col))
		v.add_child(h)

func _action_button(text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 12)
	var top := Color("2f6a2a")
	var bot := Color("1b3d18")
	var edge := Color("6faa5a")
	if kind == "del":
		top = Color("7a2f22")
		bot = Color("421811")
		edge = Color("b5533c")
	elif kind == "neutral":
		top = Color("4a3820")
		bot = Color("2a1e0f")
		edge = UiTheme.BRONZE_LIGHT
	var sb := UiTheme.box(top, edge, 2, 5)
	var sb_h := UiTheme.box(top.lightened(0.15), edge.lightened(0.2), 2, 5)
	var sb_p := UiTheme.box(bot, edge, 2, 5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.pressed.connect(func(): cb.call())
	UiFx.hover_pop(b, 1.03)
	return b

# volet « Détails et sorts » qui se déroule
var _drawer_clip: Control
var _drawer_inner: VBoxContainer
var _anim_drawer: bool = false

func _build_drawer(c: Dictionary) -> Control:
	_drawer_clip = Control.new()
	_drawer_clip.clip_contents = true
	_drawer_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer_inner = VBoxContainer.new()
	_drawer_inner.add_theme_constant_override("separation", 4)
	_drawer_inner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_drawer_clip.add_child(_drawer_inner)
	var sep := ColorRect.new()
	sep.color = Color("6a5030")
	sep.custom_minimum_size = Vector2(0, 1)
	_drawer_inner.add_child(sep)
	_drawer_inner.add_child(_label("STATISTIQUES", 13, UiTheme.GOLD, UiTheme.F_TITLE_BOLD))
	for line in [
		"Force %d · Dextérité %d · Constitution %d · Intelligence %d" % [int(c.get("effForce", 0)), int(c.get("effDex", 0)), int(c.get("effCon", 0)), int(c.get("effInt", 0))],
		"Dégâts de sort +%d · XP %d / %d" % [int(c.get("bonusSpellDmg", 0)), int(c.get("xp", 0)), int(c.get("xpToNext", 1))],
	]:
		_drawer_inner.add_child(_label(line, 13))
	_drawer_inner.add_child(_label("SORTS ET CAPACITÉS", 13, UiTheme.GOLD, UiTheme.F_TITLE_BOLD))
	var known: Array = c.get("spellsKnown", [])
	if known.is_empty():
		_drawer_inner.add_child(_label("Aucune compétence apprise.", 13, UiTheme.DIM, UiTheme.F_BODY_ITALIC))
	for sid in known:
		for sp in gs.cfg.get("spells", []):
			if sp.get("id") == sid:
				var ic := str(sp.get("icon", ""))
				var l := _label("%s %s — %s · endurance %d · recharge %d s" % [("" if ic.begins_with("@icon:") else ic), sp.name, Interactions.spell_effect(sp), int(sp.get("staminaCost", 0)), int(sp.get("cooldownSec", 0))], 13)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(200, 0)
				_drawer_inner.add_child(l)
	_drawer_clip.custom_minimum_size = Vector2(0, 0)
	if details_open:
		call_deferred("_grow_drawer", _anim_drawer)
		_anim_drawer = false
	return _drawer_clip

func _grow_drawer(animate: bool) -> void:
	if _drawer_clip == null or not is_instance_valid(_drawer_clip):
		return
	var target := _drawer_inner.get_combined_minimum_size().y + 4.0
	if animate:
		var t := create_tween()
		t.tween_property(_drawer_clip, "custom_minimum_size:y", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_drawer_clip.custom_minimum_size.y = target

func _toggle_details() -> void:
	details_open = not details_open
	_anim_drawer = details_open
	_render()

# ------------------------------------------------------------------ actions

func _bag_clicked(key: String) -> void:
	if not sel.is_empty() and sel.src == "bag" and sel.key == key:
		sel = {}
	else:
		sel = {"src": "bag", "key": key}
	_render()

func _slot_clicked(slot: String) -> void:
	var c := gs.char_by_id(char_id)
	var resolved := _resolve_sel(c)
	if not resolved.is_empty() and resolved.src == "bag" and Inventory.slot_of(resolved.it) == slot:
		_equip(int(resolved.idx))
		return
	if c.get("equipment", {}).get(slot) == null:
		return
	if not sel.is_empty() and sel.src == "slot" and sel.slot == slot:
		sel = {}
	else:
		sel = {"src": "slot", "slot": slot}
	_render()

func _equip(idx: int) -> void:
	if Inventory.equip(gs, gs.char_by_id(char_id), idx):
		sel = {}
		_after()

func _unequip(slot: String) -> void:
	if Inventory.unequip(gs, gs.char_by_id(char_id), slot):
		sel = {}
		_after()

func _discard(idx: int) -> void:
	if Inventory.discard(gs, idx):
		sel = {}
		_after()

func _use_potion(idx: int) -> void:
	var healed := Inventory.use_potion(gs, gs.char_by_id(char_id), idx)
	if healed >= 0:
		sel = {}
		ctrl.potion_drunk(char_id, healed)
		bag_changed.emit()
		_render()

func _after() -> void:
	bag_changed.emit()
	ctrl.changed.emit()
	changed.emit()
