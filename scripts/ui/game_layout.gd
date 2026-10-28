class_name GameLayout
extends MarginContainer
## Interface adaptative : paysage (vue 3D + colonne de panneaux à droite) ou portrait
## (vue 3D, cartes, panneaux en onglets). Les mêmes contrôles sont déplacés d'une disposition à l'autre.

signal command(cmd: String)
signal menu_pressed(name: String)
signal credits_pressed
signal monster_pressed(def: Dictionary, st: Dictionary)
signal item_quick(index: int)
signal item_pressed(index: int)
signal card_opened(char_id: String)
signal card_pressed(char_id: String)
signal chest_pressed(char_id: String)
signal potion_quick(idx: int)
signal scrolls_quick
signal inventory_pressed

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
var view_rule: ViewRule
var safe: Control      # partie de la vue non recouverte par les panneaux latéraux
var stage: Control
var popup_layer: Control
var message_label: Label
var level_label: Label
var compass: AtlasCompass
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
var panel_map: AtlasPanel
var panel_bag: AtlasPanel
var panel_log: AtlasPanel
var save_menu: SaveMenu      # « 💾 Sauvegarde ▾ » : hébergé par le menu du haut (`header`)
var _map_inset: Control
var _map_fold: Button
var map_box: VBoxContainer
static var map_folded := false   # carte repliée (état de la session : ne fait partie ni des sauvegardes ni des configurations)

var _root: Control
var footer: VBoxContainer
var _scroll: ScrollContainer
var _portrait: bool = false
var _compact: bool = false     # mobile (portrait, écran tactile ou fenêtre très basse) : la carte quitte l'écran
var _built_mode: int = -1
var _title: Label
var type_badge: Label
var ranked_timer: Label
var view_controls: HBoxContainer
var keys_panel: PanelContainer
var sound_panel: PanelContainer
var _comp: Control
var _vignette: TextureRect
var _ring: Panel
var _timer_track: ColorRect
var _timer_fill: ColorRect
var _was_combat: bool = false
var _flash: ColorRect
var pouch: VBoxContainer
var _pouch_sig: String = ""

var _building := false        # première construction pendant le chargement : le travail est réparti sur plusieurs images
var _in_rebuild := false

## Pendant le chargement, rend la main à l'écran de chargement (épée animée) entre deux gros morceaux de construction.
func _yield() -> void:
	if _building and Loader.is_active():
		await Loader.slice()

func setup(state: GameState, controller: CombatController, r: PlayerRig) -> void:
	clip_contents = true
	UiMetrics.update(self)
	gs = state
	ctrl = controller
	rig = r
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_building = true
	_build_parts()
	await _yield()
	resized.connect(_update_mode)
	await _update_mode()
	_building = false
	_update_mode()

# ------------------------------------------------------------------ pièces

## Boutons carrés 📊 ⌨️ 🔊 en haut à droite de la vue (« .sound-controls ») + panneaux déroulants Commandes / Son.
func _build_view_controls() -> void:
	view_controls = HBoxContainer.new()
	view_controls.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
	view_controls.anchor_left = 1.0
	view_controls.anchor_right = 1.0
	view_controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	view_controls.offset_top = UiMetrics.css(8.0)
	view_controls.offset_right = -UiMetrics.css(10.0)
	safe.add_child(view_controls)
	for n in [["Stats", "bars", L.t("ui.game_layout.statistiques_de_l_aventure")], ["Clavier", "keyboard", L.t("ui.game_layout.commandes_du_jeu")], ["Son", "sound", L.t("ui.game_layout.reglages_du_son")]]:
		var b := Button.new()
		b.icon = Atlas.icon(n[1], 18, Atlas.IVORY, 1.7)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = n[2]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = UiMetrics.design_size(Vector2(32, 32))
		Atlas.style_button(b, "", 2.0)
		var nn: String = n[0]
		b.pressed.connect(func(): _view_btn(nn))
		view_controls.add_child(b)
	_pause_btn = _pause_button()
	view_controls.add_child(_pause_btn)
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
	_keys_box = kv
	_rebuild_keys()
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

