class_name BagPanel
extends VBoxContainer
## Besace commune : or, capacité et trois onglets (équipement / potions / clés).

const CAPACITY := 12
const TABS := [["Équipement", "Aucun objet équipable."], ["Potions", "Aucune potion."], ["Clés", "Aucune clé."]]
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

func _category(it: Dictionary) -> int:
	match str(it.get("type", "")):
		"weapon", "armor": return 0
		"potion": return 1
		"key": return 2
	return 0

func refresh() -> void:
	_gold.text = "%d pièces d'or" % gs.gold
	_count.text = "%d/%d" % [gs.inventory.size(), CAPACITY]
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	for ch in _grid.get_children():
		ch.queue_free()
	var shown := 0
	for it in gs.inventory:
		if _category(it) != _tab:
			continue
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(44, 44)
		slot.add_theme_stylebox_override("panel", UiTheme.tbox("btn_d", [10, 10, 10, 10], [4, 4, 4, 4]))
		var pic := TextureRect.new()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = IconResolver.texture(str(it.get("icon", "")))
		pic.tooltip_text = str(it.get("name", ""))
		slot.add_child(pic)
		_grid.add_child(slot)
		shown += 1
	_empty.text = "" if shown > 0 else str(TABS[_tab][1])
