class_name ExpeditionScreen
extends RefCounted
## Écran unique de la partie libre : composition du groupe (4 héros, classes de base), taille et difficulté du donjon, modificateurs d'expédition.
## Remplace les deux fenêtres « Génération aléatoire » puis « Modificateurs d'expédition ». Le groupe choisi part dans `build_config(…, picks)`.

const MAX_LEVELS := 8
const MIN_W := 13           # taille minimale d'un niveau : 13 × 11 (rien en dessous)
const MIN_H := 11
const MAX_DIM := 60
const MAX_MODS := 2
const MAX_SAME_CLASS := 2
const PRESETS := [["ui.expedition.petit", 13, 11, 3], ["ui.expedition.moyen", 20, 18, 4], ["ui.expedition.grand", 30, 30, 5], ["ui.expedition.colossal", 45, 45, 6]]
const DIFF_COLORS := {"easy": "8fd16a", "normal": "e8b45c", "hard": "ff8a4c", "hardcore": "ff4a3d"}
const DIFF_ICONS := {"easy": "🕊️", "normal": "⚔️", "hard": "💀", "hardcore": "🔥"}
const STAT_KEYS := ["ui.expedition.stat_for", "ui.expedition.stat_dex", "ui.expedition.stat_con", "ui.expedition.stat_int"]
## Couleur et texte de rôle de chaque classe de base (clé = identifiant de classe).
const CLASS_LOOK := {
	"class_warrior": ["e0553d", "ui.expedition.role_guerrier"], "class_archer": ["86c54e", "ui.expedition.role_archer"],
	"class_rogue": ["9a8cf0", "ui.expedition.role_roublard"], "class_mage": ["4fb0ff", "ui.expedition.role_mage"],
	"class_priest": ["f6d87a", "ui.expedition.role_pretre"], "class_bard": ["ff7cc8", "ui.expedition.role_barde"],
	"class_druid": ["42c78f", "ui.expedition.role_druide"],
}
## Modificateurs dont le PREMIER membre de la phrase est le bonus (sinon le premier est le revers et le second le bonus).
const BONUS_FIRST := ["mod_crit"]

var _host: Node
var _on_launch: Callable
var _modal: Modal
var _base: Dictionary
var _classes: Array = []            # définitions des classes de base
var _slots: Array = []              # [{c: indice de classe, p: indice de portrait}]
var _active := 0
var _levels := 3
var _width := 13
var _height := 11
var _diff := "normal"
var _mods: Array = []
var _rng := RandomNumberGenerator.new()

var _slot_row: HBoxContainer
var _tile_grid: GridContainer
var _pick_title: Label
var _detail: Label
var _party_tag: Label
var _map: MapPreview
var _cells: Label
var _dung_tag: Label
var _sliders := {}
var _slider_vals := {}
var _preset_row: HFlowContainer
var _diff_row: HBoxContainer
var _blurb: Label
var _mod_grid: GridContainer
var _mod_tag: Label
var _summary: Label
var _toast: Label
var _toast_tween: Tween

## Ouvre l'écran ; `on_launch(cfg)` reçoit la configuration générée (comme l'ancienne fenêtre).
static func open(host: Node, on_launch: Callable, prev: Dictionary = {}) -> void:
	var s := ExpeditionScreen.new()
	s._host = host
	s._on_launch = on_launch
	s._start(prev)

func _start(prev: Dictionary) -> void:
	_rng.randomize()
	_base = Data.config
	for c in _base.get("classes", []):
		if str(c.get("evolvesFrom", "")) == "" and CLASS_LOOK.has(str(c.id)):
			_classes.append(c)
	if _classes.is_empty():
		return
	_levels = clampi(int(prev.get("levels", 3)), 1, MAX_LEVELS)
	_width = clampi(int(prev.get("width", 13)), MIN_W, MAX_DIM)
	_height = clampi(int(prev.get("height", 11)), MIN_H, MAX_DIM)
	_diff = str(prev.get("diff", "normal"))
	for i in [0, 1, 3, 4]:
		_slots.append({"c": mini(i, _classes.size() - 1), "p": -1})
	for i in _slots.size():
		_slots[i].p = _free_portrait(i, int(_slots[i].c))
	var m := Modal.open_framed(_host, L.t("ui.expedition.titre"), 1060.0)
	_modal = m
	# le corps défile : on lui laisse la hauteur de l'écran moins l'en-tête, le résumé et les boutons (la fenêtre entière doit tenir à l'écran)
	var vp: Vector2 = _host.get_viewport().get_visible_rect().size if _host.is_inside_tree() else Vector2(1280, 720)
	m.fit_ratio = clampf((vp.y - UiMetrics.css(212.0)) / vp.y, 0.3, 0.8)
	m.set_meta("screen", self)          # garde l'écran en vie tant que la fenêtre existe
	var intro := m.add_text(L.t("ui.expedition.intro"), UiTheme.DIM, int(UiMetrics.rem(0.86)), true)
	intro.custom_minimum_size.x = 0
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_party(m.content)
	_build_dungeon(m.content)
	_build_mods(m.content)
	_toast = Label.new()
	_toast.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	_toast.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.78)))
	_toast.add_theme_color_override("font_color", Color("ffb199"))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	m.content.add_child(_toast)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	_summary.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
	_summary.add_theme_color_override("font_color", UiTheme.DIM)
	var body: Control = m.panel.body
	body.add_child(_summary)
	body.move_child(_summary, m._buttons_row.get_index())
	m.set_buttons([
		{"text": L.t("ui.expedition.generer"), "cb": _launch, "primary": true},
		{"text": L.t("common.annuler"), "cb": func(): m.close()},
	], true)
	_refresh_all()

