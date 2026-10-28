class_name BagCommon
extends RefCounted
## Éléments partagés par la besace de la colonne de droite (BagPanel) et par le volet d'équipement (EquipDock) :
## case d'objet teintée par type, repère ▲ / ▼ (meilleur / moins bon que l'équipé), infobulle détaillée, glisser-déposer.

const TINT := {
	"weapon": [Color("1a0f0a"), Color("6b3a24")],
	"armor": [Color("0f131a"), Color("3a4a60")],
	"potion": [Color("0c150f"), Color("2f5a3a")],
	"key": [Color("17130a"), Color("6a5a2a")],
	"other": [Color("120c07"), Color("2a1f12")],
}
const UP := Color("6fe08a")
const DOWN := Color("ff7a62")

static func kind_of(it: Dictionary) -> String:
	match str(it.get("type", "")):
		"weapon": return "weapon"
		"armor", "jewelry": return "armor"
		"potion": return "potion"
		"key", "scroll": return "key"
	return "other"

## Pastille d'or (cercle dégradé).
static func coin(size: float = 16.0) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e0a52c")
	sb.border_color = Color("6a430a")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(size))
	sb.shadow_color = Color(1.0, 0.8, 0.3, 0.35)
	sb.shadow_size = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Onglet de besace : icône + « n/12 » (rouge quand l'onglet est plein).
## Onglet « rail » : bouton d'icône carré avec pastille de compteur (le style dépend de l'état : voir `rail_style`).
static func rail_tab(icon: String, size: Vector2, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.icon = IconResolver.texture(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size.x * 0.62))
	b.tooltip_text = tip
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.66)))
	badge.add_child(l)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = UiMetrics.css(3.0)
	badge.offset_bottom = UiMetrics.css(3.0)
	b.add_child(badge)
	b.set_meta("badge", badge)
	b.set_meta("badge_label", l)
	return b

static func rail_style(b: Button, count: int, active: bool) -> void:
	var mk := func(bg: Color, bd: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(int(UiMetrics.css(8.0)))
		sb.set_content_margin_all(UiMetrics.css(4.0))
		sb.set_border_width_all(1)
		sb.border_color = bd
		if active:
			sb.shadow_color = Color(0.88, 0.64, 0.30, 0.22)
			sb.shadow_size = int(UiMetrics.css(6.0))
		return sb
	var bg := Color("2a2018") if active else Color("0b0805")
	var bd := Color("a9793a") if active else Color("241a11")
	for st in ["normal", "pressed"]:
		b.add_theme_stylebox_override(st, mk.call(bg, bd))
	for st in ["hover", "hover_pressed"]:
		b.add_theme_stylebox_override(st, mk.call(bg.lightened(0.05), Color("a9793a") if active else Color("5a4631")))
	var full := count >= Inventory.MAX_PER_TAB
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("7a2a1c") if full else Color("080604")
	bs.border_color = Color("ff7a62") if full else Color("5a4631")
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(int(UiMetrics.css(8.0)))
	bs.content_margin_left = UiMetrics.css(4.0)
	bs.content_margin_right = UiMetrics.css(4.0)
	bs.content_margin_top = 0.0
	bs.content_margin_bottom = 0.0
	(b.get_meta("badge") as PanelContainer).add_theme_stylebox_override("panel", bs)
	var l: Label = b.get_meta("badge_label")
	l.text = str(count)
	l.add_theme_color_override("font_color", Color("fff1d6") if full else Color("e2d2b0"))
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0 if active else 0.72, 0.18)

