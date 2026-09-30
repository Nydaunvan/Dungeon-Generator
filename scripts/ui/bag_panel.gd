class_name BagPanel
extends VBoxContainer
## Besace commune (colonne de droite) : or, capacité, trois onglets à icône, grille défilante. Cliquer un objet l'ouvre.

signal item_pressed(index: int)

const CAPACITY := Inventory.MAX_PER_TAB
const TAB_IDS := ["items", "potions", "keys"]
const TAB_EMOJI := ["⚒️", "🧪", "🗝️"]
const EMPTY := ["Aucun objet équipable.", "Aucune potion.", "Aucune clé ni parchemin."]
var gs: GameState
var _gold: Label
var _count: Label
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _grid: GridContainer
var _empty: Label

func setup(state: GameState) -> void:
	gs = state
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	_gold.add_theme_color_override("font_color", Color("ffd88a"))
	_gold.add_theme_color_override("font_shadow_color", Color.BLACK)
	_gold.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_gold)
	_count = Label.new()
	_count.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	_count.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
	_count.add_theme_color_override("font_color", UiTheme.DIM)
	add_child(_count)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UiMetrics.css(4.0)))
	add_child(tabs)
	for i in TAB_IDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = TAB_EMOJI[i]
		b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		b.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.0)))
		b.add_theme_color_override("font_color", Color("e2d2b0"))
		b.add_theme_color_override("font_pressed_color", Color("ffd88a"))
		b.add_theme_color_override("font_hover_color", Color("ffd88a"))
		b.add_theme_color_override("font_hover_pressed_color", Color("ffd88a"))
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
	_empty.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	_empty.add_theme_font_size_override("font_size", 14)
	_empty.add_theme_color_override("font_color", UiTheme.DIM.darkened(0.3))
	stack.add_child(_empty)
	_select(0)

func _select(i: int) -> void:
	_tab = i
	refresh()

func select_tab_of(it: Dictionary) -> void:
	_tab = maxi(0, TAB_IDS.find(Inventory.tab_of(it)))
	refresh()

func refresh() -> void:
	_gold.text = "💰 %d pièces d'or" % gs.gold
	_count.text = "🎒 %d/%d" % [Inventory.tab_count(gs, TAB_IDS[_tab]), CAPACITY]
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	for ch in _grid.get_children():
		ch.queue_free()
	var stacks := {}
	var shown := 0
	for idx in gs.inventory.size():
		var it: Dictionary = gs.inventory[idx]
		if Inventory.tab_of(it) != TAB_IDS[_tab]:
			continue
		var k := Inventory.stack_key(it)
		if k != "" and stacks.has(k):
			stacks[k].n += 1
			stacks[k].badge.text = "×%d" % stacks[k].n
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = IconResolver.texture(str(it.get("icon", "")))
		b.expand_icon = true
		bare_tile(b)
		b.tooltip_text = str(it.get("name", ""))
		var i2 := idx
		b.pressed.connect(func(): item_pressed.emit(i2))
		UiFx.hover_pop(b, 1.07)
		var badge := Label.new()
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -30
		badge.offset_top = -18
		badge.offset_right = -3
		badge.offset_bottom = -1
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", UiTheme.GOLD)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_grid.add_child(b)
		if k != "":
			stacks[k] = {"n": 1, "badge": badge}
		shown += 1
	_empty.text = "" if shown > 0 else str(EMPTY[_tab])


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