# ------------------------------------------------------------------ utilitaires

func _cls_color(i: int) -> Color:
	return Color(str(CLASS_LOOK[str(_classes[i].id)][0]))

func _stats_of(i: int) -> Array:
	return DungeonGenerator.ARCHETYPE_STATS.get(str(_classes[i].name), [11, 11, 11, 11])

func _count(ci: int, skip: int) -> int:
	var n := 0
	for k in _slots.size():
		if k != skip and int(_slots[k].c) == ci:
			n += 1
	return n

func _portrait_count(ci: int) -> int:
	return int(DungeonGenerator.PORTRAIT_COUNTS.get(str(_classes[ci].name), 0))

func _portrait_path(ci: int, p: int) -> String:
	var f: String = str(DungeonGenerator.PORTRAIT_FILES.get(str(_classes[ci].name), ""))
	return "res://assets/portraits/%s_%d.webp" % [f, p] if f != "" and p >= 0 else ""

func _portrait_used(ci: int, p: int, skip: int) -> bool:
	var path := _portrait_path(ci, p)
	for k in _slots.size():
		if k == skip:
			continue
		var other := _portrait_path(int(_slots[k].c), int(_slots[k].p))
		if other == path or other == DungeonGenerator._portrait_twin(path) or DungeonGenerator._portrait_twin(other) == path:
			return true
	return false

## Un portrait de la classe pas encore pris par un autre héros (au hasard).
func _free_portrait(slot: int, ci: int) -> int:
	var free: Array = []
	for p in _portrait_count(ci):
		if not _portrait_used(ci, p, slot):
			free.append(p)
	return int(free[_rng.randi() % free.size()]) if not free.is_empty() else 0

func _assign(slot: int, ci: int) -> bool:
	if _count(ci, slot) >= MAX_SAME_CLASS:
		return false
	_slots[slot].c = ci
	_slots[slot].p = _free_portrait(slot, ci)
	return true

func _random_class_for(slot: int) -> int:
	var ok: Array = []
	for ci in _classes.size():
		if _count(ci, slot) < MAX_SAME_CLASS:
			ok.append(ci)
	return int(ok[_rng.randi() % ok.size()])

func _say(text: String) -> void:
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = _toast.create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)

static func _title_label(text: String, size_rem: float, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(size_rem)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

static func _rule() -> Control:
	var r := ColorRect.new()
	r.color = UiTheme.BRONZE
	r.custom_minimum_size = Vector2(0, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## Titre de section : filet, titre doré, pastille d'état, filet.
func _section(parent: Control, title: String) -> Label:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiMetrics.css(8.0))
	parent.add_child(gap)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
	h.add_child(_rule())
	h.add_child(_title_label(title.to_upper(), 1.0, UiTheme.GOLD))
	var tag := Label.new()
	tag.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	tag.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.62)))
	tag.add_theme_color_override("font_color", UiTheme.DIM)
	var pill := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.border_color = UiTheme.BRONZE_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(99)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", sb)
	pill.add_child(tag)
	h.add_child(pill)
	h.add_child(_rule())
	parent.add_child(h)
	return tag

static func _box(pad: float = 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b130c")
	sb.border_color = UiTheme.BRONZE_DARK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(UiMetrics.css(8.0)))
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.set_content_margin_all(UiMetrics.css(pad))
	p.add_theme_stylebox_override("panel", sb)
	return p

static func _chip(text: String, on: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.62)))
	b.add_theme_color_override("font_color", Color("1a0f05") if on else Color("e2d2b0"))
	b.add_theme_color_override("font_hover_color", Color("1a0f05") if on else Color("fff0c8"))
	for k in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.GOLD if on else (Color("4a3820") if k == "hover" else UiTheme.BRONZE_DARK)
		sb.border_color = UiTheme.GOLD if (on or k == "hover") else UiTheme.BRONZE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(99)
		sb.content_margin_left = UiMetrics.css(12.0)
		sb.content_margin_right = UiMetrics.css(12.0)
		sb.content_margin_top = UiMetrics.css(6.0)
		sb.content_margin_bottom = UiMetrics.css(6.0)
		b.add_theme_stylebox_override(k, sb)
	return b

# ------------------------------------------------------------------ compagnie