## Rail d'onglets verticaux : le tiret doré glisse d'un onglet à l'autre (`from` = onglet d'où il part, -1 = sans glissement).
class Rail extends Control:
	signal selected(index: int)
	var _btns: Array[Button] = []
	var _bar: ColorRect
	var _sz: Vector2
	var _sep: float
	var _pad: float
	var _active := -1
	var _tw: Tween

	func setup(defs: Array, sz: Vector2, sep: float, counts: Array, active: int, from: int = -1) -> void:
		_sz = sz
		_sep = sep
		_pad = UiMetrics.css(10.0)
		custom_minimum_size = Vector2(_pad + sz.x, defs.size() * sz.y + (defs.size() - 1) * sep)
		for i in defs.size():
			var b := BagCommon.rail_tab(defs[i][0], sz, defs[i][1])
			b.position = Vector2(_pad, i * (sz.y + sep))
			b.size = sz
			var idx := i
			b.pressed.connect(func(): selected.emit(idx))
			add_child(b)
			_btns.append(b)
		_bar = ColorRect.new()
		_bar.color = Color("e0a24c")
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.size = Vector2(maxf(2.0, UiMetrics.css(3.0)), sz.y * 0.6)
		_bar.position = Vector2(UiMetrics.css(1.0), _bar_y(from if from >= 0 else active))
		add_child(_bar)
		update(counts, active)

	func _bar_y(i: int) -> float:
		return i * (_sz.y + _sep) + _sz.y * 0.2

	func update(counts: Array, active: int) -> void:
		for i in _btns.size():
			BagCommon.rail_style(_btns[i], int(counts[i]), i == active)
		if active != _active:
			_active = active
			if _tw != null and _tw.is_valid():
				_tw.kill()
			_tw = create_tween()
			_tw.tween_property(_bar, "position:y", _bar_y(active), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Infobulle riche d'objet, dans une couche dédiée au-dessus de toute l'interface (volet, fenêtres, infobulles simples).
static var _tip_layer: CanvasLayer
static var _tip_node: Control

static func show_item_tip(host: Control, gs: GameState, it: Dictionary, char_id: String) -> void:
	hide_item_tip()
	if _tip_layer == null or not is_instance_valid(_tip_layer):
		_tip_layer = CanvasLayer.new()
		_tip_layer.name = "ItemTipLayer"
		_tip_layer.layer = 230
		host.get_tree().root.add_child(_tip_layer)
	var t := tooltip_for(gs, it, char_id)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = 0.0
	_tip_node = t
	_tip_layer.add_child(t)
	# La mise en page se fait sur plusieurs images (libellés à retour à la ligne : leur hauteur dépend de leur largeur) et un
	# contrôle ne rétrécit jamais tout seul : on le ramène à sa taille minimale réelle avant de l'afficher, puis on le replace
	# à chaque changement de taille pour qu'il reste collé à la case.
	t.resized.connect(func(): if is_instance_valid(host) and host.is_inside_tree(): _place_tip(host, t))
	for _i in 2:
		await host.get_tree().process_frame
		if not is_instance_valid(t) or _tip_node != t or not is_instance_valid(host) or not host.is_inside_tree():
			return
		t.reset_size()
	if not is_instance_valid(t):
		return
	_place_tip(host, t)
	t.modulate.a = 1.0

static func _place_tip(host: Control, t: Control) -> void:
	var r := host.get_global_rect()
	var vs := host.get_viewport().get_visible_rect().size
	var sz := t.get_combined_minimum_size()
	if t.size != sz:
		t.size = sz
	var x := clampf(r.position.x + r.size.x * 0.5 - sz.x * 0.5, 4.0, maxf(4.0, vs.x - sz.x - 4.0))
	var y := r.position.y - sz.y - 8.0
	if y < 4.0:
		y = minf(r.end.y + 8.0, vs.y - sz.y - 4.0)
	t.position = Vector2(x, y)

static func hide_item_tip() -> void:
	if _tip_node != null and is_instance_valid(_tip_node):
		_tip_node.queue_free()
	_tip_node = null

## Fond d'une case : teinte du type, liseré fin, cadre doré si sélectionnée.
static func style_tile(b: Button, it: Dictionary, selected: bool) -> void:
	var t: Array = TINT[kind_of(it)]
	var mk := func(lift: float) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = (t[0] as Color).lightened(lift)
		sb.set_corner_radius_all(int(UiMetrics.css(5.0)))
		sb.set_content_margin_all(UiMetrics.css(3.0))
		if selected:
			sb.border_color = Color("ffd88a")
			sb.set_border_width_all(2)
		elif Rarity.is_special(it) and ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
			sb.border_color = Rarity.color(it)      # liseré de la couleur de la rareté
			sb.set_border_width_all(2)
		else:
			sb.border_color = t[1]
			sb.set_border_width_all(1)
		return sb
	b.add_theme_stylebox_override("normal", mk.call(0.0))
	b.add_theme_stylebox_override("pressed", mk.call(0.0))
	b.add_theme_stylebox_override("hover", mk.call(0.08))
	b.add_theme_stylebox_override("hover_pressed", mk.call(0.08))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Case vide (emplacement libre).
static func empty_cell(min_size: float) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e0906")
	sb.set_corner_radius_all(int(UiMetrics.css(5.0)))
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(min_size, min_size)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Case d'objet. `idx` : indice (dans gs.inventory) de l'objet ou de la première pièce de la pile ; `count` : taille de la pile.
static func make_tile(gs: GameState, it: Dictionary, idx: int, count: int, selected: bool, min_size: float, char_id: String, double_click_quick: bool = false) -> Tile:
	var b := Tile.new()
	b.gs = gs
	b.it = it
	b.idx = idx
	b.char_id = char_id
	b.double_click_quick = double_click_quick
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_size, min_size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon = IconResolver.texture(str(it.get("icon", "")))
	b.expand_icon = true
	style_tile(b, it, selected)
	if count > 1:
		b.add_child(_corner_label("×%d" % count, Color("ffd88a"), false))
	var c := gs.char_by_id(char_id)
	var up := Inventory.upgrade(c, it)
	if up != 0:
		b.add_child(_corner_label("▲" if up > 0 else "▼", UP if up > 0 else DOWN, true))
	return b

static func _corner_label(text: String, col: Color, top_right: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top_right:
		l.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		l.offset_left = -22
		l.offset_right = -3
		l.offset_top = 1
		l.offset_bottom = 17
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		l.offset_left = -32
		l.offset_right = -3
		l.offset_top = -19
		l.offset_bottom = -1
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

## Fond d'une case Atlas : ardoise sombre, filet cuivre ; filet de la couleur de rareté pour les armes et armures rares ; ambre si sélectionnée.
static func style_tile_atlas(b: Button, it: Dictionary, selected: bool) -> void:
	var mk := func(lift: float) -> AtlasBox:
		var sb := AtlasBox.new(UiMetrics.css(4.0))
		sb.fill_top = Color("1f2521").lightened(lift)
		sb.fill_bottom = Color("151a17").lightened(lift)
		sb.cut = 5.0
		sb.corners = Vector4(0, 1, 0, 1)
		if selected:
			sb.border = Atlas.AMBER
		elif Rarity.is_special(it) and ["weapon", "armor", "jewelry"].has(str(it.get("type", ""))):
			sb.border = Color(Rarity.color(it), 0.85)
		else:
			sb.border = Atlas.COPPER_DIM
		return sb
	b.add_theme_stylebox_override("normal", mk.call(0.0))
	b.add_theme_stylebox_override("pressed", mk.call(0.0))
	b.add_theme_stylebox_override("hover", mk.call(0.06))
	b.add_theme_stylebox_override("hover_pressed", mk.call(0.06))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Case vide Atlas.
static func empty_cell_atlas(min_size: float) -> Control:
	var p := Panel.new()
	var sb := AtlasBox.new(0.0)
	sb.fill_top = Atlas.OBSIDIAN_DEEP
	sb.fill_bottom = Atlas.OBSIDIAN_DEEP
	sb.border = Color(Atlas.COPPER_DIM, 0.45)
	sb.cut = 5.0
	sb.corners = Vector4(0, 1, 0, 1)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(min_size, min_size)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Case d'objet Atlas : quantité toujours visible en bas à droite, repère ▲ / ▼ en haut à droite.
static func make_tile_atlas(gs: GameState, it: Dictionary, idx: int, count: int, selected: bool, min_size: float, char_id: String) -> Tile:
	var b := Tile.new()
	b.gs = gs
	b.it = it
	b.idx = idx
	b.char_id = char_id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_size, min_size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.icon = IconResolver.texture(str(it.get("icon", "")))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(min_size * 0.72))
	if b.icon == null:
		b.text = str(it.get("icon", ""))
		b.add_theme_font_size_override("font_size", int(min_size * 0.42))
	style_tile_atlas(b, it, selected)
	var q := _corner_label(str(count), Atlas.IVORY, false)
	q.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_BOLD))
	q.add_theme_font_size_override("font_size", maxi(10, int(min_size * 0.2)))
	q.add_theme_constant_override("outline_size", 3)
	b.add_child(q)
	var c := gs.char_by_id(char_id)
	var up := Inventory.upgrade(c, it)
	if up != 0:
		b.add_child(_corner_label("▲" if up > 0 else "▼", UP if up > 0 else DOWN, true))
	return b

