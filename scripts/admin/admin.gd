extends Control
## Administration : identité du jeu, personnages, classes, sorts, objets, niveaux.

const TABS := [["general", "Général"], ["chars", "Personnages"], ["classes", "Classes"], ["spells", "Sorts / Capacités"], ["items", "Objets de base"], ["levels", "Niveaux"]]

var _bg: TextureRect
var _root: VBoxContainer
var _header: PanelContainer
var _body: Control
var _gate: Control
var _main: VBoxContainer
var _tab_bar: HFlowContainer
var _content_host: VBoxContainer
var _status: Label
var _tab := "general"
var _modal_layer: CanvasLayer
var _pw_input: LineEdit
var _pw_error: Label
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = TextureRect.new()
	_bg.texture = UiTheme.tex("bg_tile")
	_bg.stretch_mode = TextureRect.STRETCH_TILE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 6
	_root.offset_right = -6
	_root.offset_top = 6
	_root.offset_bottom = -6
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 20
	add_child(_modal_layer)
	_build_header()
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_body)
	_build_gate()
	_build_main()
	_show_state()

func _build_header() -> void:
	_header = PanelContainer.new()
	_header.add_theme_stylebox_override("panel", UiTheme.tbox("frame_header", [12, 12, 12, 12], [16, 5, 12, 5]))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	_header.add_child(hrow)
	var title := Label.new()
	title.text = "ADMINISTRATION"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("e0b070"))
	hrow.add_child(title)
	for n in ["Accueil", "Admin", "Guide"]:
		var b := Button.new()
		b.text = n.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = n == "Admin"
		var nn: String = n
		b.pressed.connect(func(): _nav(nn))
		hrow.add_child(b)
	_root.add_child(_header)

func _nav(n: String) -> void:
	match n:
		"Accueil": Data.go_home()
		"Guide": Dialogs.guide(_modal_layer)

# ------------------------------------------------------------------ accès

func _build_gate() -> void:
	_gate = CenterContainer.new()
	_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_gate)
	var p := OrnatePanel.new("Accès administrateur")
	p.custom_minimum_size = Vector2(340, 0)
	_gate.add_child(p)
	_pw_input = LineEdit.new()
	_pw_input.secret = true
	_pw_input.placeholder_text = "Mot de passe"
	_pw_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pw_input.text_submitted.connect(func(_t): _try_login())
	p.body.add_child(_pw_input)
	_pw_error = Label.new()
	_pw_error.add_theme_color_override("font_color", Color("e06a5a"))
	_pw_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.body.add_child(_pw_error)
	Form.buttons(p.body, [["Se connecter", _try_login], ["Retour à l'accueil", Data.go_home]])

func _try_login() -> void:
	var pw := str(Data.config.get("adminPassword", "admin"))
	if _pw_input.text == pw:
		Data.admin_unlocked = true
		_pw_input.text = ""
		_pw_error.text = ""
		_show_state()
	else:
		_pw_error.text = "Mot de passe incorrect."

func _logout() -> void:
	Data.admin_unlocked = false
	_show_state()

func _show_state() -> void:
	_gate.visible = not Data.admin_unlocked
	_main.visible = Data.admin_unlocked
	if Data.admin_unlocked:
		_select_tab(_tab)

# ------------------------------------------------------------------ cadre principal

func _build_main() -> void:
	_main = VBoxContainer.new()
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.add_theme_constant_override("separation", 8)
	_body.add_child(_main)
	if Data.admin_banner:
		var ban := OrnatePanel.new()
		_main.add_child(ban)
		Form.hint(ban.body, "Vous configurez votre propre donjon. Lancez-le dès que vous êtes prêt, ou modifiez librement les onglets ci-dessous avant de jouer.")
		Form.buttons(ban.body, [["Jouer ce donjon", _play_current]])
	_tab_bar = HFlowContainer.new()
	_tab_bar.add_theme_constant_override("h_separation", 6)
	_tab_bar.add_theme_constant_override("v_separation", 6)
	_main.add_child(_tab_bar)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = str(t[1])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		var id: String = t[0]
		b.pressed.connect(func(): _select_tab(id))
		_tab_bar.add_child(b)
		_tab_buttons[id] = b
	_status = Label.new()
	_status.add_theme_color_override("font_color", UiTheme.HP_GREEN)
	_status.add_theme_font_size_override("font_size", 13)
	_main.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main.add_child(scroll)
	var wrap := HBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrap)
	var l := Control.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(l)
	_content_host = VBoxContainer.new()
	_content_host.add_theme_constant_override("separation", 12)
	_content_host.custom_minimum_size = Vector2(900, 0)
	wrap.add_child(_content_host)
	var r := Control.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(r)
	resized.connect(_fit_width)
	_fit_width()

func _fit_width() -> void:
	if _content_host != null:
		_content_host.custom_minimum_size.x = clampf(size.x - 40.0, 280.0, 980.0)

func _select_tab(id: String) -> void:
	_tab = id
	(_tab_buttons[id] as Button).set_pressed_no_signal(true)
	for ch in _content_host.get_children():
		ch.queue_free()
	match id:
		"general": AdminGeneral.build(_content_host, self)
		"chars": AdminChars.build(_content_host, self)
		"classes": AdminClasses.build(_content_host, self)
		"spells": AdminSpells.build(_content_host, self)
		"items": AdminItems.build(_content_host, self)
		"levels": AdminLevels.build(_content_host, self)

## Recharge l'onglet courant (après une modification qui change sa structure).
func refresh_tab() -> void:
	_select_tab(_tab)

func modals() -> Node:
	return _modal_layer

func say(text: String) -> void:
	_status.text = text

## Enregistre la configuration sur l'appareil.
func save() -> void:
	var t := Time.get_time_dict_from_system()
	say(("Configuration enregistrée à %02d:%02d:%02d." % [t.hour, t.minute, t.second]) if Data.save_config() else "Échec de l'enregistrement.")

func logout() -> void:
	_logout()

func _play_current() -> void:
	var go := func():
		Data.save_config()
		Data.launch(Data.config, "custom")
	Dialogs.confirm(_modal_layer, "Jouer ce donjon", "Commencer une partie avec le donjon actuellement configuré ?", go, "Commencer")
