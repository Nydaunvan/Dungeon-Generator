extends Control
## Administration (vue `#viewAdmin` de l'original) : porte d'accès, bannière « Jouer / Reprendre », onglets, contenu.
##
## État de session : `Data.admin_unlocked` (adminUnlocked), `Data.play_origin == "random"` (cameFromRandomGen),
## `Data.own_dungeon_launched` (ownDungeonLaunched), `Data.resume_game` (la partie suspendue : STATE de l'original).

const TABS := [["general", "Général"], ["chars", "Personnages"], ["classes", "Classes"], ["spells", "Sorts / Capacités"], ["items", "Objets de base"], ["levels", "Niveaux"]]
const SHARED_TABS := ["classes", "spells", "items"]
const SHARED_TIP := "Enregistrer comme configuration par défaut affecte aussi le donjon aléatoire, qui pioche dans ce même catalogue"

var _root: VBoxContainer
var _header: AppHeader
var _scroll: ScrollContainer
var _page: VBoxContainer
var _gate: Control
var _main: VBoxContainer
var _banner: OrnatePanel
var _banner_text: Label
var _btn_play: Button
var _btn_resume: Button
var _tab_bar: HFlowContainer
var _content_host: VBoxContainer
var _tab := "general"
var _modal_layer: CanvasLayer
var _pw_input: LineEdit
var _pw_error: Label
var _tab_buttons: Dictionary = {}
var _footer: Label
## « #adminStatus » de l'onglet Général (renseigné par AdminGeneral) : reçoit les messages de `say()`.
var admin_status: Label

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = UiTheme.tex("bg_tile")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)
	# l'original rafraîchit les données de l'administration à l'ouverture (repairEvolvedClasses + valeurs par défaut)
	Data.ensure_defaults(Data.admin_config())
	_header = AppHeader.new()
	_header.nav.connect(_nav)
	_header.btn_admin.disabled = true
	_root.add_child(_header)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiMetrics.css(12.0))
	_root.add_child(gap)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 0)
	_scroll.add_child(_page)
	_build_gate()
	_build_main()
	_footer = Label.new()
	_footer.text = tr("Éditeur de Donjon") + " v1.29 · " + tr("portage Godot") + "\nMade by Claude & Nydaunvan"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	_footer.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
	_footer.add_theme_color_override("font_color", Color("6f5e44"))
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_footer)
	resized.connect(_layout)
	_layout()
	_show_state()

func _layout() -> void:
	UiMetrics.update(self)
	var side := UiMetrics.css(14.0)
	var maxw := clampf(size.x * 0.82, 1440.0, 2000.0)
	var extra := maxf(0.0, (size.x - maxw) * 0.5)
	_root.offset_left = side + extra
	_root.offset_right = -(side + extra)
	_root.offset_top = UiMetrics.css(12.0)
	_root.offset_bottom = -UiMetrics.css(10.0)
	_header.rescale()

func _nav(n: String) -> void:
	match n:
		"Accueil": _attempt_home()
		"Guide": Dialogs.guide(_modal_layer)
		"Lang": get_tree().reload_current_scene()

# ------------------------------------------------------------------ état de session

func _random_run() -> bool:
	return Data.play_origin == "random"

## `gameActive` de updateAdminPlayBanner : une partie suspendue existe, ni perdue ni gagnée.
func _game_active() -> bool:
	if not Data.admin_has_run():
		return false
	var sv: Dictionary = Data.resume_game.save
	return not bool(sv.get("game_over", false)) and not bool(sv.get("won", false))

# ------------------------------------------------------------------ porte d'accès (#adminLoginGate)

