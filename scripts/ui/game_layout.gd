class_name GameLayout
extends MarginContainer
## Interface adaptative : paysage (vue 3D + colonne de panneaux à droite) ou portrait
## (vue 3D, cartes, panneaux en onglets). Les mêmes contrôles sont déplacés d'une disposition à l'autre.

signal command(cmd: String)
signal menu_pressed(name: String)
signal monster_pressed(def: Dictionary, st: Dictionary)
signal item_pressed(index: int)
signal card_opened(char_id: String)
signal card_pressed(char_id: String)
signal chest_pressed(char_id: String)
signal potion_quick(idx: int)
signal scrolls_quick

const PORTRAIT_RATIO := 1.05   # largeur / hauteur en dessous : mode portrait

var gs: GameState
var ctrl: CombatController
var rig: PlayerRig

# monde 3D
var world: Node3D
var sub_viewport: SubViewport
var sub_container: SubViewportContainer
# éléments partagés
var header: AppHeader
var frame: PanelContainer
var stage: Control
var popup_layer: Control
var message_label: Label
var level_label: Label
var compass_letters: Array[Label] = []
var pad: TouchControls
var map_btn: Button
var act_box: VBoxContainer
var btn_flee: Button
var queue: QueueBar
var banner: CombatBanner
var fx_layer: FxLayer
var strip: PanelContainer
var spell_bar: SpellBar
var hud: PartyHud
var minimap: Minimap
var bag: BagPanel
var log_panel: LogPanel
var panel_map: OrnatePanel
var panel_bag: OrnatePanel
var panel_log: OrnatePanel
var panel_menu: OrnatePanel
var save_menu: SaveMenu

var _root: Control
var footer: Label
var _scroll: ScrollContainer
var _portrait: bool = false
var _compact: bool = false     # mobile (portrait, écran tactile ou fenêtre très basse) : la carte quitte l'écran
var _built_mode: int = -1
var _title: Label
var type_badge: Label
var view_controls: HBoxContainer
var keys_panel: PanelContainer
var sound_panel: PanelContainer
var _comp: Control
var _plaque_lvl: Control
var _vignette: TextureRect
var _ring: Panel
var _timer_track: ColorRect
var _timer_fill: ColorRect
var _was_combat: bool = false
var _flash: ColorRect
var pouch: VBoxContainer
var _pouch_sig: String = ""

func setup(state: GameState, controller: CombatController, r: PlayerRig) -> void:
	clip_contents = true
	UiMetrics.update(self)
	gs = state
	ctrl = controller
	rig = r
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_parts()
	resized.connect(_update_mode)
	_update_mode()

# ------------------------------------------------------------------ pièces

