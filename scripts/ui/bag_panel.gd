class_name BagPanel
extends VBoxContainer
## Besace commune (colonne de droite) : or, capacité, trois onglets à icône, grille défilante. Cliquer un objet l'ouvre.

signal item_pressed(index: int)
signal item_quick(index: int)      # clic droit : boire la potion / équiper l'objet (personnage actif)

const CAPACITY := Inventory.MAX_PER_TAB
const TAB_IDS := ["items", "potions", "keys"]
const TAB_ICONS := ["@icon:sword_broad", "@icon:potion_heal", "@icon:misc_key"]
const EMPTY := ["ui.bag_panel.aucun_objet_equipable", "ui.bag_panel.aucune_potion", "ui.bag_panel.aucune_cle_ni_parchemin"]
var gs: GameState
var _gold: Label
var _count: Label
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _grid: GridContainer
var _empty: Label
var _total: Label
var _sig := ""

func setup(state: GameState) -> void:
	gs = state
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
	add_child(head)
	head.add_child(BagCommon.coin(UiMetrics.rem(1.0)))
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.95)))
	_gold.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	_gold.add_theme_color_override("font_color", Color("ffd88a"))
	_gold.add_theme_color_override("font_shadow_color", Color.BLACK)
	_gold.add_theme_constant_override("shadow_offset_y", 1)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_gold)
	_total = Label.new()
	_total.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	_total.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
	_total.add_theme_color_override("font_color", UiTheme.DIM)
	head.add_child(_total)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UiMetrics.css(4.0)))
	add_child(tabs)
	for i in TAB_IDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(st, TrapBox.new(st in ["pressed", "hover_pressed"], st.begins_with("hover")))
		b.tooltip_text = Inventory.TAB_LABELS[TAB_IDS[i]]
		var idx := i
		b.pressed.connect(func(): _select(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var tsep := ColorRect.new()
	tsep.color = Color("070504")
	tsep.custom_minimum_size = Vector2(0, maxf(1.0, UiMetrics.css(2.0)))
	add_child(tsep)
	move_child(tsep, tabs.get_index() + 1)
	var inset := PanelContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color("080604")
	isb.set_content_margin_all(UiMetrics.css(6.0))
	isb.shadow_color = Color(0, 0, 0, 0.6)
	inset.add_theme_stylebox_override("panel", isb)
	add_child(inset)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 3.0 * (UiMetrics.css(40.0) + 4.0))
	inset.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	stack.add_child(_grid)
	_empty = Label.new()
	_empty.visible = false
	stack.add_child(_empty)
	var hint := Label.new()
	hint.text = L.t("ui.bag.legende")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	hint.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.66)))
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	add_child(hint)
	_select(0)

func _select(i: int) -> void:
	_tab = i
	_sig = ""
	refresh()

func select_tab_of(it: Dictionary) -> void:
	_tab = maxi(0, TAB_IDS.find(Inventory.tab_of(it)))
	_sig = ""
	refresh()

## Signature de ce qui est affiché : on ne reconstruit la grille que si quelque chose a changé.
func _signature() -> String:
	var parts: Array = [_tab, gs.gold, gs.active_char_id]
	for it in gs.inventory:
		parts.append(str(it.get("uid", it.get("id", ""))))
	var c := gs.char_by_id(gs.active_char_id)
	for slot in ["weapon", "head", "body", "hands", "feet", "accessory"]:
		var e = c.get("equipment", {}).get(slot)
		parts.append(str(e.get("uid", e.get("id", ""))) if e != null else "-")
	return "|".join(PackedStringArray(parts.map(func(x): return str(x))))

