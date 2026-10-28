class_name AdminChars
extends RefCounted
## Page « Groupe de départ » de l'atelier : une carte par héros, puis la fiche du héros choisi (portrait, nom, classe, icône, caractéristiques,
## équipement de départ, sorts connus). Contient aussi les petits constructeurs de contrôles compacts de l'original (champs, listes,
## cases, pastilles) partagés avec AdminClasses / AdminClassTalents.

const BORDER := Color("5a4526")
const GOLD_DIM := Color("a9793a")
const GOLD_BRIGHT := Color("ffd88a")
const PDIM := Color("b8a781")
const PARCH2 := Color("efe1c2")
const STATUS_COL := Color("7a6a52")

static var _chk_cache: Dictionary = {}

# ------------------------------------------------------------------ constructeurs de contrôles compacts

## Traduit un texte français de l'interface (pour les textes construits à la main : infobulles, messages d'état).
static func T(s: String) -> String:
	return String(TranslationServer.translate(s))

static func fpx(rem: float) -> int:
	return maxi(8, roundi(UiMetrics.rem(rem)))

static func cpx(px: float) -> float:
	return UiMetrics.css(px)

## Appelle `cb(texte)` quand la saisie est validée (Entrée ou perte du focus) ET a changé : l'évènement `change` du HTML.
static func on_commit(e: LineEdit, cb: Callable) -> void:
	var st := {"last": e.text}
	var fire := func(_t = ""):
		if e.text != st.last:
			st.last = e.text
			cb.call(e.text)
	e.text_submitted.connect(fire)
	e.focus_exited.connect(fire)

## `Number(texte)||0` : entier si la valeur est entière.
static func parse_num(t: String) -> Variant:
	var s := t.strip_edges()
	if s == "" or not s.is_valid_float():
		return 0
	var f := s.to_float()
	return int(f) if is_equal_approx(f, roundf(f)) else f

static func num_text(v: Variant, blank_zero: bool = false) -> String:
	if blank_zero and (v == null or float(v) == 0.0):
		return ""
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return str(v)