## Bouton « pause » (symbole dessiné, sans police) : fige le jeu pour une capture d'écran ; un clic, P ou Échap reprend.
func _pause_button() -> Button:
	var b := Button.new()
	b.tooltip_text = L.t("ui.pause.tip")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = UiMetrics.design_size(Vector2(32, 32))
	Atlas.style_button(b, "", 2.0)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(c)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", int(UiMetrics.css(4.0)))
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bars)
	for i in 2:
		var r := ColorRect.new()
		r.color = Color("e2d2b0")
		r.custom_minimum_size = Vector2(UiMetrics.css(4.0), UiMetrics.css(14.0))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(r)
	b.pressed.connect(func(): PauseOverlay.toggle(get_tree()))
	return b

var _keys_box: VBoxContainer
var _pause_btn: Button

## Lignes du mémo des commandes, d'après les touches réglées dans Paramètres › Commandes.
func _key_rows() -> Array:
	var move: Array = []
	var alt: Array = []
	for id in ["forward", "turn_left", "back", "turn_right"]:
		var sl := Keybinds.slots(id)
		if int(sl[0]) != 0:
			move.append(Keybinds.label(int(sl[0])))
		if int(sl[1]) != 0:
			alt.append(Keybinds.label(int(sl[1])))
	var move_txt := " ".join(move)
	if not alt.is_empty():
		move_txt += "  /  " + " ".join(alt)
	var spells: Array = []
	for i in range(2, 8):
		spells.append(Keybinds.text("slot_%d" % i))
	var spells_txt := "%s – %s" % [spells[0], spells[5]] if _slots_follow() else " ".join(spells)
	return [
		[move_txt if move_txt != "" else "—", "ui.game_layout.avancer_reculer_tourner"],
		[Keybinds.text("strafe_left") + "  " + Keybinds.text("strafe_right"), "ui.keys.strafe_both"],
		[Keybinds.text("attack"), "ui.game_layout.attaquer_heros_actif"],
		[Keybinds.text("interact"), "ui.keys.act_interact"],
		[Keybinds.text("flee"), "ui.keys.act_flee"],
		[Keybinds.text("slot_1"), "ui.game_layout.attaque_du_heros_actif"],
		[spells_txt, "ui.game_layout.sorts_du_heros_actif"],
		[Keybinds.text("inventory"), "ui.game_layout.inventaire_du_heros_selectionne"],
		[Keybinds.text("map"), "ui.game_layout.carte_en_plein_ecran"],
		["ui.game_layout.echap", "ui.game_layout.fermer_la_fenetre_ouverte"],
		["ui.game_layout.clic_sur_un_portrait", "ui.game_layout.choisir_le_heros_actif"],
		["ui.game_layout.icone_coffre_un_portrait", "ui.game_layout.ouvrir_l_inventaire_de_ce"],
		["ui.game_layout.molette_sur_la_carte", "ui.game_layout.zoomer_la_mini_carte"],
	]

## Les touches des sorts 2 à 7 se suivent (ex. 2 … 7) : on les résume « 2 – 7 ».
func _slots_follow() -> bool:
	var prev := -1
	for i in range(2, 8):
		var k := Keybinds.keys("slot_%d" % i)
		if k.size() != 1:
			return false
		if prev != -1 and int(k[0]) != prev + 1:
			return false
		prev = int(k[0])
	return true