func _plaque(text: String, font_size: float = 12.6) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := FrameBox.new(8.0, Vector4(2, 0, 2, 0), Color("140f0b"))
	fb.inner_shadow = 0.0
	p.add_theme_stylebox_override("panel", fb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	l.add_theme_font_size_override("font_size", int(UiMetrics.css(font_size)))
	l.add_theme_color_override("font_color", Color("d9b56e"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## Boutons carrés 📊 ⌨️ 🔊 en haut à droite de la vue (« .sound-controls ») + panneaux déroulants Commandes / Son.
func _build_view_controls() -> void:
	view_controls = HBoxContainer.new()
	view_controls.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
	view_controls.anchor_left = 1.0
	view_controls.anchor_right = 1.0
	view_controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_controls.offset_top = UiMetrics.css(8.0)
	view_controls.offset_right = -UiMetrics.css(10.0)
	stage.add_child(view_controls)
	for n in [["Stats", "📊", L.t("ui.game_layout.statistiques_de_l_aventure")], ["Clavier", "⌨️", L.t("ui.game_layout.commandes_du_jeu")], ["Son", "🔊", L.t("ui.game_layout.reglages_du_son")]]:
		var b := Button.new()
		b.text = n[1]
		b.tooltip_text = n[2]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = UiMetrics.design_size(Vector2(32, 32))
		b.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		b.add_theme_font_size_override("font_size", int(UiMetrics.rem(1.05)))
		b.add_theme_color_override("font_color", Color("e2d2b0"))
		var ist := IronBox.button_styles()
		for k in ist:
			b.add_theme_stylebox_override(k, ist[k])
		var nn: String = n[0]
		b.pressed.connect(func(): _view_btn(nn))
		view_controls.add_child(b)
	# panneau Commandes
	keys_panel = _drop_panel(190.0 if false else 310.0)
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", int(UiMetrics.css(3.0)))
	keys_panel.add_child(kv)
	var kt := Label.new()
	kt.text = L.t("ui.game_layout.commandes")
	kt.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	kt.add_theme_font_size_override("font_size", int(UiMetrics.css(12.5)))
	kt.add_theme_color_override("font_color", Color("ffd98a"))
	kv.add_child(kt)
	for r in KEY_COMMANDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
		var k := Label.new()
		k.text = r[0]
		k.custom_minimum_size.x = UiMetrics.css(110.0)
		k.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_BOLD))
		k.add_theme_font_size_override("font_size", int(UiMetrics.css(11.5)))
		k.add_theme_color_override("font_color", Color("e8d9b5"))
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var d := Label.new()
		d.text = r[1]
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		d.add_theme_font_size_override("font_size", int(UiMetrics.css(11.5)))
		d.add_theme_color_override("font_color", Color("b9a880"))
		row.add_child(k)
		row.add_child(d)
		kv.add_child(row)
	# panneau Son
	sound_panel = _drop_panel(190.0)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", int(UiMetrics.css(2.0)))
	sound_panel.add_child(sv)
	var mute := CheckBox.new()
	mute.text = L.t("ui.game_layout.couper_tout_le_son")
	mute.button_pressed = not Sound.enabled
	mute.add_theme_font_size_override("font_size", int(UiMetrics.css(11.0)))
	mute.toggled.connect(func(v: bool): Sound.set_enabled(not v))
	sv.add_child(mute)
	for cfg in [[L.t("ui.game_layout.effets_sonores"), Sound.sfx_volume, "sfx"], [L.t("ui.game_layout.musique_ambiance"), Sound.music_volume, "music"]]:
		var lab := Label.new()
		lab.text = cfg[0]
		lab.add_theme_font_size_override("font_size", int(UiMetrics.css(10.9)))
		lab.add_theme_color_override("font_color", Color("b9a880"))
		sv.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = cfg[1]
		var which: String = cfg[2]
		sl.value_changed.connect(func(v: float):
			if which == "sfx":
				Sound.set_sfx_volume(v)
			else:
				Sound.set_music_volume(v))
		sv.add_child(sl)

const KEY_COMMANDS := [
	["↑ ↓ ← →  /  Z Q S D", "ui.game_layout.avancer_reculer_tourner"],
	["Espace", "ui.game_layout.attaquer_heros_actif"],
	["1", "ui.game_layout.attaque_du_heros_actif"],
	["2 – 7", "ui.game_layout.sorts_du_heros_actif"],
	["I", "ui.game_layout.inventaire_du_heros_selectionne"],
	["M", "ui.game_layout.carte_en_plein_ecran"],
	["ui.game_layout.echap", "ui.game_layout.fermer_la_fenetre_ouverte"],
	["ui.game_layout.clic_sur_un_portrait", "ui.game_layout.choisir_le_heros_actif"],
	["ui.game_layout.icone_coffre_un_portrait", "ui.game_layout.ouvrir_l_inventaire_de_ce"],
	["ui.game_layout.molette_sur_la_carte", "ui.game_layout.zoomer_la_mini_carte"],
]

func _drop_panel(w: float) -> PanelContainer:
	var p := PanelContainer.new()
	var fb := FrameBox.new(8.0, Vector4(4, 2, 4, 2), Color("140f0b"))
	fb.inner_shadow = 0.0
	p.add_theme_stylebox_override("panel", fb)
	p.custom_minimum_size.x = UiMetrics.css(w)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_top = UiMetrics.css(8.0 + 32.0 + 6.0)
	p.offset_right = -UiMetrics.css(10.0)
	p.z_index = 10
	p.visible = false
	stage.add_child(p)
	return p

func _view_btn(n: String) -> void:
	match n:
		"Stats":
			keys_panel.visible = false
			sound_panel.visible = false
			menu_pressed.emit("Stats")
		"Clavier":
			sound_panel.visible = false
			keys_panel.visible = not keys_panel.visible
		"Son":
			keys_panel.visible = false
			sound_panel.visible = not sound_panel.visible

func _small_iron(b: Button) -> void:
	var st := IronBox.button_styles()
	for k in st:
		(st[k] as IronBox).rivets = false
		b.add_theme_stylebox_override(k, st[k])
	b.custom_minimum_size = UiMetrics.design_size(Vector2(26, 26))
	b.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _build_parts() -> void:
	# en-tête (partagé avec l'accueil)
	header = AppHeader.new()
	header.nav.connect(func(n: String): menu_pressed.emit(n))
	_title = header.title_label

	# cadre de la vue 3D
	frame = PanelContainer.new()
	var vfb := FrameBox.new(24.0, Vector4(0, 0, 0, 0), Color("0a0705"))
	vfb.use_grime = false
	vfb.inner_shadow = 0.0
	frame.add_theme_stylebox_override("panel", vfb)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(200, 160)
	stage = Control.new()
	stage.clip_contents = true
	frame.add_child(stage)
	sub_container = SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sub_container)
	sub_viewport = SubViewport.new()
	sub_viewport.own_world_3d = true
	sub_viewport.handle_input_locally = false
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_container.add_child(sub_viewport)
	world = Node3D.new()
	sub_viewport.add_child(world)

	# plaque du niveau (haut gauche)
	var lp := _plaque("")
	lp.position = Vector2(UiMetrics.css(8.0), UiMetrics.css(6.0))
	level_label = lp.get_child(0) as Label
	stage.add_child(lp)
	_plaque_lvl = lp
	# pastille du type de donjon sous la plaque du niveau (.dungeon-type-badge)
	type_badge = Label.new()
	type_badge.position = Vector2(UiMetrics.css(12.0), UiMetrics.css(48.0))
	type_badge.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	type_badge.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
	type_badge.add_theme_color_override("font_color", Color("ffd88a"))
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.03, 0.02, 0.01, 0.72)
	tb.border_color = Color("070504")
	tb.set_border_width_all(maxi(1, roundi(UiMetrics.css(1.0))))
	tb.content_margin_left = UiMetrics.css(8.0)
	tb.content_margin_right = UiMetrics.css(8.0)
	tb.content_margin_top = UiMetrics.css(2.0)
	tb.content_margin_bottom = UiMetrics.css(2.0)
	type_badge.add_theme_stylebox_override("normal", tb)
	type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(type_badge)

	# boussole (haut centre) : N E ☠ S O, la direction actuelle est en or
	var comp := PanelContainer.new()
	comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfb := FrameBox.new(8.0, Vector4(8, 0, 8, 0), Color("140f0b"))
	cfb.inner_shadow = 0.0
	comp.add_theme_stylebox_override("panel", cfb)
	comp.anchor_left = 0.5
	comp.anchor_right = 0.5
	comp.offset_top = UiMetrics.css(6.0)
	comp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	comp.add_child(crow)
	var letters := ["N", "E", "☠", "S", "O"]
	for l in letters:
		if l == "☠":
			var sk := TextureRect.new()
			sk.texture = UiTheme.tex("medallion")
			sk.custom_minimum_size = UiMetrics.design_size(Vector2(22, 22))
			sk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			crow.add_child(sk)
			continue
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
		lb.add_theme_font_size_override("font_size", int(UiMetrics.css(12.0)))
		crow.add_child(lb)
		compass_letters.append(lb)
	stage.add_child(comp)
	_comp = comp

	# file d'initiative : chaîne sous la vue 3D (placée par _rebuild)
	queue = QueueBar.new()
	queue.setup(gs, ctrl)

	# lueur rouge en bord de vue pendant le combat
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.05, 0.03, 0.0), Color(0.75, 0.05, 0.03, 0.0), Color(0.75, 0.05, 0.03, 0.42)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.85)
	gt.width = 256
	gt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = gt
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	stage.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.12, 0.08, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_flash)
	_ring = Panel.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = Color(0.75, 0.29, 0.2, 0.85)
	rs.set_border_width_all(maxi(2, roundi(UiMetrics.css(3.0))))
	_ring.add_theme_stylebox_override("panel", rs)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	stage.add_child(_ring)
	# piste du chronomètre de tour (bas de la vue)
	_timer_track = ColorRect.new()
	_timer_track.color = Color(0, 0, 0, 0.55)
	_timer_track.anchor_top = 1.0
	_timer_track.anchor_bottom = 1.0
	_timer_track.anchor_right = 1.0
	_timer_track.offset_top = -7
	_timer_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_track.visible = false
	_timer_fill = ColorRect.new()
	_timer_fill.color = Color("e8b45c")
	_timer_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timer_fill.anchor_right = 1.0
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_track.add_child(_timer_fill)
	stage.add_child(_timer_track)

	# barre rapide potions / parchemins (combat)
	pouch = VBoxContainer.new()
	pouch.add_theme_constant_override("separation", 8)
	pouch.anchor_left = 0.0
	pouch.anchor_right = 0.0
	pouch.anchor_top = 0.5
	pouch.anchor_bottom = 0.5
	pouch.offset_left = 12
	pouch.offset_right = 62
	pouch.offset_top = 0
	pouch.offset_bottom = 0
	pouch.grow_horizontal = Control.GROW_DIRECTION_END
	pouch.grow_vertical = Control.GROW_DIRECTION_BOTH
	pouch.visible = false
	stage.add_child(pouch)

	banner = CombatBanner.new()
	banner.setup(ctrl)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = 0
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.pressed.connect(func(d, s): monster_pressed.emit(d, s))
	stage.add_child(banner)

	fx_layer = FxLayer.new()
	stage.add_child(fx_layer)
	_build_view_controls()

	popup_layer = Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(popup_layer)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message_label.offset_top = 90
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE))
	message_label.add_theme_font_size_override("font_size", 22)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.modulate.a = 0.0
	stage.add_child(message_label)

	pad = TouchControls.new()
	pad.command.connect(func(c): command.emit(c))
	stage.add_child(pad)

	# mobile : bouton 🗺 sous le pouce (en bas à droite de la vue), ouvre la carte en plein écran ; un second appui la referme
	map_btn = Button.new()
	map_btn.text = "🗺"
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.tooltip_text = L.t("ui.game_layout.carte_en_plein_ecran_touche")
	map_btn.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	map_btn.add_theme_color_override("font_color", Color("ffd98a"))
	var mst := IronBox.button_styles()
	for k in mst:
		map_btn.add_theme_stylebox_override(k, mst[k])
	map_btn.pressed.connect(func(): menu_pressed.emit("Carte"))
	stage.add_child(map_btn)

	act_box = VBoxContainer.new()
	act_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_flee = Button.new()
	btn_flee.focus_mode = Control.FOCUS_NONE
	btn_flee.text = "🏃 FUITE"
	act_box.add_child(btn_flee)
	_style_flee()
	btn_flee.pressed.connect(func(): command.emit("flee"))
	stage.add_child(act_box)
	frame.resized.connect(_size_overlays)

	# bandeau des sorts + rail, puis cartes
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	spell_bar = SpellBar.new()
	spell_bar.setup(gs, ctrl)
	spell_bar.attack_pressed.connect(func(): command.emit("attack"))
	spell_bar.spell_pressed.connect(func(id): ctrl.cast(id))
	strip.add_child(spell_bar)
	hud = PartyHud.new()
	hud.setup(gs, ctrl)
	hud.card_pressed.connect(func(id): card_pressed.emit(id))
	hud.card_opened.connect(func(id): card_opened.emit(id))
	hud.chest_pressed.connect(func(id): chest_pressed.emit(id))

	# panneaux latéraux
	panel_map = OrnatePanel.new(L.t("common.carte"))
	panel_map.name = "Carte"
	if panel_map.header_row != null:
		var fb := Button.new()
		fb.text = "🗺️"
		_small_iron(fb)
		fb.focus_mode = Control.FOCUS_NONE
		fb.tooltip_text = L.t("ui.game_layout.carte_en_plein_ecran_touche")
		fb.pressed.connect(func(): menu_pressed.emit("Carte"))
		panel_map.header_row.add_child(fb)
	var map_inset := MinimapWrap.new()
	minimap = Minimap.new()
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_inset.minimap = minimap
	map_inset.add_child(minimap)
	panel_map.body.add_child(map_inset)
	map_inset.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel_bag = OrnatePanel.new(L.t("ui.game_layout.besace_commune_du_groupe"))
	panel_bag.name = "Besace"
	bag = BagPanel.new()
	bag.setup(gs)
	bag.item_pressed.connect(func(i): item_pressed.emit(i))
	panel_bag.body.add_child(bag)
	panel_log = OrnatePanel.new(L.t("ui.game_layout.grimoire_des_evenements"))
	panel_log.name = "Journal"
	if panel_log.header_row != null:
		var lb := Button.new()
		lb.text = "📖"
		_small_iron(lb)
		lb.focus_mode = Control.FOCUS_NONE
		lb.tooltip_text = L.t("ui.game_layout.historique_complet_du_journal")
		lb.pressed.connect(func(): menu_pressed.emit("Journal"))
		panel_log.header_row.add_child(lb)
	log_panel = LogPanel.new()
	log_panel.setup(gs)
	panel_log.body.add_child(log_panel)
	panel_menu = OrnatePanel.new("")
	panel_menu.name = "Menu"
	save_menu = SaveMenu.new()
	save_menu.slots_pressed.connect(func(): menu_pressed.emit("Slots"))
	save_menu.new_pressed.connect(func(): menu_pressed.emit("Nouveau"))
	save_menu.export_pressed.connect(func(): menu_pressed.emit("Exporter"))
	save_menu.import_pressed.connect(func(): menu_pressed.emit("Importer"))
	panel_menu.body.add_child(save_menu)

