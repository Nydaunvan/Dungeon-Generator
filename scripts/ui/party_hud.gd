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
		if not ch.is_empty() and _tip_allowed():
			PartyTip.show_for(card, gs, ch))
	card.mouse_exited.connect(PartyTip.hide_tip)
	add_child(card)
	var pp := IconResolver.portrait_path(c, gs.cfg)
	card.pic.texture = load(pp) if pp != "" else IconResolver.texture(str(c.get("icon", "")))
	card.name_lbl.text = str(c.name).to_upper()
	card.cls_lbl.text = cls_name
	card.cls_ico.texture = IconResolver.texture(str(c.get("icon", "")))
	_cards[id] = {"card": card, "panel": card, "lvl": card.lvl_lbl, "hp": card.hp, "sta": card.sta, "xp": card.xp, "gauge": card.gauge,
		"badge": card.badge, "dead": card.dead_lbl, "state": "normal"}

func _on_card_input(_ev: InputEvent, _char_id: String) -> void:
	pass

const CARD_H := 92.0
## Héros seul (« Héros solitaire ») : sa fiche occupe la deuxième des quatre places, les autres restent vides.
const SOLO_SLOT := 1
## La fiche de survol n'apparaît ni en combat, ni quand un sort est en cours d'application sur un personnage.
func _tip_allowed() -> bool:
	return ctrl == null or (not ctrl.in_combat() and ctrl.pending_spell == "")

const CARD_GAP := 8.0
const PAD := 6.0

## Hauteur réservée à la rangée de fiches (px de conception) : une rangée en bureau, deux en portrait.
static func wanted_height() -> float:
	var rows := 2 if UiMetrics.portrait else 1
	return UiMetrics.css(CARD_H) * rows + UiMetrics.css(CARD_GAP) * (rows - 1) + (UiMetrics.css(PAD) if UiMetrics.portrait else 0.0)

## Bureau : une rangée de quatre fiches (un héros seul tient la deuxième place). Portrait : grille 2 × 2.
func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var gap := UiMetrics.css(CARD_GAP)
	var pad := UiMetrics.css(PAD) if UiMetrics.portrait else 0.0
	var cols := 2 if UiMetrics.portrait else maxi(1, mini(n, 4) if n != 1 else 4)
	var rows := int(ceil(float(n) / float(cols))) if n != 1 else 1
	var w := (size.x - pad * 2.0 - gap * (cols - 1)) / float(cols)
	var h := maxf(40.0, (size.y - pad * 2.0 - gap * (rows - 1)) / float(rows))
	var i := 0
	for c in gs.party:
		var card: PartyCard = _cards[str(c.id)].card
		var slot := SOLO_SLOT if (n == 1 and not UiMetrics.portrait) else i
		card.position = Vector2(pad + (slot % cols) * (w + gap), pad + int(slot / cols) * (h + gap))
		card.size = Vector2(w, h)
		card._layout()
		card.queue_redraw()
		i += 1
	queue_redraw()

## Centre de chaque carte du groupe (pixels de la fenêtre), dans l'ordre du groupe : cibles des effets de la couche CardFxOverlay.
func card_centers() -> Array:
	var out: Array = []
	for c in gs.party:
		var card: Control = _cards[str(c.id)].card
		out.append(card.get_global_rect().get_center())
	return out

## Rectangle de chaque carte du groupe (pixels de la fenêtre) : emplacement des effets de statut persistants.
func card_rects() -> Array:
	var out: Array = []
	for c in gs.party:
		out.append((_cards[str(c.id)].card as Control).get_global_rect())
	return out

## Milieu du bord bas de chaque carte (pixels de la fenêtre) : point de départ des effets lancés par un héros.
func card_bottoms() -> Array:
	var out: Array = []
	for c in gs.party:
		var r: Rect2 = (_cards[str(c.id)].card as Control).get_global_rect()
		out.append(Vector2(r.get_center().x, r.end.y))
	return out

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		var lv := L.fa(L.t("ui.party_hud.nv"), int(c.level))
		if cd.lvl.text != lv:
			cd.lvl.text = lv
			(cd.card as PartyCard)._layout()
		cd.lvl.text = lv
		# la classe change à l'évolution : nom, icône et couleur suivent la classe actuelle
		var ccls := Characters.class_def(gs.cfg, str(c.get("classId", "")))
		var cname := str(ccls.get("name", ""))
		if cd.card.cls_lbl.text != cname:
			cd.card.cls_lbl.text = cname
			cd.card.cls_ico.texture = IconResolver.texture(str(c.get("icon", "")))
			cd.card.accent = UiTheme.class_color(str(ccls.get("evolvesFrom", cname)))
			(cd.card as PartyCard)._layout()
			cd.card.queue_redraw()
		if PartyTip.current_id() == str(c.id):
			if _tip_allowed():
				PartyTip.show_for(cd.card, gs, c)     # la fiche reste à jour (PV, statuts…) pendant le survol
			else:
				PartyTip.hide_tip()
		cd.hp.set_values(int(c.hp), int(c.maxHp), "%d/%d" % [int(c.hp), int(c.maxHp)])
		cd.sta.set_values(int(c.stamina), int(c.maxStamina), "%d/%d" % [int(c.stamina), int(c.maxStamina)])
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
		# la barre dorée est le chronomètre de réflexion : visible seulement pour le héros dont c'est le tour
		var g := float(ctrl.combat.gauges.get("char_" + str(c.id), 0.0))
		var timing: bool = in_fight and g >= 100.0 and gs.active_char_id == str(c.id) and tf >= 0.0
		cd.gauge.visible = timing
		if timing:
			cd.gauge.set_values(tf * 100.0, 100.0, "")

const STATUS_COLORS := {"freeze": "7fd0ff", "stun": "e6d36b", "burn": "ff8a3d", "poison": "7fd17f", "lifedrain": "b06be0",
	"weaken": "c9a27a", "warcry": "d67a7a", "slow": "8fa8c9", "haste": "ffe27a", "vigor": "ffd88a", "weaponfire": "ff9a4d"}

## Pastille de statut sur le portrait (statut prioritaire + tours restants) et anneau teinté.
func _refresh_status(c: Dictionary, cd: Dictionary, dead: bool) -> void:
	var effs: Array = [] if dead else Statuses.active(c)
	var card: PartyCard = cd.card
	cd.badge.visible = false          # remplacée par la rangée de pastilles (une par statut, icône + tours)
	var chips: Array = []
	for i in mini(effs.size(), 4):
		var e: Dictionary = effs[i]
		chips.append({"text": "%s %d" % [Statuses.icon_of(e), int(e.remaining)], "color": Color(str(STATUS_COLORS.get(str(e.type), "ffd88a")))})
	if effs.size() > 4:
		chips.append({"text": "+%d" % (effs.size() - 4), "color": Color("c9a27a")})
	card.set_statuses(chips)
	if effs.is_empty():
		if card.ring_override.a > 0.0:
			card.ring_override = Color(0, 0, 0, 0)
			card.queue_redraw()
		return
	var col := Color(str(STATUS_COLORS.get(str(effs[0].type), "ffd88a")))
	if card.ring_override != col:
		card.ring_override = col
		card.queue_redraw()
