class_name AdminLevels
extends RefCounted
## Éditeur de niveaux (maquettes « Main », « Panneau-monstres », « Panneau-objets », « Mobile »), en plein écran :
## barre du haut, colonne des niveaux (264 px), carte + dock des 8 pinceaux, inspecteur (372 px) à quatre onglets
## Carte / Monstres / Objets / Réglages. Sur écran étroit : carte + feuille du bas (pinceaux + navigation à cinq entrées).
## Toutes les modifications sont enregistrées automatiquement (`Ax.changed`).

const THEMES := [["stone", "admin.levels.pierre_classique"], ["dirt", "admin.levels.pyramide"], ["damp", "admin.levels.cachot_humide"], ["ruins", "admin.levels.ruines_effondrees"], ["ice", "admin.levels.glace"], ["lava", "admin.levels.lave"], ["temple", "admin.levels.temple_ancien"]]
const DIRS := [[0, "admin.levels.nord"], [1, "admin.levels.est"], [2, "admin.levels.sud"], [3, "admin.levels.ouest"]]
const MAX_LEVELS := 8
## [type, clé de langue, icône]
const ITEM_TYPES := [["potion", "common.potion", "potion"], ["weapon", "common.arme", "weapon"], ["armor", "common.armure", "shield"], ["jewelry", "common.bijou", "jewel"], ["key", "common.cle", "key"], ["scroll", "common.parchemin", "scroll"], ["trap", "common.piege", "warn"], ["switch", "ui.atelier.lv_t_switch", "lever"], ["fountain", "common.fontaine", "fountain"], ["chest", "common.coffre", "chest"]]
## [pinceau, icône, clé de langue] — touches 1 à 8.
const BRUSHES := [[".", "floor", "admin.levels.sol"], ["#", "wall", "admin.levels.mur"], ["D", "door", "admin.levels.porte"], ["S", "stairs", "common.escalier"], ["start", "flag", "ui.atelier.lv_b_start"], ["mon", "skull", "ui.atelier.lv_b_monster"], ["item", "chest", "ui.atelier.lv_b_item"], ["group", "friends", "ui.atelier.lv_b_group"]]
const CHEST_SLOTS := 4
const RED_BG := Color("3a1612")
const RED_BORDER := Color("8a3a30")

static var _sel := ""
## Onglet de l'inspecteur (large) : map / mon / item / cfg.
static var _tab := "map"
## Entrée de la navigation du bas (étroit) : map / levels / mon / item / cfg.
static var _ntab := "map"
static var _brush := "."
## Cible de placement en cours : {kind: monster|item|merchant|start|teleport, id: String} ou vide.
static var _placement: Dictionary = {}
static var _admin: Node = null
static var _host: Control = null
static var _narrow := false
## Force la disposition étroite (outils de capture).
static var force_narrow := false
static var _grid: MapEditorGrid = null
static var _list_box: VBoxContainer = null
static var _panel_host: VBoxContainer = null
static var _panel_scroll: ScrollContainer = null
static var _tabs_box: VBoxContainer = null
static var _dock_box: HBoxContainer = null
static var _pills_box: Control = null
static var _saved_lbl: Label = null
static var _banner: PanelContainer = null
static var _banner_name: Label = null
static var _count_lbl: Label = null
static var _title_lbl: Label = null
static var _cell := Vector2i(-1, -1)
static var _open_mon := ""
static var _open_item := ""

# ------------------------------------------------------------------ données

static func _cfg() -> Dictionary:
	return Data.admin_config()

static func _levels() -> Array:
	return _cfg().get("levels", [])

static func _current() -> Dictionary:
	for l in _levels():
		if l.id == _sel:
			return l
	var ls := _levels()
	if ls.is_empty():
		return {}
	_sel = str(ls[0].id)
	return ls[0]

static func _level_by_id(id) -> Dictionary:
	for l in _levels():
		if l.id == id:
			return l
	return {}

static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if str(e.id) == id:
			return e
	return {}

## `ensureLevelStairs` : escaliers déduits de la carte (action copiée depuis `stairsAction` si présente).
static func _ensure_stairs(lvl: Dictionary) -> void:
	if lvl.has("stairs"):
		return
	lvl["stairs"] = []
	var rows: Array = lvl.mapRows
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			if row[x] == "S":
				var action: Dictionary = (lvl.stairsAction as Dictionary).duplicate(true) if lvl.get("stairsAction") is Dictionary else {"type": "victory"}
				lvl.stairs.append({"id": "stairs_%d_%d" % [x, y], "x": x, "y": y, "action": action})

static func _prepare(lvl: Dictionary) -> void:
	if not lvl.has("doors"):
		lvl["doors"] = []
	_ensure_stairs(lvl)
	if not lvl.has("monsters"):
		lvl["monsters"] = []
	if not lvl.has("items"):
		lvl["items"] = []

# API fournie par Data (agent « Général ») ; appels dynamiques pour rester valide tant qu'elle n'existe pas.
static func _has_run() -> bool:
	return Data.has_method("admin_has_run") and bool(Data.call("admin_has_run"))

static func _marker() -> Dictionary:
	if Data.has_method("admin_party_marker"):
		var m = Data.call("admin_party_marker")
		if m is Dictionary:
			return m
	return {}

static func _teleport_group(level_id: String, x: int, y: int) -> String:
	if Data.has_method("admin_teleport_group"):
		return str(Data.call("admin_teleport_group", level_id, x, y))
	return L.t("common.aucune_partie_en_cours_lancez")

static func _teleport_village() -> String:
	if Data.has_method("admin_teleport_village"):
		return str(Data.call("admin_teleport_village"))
	return L.t("common.aucune_partie_en_cours_lancez")

static func _alert(text: String) -> void:
	Dialogs.notice(_admin.modals(), "", text)

static func _too_close_to_stairs(lvl: Dictionary, x: int, y: int, min_dist: int = 3) -> bool:
	var rows: Array = lvl.mapRows
	for sy in rows.size():
		var row := str(rows[sy])
		for sx in row.length():
			if row[sx] == "S" and maxi(absi(sx - x), absi(sy - y)) < min_dist:
				return true
	return false

# ------------------------------------------------------------------ petits outils

