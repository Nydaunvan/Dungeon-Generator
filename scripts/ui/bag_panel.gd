class_name BagPanel
extends VBoxContainer
## Inventaire commun du groupe (colonne de droite) : six onglets à icône (Tout, Armes, Armures, Potions, Clés, Parchemins),
## grille de cases sobres avec quantité visible, puis or, total et bouton « Inventaire ». Cliquer un objet l'ouvre.
## Les onglets ne filtrent que l'affichage : la capacité (12 par catégorie de l'inventaire) et les données sont inchangées.

signal item_pressed(index: int)
signal item_quick(index: int)      # clic droit : boire la potion / équiper l'objet (personnage actif)
signal inventory_pressed           # bouton « Inventaire » : ouvre l'inventaire du personnage actif

const CAPACITY := Inventory.MAX_PER_TAB
const COLS := 4
const GAP := 6.0
## [id, icône, clé de libellé, types affichés (vide = tous), catégorie de capacité]
const TABS := [
	["all", "floor", "ui.atlas.tab_all", [], ""],
	["weapon", "weapon", "ui.atlas.tab_weapons", ["weapon"], "weapons"],
	["armor", "shield", "ui.atlas.tab_armor", ["armor", "jewelry"], "armors"],
	["potion", "potion", "ui.atlas.tab_potions", ["potion"], "potions"],
	["scroll", "scroll", "ui.atlas.tab_scrolls", ["scroll"], "scrolls"],
	["key", "key", "ui.atlas.tab_keys", ["key"], "keys"],
]
var gs: GameState
var _gold: Label
var _tab: int = 0
var _tabs_row: HBoxContainer
var _tab_btns: Array[Button] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _total: Label
var _slot := 60.0
var _sig := ""
var avail_w := 0.0       ## largeur disponible imposée par la mise en page (0 = suivre la largeur réelle)

func setup(state: GameState) -> void:
	gs = state
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	# onglets
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 4)
	add_child(_tabs_row)
	for i in TABS.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Atlas.icon(TABS[i][1], 20, Atlas.IVORY, 1.6)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 20)
		b.tooltip_text = L.t(TABS[i][2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiMetrics.css(34.0))
		var idx := i
		b.pressed.connect(func(): _select(idx))
		b.draw.connect(func(): _draw_tab_dot(b, idx))
		_tabs_row.add_child(b)
		_tab_btns.append(b)
	# grille
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(GAP))
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_scroll.add_child(_grid)
	# pied : or, total, bouton
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
	add_child(foot)
	foot.add_child(BagCommon.coin(UiMetrics.rem(0.9)))
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.74)))
	_gold.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_BOLD))
	_gold.add_theme_color_override("font_color", Atlas.IVORY)
	_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_gold)
	_total = Label.new()
	_total.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_ITALIC))
	_total.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.68)))
	_total.add_theme_color_override("font_color", Atlas.IVORY_DIM)
	_total.tooltip_text = L.t("ui.bag.legende")
	_total.mouse_filter = Control.MOUSE_FILTER_PASS
	foot.add_child(_total)
	var inv_btn := Button.new()
	inv_btn.text = L.t("ui.bag.open_inventory").replace("🎒 ", "").to_upper()
	inv_btn.tooltip_text = L.t("ui.bag.open_inventory_tip")
	inv_btn.focus_mode = Control.FOCUS_NONE
	Atlas.style_button(inv_btn, "", UiMetrics.css(7.0))
	inv_btn.add_theme_font_override("font", Atlas.title_font(false, 1))
	inv_btn.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.55)))
	inv_btn.pressed.connect(func(): inventory_pressed.emit())
	foot.add_child(inv_btn)
	resized.connect(_apply_slot)
	_select(0)

## Pastille rouge sur l'onglet dont la catégorie de capacité est pleine.
func _draw_tab_dot(b: Button, i: int) -> void:
	var cat: String = TABS[i][4]
	if cat != "" and Inventory.tab_count(gs, cat) >= CAPACITY:
		b.draw_circle(Vector2(b.size.x - 7.0, 7.0), 3.0, Atlas.DANGER)

