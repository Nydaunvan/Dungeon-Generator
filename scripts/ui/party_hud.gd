class_name PartyHud
extends Control
## Cartes de l'équipe en arche : ruban de classe, portrait rond, nom, classe, niveau, PV / endurance / XP,
## jauge de tour en combat. Cliquer une carte = choisir le personnage / la cible d'un sort.

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

## Place les cartes en grille régulière (écart 8 px CSS) sous le rail ; le rail est dessiné ici.
func _layout() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var top := UiMetrics.css(26.0)
	var gap := UiMetrics.css(8.0)
	var pad := UiMetrics.css(6.0)
	var w := (size.x - pad * 2.0 - gap * (n - 1)) / float(n)
	var h := maxf(40.0, size.y - top)
	var i := 0
	for c in gs.party:
		var card: PartyCard = _cards[str(c.id)].card
		card.position = Vector2(pad + i * (w + gap), top)
		card.size = Vector2(w, h)
		i += 1
	queue_redraw()

func _draw() -> void:
	# rail : barre bronze (gauche 2 px, droite 2 px, à -21 px du haut des cartes)
	var top := UiMetrics.css(26.0)
	var y := top - UiMetrics.css(21.0)
	var h := UiMetrics.css(9.0)
	var r := Rect2(UiMetrics.css(2.0), y, size.x - UiMetrics.css(4.0), h)
	draw_rect(Rect2(r.position - Vector2(1, 1) * UiMetrics.css(1.0), r.size + Vector2(2, 2) * UiMetrics.css(1.0)), Color("070504"))
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var col := Color("5a4630").lerp(Color("2a2016"), minf(t * 2.0, 1.0)) if t < 0.5 else Color("2a2016").lerp(Color("0d0a07"), (t - 0.5) * 2.0)
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / steps, r.size.x, r.size.y / steps + 0.5), col)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, maxf(1.0, UiMetrics.css(1.0))), Color(1, 0.86, 0.67, 0.2))
	# rivet aux deux bouts
	var rv := UiMetrics.css(2.6)
	for x in [r.position.x + UiMetrics.css(4.0), r.end.x - UiMetrics.css(4.0)]:
		draw_circle(Vector2(x, y + h * 0.5), rv, Color("b09068"))
		draw_circle(Vector2(x, y + h * 0.5), rv * 0.55, Color("4a3826"))

func refresh() -> void:
	for c in gs.party:
		var cd: Dictionary = _cards[str(c.id)]
		var lv := L.fa(L.t("ui.party_hud.nv"), int(c.level))
		if cd.lvl.text != lv:
			cd.lvl.text = lv
			(cd.card as PartyCard)._layout()
		cd.lvl.text = lv
		cd.hp.set_values(int(c.hp), int(c.maxHp), L.fa(L.t("common.pv_2"), [int(c.hp), int(c.maxHp)]))
		cd.sta.set_values(int(c.stamina), int(c.maxStamina), L.fa(L.t("ui.party_hud.end"), [int(c.stamina), int(c.maxStamina)]))
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