func _build_party(parent: Control) -> void:
	_party_tag = _section(parent, L.t("ui.expedition.compagnie"))
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
	parent.add_child(_slot_row)
	var box := _box()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	box.add_child(v)
	var head := HBoxContainer.new()
	_pick_title = _title_label("", 0.78, UiTheme.PARCH)
	_pick_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_pick_title)
	var all := _chip(L.t("ui.expedition.hasard_tous"))
	all.pressed.connect(_random_all)
	head.add_child(all)
	v.add_child(head)
	_tile_grid = GridContainer.new()
	_tile_grid.columns = _classes.size()
	_tile_grid.add_theme_constant_override("h_separation", int(UiMetrics.css(8.0)))
	v.add_child(_tile_grid)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	_detail.add_theme_color_override("font_color", UiTheme.DIM)
	v.add_child(_detail)
	_pick_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_pick_title.tooltip_text = L.t("ui.expedition.note_compagnie")      # la règle « 2 par classe » : en infobulle pour gagner de la place
	parent.add_child(box)

func _random_all() -> void:
	for i in _slots.size():
		_slots[i].c = -1
	for i in _slots.size():
		_slots[i].c = _random_class_for(i)
		_slots[i].p = -1
	for i in _slots.size():
		_slots[i].p = _free_portrait(i, int(_slots[i].c))
	_say(L.t("ui.expedition.compagnie_tiree"))
	_refresh_party()

func _refresh_party() -> void:
	for ch in _slot_row.get_children():
		ch.queue_free()
	for i in _slots.size():
		var ci := int(_slots[i].c)
		var card := ArchCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tex: Texture2D = null
		var pp := _portrait_path(ci, int(_slots[i].p))
		if pp != "" and ResourceLoader.exists(pp):
			tex = load(pp)
		var st := _stats_of(ci)
		card.setup(i, _cls_color(ci), tex, L.c(str(_classes[ci].name)), L.t(str(CLASS_LOOK[str(_classes[ci].id)][1])), st, i == _active)
		var idx := i
		card.picked.connect(func():
			_active = idx
			_refresh_party())
		card.portrait_step.connect(func(d: int):
			var n := _portrait_count(int(_slots[idx].c))
			var p := int(_slots[idx].p)
			for _k in n:
				p = (p + d + n) % n
				if not _portrait_used(int(_slots[idx].c), p, idx):
					break
			_slots[idx].p = p
			_refresh_party())
		card.rolled.connect(func():
			_slots[idx].c = _random_class_for(idx)
			_slots[idx].p = _free_portrait(idx, int(_slots[idx].c))
			_active = idx
			_refresh_party())
		_slot_row.add_child(card)
	_pick_title.text = L.fa(L.t("ui.expedition.classe_du_heros"), _active + 1)
	var cur := int(_slots[_active].c)
	for ch in _tile_grid.get_children():
		ch.queue_free()
	for ci in _classes.size():
		var tile := ClassTile.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pp2 := _portrait_path(ci, 0)
		var n := _count(ci, -1)
		tile.setup(_cls_color(ci), load(pp2) if pp2 != "" and ResourceLoader.exists(pp2) else null, L.c(str(_classes[ci].name)),
			L.fa(L.t("ui.expedition.dans_compagnie"), n) if n > 0 else "", ci == cur, _count(ci, _active) >= MAX_SAME_CLASS)
		var cidx := ci
		tile.pressed.connect(func():
			if not _assign(_active, cidx):
				_say(L.t("ui.expedition.deux_classe_max"))
				return
			_active = (_active + 1) % _slots.size()
			_refresh_party())
		_tile_grid.add_child(tile)
	var evo: Array = []
	for id in _classes[cur].get("evolvesTo", []):
		var def := Characters.class_def(_base, str(id))
		if not def.is_empty():
			evo.append(L.c(str(def.name)))
	_detail.text = L.fa(L.t("ui.expedition.detail_classe"), [L.c(str(_classes[cur].name)), L.t(str(CLASS_LOOK[str(_classes[cur].id)][1])).to_lower(), " · ".join(PackedStringArray(evo))])
	var kinds := {}
	for s in _slots:
		kinds[int(s.c)] = true
	_party_tag.text = L.fa(L.t("ui.expedition.classes_diff" if kinds.size() > 1 else "ui.expedition.classe_diff"), kinds.size())
	_refresh_summary()

# ------------------------------------------------------------------ donjon