## Onglets du mobile (Besace / Journal) au style Atlas : étiquettes en capitales fines, filet ambre sous l'onglet actif.
func _style_tabs_atlas(tabs: TabContainer) -> void:
	var mk := func(border: Color, lift: float) -> AtlasBox:
		var b := AtlasBox.new(UiMetrics.css(6.0))
		b.fill_top = Color("1f2521").lightened(lift)
		b.fill_bottom = Color("151a17").lightened(lift)
		b.border = border
		b.cut = 5.0
		b.corners = Vector4(1, 0, 0, 0)
		return b
	tabs.add_theme_stylebox_override("tab_selected", mk.call(Atlas.AMBER, 0.0))
	tabs.add_theme_stylebox_override("tab_unselected", mk.call(Atlas.COPPER_DIM, 0.0))
	tabs.add_theme_stylebox_override("tab_hovered", mk.call(Atlas.AMBER_DIM, 0.05))
	tabs.add_theme_stylebox_override("tab_focus", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_font_override("font", Atlas.title_font(false, 1))
	tabs.add_theme_font_size_override("font_size", int(UiMetrics.css(12.0)))
	tabs.add_theme_color_override("font_selected_color", Atlas.AMBER)
	tabs.add_theme_color_override("font_unselected_color", Atlas.IVORY)
	tabs.add_theme_color_override("font_hovered_color", Atlas.AMBER)

func _rebuild_keys() -> void:
	for ch in _keys_box.get_children().slice(1):   # le premier enfant est le titre
		_keys_box.remove_child(ch)
		ch.queue_free()
	for r in _key_rows():
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
		_keys_box.add_child(row)

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
	safe.add_child(p)
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
			if keys_panel.visible:
				_rebuild_keys()
		"Son":
			keys_panel.visible = false
			sound_panel.visible = not sound_panel.visible

func _small_atlas(b: Button) -> void:
	Atlas.style_button(b, "", 2.0)
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
	var vfb := AtlasBox.new(0.0)
	vfb.fill_top = Color("0a0c0b")
	vfb.fill_bottom = Color("0a0c0b")
	vfb.border = Color(0, 0, 0, 0)
	vfb.width = 0.0
	vfb.cut = 0.0
	frame.add_theme_stylebox_override("panel", vfb)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(200, 160)
	stage = Control.new()
	stage.clip_contents = true
	frame.add_child(stage)
	# zone « utile » de la vue : entre la colonne de la carte et celle de l'inventaire (la vue 3D, elle, prend toute la largeur)
	safe = Control.new()
	safe.name = "Safe"
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_container = SubViewportContainer.new()
	sub_container.stretch = true
	sub_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(sub_container)
	stage.add_child(safe)
	sub_viewport = SubViewport.new()
	sub_viewport.own_world_3d = true
	sub_viewport.handle_input_locally = false
	sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	sub_container.add_child(sub_viewport)
	world = Node3D.new()
	sub_viewport.add_child(world)

	# le nom du niveau vit dans l'en-tête (header.set_level) ; ici seulement la pastille du type de donjon et le minuteur classé
	level_label = Label.new()      # reçoit le nom du niveau (non affiché : l'en-tête le montre)
	var tb := AtlasBox.new(0.0)
	tb.fill_top = Color(Atlas.OBSIDIAN, 0.82)
	tb.fill_bottom = Color(Atlas.OBSIDIAN, 0.82)
	tb.border = Atlas.COPPER_DIM
	tb.cut = 4.0
	tb.content_margin_left = UiMetrics.css(9.0)
	tb.content_margin_right = UiMetrics.css(9.0)
	tb.content_margin_top = UiMetrics.css(3.0)
	tb.content_margin_bottom = UiMetrics.css(3.0)
	# pastille du type de donjon (haut gauche de la vue)
	type_badge = Label.new()
	type_badge.position = Vector2(UiMetrics.css(12.0), UiMetrics.css(10.0))
	type_badge.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_MED))
	type_badge.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.62)))
	type_badge.add_theme_color_override("font_color", Atlas.IVORY)
	type_badge.add_theme_stylebox_override("normal", tb)
	type_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(type_badge)
	# temps restant d'une partie classée (2 h maximum) : sous la pastille du type, visible seulement en partie classée
	ranked_timer = Label.new()
	ranked_timer.position = Vector2(UiMetrics.css(12.0), UiMetrics.css(36.0))
	ranked_timer.add_theme_font_override("font", Atlas.font(Atlas.F_BODY_BOLD))
	ranked_timer.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.78)))
	ranked_timer.add_theme_stylebox_override("normal", tb)
	ranked_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranked_timer.tooltip_text = L.t("ui.ranked.timer_tip")
	ranked_timer.visible = false
	safe.add_child(ranked_timer)

	# repère d'orientation (bas centre de la vue)
	compass = AtlasCompass.new()
	compass.anchor_left = 0.5
	compass.anchor_right = 0.5
	compass.anchor_top = 1.0
	compass.anchor_bottom = 1.0
	compass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	compass.grow_vertical = Control.GROW_DIRECTION_BEGIN
	compass.offset_bottom = -UiMetrics.css(8.0)
	safe.add_child(compass)
	_comp = compass

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
	safe.add_child(pouch)

	banner = CombatBanner.new()
	banner.setup(ctrl)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = 0
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.pressed.connect(func(d, s): monster_pressed.emit(d, s))
	safe.add_child(banner)

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
	safe.add_child(message_label)

	pad = TouchControls.new()
	pad.command.connect(func(c): command.emit(c))
	safe.add_child(pad)

	# mobile : bouton 🗺 sous le pouce (en bas à droite de la vue), ouvre la carte en plein écran ; un second appui la referme
	map_btn = Button.new()
	map_btn.text = "🗺"
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.tooltip_text = L.t("ui.game_layout.carte_en_plein_ecran_touche")
	map_btn.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
	map_btn.add_theme_color_override("font_color", Color("ffd98a"))
	Atlas.style_button(map_btn, "", 2.0)
	map_btn.pressed.connect(func(): menu_pressed.emit("Carte"))
	safe.add_child(map_btn)

	act_box = VBoxContainer.new()
	act_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_flee = Button.new()
	btn_flee.focus_mode = Control.FOCUS_NONE
	btn_flee.text = L.t("ui.atlas.flee")
	act_box.add_child(btn_flee)
	_style_flee()
	btn_flee.pressed.connect(func(): command.emit("flee"))
	safe.add_child(act_box)
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
	panel_map = AtlasPanel.new(L.t("common.carte"), "map")
	panel_map.name = "Carte"
	if panel_map.header_row != null:
		var north := MapFooter.North.new()
		panel_map.header_row.add_child(north)
		panel_map.header_row.move_child(north, 2)
		# bouton de repli à gauche, bouton « plein écran » à droite
		_map_fold = Button.new()
		_small_atlas(_map_fold)
		_map_fold.focus_mode = Control.FOCUS_NONE
		_map_fold.pressed.connect(func():
			map_folded = not map_folded
			_apply_map_fold())
		panel_map.header_row.add_child(_map_fold)
		var fb := Button.new()
		fb.icon = Atlas.icon("map", 16, Atlas.IVORY, 1.7)
		_small_atlas(fb)
		fb.focus_mode = Control.FOCUS_NONE
		fb.tooltip_text = L.t("ui.game_layout.carte_en_plein_ecran_touche")
		fb.pressed.connect(func(): menu_pressed.emit("Carte"))
		panel_map.header_row.add_child(fb)
		# « ‹ CARTE » : le bouton de repli passe devant le titre, sans cadre, comme sur la maquette
		panel_map.header_row.move_child(_map_fold, 0)
		panel_map.header_row.get_child(1).visible = false
		for b2 in [_map_fold, fb]:
			(b2 as Button).flat = true
			for stn in ["normal", "hover", "pressed", "focus", "disabled"]:
				(b2 as Button).add_theme_stylebox_override(stn, StyleBoxEmpty.new())
	var map_inset := MinimapWrap.new()
	_map_inset = map_inset
	minimap = Minimap.new()
	minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_inset.minimap = minimap
	map_inset.add_child(minimap)
	map_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_inset.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	map_box = VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 8)
	map_box.add_child(map_inset)
	map_box.add_child(MapLegend.new())
	var mfoot := MapFooter.new()
	mfoot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_box.add_child(mfoot)
	map_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_map.set_fill_alpha(0.95, 0.0)    # noir en haut, de plus en plus transparent vers le bas
	panel_map.body.add_child(map_box)
	_apply_map_fold()
	panel_bag = AtlasPanel.new(L.t("ui.atlas.inventory_title"), "chest")
	panel_bag.name = "Besace"
	bag = BagPanel.new()
	bag.setup(gs)
	bag.item_pressed.connect(func(i): item_pressed.emit(i))
	bag.item_quick.connect(func(i): item_quick.emit(i))
	bag.inventory_pressed.connect(func(): inventory_pressed.emit())
	panel_bag.body.add_child(bag)
	panel_log = AtlasPanel.new(L.t("ui.game_layout.grimoire_des_evenements"), "scroll")
	panel_log.name = "Journal"
	if panel_log.header_row != null:
		var lb := Button.new()
		lb.icon = Atlas.icon("scroll", 16, Atlas.IVORY, 1.7)
		_small_atlas(lb)
		lb.focus_mode = Control.FOCUS_NONE
		lb.tooltip_text = L.t("ui.game_layout.historique_complet_du_journal")
		lb.pressed.connect(func(): menu_pressed.emit("Journal"))
		panel_log.header_row.add_child(lb)
	log_panel = LogPanel.new()
	log_panel.setup(gs)
	panel_log.body.add_child(log_panel)
	# « 💾 Sauvegarde ▾ » : dans le menu du haut (plus de panneau dédié, la place va au grimoire)
	save_menu = SaveMenu.new()
	save_menu.slots_pressed.connect(func(): menu_pressed.emit("Slots"))
	save_menu.new_pressed.connect(func(): menu_pressed.emit("Nouveau"))
	save_menu.export_pressed.connect(func(): menu_pressed.emit("Exporter"))
	save_menu.import_pressed.connect(func(): menu_pressed.emit("Importer"))
	header.add_save_menu(save_menu)

