class_name PartyHud
extends Control
## Cartes de l'équipe en bandeaux compacts : portrait rond, nom, classe, niveau, PV / endurance / XP, jauge de tour en combat.
## Au survol : stats, XP exacte, statuts et équipement. Cliquer une carte = choisir le personnage / la cible d'un sort.
## En portrait (mobile), les cartes se rangent en grille 2 × 2.

signal card_pressed(char_id: String)
signal card_opened(char_id: String)
signal chest_pressed(char_id: String)

var gs: GameState
var ctrl: CombatController
var _cards: Dictionary = {}

func setup(state: GameState, controller: CombatController) -> void:
	gs = state
	ctrl = controller
	clip_contents = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	UiMetrics.register(self)
	for c in gs.party:
		_add_card(c)
	ctrl.changed.connect(refresh)
	resized.connect(_layout)
	_layout()
	refresh()

func rescale() -> void:
	_layout()
	queue_redraw()

func _add_card(c: Dictionary) -> void:
	var cls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
	var cls_name := str(cls.get("name", ""))
	var base := str(cls.get("evolvesFrom", cls_name))
	var accent := UiTheme.class_color(base)
	var id := str(c.id)
	var card := PartyCard.new()
	card.char_id = id
	card.accent = accent
	card.pressed.connect(func(): card_pressed.emit(id))
	card.chest_pressed.connect(func(): chest_pressed.emit(id))
	card.context.connect(func(): card_opened.emit(id))
	card.mouse_entered.connect(func():
		var ch := gs.char_by_id(id)
		if not ch.is_empty():
			PartyTip.show_for(card, gs, ch))
	card.mouse_exited.connect(PartyTip.hide_tip)
	add_child(card)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	card.pic.texture = load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", "")))
	card.name_lbl.text = str(c.name)
	card.cls_lbl.text = cls_name
	card.cls_ico.texture = IconResolver.texture(str(c.get("icon", "")))
	card.cls_ico.visible = card.cls_ico.texture != null
	_cards[id] = {"card": card, "panel": card, "lvl": card.lvl_lbl, "hp": card.hp, "sta": card.sta, "xp": card.xp, "gauge": card.gauge,
		"badge": card.badge, "dead": card.dead_lbl, "state": "normal"}

func _on_card_input(_ev: InputEvent, _char_id: String) -> void:
	pass

const CARD_H := 88.0
const BAR_SRC := "res://assets/ui/party_bar.webp"
const BAR_W := 1956.0
const BAR_H := 340.0
## Fentes du bandeau (px de l'image d'origine) : x début, x fin ; y 125 → 258 (hauteur 133).
const SLOTS := [[99.0, 471.0], [560.0, 935.0], [1022.0, 1391.0], [1479.0, 1851.0]]
const SLOT_Y := [125.0, 258.0]
var _bar_cache: Dictionary = {}
var _flames: Array = []
const TORCH_BASE := [[47.0, 108.0], [1909.0, 108.0]]    # centre des vasques (px de l'image d'origine)
const CARD_GAP := 8.0
const PAD := 6.0

## Hauteur réservée à la rangée de cartes (px de conception) : une rangée en bureau, deux en portrait.
static func wanted_height() -> float:
	if not UiMetrics.portrait:
		return UiMetrics.css(110.0)   # affiné par le rapport du bandeau dès que la largeur est connue
	var rows := 2 if UiMetrics.portrait else 1
	return UiMetrics.css(CARD_H) * rows + UiMetrics.css(CARD_GAP) * (rows - 1) + UiMetrics.css(PAD)

## Bandeau (paysage) : une seule image à 4 fentes, les cartes se posent dedans. Portrait : grille 2 × 2 de cartes encadrées.
func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var framed := not UiMetrics.portrait and n == SLOTS.size() and ResourceLoader.exists(BAR_SRC)
	if framed:
		var sc := size.x / BAR_W
		var want := BAR_H * sc
		if absf(custom_minimum_size.y - want) > 0.5:
			custom_minimum_size = Vector2(0, want)
		var i := 0
		for c in gs.party:
			var card: PartyCard = _cards[str(c.id)].card
			card.framed = true
			var sl: Array = SLOTS[mini(i, SLOTS.size() - 1)]
			var inset := 3.0 * sc
			card.position = Vector2(sl[0] * sc + inset, SLOT_Y[0] * sc + inset)
			card.size = Vector2((sl[1] - sl[0]) * sc - inset * 2.0, (SLOT_Y[1] - SLOT_Y[0]) * sc - inset * 2.0)
			card._layout()
			card.queue_redraw()
			i += 1
		_place_flames(sc)
		queue_redraw()
		return
	for fl in _flames:
		fl.visible = false
	var gap := UiMetrics.css(CARD_GAP)
	var pad := UiMetrics.css(PAD)
	var cols := 2 if UiMetrics.portrait else n
	var rows := int(ceil(float(n) / float(cols)))
	var w := (size.x - pad * 2.0 - gap * (cols - 1)) / float(cols)
	var h := maxf(40.0, (size.y - pad - gap * (rows - 1)) / float(rows))
	var i2 := 0
	for c in gs.party:
		var card: PartyCard = _cards[str(c.id)].card
		card.framed = false
		card.position = Vector2(pad + (i2 % cols) * (w + gap), pad + int(i2 / cols) * (h + gap))
		card.size = Vector2(w, h)
		card._layout()
		card.queue_redraw()
		i2 += 1
	queue_redraw()