func refresh() -> void:
	var sig := _signature()
	if sig == _sig:
		return
	_sig = sig
	_gold.text = L.fa(L.t("ui.shop_modal.pieces_or"), gs.gold)
	var total := 0
	for i in _tab_buttons.size():
		var n := Inventory.tab_count(gs, TAB_IDS[i])
		total += n
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
		BagCommon.style_tab(_tab_buttons[i], TAB_ICONS[i], n, int(UiMetrics.rem(0.8)))
	_total.text = L.fa(L.t("ui.bag.total"), [total, Inventory.MAX_PER_TAB * TAB_IDS.size()])
	for ch in _grid.get_children():
		ch.queue_free()
	var stacks := {}
	var shown := 0
	var tiles: Array = []
	for idx in gs.inventory.size():
		var it: Dictionary = gs.inventory[idx]
		if Inventory.tab_of(it) != TAB_IDS[_tab]:
			continue
		var k := Inventory.stack_key(it)
		if k != "" and stacks.has(k):
			stacks[k].n += 1
			continue
		var e := {"it": it, "idx": idx, "n": 1}
		if k != "":
			stacks[k] = e
		tiles.append(e)
		shown += 1
	for e in tiles:
		var b := BagCommon.make_tile(gs, e.it, int(e.idx), int(e.n), false, 40.0, gs.active_char_id)
		var i2: int = e.idx
		b.pressed.connect(func(): item_pressed.emit(i2))
		b.quick.connect(func(i: int): item_quick.emit(i))
		UiFx.hover_pop(b, 1.07)
		_grid.add_child(b)
	var cells := maxi(CAPACITY, int(ceil(shown / 4.0)) * 4)
	for _i in range(shown, cells):
		_grid.add_child(BagCommon.empty_cell(40.0))
	_empty.text = ""


## Case d'objet de la besace : fond plat, aucun cadre, liseré ni halo autour de l'objet.
static func bare_tile(b: Button, selected: bool = false) -> void:
	var mk := func(c: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(UiMetrics.css(5.0)))
		sb.set_content_margin_all(UiMetrics.css(3.0))
		sb.set_border_width_all(0)
		sb.shadow_size = 0
		return sb
	var base: Color = Color("2a1f12") if selected else Color("120c07")
	var hot: Color = Color("33261a") if selected else Color("1c140c")
	b.add_theme_stylebox_override("normal", mk.call(base))
	b.add_theme_stylebox_override("pressed", mk.call(base))
	b.add_theme_stylebox_override("hover", mk.call(hot))
	b.add_theme_stylebox_override("hover_pressed", mk.call(hot))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

## Onglet trapèze de la besace (clip-path polygon(10% 0, 90% 0, 100% 100%, 0 100%)) : dégradé, reflet, filet or si actif.
class TrapBox extends StyleBox:
	var on: bool
	var hot: bool
	func _init(is_on: bool = false, is_hot: bool = false) -> void:
		on = is_on
		hot = is_hot
		content_margin_top = UiMetrics.css(7.0)
		content_margin_bottom = UiMetrics.css(6.0)
		content_margin_left = 0.0
		content_margin_right = 0.0
	func _draw(ci: RID, rect: Rect2) -> void:
		var p := PackedVector2Array([rect.position + Vector2(rect.size.x * 0.1, 0), rect.position + Vector2(rect.size.x * 0.9, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
		var top := Color("5a4631") if on else Color("3a2e21")
		var bot := Color("2a2018") if on else Color("1a140e")
		var a := 1.0 if (on or hot) else 0.75
		var cols := PackedColorArray()
		for v in p:
			cols.append((top if v.y <= rect.position.y + 0.5 else bot) * Color(1, 1, 1, a))
		RenderingServer.canvas_item_add_polygon(ci, p, cols)
		RenderingServer.canvas_item_add_line(ci, p[0] + Vector2(1, 0.5), p[1] - Vector2(1, -0.5), Color(1, 0.86, 0.67, 0.22 if on else 0.12), maxf(1.0, UiMetrics.css(1.0)))
		if on:
			var h := maxf(1.0, UiMetrics.css(2.0))
			RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position.x, rect.end.y - h, rect.size.x, h), Color("a9793a"))