func _build_dungeon(parent: Control) -> void:
	_dung_tag = _section(parent, L.t("ui.expedition.donjon"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
	parent.add_child(row)
	var left := _box()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	left.add_child(lv)
	_preset_row = HFlowContainer.new()
	_preset_row.add_theme_constant_override("h_separation", int(UiMetrics.css(6.0)))
	lv.add_child(_preset_row)
	_slider_row(lv, "levels", L.t("ui.expedition.niveaux"), 1, MAX_LEVELS, _levels)
	_slider_row(lv, "width", L.t("ui.expedition.largeur"), MIN_W, MAX_DIM, _width)
	_slider_row(lv, "height", L.t("ui.expedition.hauteur"), MIN_H, MAX_DIM, _height)
	_diff_row = HBoxContainer.new()
	_diff_row.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
	lv.add_child(_diff_row)
	_blurb = Label.new()
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size = Vector2(0, UiMetrics.rem(2.4))
	_blurb.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	_blurb.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
	_blurb.add_theme_color_override("font_color", UiTheme.DIM)
	lv.add_child(_blurb)
	var right := _box()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	right.add_child(rv)
	_map = MapPreview.new()
	_map.custom_minimum_size = Vector2(0, UiMetrics.css(190.0))
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_map)
	_cells = Label.new()
	_cells.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cells.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	_cells.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
	_cells.add_theme_color_override("font_color", UiTheme.DIM)
	rv.add_child(_cells)

func _slider_row(parent: Control, key: String, label: String, lo: int, hi: int, value: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
	var l := Label.new()
	l.text = label.to_upper()
	l.custom_minimum_size = Vector2(UiMetrics.css(84.0), 0)
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.62)))
	l.add_theme_color_override("font_color", UiTheme.DIM)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, UiMetrics.css(26.0))
	s.focus_mode = Control.FOCUS_NONE
	_style_slider(s)
	h.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(UiMetrics.css(40.0), 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	v.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.1)))
	v.add_theme_color_override("font_color", UiTheme.GOLD)
	h.add_child(v)
	parent.add_child(h)
	_sliders[key] = s
	_slider_vals[key] = v
	s.value_changed.connect(func(x: float):
		match key:
			"levels": _levels = int(x)
			"width": _width = int(x)
			"height": _height = int(x)
		_refresh_dungeon())

static func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color.BLACK
	track.border_color = UiTheme.BRONZE_DARK
	track.set_border_width_all(1)
	track.set_corner_radius_all(5)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c8892f")
	fill.set_corner_radius_all(5)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 12))
			if d <= 11.0:
				var c := Color("fff3c4").lerp(Color("a8661c"), clampf((Vector2(x, y).distance_to(Vector2(9, 8))) / 16.0, 0.0, 1.0))
				if d > 9.0:
					c = Color.BLACK
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)

func _refresh_dungeon() -> void:
	for k in _sliders:
		var s: HSlider = _sliders[k]
		var val: int = {"levels": _levels, "width": _width, "height": _height}[k]
		if int(s.value) != val:
			s.set_value_no_signal(val)
		(_slider_vals[k] as Label).text = str(val)
	for ch in _preset_row.get_children():
		ch.queue_free()
	for p in PRESETS:
		var on := int(p[1]) == _width and int(p[2]) == _height and int(p[3]) == _levels
		var b := _chip("%s · %d×%d" % [L.t(str(p[0])), int(p[1]), int(p[2])], on)
		var pp: Array = p
		b.pressed.connect(func():
			_width = int(pp[1])
			_height = int(pp[2])
			_levels = int(pp[3])
			_refresh_dungeon())
		_preset_row.add_child(b)
	for ch in _diff_row.get_children():
		ch.queue_free()
	for d in GeneratorDialog.DIFFS:
		var id := str(d[0])
		var col := Color(DIFF_COLORS[id])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = ""
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UiMetrics.css(74.0))
		b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.68)))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, col)
		for k in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			var on := id == _diff
			sb.bg_color = col.darkened(0.7) if on else (Color("1a130b") if k == "hover" else Color("0e0905"))
			sb.border_color = col if (on or k == "hover") else UiTheme.BRONZE_DARK
			sb.set_border_width_all(2 if on else 1)
			sb.set_corner_radius_all(int(UiMetrics.css(8.0)))
			if on:
				sb.shadow_color = Color(col.r, col.g, col.b, 0.45)
				sb.shadow_size = 8
			b.add_theme_stylebox_override(k, sb)
		var dv := VBoxContainer.new()
		dv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dv.alignment = BoxContainer.ALIGNMENT_CENTER
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Label.new()
		ic.text = str(DIFF_ICONS[id])
		ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.5)))
		dv.add_child(ic)
		var nm := _title_label((L.t(str(d[1])) if id != "hardcore" else "Hardcore").to_upper(), 0.68, col)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dv.add_child(nm)
		b.add_child(dv)
		var did := id
		b.pressed.connect(func():
			_diff = did
			_refresh_dungeon())
		_diff_row.add_child(b)
	for d in GeneratorDialog.DIFFS:
		if str(d[0]) == _diff:
			_blurb.text = L.t(str(GeneratorDialog.BLURBS[d[0]]))
	_map.set_dims(_levels, _width, _height)
	_cells.text = "%s\n%s" % [L.fa(L.t("ui.expedition.cases_total"), _levels * _width * _height),
		L.fa(L.t("ui.expedition.niveaux_de"), [_levels, _width, _height])]
	_dung_tag.text = L.fa(L.t("ui.expedition.resume_donjon"), [_levels, _width, _height])
	_refresh_summary()

