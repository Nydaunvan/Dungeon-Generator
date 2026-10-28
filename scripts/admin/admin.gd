extends Control
## Administration (vue `#viewAdmin` de l'original) : porte d'accès, bannière « Jouer / Reprendre », onglets, contenu.
##
## État de session : `Data.admin_unlocked` (adminUnlocked), `Data.play_origin == "random"` (cameFromRandomGen),
## `Data.own_dungeon_launched` (ownDungeonLaunched), `Data.resume_game` (la partie suspendue : STATE de l'original).

## Sections de l'atelier (menu latéral : `AtelierSide.GROUPS`). Anciens identifiants d'onglet → section actuelle.
const LEGACY := {"general": "combat", "chars": "party", "items": "party"}

var _root: VBoxContainer
var _header: AppHeader
var _scroll: ScrollContainer              ## défilement principal de la page courante (pages à défilement)
var _tracked: Dictionary = {}             ## nom → ScrollContainer dont la position est conservée à la reconstruction
var _stage: Control                       ## zone à droite du menu
var _content_host: Control                ## racine des pages
var _gate: Control
var _main: Control
var _banner: Control
var _banner_text: Label
var _btn_play: Button
var _btn_resume: Button
var _body: HBoxContainer
var _side: AtelierSide
var _menu_row: HBoxContainer
var _head_margin: MarginContainer         ## en-tête de l'application (masqué dans l'éditeur de niveaux, plein écran)
var _menu_title: Label
var _side_open := false
var _tab := "home"
var _what := ""                           ## ce qui vient d'être modifié (affiché dans « Modifié récemment »)
var _modal_layer: CanvasLayer
var _pw_input: LineEdit
var _pw_error: Label
var _footer: Label
## État de la page (« Enregistré automatiquement », « N réglages modifiés ») : renseigné par les pages de règles.
var admin_status: Label

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0a0705")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(Ax.backdrop())
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)
	# l'original rafraîchit les données de l'administration à l'ouverture (repairEvolvedClasses + valeurs par défaut)
	Data.ensure_defaults(Data.admin_config())
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", int(UiMetrics.css(14.0)))
	hm.add_theme_constant_override("margin_right", int(UiMetrics.css(14.0)))
	hm.add_theme_constant_override("margin_top", int(UiMetrics.css(12.0)))
	hm.add_theme_constant_override("margin_bottom", int(UiMetrics.css(8.0)))
	_root.add_child(hm)
	_head_margin = hm
	_header = AppHeader.new()
	_header.nav.connect(_nav)
	_header.btn_admin.disabled = true
	hm.add_child(_header)
	_menu_row = HBoxContainer.new()
	_menu_row.add_theme_constant_override("separation", 12)
	_root.add_child(_menu_row)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	_root.add_child(_body)
	_side = AtelierSide.new()
	_side.picked.connect(func(id: String):
		_side_open = false
		_select_tab(id))
	_side.search_pressed.connect(_open_search)
	_side.back_pressed.connect(_attempt_home)
	_body.add_child(_side)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.clip_contents = true
	_body.add_child(_stage)
	_content_host = Control.new()
	_content_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_content_host)
	_build_gate()
	_build_main()
	_footer = Label.new()
	_footer.text = L.t("common.editeur_de_donjon") + " " + AppVersion.label() + " · " + L.t("common.portage_godot") + " · Made by Claude & Nydaunvan"
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_font_override("font", Ax.inter(400))
	_footer.add_theme_font_size_override("font_size", 10)
	_footer.add_theme_color_override("font_color", Color("6f5e44"))
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_footer)
	resized.connect(_layout)
	_layout()
	_show_state()

func _layout() -> void:
	UiMetrics.update(self)
	_apply_side()
	_header.rescale()