## Carte repliée : il ne reste que son titre, le grimoire occupe la place libérée.
func _apply_map_fold() -> void:
	if map_box != null:
		map_box.visible = not map_folded
	if _map_fold != null:
		_map_fold.icon = Atlas.icon("chevron" if map_folded else "chevdown", 16, Atlas.IVORY, 1.8)
		_map_fold.tooltip_text = L.t("ui.game_layout.deplier_la_carte") if map_folded else L.t("ui.game_layout.replier_la_carte")

# ------------------------------------------------------------------ dispositions

func _update_mode() -> void:
	if _in_rebuild:
		return
	UiMetrics.update(self)
	var portrait := size.x < size.y * PORTRAIT_RATIO
	var win := get_window()
	var compact := portrait or Settings.is_mobile() or win.size.y < 520
	var mode := (1 if portrait else 0) + (2 if compact else 0)
	if mode != _built_mode:
		_built_mode = mode
		_compact = compact
		_portrait = portrait
		_in_rebuild = true
		await _rebuild()
		_in_rebuild = false
	_size_widgets()

func _detach(n: Node) -> void:
	if n != null and n.get_parent() != null:
		n.get_parent().remove_child(n)

func _rebuild() -> void:
	for n in [header, frame, queue, strip, hud, footer, panel_map, panel_bag, panel_log]:
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
		footer = VBoxContainer.new()
		footer.add_theme_constant_override("separation", 0)
		footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ver := Label.new()
		ver.text = L.t("common.editeur_de_donjon") + " " + AppVersion.label() + " · " + L.t("common.portage_godot")
		ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ver.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		ver.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
		ver.add_theme_color_override("font_color", Color("6f5e44"))
		ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_child(ver)
		# seule la mention « Made by … » ouvre la page de remerciements (bouton aussi large que son texte, pas toute la ligne)
		var made := Button.new()
		made.text = "Made by Claude & Nydaunvan"
		made.flat = true
		made.focus_mode = Control.FOCUS_NONE
		made.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		made.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		made.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY))
		made.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.6)))
		for st in ["normal", "hover", "pressed", "focus"]:
			made.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		made.add_theme_color_override("font_color", Color("6f5e44"))
		made.add_theme_color_override("font_hover_color", Color("c9a15a"))
		made.add_theme_color_override("font_pressed_color", Color("c9a15a"))
		made.pressed.connect(func(): credits_pressed.emit())
		footer.add_child(made)
	v.add_child(header)
	await _yield()
	if _portrait:
		frame.size_flags_stretch_ratio = 4.0
		v.add_child(frame)
		await _yield()
		v.add_child(queue)
		v.add_child(strip)
		await _yield()
		v.add_child(hud)
		await _yield()
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tabs.size_flags_stretch_ratio = 1.0
		tabs.custom_minimum_size = Vector2(0, 110)
		_style_tabs_atlas(tabs)
		v.add_child(tabs)
		# la carte quitte l'écran mobile (la vue 3D gagne la place) : le bouton 🗺 de la vue l'ouvre en plein écran
		panel_map.visible = false
		v.add_child(panel_map)
		for p in [panel_bag, panel_log]:
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
		var main := VBoxContainer.new()
		main.name = "Main"
		main.size_flags_vertical = Control.SIZE_EXPAND_FILL
		main.add_theme_constant_override("separation", int(UiMetrics.css(8.0)))
		v.add_child(main)
		# la vue 3D prend toute la largeur ; la carte (gauche) et l'inventaire / carnet (droite) sont posés par-dessus, fonds translucides
		var stack := Control.new()
		stack.name = "Stack"
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.add_child(stack)
		stack.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var over := HBoxContainer.new()
		over.name = "Over"
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(UiMetrics.css(30.0)))
		over.add_theme_constant_override("separation", 0)
		stack.add_child(over)
		view_rule = ViewRule.new()
		view_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(view_rule)
		stack.move_child(view_rule, over.get_index())
		var left := VBoxContainer.new()
		left.name = "Left"
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		left.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
		left.visible = not _compact
		over.add_child(left)
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		over.add_child(gap)
		var right := VBoxContainer.new()
		right.name = "Right"
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_theme_constant_override("separation", int(UiMetrics.css(12.0)))
		over.add_child(right)
		await _yield()
		# rangée du bas : file d'initiative + fiches des héros au centre, raccourcis sous la colonne de droite
		var bottom := HBoxContainer.new()
		bottom.name = "Bottom"
		bottom.add_theme_constant_override("separation", 0)
		main.add_child(bottom)
		var lpad := Control.new()
		lpad.name = "LPad"
		lpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lpad.visible = not _compact
		bottom.add_child(lpad)
		var center := VBoxContainer.new()
		center.name = "Center"
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.add_theme_constant_override("separation", int(UiMetrics.css(6.0)))
		bottom.add_child(center)
		# la file d'initiative n'agrandit plus la rangée du bas : elle s'affiche en bas de la vue pendant le combat, sous la barre de vie des monstres
		safe.add_child(queue)
		queue.anchor_left = 0.0
		queue.anchor_right = 1.0
		queue.anchor_top = 1.0
		queue.anchor_bottom = 1.0
		queue.grow_vertical = Control.GROW_DIRECTION_BEGIN
		queue.offset_left = 0.0
		queue.offset_right = 0.0
		queue.offset_bottom = -UiMetrics.css(14.0)     # au-dessus de la piste du chronomètre de tour
		center.add_child(hud)
		var rcol := VBoxContainer.new()
		rcol.name = "RCol"
		rcol.alignment = BoxContainer.ALIGNMENT_END
		bottom.add_child(rcol)
		var smargin := MarginContainer.new()
		smargin.add_theme_constant_override("margin_left", int(UiMetrics.css(28.0)))
		rcol.add_child(smargin)
		smargin.add_child(strip)
		var rpad := Control.new()
		rpad.name = "RPad"
		rpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom.add_child(rpad)
		await _yield()
		left.add_child(panel_map)
		right.add_child(panel_bag)
		right.add_child(panel_log)
		right.resized.connect(_sync_safe)
		left.resized.connect(_sync_safe)
		await _yield()
		panel_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for p in [panel_map, panel_bag, panel_log]:
			p.custom_minimum_size = Vector2(0, 0)
		# l'inventaire garde la taille de son contenu ; le carnet prend tout le reste de la colonne
		panel_bag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel_bag.size_flags_stretch_ratio = 1.0
		panel_log.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel_log.size_flags_stretch_ratio = 1.0
	v.add_child(footer)
	footer.visible = not _portrait
	call_deferred("_size_widgets")