# ------------------------------------------------------------------ modificateurs

func _build_mods(parent: Control) -> void:
	_mod_tag = _section(parent, L.t("ui.expedition.modificateurs"))
	_mod_grid = GridContainer.new()
	_mod_grid.columns = 3
	_mod_grid.add_theme_constant_override("h_separation", int(UiMetrics.css(10.0)))
	_mod_grid.add_theme_constant_override("v_separation", int(UiMetrics.css(10.0)))
	parent.add_child(_mod_grid)
	var note := Label.new()
	note.text = L.t("ui.expedition.note_mods")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	note.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
	note.add_theme_color_override("font_color", UiTheme.DIM)
	parent.add_child(note)

func _all_mods() -> Array:
	return DungeonGenerator.run_modifiers() + Unlocks.unlocked_modifiers()

func _refresh_mods() -> void:
	for ch in _mod_grid.get_children():
		ch.queue_free()
	for mod in _all_mods():
		var id := str(mod.id)
		var on := _mods.has(id)
		var clash := not on and not DungeonGenerator.conflicts(id, _mods).is_empty()
		var card := ModCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var parts := _split_mod(mod)
		card.setup(str(mod.icon), _mod_label(mod) + (" 🔓" if bool(mod.get("weeklyOnly", false)) else ""), parts[0], parts[1], on,
			(not on and _mods.size() >= MAX_MODS) or clash, int(mod.get("risk", 0)))
		card.pressed.connect(func():
			if _mods.has(id):
				_mods.erase(id)
			elif not DungeonGenerator.conflicts(id, _mods).is_empty():
				_say(L.fa(L.t("ui.expedition.incompatible"), _mod_label(_mod_by_id(str(DungeonGenerator.conflicts(id, _mods)[0])))))
				return
			elif _mods.size() < MAX_MODS:
				_mods.append(id)
			else:
				_say(L.t("ui.expedition.deux_mods_max"))
				return
			_refresh_mods())
		_mod_grid.add_child(card)
	_mod_tag.text = "%d / %d" % [_mods.size(), MAX_MODS]
	_refresh_summary()

func _mod_by_id(id: String) -> Dictionary:
	for m in _all_mods():
		if str(m.id) == id:
			return m
	return {}

static func _english() -> bool:
	return TranslationServer.get_locale().begins_with("en")

## Nom et description du modificateur dans la langue du jeu (les données portent les deux).
static func _mod_label(mod: Dictionary) -> String:
	return str(mod.get("labelEn", mod.get("labelFr", ""))) if _english() else str(mod.get("labelFr", ""))

static func _mod_desc(mod: Dictionary) -> String:
	return str(mod.get("descEn", mod.get("descFr", ""))) if _english() else str(mod.get("descFr", ""))

## Sépare la description « revers, mais bonus. » en [bonus, revers] ; une phrase d'un seul bloc reste neutre (bonus = "").
func _split_mod(mod: Dictionary) -> Array:
	var desc := _mod_desc(mod).strip_edges()
	for sep in [", mais ", ", but "]:
		var i := desc.find(sep)
		if i > 0:
			var a := desc.substr(0, i).strip_edges()
			var b := desc.substr(i + sep.length()).strip_edges().trim_suffix(".")
			a = a.substr(0, 1).to_upper() + a.substr(1)
			b = b.substr(0, 1).to_upper() + b.substr(1)
			return [a, b] if BONUS_FIRST.has(str(mod.id)) else [b, a]
	return ["", desc]

# ------------------------------------------------------------------ résumé et lancement

func _refresh_all() -> void:
	_refresh_party()
	_refresh_dungeon()
	_refresh_mods()

func _refresh_summary() -> void:
	if _summary == null:
		return
	var names: Array = []
	for s in _slots:
		names.append(L.c(str(_classes[int(s.c)].name)))
	var mods: Array = []
	for mod in _all_mods():
		if _mods.has(str(mod.id)):
			mods.append(_mod_label(mod))
	var dn := ""
	for d in GeneratorDialog.DIFFS:
		if str(d[0]) == _diff:
			dn = L.t(str(d[1])) if _diff != "hardcore" else "Hardcore"
	_summary.text = "⚔ %s   ·   🗺 %d × %d × %d   ·   %s %s   ·   ✨ %s" % [" · ".join(PackedStringArray(names)), _levels, _width, _height,
		DIFF_ICONS[_diff], dn, " + ".join(PackedStringArray(mods)) if not mods.is_empty() else L.t("ui.expedition.aucun_mod")]