func set_avail(w: float) -> void:
	avail_w = w
	_apply_slot()

func _apply_slot() -> void:
	var avail := (avail_w if avail_w > 0.0 else size.x) - 2.0
	var s := clampf(floorf((avail - GAP * (COLS - 1)) / COLS), 34.0, 96.0)
	if absf(s - _slot) < 0.5:
		return
	_slot = s
	_scroll.custom_minimum_size = Vector2(0, 2.0 * s + GAP)
	_sig = ""
	refresh()

func _style_tabs() -> void:
	for i in _tab_btns.size():
		var on := i == _tab
		var st := Atlas.button_boxes("accent" if on else "", 2.0)
		for k in st:
			var bx: AtlasBox = st[k]
			bx.corners = Vector4(0, 1, 0, 1)
			if on:
				bx.border = Atlas.AMBER
				bx.fill_top = Color("2a302c")
				bx.fill_bottom = Color("1d2320")
			elif k == "normal" or k == "focus":
				bx.border = Color(Atlas.COPPER_DIM, 0.55)
			_tab_btns[i].add_theme_stylebox_override(k, bx)
		_tab_btns[i].icon = Atlas.icon(TABS[i][1], 20, Atlas.AMBER if on else Atlas.IVORY, 1.7)

func _select(i: int) -> void:
	_tab = i
	_sig = ""
	_style_tabs()
	refresh()

## Ouvre l'onglet le plus précis pour cet objet (utilisé quand on y pioche : ramassage, équipement…).
func select_tab_of(it: Dictionary) -> void:
	var t := str(it.get("type", ""))
	for i in range(1, TABS.size()):
		if (TABS[i][3] as Array).has(t):
			_tab = i
			_sig = ""
			_style_tabs()
			refresh()
			return
	_tab = 0
	_sig = ""
	_style_tabs()
	refresh()

## Signature de ce qui est affiché : on ne reconstruit la grille que si quelque chose a changé.
func _signature() -> String:
	var parts: Array = [_tab, gs.gold, gs.active_char_id, _slot]
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
	for cat in Inventory.CATS:
		total += Inventory.tab_count(gs, cat)
	var cat: String = TABS[_tab][4]
	if cat == "":
		_total.text = L.fa(L.t("ui.bag.total"), [total, Inventory.MAX_PER_TAB * Inventory.CATS.size()])
	else:    # onglet filtré : possédé / maximum de sa catégorie de capacité
		_total.text = L.fa(L.t("ui.bag.total"), [Inventory.tab_count(gs, cat), Inventory.MAX_PER_TAB])
	for b in _tab_btns:
		b.queue_redraw()
	for ch in _grid.get_children():
		ch.queue_free()
	var types: Array = TABS[_tab][3]
	var stacks := {}
	var tiles: Array = []
	for idx in gs.inventory.size():
		var it: Dictionary = gs.inventory[idx]
		if not types.is_empty() and not types.has(str(it.get("type", ""))):
			continue
		var k := Inventory.stack_key(it)
		if k != "" and stacks.has(k):
			stacks[k].n += 1
			continue
		var e := {"it": it, "idx": idx, "n": 1}
		if k != "":
			stacks[k] = e
		tiles.append(e)
	for e in tiles:
		var b := BagCommon.make_tile_atlas(gs, e.it, int(e.idx), int(e.n), false, _slot, gs.active_char_id)
		var i2: int = e.idx
		b.pressed.connect(func(): item_pressed.emit(i2))
		b.quick.connect(func(i: int): item_quick.emit(i))
		b.custom_minimum_size = Vector2(16, _slot)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(b)
	var min_cells := COLS * 2 if _tab == 0 else CAPACITY     # onglet filtré : les 12 emplacements de la catégorie sont visibles
	var cells := maxi(min_cells, int(ceil(tiles.size() / float(COLS))) * COLS)
	for _i in range(tiles.size(), cells):
		var ec := BagCommon.empty_cell_atlas(_slot)
		ec.custom_minimum_size = Vector2(16, _slot)
		ec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(ec)