## Un changement de thème se propage à tous les contrôles de l'interface : on ne l'émet que si la valeur change vraiment.
func _margin(item: String, v: int) -> void:
	if not has_theme_constant_override(item) or get_theme_constant(item) != v:
		add_theme_constant_override(item, v)

var _sig := ""    # dernière taille appliquée : on ne refait pas le calcul (≈ 20 ms) si rien n'a changé

func _size_widgets() -> void:
	var w := size.x
	var h := size.y
	if _root == null:
		return
	var sig := "%d|%d|%d|%d|%.3f|%d" % [roundi(w), roundi(h), 1 if _portrait else 0, 1 if _compact else 0, UiMetrics.s, get_instance_id() ^ _root.get_instance_id()]
	if sig == _sig:
		return
	_sig = sig
	var m_side := UiMetrics.css(0.0 if not _portrait else 6.0)
	_margin("margin_left", int(m_side))
	_margin("margin_right", int(m_side))
	_margin("margin_top", int(UiMetrics.css(6.0 if not _portrait else 4.0)))
	_margin("margin_bottom", int(UiMetrics.css(10.0 if not _portrait else 4.0)))
	var hh := clampf(h * 0.225, 120.0, 330.0)
	hud.custom_minimum_size = Vector2(0, PartyHud.wanted_height())
	queue.set_target_height(44.0 if _portrait else clampf(h * 0.066, 50.0, 62.0))
	header.rescale()
	var rw := UiMetrics.css(clampf(0.15 * w + 40.0, 235.0, 330.0))
	var lw := UiMetrics.css(clampf(0.125 * w + 12.0, 190.0, 250.0)) if not _compact else 0.0
	var gp := UiMetrics.css(10.0)
	var right: Node = _root.find_child("Right", true, false)
	if right:
		(right as Control).custom_minimum_size = Vector2(rw, 0)
		(right as Control).add_theme_constant_override("margin_right", 0)
	var left_col: Node = _root.find_child("Left", true, false)
	if left_col:
		(left_col as Control).custom_minimum_size = Vector2(lw, 0)
	var lpad: Node = _root.find_child("LPad", true, false)
	if lpad:
		(lpad as Control).custom_minimum_size = Vector2(UiMetrics.css(30.0), 0)    # les fiches des héros s'étendent sous la carte
	if bag != null and not _portrait:
		bag.set_avail(rw - UiMetrics.css(36.0))
	if panel_log != null and not _portrait:
		panel_log.custom_minimum_size = Vector2(0, clampf(h * 0.24, 130.0, 260.0))
	var rcol: Node = _root.find_child("RCol", true, false)
	if rcol:
		(rcol as Control).custom_minimum_size = Vector2(rw + gp, 0)
		var rpad: Node = _root.find_child("RPad", true, false)
		if rpad:
			(rpad as Control).custom_minimum_size = Vector2(UiMetrics.css(30.0), 0)
	var ins := UiMetrics.css(30.0)
	if view_rule != null:
		view_rule.step_x = (lw + gp + ins) if (not _portrait and not _compact) else 0.0
		view_rule.step_h = UiMetrics.css(14.0)
		view_rule.queue_redraw()
	if not _portrait:
		safe.offset_left = lw + gp + ins
		safe.offset_right = -(rw + gp + ins)
	else:
		safe.offset_left = 0.0
		safe.offset_right = 0.0
	_size_overlays()
	call_deferred("_sync_safe")

