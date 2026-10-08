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
static func style_tab(b: Button, icon: String, count: int, font_px: int) -> void:
	b.icon = IconResolver.texture(icon)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(UiMetrics.css(26.0)))
	b.add_theme_constant_override("h_separation", int(UiMetrics.css(6.0)))
	b.text = "%d/%d" % [count, Inventory.MAX_PER_TAB]
	var full := count >= Inventory.MAX_PER_TAB
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
	b.add_theme_font_size_override("font_size", font_px)
	var base := Color("ff7a62") if full else Color("e2d2b0")
	for k in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(k, base)
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, Color("ff9a82") if full else Color("ffd88a"))

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
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.icon = IconResolver.texture(str(it.get("icon", "")))
	b.expand_icon = true
	b.tooltip_text = str(it.get("name", ""))   # non vide : déclenche l'infobulle riche (_make_custom_tooltip)
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

## Contenu de l'infobulle : nom, type, caractéristiques (avec écart par rapport à l'objet équipé), objet remplacé.
static func tooltip_for(gs: GameState, it: Dictionary, char_id: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.box(Color("120c07"), Color("a9793a"), 1, 6))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(210, 0)
	box.add_child(v)
	var name_l := _lbl(L.c(str(it.get("name", ""))), 14, UiTheme.GOLD, UiTheme.F_TITLE_BOLD)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	v.add_child(_lbl(EquipDock.type_label(it), 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC))
	var c := gs.char_by_id(char_id)
	var slot := Inventory.slot_of(it)
	var eq = c.get("equipment", {}).get(slot) if slot != "" else null
	if slot != "":
		var is_w := str(it.get("type", "")) == "weapon"
		var rn := EquipDock.stat_rows(it, is_w)
		var emap := {}
		if eq != null:
			for r in EquipDock.stat_rows(eq, is_w):
				emap[r.key] = r.value
		var keys: Array = []
		var seen := {}
		for r in rn + (EquipDock.stat_rows(eq, is_w) if eq != null else []):
			if not seen.has(r.key):
				seen[r.key] = true
				keys.append(r)
		for r in keys:
			var val := 0
			for x in rn:
				if x.key == r.key:
					val = int(x.value)
			var h := HBoxContainer.new()
			var a := _lbl(str(r.label), 13, UiTheme.PARCH)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(a)
			h.add_child(_lbl("%s%d" % ["+" if val > 0 else "", val], 13, UiTheme.PARCH, UiTheme.F_BODY_BOLD))
			if eq != null:
				var d := val - int(emap.get(r.key, 0))
				var col := UP if d > 0 else (DOWN if d < 0 else UiTheme.DIM)
				h.add_child(_lbl(" (%s)" % (("+%d" % d) if d > 0 else (str(d) if d < 0 else "=")), 13, col))
			v.add_child(h)
		var foot := L.fa(L.t("ui.bag.remplace"), str(eq.get("name", ""))) if eq != null else L.t("ui.bag.emplacement_libre")
		v.add_child(_lbl(foot, 12, UiTheme.DIM, UiTheme.F_BODY_ITALIC))
	else:
		for line in Inventory.describe(it, gs.cfg):
			var l := _lbl(line, 13, UiTheme.PARCH)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
	return box

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

	func _make_custom_tooltip(_for_text: String) -> Object:
		return BagCommon.tooltip_for(gs, it, char_id)

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
