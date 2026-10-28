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
var _subtitle: Label
var _tbox: VBoxContainer
var _menu: MenuButton
var _icons := {}

## Emblème : boussole à quatre pointes dans un cercle fin.
class Emblem extends Control:
	static var _tex: Texture2D
	func _draw() -> void:
		if _tex == null:
			_tex = load("res://assets/ui/compass.png")
		var d := minf(size.x, size.y)
		draw_texture_rect(_tex, Rect2((size - Vector2(d, d)) * 0.5, Vector2(d, d)), false)

## Centre de la bande : « NIVEAU 1 / LES CAVES SUPÉRIEURES » entre deux filets terminés par un losange (vide sur l'accueil).
class Crest extends Control:
	var num_text := ""
	var name_text := ""
	var left_ctl: Control       # bloc du titre (à gauche) et rangée des icônes (à droite) : bornes des filets
	var right_ctl: Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		var y := size.y * 0.64        # le repère est descendu dans le décroché
		draw_string(f, Vector2(x0, y + fs * 0.36), a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.IVORY)
		if b != "":
			draw_string(f, Vector2(x0 + wa + sep, y + fs * 0.36), b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Atlas.IVORY_DIM)
			draw_line(Vector2(x0 + wa + sep * 0.5, y - fs * 0.6), Vector2(x0 + wa + sep * 0.5 - 4.0, y + fs * 0.6), Atlas.COPPER, 1.0, true)
		# filets de part et d'autre
		var gap := 16.0
		var lx1 := x0 - gap
		var rx0 := x0 + total + gap
		var yl := y + fs * 0.1
		var lim_l := (left_ctl.position.x + left_ctl.size.x + 26.0) if left_ctl != null else 4.0
		var lim_r := (right_ctl.position.x - 26.0) if right_ctl != null else size.x - 4.0
		Atlas.draw_taper(self, Vector2(minf(lim_l, lx1 - 20.0), yl), Vector2(lx1, yl), 0.4, 2.0, Color(Atlas.COPPER, 0.9))
		Atlas.draw_taper(self, Vector2(maxf(lim_r, rx0 + 20.0), yl), Vector2(rx0, yl), 0.4, 2.0, Color(Atlas.COPPER, 0.9))
		# décroché sous le repère : le filet du bas descend d'un cran autour du texte
		var yb := y + fs * 1.0
		var dq := 14.0
		draw_polyline(PackedVector2Array([Vector2(x0 - 46.0, yb), Vector2(x0 - 46.0 + dq, yb + dq * 0.5), Vector2(x0 + total + 46.0 - dq, yb + dq * 0.5), Vector2(x0 + total + 46.0, yb)]), Color(Atlas.COPPER, 0.7), 1.0, true)
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
	# titre sur deux lignes : « DONJON » en grand, « ATLAS NOIR » en petites capitales espacées dessous
	var tbox := VBoxContainer.new()
	_tbox = tbox
	tbox.add_theme_constant_override("separation", -2)
	tbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(tbox)
	title_label = Label.new()
	title_label.text = L.t("ui.atlas.title_main").to_upper()
	title_label.clip_text = false
	title_label.add_theme_font_override("font", Atlas.title_font(true, 6))
	title_label.add_theme_color_override("font_color", Atlas.IVORY)
	tbox.add_child(title_label)
	_subtitle = Label.new()
	_subtitle.text = L.t("ui.atlas.title_sub").to_upper()
	_subtitle.add_theme_font_override("font", Atlas.title_font(false, 5))
	_subtitle.add_theme_color_override("font_color", Atlas.COPPER)
	tbox.add_child(_subtitle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hrow.add_child(spacer)
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 0)
	nav_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(nav_row)
	# commandes en icônes (comme sur la maquette) : Guide, Sauvegarde, Paramètres, puis un menu ≡ qui regroupe Accueil, Compte, Admin, Langue et Quitter
	btn_home = _button(L.t("ui.app_header.accueil"))
	btn_home.pressed.connect(func(): nav.emit("Accueil"))
	btn_home.visible = false
	nav_row.add_child(btn_home)
	var guide := _icon_button("book", L.t("ui.atlas.guide_tip"))
	guide.pressed.connect(func(): nav.emit("Guide"))
	nav_row.add_child(guide)
	var cfg := _icon_button("gear", L.t("ui.app_header.parametres_tip"))
	cfg.pressed.connect(func(): nav.emit("Paramètres"))
	nav_row.add_child(cfg)
	btn_account = _button(_account_text())
	btn_account.visible = false
	btn_account.pressed.connect(func(): nav.emit("Compte"))
	nav_row.add_child(btn_account)
	Cloud.session_changed.connect(_refresh_account)
	btn_admin = _button("🛠 Admin")
	btn_admin.pressed.connect(func(): nav.emit("Admin"))
	btn_admin.visible = false
	nav_row.add_child(btn_admin)
	_lang = MenuButton.new()
	_lang.visible = false
	nav_row.add_child(_lang)
	_menu = MenuButton.new()
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.tooltip_text = L.t("ui.atlas.menu_tip")
	_icons[_menu] = "menu"
	var pm := _menu.get_popup()
	_style_popup(pm)
	pm.about_to_popup.connect(_fill_menu)
	pm.id_pressed.connect(_menu_chosen)
	nav_row.add_child(_menu)
	NotifDot.attach(_menu, SuperAdmin.pending, false, SuperAdmin.refresh_pending)    # super admin : signalements à traiter
	_crest = Crest.new()
	_crest.left_ctl = _tbox
	_crest.right_ctl = nav_row
	add_child(_crest)
	_tbox.resized.connect(_crest.queue_redraw)
	nav_row.resized.connect(_crest.queue_redraw)
	UiMetrics.register(self)
	rescale()