func _nav(n: String) -> void:
	match n:
		"Accueil": _attempt_home()
		"Guide": Dialogs.guide(_modal_layer)
		"Paramètres": SettingsModal.open(_modal_layer)
		"Compte": AccountModal.open(_modal_layer)
		"Tchat": ChatDock.open_panel()
		"Quitter": Dialogs.confirm(_modal_layer, "", L.t("ui.app_header.quitter_confirm"), func(): get_tree().quit(), L.t("ui.app_header.quitter"))
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
	var p := OrnatePanel.new(L.t("admin.main.acces_administrateur"))
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
	_pw_input.placeholder_text = L.t("admin.main.mot_de_passe")
	_pw_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_input.text_submitted.connect(func(_t): _try_login())
	_pw_input.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.85))))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pw_input.custom_minimum_size = Vector2(UiMetrics.css(208.0), 0)
	row.add_child(_pw_input)
	Form._place(p.body, row, 0.0, 10.0)
	var c1 := CenterContainer.new()
	c1.add_child(Form._button([L.t("admin.main.se_connecter"), _try_login, true]))
	Form._place(p.body, c1, 0.0, 0.0)
	_pw_error = Label.new()
	_pw_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_error.custom_minimum_size = Vector2(0, UiMetrics.rem(0.78) * 1.5)
	_pw_error.add_theme_font_size_override("font_size", int(round(UiMetrics.rem(0.78))))
	_pw_error.add_theme_color_override("font_color", Color("e06a5a"))
	Form._place(p.body, _pw_error, 6.0, 0.0)
	var c2 := CenterContainer.new()
	c2.add_child(Form._button([L.t("admin.main.retour_au_jeu"), _back_to_game]))
	Form._place(p.body, c2, 10.0, 0.0)
	_stage.add_child(_gate)
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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
		_pw_error.text = L.t("admin.main.mot_de_passe_incorrect")

## `adminLogout` : retour à l'accueil (qui reverrouille).
func logout() -> void:
	Data.go_home()

func _show_state() -> void:
	_gate.visible = not Data.admin_unlocked
	_main.visible = Data.admin_unlocked
	_apply_side()
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
	_main = Control.new()
	_main.visible = false
	add_child(_main)
	# écran étroit : le menu latéral se range derrière un bouton
	var mb := Ax.icon_btn("menu", func():
		_side_open = not _side_open
		_apply_side(), 40.0, Ax.GOLD, "ghost", L.t("ui.atelier.menu"))
	_menu_row.add_child(Ax.margin(mb, 14, 4, 0, 4))
	_menu_title = Ax.title("", 18, Ax.GOLD_L)
	_menu_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_menu_row.add_child(_menu_title)
	# bannière « Tester la partie / Reprendre » : dans le pied du menu latéral
	_banner = _side.banner
	_banner_text = _side.banner_text
	_btn_play = _side.btn_play
	_btn_resume = _side.btn_resume
	_btn_play.pressed.connect(_banner_primary)
	_btn_resume.pressed.connect(Data.resume_from_admin)

## Écran étroit (portrait) ?
func _narrow() -> bool:
	return size.x < 860.0

## Menu latéral : visible une fois connecté ; sur écran étroit, seulement à la demande (bouton ☰).
func _apply_side() -> void:
	if _side == null:
		return
	var narrow := _narrow()
	var full := _tab == "levels"            # l'éditeur de niveaux occupe tout l'écran
	_side.visible = Data.admin_unlocked and not full and (not narrow or _side_open)
	_menu_row.visible = narrow and Data.admin_unlocked and not full
	_head_margin.visible = not full
	if _footer != null:
		_footer.visible = not full
	_content_host.visible = Data.admin_unlocked
	if narrow:
		_side.custom_minimum_size.x = minf(300.0, size.x * 0.82)
	else:
		_side.custom_minimum_size.x = 280.0

func _open_search() -> void:
	AtelierSearch.open(self)

func _unhandled_key_input(e: InputEvent) -> void:
	if Data.admin_unlocked and e is InputEventKey and e.pressed and e.keycode == KEY_K and (e.ctrl_pressed or e.meta_pressed):
		get_viewport().set_input_as_handled()
		_open_search()

