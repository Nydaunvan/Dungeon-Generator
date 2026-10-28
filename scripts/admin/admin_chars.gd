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
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(cpx(8.0)))
	h.add_theme_constant_override("v_separation", int(cpx(8.0)))
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

# ------------------------------------------------------------------ page « Groupe de départ »

## Héros affiché dans la fiche (indice dans `party`).
static var _sel := 0

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
	var party: Array = cfg.get("party", [])
	if party.is_empty():
		host.add_child(Atelier.muted(L.t("ui.atelier.p_empty"), 14))
		return
	_sel = clampi(_sel, 0, party.size() - 1)
	var narrow: bool = admin.size.x < 1000.0
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	host.add_child(gap)
	# ---- cartes des héros
	var cards := GridContainer.new()
	cards.columns = 2 if narrow else clampi(party.size(), 1, 4)
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	host.add_child(cards)
	for i in party.size():
		var idx := i
		cards.add_child(_hero_card(cfg, party[i], i == _sel, func():
			Form.flush()
			_sel = idx
			admin.refresh_tab()))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 16)
	host.add_child(gap2)
	# ---- fiche du héros choisi
	var sheet := GameScreen.glass(24, 18)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(sheet)
	var cols := GridContainer.new()
	cols.columns = 1 if narrow else 3
	cols.add_theme_constant_override("h_separation", 28)
	cols.add_theme_constant_override("v_separation", 24)
	sheet.add_child(cols)
	var c: Dictionary = party[_sel]
	var cur := class_by_id(cfg, str(c.get("classId", "")))
	var save := func(): admin.save()
	cols.add_child(_identity(admin, cfg, c, cur, save, narrow))
	cols.add_child(_stats(c, cur, save))
	cols.add_child(_gear(admin, cfg, c, cur, save))
	Form.autosave(sheet, save)

## Carte d'un héros dans la rangée du haut : pastille (portrait ou initiale), nom, classe.
static func _hero_card(cfg: Dictionary, c: Dictionary, selected: bool, cb: Callable) -> Control:
	var p := Atelier.card(selected, 16, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(56, 56)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av.clip_contents = true
	av.add_theme_stylebox_override("panel", Atelier.box(Color("e8b45c") if selected else Color("241a0e"), Color(0, 0, 0, 0), 14, 0, 0, 0))
	var path := str(c.get("portrait", ""))
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		av.add_child(tr)
	else:
		var l := Label.new()
		l.text = str(c.get("name", "?")).substr(0, 1).to_upper()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color("2a1a06") if selected else Color("b8a781"))
		av.add_child(l)
	v.add_child(av)
	var n := Label.new()
	n.text = str(c.get("name", ""))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	n.add_theme_font_size_override("font_size", 18)
	n.add_theme_color_override("font_color", Color("f4e6c6"))
	n.clip_text = true
	v.add_child(n)
	var k := Atelier.muted(str(class_by_id(cfg, str(c.get("classId", ""))).get("name", "?")))
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	Atelier.clickable(p, cb)
	return p