## La zone utile de la vue suit les colonnes réellement affichées (leur largeur peut dépasser le minimum demandé).
func _sync_safe() -> void:
	if _root == null or safe == null or _portrait:
		return
	var left_col := _root.find_child("Left", true, false) as Control
	var right := _root.find_child("Right", true, false) as Control
	var st := safe.get_parent() as Control
	if st == null or right == null or left_col == null:
		return
	var gp := UiMetrics.css(10.0)
	var l := (left_col.global_position.x + left_col.size.x - st.global_position.x) + gp if left_col.visible else UiMetrics.css(30.0)
	var r := (st.global_position.x + st.size.x - right.global_position.x) + gp
	safe.offset_left = l
	safe.offset_right = -r
	var rcol := _root.find_child("RCol", true, false) as Control
	if rcol != null:
		rcol.custom_minimum_size.x = maxf(rcol.custom_minimum_size.x, right.size.x + gp)

func _size_overlays() -> void:
	pad.rescale()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, int(UiMetrics.css(12.0)))
	act_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(UiMetrics.css(12.0)))
	if not _portrait:
		act_box.offset_top -= UiMetrics.css(64.0)
		act_box.offset_bottom -= UiMetrics.css(64.0)
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

## Minuteur de partie classée : `text` vide = masqué.
func set_ranked_timer(text: String, color: Color) -> void:
	if ranked_timer == null:
		return
	ranked_timer.visible = text != ""
	ranked_timer.text = text
	ranked_timer.add_theme_color_override("font_color", color)

func set_level_name(text: String) -> void:
	level_label.text = text
	header.set_level(L.fa(L.t("ui.atlas.level_n"), gs.level_index + 1), str(gs.cfg.get("title", "")) if str(gs.cfg.get("title", "")) != "" else text)
	if type_badge != null:
		type_badge.text = {"original": "🏰 Donjon d'Origine", "custom": L.t("common.donjon_personnalise")}.get(Data.play_origin, RankedRun.mode_label(gs.cfg))

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
	Atlas.style_button(btn_flee, "danger", 8.0)
	btn_flee.add_theme_font_override("font", Atlas.title_font(true, 2))
	btn_flee.add_theme_font_size_override("font_size", int(UiMetrics.rem(0.8)))
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
		save_menu.modulate = Color(0.62, 0.62, 0.62, 0.4) if on else Color.WHITE
	pad.visible = not on
	map_btn.visible = _compact and not on
	_comp.visible = not on
	for vb in view_controls.get_children():      # la pause reste accessible en combat
		if vb != _pause_btn:
			vb.visible = not on
	if on:
		keys_panel.visible = false
		sound_panel.visible = false
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
		compass.dir = rig.dir
		compass.visible = not ctrl.in_combat()
