class_name BagPanel
extends VBoxContainer
## Besace : or et objets portés (affichage simple pour l'instant).

const CAPACITY := 12
var gs: GameState
var _gold: Label
var _grid: GridContainer

func setup(state: GameState) -> void:
	gs = state
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", UiTheme.GOLD)
	add_child(_gold)
	_grid = GridContainer.new()
	_grid.columns = 4
	add_child(_grid)
	refresh()

func refresh() -> void:
	_gold.text = "🪙 %d or        %d/%d" % [gs.gold, gs.inventory.size(), CAPACITY]
	for ch in _grid.get_children():
		ch.queue_free()
	for i in CAPACITY:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.add_theme_stylebox_override("panel", UiTheme.box(Color("0d0906"), UiTheme.BRONZE_DARK, 2, 4))
		if i < gs.inventory.size():
			var it: Dictionary = gs.inventory[i]
			var pic := TextureRect.new()
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture = IconResolver.texture(str(it.get("icon", "")))
			pic.tooltip_text = str(it.get("name", ""))
			slot.add_child(pic)
		_grid.add_child(slot)
