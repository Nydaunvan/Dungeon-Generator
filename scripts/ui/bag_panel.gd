class_name BagPanel
extends VBoxContainer
## Besace commune (colonne de droite) : or, capacité, trois onglets à icône, grille défilante. Cliquer un objet l'ouvre.

signal item_pressed(index: int)

const CAPACITY := Inventory.MAX_PER_TAB
const TAB_IDS := ["items", "potions", "keys"]
const TAB_ICONS := ["@icon:sword_broad", "@icon:potion_heal", "@icon:misc_key"]
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
	var top := HBoxContainer.new()
	add_child(top)
	_gold = Label.new()
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold.add_theme_color_override("font_color", UiTheme.GOLD)
	top.add_child(_gold)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", UiTheme.DIM)
	top.add_child(_count)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)
	for i in TAB_IDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = IconResolver.texture(TAB_ICONS[i])
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 26)
		b.tooltip_text = Inventory.TAB_LABELS[TAB_IDS[i]]
		var idx := i
		b.pressed.connect(func(): _select(idx))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var inset := PanelContainer.new()
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_theme_stylebox_override("panel", UiTheme.tbox("inset", [8, 8, 8, 8], [6, 6, 6, 6]))
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
	_gold.text = "%d pièces d'or" % gs.gold
	_count.text = "%d/%d" % [Inventory.tab_count(gs, TAB_IDS[_tab]), CAPACITY]
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