static func _field(parent: Control, label: String, ctl: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(Atelier.muted(label))
	v.add_child(ctl)
	parent.add_child(v)

## Colonne 1 : portrait, nom, classe, icône.
static func _identity(admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary, save: Callable, narrow: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(0 if narrow else 260, 0)
	# portrait
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 150)
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", Atelier.box(Color("2a1d10"), Color("5a4526"), 18, 0, 0))
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
		var ic := GameIcons.rect("user", 64, Color("5a4526"), 1.4)
		ic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		inner.add_child(ic)
	var tag := Label.new()
	tag.text = L.t("ui.atelier.p_portrait")
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color("e2d2b0"))
	var tagbox := PanelContainer.new()
	tagbox.add_theme_stylebox_override("panel", Atelier.box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 9, 9, 3, 0))
	tagbox.add_child(tag)
	tagbox.position = Vector2(10, 10)
	inner.add_child(tagbox)
	col.add_child(frame)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	var choose := Atelier.button(L.t("ui.atelier.p_choose"), func():
		IconPicker.open_portrait(admin.modals(), str(c.get("portrait", "")), func(v: String):
			if v == "":
				c.erase("portrait")
			else:
				c["portrait"] = v
			save.call()
			admin.refresh_tab()), true, false, 38.0)
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(choose)
	var rm := Atelier.button("", func():
		c.erase("portrait")
		save.call()
		admin.refresh_tab(), false, false, 38.0)
	rm.icon = GameIcons.tex("close", 32, Color("b8a781"), 2.0)
	rm.add_theme_constant_override("icon_max_width", 16)
	rm.tooltip_text = L.t("ui.atelier.p_remove")
	rm.custom_minimum_size = Vector2(38, 38)
	rm.disabled = path == ""
	btns.add_child(rm)
	col.add_child(btns)
	# nom
	var name_edit := line_edit(str(c.get("name", "")), 0.0, 0.95, 12.0, 9.0)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String): c["name"] = t)
	_field(col, L.t("common.nom"), name_edit)
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
		save.call()
		admin.refresh_tab()
	_field(col, L.t("admin.chars.classe"), select(opts, c.get("classId", ""), on_class, 0.0, 0.95, 12.0, 9.0, true))
	# icône
	var ib := icon_btn(admin, c, "icon", func():
		save.call()
		admin.refresh_tab())
	ib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_field(col, L.t("common.icone"), ib)
	return col

## Colonne 2 : caractéristiques (barre + valeur). Les PV sont calculés, le reste se règle ici.
static func _stats(c: Dictionary, cur: Dictionary, save: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Atelier.section(L.t("ui.atelier.p_stats")))
	var bars: Dictionary = {}
	# PV (calculés à partir de la Constitution)
	var hp_row := _stat_row(L.t("ui.atelier.p_hp"), 0.0, 150.0, bars, "hp")
	var hp_box: LineEdit = hp_row[1]
	hp_box.editable = false
	hp_box.tooltip_text = L.t("admin.chars.les_pv_et_l_attaque")
	col.add_child(hp_row[0])
	var refresh_hp := func():
		var d := c.duplicate()
		d["level"] = 1
		var b := Stats.char_base(d)
		hp_box.text = str(int(b.maxHp))
		(bars["hp"] as ProgressBar).value = minf(float(b.maxHp), (bars["hp"] as ProgressBar).max_value)
	# Endurance
	var on_sta := func(v):
		var n = clampf(float(v), 1.0, 205.0)
		c["maxStamina"] = int(n) if is_equal_approx(n, roundf(n)) else n
		(bars["sta"] as ProgressBar).value = minf(float(c["maxStamina"]), 205.0)
		return c["maxStamina"]
	var sta_row := _stat_row(L.t("ui.atelier.p_sta"), float(c.get("maxStamina", 100)), 205.0, bars, "sta", on_sta)
	sta_row[1].tooltip_text = L.t("admin.chars.endurance_maximale")
	col.add_child(sta_row[0])
	for f in [["force", "ui.atelier.p_str"], ["dex", "ui.atelier.p_dex"], ["con", "ui.atelier.p_con"], ["int", "ui.atelier.p_int"]]:
		var key: String = f[0]
		var on_stat := func(v):
			var n = clampf(float(v), 1.0, 100.0)
			c[key] = int(n) if is_equal_approx(n, roundf(n)) else n
			(bars[key] as ProgressBar).value = minf(float(c[key]), 20.0)
			refresh_hp.call()
			return c[key]
		col.add_child(_stat_row(L.t(str(f[1])), float(c.get(key, 10)), 20.0, bars, key, on_stat)[0])
	# vitesse : celle de la classe par défaut (case vide), ou propre à ce personnage ; elle décide de l'ordre d'initiative
	var cls_speed := int(cur.get("baseSpeed", 10))
	var on_speed := func(v):
		var n = clampf(float(v), 0.0, 40.0)
		if n < 1.0:
			c.erase("baseSpeed")
			(bars["speed"] as ProgressBar).value = minf(float(cls_speed), 20.0)
			return null
		c["baseSpeed"] = int(roundf(n))
		(bars["speed"] as ProgressBar).value = minf(float(c["baseSpeed"]), 20.0)
		return c["baseSpeed"]
	var sp_row := _stat_row(L.t("ui.atelier.p_speed"), float(c.get("baseSpeed", cls_speed)), 20.0, bars, "speed", on_speed)
	var sp_edit: LineEdit = sp_row[1]
	sp_edit.text = num_text(c.get("baseSpeed", 0), true)
	sp_edit.placeholder_text = str(cls_speed)
	sp_edit.tooltip_text = L.fa(L.t("admin.chars.vitesse_aide"), cls_speed)
	col.add_child(sp_row[0])
	refresh_hp.call()
	return col