func _build_gate() -> void:
	_gate = HBoxContainer.new()
	_gate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Control.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate.add_child(l)
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(UiMetrics.css(340.0), 0)
	wrap.add_theme_constant_override("separation", 0)
	_gate.add_child(wrap)
	var r := Control.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate.add_child(r)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, UiMetrics.css(28.0))
	wrap.add_child(top)
	var p := OrnatePanel.new("Accès administrateur")
	wrap.add_child(p)
	var crest := Label.new()
	crest.text = "🔐"
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crest.add_theme_font_size_override("font_size", int(UiMetrics.rem(2.4)))
	var v: Node = p.get_child(0)
	v.add_child(crest)
	v.move_child(crest, 0)
	_pw_input = LineEdit.new()
	_pw_input.secret = true
	_pw_input.placeholder_text = "Mot de passe"
	_pw_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_input.text_submitted.connect(func(_t): _try_login())
	_pw_input.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.85))))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pw_input.custom_minimum_size = Vector2(UiMetrics.css(208.0), 0)
	row.add_child(_pw_input)
	Form._place(p.body, row, 0.0, 10.0)
	var c1 := CenterContainer.new()
	c1.add_child(Form._button(["Se connecter", _try_login, true]))
	Form._place(p.body, c1, 0.0, 0.0)
	_pw_error = Label.new()
	_pw_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_error.custom_minimum_size = Vector2(0, UiMetrics.rem(0.78) * 1.5)
	_pw_error.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.78))))
	_pw_error.add_theme_color_override("font_color", Color("e06a5a"))
	Form._place(p.body, _pw_error, 6.0, 0.0)
	var c2 := CenterContainer.new()
	c2.add_child(Form._button(["◀ Retour au jeu", _back_to_game]))
	Form._place(p.body, c2, 10.0, 0.0)
	_page.add_child(_gate)

## « ◀ Retour au jeu » (`switchView('play')`) : reprend la partie suspendue, sinon retombe à l'accueil.
func _back_to_game() -> void:
	if Data.resume_game.is_empty():
		Data.go_home()
	else:
		Data.resume_from_admin()

## `tryAdminLogin` : compare à `CONFIG.adminPassword||'admin'`.
func _try_login() -> void:
	var cfg := Data.admin_config()
	var pw := str(cfg.get("adminPassword", ""))
	if pw == "":
		pw = "admin"
	if _pw_input.text == pw:
		Data.admin_unlocked = true
		_pw_input.text = ""
		_pw_error.text = ""
		_show_state()
	else:
		_pw_error.text = "Mot de passe incorrect."

## `adminLogout` : retour à l'accueil (qui reverrouille).
func logout() -> void:
	Data.go_home()

func _show_state() -> void:
	_gate.visible = not Data.admin_unlocked
	_main.visible = Data.admin_unlocked
	if Data.admin_unlocked:
		_update_banner()
		_select_tab(_tab)

# ------------------------------------------------------------------ cadre principal

func _pad_button(b: Button, px: float, py: float) -> void:
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st)
		if sb == null:
			continue
		sb = sb.duplicate()
		sb.set_content_margin(SIDE_LEFT, UiMetrics.css(px))
		sb.set_content_margin(SIDE_RIGHT, UiMetrics.css(px))
		sb.set_content_margin(SIDE_TOP, UiMetrics.css(py))
		sb.set_content_margin(SIDE_BOTTOM, UiMetrics.css(py))
		b.add_theme_stylebox_override(st, sb)

func _build_main() -> void:
	_main = VBoxContainer.new()
	_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_theme_constant_override("separation", int(UiMetrics.css(14.0)))
	_page.add_child(_main)
	# bannière #adminPlayBanner
	_banner = OrnatePanel.new()
	_main.add_child(_banner)
	_banner_text = Form.note(_banner.body, "", 0.0, 8.0)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var brow := HFlowContainer.new()
	brow.alignment = FlowContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("h_separation", int(UiMetrics.css(4.0)))
	brow.add_theme_constant_override("v_separation", int(UiMetrics.css(4.0)))
	_banner.body.add_child(brow)
	_btn_play = Form._button(["▶ Jouer ce donjon", _banner_primary, true])
	_btn_resume = Form._button(["◀ Reprendre là où vous étiez", Data.resume_from_admin])
	var tut := Form._button(["🧭 Tutoriel", func(): DocModal.tutorial(_modal_layer)])
	for b in [_btn_play, _btn_resume, tut]:
		brow.add_child(b)
		_pad_button(b, 24.0, 12.0)
	# onglets
	_tab_bar = HFlowContainer.new()
	_tab_bar.add_theme_constant_override("h_separation", int(UiMetrics.css(6.0)))
	_tab_bar.add_theme_constant_override("v_separation", int(UiMetrics.css(6.0)))
	_main.add_child(_tab_bar)
	var group := ButtonGroup.new()
	for t in TABS:
		var id: String = t[0]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.78))))
		b.text = str(t[1])
		b.pressed.connect(func(): _select_tab(id))
		_tab_bar.add_child(b)
		_pad_button(b, 16.0, 8.0)
		_tab_buttons[id] = b
		if id in SHARED_TABS:
			_add_badge(b)
	_content_host = VBoxContainer.new()
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_theme_constant_override("separation", int(UiMetrics.css(14.0)))
	_main.add_child(_content_host)