func _launch() -> void:
	var picks: Array = []
	for s in _slots:
		picks.append({"classId": str(_classes[int(s.c)].id), "portrait": int(s.p)})
	var mods: Array = []
	var valid: Array = _all_mods().map(func(x): return str(x.id))
	for id in _mods:
		if valid.has(str(id)) and mods.size() < MAX_MODS and DungeonGenerator.conflicts(str(id), mods).is_empty():
			mods.append(str(id))
	var l := clampi(_levels, 1, MAX_LEVELS)
	var w := clampi(_width, MIN_W, MAX_DIM)
	var h := clampi(_height, MIN_H, MAX_DIM)
	var diff := _diff
	var base: Dictionary = Data.config
	var cb := _on_launch
	_modal.close()
	Loader.generate(func(): return DungeonGenerator.build_config(base, l, w, h, diff, mods, 1, -1, picks), cb)

# ------------------------------------------------------------------ composants

## Carte de héros en arche : cadre de bronze (lumineux et pulsant quand elle est active), portrait rond, nom, rôle, quatre jauges, outils.
class ArchCard extends Control:
	signal picked
	signal portrait_step(delta: int)
	signal rolled
	var color := Color.WHITE
	var active := false
	var glow := 1.0
	var _tw: Tween

	func setup(slot: int, c: Color, tex: Texture2D, title: String, role: String, stats: Array, is_active: bool) -> void:
		color = c
		active = is_active
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(0, UiMetrics.css(262.0))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = UiMetrics.css(14.0)
		v.offset_right = -UiMetrics.css(14.0)
		v.offset_top = UiMetrics.css(28.0)
		v.offset_bottom = -UiMetrics.css(8.0)
		v.add_theme_constant_override("separation", int(UiMetrics.css(3.0)))
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(v)
		var pr := UiTheme.portrait(tex, c, UiMetrics.css(76.0))
		pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pr)
		var n := ExpeditionScreen._title_label(title.to_upper(), 0.98, c)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var r := Label.new()
		r.text = role
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.custom_minimum_size = Vector2(0, UiMetrics.rem(1.2))
		r.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
		r.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.72)))
		r.add_theme_color_override("font_color", UiTheme.DIM)
		v.add_child(r)
		for i in 4:
			var h := HBoxContainer.new()
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
			var l := Label.new()
			l.text = L.t(str(ExpeditionScreen.STAT_KEYS[i]))
			l.custom_minimum_size = Vector2(UiMetrics.css(34.0), 0)
			l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
			l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.55)))
			l.add_theme_color_override("font_color", UiTheme.DIM)
			h.add_child(l)
			var b := StatBar.new()
			b.value = float(stats[i]) / 18.0
			b.color = c
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.custom_minimum_size = Vector2(0, UiMetrics.css(7.0))
			h.add_child(b)
			v.add_child(h)
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(sp)
		var tools := HBoxContainer.new()
		tools.alignment = BoxContainer.ALIGNMENT_CENTER
		tools.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
		for t in [["", "prev"], ["🎲", "roll"], ["", "next"]]:
			var bt := Button.new()
			bt.text = str(t[0])
			bt.focus_mode = Control.FOCUS_NONE
			bt.custom_minimum_size = Vector2(UiMetrics.css(30.0), UiMetrics.css(30.0))
			for k in ["normal", "hover", "pressed"]:
				bt.add_theme_stylebox_override(k, UiTheme.round_button_style(UiTheme.GOLD if k == "hover" else UiTheme.BRONZE, Color("4a3820") if k == "hover" else Color("241a10")))
			var kind := str(t[1])
			if kind != "roll":
				var g := ArrowGlyph.new()
				g.dir = -1 if kind == "prev" else 1
				g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				g.mouse_filter = Control.MOUSE_FILTER_IGNORE
				bt.add_child(g)
			bt.pressed.connect(func():
				if kind == "prev":
					portrait_step.emit(-1)
				elif kind == "next":
					portrait_step.emit(1)
				else:
					rolled.emit())
			tools.add_child(bt)
		v.add_child(tools)
		var tag := ExpeditionScreen._title_label(L.fa(L.t("ui.expedition.heros_n"), slot + 1), 0.6, Color("120d09"))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		var pill := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(99)
		sb.border_color = Color.BLACK
		sb.set_border_width_all(2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		pill.add_theme_stylebox_override("panel", sb)
		pill.add_child(tag)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()          # centré sur toute la largeur de la carte, quelle que soit sa taille
		cc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		cc.offset_top = UiMetrics.css(4.0)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(pill)
		add_child(cc)
		if active:
			_tw = create_tween().set_loops()
			_tw.tween_property(self, "glow", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
			_tw.tween_property(self, "glow", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
		UiFx.hover_pop(self, 1.02)

	func _process(_d: float) -> void:
		if active:
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit()

	func _arch(r: Rect2, corner: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		var rad := r.size.x * 0.5
		var cx := r.position.x + rad
		var cy := r.position.y + rad
		for i in 25:
			var a := PI + PI * float(i) / 24.0
			p.append(Vector2(cx + cos(a) * rad, cy + sin(a) * rad))
		for c in [[r.end - Vector2(corner, corner), 0.0], [Vector2(r.position.x + corner, r.end.y - corner), PI * 0.5]]:
			for i in 5:
				var a: float = c[1] + float(i) / 4.0 * PI * 0.5
				p.append(c[0] + Vector2(cos(a), sin(a)) * corner)
		return p

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(-UiMetrics.css(6.0))
		var corner := UiMetrics.css(12.0)
		if active:
			for i in 4:
				var g := _arch(r.grow(UiMetrics.css(3.0 * (i + 1))), corner + 3.0 * (i + 1))
				draw_colored_polygon(g, Color(color.r, color.g, color.b, 0.12 * glow))
		var edge := color if active else UiTheme.BRONZE_LIGHT
		draw_colored_polygon(_arch(r.grow(UiMetrics.css(2.0)), corner + 2.0), Color.BLACK)
		draw_colored_polygon(_arch(r, corner), edge if active else UiTheme.BRONZE)
		var inner := r.grow(-UiMetrics.css(3.0))
		var poly := _arch(inner, corner - 2.0)
		var cols := PackedColorArray()
		for pt in poly:
			var t := clampf((pt.y - inner.position.y) / inner.size.y, 0.0, 1.0)
			cols.append(Color("2d2014").lerp(Color("100a06"), t))
		draw_polygon(poly, cols)

## Petit triangle doré des boutons de portrait (le caractère ◀ ▶ s'afficherait en emoji).
class ArrowGlyph extends Control:
	var dir := 1

	func _draw() -> void:
		var c := size * 0.5
		var h := minf(size.x, size.y) * 0.2
		var pts := PackedVector2Array([c + Vector2(dir * h, 0), c + Vector2(-dir * h * 0.8, -h), c + Vector2(-dir * h * 0.8, h)])
		draw_colored_polygon(pts, UiTheme.GOLD)

## Jauge fine d'une caractéristique.
class StatBar extends Control:
	var value := 0.5
	var color := Color.WHITE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BRONZE_DARK, false, 1.0)
		var w := (size.x - 2.0) * clampf(value, 0.0, 1.0)
		var steps := 12
		for i in steps:
			var x0 := 1.0 + w * i / steps
			draw_rect(Rect2(x0, 1.0, w / steps + 0.6, size.y - 2.0), color.darkened(0.45).lerp(color, float(i) / steps))

## Tuile de classe du sélecteur.
class ClassTile extends Button:
	func setup(c: Color, tex: Texture2D, title: String, sub: String, selected: bool, full: bool) -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, UiMetrics.css(80.0))
		for k in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = c.darkened(0.78) if (selected or k == "hover") else Color("0e0905")
			sb.border_color = c if (selected or k == "hover") else UiTheme.BRONZE_DARK
			sb.set_border_width_all(2 if selected else 1)
			sb.set_corner_radius_all(int(UiMetrics.css(8.0)))
			if selected:
				sb.shadow_color = Color(c.r, c.g, c.b, 0.5)
				sb.shadow_size = 8
			add_theme_stylebox_override(k, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", int(UiMetrics.css(3.0)))
		add_child(v)
		var pr := UiTheme.portrait(tex, c, UiMetrics.css(38.0), false)
		pr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pr)
		var n := ExpeditionScreen._title_label(title.to_upper(), 0.62, UiTheme.PARCH)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
		s.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.55)))
		s.add_theme_color_override("font_color", UiTheme.DIM)
		v.add_child(s)
		if full:
			modulate = Color(1, 1, 1, 0.4)
		UiFx.hover_pop(self, 1.04)

