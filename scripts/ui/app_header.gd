class_name AppHeader
extends PanelContainer
## Barre du haut de l'original (« .topbar ») : cadre riveté, titre, groupe « 🏠 Accueil | 📖 Guide | 🇫🇷 FR ▾ »
## (+ 🛠 Admin quand une session d'administration est ouverte) et chaîne au crâne suspendue qui se balance.

signal nav(name: String)

var title_label: Label
var nav_row: HBoxContainer
var btn_admin: Button
var btn_account: Button
var btn_home: Button
var save_menu: SaveMenu    # « 💾 Sauvegarde ▾ » (seulement en jeu : ajouté par GameLayout)
var hang: HangChain
var _lang: MenuButton
var _home_mode: bool = false
var _frame: FrameBox
var _holder: Control
var _box: PanelContainer
var _grip: Button
var _open := 0.0          # 0 = replié, 1 = déployé
var _pinned := false      # déployé à la demande (clic sur la poignée : écrans tactiles)
var _idle := 0.0

func _init() -> void:
	clip_contents = false
	_frame = FrameBox.new(18.0, Vector4(58, 0, 8, 0))
	add_theme_stylebox_override("panel", _frame)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	add_child(hrow)
	title_label = Label.new()
	title_label.text = L.t("common.editeur_de_donjon")
	title_label.clip_text = true
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	title_label.add_theme_color_override("font_color", Color("ffd98a"))
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	hrow.add_child(title_label)
	var box := PanelContainer.new()
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nbox := FrameBox.new(10.0, Vector4(2, 2, 2, 2), Color("0e0b08"))
	nbox.use_grime = false
	nbox.inner_shadow = 0.0
	box.add_theme_stylebox_override("panel", nbox)
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 0)
	box.add_child(nav_row)
	# le groupe de boutons se replie vers la droite (il ne reste que la poignée) et se déploie au survol
	_holder = Control.new()
	_holder.clip_contents = true
	_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(_holder)
	_holder.add_child(box)
	_box = box
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
		_lang.text = _lang_text()
		nav.emit("Lang"))
	nav_row.add_child(_lang)
	var quit := _button("🚪 " + L.t("ui.app_header.quitter"))
	quit.tooltip_text = L.t("ui.app_header.quitter_tip")
	quit.pressed.connect(func(): nav.emit("Quitter"))
	nav_row.add_child(quit)
	_grip = _button("◂")
	_grip.tooltip_text = L.t("ui.app_header.menu_tip")
	_grip.set_meta("keep", true)
	_grip.pressed.connect(func(): _pinned = not _pinned)
	nav_row.add_child(_grip)
	hang = HangChain.new()
	add_child(hang)
	UiMetrics.register(self)
	rescale()

func _account_text() -> String:
	return "👤 " + (Cloud.pseudo() if Cloud.is_signed_in() and Cloud.pseudo() != "" else L.t("ui.cloud.header"))

func _refresh_account() -> void:
	if btn_account == null or not is_instance_valid(btn_account):
		return
	btn_account.set_meta("full", _account_text())
	_style(btn_account, _short(_account_text()) if UiMetrics.portrait else _account_text())

func _lang_text() -> String:
	return "%s ▾" % ("🇬🇧 EN" if Data.lang == "en" else "🇫🇷 FR")

## Menu « 💾 Sauvegarde ▾ » de la partie en cours, entre « Paramètres » et « Compte » (l'accueil n'en a pas : pas de partie à sauvegarder).
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

func rescale() -> void:
	custom_minimum_size.y = UiMetrics.css(92.0 if not UiMetrics.portrait else 60.0)
	title_label.add_theme_font_size_override("font_size", int(UiMetrics.css(28.8 if not UiMetrics.portrait else 15.0)))
	_frame.pad_css = Vector4(58 if not UiMetrics.portrait else 34, 0, 8, 0)
	_frame.rescale()
	if nav_row != null:
		for b in nav_row.get_children():
			if b is Button:
				if not b.has_meta("full"):
					b.set_meta("full", (b as Button).text)
					if (b as Button).tooltip_text == "":
						(b as Button).tooltip_text = str((b as Button).text)
				var full := str(b.get_meta("full"))
				_style(b, _short(full) if UiMetrics.portrait else full)
			elif b is MenuButton:
				_style(b, (b as MenuButton).text)

func _process(d: float) -> void:
	btn_admin.visible = (Data.admin_unlocked or Data.play_origin == "random") and not _home_mode
	_animate_menu(d)

## Menu replié : seule la poignée reste visible à droite ; il se déploie dès que la souris est dessus (ou après un clic sur la poignée)
## et se replie une fraction de seconde après qu'elle l'a quitté.
func _animate_menu(d: float) -> void:
	if _holder == null or _box == null:
		return
	var over := _box.get_global_rect().has_point(get_global_mouse_position()) and get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
	if over or _pinned or (_lang != null and _lang.get_popup().visible) or (save_menu != null and save_menu.is_open()):
		_idle = 0.0
	else:
		_idle += d
	var want := 1.0 if (over or _pinned or _idle < 0.45) else 0.0
	_open = move_toward(_open, want, d * 6.0)
	_grip.text = "▸" if _open > 0.5 else "◂"
	var full := nav_row.get_combined_minimum_size()
	var closed_w := _grip.get_combined_minimum_size().x
	var w := lerpf(closed_w, full.x, smoothstep(0.0, 1.0, _open))
	_holder.custom_minimum_size = Vector2(w, full.y)
	nav_row.size = full
	nav_row.position = Vector2(w - full.x, 0.0)

func _button(text: String) -> Button:
	var b := Button.new()
	_style(b, text)
	return b

func _style(b: Button, text: String) -> void:
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.82 if not UiMetrics.portrait else 0.9)))
	b.add_theme_color_override("font_color", Color("dccbaa"))
	b.add_theme_color_override("font_hover_color", Color("ffd98a"))
	b.add_theme_color_override("font_pressed_color", Color("ffd98a"))
	b.add_theme_color_override("font_disabled_color", Color("ffd98a"))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color("3a2e21") if st == "hover" else (Color("43352a") if st == "disabled" else Color("2a2119"))
		g.border_color = Color("070504")
		g.border_width_left = maxi(1, roundi(UiMetrics.css(2.0)))
		g.content_margin_left = UiMetrics.css(14.0 if not UiMetrics.portrait else 4.5)
		g.content_margin_right = UiMetrics.css(14.0 if not UiMetrics.portrait else 4.5)
		g.content_margin_top = UiMetrics.css(7.0)
		g.content_margin_bottom = UiMetrics.css(7.0)
		b.add_theme_stylebox_override(st, g)