## Pastille « 🎲 partagé » (`.tab-shared-badge`) collée à droite du libellé de l'onglet, avec son infobulle.
func _add_badge(b: Button) -> void:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(232.0 / 255.0, 180.0 / 255.0, 92.0 / 255.0, 0.18)
	sb.border_color = Color(232.0 / 255.0, 180.0 / 255.0, 92.0 / 255.0, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = UiMetrics.css(6.0)
	sb.content_margin_right = UiMetrics.css(6.0)
	sb.content_margin_top = UiMetrics.css(1.0)
	sb.content_margin_bottom = UiMetrics.css(1.0)
	badge.add_theme_stylebox_override("panel", sb)
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.tooltip_text = SHARED_TIP
	var lab := Label.new()
	lab.text = SHARED_BADGE
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.65))))
	lab.add_theme_color_override("font_color", Color("ffd88a"))
	badge.add_child(lab)
	b.add_child(badge)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# réserve la place sous le badge (marge gauche de 5 px de `.tab-shared-badge`)
	var font := b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	var bw := lab.get_minimum_size().x + UiMetrics.css(12.0) + 2.0
	var tw := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.custom_minimum_size.x = tw + UiMetrics.css(32.0) + UiMetrics.css(5.0) + bw
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.offset_right = -UiMetrics.css(16.0)
	badge.offset_left = -UiMetrics.css(16.0) - bw
	badge.offset_top = -lab.get_minimum_size().y * 0.5 - 1.0
	badge.offset_bottom = lab.get_minimum_size().y * 0.5 + 1.0

const SHARED_BADGE := "🎲 partagé"

## `updateAdminPlayBanner` : trois états.
func _update_banner() -> void:
	var active := _game_active()
	if _random_run() and active:
		_banner.visible = true
		_btn_resume.visible = false
		_banner_text.text = "Une partie est en cours sur ce donjon aléatoire. Reprenez-la dès que vous le souhaitez."
		_btn_play.text = "◀ Reprendre la partie en cours"
	elif not _random_run():
		_banner.visible = true
		_banner_text.text = "Vous pouvez reprendre votre partie en cours pour continuer à tester, ou relancer une partie neuve avec vos dernières modifications." \
			if (active and Data.own_dungeon_launched) else "Vous configurez votre propre donjon. Lancez-le dès que vous êtes prêt, ou modifiez librement les onglets ci-dessous avant de jouer."
		_btn_play.text = "▶ Jouer ce donjon"
		_btn_resume.visible = active and Data.own_dungeon_launched
	else:
		_banner.visible = false
		_btn_resume.visible = false

## Bouton principal de la bannière : reprise (donjon aléatoire en cours) ou nouvelle partie.
func _banner_primary() -> void:
	if _random_run() and _game_active():
		Data.resume_from_admin()
	else:
		_play_current()

## `playCurrentDungeon` : confirmation, enregistrement, écran de chargement, nouvelle partie avec la configuration éditée.
func _play_current() -> void:
	var go := func():
		_show_loader("Descente dans le donjon", "Chargement de la carte")
		await get_tree().create_timer(0.32).timeout
		Data.save_config()
		var cfg := Data.admin_config().duplicate(true)
		Data.launch(cfg, "custom", Data.ADMIN_KEEP)
		Data.own_dungeon_launched = true
	Dialogs.confirm(_modal_layer, "", "Commencer une partie avec le donjon actuellement configuré ?", go)

func _show_loader(title: String, text: String) -> void:
	var m := Modal.open(_modal_layer, title, 340.0)
	m.esc_closes = false
	m.add_text(text, UiTheme.PARCH, 15, true)

func _select_tab(id: String) -> void:
	_tab = id
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == id)
	for ch in _content_host.get_children():
		ch.queue_free()
	admin_status = null
	match id:
		"general": AdminGeneral.build(_content_host, self)
		"chars": AdminChars.build(_content_host, self)
		"classes": AdminClasses.build(_content_host, self)
		"spells": AdminSpells.build(_content_host, self)
		"items": AdminItems.build(_content_host, self)
		"levels": AdminLevels.build(_content_host, self)

## Recharge l'onglet courant (après une modification qui change sa structure).
func refresh_tab() -> void:
	var keep := _scroll.scroll_vertical if _scroll != null else 0
	_select_tab(_tab)
	_update_banner()
	if _scroll != null:
		await get_tree().process_frame
		await get_tree().process_frame
		_scroll.scroll_vertical = keep

