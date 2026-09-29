class_name BagPanel
extends VBoxContainer
## Besace commune : or, capacité et trois onglets (équipement / potions / clés).

signal item_pressed(index: int)

const CAPACITY := Inventory.MAX_PER_TAB
const TAB_IDS := ["items", "potions", "keys"]
const TABS := [["Équipement", "Aucun objet équipable."], ["Potions", "Aucune potion."], ["Clés", "Aucune clé ni parchemin."]]
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
	add_theme_constant_override("separation", 6)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", UiTheme.GOLD)
	add_child(_gold)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", UiTheme.DIM)
	add_child(_count)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i][0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		var idx := i
		b.pressed.connect(func(): _select(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var inset := PanelContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.custom_minimum_size = Vector2(0, 80)
	inset.add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [8, 8, 8, 8]))
	add_child(inset)
	var stack := VBoxContainer.new()
	inset.add_child(stack)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	stack.add_child(_grid)
	_empty = Label.new()
	_empty.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	_empty.add_theme_color_override("font_color", UiTheme.DIM.darkened(0.3))
	stack.add_child(_empty)
	_select(0)

func _select(i: int) -> void:
	_tab = i
	refresh()

func refresh() -> void:
	_gold.text = "%d pièces d'or" % gs.gold
	_count.text = "%d/%d" % [Inventory.tab_count(gs, TAB_IDS[_tab]), CAPACITY]
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	for ch in _grid.get_children():
		ch.queue_free()
	var stacks := {}   # clé de pile -> {btn, n}
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
		b.custom_minimum_size = Vector2(46, 46)
		b.icon = IconResolver.texture(str(it.get("icon", "")))
		b.expand_icon = true
		b.tooltip_text = str(it.get("name", ""))
		var i2 := idx
		b.pressed.connect(func(): item_pressed.emit(i2))
		var badge := Label.new()
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.offset_left = -28
		badge.offset_top = -18
		badge.offset_right = -3
		badge.offset_bottom = -1
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_constant_override("outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		_grid.add_child(b)
		if k != "":
			stacks[k] = {"n": 1, "badge": badge}
		shown += 1
	_empty.text = "" if shown > 0 else str(TABS[_tab][1])
