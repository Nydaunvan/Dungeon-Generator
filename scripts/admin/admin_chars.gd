class_name AdminChars
extends RefCounted
## Onglet « Personnages » : tableau « data-table » du groupe de départ (portrait, icône, nom, classe, stats, équipement,
## sorts connus, aperçu). Contient aussi les petits constructeurs de contrôles compacts de l'original (champs, listes,
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

static func field_box(focus: bool = false, pad_h: float = 5.0, pad_v: float = 5.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("150f08")
	s.border_color = GOLD_DIM if focus else BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = cpx(pad_h)
	s.content_margin_right = cpx(pad_h)
	s.content_margin_top = cpx(pad_v)
	s.content_margin_bottom = cpx(pad_v)
	return s

## Champ texte compact (`input[type=text]`) : largeur et police en rem de l'original.
static func line_edit(text: String, width_css: float, rem: float, pad_h: float = 5.0, pad_v: float = 5.0, placeholder: String = "") -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.add_theme_constant_override("minimum_character_width", 1)
	if width_css > 0.0:
		e.custom_minimum_size.x = cpx(width_css)
	e.add_theme_font_size_override("font_size", fpx(rem))
	e.add_theme_stylebox_override("normal", field_box(false, pad_h, pad_v))
	e.add_theme_stylebox_override("focus", field_box(true, pad_h, pad_v))
	e.add_theme_stylebox_override("read_only", field_box(false, pad_h, pad_v))
	e.add_theme_color_override("font_color", PARCH2)
	e.add_theme_color_override("font_placeholder_color", Color(0.72, 0.66, 0.5, 0.45))
	return e

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

## Champ nombre (`input[type=number]`) : `on_change(valeur)` renvoie la valeur normalisée (bornée) réécrite dans le champ.
static func num_edit(value: Variant, width_css: float, rem: float, on_change: Callable, pad_h: float = 5.0, pad_v: float = 5.0, blank_zero: bool = false, tip: String = "") -> LineEdit:
	var e := line_edit(num_text(value, blank_zero), width_css, rem, pad_h, pad_v)
	e.tooltip_text = tip
	on_commit(e, func(t: String):
		var norm = on_change.call(parse_num(t))
		if norm != null:
			e.text = num_text(norm, blank_zero))
	return e

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

static func _check_tex(on: bool, disabled: bool, px: int) -> Texture2D:
	var key := "%s|%s|%d" % [on, disabled, px]
	if not _chk_cache.has(key):
		var img: Image = UiTheme._check_icon(on, disabled).get_image()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_chk_cache[key] = ImageTexture.create_from_image(img)
	return _chk_cache[key]

## Case à cocher compacte : libellé en rem de l'original ; `wrap` = retour à la ligne dans la largeur donnée (`label`).
static func chk(text: String, rem: float, checked: bool, on_toggle: Callable, wrap_w_css: float = 0.0, disabled: bool = false) -> CheckBox:
	var c := CheckBox.new()
	c.focus_mode = Control.FOCUS_NONE
	c.text = text
	c.disabled = disabled
	c.button_pressed = checked
	var px := int(cpx(15.0))
	c.add_theme_icon_override("checked", _check_tex(true, false, px))
	c.add_theme_icon_override("unchecked", _check_tex(false, false, px))
	c.add_theme_icon_override("checked_disabled", _check_tex(true, true, px))
	c.add_theme_icon_override("unchecked_disabled", _check_tex(false, true, px))
	c.add_theme_font_size_override("font_size", fpx(rem))
	c.add_theme_constant_override("h_separation", int(cpx(5.0)))
	if wrap_w_css > 0.0:
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size.x = cpx(wrap_w_css)
		c.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if on_toggle.is_valid():
		c.toggled.connect(on_toggle)
	return c

## Bouton « .icon-pick-btn » : carré, fond #1c1610, liseré, survol doré.
static func pick_box(hover: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("1c1610")
	s.border_color = GOLD_DIM if hover else BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(0)
	return s

static func style_pick_btn(b: Button, size_css: float) -> void:
	b.custom_minimum_size = Vector2(cpx(size_css), cpx(size_css))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("normal", pick_box(false))
	b.add_theme_stylebox_override("hover", pick_box(true))
	b.add_theme_stylebox_override("pressed", pick_box(true))
	b.add_theme_stylebox_override("focus", pick_box(true))
	b.add_theme_color_override("font_color", PDIM)

## Bouton-icône 38×38 (sélecteur d'icônes du jeu) : l'icône occupe 1,3 rem comme `.icon-pick-btn`. `changed` recharge l'onglet.
static func icon_btn(admin: Node, target: Dictionary, key: String, changed: Callable) -> Button:
	var b := IconPicker.button(admin.modals(), target, key, changed, 26.0)
	b.tooltip_text = ""
	style_pick_btn(b, 38.0)
	b.add_theme_font_size_override("font_size", fpx(1.3))
	b.add_theme_constant_override("icon_max_width", int(cpx(24.0)))
	return b

## Petit bouton (🗑, +, ×…) : police en rem, marges en px de l'original.
static func small_btn(text: String, rem: float, pad_h: float, pad_v: float, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fpx(rem))
	b.add_theme_stylebox_override("normal", plate_box(false, pad_h, pad_v))
	b.add_theme_stylebox_override("hover", plate_box(true, pad_h, pad_v))
	b.add_theme_stylebox_override("pressed", plate_box(true, pad_h, pad_v))
	b.add_theme_stylebox_override("focus", plate_box(true, pad_h, pad_v))
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	return b

## Bouton d'action `.admin-actions` : `primary` = liseré/texte dorés comme `button.primary`.
static func action_btn(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_color_override("font_color", GOLD_BRIGHT)
	b.pressed.connect(cb)
	return b

## Ligne « .admin-actions » (marge haute 14, espacement 8).
static func actions_row(parent: Control, buttons: Array) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(cpx(10.0)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(cpx(8.0)))
	for b in buttons:
		h.add_child(b)
	m.add_child(h)
	parent.add_child(m)

## `.save-status` : 0,7 rem, #7a6a52.
static func status_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fpx(0.7))
	l.add_theme_color_override("font_color", STATUS_COL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, cpx(13.0))
	return l

## `.csection-label` : 0,62 rem, doré atténué, capitales espacées (.08em), marge basse 5.
static func csection_label(text: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", int(cpx(5.0)))
	var l := Label.new()
	l.text = L.u(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120.0
	var fv := FontVariation.new()
	fv.base_font = UiTheme.font(UiTheme.F_BODY)
	fv.spacing_glyph = int(roundf(cpx(0.08 * 0.62 * 18.0)))
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", fpx(0.62))
	l.add_theme_color_override("font_color", GOLD_DIM)
	m.add_child(l)
	return m

## Texte « .hint » sans marge (0,74 rem, italique, atténué).
static func dim_hint(text: String, rem: float = 0.74) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", fpx(rem))
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	l.add_theme_color_override("font_color", PDIM)
	return l

static func flow(parent: Control, h_css: float, v_css: float) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(cpx(h_css)))
	f.add_theme_constant_override("v_separation", int(cpx(v_css)))
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null:
		parent.add_child(f)
	return f

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

# ------------------------------------------------------------------ onglet

static func build(host: VBoxContainer, admin: Node) -> void:
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
	var panel := Form.panel(host, L.t("admin.chars.groupe_aventuriers"))
	Form.hint(panel, L.t("admin.chars.les_pv_et_l_attaque"))
	Form.hint(panel, L.t("admin.chars.ce_tableau_definit_la_configuration"))
	var status := status_label()
	var grid := AdminTable.create(panel, ["Portrait", L.t("common.icone"), L.t("common.nom"), L.t("admin.chars.classe"), L.t("common.for"), "Dex", "Con", "Int", L.t("admin.chars.end_max"), L.t("admin.chars.equipement_depart"), L.t("admin.chars.sorts_connus"), L.t("common.apercu")],
		[46, 38, 100, 100, 42, 42, 42, 42, 44, 128, 290, 70])
	var party: Array = cfg.get("party", [])
	for idx in party.size():
		_row(grid, admin, cfg, party[idx], status)
	actions_row(panel, [action_btn(L.t("common.enregistrer_la_configuration"), func(): admin.confirm_save(status), true)])
	panel.add_child(status)

static func _row(grid: GridContainer, admin: Node, cfg: Dictionary, c: Dictionary, status: Label) -> void:
	var cur := class_by_id(cfg, str(c.get("classId", "")))
	# portrait : image seulement si le personnage en a un, sinon « — »
	var pb := Button.new()
	pb.focus_mode = Control.FOCUS_NONE
	pb.tooltip_text = "Portrait"
	style_pick_btn(pb, 46.0)
	pb.clip_contents = true
	_set_portrait(pb, c)
	pb.pressed.connect(func():
		IconPicker.open_portrait(admin.modals(), str(c.get("portrait", "")), func(v: String):
			if v == "":
				c.erase("portrait")
			else:
				c["portrait"] = v
			_set_portrait(pb, c)))
	AdminTable.cell(grid, pb)
	AdminTable.cell(grid, icon_btn(admin, c, "icon", admin.refresh_tab))
	# nom
	var name_edit := line_edit(str(c.get("name", "")), 90.0, 0.74)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String): c["name"] = t)
	AdminTable.cell(grid, name_edit)
	# classe : classes de base (la classe évoluée actuelle reste listée en tête)
	var opts: Array = []
	if cur.get("id", "") != "" and not AdminUtil.is_base(cur):
		opts.append([cur.id, L.fa(L.t("admin.chars.evoluee_en_jeu"), [AdminUtil.icon_text_fallback(str(cur.get("icon", ""))), cur.name])])
	for cl in cfg.get("classes", []):
		if AdminUtil.is_base(cl):
			opts.append([cl.id, "%s %s" % [AdminUtil.icon_text_fallback(str(cl.get("icon", ""))), cl.name]])
	var on_class := func(v):
		c["classId"] = v
		var allowed: Array = AdminUtil.eff_spells(class_by_id(cfg, str(v)))
		var keep: Array = []
		for sid in c.get("spellsKnown", []):
			if allowed.has(sid):
				keep.append(sid)
		c["spellsKnown"] = keep
		admin.refresh_tab()
	AdminTable.cell(grid, select(opts, c.get("classId", ""), on_class, 90.0, 0.74, 5.0, 5.0, true))
	# caractéristiques + aperçu
	var preview := Label.new()
	preview.add_theme_font_size_override("font_size", fpx(0.62))
	preview.add_theme_color_override("font_color", PDIM)
	var upd := func():
		var d := c.duplicate()
		d["level"] = 1
		var b := Stats.char_base(d)
		preview.text = "PV%d·%d-%d" % [int(b.maxHp), int(b.baseAtkMin), int(b.baseAtkMax)]
	for f in ["force", "dex", "con", "int"]:
		var key: String = f
		var on_stat := func(v):
			var n = clampf(float(v), 1.0, 100.0)
			c[key] = int(n) if is_equal_approx(n, roundf(n)) else n
			upd.call()
			return c[key]
		AdminTable.cell(grid, num_edit(c.get(key, 10), 42.0, 0.74, on_stat))
	var on_sta := func(v):
		var n = clampf(float(v), 1.0, 205.0)
		c["maxStamina"] = int(n) if is_equal_approx(n, roundf(n)) else n
		return c["maxStamina"]
	AdminTable.cell(grid, num_edit(c.get("maxStamina", 100), 44.0, 0.74, on_sta, 5.0, 5.0, false, L.t("admin.chars.endurance_maximale")))
	upd.call()
	# équipement de départ : un select par emplacement, sans libellé
	var eqbox := VBoxContainer.new()
	eqbox.add_theme_constant_override("separation", int(cpx(2.0)))
	eqbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		var on_eq := func(v): se[sid] = v
		eqbox.add_child(select(options, se.get(sid, ""), on_eq, 64.0, 0.58, 1.0, 1.0, true))
	AdminTable.cell(grid, eqbox)
	# sorts connus
	AdminTable.cell(grid, _spells_cell(cfg, c, cur, status))
	AdminTable.cell(grid, preview)

static func _set_portrait(b: Button, c: Dictionary) -> void:
	var path := str(c.get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		b.icon = load(path)
		b.text = ""
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", int(cpx(44.0)))
	else:
		b.icon = null
		b.text = "—"

## Cases « sorts connus » : grille à 2 colonnes (max 290 px), police 0,66 rem ; les sorts appris automatiquement sont verrouillés.
static func _spells_cell(cfg: Dictionary, c: Dictionary, cur: Dictionary, status: Label) -> Control:
	var eff: Array = AdminUtil.eff_spells(cur)
	if eff.is_empty():
		var h := dim_hint("—")
		h.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		return h
	var max_sp := int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(cpx(12.0)))
	g.add_theme_constant_override("v_separation", int(cpx(3.0)))
	g.custom_minimum_size.x = cpx(290.0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var col_w := (290.0 - 12.0) / 2.0
	for sid in eff:
		var s := spell_by_id(cfg, str(sid))
		if s.is_empty():
			continue
		var label := "%s %s" % [AdminUtil.icon_text_fallback(str(s.get("icon", ""))), s.get("name", "?")]
		var lock := AdminUtil.locked_level(cur, str(sid))
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", int(cpx(5.0)))
		cell.custom_minimum_size.x = cpx(col_w)
		cell.size_flags_horizontal = Control.SIZE_FILL
		if lock > 0:
			var tip := L.fa(T(L.t("admin.chars.apprend_automatiquement_au_niveau")), lock)
			cell.modulate.a = 0.5
			var lk := Label.new()
			lk.text = "🔒"
			lk.add_theme_font_size_override("font_size", fpx(0.66))
			lk.tooltip_text = tip
			lk.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.add_child(lk)
			var cb := chk(L.fa(L.t("admin.chars.label_niv"), [L.c(label), lock]), 0.66, false, Callable(), col_w - 24.0, true)
			cb.tooltip_text = tip
			cb.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.add_child(cb)
		else:
			var spell_id: String = str(sid)
			var cb := chk(label, 0.66, (c.get("spellsKnown", []) as Array).has(sid), Callable(), col_w, false)
			cb.toggled.connect(func(on: bool):
				var known: Array = c.get("spellsKnown", [])
				if on:
					if known.size() >= max_sp:
						cb.set_pressed_no_signal(false)
						status.text = L.fa(T(L.t("admin.chars.competences_maximum_par_personnage")), [c.get("name", ""), max_sp])
						return
					if not known.has(spell_id):
						known.append(spell_id)
				else:
					known.erase(spell_id)
				c["spellsKnown"] = known)
			cell.add_child(cb)
		g.add_child(cell)
	return g