## Contenu de l'infobulle d'un objet : voir `ItemTip` (en-tête, bloc principal, bonus avec écart, pouvoirs, pied).
static func tooltip_for(gs: GameState, it: Dictionary, char_id: String) -> Control:
	return ItemTip.build(gs, it, char_id)

static func _sg(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)

## Conséquence, pour ce personnage, du changement net d'une caractéristique (objet équipé à la place de l'ancien) : « → PV max +6 · garde +2 % ».
static func _effect_hint(c: Dictionary, key: String, d: int) -> String:
	if c.is_empty() or d == 0:
		return ""
	match key:
		"force":
			var f := int(c.get("effForce", 10))
			var dm := (f + d) / 3 - f / 3
			return L.fa(L.t("ui.bag.fx_force"), _sg(dm)) if dm != 0 else L.t("ui.bag.fx_force_none")
		"dex":
			var x := int(c.get("effDex", 10))
			return L.fa(L.t("ui.bag.fx_dex"), [_sg((x + d) / 4 - x / 4), _sg(Stats.crit_from_dex(x + d) - Stats.crit_from_dex(x)), _sg(Stats.dodge_from_dex(x + d) - Stats.dodge_from_dex(x))])
		"con":
			var k := int(c.get("effCon", 10))
			return L.fa(L.t("ui.bag.fx_con"), [_sg(3 * d), _sg(Stats.guard_from_con(k + d) - Stats.guard_from_con(k))])
		"int":
			var i := int(c.get("effInt", 10))
			return L.fa(L.t("ui.bag.fx_int"), _sg(Stats.spell_power(i + d) - Stats.spell_power(i)))
		"speed":
			return L.fa(L.t("ui.bag.fx_speed"), _sg(d))
		"spellDmg":
			return L.fa(L.t("ui.bag.fx_spelldmg"), _sg(d))
		"hp":
			return ""
	return ""