## Bouton-icône du menu du haut (cadre absent, icône ivoire qui passe à l'ambre au survol) précédé d'un petit séparateur vertical.
func _icon_button(icon_name: String, tip: String) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	_icons[b] = icon_name
	_style_icon(b, icon_name)
	return b

func _style_icon(b: BaseButton, icon_name: String) -> void:
	var px := int(UiMetrics.css(22.0 if not UiMetrics.portrait else 20.0))
	if b is Button:
		(b as Button).text = ""
		(b as Button).icon = Atlas.icon(icon_name, px, Atlas.IVORY, 1.6)
		(b as Button).expand_icon = false
	elif b is MenuButton:
		(b as MenuButton).text = ""
		(b as MenuButton).icon = Atlas.icon(icon_name, px, Atlas.IVORY, 1.6)
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(0, 0, 0, 0)
		var lit: bool = st == "hover" or st == "pressed" or st == "hover_pressed"
		g.border_color = Atlas.AMBER if lit else Color(0, 0, 0, 0)
		g.border_width_bottom = maxi(1, roundi(UiMetrics.css(2.0)))
		g.content_margin_left = UiMetrics.css(14.0 if not UiMetrics.portrait else 8.0)
		g.content_margin_right = UiMetrics.css(14.0 if not UiMetrics.portrait else 8.0)
		g.content_margin_top = UiMetrics.css(8.0)
		g.content_margin_bottom = UiMetrics.css(8.0)
		# filet de séparation à gauche (sauf pour le premier de la rangée)
		g.border_width_left = 1
		g.border_color = Atlas.AMBER if lit else Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(st, g)
	b.add_theme_color_override("icon_normal_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color("ffd88a"))
	b.add_theme_color_override("icon_pressed_color", Color("ffd88a"))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))