## Ligne « libellé · barre · valeur » : renvoie [ligne, champ].
static func _stat_row(label: String, value: float, max_v: float, bars: Dictionary, key: String, on_change: Callable = Callable()) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color("f4e6c6"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var b := Atelier.bar(value, max_v)
	bars[key] = b
	h.add_child(b)
	var e: LineEdit
	if on_change.is_valid():
		e = num_edit(value, 56.0, 0.9, on_change, 4.0, 6.0)
	else:
		e = line_edit(num_text(value), 56.0, 0.9, 4.0, 6.0)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size.x = 56
	h.add_child(e)
	return [h, e]

## Colonne 3 : équipement de départ (une carte par emplacement) et sorts connus (pastilles).
static func _gear(admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary, save: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Atelier.section(L.t("ui.atelier.p_equip")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
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
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", Atelier.box(Color("14100a"), Color("3a2c18"), 10, 10, 8))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		cell.add_child(v)
		var cap := Label.new()
		cap.text = L.c(str(slot.get("label", sid))).to_upper()
		cap.add_theme_font_size_override("font_size", 11)
		cap.add_theme_color_override("font_color", Color("9a8863"))
		v.add_child(cap)
		var on_eq := func(x): se[sid] = x
		v.add_child(select(options, se.get(sid, ""), on_eq, 0.0, 0.8, 4.0, 4.0, true))
		grid.add_child(cell)
	col.add_child(Atelier.section(L.t("ui.atelier.p_spells")))
	col.add_child(_spell_chips(admin, cfg, c, cur, save))
	return col

## Sorts connus : une pastille par sort de la classe ; les sorts appris automatiquement sont verrouillés (🔒 niv. n).
static func _spell_chips(admin: Node, cfg: Dictionary, c: Dictionary, cur: Dictionary, save: Callable) -> Control:
	var eff: Array = AdminUtil.eff_spells(cur)
	if eff.is_empty():
		return Atelier.muted(L.t("ui.atelier.p_spells_none"), 13)
	var max_sp := int(Data.constants.get("MAX_SPELLS_PER_CHARACTER", 6))
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sid in eff:
		var s := spell_by_id(cfg, str(sid))
		if s.is_empty():
			continue
		var label := "%s %s" % [AdminUtil.icon_text_fallback(str(s.get("icon", ""))), s.get("name", "?")]
		var lock := AdminUtil.locked_level(cur, str(sid))
		var spell_id := str(sid)
		var known: bool = (c.get("spellsKnown", []) as Array).has(sid)
		var b: Button
		if lock > 0:
			b = Atelier.pill("🔒 " + L.fa(L.t("admin.chars.label_niv"), [L.c(label), lock]), false, Callable(), Color("e8b45c"), 32, 12)
			b.modulate.a = 0.55
			b.tooltip_text = L.fa(T(L.t("admin.chars.apprend_automatiquement_au_niveau")), lock)
		else:
			b = Atelier.pill(label, known, Callable(), Color("e8b45c"), 32, 12)
			b.pressed.connect(func():
				var list: Array = c.get("spellsKnown", [])
				if list.has(spell_id):
					list.erase(spell_id)
				elif list.size() >= max_sp:
					admin.say(L.fa(T(L.t("admin.chars.competences_maximum_par_personnage")), [c.get("name", ""), max_sp]))
					return
				else:
					list.append(spell_id)
				c["spellsKnown"] = list
				save.call()
				admin.refresh_tab())
		f.add_child(b)
	return f