# ------------------------------------------------------------------ dispositions

func _update_mode() -> void:
	UiMetrics.update(self)
	var portrait := size.x < size.y * PORTRAIT_RATIO
	var win := get_window()
	var compact := portrait or Settings.is_mobile() or win.size.y < 520
	var mode := (1 if portrait else 0) + (2 if compact else 0)
	if mode != _built_mode:
		_built_mode = mode
		_compact = compact
		_portrait = portrait
		_rebuild()
	_size_widgets()

func _detach(n: Node) -> void:
	if n != null and n.get_parent() != null:
		n.get_parent().remove_child(n)

func _rebuild() -> void:
	for n in [header, frame, queue, strip, hud, footer, panel_map, panel_bag, panel_log, panel_menu]:
		_detach(n)
	if _root != null:
		_root.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UiMetrics.css(10.0)))
	_root = v
	if _scroll == null:
		# si l'écran est trop bas pour tout afficher (comme la page de l'original), l'interface défile verticalement
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_scroll)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(v)
	if footer == null:
		footer = Label.new()
		footer.text = L.t("common.editeur_de_donjon") + " v1.29 · " + L.t("common.portage_godot") + "\nMade by Claude & Nydaunvan"
		footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		footer.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
		footer.add_theme_color_override("font_color", Color("6f5e44"))
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(header)
	if _portrait:
		frame.size_flags_stretch_ratio = 4.0
		v.add_child(frame)
		v.add_child(queue)
		v.add_child(strip)
		v.add_child(hud)
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tabs.size_flags_stretch_ratio = 1.0
		tabs.custom_minimum_size = Vector2(0, 110)
		v.add_child(tabs)
		# la carte quitte l'écran mobile (la vue 3D gagne la place) : le bouton 🗺 de la vue l'ouvre en plein écran
		panel_map.visible = false
		v.add_child(panel_map)
		for p in [panel_bag, panel_log, panel_menu]:
			# chaque onglet défile s'il manque de place : la vue 3D garde le plus de hauteur possible
			var sc := ScrollContainer.new()
			sc.name = p.name
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.add_child(p)
			tabs.add_child(sc)
	else:
		panel_map.visible = not _compact
		frame.size_flags_stretch_ratio = 1.0
		var h := HBoxContainer.new()
		h.name = "Main"
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", int(UiMetrics.css(14.0)))
		v.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
		h.add_child(left)
		left.add_child(frame)
		left.add_child(queue)
		left.add_child(strip)
		left.add_child(hud)
		var right := VBoxContainer.new()
		right.name = "Right"
		right.add_theme_constant_override("separation", int(UiMetrics.css(18.0)))
		var spc := Control.new()
		spc.custom_minimum_size = Vector2(0, 0)
		right.add_child(spc)
		for pm in [panel_map, panel_bag, panel_log]:
			pm.medal = true
		panel_log.hooks = true
		panel_bag.hooks = true
		panel_menu.hooks = true
		h.add_child(right)
		for p in [panel_map, panel_bag, panel_log, panel_menu]:
			right.add_child(p)
		panel_map.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for p in [panel_map, panel_bag, panel_log]:
			p.custom_minimum_size = Vector2(0, 0)
		panel_bag.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_bag.size_flags_stretch_ratio = 1.5
		panel_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel_log.size_flags_stretch_ratio = 1.0
		panel_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.add_child(footer)
	footer.visible = not _portrait
	call_deferred("_size_widgets")