func _style_popup(pm: PopupMenu) -> void:
	var box := AtlasBox.new(6.0)
	box.fill_top = Color(0.03, 0.04, 0.045, 0.97)
	box.fill_bottom = Color(0.02, 0.026, 0.03, 0.97)
	box.border = Color(Atlas.COPPER, 0.7)
	box.cut = 5.0
	pm.add_theme_stylebox_override("panel", box)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(Atlas.AMBER, 0.14)
	pm.add_theme_stylebox_override("hover", hov)
	pm.add_theme_font_override("font", Atlas.title_font(false, 1))
	pm.add_theme_font_size_override("font_size", int(UiMetrics.css(12.0)))
	pm.add_theme_color_override("font_color", Atlas.IVORY)
	pm.add_theme_color_override("font_hover_color", Atlas.AMBER)
	pm.add_theme_color_override("font_disabled_color", Atlas.AMBER_DIM)
	pm.add_theme_constant_override("v_separation", int(UiMetrics.css(8.0)))

## Contenu du menu ≡ : reconstruit à chaque ouverture (Accueil inactif sur l'accueil, Admin seulement si disponible, compte du joueur).
func _fill_menu() -> void:
	var pm := _menu.get_popup()
	pm.clear()
	pm.add_item(L.t("ui.app_header.accueil").to_upper(), 0)
	pm.set_item_disabled(0, btn_home.disabled)
	pm.add_item(_plain(_account_text()).to_upper(), 1)
	if (Data.admin_unlocked or Data.play_origin == "random") and not _home_mode:
		pm.add_item("ADMIN", 2)
		pm.set_item_disabled(pm.get_item_index(2), btn_admin.disabled)
	pm.add_separator()
	pm.add_item(("✓ " if Data.lang == "fr" else "") + "FR", 3)
	pm.add_item(("✓ " if Data.lang == "en" else "") + "EN", 4)
	pm.add_separator()
	pm.add_item(L.t("ui.app_header.quitter").to_upper(), 5)

func _menu_chosen(id: int) -> void:
	match id:
		0:
			nav.emit("Accueil")
		1:
			nav.emit("Compte")
		2:
			nav.emit("Admin")
		3, 4:
			Data.set_lang("en" if id == 4 else "fr")
			nav.emit("Lang")
		5:
			nav.emit("Quitter")

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
	_icons[m] = "save"
	nav_row.add_child(m)
	nav_row.move_child(m, btn_account.get_index())
	m.tooltip_text = L.t("ui.save_menu.sauvegarde")
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
	custom_minimum_size.y = UiMetrics.css(76.0 if not UiMetrics.portrait else 44.0)
	title_label.add_theme_font_size_override("font_size", int(UiMetrics.css(30.0 if not UiMetrics.portrait else 16.0)))
	_subtitle.add_theme_font_size_override("font_size", int(UiMetrics.css(11.0 if not UiMetrics.portrait else 8.0)))
	if _crest != null:
		_crest.visible = not UiMetrics.portrait and _crest.num_text != ""
	var side := UiMetrics.css(40.0 if not UiMetrics.portrait else 22.0)
	_box.content_margin_left = UiMetrics.css(30.0 if not UiMetrics.portrait else 12.0)
	_box.content_margin_right = UiMetrics.css(30.0 if not UiMetrics.portrait else 10.0)
	_box.content_margin_top = UiMetrics.css(15.0 if not UiMetrics.portrait else 0.0)    # titre et icônes descendus vers le décroché
	_box.emit_changed()
	if _emblem != null:
		_emblem.custom_minimum_size = Vector2(side * 1.6, side * 1.6)
		_emblem.queue_redraw()
	if nav_row != null:
		for b in nav_row.get_children():
			if _icons.has(b):
				_style_icon(b as BaseButton, _icons[b])
			elif b is Button:
				if not b.has_meta("full"):
					b.set_meta("full", (b as Button).text)
					if (b as Button).tooltip_text == "":
						(b as Button).tooltip_text = _plain(str((b as Button).text))
				var full := str(b.get_meta("full"))
				_style(b, _short(full) if UiMetrics.portrait else _plain(full))
			elif b is MenuButton:
				_style(b, _plain((b as MenuButton).text) if not UiMetrics.portrait else _short((b as MenuButton).text))

func _process(_d: float) -> void:
	pass

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