func modals() -> Node:
	return _modal_layer

## Écrit un message dans l'état de l'onglet Général (s'il est affiché).
func say(text: String) -> void:
	if admin_status != null and is_instance_valid(admin_status):
		admin_status.text = text

static func _now_message() -> String:
	var t := Time.get_time_dict_from_system()
	return "Configuration enregistrée à %02d:%02d:%02d (stockage local de l'appareil)" % [t.hour, t.minute, t.second]

## `saveConfigNow` : enregistre la configuration éditée ; le message va dans `status` (ou dans l'état du Général).
func save(status: Label = null) -> void:
	var msg := _now_message() if Data.save_config() else "Échec de l'enregistrement."
	if status != null and is_instance_valid(status):
		status.text = msg
	say(msg)

## Bouton « 💾 Enregistrer la configuration par défaut » de l'original (`confirmSaveConfigDefault`).
func confirm_save(status: Label = null) -> void:
	var go := func(): save(status)
	Dialogs.confirm(_modal_layer, "", "⚠️ Ceci va enregistrer la configuration comme NOUVELLE CONFIGURATION PAR DÉFAUT : classes, sorts, objets, niveaux... Tout changement ici s'appliquera à TOUTES les futures parties, y compris le donjon aléatoire, qui pioche dans ce même catalogue de classes/sorts/objets — pas seulement à la partie en cours. Confirmer l'enregistrement ?", go)

# ------------------------------------------------------------------ quitter vers l'accueil (attemptSwitchView('home'))

func _attempt_home() -> void:
	if _random_run() and _game_active():
		_leave_game_overlay()
	elif Data.admin_unlocked and not _random_run():
		_creation_leave_overlay()
	else:
		Data.go_home()

func _slot_opts() -> Dictionary:
	return {"current_origin": Data.play_origin}

## `leaveGameOverlay` pendant une partie aléatoire en cours.
func _leave_game_overlay() -> void:
	var g: Dictionary = Data.resume_game
	var m := Modal.open(_modal_layer, "🚪 Quitter la partie en cours", 440.0)
	m.add_text("Voulez-vous sauvegarder votre progression avant de continuer ?", UiTheme.PARCH, 14, true)
	var btns: Array = [
		{"text": "💾 Sauvegarder et quitter", "primary": true, "cb": func():
			m.close()
			SlotsModal.open(_modal_layer, func(): return g, Data.launch_save, func(_i): Data.go_home(), _slot_opts())},
		{"text": "📤 Exporter le donjon (fichier JSON) et quitter", "primary": false, "cb": func():
			m.close()
			Files.save_text(_modal_layer, Data.export_name(str(g.config.get("title", "")), "_sauvegarde"), Saves.export_text(g.config, g.save, str(g.get("origin", Data.play_origin))), func(_t): Data.go_home())},
		{"text": "Quitter sans sauvegarder", "primary": false, "cb": func():
			m.close()
			Data.go_home()},
		{"text": "Annuler, rester dans la partie", "primary": false, "cb": func(): m.close()},
	]
	m.set_buttons(btns)

## `creationLeaveOverlay` : quitter la création d'un donjon (revenir repart d'une base neuve).
func _creation_leave_overlay() -> void:
	var m := Modal.open(_modal_layer, "🏠 Quitter la création du donjon", 440.0)
	m.add_text("Revenir ici repartira toujours d'une toute nouvelle base aléatoire : exportez votre création si vous voulez la conserver.", UiTheme.PARCH, 14, true)
	m.set_buttons([
		{"text": "⬇ Exporter en JSON (fichier)", "primary": false, "cb": func(): AdminGeneral.export_config(self)},
		{"text": "📋 Générer un code à partager", "primary": false, "cb": func(): Form.generate_code(Data.admin_config(), out_ref[0], status_ref[0])},
		{"text": "🚪 Quitter et abandonner cette création", "primary": true, "cb": func():
			m.close()
			Data.go_home()},
		{"text": "Rester dans l'interface de création", "primary": false, "cb": func(): m.close()},
	])
	# zone du code, sous « Générer un code »
	var row: Node = m._buttons_row
	var out := Form.code_area(row, "", true, 70.0, 6.0)
	out.visible = false
	var status := Form.status_label(row)
	out_ref[0] = out
	status_ref[0] = status
	row.move_child(out, 2)
	row.move_child(status, 3)

var out_ref: Array = [null]
var status_ref: Array = [null]
