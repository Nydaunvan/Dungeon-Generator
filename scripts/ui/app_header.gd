class_name AppHeader
extends PanelContainer
## Bande du haut Atlas Noir : emblème de boussole, nom du jeu, puis les commandes (Accueil, Guide, Paramètres, Sauvegarde,
## Compte, Admin, langue, Quitter) en capitales fines ; la commande survolée se souligne en ambre.
## Sur mobile (portrait), chaque commande se réduit à son symbole.

signal nav(name: String)

var title_label: Label
var nav_row: HBoxContainer
var btn_admin: Button
var btn_account: Button
var btn_home: Button
var save_menu: SaveMenu    # « Sauvegarde ▾ » (seulement en jeu : ajouté par GameLayout)
var _lang: MenuButton
var _home_mode: bool = false
var _box: AtlasBox
var _emblem: Emblem

## Emblème : boussole à quatre pointes dans un cercle fin.
class Emblem extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0.0, TAU, 40, Atlas.COPPER, 1.2, true)
		draw_arc(c, r * 0.72, 0.0, TAU, 32, Atlas.COPPER_DIM, 1.0, true)
		for i in 4:
			var a := float(i) * PI * 0.5 - PI * 0.5
			var d := Vector2(cos(a), sin(a))
			var n := Vector2(-d.y, d.x)
			var tip := c + d * r * (1.0 if i == 0 else 0.86)
			draw_colored_polygon(PackedVector2Array([tip, c + n * r * 0.13, c - n * r * 0.13]), Atlas.AMBER if i == 0 else Atlas.IVORY)

## Centre de la bande : « NIVEAU 1 / LES CAVES SUPÉRIEURES » entre deux filets terminés par un losange (vide sur l'accueil).
class Crest extends Control:
	var num_text := ""
	var name_text := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 28)
	func _draw() -> void:
		if num_text == "" and name_text == "":
			return
		var f := Atlas.title_font(false, 3)
		var fs := int(UiMetrics.css(13.0))
		var a := num_text.to_upper()
		var b := name_text.to_upper()
		var wa := f.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var wb := f.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sep := 26.0
		var total := wa + wb + sep
		if total > size.x - 70.0:
			b = ""
			wb = 0.0
			total = wa
			sep = 0.0
		var x0 := (size.x - total) * 0.5
		var y := size.y * 0.5
		draw_string(f, Vector2(x0, y + fs * 0.36), a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.IVORY)
		if b != "":
			draw_string(f, Vector2(x0 + wa + sep, y + fs * 0.36), b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.IVORY_DIM)
			draw_line(Vector2(x0 + wa + sep * 0.5, y - fs * 0.6), Vector2(x0 + wa + sep * 0.5 - 4.0, y + fs * 0.6), Atlas.COPPER, 1.0, true)
		# filets de part et d'autre
		var gap := 16.0
		var lx1 := x0 - gap
		var rx0 := x0 + total + gap
		var yl := y + fs * 0.1
		Atlas.draw_taper(self, Vector2(4.0, yl), Vector2(lx1, yl), 0.4, 2.0, Color(Atlas.COPPER, 0.9))
		Atlas.draw_taper(self, Vector2(size.x - 4.0, yl), Vector2(rx0, yl), 0.4, 2.0, Color(Atlas.COPPER, 0.9))
		Atlas.draw_diamond(self, Vector2(lx1 + 7.0, yl), 5.0, Atlas.COPPER)
		Atlas.draw_diamond(self, Vector2(lx1 + 7.0, yl), 2.5, Atlas.AMBER)
		Atlas.draw_diamond(self, Vector2(rx0 - 7.0, yl), 4.0, Atlas.COPPER)
		Atlas.draw_diamond(self, Vector2(rx0 - 4.0, y), 3.0, Atlas.AMBER)

var _crest: Crest

func set_level(num_text: String, name_text: String) -> void:
	_crest.num_text = num_text
	_crest.name_text = name_text
	_crest.visible = not UiMetrics.portrait and num_text != ""
	_crest.queue_redraw()

func _init() -> void:
	clip_contents = false
	_box = AtlasBox.new(0.0)
	_box.fill_top = Color(0, 0, 0, 0)     # bande sans fond : le noir de l'écran, des filets et rien d'autre
	_box.fill_bottom = Color(0, 0, 0, 0)
	_box.border = Color(0, 0, 0, 0)
	_box.cut = 0.0
	add_theme_stylebox_override("panel", _box)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	add_child(hrow)
	_emblem = Emblem.new()
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(_emblem)
	title_label = Label.new()
	title_label.text = L.t("common.editeur_de_donjon")
	title_label.clip_text = false
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", Atlas.title_font(true, 3))
	title_label.add_theme_color_override("font_color", Atlas.IVORY)
	hrow.add_child(title_label)
	_crest = Crest.new()
	hrow.add_child(_crest)
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 0)
	nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(nav_row)
	btn_home = _button(L.t("ui.app_header.accueil"))
	btn_home.pressed.connect(func(): nav.emit("Accueil"))
	nav_row.add_child(btn_home)
	var guide := _button("📖 Guide")
	guide.pressed.connect(func(): nav.emit("Guide"))
	nav_row.add_child(guide)
	var cfg := _button("⚙ " + L.t("ui.app_header.parametres"))
	cfg.tooltip_text = L.t("ui.app_header.parametres_tip")
	cfg.pressed.connect(func(): nav.emit("Paramètres"))
	nav_row.add_child(cfg)
	btn_account = _button(_account_text())
	btn_account.tooltip_text = L.t("ui.cloud.header_tip")
	btn_account.pressed.connect(func(): nav.emit("Compte"))
	nav_row.add_child(btn_account)
	NotifDot.attach(btn_account, SuperAdmin.pending, false, SuperAdmin.refresh_pending)    # super admin : signalements à traiter
	Cloud.session_changed.connect(_refresh_account)
	btn_admin = _button("🛠 Admin")
	btn_admin.pressed.connect(func(): nav.emit("Admin"))
	btn_admin.visible = false
	nav_row.add_child(btn_admin)
	_lang = MenuButton.new()
	_style(_lang, _lang_text())
	var pm := _lang.get_popup()
	pm.add_item("🇫🇷 FR", 0)
	pm.add_item("🇬🇧 EN", 1)
	pm.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.82)))
	pm.id_pressed.connect(func(i: int):
		Data.set_lang("en" if i == 1 else "fr")
		_lang.text = _plain(_lang_text())
		nav.emit("Lang"))
	nav_row.add_child(_lang)
	var quit := _button("🚪 " + L.t("ui.app_header.quitter"))
	quit.tooltip_text = L.t("ui.app_header.quitter_tip")
	quit.pressed.connect(func(): nav.emit("Quitter"))
	nav_row.add_child(quit)
	UiMetrics.register(self)
	rescale()