func _size_widgets() -> void:
	var w := size.x
	var h := size.y
	if _root == null:
		return
	var m_side := UiMetrics.css(30.0 if not _portrait else 6.0)
	add_theme_constant_override("margin_left", int(m_side))
	add_theme_constant_override("margin_right", int(m_side))
	add_theme_constant_override("margin_top", int(UiMetrics.css(12.0 if not _portrait else 4.0)))
	add_theme_constant_override("margin_bottom", int(UiMetrics.css(10.0 if not _portrait else 4.0)))
	var hh := clampf(h * 0.225, 120.0, 330.0)
	hud.custom_minimum_size = Vector2(0, PartyHud.wanted_height())
	queue.set_target_height(44.0 if _portrait else clampf(h * 0.08, 36.0, 70.0))
	header.rescale()
	var right: Node = _root.get_node_or_null("Main/Right")
	if right:
		var wreal := w
		(right as Control).custom_minimum_size = Vector2(UiMetrics.css(clampf(0.175 * wreal + 56.0, 260.0, 460.0)), 0)
	_size_overlays()

func _size_overlays() -> void:
	pad.rescale()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, int(UiMetrics.css(12.0)))
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(UiMetrics.css(12.0)))
	# boussole : en haut au centre en paysage ; sur mobile elle descend au bas de la vue (le haut est pris par la plaque et les boutons)
	if _comp != null:
		_comp.anchor_top = 1.0 if _portrait else 0.0
		_comp.anchor_bottom = 1.0 if _portrait else 0.0
		_comp.grow_vertical = Control.GROW_DIRECTION_BEGIN if _portrait else Control.GROW_DIRECTION_END
		_comp.offset_top = -UiMetrics.css(10.0) if _portrait else UiMetrics.css(6.0)
		_comp.offset_bottom = -UiMetrics.css(10.0) if _portrait else UiMetrics.css(6.0)
	var mb := UiMetrics.css(46.0)
	map_btn.custom_minimum_size = Vector2(mb, mb)
	map_btn.add_theme_font_size_override("font_size", int(mb * 0.55))
	var mm := UiMetrics.css(12.0)
	map_btn.anchor_left = 1.0
	map_btn.anchor_right = 1.0
	map_btn.anchor_top = 1.0
	map_btn.anchor_bottom = 1.0
	map_btn.offset_right = -mm
	map_btn.offset_left = -mm - mb
	map_btn.offset_bottom = -mm
	map_btn.offset_top = -mm - mb