static func _lbl(text: String, size: int, color: Color, font_path: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font_path != "":
		l.add_theme_font_override("font", UiTheme.font(font_path))
	return l

## Case d'objet : clic droit (et double-clic dans le volet) = action rapide, glisser = équiper / jeter, infobulle riche.
class Tile extends Button:
	signal quick(index: int)
	var gs: GameState
	var it: Dictionary = {}
	var idx: int = -1
	var char_id: String = ""
	var double_click_quick: bool = false

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_RIGHT:
				quick.emit(idx)
				accept_event()
			elif ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click and double_click_quick:
				quick.emit(idx)
				accept_event()

	func _ready() -> void:
		mouse_entered.connect(func(): BagCommon.show_item_tip(self, gs, it, char_id))
		mouse_exited.connect(BagCommon.hide_item_tip)
		button_down.connect(BagCommon.hide_item_tip)
		tree_exiting.connect(BagCommon.hide_item_tip)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN:
			BagCommon.hide_item_tip()

	func _get_drag_data(_at: Vector2) -> Variant:
		var pic := TextureRect.new()
		pic.texture = icon
		pic.custom_minimum_size = Vector2(48, 48)
		pic.size = Vector2(48, 48)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.modulate = Color(1, 1, 1, 0.85)
		var holder := Control.new()
		holder.add_child(pic)
		pic.position = Vector2(-24, -24)
		set_drag_preview(holder)
		return {"kind": "bag_item", "idx": idx, "it": it}