func _account_text() -> String:
	return "👤 " + (Cloud.pseudo() if Cloud.is_signed_in() and Cloud.pseudo() != "" else L.t("ui.cloud.header"))

func _refresh_account() -> void:
	if btn_account == null or not is_instance_valid(btn_account):
		return
	btn_account.set_meta("full", _account_text())
	_style(btn_account, _short(_account_text()) if UiMetrics.portrait else _plain(_account_text()))

func _lang_text() -> String:
	return "%s ▾" % ("🇬🇧 EN" if Data.lang == "en" else "🇫🇷 FR")

## Menu « Sauvegarde ▾ » de la partie en cours, entre « Paramètres » et « Compte » (l'accueil n'en a pas : pas de partie à sauvegarder).
func add_save_menu(m: SaveMenu) -> void:
	save_menu = m
	nav_row.add_child(m)
	nav_row.move_child(m, btn_account.get_index())
	rescale()

## Sur l'accueil, « Accueil » est la page courante (inactif).
func set_home_mode(on: bool) -> void:
	_home_mode = on
	btn_home.disabled = on

## Sur mobile (portrait) la rangée de boutons ne garde que l'icône : le texte complet passe dans l'infobulle.
func _short(full: String) -> String:
	var parts := full.split(" ", false, 1)
	if parts.size() < 2:
		return full
	var first := parts[0]
	if first.unicode_at(0) > 0x2000:       # commence par un symbole / un emoji : on le garde seul
		return first
	return full

## Bureau : le libellé sans son symbole (les commandes s'écrivent en capitales fines, sans emoji).
func _plain(full: String) -> String:
	var parts := full.split(" ", false, 1)
	if parts.size() >= 2 and parts[0].unicode_at(0) > 0x2000:
		return parts[1]
	return full

func rescale() -> void:
	custom_minimum_size.y = UiMetrics.css(64.0 if not UiMetrics.portrait else 44.0)
	title_label.add_theme_font_size_override("font_size", int(UiMetrics.css(21.0 if not UiMetrics.portrait else 13.0)))
	if _crest != null:
		_crest.visible = not UiMetrics.portrait and _crest.num_text != ""
	var side := UiMetrics.css(30.0 if not UiMetrics.portrait else 22.0)
	_box.content_margin_left = UiMetrics.css(30.0 if not UiMetrics.portrait else 12.0)
	_box.content_margin_right = UiMetrics.css(30.0 if not UiMetrics.portrait else 10.0)
	_box.emit_changed()
	if _emblem != null:
		_emblem.custom_minimum_size = Vector2(side * 1.4, side * 1.4)
		_emblem.queue_redraw()
	if nav_row != null:
		for b in nav_row.get_children():
			if b is Button:
				if not b.has_meta("full"):
					b.set_meta("full", (b as Button).text)
					if (b as Button).tooltip_text == "":
						(b as Button).tooltip_text = _plain(str((b as Button).text))
				var full := str(b.get_meta("full"))
				_style(b, _short(full) if UiMetrics.portrait else _plain(full))
			elif b is MenuButton:
				_style(b, _plain((b as MenuButton).text) if not UiMetrics.portrait else _short((b as MenuButton).text))

func _process(_d: float) -> void:
	btn_admin.visible = (Data.admin_unlocked or Data.play_origin == "random") and not _home_mode

func _button(text: String) -> Button:
	var b := Button.new()
	_style(b, text)
	return b

func _style(b: Button, text: String) -> void:
	b.text = text.to_upper() if not UiMetrics.portrait else text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Atlas.title_font(false, 2))
	b.add_theme_font_size_override("font_size", int(UiMetrics.css(11.0 if not UiMetrics.portrait else 15.0)))
	b.add_theme_color_override("font_color", Atlas.IVORY)
	b.add_theme_color_override("font_hover_color", Atlas.AMBER)
	b.add_theme_color_override("font_pressed_color", Atlas.AMBER)
	b.add_theme_color_override("font_disabled_color", Atlas.AMBER)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(0, 0, 0, 0)
		var lit: bool = st != "normal" and st != "focus"
		g.border_color = Atlas.AMBER if lit else Color(0, 0, 0, 0)
		g.border_width_bottom = maxi(1, roundi(UiMetrics.css(2.0)))
		g.content_margin_left = UiMetrics.css(13.0 if not UiMetrics.portrait else 7.0)
		g.content_margin_right = UiMetrics.css(13.0 if not UiMetrics.portrait else 7.0)
		g.content_margin_top = UiMetrics.css(8.0)
		g.content_margin_bottom = UiMetrics.css(6.0)
		b.add_theme_stylebox_override(st, g)