# ------------------------------------------------------------------ mises à jour

func set_level_name(text: String) -> void:
	level_label.text = text
	if type_badge != null:
		type_badge.text = {"original": "🏰 Donjon d'Origine", "custom": L.t("common.donjon_personnalise")}.get(Data.play_origin, L.t("common.donjon_aleatoire"))

func _refresh_pouch(on: bool) -> void:
	var potions: Array = []
	var scrolls := 0
	if on:
		for i in gs.inventory.size():
			var it: Dictionary = gs.inventory[i]
			var t := str(it.get("type", ""))
			if t == "potion":
				var key := "%s|%d|%d" % [it.get("name", ""), int(it.get("heal", 0)), int(it.get("staminaRestore", 0))]
				var hit := false
				for g in potions:
					if g.key == key:
						g.count += 1
						hit = true
						break
				if not hit:
					potions.append({"key": key, "it": it, "idx": i, "count": 1})
			elif t == "scroll":
				scrolls += 1
	var sig := str(on) + "|" + str(potions.map(func(g): return "%s%d" % [g.key, g.count])) + "|" + str(scrolls)
	if sig == _pouch_sig:
		return
	_pouch_sig = sig
	for c in pouch.get_children():
		c.queue_free()
	pouch.visible = on and (not potions.is_empty() or scrolls > 0)
	for g in potions:
		var it2: Dictionary = g.it
		var detail := L.fa(L.t("ui.game_layout.pv"), int(it2.heal)) if int(it2.get("heal", 0)) > 0 else (L.fa(L.t("ui.game_layout.end"), int(it2.get("staminaRestore", 0))) if int(it2.get("staminaRestore", 0)) > 0 else "")
		var idx: int = g.idx
		pouch.add_child(_pouch_button(IconResolver.texture(str(it2.get("icon", ""))), "🧪", detail, int(g.count), str(it2.get("name", "")), func(): potion_quick.emit(idx)))
	if scrolls > 0:
		pouch.add_child(_pouch_button(null, "📜", L.t("common.parchemins"), scrolls, L.t("common.parchemins"), func(): scrolls_quick.emit()))