## Nombre tel que l'affiche JavaScript (entier sans « .0 »).
static func _js_num(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "NaN" if is_nan(v) else ("Infinity" if v > 0.0 else "-Infinity")
	if v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	for d in range(1, 18):
		var s := String.num(v, d)
		if s.to_float() == v:
			return s
	return str(v)

## `x||d` de JavaScript pour un nombre.
static func _or(v, d: float) -> float:
	if v == null:
		return d
	var f := float(v) if (v is int or v is float) else (str(v).to_float() if str(v).is_valid_float() else 0.0)
	return d if (f == 0.0 or is_nan(f)) else f

## Libellé sans emoji de tête ni tiret décoratif (« — Aucune — » → « Aucune »).
static func _plain(t: String) -> String:
	var r := AdminItems._plain(t)
	while r.ends_with("—") or r.ends_with("-") or r.ends_with("–"):
		r = r.substr(0, r.length() - 1).strip_edges()
	return r

static func _vc(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c

static func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

static func _theme_label(id: String) -> String:
	for t in THEMES:
		if t[0] == id:
			return _plain(L.t(str(t[1])))
	return id

## Nom court du thème (« Pierre » pour « Pierre (classique) »).
static func _theme_short(id: String) -> String:
	return _theme_label(id).split(" (")[0]

static func _dims(lvl: Dictionary) -> Vector2i:
	var rows: Array = lvl.get("mapRows", [])
	return Vector2i(str(rows[0]).length() if rows.size() > 0 else 0, rows.size())

## Une modification vient d'être faite : enregistrement différé, mémo « modifié récemment », carte et pastilles à jour.
static func _touch(structural: bool = false) -> void:
	Ax.changed()
	var l := _current()
	if not l.is_empty() and _admin != null:
		_admin.note(str(l.get("name", "")))
	_refresh_grid()
	_fill_pills()
	_render_list()
	if structural:
		_render_sub.call_deferred()

## Fenêtre déroulante sous `anchor` : `options` = [[valeur, libellé], …].
static func _pick_menu(anchor: Control, options: Array, cb: Callable) -> void:
	var pm := PopupMenu.new()
	pm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for i in options.size():
		pm.add_item(str(options[i][1]), i)
	pm.id_pressed.connect(func(i: int): cb.call(options[i][0]))
	pm.popup_hide.connect(func(): pm.queue_free())
	_admin.add_child(pm)
	pm.popup(Rect2i(Vector2i(anchor.get_screen_position()) + Vector2i(0, int(anchor.size.y)), Vector2i(int(anchor.size.x), 0)))

## Carte de section (bordure #4a3920, rayon 14) : renvoie son corps.
static func _section(parent: Control, border: Color = Ax.LINE2, bg: Color = Ax.CARD2) -> VBoxContainer:
	var p := Ax.panel(bg, border, 14, 14, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := Ax.vbox(12)
	p.add_child(v)
	return v

## Libellé + interrupteur sur une ligne.
static func _toggle(parent: Control, text: String, on: bool, cb: Callable) -> HBoxContainer:
	var r := Ax.hbox(12)
	r.custom_minimum_size.y = 36
	var l := Ax.lab(text, 13, Ax.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	r.add_child(l)
	r.add_child(_vc(Ax.switch(on, cb)))
	parent.add_child(r)
	return r

static func _select(label: String, options: Array, cur, cb: Callable, h: float = 36.0) -> VBoxContainer:
	var s := Ax.select(options, cur, cb, h, 13)
	return Ax.labeled(label, s) if label != "" else _wrap(s)

static func _wrap(c: Control) -> VBoxContainer:
	var v := Ax.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(c)
	return v

## Champ nombre « − 12 + » lié à `target[key]`.
static func _num(target: Dictionary, key: String, def: float, lo: float, hi: float, label: String, on_change: Callable = Callable(), unit: String = "") -> VBoxContainer:
	return Ax.num(target, key, def, lo, hi, label, 1.0, unit, func(v: float):
		_touch()
		if on_change.is_valid():
			on_change.call(v))

static func _header_row(title_text: String, trailing: Control = null) -> HBoxContainer:
	var h := Ax.hbox(8)
	var t := Ax.title(title_text, 17)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.clip_text = true
	h.add_child(t)
	if trailing != null:
		h.add_child(_vc(trailing))
	return h

# ------------------------------------------------------------------ cadre

static func build(host: Control, admin: Node) -> void:
	_admin = admin
	_host = host
	_narrow = force_narrow or admin.size.x < 1000.0
	_current()
	if str(_placement.get("kind", "")) != "teleport":
		_placement = {}
	_cell = Vector2i(-1, -1)
	_render_all()

## Reconstruit tout l'écran (changement de niveau, d'onglet de navigation, de taille de carte).
static func _render_all() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_clear(_host)
	_grid = null
	_list_box = null
	_panel_host = null
	_panel_scroll = null
	_tabs_box = null
	_dock_box = null
	_pills_box = null
	_banner = null
	_count_lbl = null
	var lvl := _current()
	if not lvl.is_empty():
		_prepare(lvl)
	var root := Ax.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.add_child(root)
	root.add_child(_topbar())
	if _narrow:
		_build_narrow(root)
	else:
		_build_wide(root)
	_host.add_child(KeyCatcher.new())
	_render_list()
	_render_sub()

static func _saved_text() -> String:
	for r in Atelier.recent():
		if str(r.get("section", "")) == "levels":
			return L.fa(L.t("ui.atelier.lv_saved"), Atelier.ago(float(r.get("ts", 0))))
	return L.t("ui.atelier.autosave")

static func _topbar() -> Control:
	var s := Ax.sb(Color(0.071, 0.051, 0.031, 0.8), Ax.LINE, 0, 0, 16 if _narrow else 24, 0)
	s.border_width_bottom = 1
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size.y = 60 if _narrow else 64
	var h := Ax.hbox(12 if _narrow else 16)
	p.add_child(h)
	h.add_child(_vc(Ax.icon_btn("back", func():
		Ax.flush()
		_admin.go("home"), 44.0 if _narrow else 40.0, Ax.GOLD, "ghost", L.t("ui.atelier.lv_back"))))
	var lvl := _current()
	if _narrow:
		var col := Ax.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var idx := _levels().find(lvl) + 1
		var sub := Ax.lab("%s · %s" % [str(_cfg().get("title", "")), L.fa(L.t("ui.atelier.lv_level_n"), idx)], 12, Ax.MUTED)
		sub.clip_text = true
		col.add_child(sub)
		_title_lbl = Ax.title(str(lvl.get("name", "")), 16)
		_title_lbl.clip_text = true
		col.add_child(_title_lbl)
		h.add_child(col)
		h.add_child(_vc(Ax.btn(L.t("ui.atelier.lv_test_short"), func(): _test(), "primary", 44.0, 16, 13)))
		return p
	var col := Ax.vbox(2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := Label.new()
	t.text = L.t("common.editeur_de_donjon").to_upper()
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.add_theme_font_override("font", Ax.cinzel(2))
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Ax.GOLD_L)
	col.add_child(t)
	_saved_lbl = Ax.lab(_saved_text(), 12, Ax.MUTED)
	col.add_child(_saved_lbl)
	h.add_child(col)
	var tm := Timer.new()
	tm.wait_time = 4.0
	tm.autostart = true
	tm.timeout.connect(func():
		if _saved_lbl != null and is_instance_valid(_saved_lbl):
			_saved_lbl.text = _saved_text())
	h.add_child(tm)
	h.add_child(Ax.spacer())
	h.add_child(_vc(Ax.btn(L.t("ui.atelier.lv_save"), func():
		Ax.flush()
		_admin.save()
		_saved_lbl.text = _saved_text(), "ghost", 40.0, 16, 13, "save")))
	h.add_child(_vc(Ax.btn(L.t("ui.atelier.lv_share"), func():
		Ax.flush()
		_admin.go("share"), "ghost", 40.0, 16, 13, "link")))
	h.add_child(_vc(Ax.btn(L.t("ui.atelier.lv_test"), func(): _test(), "primary", 40.0, 20, 13, "play")))
	return p

static func _test() -> void:
	Ax.flush()
	_admin._play_current()

static func _side_panel(width: float, left: bool) -> PanelContainer:
	var s := Ax.sb(Color(0.063, 0.047, 0.031, 0.55), Ax.LINE, 0, 0, 0, 0)
	if left:
		s.border_width_right = 1
	else:
		s.border_width_left = 1
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size.x = width
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p

static func _build_wide(root: VBoxContainer) -> void:
	var body := Ax.hbox(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := _side_panel(264.0, true)
	body.add_child(left)
	var lm := MarginContainer.new()
	for k in ["left", "right"]:
		lm.add_theme_constant_override("margin_" + k, 16)
	lm.add_theme_constant_override("margin_top", 20)
	lm.add_theme_constant_override("margin_bottom", 20)
	left.add_child(lm)
	lm.add_child(_levels_column(true))
	var mid := MarginContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("margin_left", 24)
	mid.add_theme_constant_override("margin_right", 24)
	mid.add_theme_constant_override("margin_top", 20)
	mid.add_theme_constant_override("margin_bottom", 20)
	body.add_child(mid)
	mid.add_child(_centre(_admin.size.x - 264.0 - 372.0 - 48.0, _admin.size.y - 64.0 - 40.0))
	var right := _side_panel(372.0, false)
	body.add_child(right)
	var rv := Ax.vbox(0)
	right.add_child(rv)
	_tabs_box = Ax.vbox(0)
	rv.add_child(Ax.margin(_tabs_box, 12, 12, 12, 0))
	_fill_tabs()
	_panel_scroll = ScrollContainer.new()
	_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(_panel_scroll)
	var pm := MarginContainer.new()
	pm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]:
		pm.add_theme_constant_override("margin_" + k, 20)
	_panel_scroll.add_child(pm)
	_panel_host = Ax.vbox(18)
	_panel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pm.add_child(_panel_host)

static func _tab_items() -> Array:
	return [["map", _plain(L.t("admin.levels.carte"))], ["mon", _plain(L.t("admin.levels.monstres"))], ["item", _plain(L.t("admin.levels.objets"))], ["cfg", _plain(L.t("admin.levels.reglages"))]]

static func _fill_tabs() -> void:
	if _tabs_box == null or not is_instance_valid(_tabs_box):
		return
	_clear(_tabs_box)
	_tabs_box.add_child(Ax.tabs(_tab_items(), _tab, func(id: String):
		_tab = id
		_fill_tabs()
		_render_sub(), 38.0, 13, 14))

# ------------------------------------------------------------------ colonne des niveaux

## Nom du donjon, liste des niveaux, « Ajouter un niveau » et, en pied, l'aide des raccourcis.
static func _levels_column(with_legend: bool) -> Control:
	var col := Ax.vbox(16)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nm := Ax.vbox(6)
	nm.add_child(Ax.lab(L.t("ui.atelier.lv_dname").to_upper(), 12, Ax.MUTED))
	nm.add_child(Ax.text_field(_cfg(), "title", 40, 14))
	col.add_child(nm)
	var hd := Ax.hbox(8)
	var t := Label.new()
	t.text = L.t("ui.atelier.nav_levels").to_upper()
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.add_theme_font_override("font", Ax.cinzel(1))
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", Ax.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(t)
	_count_lbl = Ax.lab("", 12, Ax.MUTED)
	hd.add_child(_count_lbl)
	col.add_child(hd)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	var inner := Ax.vbox(8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	_list_box = Ax.vbox(8)
	inner.add_child(_list_box)
	var add := AxDashed.new(Color("6b5430"), 12.0)
	add.custom_minimum_size.y = 44
	var ar := Ax.hbox(8)
	ar.alignment = BoxContainer.ALIGNMENT_CENTER
	ar.add_child(Ax.ico("plus", 18, Ax.GOLD, 2.0))
	ar.add_child(Ax.lab(_plain(L.t("admin.levels.ajouter_un_niveau")), 13, Ax.GOLD, 500))
	add.add_child(ar)
	Ax.clickable(add, func(): _add_level())
	inner.add_child(add)
	if with_legend:
		var lg := Ax.vbox(8)
		lg.add_child(Ax.line())
		for k in [["ui.atelier.lv_key_a", "ui.atelier.lv_k1"], ["ui.atelier.lv_key_b", "ui.atelier.lv_k2"], ["ui.atelier.lv_key_c", "ui.atelier.lv_k3"]]:
			var r := HFlowContainer.new()
			r.add_theme_constant_override("h_separation", 5)
			r.add_child(Ax.lab(L.t(str(k[0])), 12, Ax.TEXT, 600))
			r.add_child(Ax.lab(L.t(str(k[1])), 12, Ax.MUTED))
			lg.add_child(r)
		col.add_child(Ax.margin(lg, 0, 6, 0, 0))
	return col

static func _meta_of(l: Dictionary) -> String:
	var d := _dims(l)
	var n := (l.get("monsters", []) as Array).size()
	return "%s · %d×%d · %s" % [_theme_short(str(l.get("theme", "stone"))), d.x, d.y, L.fa(L.t("ui.atelier.lv_mons_short"), n)]

static func _render_list() -> void:
	if _count_lbl != null and is_instance_valid(_count_lbl):
		_count_lbl.text = "%d / %d" % [_levels().size(), MAX_LEVELS]
	if _list_box == null or not is_instance_valid(_list_box):
		return
	_clear(_list_box)
	var levels := _levels()
	for i in levels.size():
		var l: Dictionary = levels[i]
		var lid := str(l.id)
		var on := lid == _sel
		var row := Ax.panel(Ax.GOLD_BG2 if on else Color(0.118, 0.086, 0.051, 0.6), Ax.GOLD if on else Ax.LINE, 12, 10, 10)
		var h := Ax.hbox(12)
		row.add_child(h)
		var badge := Ax.panel(Ax.GOLD if on else Color("241a0e"), Ax.CLEAR, 9, 0, 0, 0)
		badge.custom_minimum_size = Vector2(34, 34)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bn := Ax.title(str(i + 1), 15, Color("2a1a06") if on else Ax.MUTED)
		bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(bn)
		h.add_child(badge)
		var tv := Ax.vbox(3)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := Ax.lab(str(l.get("name", "")), 14, Ax.CREAM, 600)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.x = 10
		tv.add_child(nl)
		var ml := Ax.lab(_meta_of(l), 12, Ax.MUTED)
		ml.clip_text = true
		ml.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ml.custom_minimum_size.x = 10
		tv.add_child(ml)
		h.add_child(tv)
		if on and levels.size() > 1:
			var mv := Ax.vbox(0)
			mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			for d in [["↑", -1], ["↓", 1]]:
				var dd: int = d[1]
				var idx := i
				var mb := Ax.btn(str(d[0]), func():
					var ls := _levels()
					if idx + dd >= 0 and idx + dd < ls.size():
						var tmp = ls[idx]
						ls[idx] = ls[idx + dd]
						ls[idx + dd] = tmp
						_touch(), "flat", 20.0, 6, 12)
				mv.add_child(mb)
			h.add_child(mv)
		Ax.clickable(row, func(): _select_level(lid))
		_list_box.add_child(row)

static func _select_level(id: String) -> void:
	_sel = id
	_cell = Vector2i(-1, -1)
	if str(_placement.get("kind", "")) != "teleport":
		_placement = {}
	_open_mon = ""
	_open_item = ""
	if _narrow:
		_ntab = "map"
	_render_all()

static func _add_level() -> void:
	if _levels().size() >= MAX_LEVELS:
		_alert(L.t("admin.levels.un_donjon_ne_peut_pas"))
		return
	var rows: Array = []
	for y in 8:
		rows.append("#".repeat(8))
	var id := "lvl_%d" % Time.get_ticks_msec()
	_levels().append({"id": id, "name": L.t("admin.levels.nouveau_niveau"), "theme": "stone", "mapRows": rows, "startX": 1, "startY": 1, "startDir": 1, "stairs": [], "doors": [], "monsters": [], "items": []})
	Ax.changed()
	_select_level(id)

static func _delete_level() -> void:
	if _levels().size() <= 1:
		_alert(L.t("admin.levels.il_doit_rester_au_moins"))
		return
	var go := func():
		var removed := _sel
		var ls := _levels()
		for i in range(ls.size() - 1, -1, -1):
			if ls[i].id == removed:
				ls.remove_at(i)
		for l in ls:
			for st in l.get("stairs", []):
				var a: Dictionary = st.get("action", {})
				if a.get("type") == "level" and a.get("targetId") == removed:
					st["action"] = {"type": "victory"}
		Ax.changed()
		_select_level(str(ls[0].id))
	Dialogs.confirm(_admin.modals(), "", L.t("admin.levels.supprimer_ce_niveau_definitivement"), go)

# ------------------------------------------------------------------ centre : en-tête, carte, dock

static func _fit_cell(lvl: Dictionary, avail_w: float, avail_h: float) -> float:
	var d := _dims(lvl)
	if d.x <= 0 or d.y <= 0:
		return 40.0
	var pad := 2.0 * (MapEditorGrid.PAD + MapEditorGrid.BORDER)
	var cw := (avail_w - pad - (d.x - 1) * MapEditorGrid.GAP) / d.x
	var ch := (avail_h - pad - (d.y - 1) * MapEditorGrid.GAP) / d.y
	return clampf(floorf(minf(cw, ch)), 20.0, 40.0)

static func _centre(avail_w: float, avail_h: float) -> Control:
	var col := Ax.vbox(16)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lvl := _current()
	# titre du niveau (champ discret) + pastilles taille / thème
	var head := Ax.hbox(12)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var idx := _levels().find(lvl) + 1
	tv.add_child(Ax.lab(L.fa(L.t("ui.atelier.lv_level_n"), idx).to_upper(), 12, Ax.MUTED))
	var te := Ax.field(str(lvl.get("name", "")), Callable(), 40, 24)
	te.add_theme_font_override("font", Ax.cinzel())
	te.add_theme_color_override("font_color", Ax.CREAM)
	te.add_theme_stylebox_override("normal", Ax.sb(Ax.CLEAR, Ax.CLEAR, 8, 1, 6, 0))
	te.add_theme_stylebox_override("hover", Ax.sb(Ax.CLEAR, Ax.LINE2, 8, 1, 6, 0))
	te.text_changed.connect(func(t: String):
		var l := _current()
		if not l.is_empty():
			l["name"] = t
			Ax.changed()
			_render_list())
	tv.add_child(te)
	head.add_child(tv)
	_pills_box = HBoxContainer.new()
	(_pills_box as HBoxContainer).add_theme_constant_override("separation", 8)
	_pills_box.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_pills_box)
	_fill_pills()
	col.add_child(head)
	_build_banner(col)
	col.add_child(_map_area(lvl, avail_w, avail_h - 150.0))
	var dock_wrap := CenterContainer.new()
	var dock := Ax.panel(Color(0.086, 0.063, 0.039, 0.88), Ax.LINE3, 16, 8, 8)
	_dock_box = Ax.hbox(6)
	dock.add_child(_dock_box)
	dock_wrap.add_child(dock)
	col.add_child(dock_wrap)
	_fill_dock(clampf((avail_w - 16.0 - 7.0 * 6.0) / 8.0, 54.0, 78.0))
	return col

static func _fill_pills() -> void:
	if _pills_box == null or not is_instance_valid(_pills_box):
		return
	_clear(_pills_box)
	var lvl := _current()
	if lvl.is_empty():
		return
	var d := _dims(lvl)
	var goto := func():
		_tab = "cfg"
		_fill_tabs()
		_render_sub()
	_pills_box.add_child(Ax.pill(L.fa(L.t("ui.atelier.lv_cells"), [d.x, d.y]), false, goto, Ax.GOLD, 32.0, 13, 12))
	_pills_box.add_child(Ax.pill(_theme_label(str(lvl.get("theme", "stone"))), false, goto, Ax.GOLD, 32.0, 13, 12))

static func _map_area(lvl: Dictionary, avail_w: float, avail_h: float) -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	_grid = MapEditorGrid.new()
	_grid.cell = _fit_cell(lvl, avail_w, avail_h)
	_grid.party_marker = _marker()
	_grid.selected = _cell
	cc.add_child(_grid)
	_grid.set_level(lvl)
	_grid.cell_pressed.connect(func(x: int, y: int): _on_cell(_current(), x, y))
	_grid.badge_pressed.connect(func(x: int, y: int, kind: String, id: String): _on_badge(_current(), kind, id))
	return sc

static func _fill_dock(btn_w: float) -> void:
	if _dock_box == null or not is_instance_valid(_dock_box):
		return
	_clear(_dock_box)
	for i in BRUSHES.size():
		_dock_box.add_child(_brush_btn(i, btn_w, 62.0, false))

static func _brush_btn(i: int, w: float, h: float, compact: bool) -> Button:
	var br: Array = BRUSHES[i]
	var on := _brush == str(br[0])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0 if compact else w, h)
	if compact:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s (%d)" % [_plain(L.t(str(br[2]))), i + 1]
	var bg := Color(0.91, 0.706, 0.361, 0.16) if on else Ax.CLEAR
	var ln := Ax.GOLD if on else Ax.CLEAR
	for k in ["normal", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Ax.sb(bg, ln, 12 if not compact else 10, 1, 0, 0))
	var hv := Ax.sb(bg if on else Color(1, 1, 1, 0.05), ln, 12 if not compact else 10, 1, 0, 0)
	b.add_theme_stylebox_override("hover", hv)
	var inner := Ax.vbox(3 if compact else 4)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := Ax.GOLD if on else Ax.TEXT
	var ic := Ax.ico(str(br[1]), 22, fg, 1.7)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(ic)
	var tl := Ax.lab(_plain(L.t(str(br[2]))), 11 if compact else 12, fg, 500)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.clip_text = true
	inner.add_child(tl)
	b.add_child(inner)
	if not compact:
		var kl := Ax.lab(str(i + 1), 11, Ax.MUTED)
		kl.position = Vector2(w - 14.0, 4.0)
		kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(kl)
	b.pressed.connect(func(): _set_brush(str(br[0])))
	return b

static func _set_brush(id: String) -> void:
	_brush = id
	if _narrow:
		_fill_sheet_brushes()
	else:
		_fill_dock(clampf((_admin.size.x - 264.0 - 372.0 - 48.0 - 16.0 - 42.0) / 8.0, 54.0, 78.0))

## Raccourcis clavier 1 à 8 (pinceaux).
class KeyCatcher extends Node:
	func _unhandled_key_input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.pressed or e.echo or e.ctrl_pressed or e.meta_pressed or e.alt_pressed:
			return
		var n := -1
		if e.keycode >= KEY_1 and e.keycode <= KEY_8:
			n = e.keycode - KEY_1
		elif e.keycode >= KEY_KP_1 and e.keycode <= KEY_KP_8:
			n = e.keycode - KEY_KP_1
		if n >= 0:
			get_viewport().set_input_as_handled()
			AdminLevels._set_brush(str(AdminLevels.BRUSHES[n][0]))

# ------------------------------------------------------------------ écran étroit

static var _sheet_brushes: HBoxContainer = null

static func _build_narrow(root: VBoxContainer) -> void:
	var lvl := _current()
	var area := Ax.vbox(0)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(area)
	match _ntab:
		"map":
			var mm := MarginContainer.new()
			mm.size_flags_vertical = Control.SIZE_EXPAND_FILL
			for k in ["left", "right", "top", "bottom"]:
				mm.add_theme_constant_override("margin_" + k, 12)
			area.add_child(mm)
			var col := Ax.vbox(10)
			mm.add_child(col)
			_build_banner(col)
			col.add_child(_map_area(lvl, _admin.size.x - 24.0, _admin.size.y - 60.0 - 12.0 - 250.0))
		"levels":
			var sc := ScrollContainer.new()
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			area.add_child(sc)
			var pm := MarginContainer.new()
			pm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for k in ["left", "right", "top", "bottom"]:
				pm.add_theme_constant_override("margin_" + k, 16)
			sc.add_child(pm)
			pm.add_child(_levels_column(false))
		_:
			_panel_scroll = ScrollContainer.new()
			_panel_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			area.add_child(_panel_scroll)
			var pm2 := MarginContainer.new()
			pm2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for k in ["left", "right", "top", "bottom"]:
				pm2.add_theme_constant_override("margin_" + k, 16)
			_panel_scroll.add_child(pm2)
			_panel_host = Ax.vbox(16)
			_panel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pm2.add_child(_panel_host)
	# feuille du bas : pinceaux (carte) + navigation
	var s := Ax.sb(Color(0.086, 0.063, 0.039, 0.96), Ax.LINE3, 20, 1, 16, 10)
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.border_width_bottom = 0
	s.content_margin_bottom = 0
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", s)
	root.add_child(sheet)
	var sv := Ax.vbox(12)
	sheet.add_child(sv)
	var grip := Ax.panel(Ax.LINE2, Ax.CLEAR, 2, 0, 0, 0)
	grip.custom_minimum_size = Vector2(40, 4)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv.add_child(grip)
	if _ntab == "map":
		_sheet_brushes = Ax.hbox(4)
		sv.add_child(_sheet_brushes)
		_fill_sheet_brushes()
	var nav := Ax.hbox(0)
	nav.custom_minimum_size.y = 64
	for it in [["map", "map", "admin.levels.carte"], ["levels", "stairs", "ui.atelier.nav_levels"], ["mon", "skull", "admin.levels.monstres"], ["item", "chest", "admin.levels.objets"], ["cfg", "sliders", "admin.levels.reglages"]]:
		var id: String = it[0]
		var on := _ntab == id
		var nb := Button.new()
		nb.flat = true
		nb.focus_mode = Control.FOCUS_NONE
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for k in ["normal", "hover", "pressed", "focus"]:
			nb.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		var iv := Ax.vbox(4)
		iv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		iv.alignment = BoxContainer.ALIGNMENT_CENTER
		iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col2 := Ax.GOLD_L if on else Ax.MUTED
		var ic := Ax.ico(str(it[1]), 22, col2, 1.7)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		iv.add_child(ic)
		var nl := Ax.lab(_plain(L.t(str(it[2]))), 11, col2)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iv.add_child(nl)
		nb.add_child(iv)
		nb.pressed.connect(func():
			_ntab = id
			_render_all())
		nav.add_child(nb)
	var navw := Ax.vbox(0)
	navw.add_child(Ax.line())
	navw.add_child(nav)
	sv.add_child(Ax.margin(navw, -16, 0, -16, 0))

static func _fill_sheet_brushes() -> void:
	if _sheet_brushes == null or not is_instance_valid(_sheet_brushes):
		return
	_clear(_sheet_brushes)
	for i in BRUSHES.size():
		_sheet_brushes.add_child(_brush_btn(i, 0.0, 56.0, true))

# ------------------------------------------------------------------ placement en cours

static func _placement_name(lvl: Dictionary) -> String:
	match str(_placement.get("kind", "")):
		"monster": return str(_find(lvl.monsters, str(_placement.id)).get("name", ""))
		"item": return str(_find(lvl.items, str(_placement.id)).get("name", ""))
		"merchant": return L.t("admin.levels.le_marchand_ambulant")
		"teleport": return L.t("admin.levels.le_groupe_teleportation")
	return L.t("admin.levels.le_point_de_depart")

static func _update_banner() -> void:
	if _banner == null or not is_instance_valid(_banner):
		return
	_banner.visible = not _placement.is_empty()
	if _banner.visible:
		_banner_name.text = _placement_name(_current())

static func _build_banner(parent: Control) -> void:
	_banner = Ax.panel(Ax.GOLD_BG, Color("a9793a"), 10, 12, 8)
	var h := Ax.hbox(10)
	_banner.add_child(h)
	var pre := Ax.lab(_plain(L.t("admin.levels.cliquez_sur_la_carte_pour")), 13, Ax.TEXT)
	pre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pre)
	_banner_name = Ax.lab("", 13, Ax.GOLD_L, 600)
	_banner_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_banner_name)
	h.add_child(Ax.btn(L.t("common.annuler"), func():
		_placement = {}
		_update_banner(), "ghost", 30.0, 10, 12))
	parent.add_child(_banner)
	_banner.visible = false
	_update_banner()

static func _start_placement(kind: String, id: String = "") -> void:
	_placement = {"kind": kind, "id": id}
	if _narrow and _ntab != "map":
		_ntab = "map"
		_render_all()
	else:
		_update_banner()

static func _refresh_grid() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.party_marker = _marker()
		_grid.selected = _cell
		_grid.refresh()


# ------------------------------------------------------------------ carte : clics et peinture

static func _resize(lvl: Dictionary, w: int, h: int) -> void:
	var W := clampi(w, 4, 60)
	var H := clampi(h, 4, 60)
	var old: Array = lvl.mapRows
	var nr: Array = []
	for y in H:
		var row := ""
		for x in W:
			row += str(old[y])[x] if (y < old.size() and x < str(old[0]).length()) else "#"
		nr.append(row)
	lvl["mapRows"] = nr
	_cell = Vector2i(-1, -1)
	Ax.changed()
	_render_all()

## Clic sur une pastille retirable : retire l'entité du niveau.
static func _on_badge(lvl: Dictionary, kind: String, id: String) -> void:
	if kind == "mon":
		var arr: Array = lvl.monsters
		for i in arr.size():
			if str(arr[i].id) == id:
				arr.remove_at(i)
				break
	else:
		_remove_item(lvl, id)
	_touch(true)

static func _remove_item(lvl: Dictionary, id: String) -> void:
	var items: Array = lvl.items
	for i in items.size():
		if str(items[i].id) == id:
			items.remove_at(i)
			break
	for m in lvl.monsters:
		if m.get("lootItemId") == id:
			m["lootItemId"] = ""
		if m.get("lootItemId2") == id:
			m["lootItemId2"] = ""

static func _monsters_at(lvl: Dictionary, x: int, y: int) -> Array:
	var out: Array = []
	for m in lvl.get("monsters", []):
		if int(m.x) == x and int(m.y) == y:
			out.append(m)
	return out

## Objets de la case (décors exclus).
static func _items_at(lvl: Dictionary, x: int, y: int) -> Array:
	var out: Array = []
	for it in lvl.get("items", []):
		if int(it.x) == x and int(it.y) == y and str(it.get("type", "")) != "decor":
			out.append(it)
	return out

## Clic sur une case : placement en cours, sinon pinceau courant.
static func _on_cell(lvl: Dictionary, x: int, y: int) -> void:
	if lvl.is_empty():
		return
	if not _placement.is_empty():
		_place(lvl, x, y)
		return
	_cell = Vector2i(x, y)
	match _brush:
		".", "#", "D", "S":
			_paint(lvl, x, y)
		"start":
			lvl["startX"] = x
			lvl["startY"] = y
		"mon":
			if str(lvl.mapRows[y])[x] != "#" and _monsters_at(lvl, x, y).is_empty():
				if _too_close_to_stairs(lvl, x, y):
					_alert(L.t("admin.levels.un_monstre_ne_peut_pas"))
				else:
					var m := _new_monster(lvl, x, y)
					_open_mon = str(m.id)
		"item":
			if str(lvl.mapRows[y])[x] != "#" and _items_at(lvl, x, y).is_empty():
				var it := _new_item(lvl, x, y, "potion")
				_open_item = str(it.id)
		"group":
			if not _has_run():
				_alert(L.t("common.aucune_partie_en_cours_lancez"))
			else:
				var err: String = _teleport_group(str(lvl.id), x, y)
				if err != "":
					_alert(err)
	_touch(true)

static func _place(lvl: Dictionary, x: int, y: int) -> void:
	match str(_placement.get("kind", "")):
		"monster":
			if _too_close_to_stairs(lvl, x, y):
				_alert(L.t("admin.levels.un_monstre_ne_peut_pas"))
				return
			var m := _find(lvl.monsters, str(_placement.id))
			if not m.is_empty():
				m["x"] = x
				m["y"] = y
		"item":
			var it := _find(lvl.items, str(_placement.id))
			if not it.is_empty():
				it["x"] = x
				it["y"] = y
				if str(it.get("type", "")) == "chest" and bool(it.get("wallAuto", true)):
					it["wall"] = _chest_auto_wall(lvl, x, y)
		"merchant":
			if not (lvl.get("travelingMerchant") is Dictionary):
				lvl["travelingMerchant"] = {"x": x, "y": y, "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			else:
				lvl.travelingMerchant["x"] = x
				lvl.travelingMerchant["y"] = y
		"start":
			lvl["startX"] = x
			lvl["startY"] = y
		"teleport":
			if str(lvl.mapRows[y])[x] == "#":
				_alert(L.t("admin.levels.case_muree_choisissez_une_case"))
				return
			var err: String = _teleport_group(str(lvl.id), x, y)
			if err != "":
				_alert(err)
				_placement = {}
				_update_banner()
				return
	_placement = {}
	_cell = Vector2i(x, y)
	_update_banner()
	_touch(true)

static func _paint(lvl: Dictionary, x: int, y: int) -> void:
	var rows: Array = lvl.mapRows
	var row := str(rows[y])
	rows[y] = row.substr(0, x) + _brush + row.substr(x + 1)
	var doors: Array = lvl.doors
	var stairs: Array = lvl.stairs
	for i in range(doors.size() - 1, -1, -1):
		if int(doors[i].x) == x and int(doors[i].y) == y:
			doors.remove_at(i)
	for i in range(stairs.size() - 1, -1, -1):
		if int(stairs[i].x) == x and int(stairs[i].y) == y:
			stairs.remove_at(i)
	if _brush == "D":
		doors.append({"id": "door_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "locked": true})
	elif _brush == "S":
		stairs.append({"id": "stairs_%d_%d_%d" % [x, y, Time.get_ticks_msec()], "x": x, "y": y, "action": {"type": "victory"}})

static func _new_monster(lvl: Dictionary, x: int, y: int) -> Dictionary:
	var m := {"id": "mon_%d" % Time.get_ticks_msec(), "name": L.t("admin.levels.nouveau_monstre"), "icon": "👹", "x": x, "y": y, "force": 8, "dex": 8, "con": 8, "resistPhys": 0, "resistMagic": 0, "xpReward": 10, "goldReward": 5, "abilitySpellId": "", "abilityChance": 30, "enrageThreshold": 0, "patrolRadius": 3, "attackSpeed": 2, "opensDoorId": "", "startHidden": false, "isBoss": false, "lootItemId": "", "lootChance": 100, "lootItemId2": "", "lootChance2": 100}
	lvl.monsters.append(m)
	return m

static func _new_item(lvl: Dictionary, x: int, y: int, type: String) -> Dictionary:
	var it := {"id": "item_%d" % Time.get_ticks_msec(), "name": L.t("common.nouvel_objet"), "icon": "💎", "x": x, "y": y, "type": type, "startHidden": false}
	if type == "chest":
		it["wall"] = _chest_auto_wall(lvl, x, y)
	lvl.items.append(it)
	return it

## Nom du terrain de la case (« Sol — dans la salle 1 »).
static func _terrain_text(lvl: Dictionary, x: int, y: int) -> String:
	var ch := str(lvl.mapRows[y])[x]
	var name_s := ""
	match ch:
		"#": name_s = _plain(L.t("admin.levels.mur"))
		"D": name_s = _plain(L.t("admin.levels.porte"))
		"S": name_s = _plain(L.t("common.escalier"))
		_: name_s = _plain(L.t("admin.levels.sol"))
	if ch != "#" and ch != "D" and ch != "S":
		for r in RoomMap.detect(lvl.mapRows):
			if (r.cells as Array).has(Vector2i(x, y)):
				name_s = L.fa(L.t("ui.atelier.lv_in_room"), [name_s, int(r.id) + 1])
				break
	if int(lvl.get("startX", -1)) == x and int(lvl.get("startY", -1)) == y:
		name_s += " · " + _plain(L.t("ui.atelier.lv_b_start")).to_lower()
	return name_s

# ------------------------------------------------------------------ inspecteur

static func _render_sub() -> void:
	if _panel_host == null or not is_instance_valid(_panel_host):
		return
	var keep := 0
	if _panel_scroll != null and is_instance_valid(_panel_scroll):
		keep = _panel_scroll.scroll_vertical
	_clear(_panel_host)
	var lvl := _current()
	if lvl.is_empty():
		return
	_prepare(lvl)
	var t := _ntab if _narrow else _tab
	match t:
		"map": _cell_panel(_panel_host, lvl)
		"mon": _monsters_panel(_panel_host, lvl)
		"item": _items_panel(_panel_host, lvl)
		"cfg": _cfg_panel(_panel_host, lvl)
	if _panel_scroll != null and is_instance_valid(_panel_scroll):
		_set_scroll.call_deferred(_panel_scroll, keep)

static func _set_scroll(sc: ScrollContainer, v: int) -> void:
	if is_instance_valid(sc):
		sc.scroll_vertical = v

static func _legend(parent: Control) -> void:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 14)
	f.add_theme_constant_override("v_separation", 6)
	for it in [[MapEditorGrid.C_MON, "ui.atelier.lv_b_monster", true], [MapEditorGrid.C_ITEM, "ui.atelier.lv_b_item", false], [MapEditorGrid.C_START, "ui.atelier.lv_b_start", true], [MapEditorGrid.C_PARTY, "ui.atelier.lv_b_group", true]]:
		var r := Ax.hbox(6)
		var dot := Ax.panel(it[0], Ax.CLEAR, 5 if it[2] else 3, 0, 0, 0)
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(dot)
		r.add_child(Ax.lab(_plain(L.t(str(it[1]))), 12, Ax.MUTED))
		f.add_child(r)
	parent.add_child(f)

# ---- onglet Carte : la case sélectionnée

static func _cell_panel(host: VBoxContainer, lvl: Dictionary) -> void:
	var d := _dims(lvl)
	if _cell.x < 0 or _cell.x >= d.x or _cell.y < 0 or _cell.y >= d.y:
		host.add_child(Ax.para(L.t("ui.atelier.lv_pick_cell"), 13, Ax.MUTED))
		_legend(host)
		return
	var x := _cell.x
	var y := _cell.y
	var hd := Ax.hbox(8)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Ax.title(L.fa(L.t("ui.atelier.lv_cell"), [x, y]), 18))
	var sub := Ax.lab(_terrain_text(lvl, x, y), 12, Ax.MUTED)
	sub.clip_text = true
	sub.custom_minimum_size.x = 10
	tv.add_child(sub)
	hd.add_child(tv)
	hd.add_child(_vc(Ax.btn(L.t("ui.atelier.lv_clear"), func():
		for m in _monsters_at(lvl, x, y):
			(lvl.monsters as Array).erase(m)
		for it in _items_at(lvl, x, y):
			_remove_item(lvl, str(it.id))
		_touch(true), "ghost", 34.0, 12, 12)))
	host.add_child(hd)
	for m in _monsters_at(lvl, x, y):
		_mon_summary(host, lvl, m)
	if str(lvl.mapRows[y])[x] == "S":
		for st in lvl.stairs:
			if int(st.x) == x and int(st.y) == y:
				host.add_child(_stairs_card(lvl, st))
	_item_summary(host, lvl, x, y)
	_legend(host)

static func _mon_summary(host: Control, lvl: Dictionary, m: Dictionary) -> void:
	var v := _section(host, Ax.LINE2, Color(0.118, 0.086, 0.051, 0.8))
	var r := Ax.hbox(12)
	var ib := Ax.panel(RED_BG, RED_BORDER, 12, 0, 0)
	ib.custom_minimum_size = Vector2(44, 44)
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Ax.ico("skull", 26, Ax.RED, 1.7)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ib.add_child(ic)
	r.add_child(ib)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl := Ax.lab(str(m.get("name", "")), 15, Ax.CREAM, 600)
	nl.clip_text = true
	nl.custom_minimum_size.x = 10
	tv.add_child(nl)
	var kind := L.t("ui.atelier.lv_mon_sub")
	if bool(m.get("isBoss", false)):
		kind = L.t("ui.atelier.lv_mon_boss")
	elif bool(m.get("isGroup", false)):
		kind = L.t("ui.atelier.lv_mon_group")
	tv.add_child(Ax.lab(kind, 12, Ax.MUTED))
	r.add_child(tv)
	r.add_child(_vc(Ax.icon_btn("close", func():
		(lvl.monsters as Array).erase(m)
		_touch(true), 34.0, Ax.RED, "danger", L.t("ui.atelier.lv_remove"))))
	v.add_child(r)
	var g := Ax.grid2(v)
	if bool(m.get("isGroup", false)):
		var sz := 3 if int(_or(m.get("groupSize"), 2.0)) == 3 else 2
		g.add_child(Ax.labeled(L.t("ui.atelier.lv_group_size"), Ax.stepper(float(sz), 2, 3, 1, func(val: float):
			m["groupSize"] = int(val)
			_touch())))
	g.add_child(_num(m, "patrolRadius", 0, 0, 99, L.t("admin.levels.rayon_de_patrouille")))
	var rage_on := int(_or(m.get("enrageThreshold"), 0.0)) > 0
	_toggle(v, L.t("ui.atelier.lv_rage"), rage_on, func(on: bool):
		if on:
			if int(_or(m.get("enrageThreshold"), 0.0)) <= 0:
				m["enrageThreshold"] = 40
			if int(_or(m.get("enrageBonusPct"), 0.0)) <= 0:
				m["enrageBonusPct"] = 30
		else:
			m["enrageThreshold"] = 0
		_touch())
	var gold := int(_or(m.get("goldReward"), 0.0))
	var gv := Ax.vbox(6)
	var gh := Ax.hbox(8)
	gh.add_child(Ax.lab(L.t("ui.atelier.lv_gold_death"), 12, Ax.MUTED))
	gh.add_child(Ax.spacer())
	var gl := Ax.lab(str(gold), 12, Ax.GOLD_L, 600)
	gh.add_child(gl)
	gv.add_child(gh)
	var sl := Ax.slider(float(gold), 0, maxf(100.0, float(gold)), 1)
	sl.value_changed.connect(func(val: float):
		m["goldReward"] = int(val)
		gl.text = str(int(val))
		_touch())
	gv.add_child(sl)
	v.add_child(gv)
	v.add_child(Ax.btn(L.t("ui.atelier.lv_all_settings"), func():
		_open_mon = str(m.id)
		_goto("mon"), "ghost", 34.0, 12, 12))

static func _goto(tab: String) -> void:
	if _narrow:
		_ntab = tab
		_render_all()
	else:
		_tab = tab
		_fill_tabs()
		_render_sub()

static func _item_summary(host: Control, lvl: Dictionary, x: int, y: int) -> void:
	var v := _section(host, Ax.LINE2, Color(0.118, 0.086, 0.051, 0.8))
	var here := _items_at(lvl, x, y)
	var cur: Dictionary = here[0] if not here.is_empty() else {}
	var hr := Ax.hbox(8)
	var tl := Ax.lab(L.t("ui.atelier.lv_item_on"), 15, Ax.CREAM, 600)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	hr.add_child(Ax.lab(_item_name(cur) if not cur.is_empty() else _plain(L.t("common.aucun")), 12, Ax.MUTED))
	v.add_child(hr)
	var gp := GridContainer.new()
	gp.columns = 5
	gp.add_theme_constant_override("h_separation", 8)
	gp.add_theme_constant_override("v_separation", 8)
	v.add_child(gp)
	for t in ITEM_TYPES:
		var tid: String = t[0]
		var on := not cur.is_empty() and str(cur.get("type", "")) == tid
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = _plain(L.t(str(t[1])))
		var bg := Ax.GOLD_BG if on else Ax.FIELD
		var ln := Ax.GOLD if on else Ax.LINE2
		for k in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, Ax.sb(bg, ln, 10, 1, 0, 0))
		b.add_theme_stylebox_override("hover", Ax.sb(Ax.GOLD_BG if on else Color("1c160d"), ln if on else Color("6b5430"), 10, 1, 0, 0))
		var iv := Ax.vbox(4)
		iv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		iv.alignment = BoxContainer.ALIGNMENT_CENTER
		iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fg := Ax.GOLD_L if on else Ax.TEXT
		var ic := Ax.ico(str(t[2]), 20, fg, 1.7)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		iv.add_child(ic)
		var ll := Ax.lab(_plain(L.t(str(t[1]))), 11, fg)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.clip_text = true
		ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		iv.add_child(ll)
		b.add_child(iv)
		b.pressed.connect(func():
			if cur.is_empty():
				var it := _new_item(lvl, x, y, tid)
				_open_item = str(it.id)
			else:
				cur["type"] = tid
				if tid == "chest" and not cur.has("wall"):
					cur["wall"] = _chest_auto_wall(lvl, x, y)
			_touch(true))
		gp.add_child(b)
	if not cur.is_empty():
		var br := Ax.hbox(8)
		br.add_child(Ax.btn(L.t("ui.atelier.lv_all_settings"), func():
			_open_item = str(cur.id)
			_goto("item"), "ghost", 34.0, 12, 12))
		br.add_child(Ax.btn(L.t("ui.atelier.lv_remove"), func():
			_remove_item(lvl, str(cur.id))
			_touch(true), "danger", 34.0, 12, 12))
		v.add_child(br)

static func _item_name(it: Dictionary) -> String:
	return str(it.get("name", ""))

# ---- onglet Monstres

static func _mon_derived(m: Dictionary) -> Dictionary:
	var max_hp := 5.0 + _or(m.get("con"), 8.0) * 2.8
	var amin := maxf(1.0, floorf(_or(m.get("force"), 8.0) / 2.5))
	var amax := amin + 1.0 + floorf(_or(m.get("dex"), 8.0) / 3.3)
	return {"maxHp": max_hp, "atkMin": amin, "atkMax": amax}

static func _preview_text(m: Dictionary) -> String:
	var d := _mon_derived(m)
	return "%s %s · %s %d-%d" % [L.t("common.pv"), _js_num(d.maxHp), L.t("common.atq"), int(d.atkMin), int(d.atkMax)]

static func _door_options(lvl: Dictionary) -> Array:
	var out: Array = [["", _plain(L.t("admin.levels.aucune"))]]
	for d in lvl.get("doors", []):
		out.append([d.id, L.fa(L.t("common.porte"), [int(d.x), int(d.y)])])
	return out

static func _add_monster(lvl: Dictionary) -> void:
	var m := _new_monster(lvl, int(lvl.startX), int(lvl.startY))
	_open_mon = str(m.id)
	_touch(true)

static func _monsters_panel(host: VBoxContainer, lvl: Dictionary) -> void:
	var mons: Array = lvl.monsters
	var title_text := L.fa(L.t("ui.atelier.lv_mons_n") if mons.size() != 1 else L.t("ui.atelier.lv_mons_1"), mons.size())
	host.add_child(_header_row(title_text, Ax.btn(L.t("ui.atelier.lv_add"), func(): _add_monster(lvl), "gold", 34.0, 12, 12)))
	for i in mons.size():
		_mon_card(host, lvl, mons[i], i + 1)

static func _tag(host: Control, text: String, col: Color) -> void:
	host.add_child(Ax.chip(text, col, Ax.CLEAR, col, 11, 9, 9, 3))

static func _mon_card(host: Control, lvl: Dictionary, m: Dictionary, n: int) -> void:
	var mid := str(m.id)
	var open := mid == _open_mon
	var card := Ax.panel(Ax.GOLD_BG2 if open else Color(0.118, 0.086, 0.051, 0.85), Ax.GOLD if open else Ax.LINE, 14, 12, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(card)
	var v := Ax.vbox(12)
	card.add_child(v)
	var hd := Ax.hbox(12)
	var badge := Ax.panel(RED_BG, RED_BORDER, 10, 0, 0)
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bn := Ax.lab(str(n), 14, Ax.RED, 700)
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bn)
	hd.add_child(badge)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl := Ax.lab(str(m.get("name", "")), 14, Ax.CREAM, 600)
	nl.clip_text = true
	nl.custom_minimum_size.x = 10
	tv.add_child(nl)
	var pos := L.fa(L.t("ui.atelier.lv_pos"), [int(m.x), int(m.y)])
	if bool(m.get("isGroup", false)):
		pos += " · " + L.fa(L.t("ui.atelier.lv_tag_group"), 3 if int(_or(m.get("groupSize"), 2.0)) == 3 else 2)
	var pl := Ax.lab(pos, 12, Ax.MUTED)
	pl.clip_text = true
	pl.custom_minimum_size.x = 10
	tv.add_child(pl)
	hd.add_child(tv)
	var tags := Ax.hbox(4)
	tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if int(_or(m.get("enrageThreshold"), 0.0)) > 0:
		_tag(tags, L.t("ui.atelier.lv_rage"), Ax.RED)
	if bool(m.get("isBoss", false)):
		_tag(tags, L.t("ui.atelier.lv_tag_boss"), Ax.GOLD)
	if bool(m.get("startHidden", false)):
		_tag(tags, L.t("ui.atelier.lv_tag_hidden"), Ax.MUTED)
	hd.add_child(tags)
	v.add_child(hd)
	Ax.clickable(hd, func():
		_open_mon = "" if open else mid
		_render_sub())
	if open:
		_mon_editor(v, lvl, m)

static func _mon_editor(v: VBoxContainer, lvl: Dictionary, m: Dictionary) -> void:
	var idr := Ax.hbox(10)
	idr.add_child(_vc(IconPicker.button(_admin.modals(), m, "icon", func(): Ax.changed(), 44.0)))
	idr.add_child(Ax.text_field(m, "name", 40, 14, "", func(_t): _admin.note(str(m.get("name", "")))))
	v.add_child(idr)
	var prev := Ax.lab(_preview_text(m), 12, Ax.GOLD_L, 600)
	var upd := func(_x = 0.0): prev.text = _preview_text(m)
	var g := Ax.grid2(v)
	g.add_child(_num(m, "force", 8, 0, 999, L.t("common.for"), upd))
	g.add_child(_num(m, "dex", 8, 0, 999, "Dex", upd))
	g.add_child(_num(m, "con", 8, 0, 999, "Con", upd))
	g.add_child(Ax.labeled(L.t("common.vitesse"), Ax.stepper(Stats.monster_speed(m), 0, 999, 1, func(val: float):
		m["speed"] = Ax.num_value(val)
		_touch())))
	v.add_child(prev)
	var g2 := Ax.grid2(v)
	g2.add_child(_num(m, "resistPhys", 0, 0, 100, L.t("admin.levels.res_phys"), Callable(), "%"))
	g2.add_child(_num(m, "resistMagic", 0, 0, 100, L.t("admin.levels.res_mag"), Callable(), "%"))
	g2.add_child(_num(m, "xpReward", 10, 0, 99999, "XP"))
	g2.add_child(_num(m, "goldReward", 0, 0, 99999, _plain(L.t("common.or"))))
	g2.add_child(_num(m, "patrolRadius", 0, 0, 99, "Zone"))
	g2.add_child(Ax.labeled(_plain(L.t("admin.levels.ouvre_porte")), Ax.select(_door_options(lvl), str(m.get("opensDoorId", "")), func(val):
		m["opensDoorId"] = val
		_touch(), 36.0, 13)))
	# capacité spéciale
	var spells: Array = [["", _plain(L.t("admin.levels.attaque_simple"))]]
	for s in _cfg().get("spells", []):
		if s.get("mode") == "damage":
			spells.append([s.id, str(s.get("name", ""))])
	v.add_child(Ax.labeled(_plain(L.t("admin.levels.capacite_chance")), Ax.select(spells, str(m.get("abilitySpellId", "")), func(val):
		m["abilitySpellId"] = val
		_touch(true), 36.0, 13)))
	if str(m.get("abilitySpellId", "")) != "":
		var cg := Ax.grid2(v)
		cg.add_child(_num(m, "abilityChance", 30, 0, 100, L.t("admin.levels.chance"), Callable(), "%"))
	# rage
	var rage_on := int(_or(m.get("enrageThreshold"), 0.0)) > 0
	_toggle(v, L.t("ui.atelier.lv_rage"), rage_on, func(on: bool):
		if on:
			if int(_or(m.get("enrageThreshold"), 0.0)) <= 0:
				m["enrageThreshold"] = 40
			if int(_or(m.get("enrageBonusPct"), 0.0)) <= 0:
				m["enrageBonusPct"] = 30
		else:
			m["enrageThreshold"] = 0
		_touch(true))
	if rage_on:
		var rg := Ax.grid2(v)
		rg.add_child(_num(m, "enrageThreshold", 40, 1, 100, L.t("ui.atelier.lv_rage_at"), Callable(), "%"))
		rg.add_child(_num(m, "enrageBonusPct", 30, 0, 300, L.t("ui.atelier.lv_rage_bonus"), Callable(), "%"))
	# effet infligé
	var cur_fx := "sleep" if str(m.get("hitStatusLook", "")) == "sleep" else str(m.get("hitStatus", ""))
	var fx_opts: Array = [["", _plain(L.t("admin.levels.effet_aucun"))]]
	for t in ["poison", "burn", "lifedrain", "stun", "sleep", "freeze", "slow", "weaken", "warcry"]:
		var probe := {"type": "stun" if t == "sleep" else t, "look": "sleep" if t == "sleep" else ""}
		fx_opts.append([t, Statuses.label_of(probe)])
	v.add_child(Ax.labeled(_plain(L.t("admin.levels.effet")), Ax.select(fx_opts, cur_fx, func(val):
		m["hitStatus"] = "stun" if val == "sleep" else val
		m["hitStatusLook"] = "sleep" if val == "sleep" else ""
		if val != "":
			if int(_or(m.get("hitStatusChance"), 0.0)) <= 0:
				m["hitStatusChance"] = 30
			if int(_or(m.get("hitStatusDuration"), 0.0)) <= 0:
				m["hitStatusDuration"] = 2
			if int(_or(m.get("hitStatusPower"), 0.0)) <= 0:
				m["hitStatusPower"] = 2
		_touch(true), 36.0, 13)))
	if cur_fx != "":
		var fg := Ax.grid2(v)
		fg.add_child(_num(m, "hitStatusChance", 30, 0, 100, L.t("admin.levels.chance"), Callable(), "%"))
		fg.add_child(_num(m, "hitStatusDuration", 2, 1, 20, _plain(L.t("admin.levels.effet_duree"))))
	# résistances par école (négatif = faiblesse)
	v.add_child(Ax.cap(_plain(L.t("admin.levels.resists"))))
	var rz := Ax.grid2(v)
	for rk in Resist.KEYS:
		var key: String = rk
		var st := Ax.stepper(float(Resist.of_monster(m, key)), -100, 100, 1, func(val: float):
			var cur: Dictionary = m.get("resists", {}) if m.get("resists") is Dictionary else {}
			var iv := clampi(int(val), -100, 100)
			if iv == 0:
				cur.erase(key)
			else:
				cur[key] = iv
			if cur.is_empty():
				m.erase("resists")
			else:
				m["resists"] = cur
			_touch(), 36.0, "%")
		rz.add_child(Ax.labeled(_plain(L.t(str(Resist.NAME_KEYS[key]))), st))
	# butin
	v.add_child(Ax.cap(_plain(L.t("admin.levels.butin"))))
	_loot_row(v, lvl, m, "lootItemId", "lootChance")
	_loot_row(v, lvl, m, "lootItemId2", "lootChance2")
	# boss / groupe / caché
	_toggle(v, "Boss", bool(m.get("isBoss", false)), func(on: bool):
		m["isBoss"] = on
		if on:
			m["isGroup"] = false
			if int(_or(m.get("enrageThreshold"), 0.0)) <= 0:
				m["enrageThreshold"] = 40
				m["enrageBonusPct"] = 30
		_touch(true))
	_toggle(v, _plain(L.t("admin.levels.groupe")), bool(m.get("isGroup", false)), func(on: bool):
		m["isGroup"] = on
		if on:
			m["isBoss"] = false
			if _or(m.get("groupSize"), 0.0) == 0.0:
				m["groupSize"] = 2
		_touch(true))
	if bool(m.get("isGroup", false)):
		var sz := 3 if int(_or(m.get("groupSize"), 2.0)) == 3 else 2
		v.add_child(Ax.seg([["2", "2"], ["3", "3"]], str(sz), func(id: String):
			m["groupSize"] = int(id)
			_touch(true)))
	_hidden_block(v, lvl, m, "switchRevealMonsterId")
	var br := Ax.hbox(8)
	br.add_child(Ax.btn(_plain(L.t("admin.levels.placer_sur_la_carte")), func(): _start_placement("monster", str(m.id)), "gold", 36.0, 12, 12, "target"))
	br.add_child(Ax.btn(L.t("ui.atelier.lv_remove"), func():
		(lvl.monsters as Array).erase(m)
		_open_mon = ""
		_touch(true), "danger", 36.0, 12, 12))
	v.add_child(br)

static func _loot_row(v: Control, lvl: Dictionary, m: Dictionary, key: String, chance_key: String) -> void:
	var r := Ax.hbox(8)
	var id := str(m.get(key, ""))
	var cur: Dictionary = _find(lvl.items, id) if id != "" else {}
	var b := Ax.btn(_plain(L.t("common.aucun")) if cur.is_empty() else str(cur.get("name", "")), func():
		LootPicker.open(_admin.modals(), lvl.items, func(picked: String):
			m[key] = picked
			_touch()
			_render_sub.call_deferred()), "ghost", 36.0, 12, 13)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	r.add_child(b)
	var ch := Ax.stepper(float(_or(m.get(chance_key), 100.0)), 0, 100, 1, func(val: float):
		m[chance_key] = Ax.num_value(val)
		_touch(), 36.0, "%")
	ch.custom_minimum_size.x = 112
	r.add_child(ch)
	v.add_child(r)

## « Lié à un interrupteur » : l'entité reste cachée tant qu'un levier ne la révèle pas.
static func _hidden_block(v: Control, lvl: Dictionary, e: Dictionary, reveal_key: String) -> void:
	v.add_child(Ax.line())
	v.add_child(Ax.cap(L.t("ui.atelier.lv_linked")))
	var p := Ax.panel(Color(0.118, 0.086, 0.051, 0.85), Ax.LINE, 10, 12, 10)
	var r := Ax.hbox(12)
	p.add_child(r)
	var ib := Ax.panel(Color("241a0e"), Ax.CLEAR, 9, 0, 0, 0)
	ib.custom_minimum_size = Vector2(34, 34)
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Ax.ico("lever", 18, Ax.GOLD, 1.7)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ib.add_child(ic)
	r.add_child(ib)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(Ax.para(L.t("ui.atelier.lv_hidden_until"), 13, Ax.CREAM, 500))
	var lever_txt := L.t("ui.atelier.lv_no_lever")
	for it in lvl.get("items", []):
		if str(it.get("type", "")) == "switch" and str(it.get(reveal_key, "")) == str(e.id):
			lever_txt = L.fa(L.t("ui.atelier.lv_lever"), [int(it.x), int(it.y)])
			break
	tv.add_child(Ax.para(lever_txt, 12, Ax.MUTED))
	r.add_child(tv)
	r.add_child(_vc(Ax.switch(bool(e.get("startHidden", false)), func(on: bool):
		e["startHidden"] = on
		_touch())))
	v.add_child(p)

# ---- onglet Objets

## Bornes d'un champ numérique d'objet (`clampItemStat`).
static func _clamp_item_stat(it: Dictionary, field: String, v: float) -> float:
	return AdminItems.clamp_value(it, field, v)

static func _add_item(lvl: Dictionary) -> void:
	var it := _new_item(lvl, int(lvl.startX), int(lvl.startY), "potion")
	_open_item = str(it.id)
	_touch(true)

static func _type_label(t: String) -> String:
	for x in ITEM_TYPES:
		if x[0] == t:
			return _plain(L.t(str(x[1])))
	return t

static func _type_icon(t: String) -> String:
	for x in ITEM_TYPES:
		if x[0] == t:
			return str(x[2])
	return "chest"

static func _items_panel(host: VBoxContainer, lvl: Dictionary) -> void:
	var list: Array = []
	for it in lvl.items:
		if str(it.get("type", "")) != "decor":
			list.append(it)
	var title_text := L.fa(L.t("ui.atelier.lv_items_n") if list.size() != 1 else L.t("ui.atelier.lv_items_1"), list.size())
	host.add_child(_header_row(title_text, Ax.btn(L.t("ui.atelier.lv_add"), func(): _add_item(lvl), "gold", 34.0, 12, 12)))
	for it in list:
		_item_card(host, lvl, it)

static func _item_card(host: Control, lvl: Dictionary, it: Dictionary) -> void:
	var iid := str(it.id)
	var open := iid == _open_item
	var card := Ax.panel(Ax.GOLD_BG2 if open else Color(0.118, 0.086, 0.051, 0.85), Ax.GOLD if open else Ax.LINE, 14, 12, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(card)
	var v := Ax.vbox(12)
	card.add_child(v)
	var hd := Ax.hbox(12)
	var badge := Ax.panel(Color("241a0e"), Ax.LINE2, 10, 0, 0)
	badge.custom_minimum_size = Vector2(40, 40)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Ax.ico(_type_icon(str(it.get("type", ""))), 22, Ax.GOLD, 1.7)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(ic)
	hd.add_child(badge)
	var tv := Ax.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl := Ax.lab(str(it.get("name", "")), 14, Ax.CREAM, 600)
	nl.clip_text = true
	nl.custom_minimum_size.x = 10
	tv.add_child(nl)
	var pl := Ax.lab("%s · %s" % [_type_label(str(it.get("type", ""))), L.fa(L.t("ui.atelier.lv_pos"), [int(it.x), int(it.y)])], 12, Ax.MUTED)
	pl.clip_text = true
	pl.custom_minimum_size.x = 10
	tv.add_child(pl)
	hd.add_child(tv)
	if bool(it.get("startHidden", false)):
		var tags := Ax.hbox(4)
		tags.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_tag(tags, L.t("ui.atelier.lv_tag_hidden"), Ax.MUTED)
		hd.add_child(tags)
	v.add_child(hd)
	Ax.clickable(hd, func():
		_open_item = "" if open else iid
		_render_sub())
	if open:
		_item_editor(v, lvl, it)

static func _item_editor(v: VBoxContainer, lvl: Dictionary, it: Dictionary) -> void:
	var t := str(it.get("type", ""))
	var top := _header_row("%s · %s" % [_type_label(t), L.fa(L.t("ui.atelier.lv_pos"), [int(it.x), int(it.y)])], Ax.btn(L.t("ui.atelier.lv_remove"), func():
		_remove_item(lvl, str(it.id))
		_open_item = ""
		_touch(true), "danger", 34.0, 12, 12))
	v.add_child(top)
	var idr := Ax.hbox(10)
	idr.add_child(_vc(IconPicker.button(_admin.modals(), it, "icon", func(): Ax.changed(), 44.0)))
	idr.add_child(Ax.text_field(it, "name", 40, 14, "", func(_t): _admin.note(str(it.get("name", "")))))
	v.add_child(idr)
	var opts: Array = []
	for x in ITEM_TYPES:
		opts.append([x[0], _plain(L.t(str(x[1])))])
	v.add_child(Ax.select(opts, t, func(val):
		it["type"] = val
		if val == "chest" and not it.has("wall"):
			it["wall"] = _chest_auto_wall(lvl, int(it.x), int(it.y))
		_touch(true), 36.0, 13))
	_item_details(v, it, lvl)
	_hidden_block(v, lvl, it, "switchRevealItemId")
	v.add_child(Ax.btn(_plain(L.t("admin.levels.placer_sur_la_carte")), func(): _start_placement("item", str(it.id)), "gold", 36.0, 12, 12, "target"))

static func _classes_allowing(spell_id: String) -> Array:
	var out: Array = []
	for c in _cfg().get("classes", []):
		if AdminUtil.eff_spells(c).has(spell_id):
			out.append(str(c.get("name", "")))
	return out

static func _istat(g: Control, it: Dictionary, key: String, label: String, def: float = 0.0) -> void:
	var lo := AdminItems.clamp_value(it, key, -1.0e9)
	var hi := 100.0 if AdminItems.BOOST_FIELDS.has(key) else 9999.0
	g.add_child(Ax.num(it, key, def, lo, hi, label, 1.0, "", func(_v): _touch()))

static func _boosts(v: Control, it: Dictionary) -> void:
	var g := Ax.grid2(v)
	for x in [[L.t("common.for"), "bonusForce"], ["Dex", "bonusDex"], ["Con", "bonusCon"], ["Int", "bonusInt"], ["Vit", "bonusSpeed"]]:
		_istat(g, it, str(x[1]), str(x[0]))

## Champs propres au type de l'objet (`itemDetailsHtml`).
static func _item_details(v: VBoxContainer, it: Dictionary, lvl: Dictionary) -> void:
	var refresh := func(): _render_sub.call_deferred()
	match str(it.get("type", "")):
		"potion":
			var g := Ax.grid2(v)
			_istat(g, it, "heal", L.t("common.soin"), 5.0)
			_istat(g, it, "staminaRestore", L.t("common.endurance"))
		"weapon":
			var wt: Array = []
			for w in AdminUtil.weapon_types():
				wt.append([w.id, w.label])
			v.add_child(Ax.labeled(L.t("ui.atelier.i_weapon_type"), Ax.select(wt, str(it.get("weaponType", "")), func(val):
				it["weaponType"] = val
				_touch(), 36.0, 13)))
			var g := Ax.grid2(v)
			_istat(g, it, "bonusAtkMin", L.t("admin.levels.bonus_min"))
			_istat(g, it, "bonusAtkMax", L.t("admin.levels.bonus_max"))
			_boosts(v, it)
			AdminItems._rarity(v, it, refresh)
		"armor":
			var slots: Array = []
			for s in Data.constants.get("SLOT_TYPES", []):
				if s.id != "weapon" and s.id != "accessory":
					slots.append([s.id, s.label])
			v.add_child(Ax.labeled(L.t("ui.atelier.i_type"), Ax.select(slots, str(it.get("slot", "")), func(val):
				it["slot"] = val
				_touch(), 36.0, 13)))
			var g := Ax.grid2(v)
			_istat(g, it, "bonusHp", L.t("common.pv"))
			_istat(g, it, "bonusAtkMin", L.t("common.atq") + " min")
			_istat(g, it, "bonusAtkMax", L.t("common.atq") + " max")
			_istat(g, it, "bonusSpellDmg", L.t("common.sort"))
			_boosts(v, it)
			AdminItems._rarity(v, it, refresh)
		"jewelry":
			var g := Ax.grid2(v)
			_istat(g, it, "bonusHp", L.t("common.pv"))
			_istat(g, it, "bonusAtkMin", L.t("common.atq") + " min")
			_istat(g, it, "bonusAtkMax", L.t("common.atq") + " max")
			_istat(g, it, "bonusSpellDmg", L.t("common.sort"))
			_boosts(v, it)
			AdminItems._rarity(v, it, refresh)
		"key":
			v.add_child(Ax.labeled(_plain(L.t("admin.levels.ouvre_porte")), Ax.select(_door_options(lvl), str(it.get("opensDoorId", "")), func(val):
				it["opensDoorId"] = val
				_touch(), 36.0, 13)))
		"trap":
			var g := Ax.grid2(v)
			_istat(g, it, "trapDmgMin", L.t("common.degats_min"), 1.0)
			_istat(g, it, "trapDmgMax", L.t("common.degats_max"), 4.0)
			_toggle(v, "Permanent", bool(it.get("permanent", false)), func(on: bool):
				it["permanent"] = on
				_touch())
		"switch":
			var doors: Array = [["", _plain(L.t("admin.levels.porte_aucune"))]]
			for d in lvl.get("doors", []):
				doors.append([d.id, L.fa(L.t("admin.levels.porte_2"), [int(d.x), int(d.y)])])
			var mons: Array = [["", _plain(L.t("admin.levels.monstre_aucun"))]]
			for m in lvl.monsters:
				mons.append([m.id, str(m.get("name", ""))])
			var its: Array = [["", _plain(L.t("admin.levels.objet_aucun"))]]
			for o in lvl.items:
				if o.id != it.id:
					its.append([o.id, str(o.get("name", ""))])
			v.add_child(Ax.labeled(L.t("ui.atelier.lv_sw_door"), Ax.select(doors, str(it.get("switchOpensDoorId", "")), func(val):
				it["switchOpensDoorId"] = val
				_touch(true), 36.0, 13)))
			v.add_child(Ax.labeled(L.t("ui.atelier.lv_sw_mon"), Ax.select(mons, str(it.get("switchRevealMonsterId", "")), func(val):
				it["switchRevealMonsterId"] = val
				_touch(true), 36.0, 13)))
			v.add_child(Ax.labeled(L.t("ui.atelier.lv_sw_item"), Ax.select(its, str(it.get("switchRevealItemId", "")), func(val):
				it["switchRevealItemId"] = val
				_touch(true), 36.0, 13)))
			v.add_child(Ax.labeled(_plain(L.t("common.message_affiche")), Ax.text_field(it, "message", 36, 13)))
		"chest":
			_chest_details(v, it, lvl)
		"fountain":
			v.add_child(Ax.para(L.t("admin.levels.restaure_pv_endurance_du_groupe"), 13, Ax.MUTED))
		"scroll":
			var so: Array = []
			for s in _cfg().get("spells", []):
				so.append([s.id, str(s.get("name", ""))])
			if so.is_empty():
				so.append(["", _plain(L.t("common.aucun_sort_defini_2"))])
			var hint := Ax.para("", 12, Ax.MUTED)
			var upd := func():
				var sid := str(it.get("spellId", ""))
				if sid == "":
					hint.text = "—"
				else:
					var names := _classes_allowing(sid)
					hint.text = ", ".join(names) if not names.is_empty() else L.t("admin.levels.aucune_classe")
			v.add_child(Ax.select(so, str(it.get("spellId", "")), func(val):
				it["spellId"] = val
				upd.call()
				_touch(), 36.0, 13))
			upd.call()
			v.add_child(hint)

## Premier côté muré de la case (N, E, S, O) : un coffre se pose toujours contre un mur.
static func _chest_auto_wall(lvl: Dictionary, x: int, y: int) -> String:
	var rows: Array = lvl.mapRows
	for w in [["N", 0, -1], ["E", 1, 0], ["S", 0, 1], ["O", -1, 0]]:
		var nx: int = x + int(w[1])
		var ny: int = y + int(w[2])
		if ny < 0 or ny >= rows.size() or nx < 0 or nx >= str(rows[ny]).length() or str(rows[ny])[nx] == "#":
			return str(w[0])
	return "N"

## Coffre posé à la main (maquette « Panneau-objets ») : quatre emplacements, or, mur d'appui.
static func _chest_details(v: VBoxContainer, it: Dictionary, lvl: Dictionary) -> void:
	if not it.has("wall"):
		it["wall"] = _chest_auto_wall(lvl, int(it.x), int(it.y))
	if not (it.get("contentIds") is Array):
		it["contentIds"] = []
	var ids: Array = it.contentIds
	var lib: Dictionary = {}
	var lib_opts: Array = [["", _plain(L.t("admin.levels.vide"))]]
	for d in _cfg().get("itemLibrary", []):
		lib[str(d.id)] = d
		lib_opts.append([d.id, str(d.get("name", ""))])
	v.add_child(Ax.cap(L.fa(L.t("ui.atelier.lv_contents"), CHEST_SLOTS)))
	var g := Ax.grid2(v, 8)
	for i in CHEST_SLOTS:
		var slot := i
		var cur := str(ids[slot]) if slot < ids.size() and ids[slot] != null else ""
		var def: Dictionary = lib.get(cur, {})
		var full := not def.is_empty()
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Ax.sb(Color(0.118, 0.086, 0.051, 0.9) if full else Ax.CLEAR, Ax.LINE2, 10, 1, 12, 10))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := Ax.vbox(3)
		p.add_child(cv)
		cv.add_child(Ax.lab(L.fa(L.t("ui.atelier.lv_slot"), slot + 1), 11, Ax.DIM))
		var nc := Ax.GREEN if (full and str(def.get("type", "")) == "weapon") else (Ax.CREAM if full else Ax.DIM)
		var nm := Ax.lab(str(def.get("name", "")) if full else _plain(L.t("admin.levels.vide")), 13, nc, 500 if full else 400)
		nm.clip_text = true
		nm.custom_minimum_size.x = 10
		cv.add_child(nm)
		Ax.clickable(p, func():
			_pick_menu(p, lib_opts, func(val):
				while ids.size() <= slot:
					ids.append("")
				ids[slot] = val
				_touch(true)))
		g.add_child(p)
	v.add_child(Ax.para(L.t("ui.atelier.lv_random_empty"), 12, Ax.MUTED))
	var g2 := Ax.grid2(v)
	g2.add_child(Ax.num(it, "gold", 0, 0, 99999, L.t("ui.atelier.lv_chest_gold"), 1.0, "", func(_v): _touch()))
	var walls := [["auto", _plain(L.t("admin.levels.coffre_mur_auto"))], ["N", _plain(L.t("admin.levels.nord"))], ["E", _plain(L.t("admin.levels.coffre_est"))], ["S", _plain(L.t("admin.levels.coffre_sud"))], ["O", _plain(L.t("admin.levels.ouest"))]]
	g2.add_child(Ax.labeled(L.t("ui.atelier.lv_chest_wall"), Ax.select(walls, "auto" if bool(it.get("wallAuto", true)) else str(it.get("wall", "N")), func(val):
		it["wallAuto"] = (val == "auto")
		it["wall"] = _chest_auto_wall(lvl, int(it.x), int(it.y)) if val == "auto" else val
		_touch(), 36.0, 13)))

# ---- onglet Réglages

static func _cfg_panel(host: VBoxContainer, lvl: Dictionary) -> void:
	if _narrow:
		host.add_child(Ax.labeled(L.t("admin.levels.nom_du_niveau"), Ax.text_field(lvl, "name", 40, 14, "", func(_t):
			if _title_lbl != null and is_instance_valid(_title_lbl):
				_title_lbl.text = str(lvl.get("name", "")))))
	host.add_child(_header_row(L.t("ui.atelier.lv_level_settings")))
	# thème + taille
	var theme_opts: Array = []
	for t in THEMES:
		theme_opts.append([t[0], _plain(L.t(str(t[1])))])
	host.add_child(Ax.labeled(_plain(L.t("admin.levels.theme_visuel")), Ax.select(theme_opts, str(lvl.get("theme", "stone")), func(val):
		lvl["theme"] = val
		_touch(), 40.0, 14)))
	var d := _dims(lvl)
	var dims := {"w": d.x, "h": d.y}
	host.add_child(Ax.cap(L.t("ui.atelier.lv_size")))
	var sg := Ax.grid2(host)
	sg.add_child(_dim_field(dims, "w", _plain(L.t("admin.levels.largeur"))))
	sg.add_child(_dim_field(dims, "h", _plain(L.t("admin.levels.hauteur"))))
	host.add_child(Ax.para(L.t("admin.levels.max_60").lstrip("(").rstrip(")"), 12, Ax.MUTED))
	host.add_child(Ax.btn(_plain(L.t("admin.levels.redimensionner")), func(): _resize(lvl, int(dims.w), int(dims.h)), "ghost", 36.0, 12, 13))
	# lumière
	host.add_child(Ax.line())
	host.add_child(Ax.cap(L.t("ui.atelier.lv_light")))
	_light_row(host, _plain(L.t("admin.levels.lumiere_ambiante")), lvl, "lightAmbient", 0.1, 1.6, 1.1)
	_light_row(host, _plain(L.t("admin.levels.intensite_des_torches")), lvl, "lightTorch", 0.2, 2.6, 1.4)
	# départ
	host.add_child(Ax.line())
	host.add_child(Ax.cap(L.t("ui.atelier.lv_start_cap")))
	var pg := Ax.grid2(host)
	pg.add_child(Ax.num(lvl, "startX", 0, 0, 59, "X", 1.0, "", func(_v): _touch()))
	pg.add_child(Ax.num(lvl, "startY", 0, 0, 59, "Y", 1.0, "", func(_v): _touch()))
	var dir_opts: Array = []
	for x in DIRS:
		dir_opts.append([x[0], _plain(L.t(str(x[1])))])
	host.add_child(Ax.labeled(_plain(L.t("admin.levels.direction_de_depart")), Ax.select(dir_opts, int(lvl.get("startDir", 1)), func(val):
		lvl["startDir"] = int(val)
		_touch(), 36.0, 13)))
	host.add_child(Ax.btn(_plain(L.t("admin.levels.choisir_le_depart_sur_la")), func(): _start_placement("start"), "gold", 36.0, 12, 13, "flag"))
	var tp := Ax.hbox(8)
	var b1 := Ax.btn(_plain(L.t("admin.levels.teleporter_le_groupe_ici_tests")), func(): _pick_teleport(), "ghost", 36.0, 10, 12)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.clip_text = true
	var b2 := Ax.btn(_plain(L.t("admin.levels.teleporter_au_village_tests")), func(): _go_village(), "ghost", 36.0, 10, 12)
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.clip_text = true
	tp.add_child(b1)
	tp.add_child(b2)
	host.add_child(tp)
	# escaliers
	host.add_child(Ax.line())
	host.add_child(Ax.cap(_plain(L.t("admin.levels.escaliers_de_ce_niveau"))))
	_ensure_stairs(lvl)
	if (lvl.stairs as Array).is_empty():
		host.add_child(Ax.para(_plain(L.t("admin.levels.aucun_escalier_sur_ce_niveau")), 12, Ax.MUTED))
	for st in lvl.stairs:
		host.add_child(_stairs_card(lvl, st))
	host.add_child(Ax.para(_plain(L.t("admin.levels.peignez_sur_la_carte_onglet")), 12, Ax.MUTED))
	# salles
	host.add_child(Ax.line())
	_room_styles(host, lvl)
	# marchand
	host.add_child(Ax.line())
	host.add_child(Ax.cap(_plain(L.t("common.marchand_ambulant"))))
	_merchant(host, lvl)
	host.add_child(Ax.line())
	host.add_child(Ax.btn(_plain(L.t("admin.levels.supprimer_ce_niveau")), func(): _delete_level(), "danger", 40.0, 16, 13))

## Curseur de lumière : libellé et valeur sur une ligne, curseur dessous.
static func _light_row(host: Control, label: String, lvl: Dictionary, key: String, lo: float, hi: float, def: float) -> void:
	var cur := _light(lvl, key, def)
	var v := Ax.vbox(6)
	var h := Ax.hbox(8)
	var nl := Ax.lab(label, 13, Ax.CREAM, 500)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	var vl := Ax.lab("%.2f" % cur, 13, Ax.GOLD_L, 600)
	h.add_child(vl)
	v.add_child(h)
	var sl := Ax.slider(cur, lo, hi, 0.05)
	sl.value_changed.connect(func(x: float):
		var q := snappedf(x, 0.05)
		lvl[key] = q
		vl.text = "%.2f" % q
		_touch())
	v.add_child(sl)
	host.add_child(v)

static func _light(lvl: Dictionary, key: String, def: float) -> float:
	return float(lvl[key]) if lvl.get(key) != null else def

static func _dim_field(dims: Dictionary, key: String, label: String) -> Control:
	return Ax.labeled(label, Ax.stepper(float(dims[key]), 4, 60, 1, func(val: float): dims[key] = int(val)))

static func _pick_teleport() -> void:
	if not _has_run():
		_alert(L.t("common.aucune_partie_en_cours_lancez"))
		return
	_start_placement("teleport")

static func _go_village() -> void:
	var err: String = _teleport_village()
	if err != "":
		_alert(err)

## Style de décoration de chaque salle repérée sur la carte (Auto : selon le contenu et le thème, voir RoomStyles).
static func _room_styles(host: Control, lvl: Dictionary) -> void:
	var rooms := RoomMap.detect(lvl.mapRows)
	host.add_child(Ax.cap(_plain(L.t("admin.levels.styles_des_salles"))))
	if rooms.is_empty():
		host.add_child(Ax.para(_plain(L.t("admin.levels.aucune_salle_sur_ce_niveau")), 12, Ax.MUTED))
		return
	host.add_child(Ax.para(_plain(L.t("admin.levels.salles_aide")), 12, Ax.MUTED))
	var opts: Array = [["", _plain(L.t("admin.levels.style_auto"))]]
	for id in RoomStyles.ALL:
		opts.append([id, _style_label(id)])
	var auto := RoomStyles.assign(lvl, rooms, str(lvl.get("theme", "stone")))
	if not (lvl.get("roomStyles") is Dictionary):
		lvl["roomStyles"] = {}
	var chosen: Dictionary = lvl.roomStyles
	var order: Array = rooms.duplicate()
	order.sort_custom(func(a, b): return a.rect.position.y < b.rect.position.y or (a.rect.position.y == b.rect.position.y and a.rect.position.x < b.rect.position.x))
	for r in order:
		var rect: Rect2i = r.rect
		var key := RoomStyles.key_of(rect)
		var cv := Ax.vbox(4)
		var sel := Ax.select(opts, str(chosen.get(key, "")), func(val):
			if str(val) == "":
				chosen.erase(key)
			else:
				chosen[key] = str(val)
			_touch(), 36.0, 13)
		cv.add_child(Ax.labeled(L.fa(L.t("admin.levels.salle_n"), [int(r.id) + 1, rect.position.x, rect.position.y, rect.size.x, rect.size.y]), sel))
		cv.add_child(Ax.lab(L.fa(L.t("admin.levels.salle_auto_donne"), _style_label(str(auto.get(int(r.id), "commune")))), 11, Ax.DIM))
		host.add_child(cv)

static func _style_label(id: String) -> String:
	match id:
		"bibliotheque": return _plain(L.t("admin.levels.style_bibliotheque"))
		"armes": return _plain(L.t("admin.levels.style_armes"))
		"cellier": return _plain(L.t("admin.levels.style_cellier"))
		"autel": return _plain(L.t("admin.levels.style_autel"))
		"ruine": return _plain(L.t("admin.levels.style_ruine"))
		"commune": return _plain(L.t("admin.levels.style_commune"))
		"humide": return _plain(L.t("admin.levels.style_humide"))
		"tresor": return _plain(L.t("admin.levels.style_tresor"))
		"repaire": return _plain(L.t("admin.levels.style_repaire"))
		"marche": return _plain(L.t("admin.levels.style_marche"))
	return id

# ---- escaliers

## Champ numérique conservant le texte tel quel (« Arrivée X / Y » : vide = départ du niveau).
static func _raw_field(target: Dictionary, key: String, placeholder: String) -> LineEdit:
	var e := Ax.field(str(target[key]) if target.has(key) and target[key] != null else "", Callable(), 36, 13, placeholder)
	var ok := RegEx.create_from_string("^[0-9eE.+\\-]*$")
	var last := [e.text]
	e.text_changed.connect(func(t: String):
		if ok.search(t) == null:
			var c := e.caret_column - 1
			e.text = last[0]
			e.caret_column = clampi(c, 0, e.text.length())
			return
		last[0] = t
		var s := t.strip_edges()
		target[key] = s if (s == "" or s.is_valid_float()) else ""
		Ax.changed())
	return e

static func _parse(t: String) -> float:
	var s := t.strip_edges()
	return s.to_float() if s.is_valid_float() else 0.0

static func _stairs_card(lvl: Dictionary, st: Dictionary) -> Control:
	var p := Ax.panel(Color(0.118, 0.086, 0.051, 0.8), Ax.LINE2, 14, 14, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ax.vbox(10)
	p.add_child(v)
	var hd := Ax.hbox(8)
	hd.add_child(_vc(Ax.ico("stairs", 18, Ax.GOLD, 1.8)))
	var tl := Ax.lab(L.fa(_plain(L.t("admin.levels.escalier_en")), [int(st.x), int(st.y)]), 14, Ax.CREAM, 600)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(tl)
	v.add_child(hd)
	var act: Dictionary = st.get("action", {})
	if not (st.get("action") is Dictionary):
		st["action"] = act
	var others: Array = []
	for l in _levels():
		if l.id != lvl.id:
			others.append([l.id, str(l.get("name", ""))])
	v.add_child(Ax.labeled("Action", Ax.select([["victory", _plain(L.t("admin.levels.terminer_la_partie_victoire"))], ["level", _plain(L.t("admin.levels.aller_vers_un_autre_niveau"))]], str(act.get("type", "victory")), func(val):
		if val == "victory":
			st["action"] = {"type": "victory"}
		else:
			st["action"] = {"type": "level", "targetId": others[0][0] if not others.is_empty() else null}
		_touch(true), 36.0, 13)))
	if act.get("type") == "level":
		var target := _level_by_id(act.get("targetId"))
		v.add_child(Ax.labeled(_plain(L.t("admin.levels.niveau_cible")), Ax.select(others, act.get("targetId", ""), func(val):
			act["targetId"] = val
			_touch(true), 36.0, 13)))
		var g := Ax.grid2(v)
		g.add_child(Ax.labeled(_plain(L.t("admin.levels.arrivee")), _raw_field(act, "targetX", _js_num(float(target.get("startX", 0))) if not target.is_empty() else "0")))
		g.add_child(Ax.labeled("Y", _raw_field(act, "targetY", _js_num(float(target.get("startY", 0))) if not target.is_empty() else "0")))
		var dir_opts: Array = [["", _plain(L.t("admin.levels.par_defaut_du_niveau"))]]
		for d in DIRS:
			dir_opts.append([str(d[0]), _plain(L.t(str(d[1])))])
		var cur_dir := ""
		if act.has("targetDir") and str(act.targetDir) != "":
			cur_dir = str(int(_parse(str(act.targetDir))))
		v.add_child(Ax.labeled(_plain(L.t("admin.levels.direction_arrivee")), Ax.select(dir_opts, cur_dir, func(val):
			act["targetDir"] = val
			_touch(), 36.0, 13)))
		v.add_child(Ax.para(L.fa(_plain(L.t("admin.levels.laissez_y_vides_pour_arriver")), (str(target.get("name", "")) if not target.is_empty() else L.t("admin.levels.ce_niveau"))), 12, Ax.MUTED))
	return p

# ---- marchand ambulant

static func _merchant(host: VBoxContainer, lvl: Dictionary) -> void:
	var tm = lvl.get("travelingMerchant")
	if not (tm is Dictionary):
		host.add_child(Ax.para(_plain(L.t("admin.levels.aucun_marchand_sur_ce_niveau")), 12, Ax.MUTED))
		host.add_child(Ax.btn(_plain(L.t("admin.levels.ajouter_un_marchand_ambulant")), func():
			lvl["travelingMerchant"] = {"x": int(lvl.startX), "y": int(lvl.startY), "patrolRadius": 4, "lootSlotCount": 6, "lootItemIds": []}
			_touch(true), "gold", 36.0, 12, 13))
		return
	var count := 8 if int(_or(tm.get("lootSlotCount"), 6.0)) == 8 else 6
	if not (tm.get("lootItemIds") is Array):
		tm["lootItemIds"] = []
	var ids: Array = tm.lootItemIds
	var pr := Ax.hbox(10)
	pr.add_child(_vc(Ax.lab(L.fa(L.t("ui.atelier.lv_pos"), [int(tm.x), int(tm.y)]), 13, Ax.CREAM, 600)))
	pr.add_child(Ax.spacer())
	pr.add_child(Ax.btn(_plain(L.t("admin.levels.placer_sur_la_carte")), func(): _start_placement("merchant"), "gold", 34.0, 12, 12, "target"))
	host.add_child(pr)
	var g := Ax.grid2(host)
	g.add_child(Ax.num(tm, "patrolRadius", 4, 0, 99, _plain(L.t("admin.levels.rayon_de_patrouille")), 1.0, "", func(_v): _touch()))
	g.add_child(Ax.labeled(_plain(L.t("admin.levels.nombre_objets_en_vente")), Ax.select([[6, "6"], [8, "8"]], count, func(val):
		tm["lootSlotCount"] = 8 if int(val) == 8 else 6
		_touch(true), 36.0, 13)))
	host.add_child(Ax.para(_plain(L.t("admin.levels.emplacements_laisses_vides_le")), 12, Ax.MUTED))
	var lib: Array = [["", _plain(L.t("admin.levels.vide"))]]
	for it in _cfg().get("itemLibrary", []):
		lib.append([it.id, str(it.get("name", ""))])
	var sg := Ax.grid2(host)
	for i in count:
		var slot := i
		var cur := str(ids[slot]) if slot < ids.size() and ids[slot] != null else ""
		sg.add_child(Ax.labeled(L.fa(_plain(L.t("common.emplacement")), i + 1), Ax.select(lib, cur, func(val):
			while ids.size() <= slot:
				ids.append("")
			ids[slot] = val
			_touch(), 36.0, 13)))
	host.add_child(Ax.btn(_plain(L.t("admin.levels.retirer_le_marchand_de_ce")), func():
		lvl["travelingMerchant"] = null
		_touch(true), "danger", 36.0, 12, 13))