## `updateAdminPlayBanner` : trois états.
func _update_banner() -> void:
	var active := _game_active()
	if _random_run() and active:
		_banner.visible = true
		_btn_resume.visible = false
		_banner_text.text = L.t("admin.main.une_partie_est_en_cours")
		_btn_play.text = L.t("admin.main.reprendre_la_partie_en_cours").lstrip("◀ ")
	elif not _random_run():
		_banner.visible = true
		_banner_text.text = L.t("admin.main.vous_pouvez_reprendre_votre_partie") \
			if (active and Data.own_dungeon_launched) else L.t("admin.main.vous_configurez_votre_propre")
		_btn_play.text = L.t("admin.main.jouer_ce_donjon").lstrip("▶ ")
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
		_show_loader(L.t("admin.main.descente_dans_le_donjon"), L.t("admin.main.chargement_de_la_carte"))
		await get_tree().create_timer(0.32).timeout
		Data.save_config()
		var cfg := Data.admin_config().duplicate(true)
		Data.launch(cfg, "custom", Data.ADMIN_KEEP)
		Data.own_dungeon_launched = true
	Dialogs.confirm(_modal_layer, "", L.t("admin.main.commencer_une_partie_avec_le"), go)

func _show_loader(title: String, text: String) -> void:
	var m := Modal.open(_modal_layer, title, 340.0)
	m.esc_closes = false
	m.add_text(text, UiTheme.PARCH, 15, true)

func _select_tab(id: String) -> void:
	if LEGACY.has(id):
		if id == "items":
			AtelierParty.sub = "items"
		id = str(LEGACY[id])
	Ax.flush()
	Form.flush()
	_tab = id
	_side.select(id)
	_menu_title.text = _section_title(id)
	_apply_side()
	for ch in _content_host.get_children():
		ch.queue_free()
	admin_status = null
	_scroll = null
	_tracked.clear()
	Form.reg.clear()
	AdminGeneral.reg.clear()
	Ax.bind(self, func(): save())
	match id:
		"home": AtelierHome.build(_content_host, self)
		"levels": AdminLevels.build(_content_host, self)
		"party": AtelierParty.build(_content_host, self)
		"classes": AdminClasses.build(_content_host, self)
		"spells": AdminSpells.build(_content_host, self)
		_: AdminGeneral.build_page(_content_host, self, id)
	_refresh_side()
	Atelier.visited(id)

## Pastilles du menu : nombre de niveaux, sections modifiées.
func _refresh_side() -> void:
	_side.set_count("levels", str((Data.admin_config().get("levels", []) as Array).size()))
	_side.set_dirty(Atelier.session_count())