## Flammes 3D des deux torches du bandeau (créées à la première mise en page).
func _place_flames(sc: float) -> void:
	if _flames.is_empty():
		for tb in TORCH_BASE:
			var fl := HudFlame.new()
			add_child(fl)
			_flames.append(fl)
	for i in _flames.size():
		_flames[i].visible = true
		_flames[i].place(Vector2(TORCH_BASE[i][0], TORCH_BASE[i][1]) * sc, sc)

func _bar_texture(real_w: int) -> Texture2D:
	if not _bar_cache.has(real_w):
		var src := load(BAR_SRC) as Texture2D
		var img := src.get_image()
		img.resize(real_w, maxi(1, roundi(real_w * BAR_H / BAR_W)), Image.INTERPOLATE_LANCZOS)
		_bar_cache.clear()
		_bar_cache[real_w] = ImageTexture.create_from_image(img)
	return _bar_cache[real_w]

func _draw() -> void:
	if UiMetrics.portrait or _cards.size() != SLOTS.size() or not ResourceLoader.exists(BAR_SRC) or size.x < 50.0:
		return
	var real_w := maxi(64, roundi(size.x * UiMetrics.s))
	draw_texture_rect(_bar_texture(real_w), Rect2(Vector2.ZERO, Vector2(size.x, size.x * BAR_H / BAR_W)), false)

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		var lv := L.fa(L.t("ui.party_hud.nv"), int(c.level))
		if cd.lvl.text != lv:
			cd.lvl.text = lv
			(cd.card as PartyCard)._layout()
		cd.lvl.text = lv
		if PartyTip.current_id() == str(c.id):
			PartyTip.show_for(cd.card, gs, c)     # la fiche reste à jour (PV, statuts…) pendant le survol
		cd.hp.set_values(int(c.hp), int(c.maxHp), ("%d/%d" % [int(c.hp), int(c.maxHp)]) if cd.card.framed else L.fa(L.t("common.pv_2"), [int(c.hp), int(c.maxHp)]))
		cd.sta.set_values(int(c.stamina), int(c.maxStamina), ("%d/%d" % [int(c.stamina), int(c.maxStamina)]) if cd.card.framed else L.fa(L.t("ui.party_hud.end"), [int(c.stamina), int(c.maxStamina)]))
		cd.xp.set_values(int(c.get("xp", 0)), int(c.get("xpToNext", 1)), L.fa(L.t("ui.party_hud.xp"), [int(c.get("xp", 0)), int(c.get("xpToNext", 1))]))
		var dead: bool = int(c.hp) <= 0
		_refresh_status(c, cd, dead)
		var cant_act: bool = not dead and ctrl.in_combat() and ctrl.combat != null and not ctrl.combat.can_act(c)
		cd.panel.modulate = Color(0.45, 0.45, 0.45) if dead else (Color(0.58, 0.56, 0.54) if cant_act else Color.WHITE)
		cd.dead.visible = dead
		var my_turn: bool = ctrl.in_combat() and gs.active_char_id == str(c.id) \
				and float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0)) >= 100.0
		var selected: bool = not ctrl.in_combat() and gs.active_char_id == str(c.id)
		var targeting: bool = ctrl.pending_spell != "" and not dead
		var card: PartyCard = cd.card
		card.active = my_turn or selected
		card.targetable = targeting
		card.dead = dead
		card.queue_redraw()

func _process(_delta: float) -> void:
	if ctrl.combat == null:
		return
	var in_fight := ctrl.in_combat()
	var tf := ctrl.turn_timer_fraction()
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		cd.gauge.visible = in_fight
		if in_fight:
			var g := float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0))
			if g >= 100.0 and gs.active_char_id == str(c.id) and tf >= 0.0:
				cd.gauge.set_values(tf * 100.0, 100.0, "")
			else:
				cd.gauge.set_values(g, 100.0, "")

const STATUS_COLORS := {"freeze": "7fd0ff", "stun": "e6d36b", "burn": "ff8a3d", "poison": "7fd17f", "lifedrain": "b06be0",
	"weaken": "c9a27a", "warcry": "d67a7a", "slow": "8fa8c9", "haste": "ffe27a", "vigor": "ffd88a", "weaponfire": "ff9a4d"}

## Pastille de statut sur le portrait (statut prioritaire + tours restants) et anneau teinté.
func _refresh_status(c: Dictionary, cd: Dictionary, dead: bool) -> void:
	var effs: Array = [] if dead else Statuses.active(c)
	var card: PartyCard = cd.card
	if effs.is_empty():
		cd.badge.visible = false
		if card.ring_override.a > 0.0:
			card.ring_override = Color(0, 0, 0, 0)
			card.queue_redraw()
		return
	var e: Dictionary = effs[0]
	var sdef := Statuses.def(str(e.type))
	var col := Color(str(STATUS_COLORS.get(str(e.type), "ffd88a")))
	cd.badge.text = "%s %d" % [str(sdef.label), int(e.remaining)] + (" +%d" % (effs.size() - 1) if effs.size() > 1 else "")
	cd.badge.add_theme_color_override("font_color", col)
	cd.badge.visible = true
	if card.ring_override != col:
		card.ring_override = col
		card.queue_redraw()