## Carte de modificateur : icône et nom, bonus (vert) et revers (rouge).
class ModCard extends Button:
	func setup(icon: String, title: String, bonus: String, malus: String, on: bool, dim: bool, risk: int = 0) -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, UiMetrics.css(152.0))
		for k in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("3a2810") if on else (Color("2a1d10") if k == "hover" else Color("1b130c"))
			sb.border_color = UiTheme.GOLD if on else (UiTheme.BRONZE_LIGHT if k == "hover" else UiTheme.BRONZE_DARK)
			sb.set_border_width_all(2 if on else 1)
			sb.set_corner_radius_all(int(UiMetrics.css(8.0)))
			if on:
				sb.shadow_color = Color(UiTheme.GOLD.r, UiTheme.GOLD.g, UiTheme.GOLD.b, 0.4)
				sb.shadow_size = 9
			add_theme_stylebox_override(k, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = UiMetrics.css(10.0)
		v.offset_right = -UiMetrics.css(10.0)
		v.offset_top = UiMetrics.css(8.0)
		v.offset_bottom = -UiMetrics.css(8.0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", int(UiMetrics.css(5.0)))
		add_child(v)
		var t := ExpeditionScreen._title_label("%s  %s" % [icon, title], 0.78, UiTheme.PARCH)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		if bonus != "":
			v.add_child(_pill(bonus, Color("7ab648"), Color("cfe9b2")))
		v.add_child(_pill(malus, Color("c0392b") if bonus != "" else UiTheme.BRONZE, Color("f0b8b0") if bonus != "" else UiTheme.PARCH))
		if risk > 0:
			var rk := Label.new()
			rk.text = "💀".repeat(risk)
			rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rk.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
			rk.add_theme_color_override("font_color", Color("e07a5f") if risk >= 3 else (Color("e8b45c") if risk == 2 else Color("9ec27a")))
			rk.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			rk.offset_left = -UiMetrics.css(70.0)
			rk.offset_right = -UiMetrics.css(10.0)
			rk.offset_top = -UiMetrics.css(24.0)
			rk.offset_bottom = -UiMetrics.css(4.0)
			add_child(rk)
		if on:
			var ck := Label.new()
			ck.text = "✔"
			ck.add_theme_color_override("font_color", Color("120d09"))
			ck.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
			ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var pn := Panel.new()
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = UiTheme.GOLD
			sb2.set_corner_radius_all(99)
			sb2.border_color = Color.BLACK
			sb2.set_border_width_all(2)
			pn.add_theme_stylebox_override("panel", sb2)
			pn.custom_minimum_size = Vector2(UiMetrics.css(24.0), UiMetrics.css(24.0))
			pn.size = pn.custom_minimum_size
			pn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			pn.offset_left = -UiMetrics.css(28.0)
			pn.offset_right = -UiMetrics.css(4.0)
			pn.offset_top = UiMetrics.css(4.0)
			pn.offset_bottom = UiMetrics.css(28.0)
			pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pn.add_child(ck)
			add_child(pn)
		if dim:
			modulate = Color(1, 1, 1, 0.4)
		UiFx.hover_pop(self, 1.02)

	static func _pill(text: String, bar: Color, fg: Color) -> Control:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(bar.r, bar.g, bar.b, 0.14)
		sb.border_color = bar
		sb.border_width_left = 3
		sb.set_corner_radius_all(5)
		sb.content_margin_left = 8
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.7)))
		l.add_theme_color_override("font_color", fg)
		p.add_child(l)
		return p