## Titre d'une section (clé de langue du menu).
static func _section_title(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return L.t(str(it[1]))
	return ""

## Ouvre une section depuis une autre page (accueil, recherche).
func go(id: String) -> void:
	_select_tab(id)

## Défilement à conserver quand la page est reconstruite (listes des pages maître-détail).
func track_scroll(name: String, sc: ScrollContainer) -> void:
	_tracked[name] = sc

## Ce que l'utilisateur est en train de modifier (« Épée de cendre ») : affiché dans « Modifié récemment ».
func note(text: String) -> void:
	_what = text

## Recharge l'onglet courant (après une modification qui change sa structure).
func refresh_tab() -> void:
	var keep := {}
	for k in _tracked:
		var sc: ScrollContainer = _tracked[k]
		if is_instance_valid(sc):
			keep[k] = sc.scroll_vertical
	var main_v := _scroll.scroll_vertical if _scroll != null and is_instance_valid(_scroll) else 0
	_select_tab(_tab)
	_update_banner()
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = main_v
	for k in keep:
		if _tracked.has(k) and is_instance_valid(_tracked[k]):
			(_tracked[k] as ScrollContainer).scroll_vertical = keep[k]

func modals() -> Node:
	return _modal_layer

## Écrit un message dans l'état de l'onglet Général (s'il est affiché).
func say(text: String) -> void:
	if admin_status != null and is_instance_valid(admin_status):
		admin_status.text = text

static func _now_message() -> String:
	var t := Time.get_time_dict_from_system()
	return L.fa(L.t("admin.main.configuration_enregistree_a_02d"), [t.hour, t.minute, t.second])

## `saveConfigNow` : enregistre la configuration éditée ; le message va dans `status` (ou dans l'état du Général).
func save(status: Label = null) -> void:
	Atelier.touch(_tab, _what)
	_refresh_dirty()
	var msg := _now_message() if Data.save_config() else L.t("admin.main.echec_de_l_enregistrement")
	if status != null and is_instance_valid(status):
		status.text = msg
	say(msg)

func _refresh_dirty() -> void:
	if _side != null:
		_side.set_dirty(Atelier.session_count())

## Bouton « 💾 Enregistrer la configuration par défaut » de l'original (`confirmSaveConfigDefault`).
func confirm_save(status: Label = null) -> void:
	var go := func(): save(status)
	Dialogs.confirm(_modal_layer, "", L.t("admin.main.ceci_va_enregistrer_la_configuration"), go)

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
	var m := Modal.open(_modal_layer, L.t("common.quitter_la_partie_en_cours"), 440.0)
	m.add_text(L.t("common.voulez_vous_sauvegarder_votre"), UiTheme.PARCH, 14, true)
	var btns: Array = [
		{"text": L.t("common.sauvegarder_et_quitter"), "primary": true, "cb": func():
			m.close()
			SlotsModal.open(_modal_layer, func(): return g, Data.launch_save, func(_i): Data.go_home(), _slot_opts())},
		{"text": L.t("common.exporter_le_donjon_fichier_json"), "primary": false, "cb": func():
			m.close()
			Files.save_text(_modal_layer, Data.export_name(str(g.config.get("title", "")), "_sauvegarde"), Saves.export_text(g.config, g.save, str(g.get("origin", Data.play_origin))), func(_t): Data.go_home())},
		{"text": L.t("common.quitter_sans_sauvegarder"), "primary": false, "cb": func():
			m.close()
			Data.go_home()},
		{"text": L.t("common.annuler_rester_dans_la_partie"), "primary": false, "cb": func(): m.close()},
	]
	m.set_buttons(btns)

## `creationLeaveOverlay` : quitter la création d'un donjon (revenir repart d'une base neuve). Une seule colonne de cartes : chaque
## choix dit ce qu'il fait, le plus sûr en haut, l'abandon en bas.
func _creation_leave_overlay() -> void:
	var header: Array = [[L.t("ui.creation_leave.autosaved"), HubKit.GOOD, 14]]
	var opts: Array = [
		{"icon": "⬇", "title": L.t("ui.creation_leave.export_t"), "desc": L.t("ui.creation_leave.export_d"), "btn": L.t("ui.creation_leave.export_b"), "primary": true, "keep": true, "cb": func(): AdminGeneral.export_config(self)},
		{"icon": "📋", "title": L.t("ui.creation_leave.code_t"), "desc": L.t("ui.creation_leave.code_d"), "extra": func(card: VBoxContainer):
			var out: TextEdit = null
			var status: Label = null
			var b := HubKit.button(L.t("common.generer_un_code_a_partager"), func(): Form.generate_code(Data.admin_config(), out, status), false, 38)
			card.add_child(b)
			out = Form.code_area(card, "", true, 70.0, 6.0)
			out.visible = false
			status = Form.status_label(card)},
		{"icon": "🚪", "title": L.t("ui.creation_leave.quit_t"), "desc": L.t("ui.creation_leave.quit_d"), "btn": L.t("ui.creation_leave.quit_b"), "primary": true, "cb": func(): Data.go_home()},
	]
	LeaveModal.open(_modal_layer, L.t("admin.main.quitter_la_creation_du_donjon"), header, opts, L.t("admin.main.rester_dans_l_interface_de"), true, 540.0)