func _pouch_button(tex: Texture2D, glyph: String, detail: String, count: int, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(64, 46)
	b.add_theme_font_size_override("font_size", 11)
	b.text = "" if tex != null else glyph
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 26)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.text = detail if tex != null else glyph + "\n" + detail
	b.pressed.connect(cb)
	if count > 1:
		var l := Label.new()
		l.text = "×%d" % count
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("1a1108"))
		var bs := UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 9)
		bs.content_margin_left = 5
		bs.content_margin_right = 5
		bs.content_margin_top = 0
		bs.content_margin_bottom = 0
		l.add_theme_stylebox_override("normal", bs)
		l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		l.offset_right = 6
		l.offset_top = -7
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	return b

func _style_flee() -> void:
	var st := IronBox.button_styles(Color("d0452e"), "flee")
	for k in st:
		btn_flee.add_theme_stylebox_override(k, st[k])
	btn_flee.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	btn_flee.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.85)))
	btn_flee.add_theme_color_override("font_color", Color("f0c9a0"))
	btn_flee.add_theme_color_override("font_hover_color", Color("ffe0b8"))
	btn_flee.custom_minimum_size = Vector2(UiMetrics.css(130.0), UiMetrics.css(40.0))

func _process(_d: float) -> void:
	var on := ctrl != null and ctrl.in_combat()
	if on != _was_combat:
		_was_combat = on
		if on:
			_flash.color.a = 0.55
			create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	_refresh_pouch(on)
	if save_menu != null:
		# `#viewPlay.in-combat .save-menu-panel{opacity:.4;pointer-events:none;filter:grayscale(1)}` : sauvegarde indisponible en combat
		save_menu.locked = on
		panel_menu.modulate = Color(0.62, 0.62, 0.62, 0.4) if on else Color.WHITE
	pad.visible = not on
	map_btn.visible = _compact and not on
	_comp.visible = not on
	view_controls.visible = not on
	if on:
		keys_panel.visible = false
		sound_panel.visible = false
	_plaque_lvl.visible = not on
	type_badge.visible = not on
	btn_flee.visible = on
	_vignette.visible = on
	_ring.visible = on
	var tf := ctrl.turn_timer_fraction() if on else -1.0
	_timer_track.visible = tf >= 0.0
	if on:
		_timer_fill.anchor_right = clampf(tf, 0.0, 1.0)
		_timer_fill.color = Color("e8b45c") if tf > 0.3 else Color("d8452e")
		_vignette.modulate.a = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 400.0)
	if rig != null:
		for i in compass_letters.size():
			# ordre affiché : N E S O = directions 0 1 2 3
			compass_letters[i].add_theme_color_override("font_color", UiTheme.GOLD if i == rig.dir else Color("6f5e44"))