static func plate_box(hover: bool = false, pad_h: float = 6.0, pad_v: float = 3.0, radius: float = 6.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("4a3a22") if hover else Color("3a2c18")
	s.border_color = GOLD_DIM if hover else Color("6a5432")
	s.set_border_width_all(1)
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = cpx(pad_h)
	s.content_margin_right = cpx(pad_h)
	s.content_margin_top = cpx(pad_v)
	s.content_margin_bottom = cpx(pad_v)
	return s

## Liste déroulante compacte (`select`) : options [[valeur, libellé], …] ; `disabled_vals` = valeurs grisées.
static func select(options: Array, current: Variant, on_pick: Callable, width_css: float = 0.0, rem: float = 0.74, pad_h: float = 5.0, pad_v: float = 5.0, expand: bool = false, disabled_vals: Array = [], fit: bool = false) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = fit
	o.clip_text = not fit
	o.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if width_css > 0.0:
		o.custom_minimum_size.x = cpx(width_css)
	if expand:
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	o.add_theme_font_size_override("font_size", fpx(rem))
	o.add_theme_constant_override("arrow_margin", int(cpx(2.0)))
	o.add_theme_constant_override("h_separation", int(cpx(2.0)))
	o.add_theme_stylebox_override("normal", plate_box(false, pad_h, pad_v))
	o.add_theme_stylebox_override("hover", plate_box(true, pad_h, pad_v))
	o.add_theme_stylebox_override("pressed", plate_box(true, pad_h, pad_v))
	o.add_theme_stylebox_override("focus", plate_box(true, pad_h, pad_v))
	o.add_theme_stylebox_override("disabled", plate_box(false, pad_h, pad_v))
	o.add_theme_color_override("font_color", PARCH2)
	o.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	var sel := 0
	for i in options.size():
		o.add_item(str(options[i][1]))
		if str(options[i][0]) == str(current):
			sel = i
		if disabled_vals.has(options[i][0]):
			o.set_item_disabled(i, true)
	var pop := o.get_popup()
	pop.add_theme_font_size_override("font_size", maxi(13, fpx(rem)))
	if options.size() > 0:
		o.select(sel)
	o.item_selected.connect(func(i: int): on_pick.call(options[i][0]))
	return o

## Alerte modale (`showAlert`) : sans titre, bouton « OK » principal.
static func alert(admin: Node, text: String) -> Modal:
	var m := Modal.open(admin.modals(), "", 380.0)
	m.add_text(text, UiTheme.PARCH, 16)
	m.set_buttons([{"text": "OK", "primary": true, "cb": func(): m.close()}])
	return m

# ------------------------------------------------------------------ accès au catalogue (config d'administration)

## `classById` : renvoie une classe factice « ? » si l'identifiant est inconnu.
static func class_by_id(cfg: Dictionary, id: String) -> Dictionary:
	for c in cfg.get("classes", []):
		if c.get("id") == id:
			return c
	return {"id": "", "name": "?", "icon": "❓", "allowedWeaponTypes": [], "allowedSpellIds": []}

static func spell_by_id(cfg: Dictionary, id: String) -> Dictionary:
	for s in cfg.get("spells", []):
		if s.get("id") == id:
			return s
	return {}

## `baseClassOf` : classe de base dont dépend une classe évoluée.
static func base_of(cfg: Dictionary, cls: Dictionary) -> Dictionary:
	var from := str(cls.get("evolvesFrom", ""))
	if from == "":
		return {}
	for c in cfg.get("classes", []):
		if str(c.get("name", "")) == from and AdminUtil.is_base(c):
			return c
	return {}

## `effectiveWeaponTypes`.
static func eff_weapons(cfg: Dictionary, cls: Dictionary) -> Array:
	var out: Array = (cls.get("allowedWeaponTypes", []) as Array).duplicate()
	for w in base_of(cfg, cls).get("allowedWeaponTypes", []):
		if not out.has(w):
			out.append(w)
	return out

# ------------------------------------------------------------------ page « Groupe de départ » (maquette « Groupe »)

## Héros affiché dans la fiche (indice dans `party`).
static var _sel := 0

static func build(host: Control, admin: Node) -> void:
	var cfg: Dictionary = Data.admin_config()
	# réparation à chaque affichage : sorts connus non autorisés par la classe ou appris automatiquement plus tard
	for p in cfg.get("party", []):
		var cls := class_by_id(cfg, str(p.get("classId", "")))
		var allowed: Array = AdminUtil.eff_spells(cls)
		var keep: Array = []
		for sid in p.get("spellsKnown", []):
			if allowed.has(sid) and AdminUtil.locked_level(cls, str(sid)) == 0:
				keep.append(sid)
		p["spellsKnown"] = keep
	var party: Array = cfg.get("party", [])
	var narrow: bool = admin.size.x < 1000.0
	var page := Ax.scroll_page(host, admin, 40, 28, 20)
	# ---- titre + sélecteur Groupe / Objets
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 16)
	top.add_theme_constant_override("v_separation", 12)
	page.add_child(top)
	var head := Ax.head(Atelier.kicker_of("party"), Atelier.title_of("party"), 30 if not narrow else 24)
	top.add_child(head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var sw := AtelierParty.switcher(admin)
	sw.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(sw)
	if party.is_empty():
		page.add_child(Ax.lab(L.t("ui.atelier.p_empty"), 14, Ax.MUTED))
		return
	_sel = clampi(_sel, 0, party.size() - 1)
	# ---- cartes des héros
	var cards := GridContainer.new()
	cards.columns = 2 if narrow else clampi(party.size(), 1, 4)
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	page.add_child(cards)
	for i in party.size():
		var idx := i
		cards.add_child(_hero_card(cfg, party[i], i == _sel, func():
			Ax.flush()
			_sel = idx
			admin.refresh_tab()))
	# ---- fiche du héros choisi
	var c: Dictionary = party[_sel]
	var cur := class_by_id(cfg, str(c.get("classId", "")))
	var sheet := Ax.panel(Ax.CARD, Ax.LINE2, 18, 24, 24)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(sheet)
	var cols := GridContainer.new()
	cols.columns = 1 if narrow else 3
	cols.add_theme_constant_override("h_separation", 28)
	cols.add_theme_constant_override("v_separation", 24)
	sheet.add_child(cols)
	cols.add_child(_identity(admin, cfg, c, cur, narrow))
	cols.add_child(_stats(c, cur))
	cols.add_child(_gear(admin, cfg, c, cur, admin.size.x < 1300.0))

## Pastille d'un héros : portrait recadré ou initiale (Cinzel).
static func _avatar(c: Dictionary, selected: bool, px: float) -> Control:
	var av := Ax.panel(Ax.GOLD if selected else Color("241a0e"), Ax.CLEAR, 14, 0, 0, 0)
	av.custom_minimum_size = Vector2(px, px)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av.clip_contents = true
	var path := str(c.get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		av.add_child(tr)
	else:
		var l := Ax.title(str(c.get("name", "?")).substr(0, 1).to_upper(), 26, Color("2a1a06") if selected else Ax.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		av.add_child(l)
	return av

static func _hero_card(cfg: Dictionary, c: Dictionary, selected: bool, cb: Callable) -> Control:
	var p := Ax.panel(Color(0.91, 0.706, 0.361, 0.1) if selected else Ax.CARD, Ax.GOLD if selected else Ax.LINE, 16, 16, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ax.vbox(6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(_avatar(c, selected, 56.0))
	var n := Ax.title(str(c.get("name", "")), 18)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	v.add_child(n)
	var k := Ax.lab(str(class_by_id(cfg, str(c.get("classId", ""))).get("name", "?")), 12, Ax.MUTED)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	Ax.clickable(p, cb)
	return p

## Colonne 1 : portrait, nom, classe, icône.
static func _identity(admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary, narrow: bool) -> Control:
	var col := Ax.vbox(14)
	col.custom_minimum_size = Vector2(0 if narrow else 260, 0)
	var frame := Ax.panel(Color("2a1d10"), Ax.LINE3, 18, 0, 0)
	frame.custom_minimum_size = Vector2(0, 150)
	frame.clip_contents = true
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(0, 150)
	frame.add_child(inner)
	var path := str(c.get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_child(tr)
	else:
		var ic := GameIcons.rect("user", 96, Color(0.1, 0.07, 0.04, 0.85), 1.4)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		ic.grow_horizontal = Control.GROW_DIRECTION_BOTH
		ic.grow_vertical = Control.GROW_DIRECTION_BEGIN
		inner.add_child(ic)
	var tagbox := Ax.panel(Color(0, 0, 0, 0.55), Ax.CLEAR, 9, 9, 3, 0)
	tagbox.add_child(Ax.lab(L.t("ui.atelier.p_portrait"), 11, Ax.TEXT))
	tagbox.position = Vector2(10, 10)
	inner.add_child(tagbox)
	col.add_child(frame)
	var btns := Ax.hbox(8)
	var choose := Ax.btn(L.t("ui.atelier.p_choose"), func():
		_portrait_picker(admin, c), "gold", 38.0)
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(choose)
	var rm := Ax.icon_btn("close", func():
		c.erase("portrait")
		Ax.changed()
		admin.refresh_tab(), 38.0, Ax.MUTED, "ghost", L.t("ui.atelier.p_remove"))
	rm.disabled = path == ""
	btns.add_child(rm)
	col.add_child(btns)
	col.add_child(Ax.labeled(L.t("common.nom"), Ax.text_field(c, "name", 40.0, 14, "", func(t: String): admin.note(t)), 6))
	var opts: Array = []
	if cur.get("id", "") != "" and not AdminUtil.is_base(cur):
		opts.append([cur.id, L.fa(L.t("admin.chars.evoluee_en_jeu"), [AdminUtil.icon_text_fallback(str(cur.get("icon", ""))), cur.name])])
	for cl in cfg.get("classes", []):
		if AdminUtil.is_base(cl):
			opts.append([cl.id, "%s %s" % [AdminUtil.icon_text_fallback(str(cl.get("icon", ""))), cl.name]])
	col.add_child(Ax.labeled(L.t("admin.chars.classe"), Ax.select(opts, c.get("classId", ""), func(v):
		c["classId"] = v
		var allowed: Array = AdminUtil.eff_spells(class_by_id(cfg, str(v)))
		var keep: Array = []
		for sid in c.get("spellsKnown", []):
			if allowed.has(sid):
				keep.append(sid)
		c["spellsKnown"] = keep
		Ax.changed()
		admin.refresh_tab()), 6))
	var ib := IconPicker.button(admin.modals(), c, "icon", func():
		Ax.changed()
		admin.refresh_tab(), 40.0)
	ib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(Ax.labeled(L.t("common.icone"), ib, 6))
	return col

## Fenêtre « Choisir un portrait » (maquette) : grille de 4, portrait courant cerclé d'or, Annuler / Valider.
static func _portrait_picker(admin: Node, c: Dictionary) -> void:
	var paths: Array = []
	for pc in IconPicker.PORTRAIT_CLASSES:
		var i := 0
		while ResourceLoader.exists("res://assets/portraits/%s_%d.webp" % [pc[1], i]):
			paths.append("res://assets/portraits/%s_%d.webp" % [pc[1], i])
			i += 1
	var m := AxModal.open(admin.modals(), L.t("ui.icon_picker.choisir_un_portrait"), L.fa(L.t("ui.atelier.p_images"), paths.size()), 460.0, 420.0)
	var pick := {"v": str(c.get("portrait", ""))}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.body.add_child(grid)
	var tiles: Dictionary = {}
	var paint := func():
		for k in tiles:
			var on: bool = k == pick.v
			(tiles[k] as Button).add_theme_stylebox_override("normal", Ax.sb(Color("2a1d10"), Ax.GOLD if on else Ax.LINE2, 12, 2 if on else 1, 0, 0))
	for path in paths:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		for k in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, Ax.sb(Color("2a1d10"), Ax.GOLD_L, 12, 1, 0, 0))
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 2
		tr.offset_top = 2
		tr.offset_right = -2
		tr.offset_bottom = -2
		b.add_child(tr)
		var pth: String = path
		b.pressed.connect(func():
			pick.v = pth
			paint.call())
		tiles[path] = b
		grid.add_child(b)
	paint.call()
	m.set_buttons([
		{"text": L.t("common.annuler"), "cb": func(): pass},
		{"text": L.t("ui.atelier.p_validate"), "primary": true, "cb": func():
			if str(pick.v) == "":
				c.erase("portrait")
			else:
				c["portrait"] = pick.v
			Ax.changed()
			admin.refresh_tab()}])

## Colonne 2 : caractéristiques (barre + valeur). Les PV sont calculés, le reste se règle ici.
static func _stats(c: Dictionary, cur: Dictionary) -> Control:
	var col := Ax.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Ax.gold_cap(L.t("ui.atelier.p_stats")))
	var hp := _stat_row(col, L.t("ui.atelier.p_hp"), 0.0, 60.0, Callable())
	(hp.edit as LineEdit).editable = false
	(hp.edit as LineEdit).tooltip_text = L.t("admin.chars.les_pv_et_l_attaque")
	var refresh_hp := func():
		var d := c.duplicate()
		d["level"] = 1
		var b := Stats.char_base(d)
		(hp.edit as LineEdit).text = str(int(b.maxHp))
		hp.set_fill.call(float(b.maxHp))
	var sta := _stat_row(col, L.t("ui.atelier.p_sta"), float(c.get("maxStamina", 100)), 60.0, func(v):
		var n = clampf(float(v), 1.0, 205.0)
		c["maxStamina"] = Ax.num_value(n)
		Ax.changed()
		return c["maxStamina"])
	(sta.edit as LineEdit).tooltip_text = L.t("admin.chars.endurance_maximale")
	for f in [["force", "ui.atelier.p_str"], ["dex", "ui.atelier.p_dex"], ["con", "ui.atelier.p_con"], ["int", "ui.atelier.p_int"]]:
		var key: String = f[0]
		_stat_row(col, L.t(str(f[1])), float(c.get(key, 10)), 20.0, func(v):
			var n = clampf(float(v), 1.0, 100.0)
			c[key] = Ax.num_value(n)
			Ax.changed()
			refresh_hp.call()
			return c[key])
	# vitesse : celle de la classe par défaut (case vide), ou propre à ce personnage ; elle décide de l'ordre d'initiative
	var cls_speed := int(cur.get("baseSpeed", 10))
	var sp := _stat_row(col, L.t("ui.atelier.p_speed"), float(c.get("baseSpeed", cls_speed)), 20.0, Callable())
	var sp_edit: LineEdit = sp.edit
	sp_edit.text = num_text(c.get("baseSpeed", 0), true)
	sp_edit.placeholder_text = str(cls_speed)
	sp_edit.tooltip_text = L.fa(L.t("admin.chars.vitesse_aide"), cls_speed)
	on_commit(sp_edit, func(t: String):
		var n := clampf(float(parse_num(t)), 0.0, 40.0)
		if n < 1.0:
			c.erase("baseSpeed")
			sp_edit.text = ""
			sp.set_fill.call(float(cls_speed))
		else:
			c["baseSpeed"] = int(roundf(n))
			sp_edit.text = str(c["baseSpeed"])
			sp.set_fill.call(n)
		Ax.changed())
	refresh_hp.call()
	return col

## Ligne « libellé · barre · valeur » : renvoie {edit, set_fill}. `on_change(valeur)` renvoie la valeur normalisée réécrite dans le champ.
static func _stat_row(parent: Control, label: String, value: float, max_v: float, on_change: Callable) -> Dictionary:
	var h := Ax.hbox(12)
	var l := Ax.lab(label, 13, Ax.CREAM)
	l.custom_minimum_size.x = 110
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.clip_text = true
	h.add_child(l)
	var track := Ax.panel(Ax.TRACK, Ax.CLEAR, 4, 0, 0, 0)
	track.custom_minimum_size = Vector2(40, 8)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := Ax.panel(Color("d9a444"), Ax.CLEAR, 4, 0, 0, 0)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(value / max_v, 0.0, 1.0)
	fill.offset_right = 0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(fill)
	track.add_child(holder)
	h.add_child(track)
	var box := Ax.panel(Ax.FIELD, Ax.LINE2, 8, 0, 0)
	box.custom_minimum_size = Vector2(56, 32)
	var e := LineEdit.new()
	e.text = num_text(value)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_override("font", Ax.inter(600))
	e.add_theme_font_size_override("font_size", 14)
	e.add_theme_color_override("font_color", Ax.CREAM)
	e.add_theme_color_override("caret_color", Ax.GOLD)
	for k in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(k, Ax.sb(Ax.CLEAR, Ax.CLEAR, 4, 0, 2, 0))
	box.add_child(e)
	h.add_child(box)
	parent.add_child(h)
	var set_fill := func(v: float):
		fill.anchor_right = clampf(v / max_v, 0.0, 1.0)
	if on_change.is_valid():
		on_commit(e, func(t: String):
			var norm = on_change.call(parse_num(t))
			if norm != null:
				e.text = num_text(norm)
				set_fill.call(float(norm)))
	return {"edit": e, "set_fill": set_fill}

## Colonne 3 : équipement de départ (une carte par emplacement) et sorts connus (pastilles).
static func _gear(admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary, one_col: bool) -> Control:
	var col := Ax.vbox(14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Ax.gold_cap(L.t("ui.atelier.p_equip")))
	var grid := Ax.grid2(col, 8)
	grid.columns = 1 if one_col else 2
	var se := Form.sub(c, "startEquipment")
	var weapons := eff_weapons(cfg, cur)
	for slot in Data.constants.get("SLOT_TYPES", []):
		var sid: String = slot.id
		var options: Array = [["", L.fa(L.t("admin.chars.aucun"), slot.get("icon", ""))]]
		for it in cfg.get("itemLibrary", []):
			var ok := false
			if sid == "weapon":
				ok = it.get("type") == "weapon" and weapons.has(it.get("weaponType"))
			elif sid == "accessory":
				ok = it.get("type") == "jewelry"
			else:
				ok = it.get("type") == "armor" and it.get("slot") == sid
			if ok:
				options.append([it.id, AdminUtil.item_label(it)])
		var cell := Ax.panel(Ax.FIELD, Ax.LINE, 10, 12, 10)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Ax.vbox(4)
		cell.add_child(v)
		v.add_child(Ax.cap(L.c(str(slot.get("label", sid)))))
		v.add_child(Ax.select(options, se.get(sid, ""), func(x):
			se[sid] = x
			Ax.changed(), 32.0, 13))
		grid.add_child(cell)
	var sp := Ax.margin(Ax.gold_cap(L.t("ui.atelier.p_spells")), 0, 6, 0, 0)
	col.add_child(sp)
	_spell_chips(col, admin, cfg, c, cur)
	return col

## Sorts connus : une pastille par sort connu (× pour le retirer), les sorts appris automatiquement sont verrouillés (🔒 niv. n),
## et « + Ajouter » propose les sorts de la classe qui restent.
static func _spell_chips(col: Control, admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary) -> void:
	var eff: Array = AdminUtil.eff_spells(cur)
	if eff.is_empty():
		col.add_child(Ax.lab(L.t("ui.atelier.p_spells_none"), 13, Ax.MUTED))
		return
	var max_sp := int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(f)
	var known: Array = c.get("spellsKnown", [])
	var free: Array = []
	for sid in eff:
		var s := spell_by_id(cfg, str(sid))
		if s.is_empty():
			continue
		var label := "%s %s" % [AdminUtil.icon_text_fallback(str(s.get("icon", ""))), s.get("name", "?")]
		var lock := AdminUtil.locked_level(cur, str(sid))
		var spell_id := str(sid)
		if lock > 0:
			var ch := Ax.chip("🔒 " + L.fa(L.t("admin.chars.label_niv"), [L.c(label), lock]), Ax.MUTED, Color("241a0e"), Ax.LINE2, 13, 14, 12, 6)
			ch.tooltip_text = L.fa(T(L.t("admin.chars.apprend_automatiquement_au_niveau")), lock)
			f.add_child(ch)
		elif known.has(sid):
			var ch := Ax.chip(label + "  ×", Ax.TEXT, Color("241a0e"), Ax.LINE2, 13, 14, 12, 6)
			Ax.clickable(ch, func():
				var list: Array = c.get("spellsKnown", [])
				list.erase(spell_id)
				c["spellsKnown"] = list
				Ax.changed()
				admin.refresh_tab())
			f.add_child(ch)
		else:
			free.append([spell_id, label])
	var add := AxDashed.new()
	add.add_child(Ax.margin(Ax.lab("+ " + L.t("ui.atelier.p_add"), 13, Ax.GOLD), 12, 6, 12, 6))
	Ax.clickable(add, func():
		if known.size() >= max_sp:
			alert(admin, L.fa(T(L.t("admin.chars.competences_maximum_par_personnage")), [c.get("name", ""), max_sp]))
			return
		var pm := PopupMenu.new()
		for i in free.size():
			pm.add_item(str(free[i][1]), i)
		if free.is_empty():
			pm.add_item(L.t("ui.atelier.p_spells_none"), 0)
			pm.set_item_disabled(0, true)
		pm.id_pressed.connect(func(i: int):
			if i < free.size():
				var list: Array = c.get("spellsKnown", [])
				list.append(free[i][0])
				c["spellsKnown"] = list
				Ax.changed()
				admin.refresh_tab())
		admin.add_child(pm)
		pm.popup(Rect2i(Vector2i(add.get_screen_position()) + Vector2i(0, int(add.size.y)), Vector2i(0, 0)))
		pm.popup_hide.connect(func(): pm.queue_free()))
	f.add_child(add)