## Aperçu du donjon : les niveaux empilés, salles et couloirs tirés d'une graine fixe (simple repère de proportions).
class MapPreview extends Control:
	var _l := 3
	var _w := 13
	var _h := 11

	func set_dims(l: int, w: int, h: int) -> void:
		_l = l
		_w = w
		_h = h
		queue_redraw()

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_rect(area, Color.BLACK)
		draw_rect(area, UiTheme.BRONZE_DARK, false, 1.0)
		var off := minf(22.0, 130.0 / _l)
		var avail := Vector2(size.x - off * (_l - 1) - 24.0, size.y - off * (_l - 1) - 24.0)
		var cell := maxf(1.0, minf(avail.x / _w, avail.y / _h))
		var mw := _w * cell
		var mh := _h * cell
		var ox0 := (size.x - (mw + off * (_l - 1))) * 0.5
		var oy0 := (size.y - (mh + off * (_l - 1))) * 0.5
		for k in range(_l - 1, -1, -1):
			var o := Vector2(ox0 + k * off, oy0 + (_l - 1 - k) * off)
			draw_rect(Rect2(o, Vector2(mw, mh)), Color("1a120a"))
			draw_rect(Rect2(o, Vector2(mw, mh)), UiTheme.GOLD if k == 0 else UiTheme.BRONZE, false, 2.0)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7919 * (k + 3)
			var rooms: Array = []
			var n := maxi(3, int(round(_w * _h / 40.0)))
			for _i in n:
				var rw := 2 + rng.randi() % int(maxf(1.0, minf(5.0, _w / 3.0)))
				var rh := 2 + rng.randi() % int(maxf(1.0, minf(4.0, _h / 3.0)))
				rooms.append(Rect2(rng.randi() % maxi(1, _w - rw), rng.randi() % maxi(1, _h - rh), rw, rh))
			var col := Color("6a4a22") if k == 0 else Color("3a2a18")
			for i in rooms.size():
				if i == 0:
					continue
				var a: Rect2 = rooms[i]
				var b: Rect2 = rooms[i - 1]
				var ac := (a.position + a.size * 0.5) * cell
				var bc := (b.position + b.size * 0.5) * cell
				draw_rect(Rect2(o + Vector2(minf(ac.x, bc.x), ac.y - cell * 0.5), Vector2(absf(ac.x - bc.x) + cell, cell)), col)
				draw_rect(Rect2(o + Vector2(bc.x - cell * 0.5, minf(ac.y, bc.y)), Vector2(cell, absf(ac.y - bc.y) + cell)), col)
			for r in rooms:
				draw_rect(Rect2(o + r.position * cell, r.size * cell), col)
			if k == 0:
				var s: Rect2 = rooms[0]
				var e: Rect2 = rooms[rooms.size() - 1]
				draw_rect(Rect2(o + (s.position + s.size * 0.5) * cell - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), UiTheme.STA_CYAN)
				draw_rect(Rect2(o + (e.position + e.size * 0.5) * cell - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), UiTheme.RED)
