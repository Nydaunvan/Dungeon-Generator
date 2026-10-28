class_name OnlineHub
extends RefCounted
## Écran unique du mode en ligne (style « jeu vidéo », GameScreen) : barre du haut (compte, onglets, actions) toujours visible, cinq onglets
##  Jouer (choix du mode : partie libre, classée, défis du jour / de la semaine, Hardcore du mois — avec ce que chacun implique),
##  Classements, Récompenses, Mes parties, Amis. Les icônes sont dessinées (GameIcons), plus d'emojis.
## Rien ne défile en usage normal : chaque onglet tient à l'écran (les lignes des classements s'adaptent à la hauteur disponible).

const TABS := [["play", "ui.hub.tab_play", "swords"], ["boards", "ui.hub.tab_boards", "bars"], ["rewards", "ui.hub.tab_rewards", "medal"], ["runs", "ui.hub.tab_runs", "scroll"], ["friends", "ui.hub.tab_friends", "friends"]]
const MODES := ["free", "ranked", "weekly", "hardcore"]
## Ce que mesure le classement de certaines règles du Défi de la semaine (les autres comptent des niveaux).
const RULE_METRIC := {"richest": "gold", "bossrush": "bosses"}
## Modes de l'onglet « Jouer » : les classements (MODES) n'incluent pas le Défi du jour, qui n'a pas de classement.
const PLAY_MODES := ["free", "ranked", "daily", "weekly", "hardcore"]
const MODE_ICON := {"free": "🎲", "ranked": "🏆", "weekly": "📅", "daily": "🌅", "hardcore": "🔥"}
## Icônes dessinées (GameIcons) et couleur de chaque mode de l'onglet Jouer.
const MODE_GLYPH := {"free": "dice", "ranked": "trophy", "weekly": "calendar", "daily": "sunrise", "hardcore": "flame"}
## Affiches de la rangée « Autres modes » (mobile) : haut et bas du dégradé, couleur de l'icône, couleur du liseré.
const POSTER := {
	"free": [Color("25361a"), Color("0e140a"), Color("e8e0a8"), Color(0.94, 0.77, 0.36, 0.3)],
	"ranked": [Color("5c4416"), Color("171004"), Color("f6dc8a"), Color(0.94, 0.77, 0.36, 0.3)],
	"daily": [Color("7a3d12"), Color("1d1008"), Color("ffd59a"), Color(0.94, 0.77, 0.36, 0.3)],
	"weekly": [Color("1f5a64"), Color("071316"), Color("a9eaf2"), Color(0.94, 0.77, 0.36, 0.3)],
	"hardcore": [Color("8a2a17"), Color("1a0705"), Color("ffb59a"), Color(0.88, 0.31, 0.18, 0.6)]}
const MODE_KICK := {"free": "ui.hub.kick_free", "ranked": "ui.hub.kick_ranked", "weekly": "ui.hub.kick_weekly", "daily": "ui.hub.kick_daily", "hardcore": "ui.hub.kick_hardcore"}
const STAFF_TAG := {"dev": "DEV", "super_admin": "ADMIN", "moderator": "MOD"}
const MODE_NAME := {"free": "ui.hub.mode_free", "ranked": "ui.hub.mode_ranked", "weekly": "ui.hub.mode_weekly", "daily": "ui.hub.mode_daily", "hardcore": "ui.hub.mode_hardcore"}
const MODE_TAG := {"free": "ui.hub.tag_free", "ranked": "ui.hub.tag_ranked", "weekly": "ui.hub.tag_weekly", "daily": "ui.hub.tag_daily", "hardcore": "ui.hub.tag_hardcore"}
const XP_MULT := {"easy": "×1", "normal": "×1,5", "hard": "×2", "hardcore": "×3"}
const STATUS_KEYS := {"started": "ui.hub.st_started", "submitted": "ui.hub.st_submitted", "verified": "ui.hub.st_verified",
	"rejected": "ui.hub.st_rejected", "expired": "ui.hub.st_expired"}
const GOLD := Color("e8b45c")

var _host: Node
var _modal: GameScreen
var _on_launch: Callable
var _tab := "play"
var _mode := "free"
var _diff := "normal"
var _src := "free"          ## classements : free / ranked / hardcore
var _src_diff := "normal"
var _gen := 0               ## change à chaque changement d'onglet ou de vue : les réponses en retard sont ignorées
var _body: VBoxContainer
var _strip_box: VBoxContainer
var _tab_buttons: Dictionary = {}
var _xp := -1
var _weekly: Dictionary = {}     ## règle de la semaine (RankedRun.weekly_current), vide tant qu'elle n'est pas lue
var _daily: Dictionary = {}      ## Défi du jour (RankedRun.daily_current), vide tant qu'il n'est pas lu
var _runs: Array = []
var _runs_holder: VBoxContainer
var _run_clocks: Array = []
var _run_poll := 0
var _run_busy := false
var _wk_clocks: Array = []
var _runs_ok := false
var _width := 760.0
var _notice_box: VBoxContainer
var _glass: PanelContainer
var _glass_style: StyleBox
var _play_btn: Button = null     ## bouton de lancement du mode affiché (touche Entrée)
var _rules_open := false         ## « Règles du mode » déplié ou non (garde son état d'un mode à l'autre)
var _rules_panel: Control = null
var _list: VBoxContainer = null  ## liste des modes (écran large), reconstruite quand les minuteurs arrivent
var _prefetching := false

## `on_launch` : appelé quand le joueur lance une partie libre (la fenêtre est alors fermée) ; `tab` : onglet affiché d'abord.
static func open(host: Node, on_launch: Callable = Callable(), tab: String = "play") -> OnlineHub:
	var h := OnlineHub.new()
	h._host = host
	h._on_launch = on_launch
	h._tab = tab
	var vp: Vector2 = host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	var narrow := UiMetrics.portrait or vp.x < 760.0
	h._width = clampf(vp.x - (28.0 if narrow else 72.0), 300.0, 1500.0)
	h._modal = GameScreen.open(host, narrow)
	h._modal.closed.connect(h._on_closed)
	Cloud.session_changed.connect(h._on_session)
	h._build()
	h._refresh_notice.call_deferred()
	h._load_friend_badge.call_deferred()
	return h

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _on_closed() -> void:
	if Cloud.session_changed.is_connected(_on_session):
		Cloud.session_changed.disconnect(_on_session)

func _on_session() -> void:
	if not _alive():
		return
	_xp = -1
	_runs_ok = false
	_fill_strip()
	_show(_tab)

func _narrow() -> bool:
	return _modal != null and _modal.narrow

func _online() -> bool:
	return Cloud.is_configured()

func _signed() -> bool:
	return Cloud.is_configured() and Cloud.is_signed_in()

# ------------------------------------------------------------------ structure

func _build() -> void:
	var c := _modal.content
	c.add_theme_constant_override("separation", 8)
	_strip_box = _modal.player_box as VBoxContainer
	_notice_box = HubKit.vbox(0)
	c.add_child(_notice_box)
	_glass = GameScreen.glass(14, 6)
	_glass_style = _glass.get_theme_stylebox("panel")
	_glass.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(_glass)
	_body = HubKit.vbox(8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_glass.add_child(_body)
	_fill_strip()
	for t in TABS:
		var id: String = t[0]
		var b: Button
		if _narrow():
			b = GameWidgets.tab_button(L.t(t[1]).to_upper(), str(t[2]), id == _tab, func(): _show(id))
		else:
			b = GameWidgets.nav_button(L.t(t[1]).to_upper(), id == _tab, func(): _show(id))
		b.tooltip_text = L.t(t[1])
		_modal.nav_box.add_child(b)
		_tab_buttons[id] = b
		if id == "friends":
			_friend_dot = NotifDot.attach(b, func(): return _friend_requests, true)
			var blink := _friend_dot.create_tween().set_loops()
			blink.tween_property(_friend_dot, "modulate:a", 0.15, 0.55)
			blink.tween_property(_friend_dot, "modulate:a", 1.0, 0.55)
	_modal.set_buttons([{"text": L.t("ui.hub.back"), "cb": func(): _modal.close()}])
	_modal.key_handler = _on_key
	_show(_tab)

## Pastille à bascule précédée d'une icône dessinée (sous-onglets des classements).
func _icon_toggle(icon: String, text: String, active: bool, cb: Callable) -> Button:
	var b := HubKit.toggle(text, active, cb, 14, 12, 7)
	b.icon = GameIcons.tex(icon, 40, Color.WHITE)
	b.add_theme_constant_override("icon_max_width", 17)
	b.add_theme_constant_override("h_separation", 7)
	b.add_theme_color_override("icon_normal_color", Color("e2d2b0"))
	b.add_theme_color_override("icon_hover_color", Color("f4e6c6"))
	b.add_theme_color_override("icon_pressed_color", Color("ffd88a"))
	b.add_theme_color_override("icon_hover_pressed_color", Color("ffe6a8"))
	return b

## Touches : ↑↓ (Haut/Bas) changent de mode, Entrée lance, ←→ changent d'onglet.
func _on_key(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_UP, KEY_DOWN:
			if _tab != "play":
				return false
			var i := PLAY_MODES.find(_mode)
			i = clampi(i + (1 if ev.keycode == KEY_DOWN else -1), 0, PLAY_MODES.size() - 1)
			if PLAY_MODES[i] != _mode:
				_mode = PLAY_MODES[i]
				_show("play")
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if _tab == "play" and _play_btn != null and is_instance_valid(_play_btn) and not _play_btn.disabled:
				_play_btn.pressed.emit()
				return true
		KEY_LEFT, KEY_RIGHT:
			var ids: Array = TABS.map(func(t): return t[0])
			var j := clampi(ids.find(_tab) + (1 if ev.keycode == KEY_RIGHT else -1), 0, ids.size() - 1)
			if ids[j] != _tab:
				_show(ids[j])
			return true
	return false

func _show(tab: String) -> void:
	_tab = tab
	_gen += 1
	_play_btn = null
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).button_pressed = t == tab
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	# l'onglet Jouer se pose directement sur le décor (liste collée au bord) ; les autres sont dans un panneau de verre
	if tab == "play":
		_glass.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		_glass.add_theme_stylebox_override("panel", _glass_style)
	_modal.set_body_inset(0 if (tab == "play" and not _narrow()) else (14 if _narrow() else 40))
	_modal.clear_hints("right")
	if not _narrow() and tab == "play":
		_modal.add_hint([L.t("ui.screen.key_up"), L.t("ui.screen.key_down")], L.t("ui.screen.hint_choose"))
		_modal.add_hint(L.t("ui.screen.key_enter"), L.t("ui.screen.hint_play"), "right", func():
			if _play_btn != null and is_instance_valid(_play_btn) and not _play_btn.disabled:
				_play_btn.pressed.emit())
	match tab:
		"play": _show_play()
		"boards": _show_boards()
		"rewards": _show_rewards()
		"runs": _show_runs()
		"friends": _show_friends()
	_stabilize_height()

## La fenêtre occupe tout l'écran : le corps prend la place restante (et défile au-delà), la hauteur ne change donc pas d'un onglet à l'autre.
func _stabilize_height() -> void:
	_body.custom_minimum_size.y = 0

## Onglet « Amis » : tout est dans HubFriends. La pastille (demandes reçues) du bouton de l'onglet suit la liste.
var _friends: HubFriends

func _show_friends() -> void:
	if not _signed():
		_body.add_child(HubKit.label(L.t("ui.hub.friends_sign_in"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var mine := _gen
	_friends = HubFriends.build(_body, _host, func(): return mine != _gen or not _alive(), func(): _modal.call_deferred("_fit"),
		func(): _modal.close(), _set_friend_badge)

## Texte du bouton de l'onglet Amis : « 👥 Amis (2) » quand des demandes attendent.
func _set_friend_badge(n: int) -> void:
	_friend_requests = n
	if _friend_dot != null and is_instance_valid(_friend_dot):
		_friend_dot._update()
	if _tab_buttons.has("friends"):
		var b: Button = _tab_buttons["friends"]
		b.text = L.t("ui.hub.tab_friends").to_upper() + (" (%d)" % n if n > 0 else "")

var _friend_requests := 0
var _friend_dot: NotifDot = null   ## point rouge clignotant sur l'onglet Amis tant que des demandes attendent

func _load_friend_badge() -> void:
	if not _signed():
		return
	var r: Dictionary = await Friends.pending_count()
	if _alive() and r.ok and (r.data is int or r.data is float):
		_set_friend_badge(int(r.data))

func _wait(parent: Control) -> Label:
	var l := HubKit.label(L.t("ui.hub.loading"), UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER)
	parent.add_child(l)
	return l

func _error(parent: Control, r: Dictionary) -> void:
	parent.add_child(HubKit.label(str(r.get("message", "")), HubKit.BAD, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER))

# ------------------------------------------------------------------ bandeau « mon compte »

## Marque de rôle (développeur, super admin, modérateur) suivie d'une espace, "" pour un joueur ordinaire.
func _role_mark(player_id: String) -> String:
	var m := StaffBadges.mark(player_id)
	return m + " " if m != "" else ""

## Relit annonce, maintenance et rôles ; redessine le bandeau si quelque chose a changé.
func _refresh_notice() -> void:
	var before := ServerNotice.banner_text()
	await ServerNotice.refresh()
	await StaffBadges.refresh()
	if _alive() and _strip_box != null and ServerNotice.banner_text() != before:
		_fill_strip()

func _fill_strip() -> void:
	for ch in _strip_box.get_children():
		_strip_box.remove_child(ch)
		ch.queue_free()
	for ch in _notice_box.get_children():
		_notice_box.remove_child(ch)
		ch.queue_free()
	for ch in _modal.actions_box.get_children():
		_modal.actions_box.remove_child(ch)
		ch.queue_free()
	_modal.add_back_button()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12 if _narrow() else 16)
	_strip_box.add_child(h)
	var ring := GameWidgets.Ring.new(52.0 if _narrow() else 72.0)
	ring.name = "XpRing"
	h.add_child(ring)
	var left := HubKit.vbox(3)
	left.custom_minimum_size.x = 0 if _narrow() else 210
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(left)
	if _signed():
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = Cloud.pseudo().to_upper()
		nm.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 2))
		nm.add_theme_font_size_override("font_size", 16 if _narrow() else 20)
		nm.add_theme_color_override("font_color", GameWidgets.CREAM)
		top.add_child(nm)
		var tag: String = STAFF_TAG.get(StaffBadges.role_of(Cloud.user_id()), "")
		if tag != "":
			var tp := PanelContainer.new()
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = Color(0, 0, 0, 0)
			tsb.border_color = GameWidgets.GOLD
			tsb.set_border_width_all(1)
			tsb.set_corner_radius_all(3)
			tsb.content_margin_left = 8
			tsb.content_margin_right = 8
			tsb.content_margin_top = 1
			tsb.content_margin_bottom = 1
			tp.add_theme_stylebox_override("panel", tsb)
			var tl := Label.new()
			tl.text = tag
			tl.add_theme_font_size_override("font_size", 11)
			tl.add_theme_color_override("font_color", Color("f6dc8a"))
			tp.add_child(tl)
			tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(tp)
		left.add_child(top)
		var xl := HubKit.label("", GameWidgets.MUTED, 12 if _narrow() else 13, false, false)
		xl.name = "XpText"
		left.add_child(xl)
		ring.set_state(0.0, "")
		_load_xp()
	else:
		ring.icon = GameIcons.tex("user", 48, Color("f1deb0"))
		left.add_child(HubKit.label(L.t("ui.hub.offline_title") if _online() else L.t("ui.hub.unavailable_title"), GameWidgets.CREAM, 16, true, false))
		left.add_child(HubKit.label(L.t("ui.hub.offline_text") if _online() else L.t("ui.challenges.not_configured"), GameWidgets.MUTED, 12))
	var right := _modal.actions_box
	if _online() and not _signed():
		right.add_child(HubKit.button(L.t("ui.hub.sign_in"), func(): AccountModal.open(_host), true, 40))
	if _signed():
		var cbtn := GameWidgets.icon_button("chat", L.t("ui.chat.header"), func():
			_modal.close()
			ChatDock.open_panel())
		NotifDot.attach(cbtn)
		right.add_child(cbtn)
		var acc := GameWidgets.icon_button("user", L.t("ui.cloud.header"), func(): AccountModal.open(_host))
		NotifDot.attach(acc, SuperAdmin.pending, false, SuperAdmin.refresh_pending)
		right.add_child(acc)
	right.add_child(GameWidgets.icon_button("help", L.t("ui.help.how"), func(): DocModal.guide(_host, "defis")))
	var notice := ServerNotice.banner_text()
	if notice != "":
		var nl := HubKit.label(notice, Color("e0b87a"), 13, false, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nmg := MarginContainer.new()
		nmg.add_theme_constant_override("margin_bottom", 4)
		nmg.add_child(nl)
		_notice_box.add_child(nmg)

func _load_xp() -> void:
	var r: Dictionary = await RankedRun.my_xp()
	if not _alive() or not _signed():
		return
	_xp = 0
	if r.ok and r.data is Array and not (r.data as Array).is_empty():
		_xp = int(r.data[0].get("xp", 0))
	var lvl := Cosmetics.level_of(_xp)
	var lo := Cosmetics.xp_for_level(lvl)
	var hi := Cosmetics.xp_for_level(lvl + 1)
	var ring := _strip_box.find_child("XpRing", true, false) as GameWidgets.Ring
	var xt := _strip_box.find_child("XpText", true, false) as Label
	if ring != null:
		ring.set_state(float(_xp - lo) / maxf(1.0, float(hi - lo)), str(lvl))
	if xt != null:
		xt.text = L.fa(L.t("ui.hub.xp_next"), [hi - _xp, lvl + 1])

# ------------------------------------------------------------------ onglet Jouer

func _show_play() -> void:
	# Maquette B. Écran large : liste des modes collée au bord gauche (gemme, nom, accroche, temps restant ; le choisi a un dégradé doré
	# et une barre lumineuse), fiche du mode à droite directement sur le décor (accroche, titre géant, description, trois tuiles, bouton
	# de lancement, liens). Mobile / écran moyen : fiche en bas de l'écran, rangée d'affiches « Autres modes » dessous.
	var wide := not _narrow() and _width >= 820.0
	var box := HubKit.vbox(16 if wide else 10)
	_rules_panel = null
	if wide:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 80)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_body.add_child(row)
		_list = VBoxContainer.new()
		_list.add_theme_constant_override("separation", 6)
		_list.custom_minimum_size.x = clampf(_width * 0.36, 340.0, 440.0)
		_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(_list)
		_fill_list()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(box)
	else:
		_list = null
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_body.add_child(spacer)
		_body.add_child(box)
	_fill_mode(box)
	if not wide:
		_body.add_child(_poster_row())
	if (_mode == "hardcore" or _mode == "ranked" or _mode == "weekly" or _mode == "daily") and _signed() and not _runs_ok:
		_load_runs_for_play()
	_prefetch_timers()

func _fill_list() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	for m in PLAY_MODES:
		_list.add_child(_tile(m))

## Lit en arrière-plan le Défi du jour et le Défi de la semaine (fin des défis) pour afficher les temps restants dans la liste.
func _prefetch_timers() -> void:
	if _prefetching or not _online():
		return
	var need_d := _daily.is_empty() or _utc(_daily.get("ends_at", "")) < Time.get_unix_time_from_system()
	var need_w := _weekly.is_empty()
	if not need_d and not need_w:
		return
	_prefetching = true
	var mine := _gen
	if need_d:
		var r: Dictionary = await RankedRun.daily_current()
		if _alive() and r.ok and r.data is Dictionary:
			_daily = r.data
	if need_w and _alive():
		var r2: Dictionary = await RankedRun.weekly_current()
		if _alive() and r2.ok and r2.data is Dictionary:
			_weekly = (r2.data as Dictionary).get("current", r2.data) if (r2.data as Dictionary).has("current") else r2.data
	_prefetching = false
	if _alive() and mine == _gen and _list != null and is_instance_valid(_list):
		_fill_list()

## Texte à droite d'une ligne de la liste : temps restant du défi (jour, semaine, mois).
func _tile_status(m: String) -> String:
	var left := _end_left(m)
	return "" if left < 0 else _fmt_left(left, true)

## Secondes restantes avant la fin du mode, -1 si inconnue ou sans fin (partie libre, classée).
func _end_left(m: String) -> int:
	var ts := 0.0
	match m:
		"daily":
			ts = _utc(_daily.get("ends_at", "")) if not _daily.is_empty() else 0.0
		"weekly":
			ts = _utc(_weekly.get("ends_at", "")) if not _weekly.is_empty() and _weekly.has("ends_at") else 0.0
		"hardcore":
			var d := Time.get_datetime_dict_from_system()
			var y := int(d.year) + (1 if int(d.month) == 12 else 0)
			var mo := 1 if int(d.month) == 12 else int(d.month) + 1
			ts = float(Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00" % [y, mo]))
	if ts <= 0.0:
		return -1
	return maxi(0, int(ts - Time.get_unix_time_from_system()))

## « 14 h 12 » (ou « 4 j » en abrégé) : unités traduites (j/d, h).
func _fmt_left(secs: int, short: bool = false) -> String:
	var dd := L.t("ui.hub.u_day")
	if secs >= 86400:
		var days := secs / 86400
		var hrs := (secs % 86400) / 3600
		return "%d %s" % [days, dd] if short else "%d %s %d h" % [days, dd, hrs]
	return "%d h" % ceili(secs / 3600.0) if short else "%d h %02d" % [secs / 3600, (secs % 3600) / 60]

## Ligne de la liste des modes (maquette B).
func _tile(m: String) -> Button:
	var sel := m == _mode
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.pressed.connect(func():
		_mode = m
		_show("play"))
	var bg := GameWidgets.TileBg.new()
	bg.on = sel
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 10 if sel else 0
	b.add_child(bg)
	b.mouse_entered.connect(func():
		bg.hover = true
		bg.queue_redraw())
	b.mouse_exited.connect(func():
		bg.hover = false
		bg.queue_redraw())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22 + (10 if sel else 0)
	h.offset_right = -20
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := GameWidgets.Gem.new()
	gem.lit = sel
	var hc := m == "hardcore"
	if hc:
		gem.border = Color(0.88, 0.31, 0.18, 0.7)
	gem.tex = GameIcons.tex(MODE_GLYPH[m], 48, Color("ff9a7a") if hc else (Color("fff1d0") if sel else Color("e8dcc0")), 1.6)
	h.add_child(gem)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := Label.new()
	t1.text = L.t(MODE_NAME[m]).to_upper()
	t1.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD if sel else UiTheme.F_TITLE, 2))
	t1.add_theme_font_size_override("font_size", 22 if sel else 20)
	t1.add_theme_color_override("font_color", Color("fff1d0") if sel else Color("bfae8a"))
	t1.clip_text = true
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t1)
	var t2 := Label.new()
	t2.text = L.t(MODE_TAG[m])
	t2.add_theme_font_size_override("font_size", 14)
	t2.add_theme_color_override("font_color", Color("e8dcc0") if sel else Color("bfae8a"))
	t2.clip_text = true
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t2)
	h.add_child(v)
	var st := _tile_status(m)
	if st != "":
		var sl := Label.new()
		sl.text = st
		sl.add_theme_font_size_override("font_size", 13)
		sl.add_theme_color_override("font_color", GameWidgets.GOLD if (sel or m == "daily") else GameWidgets.MUTED)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sl)
	b.add_child(h)
	return b

## Rangée d'affiches « Autres modes » (mobile) : un appui change de mode.
func _poster_row() -> Control:
	var box := HubKit.vbox(8)
	var cap := Label.new()
	cap.text = L.t("ui.hub.others").to_upper()
	cap.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_BODY, 3))
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", GameWidgets.MUTED)
	box.add_child(cap)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 158)
	box.add_child(sc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	sc.add_child(hb)
	for m in PLAY_MODES:
		if m == _mode:
			continue
		var pc: Array = POSTER[m]
		hb.add_child(GameWidgets.poster(L.t(MODE_NAME[m]), MODE_GLYPH[m], pc[2], pc[0], pc[1], pc[3], func():
			_mode = m
			_show("play")))
	return box

## Accroche, titre géant (capitales Cinzel espacées, halo orangé) et description du mode.
func _mode_head(box: VBoxContainer, text: String, desc: String) -> void:
	var kt := Label.new()
	kt.text = L.t(MODE_KICK[_mode]).to_upper()
	kt.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_BODY, 5))
	kt.add_theme_font_size_override("font_size", 12 if _narrow() else 14)
	kt.add_theme_color_override("font_color", GameWidgets.GOLD)
	box.add_child(kt)
	var size_t := (34 if text.length() > 14 else 38) if _narrow() else (56 if (_width < 1100.0 or text.length() > 14) else 74)
	var t := Label.new()
	t.text = text.to_upper()
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 10
	t.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE_BOLD, 3))
	t.add_theme_font_size_override("font_size", size_t)
	t.add_theme_color_override("font_color", GameWidgets.CREAM)
	t.add_theme_color_override("font_shadow_color", Color(1.0, 0.59, 0.24, 0.32))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_constant_override("shadow_outline_size", 16)
	t.add_theme_constant_override("line_spacing", -6)
	box.add_child(t)
	var d := HubKit.label(desc, Color("e8dcc0"), 16 if _narrow() else 20, false, true)
	if not _narrow():
		d.custom_minimum_size.x = minf(560.0, _width * 0.45)
		d.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(d)

## Trois tuiles de verre : fin du défi (ou classement), essais, récompense.
func _info_tiles(box: VBoxContainer, m: String) -> void:
	var data := {
		"free": [["ui.hub.t_board", "ui.hub.v_declared"], ["ui.hub.t_tries", "ui.hub.v_unlimited"], ["ui.hub.t_save", "ui.hub.v_yes"]],
		"ranked": [["ui.hub.t_board", "ui.hub.v_verified"], ["ui.hub.t_tries", "ui.hub.v_unlimited"], ["ui.hub.t_reward", "ui.hub.v_r_ranked"]],
		"daily": [["ui.hub.t_end", ""], ["ui.hub.t_tries", "ui.hub.v_unlimited"], ["ui.hub.t_reward", "ui.hub.v_r_daily"]],
		"weekly": [["ui.hub.t_end", ""], ["ui.hub.t_tries", "ui.hub.v_unlimited"], ["ui.hub.t_reward", "ui.hub.v_r_weekly"]],
		"hardcore": [["ui.hub.t_end", ""], ["ui.hub.t_tries", "ui.hub.v_one_day"], ["ui.hub.t_reward", "ui.hub.v_r_hc"]]}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if _narrow() else 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow() else Control.SIZE_SHRINK_BEGIN
	box.add_child(row)
	var i := 0
	for spec in data[m]:
		var strong: bool = i == 2
		var tile := GameWidgets.info_tile(L.t(spec[0]), L.t(spec[1]) if spec[1] != "" else "…", strong, _narrow())
		if strong and not _narrow():
			tile.custom_minimum_size.x = 260
		row.add_child(tile)
		if spec[1] == "":
			var lbl := tile.get_meta("value") as Label
			var tmr := Timer.new()
			tmr.wait_time = 1.0
			tmr.autostart = true
			var mine := _gen
			var upd := func():
				if mine != _gen or not _alive() or not is_instance_valid(lbl):
					return
				var left := _end_left(m)
				lbl.text = "…" if left < 0 else (_fmt_left(left) if left > 0 else "—")
			tmr.timeout.connect(upd)
			tile.add_child(tmr)
			upd.call()
		i += 1

## Rangée de lancement : grand bouton bronze + liens « Règles du mode » et « Voir le classement ».
func _cta_row(box: VBoxContainer, mode: String, text: String, cb: Callable) -> Button:
	var stacked := _narrow() or text.length() > 24     # libellé long : les liens passent sous le bouton
	var wrap: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 10 if _narrow() else (14 if stacked else 26))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := GameWidgets.cta_button(text, cb, _narrow())
	wrap.add_child(b)
	var links: BoxContainer = HBoxContainer.new() if stacked else VBoxContainer.new()
	links.add_theme_constant_override("separation", 22 if stacked else 8)
	links.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	links.add_child(GameWidgets.link(L.t("ui.hub.link_rules"), func():
		_rules_open = not _rules_open
		if _rules_panel != null and is_instance_valid(_rules_panel):
			_rules_panel.visible = _rules_open))
	if mode != "daily":
		links.add_child(GameWidgets.link(L.t("ui.hub.link_board"), func():
			_src = mode
			_show("boards")))
	wrap.add_child(links)
	box.add_child(wrap)
	_play_btn = b
	return b

## Règles et détails du mode : panneau de verre replié, que le lien « Règles du mode » déplie (état conservé d'un mode à l'autre).
func _facts(box: VBoxContainer, rows: Array, columns: int) -> void:
	var panel := GameScreen.glass(16, 6)
	panel.visible = _rules_open
	var inner := HubKit.vbox(8)
	panel.add_child(inner)
	HubKit.facts(inner, rows, columns)
	box.add_child(panel)
	_rules_panel = panel

func _fill_mode(box: VBoxContainer) -> void:
	var cols := 1 if (_narrow() or _width < 1100.0) else 2
	match _mode:
		"free":
			_mode_head(box, L.t("ui.hub.mode_free"), L.t("ui.hub.free_desc"))
			_info_tiles(box, "free")
			if _on_launch.is_valid():
				_cta_row(box, "free", L.t("ui.hub.free_play"), func():
					_modal.close()
					_on_launch.call())
			else:
				box.add_child(HubKit.label(L.t("ui.hub.free_home"), UiTheme.DIM, 13, false, true))
			_facts(box, [
				["bars", L.t("ui.hub.f_board"), L.t("ui.hub.free_board")],
				["stop", L.t("ui.hub.f_quit"), L.t("ui.hub.free_quit")],
				["save", L.t("ui.hub.f_save"), L.t("ui.hub.free_save")],
				["tools", L.t("ui.hub.f_editor"), L.t("ui.hub.free_editor")],
				["unlock", L.t("ui.hub.f_unlock"), L.t("ui.hub.free_unlock")],
			], cols)
		"ranked":
			_mode_head(box, L.t("ui.hub.mode_ranked"), L.t("ui.hub.ranked_desc"))
			var chips := HFlowContainer.new()
			chips.add_theme_constant_override("h_separation", 6)
			chips.add_theme_constant_override("v_separation", 6)
			box.add_child(chips)
			for d in RankedRun.DIFFICULTIES:
				chips.add_child(HubKit.toggle("%s · XP %s" % [L.t(ChallengesModal.DIFF_KEYS[d]), XP_MULT[d]], d == _diff, func():
					_diff = d
					_show("play"), 14, 12, 7))
			_info_tiles(box, "ranked")
			_cta(box, "ranked")
			box.add_child(HubKit.label(L.t("ui.hub.ranked_dungeon"), UiTheme.DIM, 12))
			_facts(box, [
				["scale", L.t("ui.hub.f_fair"), L.t("ui.hub.ranked_fair")],
				["bars", L.t("ui.hub.f_board"), L.t("ui.hub.ranked_board")],
				["hourglass", L.t("ui.hub.f_time"), L.t("ui.hub.ranked_time"), HubKit.WARN],
				["stop", L.t("ui.hub.f_quit"), L.t("ui.hub.ranked_quit")],
				["star", L.t("ui.hub.f_reward"), L.t("ui.hub.ranked_reward")],
				["forbidden", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
				["repeat", L.t("ui.hub.f_tries"), L.t("ui.hub.ranked_tries")],
			], cols)
		"weekly":
			_mode_head(box, L.t("ui.hub.mode_weekly"), L.t("ui.hub.weekly_desc"))
			var rule_box := HubKit.card(Color("7a5a2c"), Color(0.2, 0.14, 0.05, 0.45), 12)
			rule_box.name = "RuleCard"
			box.add_child(rule_box)
			_info_tiles(box, "weekly")
			_cta(box, "weekly")
			_facts(box, [
				["target", L.t("ui.hub.f_dungeon"), L.t("ui.hub.weekly_dungeon")],
				["repeat", L.t("ui.hub.f_tries"), L.t("ui.hub.weekly_tries")],
				["hourglass", L.t("ui.hub.f_time"), L.t("ui.hub.ranked_time"), HubKit.WARN],
				["stop", L.t("ui.hub.f_quit"), L.t("ui.hub.weekly_quit")],
				["bars", L.t("ui.hub.f_board"), L.t("ui.hub.weekly_board")],
				["star", L.t("ui.hub.f_reward"), L.t("ui.hub.weekly_reward")],
				["forbidden", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
			], cols)
			_load_weekly(rule_box, _gen)
		"daily":
			_mode_head(box, L.t("ui.hub.mode_daily"), L.t("ui.hub.daily_desc"))
			var day_box := HubKit.card(Color("7a5a2c"), Color(0.2, 0.14, 0.05, 0.45), 12)
			day_box.name = "DailyCard"
			box.add_child(day_box)
			_info_tiles(box, "daily")
			_cta(box, "daily")
			_facts(box, [
				["target", L.t("ui.hub.f_dungeon"), L.t("ui.hub.daily_dungeon")],
				["repeat", L.t("ui.hub.f_tries"), L.t("ui.hub.daily_tries")],
				["stop", L.t("ui.hub.f_quit"), L.t("ui.hub.weekly_quit")],
				["star", L.t("ui.hub.f_reward"), L.t("ui.hub.daily_reward")],
				["forbidden", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
			], cols)
			_load_daily(day_box, _gen)
		"hardcore":
			var key := _month_key()
			_mode_head(box, L.t("ui.hub.mode_hardcore"), L.t("ui.hub.hc_desc"))
			box.add_child(HubKit.label(key.substr(5) + "/" + key.substr(0, 4), HubKit.FIRE, 18, true, false))
			_info_tiles(box, "hardcore")
			_cta(box, "hardcore")
			_facts(box, [
				["target", L.t("ui.hub.f_dungeon"), L.t("ui.hub.hc_dungeon")],
				["hourglass", L.t("ui.hub.f_tries"), L.t("ui.hub.hc_tries"), HubKit.WARN],
				["hourglass", L.t("ui.hub.f_time"), L.t("ui.hub.ranked_time"), HubKit.WARN],
				["stop", L.t("ui.hub.f_quit"), L.t("ui.hub.hc_quit")],
				["bars", L.t("ui.hub.f_board"), L.t("ui.hub.hc_board")],
				["medal", L.t("ui.hub.f_reward"), L.t("ui.hub.hc_reward")],
				["forbidden", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
			], cols)

## Lit (une fois) le Défi du jour et remplit sa carte : règle, temps restant, état du joueur.
func _load_daily(card: Control, mine: int) -> void:
	var v := HubKit.vbox(4)
	card.add_child(v)
	if _daily.is_empty() or _utc(_daily.get("ends_at", "")) < Time.get_unix_time_from_system():
		var wait := _wait(v)
		var r: Dictionary = await RankedRun.daily_current()
		if mine != _gen or not _alive():
			return
		wait.queue_free()
		if not r.ok or not (r.data is Dictionary):
			_error(v, r)
			return
		_daily = r.data
	var rule: Dictionary = _daily.get("rule", {})
	var en := TranslationServer.get_locale().begins_with("en")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(HubKit.label(str(rule.get("icon", "")), UiTheme.PARCH, 34, false, false, HORIZONTAL_ALIGNMENT_CENTER))
	var t := HubKit.vbox(0)
	head.add_child(t)
	t.add_child(HubKit.label(L.t("ui.hub.daily_rule"), UiTheme.DIM, 12))
	t.add_child(HubKit.label(str(rule.get("label_en" if en else "label_fr", "")), GOLD, 20, true))
	v.add_child(HubKit.label(str(rule.get("desc_en" if en else "desc_fr", "")), UiTheme.PARCH, 14))
	var l_end := HubKit.label("", UiTheme.PARCH, 13)
	v.add_child(l_end)
	_wk_clocks.clear()
	_wk_clocks.append({"label": l_end, "kind": "end", "t": _utc(_daily.get("ends_at", ""))})
	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(_tick_weekly.bind(mine))
	v.add_child(tm)
	_tick_weekly(mine)
	if _signed():
		var st: Dictionary = await RankedRun.daily_status()
		if mine != _gen or not _alive() or not st.ok or not (st.data is Dictionary):
			return
		var done := bool(st.data.get("done", false))
		var line := (L.t("ui.hub.daily_done") if done else L.t("ui.hub.daily_todo")) + "   ·   " + L.fa(L.t("ui.hub.daily_total"), int(st.data.get("total", 0)))
		v.add_child(HubKit.label(line, HubKit.GOOD if done else UiTheme.PARCH, 13))
	_modal.call_deferred("_fit")

## Lit (une fois) la règle de la semaine et remplit sa carte.
func _load_weekly(card: Control, mine: int) -> void:
	var v := HubKit.vbox(4)
	card.add_child(v)
	if _weekly.is_empty():
		var wait := _wait(v)
		var r: Dictionary = await RankedRun.weekly_current()
		if mine != _gen or not _alive():
			return
		wait.queue_free()
		if not r.ok or not (r.data is Dictionary):
			_error(v, r)
			return
		_weekly = r.data
	var rule: Dictionary = _weekly.get("rule", {})
	var en := TranslationServer.get_locale().begins_with("en")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(HubKit.label(str(rule.get("icon", "")), UiTheme.PARCH, 34, false, false, HORIZONTAL_ALIGNMENT_CENTER))
	var t := HubKit.vbox(0)
	head.add_child(t)
	t.add_child(HubKit.label(L.t("ui.hub.weekly_rule") + " · " + L.fa(L.t("ui.hub.weekly_week"), str(_weekly.get("period", "")).get_slice("W", 1)), UiTheme.DIM, 12))
	t.add_child(HubKit.label(str(rule.get("label_en" if en else "label_fr", "")), GOLD, 20, true))
	v.add_child(HubKit.label(str(rule.get("desc_en" if en else "desc_fr", "")), UiTheme.PARCH, 14))
	# comptes à rebours en direct : fin du défi, puis distribution des récompenses (la clôture a lieu REWARD_DELAY après la fin)
	var ends := _utc(_weekly.get("ends_at", ""))
	var rewards_at := ends + RankedRun.REWARD_DELAY_SEC
	_wk_clocks.clear()
	var l_end := HubKit.label("", UiTheme.PARCH, 13)
	v.add_child(l_end)
	_wk_clocks.append({"label": l_end, "kind": "end", "t": ends})
	var l_rew := HubKit.label("", UiTheme.GOLD, 13)
	l_rew.tooltip_text = L.fa(L.t("ui.hub.weekly_rewards_tip"), _when(rewards_at))
	l_rew.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(l_rew)
	_wk_clocks.append({"label": l_rew, "kind": "rew", "t": rewards_at})
	var nx: Dictionary = _weekly.get("next", {})
	if not nx.is_empty():
		var l_nx := HubKit.label(L.fa(L.t("ui.hub.weekly_next_label"), "%s %s" % [str(nx.get("icon", "")), str(nx.get("label_en" if en else "label_fr", ""))]), UiTheme.PARCH, 13)
		l_nx.mouse_filter = Control.MOUSE_FILTER_STOP
		l_nx.mouse_default_cursor_shape = Control.CURSOR_HELP
		l_nx.tooltip_text = L.fa(L.t("ui.hub.weekly_next_tip_wait"), str(nx.get("label_en" if en else "label_fr", "")))
		v.add_child(l_nx)
		_load_next_tip(l_nx, nx, ends, en, mine)
	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(_tick_weekly.bind(mine))
	v.add_child(tm)
	_tick_weekly(mine)
	if _signed():
		_load_streak(v, mine)
	_modal.call_deferred("_fit")

## Série de semaines consécutives du joueur et prochain palier.
func _load_streak(v: VBoxContainer, mine: int) -> void:
	var r: Dictionary = await RankedRun.my_streak()
	if mine != _gen or not _alive() or not r.ok or not (r.data is Dictionary):
		return
	var n := int(r.data.get("streak", 0))
	var played := bool(r.data.get("played_this_week", false))
	var goals := [3, 6, 12]
	var nxt := 0
	for g in goals:
		if n < g:
			nxt = g
			break
	var line := "🔗 " + L.fa(L.t("ui.hub.streak"), n)
	if nxt > 0:
		line += "   ·   " + L.fa(L.t("ui.hub.streak_next"), [nxt, nxt - n])
	line += "   ·   " + (L.t("ui.hub.streak_done") if played else L.t("ui.hub.streak_todo"))
	v.add_child(HubKit.label(line, HubKit.GOOD if played else UiTheme.PARCH, 13))
	_modal.call_deferred("_fit")

## Temps restant avant une date ISO (UTC) : « 3 jours », « 5 heures »…
func _remaining(iso: String) -> String:
	if iso.length() < 19:
		return "—"
	var left := int(Time.get_unix_time_from_datetime_string(iso.substr(0, 19)) - Time.get_unix_time_from_system())
	if left <= 0:
		return "—"
	if left >= 86400:
		return L.fa(L.t("ui.hub.weekly_days"), int(ceil(left / 86400.0)))
	return L.fa(L.t("ui.hub.weekly_hours"), maxi(1, int(ceil(left / 3600.0))))

## Compte à rebours « 2 j 03:12:45 » / « 03:12:45 ».
static func _countdown(secs: int) -> String:
	if secs >= 86400:
		return "%d j %02d:%02d:%02d" % [secs / 86400, (secs % 86400) / 3600, (secs % 3600) / 60, secs % 60]
	return "%02d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]

## Date locale courte d'un instant UNIX : « 13/10 à 00:00 ».
static func _when(t: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(t) + bias * 60)
	return L.fa(L.t("ui.hub.when_fmt"), [int(d.day), int(d.month), int(d.hour), int(d.minute)])

func _tick_weekly(mine: int) -> void:
	if mine != _gen or not _alive():
		return
	var now := Time.get_unix_time_from_system()
	for c in _wk_clocks:
		if not is_instance_valid(c.label):
			continue
		var left := int(float(c.t) - now)
		if c.kind == "end":
			(c.label as Label).text = L.fa(L.t("ui.hub.weekly_ends_in"), _countdown(left)) if left > 0 else L.t("ui.hub.weekly_ended")
		else:
			(c.label as Label).text = L.fa(L.t("ui.hub.weekly_rewards_in"), [_countdown(left), _when(float(c.t))]) if left > 0 else L.t("ui.hub.weekly_rewards_now")

## Lit la règle de la semaine suivante (description) pour l'infobulle explicative.
func _load_next_tip(lbl: Label, nx: Dictionary, starts: float, en: bool, mine: int) -> void:
	var r: Dictionary = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/weekly_rules?rule_id=eq.%s&select=icon,label_fr,label_en,desc_fr,desc_en" % str(nx.get("rule_id", "")).uri_encode(), null, false)
	if mine != _gen or not _alive() or not is_instance_valid(lbl) or not r.ok or not (r.data is Array) or (r.data as Array).is_empty():
		return
	var row: Dictionary = r.data[0]
	lbl.tooltip_text = L.fa(L.t("ui.hub.weekly_next_tip"), [str(row.get("icon", "")), str(row.get("label_en" if en else "label_fr", "")),
		str(row.get("desc_en" if en else "desc_fr", "")), _when(starts), _countdown(maxi(0, int(starts - Time.get_unix_time_from_system())))])

func _month_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d" % [int(d.year), int(d.month)]

## Bas de fiche : état (essai du jour, partie en attente…) et bouton de lancement.
func _cta(box: VBoxContainer, mode: String) -> void:
	var status := HubKit.label("", UiTheme.DIM, 13, true, true, HORIZONTAL_ALIGNMENT_LEFT)
	status.name = "CtaStatus"
	if not _online():
		status.text = L.t("ui.challenges.not_configured")
		box.add_child(status)
		return
	if not _signed():
		status.text = L.t("ui.hub.need_account")
		status.add_theme_color_override("font_color", HubKit.WARN)
		box.add_child(status)
		box.add_child(HubKit.button(L.t("ui.hub.sign_in"), func(): AccountModal.open(_host), true, 46))
		return
	var text := L.t("ui.hub.ranked_play") if mode == "ranked" else (L.t("ui.hub.weekly_play") if mode == "weekly" else (L.t("ui.hub.daily_play") if mode == "daily" else L.t("ui.hub.hc_play")))
	var b := _cta_row(box, mode, text, func(): _ask(mode))
	b.name = "CtaButton"
	box.add_child(status)
	_update_cta()

func _used_today() -> bool:
	var today := HubKit.paris_date(Time.get_unix_time_from_system())
	for r in _runs:
		if str(r.get("kind", "")) == "hardcore_month" and str(r.get("day", "")) == today:
			return true
	return false

func _update_cta() -> void:
	var status := _body.find_child("CtaStatus", true, false) as Label
	var b := _body.find_child("CtaButton", true, false) as Button
	if status == null or b == null:
		return
	if _mode == "hardcore":
		if not _runs_ok:
			status.text = L.t("ui.hub.loading")
			return
		var used := _used_today()
		b.disabled = used
		status.text = L.t("ui.hub.hc_used") if used else L.t("ui.hub.hc_available")
		status.add_theme_color_override("font_color", HubKit.WARN if used else HubKit.GOOD)
	else:
		var pending := 0
		if _runs_ok:
			for r in _runs:
				if str(r.get("status", "")) == "submitted":
					pending += 1
		status.text = L.fa(L.t("ui.hub.pending"), pending) if pending > 0 else (L.t("ui.hub.weekly_status") if _mode == "weekly" else (L.t("ui.hub.daily_status") if _mode == "daily" else ""))

func _load_runs_for_play() -> void:
	var mine := _gen
	var r: Dictionary = await RankedRun.my_runs()
	if mine != _gen or not _alive():
		return
	_runs = r.data if r.ok and r.data is Array else []
	_runs_ok = r.ok
	if not r.ok and _mode == "hardcore":
		var b := _body.find_child("CtaButton", true, false) as Button
		var status := _body.find_child("CtaStatus", true, false) as Label
		if status != null:
			status.text = L.t("ui.hub.hc_unknown")
		if b != null:
			b.disabled = false
		return
	_update_cta()

## Avertissement si une partie classée est déjà en cours : en lancer une autre l'abandonne (« expirée », sans score).
## Une partie démarrée depuis plus de 2 h 10 est de toute façon déjà expirée : pas d'avertissement.
func _expiry_note() -> String:
	var r: Dictionary = await RankedRun.my_runs(10)
	if not r.ok or not (r.data is Array):
		return ""
	for x in r.data:
		if str(x.get("status", "")) != "started":
			continue
		var t0 := Time.get_unix_time_from_datetime_string(str(x.get("started_at", "")).substr(0, 19))
		if Time.get_unix_time_from_system() - t0 < 7800.0:
			return "\n\n" + L.fa(L.t("ui.hub.expire_warn"), HubKit.short_date(x.get("started_at")))
	return ""

func _ask(mode: String) -> void:
	var note: String = await _expiry_note()
	if not _alive():
		return
	if mode == "weekly":
		var rule: Dictionary = _weekly.get("rule", {})
		var rname := str(rule.get("label_en" if TranslationServer.get_locale().begins_with("en") else "label_fr", ""))
		Dialogs.confirm(_host, L.t("ui.hub.weekly_play"), L.fa(L.t("ui.hub.weekly_confirm"), rname) + note, func(): _start("normal", "weekly"), L.t("ui.challenges.hc_go"), L.t("common.annuler"))
	elif mode == "daily":
		var drule: Dictionary = _daily.get("rule", {})
		var dname := str(drule.get("label_en" if TranslationServer.get_locale().begins_with("en") else "label_fr", ""))
		Dialogs.confirm(_host, L.t("ui.hub.daily_play"), L.fa(L.t("ui.hub.daily_confirm"), dname) + note, func(): _start("normal", "daily"), L.t("ui.challenges.hc_go"), L.t("common.annuler"))
	elif mode == "hardcore":
		Dialogs.confirm(_host, L.t("ui.hub.hc_play"), L.t("ui.hub.hc_confirm") + note, func(): _start("hardcore", "hardcore_month"), L.t("ui.challenges.hc_go"), L.t("common.annuler"))
	else:
		Dialogs.confirm(_host, L.t("ui.hub.ranked_play"), L.fa(L.t("ui.hub.ranked_confirm"), L.t(ChallengesModal.DIFF_KEYS[_diff])) + note,
			func(): _start(_diff, "difficulty"), L.t("ui.challenges.hc_go"), L.t("common.annuler"))

func _start(difficulty: String, kind: String) -> void:
	var r: Dictionary = await RankedRun.launch(difficulty, kind)
	if not r.ok and is_instance_valid(_host):
		Form.alert(_host, str(r.get("message", "")))

# ------------------------------------------------------------------ onglet Classements

func _show_boards() -> void:
	var srcs := HFlowContainer.new()
	srcs.add_theme_constant_override("h_separation", 6)
	srcs.add_theme_constant_override("v_separation", 6)
	_body.add_child(srcs)
	for s in MODES:
		srcs.add_child(_icon_toggle(MODE_GLYPH[s], L.t(MODE_NAME[s]), s == _src, func():
			_src = s
			_show("boards")))
	srcs.add_child(_icon_toggle("crown", L.t("ui.hub.legends"), _src == "legends", func():
		_src = "legends"
		_show("boards")))
	if _src == "ranked":
		var ds := HFlowContainer.new()
		ds.add_theme_constant_override("h_separation", 6)
		_body.add_child(ds)
		for d in RankedRun.DIFFICULTIES:
			ds.add_child(HubKit.toggle(L.t(ChallengesModal.DIFF_KEYS[d]), d == _src_diff, func():
				_src_diff = d
				_show("boards"), 13, 10, 5))
	var card := HubKit.card(UiTheme.BRONZE_DARK, HubKit.CARD_BG, 12)
	_body.add_child(card)
	var box := HubKit.vbox(4)
	card.add_child(box)
	var intro: String = {"free": "ui.hub.bd_free", "ranked": "ui.hub.bd_ranked", "weekly": "ui.hub.bd_weekly", "hardcore": "ui.hub.bd_hardcore", "legends": "ui.hub.bd_legends"}[_src]
	box.add_child(HubKit.label(L.t(intro), UiTheme.DIM, 12))
	var wait := _wait(box)
	_load_board(box, wait, _gen)

func _rows_fit() -> int:
	var vp: Vector2 = _host.get_viewport().get_visible_rect().size if _host.is_inside_tree() else Vector2(1280, 720)
	var avail: float = vp.y * 0.8 - 330.0
	return clampi(int(avail / 30.0), 4, 10)

func _load_board(box: VBoxContainer, wait: Label, mine: int) -> void:
	var rows: Array = []
	var err: Dictionary = {}
	var unit := L.t("ui.challenges.unit_niveaux")
	match _src:
		"legends":
			var gr: Dictionary = await RankedRun.hall()
			if mine != _gen or not _alive():
				return
			wait.queue_free()
			if not gr.ok:
				_error(box, gr)
			elif (gr.data as Array).is_empty():
				box.add_child(HubKit.label(L.t("ui.hub.legends_empty"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
			else:
				_legends_table(box, gr.data)
			_modal.call_deferred("_fit")
			return
		"free":
			var lr: Dictionary = await Challenges.list(true)
			if mine != _gen or not _alive():
				return
			if not lr.ok:
				err = lr
			elif (lr.data as Array).is_empty():
				wait.queue_free()
				box.add_child(HubKit.label(L.t("ui.challenges.none"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
				return
			else:
				var ch: Dictionary = lr.data[0]
				unit = Challenges.unit_label(str(ch.get("unit", "points")))
				var br: Dictionary = await Challenges.board(str(ch.id), 100)
				if mine != _gen or not _alive():
					return
				if br.ok:
					rows = br.data if br.data is Array else []
				else:
					err = br
		"ranked":
			var rr: Dictionary = await RankedRun.board(_src_diff)
			if mine != _gen or not _alive():
				return
			if rr.ok:
				rows = rr.data if rr.data is Array else []
			else:
				err = rr
		"weekly":
			if _weekly.is_empty():
				var wr: Dictionary = await RankedRun.weekly_current()
				if mine != _gen or not _alive():
					return
				if wr.ok and wr.data is Dictionary:
					_weekly = wr.data
			if _weekly.is_empty():
				err = {"ok": false, "error_code": "generic", "message": L.t("ui.hub.weekly_unknown")}
			else:
				unit = L.t(RankedRun.unit_key(str((_weekly.get("rule", {}) as Dictionary).get("metric", "levels"))))
				var kr: Dictionary = await RankedRun.period_board("weekly", str(_weekly.get("period", "")))
				if mine != _gen or not _alive():
					return
				if kr.ok:
					rows = kr.data if kr.data is Array else []
				else:
					err = kr
		"hardcore":
			var hr: Dictionary = await RankedRun.period_board("hardcore_month", _month_key())
			if mine != _gen or not _alive():
				return
			if hr.ok:
				rows = hr.data if hr.data is Array else []
			else:
				err = hr
	wait.queue_free()
	if not err.is_empty():
		_error(box, err)
		return
	if rows.is_empty():
		box.add_child(HubKit.label(L.t("ui.challenges.empty_board") if _src == "free" else (L.t("ui.ranked.empty") if _src == "ranked" else (L.t("ui.hub.weekly_empty") if _src == "weekly" else L.t("ui.challenges.hc_empty"))), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		_modal.call_deferred("_fit")
		return
	_board_table(box, rows, unit)
	_modal.call_deferred("_fit")

## Hall des légendes : un champion par semaine ou par mois clos.
func _legends_table(box: VBoxContainer, rows: Array) -> void:
	var en := TranslationServer.get_locale().begins_with("en")
	var g := GridContainer.new()
	g.columns = 2 if _narrow() else 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(g)
	var n := mini(rows.size(), _rows_fit() * 2)
	for i in n:
		var r: Dictionary = rows[i]
		var weekly := str(r.get("kind", "")) == "weekly"
		var when := L.fa(L.t("ui.hub.weekly_week"), str(r.get("period", "")).get_slice("W", 1)) + " " + str(r.get("period", "")).get_slice("-", 0) if weekly else str(r.get("period", ""))
		g.add_child(HubKit.label(("📅 " if weekly else "🔥 ") + when, UiTheme.DIM, 13, false, false))
		g.add_child(Cosmetics.name_plate(_role_mark(str(r.get("player_id", ""))) + str(r.get("pseudo", "?")), "", str(r.get("frame", "")) if r.get("frame") != null else "", r.get("color"), 15))
		var unit_txt := L.t(RankedRun.unit_key(str(RULE_METRIC.get(str(r.get("rule_id", "")), "levels"))))
		g.add_child(HubKit.label("%d %s · %s" % [int(r.get("score", 0)), unit_txt, Challenges.format_time(int(r.get("seconds", 0)))], GOLD, 13, false, false))
		var rule := (str(r.get("rule_en" if en else "rule_fr", "")) if r.get("rule_fr") != null else "")
		g.add_child(HubKit.label(("%s %s" % [str(r.get("rule_icon", "")), rule]) if rule != "" else "", UiTheme.PARCH, 13, false, false))

func _board_table(box: VBoxContainer, rows: Array, unit: String) -> void:
	var me := Cloud.user_id() if _signed() else ""
	var n := _rows_fit()
	var my_row := -1
	for i in rows.size():
		if me != "" and str(rows[i].get("player_id", "")) == me:
			my_row = i
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(g)
	_cell(g, "#", UiTheme.DIM, 12, 34, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(g, L.t("ui.challenges.col_player"), UiTheme.DIM, 12, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, unit, UiTheme.DIM, 12, 70, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(g, L.t("ui.challenges.col_time"), UiTheme.DIM, 12, 64, HORIZONTAL_ALIGNMENT_RIGHT)
	var shown: Array = []
	for i in mini(n, rows.size()):
		shown.append(i)
	if my_row >= n:
		shown.append(-1)
		shown.append(my_row)
	var any_declared := false
	for i in shown:
		if i == -1:
			for k in 4:
				_cell(g, "…", UiTheme.DIM, 14, 34 if k == 0 else (0 if k == 1 else 64), HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var row: Dictionary = rows[i]
		var mine_row := me != "" and str(row.get("player_id", "")) == me
		var col: Color = GOLD if mine_row else HubKit.rank_color(i)
		var verified := _src != "free" or bool(row.get("verified", false))
		if not verified:
			any_declared = true
		_cell(g, str(i + 1), col, 15, 34, HORIZONTAL_ALIGNMENT_RIGHT)
		var title := Cosmetics.loc(row, "title") if row.get("title_fr") != null else ""
		var plate := Cosmetics.name_plate(_role_mark(str(row.get("player_id", ""))) + str(row.get("pseudo", "?")) + (" ✔" if verified else ""), title,
			str(row.get("frame", "")) if row.get("frame") != null else "", row.get("color") if row.get("color") != null else (col.to_html(false) if (mine_row or i < 3) else null),
			15, int(row.get("level", 0)) if int(row.get("level", 0)) > 1 else 0)
		if _src == "free":
			plate.tooltip_text = _details(row)
		g.add_child(plate)
		_cell(g, str(int(row.get("score", 0))), col, 15, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(g, Challenges.format_time(int(row.get("seconds", -1))) if row.get("seconds") != null else "–", col, 15, 64, HORIZONTAL_ALIGNMENT_RIGHT)
	if my_row < 0 and _signed():
		box.add_child(HubKit.label(L.t("ui.hub.not_ranked"), UiTheme.DIM, 12, false, true, HORIZONTAL_ALIGNMENT_CENTER))
	if any_declared:
		box.add_child(HubKit.label(L.t("ui.challenges.declared_note"), UiTheme.DIM, 12, false, true, HORIZONTAL_ALIGNMENT_CENTER))
	elif _src != "free":
		box.add_child(HubKit.label(L.t("ui.challenges.hc_verified_note"), UiTheme.DIM, 12, false, true, HORIZONTAL_ALIGNMENT_CENTER))

func _cell(g: GridContainer, text: String, color: Color, size: int, min_w: float, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align as HorizontalAlignment
	l.custom_minimum_size = Vector2(min_w, 0)
	if min_w <= 0.0:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	g.add_child(l)
	return l

func _details(row: Dictionary) -> String:
	var d: Dictionary = row.get("details") if row.get("details") is Dictionary else {}
	var parts: Array = []
	if d.has("expeditions"):
		parts.append(L.fa(L.t("ui.challenges.d_expeditions"), int(d.expeditions)))
	if str(d.get("difficulty", "")) != "":
		var diff := str(d.difficulty)
		parts.append(L.fa(L.t("ui.challenges.d_difficulty"), L.t(ChallengesModal.DIFF_KEYS[diff]) if ChallengesModal.DIFF_KEYS.has(diff) else diff))
	if d.has("kills"):
		parts.append(L.fa(L.t("ui.challenges.d_kills"), int(d.kills)))
	return "\n".join(parts)

# ------------------------------------------------------------------ onglet Récompenses

var _cat: Array = []
var _owned: Dictionary = {}
var _sel := {"title": "", "frame": "", "color": ""}
var _preview_box: VBoxContainer
var _eq_status: Label

func _show_rewards() -> void:
	if not _signed():
		_body.add_child(HubKit.label(L.t("ui.rewards.need_account"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var wait := _wait(_body)
	_load_rewards(wait, _gen)

func _load_rewards(wait: Label, mine: int) -> void:
	var cat: Dictionary = await RankedRun.badges()
	var mb: Dictionary = await RankedRun.my_badges()
	var xp: Dictionary = await RankedRun.my_xp()
	var eq: Dictionary = await Cloud.request(HTTPClient.METHOD_GET, "/rest/v1/player_cosmetics?player_id=eq.%s&select=title_badge,frame_badge,color_badge" % Cloud.user_id())
	if mine != _gen or not _alive():
		return
	wait.queue_free()
	if not cat.ok:
		_error(_body, cat)
		return
	_cat = cat.data
	_owned = {}
	if mb.ok:
		for b in mb.data:
			_owned[str(b.badge_id)] = true
		Unlocks.set_owned(_owned.keys())
	var total_xp := 0
	if xp.ok and xp.data is Array and not (xp.data as Array).is_empty():
		total_xp = int(xp.data[0].get("xp", 0))
	if eq.ok and eq.data is Array and not (eq.data as Array).is_empty():
		var e: Dictionary = eq.data[0]
		_sel = {"title": str(e.get("title_badge", "")) if e.get("title_badge") != null else "",
			"frame": str(e.get("frame_badge", "")) if e.get("frame_badge") != null else "",
			"color": str(e.get("color_badge", "")) if e.get("color_badge") != null else ""}
	_build_rewards(total_xp)

var _rw_xp := 0

func _build_rewards(total_xp: int) -> void:
	_rw_xp = total_xp
	var lvl := Cosmetics.level_of(total_xp)
	var top := (HBoxContainer.new() if not _narrow() else VBoxContainer.new()) as BoxContainer
	top.add_theme_constant_override("separation", 8)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(top)
	# niveau
	var c1 := HubKit.card()
	c1.size_flags_stretch_ratio = 0.8
	top.add_child(c1)
	var v1 := HubKit.vbox(4)
	c1.add_child(v1)
	v1.add_child(HubKit.label(L.fa(L.t("ui.hub.level"), lvl), GOLD, 22, true, false))
	v1.add_child(HubKit.progress(total_xp, Cosmetics.xp_for_level(lvl), Cosmetics.xp_for_level(lvl + 1), 12))
	v1.add_child(HubKit.label(L.fa(L.t("ui.rewards.next"), [Cosmetics.xp_for_level(lvl + 1) - total_xp, lvl + 1]), UiTheme.DIM, 12))
	var nxt := _next_level_reward(lvl)
	if not nxt.is_empty():
		v1.add_child(HubKit.label(L.fa(L.t("ui.rewards.next_reward"), [int(nxt.level), "%s %s" % [str(nxt.badge.get("icon", "🏅")), Cosmetics.loc(nxt.badge, "label")]]), GOLD, 12))
	v1.add_child(HubKit.label(L.fa(L.t("ui.rewards.collection"), [_owned.size(), _cat.size()]), UiTheme.PARCH, 14, true))
	v1.add_child(HubKit.label(L.t("ui.hub.xp_how"), UiTheme.DIM, 12))
	# cosmétiques
	var c2 := HubKit.card()
	top.add_child(c2)
	var v2 := HubKit.vbox(5)
	c2.add_child(v2)
	_preview_box = HubKit.vbox(0)
	v2.add_child(_preview_box)
	_refresh_preview()
	_picker(v2, "title", L.t("ui.rewards.pick_title"), func(b: Dictionary): return b.get("title_fr") != null)
	_picker(v2, "frame", L.t("ui.rewards.pick_frame"), func(b: Dictionary): return b.get("frame") != null)
	_picker(v2, "color", L.t("ui.rewards.pick_color"), func(b: Dictionary): return b.get("color") != null)
	_skin_picker(v2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(HubKit.button(L.t("ui.rewards.equip"), _equip, true, 34))
	_eq_status = HubKit.label("", UiTheme.DIM, 12, false, true)
	row.add_child(_eq_status)
	v2.add_child(row)
	v2.add_child(HubKit.label(L.t("ui.rewards.equip_hint"), UiTheme.DIM, 11))
	# parcourir les récompenses par type
	_rewards_browser()
	_modal.call_deferred("_fit")

const REWARD_KINDS := [["all", "ui.rewards.k_all"], ["title", "ui.rewards.k_title"], ["frame", "ui.rewards.k_frame"], ["color", "ui.rewards.k_color"], ["skin", "ui.rewards.k_skin"]]
const REWARD_FILTERS := [["all", "ui.rewards.f_all"], ["todo", "ui.rewards.f_todo"], ["done", "ui.rewards.f_done"]]
var _rw_kind := "all"
var _rw_filter := "all"
var _rw_box: VBoxContainer

## Entrées d'un type de récompense : [{b: badge, s: anneau (skin) ou {}, have: bool}].
func _rw_entries(kind: String) -> Array:
	var out: Array = []
	if kind == "skin":
		for s in Unlocks.skins():
			var ub := str(s.get("unlockBadge", ""))
			out.append({"b": _badge_by_id(ub), "s": s, "have": _owned.has(ub)})
		return out
	for b in _cat:
		var ok := true
		match kind:
			"title": ok = b.get("title_fr") != null
			"frame": ok = b.get("frame") != null
			"color": ok = b.get("color") != null
		if ok:
			out.append({"b": b, "s": {}, "have": _owned.has(str(b.id))})
	return out

func _rewards_browser() -> void:
	_body.add_child(HubKit.label(L.t("ui.rewards.browse_hint"), UiTheme.DIM, 12, false, true))
	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", 6)
	kinds.add_theme_constant_override("v_separation", 6)
	_body.add_child(kinds)
	for k in REWARD_KINDS:
		var es := _rw_entries(k[0])
		var have := 0
		for e in es:
			if e.have:
				have += 1
		var kk: String = k[0]
		kinds.add_child(HubKit.toggle("%s (%d/%d)" % [L.t(k[1]), have, es.size()], _rw_kind == kk, func():
			_rw_kind = kk
			_show_rewards_again.call_deferred(), 14, 12, 6))
	var flt := HFlowContainer.new()
	flt.add_theme_constant_override("h_separation", 6)
	_body.add_child(flt)
	for f in REWARD_FILTERS:
		var ff: String = f[0]
		flt.add_child(HubKit.toggle(L.t(f[1]), _rw_filter == ff, func():
			_rw_filter = ff
			_show_rewards_again.call_deferred(), 13, 10, 4))
	_rw_box = HubKit.vbox(6)
	_body.add_child(_rw_box)
	_rw_render()

## Reconstruit l'onglet (sans nouvelle requête réseau pour les données déjà chargées).
func _show_rewards_again() -> void:
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	_build_rewards(_rw_xp)

func _rw_render() -> void:
	for ch in _rw_box.get_children():
		_rw_box.remove_child(ch)
		ch.queue_free()
	var es := _rw_entries(_rw_kind)
	var shown: Array = []
	for e in es:
		if _rw_filter == "todo" and e.have:
			continue
		if _rw_filter == "done" and not e.have:
			continue
		shown.append(e)
	# obtenues d'abord, puis celles à obtenir ; dans chaque groupe, par rareté croissante (tri stable : ordre du catalogue à rareté égale)
	var rank := {}
	for i in shown.size():
		rank[shown[i]] = i
	shown.sort_custom(func(a, b):
		if a.have != b.have:
			return a.have
		var ra := int(a.b.get("rarity", 1))
		var rb := int(b.b.get("rarity", 1))
		if ra != rb:
			return ra < rb
		return int(rank[a]) < int(rank[b]))
	if shown.is_empty():
		_rw_box.add_child(HubKit.label(L.t("ui.rewards.empty"), UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	if _rw_kind == "all":
		var g := GridContainer.new()
		g.columns = 3 if _narrow() else 5
		g.add_theme_constant_override("h_separation", 6)
		g.add_theme_constant_override("v_separation", 6)
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rw_box.add_child(g)
		for e in shown:
			g.add_child(_badge_tile(e.b))
		return
	var g2 := GridContainer.new()
	g2.columns = 1 if _narrow() else 2
	g2.add_theme_constant_override("h_separation", 6)
	g2.add_theme_constant_override("v_separation", 6)
	g2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rw_box.add_child(g2)
	for e in shown:
		g2.add_child(_reward_row(_rw_kind, e))

func _reward_row(kind: String, e: Dictionary) -> Control:
	var b: Dictionary = e.b
	var have: bool = e.have
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Cosmetics.RARITY_COLORS[clampi(int(b.get("rarity", 1)) - 1, 0, 4)] if have else Color(1, 1, 1, 0.1)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	# aperçu
	match kind:
		"title":
			v.add_child(Cosmetics.name_plate(Cloud.pseudo(), Cosmetics.loc(b, "title"), "", null, 16))
		"frame":
			v.add_child(Cosmetics.name_plate(Cloud.pseudo(), "", str(b.frame), null, 16))
		"color":
			v.add_child(Cosmetics.name_plate(Cloud.pseudo(), "", "", b.color, 16))
		"skin":
			var s: Dictionary = e.s
			var ring := Panel.new()
			var rs := StyleBoxFlat.new()
			rs.bg_color = Color(0, 0, 0, 0.35)
			rs.set_corner_radius_all(24)
			rs.set_border_width_all(4)
			rs.border_color = Color(str(s.get("color", "#ffffff")))
			ring.add_theme_stylebox_override("panel", rs)
			ring.custom_minimum_size = Vector2(48, 48)
			ring.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			v.add_child(ring)
			v.add_child(HubKit.label("%s %s" % [str(s.get("icon", "")), _skin_label(s)], UiTheme.PARCH, 13, true, true))
	if not b.is_empty():
		v.add_child(HubKit.label("%s %s" % [str(b.get("icon", "🏅")), Cosmetics.loc(b, "label")], GOLD if have else UiTheme.PARCH, 13, true, true))
		var how := Cosmetics.loc(b, "desc")
		v.add_child(HubKit.label(L.fa(L.t("ui.rewards.how_skin" if kind == "skin" else "ui.rewards.how"), how), UiTheme.DIM, 12, false, true))
	v.add_child(HubKit.label(L.t("ui.rewards.t_have") if have else L.t("ui.rewards.t_todo"), HubKit.GOOD if have else GOLD, 12, true))
	p.modulate = Color.WHITE if have else Color(1, 1, 1, 0.85)
	return p

## Colonnes des listes de choix : étiquettes de largeur fixe, listes alignées et plus étroites.
const PICK_LABEL_W := 150.0
const PICK_BOX_W := 250.0

func _picker(parent: Control, kind: String, label: String, offers: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := HubKit.label(label, UiTheme.DIM, 13, false, false)
	l.custom_minimum_size.x = PICK_LABEL_W
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size.x = PICK_BOX_W
	ob.clip_text = true
	ob.add_item(L.t("ui.rewards.none"))
	ob.set_item_metadata(0, "")
	var cur := 0
	for b in _cat:
		if _owned.has(str(b.id)) and offers.call(b):
			ob.add_item(str(b.get("icon", "🏅")) + " " + (Cosmetics.loc(b, "title") if kind == "title" else Cosmetics.loc(b, "label")))
			ob.set_item_metadata(ob.item_count - 1, str(b.id))
			if str(b.id) == _sel[kind]:
				cur = ob.item_count - 1
	ob.select(cur)
	ob.item_selected.connect(func(i: int):
		_sel[kind] = str(ob.get_item_metadata(i))
		_refresh_preview())
	row.add_child(ob)
	parent.add_child(row)

## Apparence des héros : couleur de l'anneau des portraits en partie (gardée sur cet appareil).
func _skin_picker(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := HubKit.label(L.t("ui.rewards.pick_skin"), UiTheme.DIM, 13, false, false)
	l.custom_minimum_size.x = PICK_LABEL_W
	row.add_child(l)
	var ob := OptionButton.new()
	ob.custom_minimum_size.x = PICK_BOX_W
	ob.clip_text = true
	ob.add_item(L.t("ui.rewards.none"))
	ob.set_item_metadata(0, "")
	var cur := 0
	var total := 0
	for s in Unlocks.skins():
		total += 1
		if _owned.has(str(s.unlockBadge)):
			ob.add_item("%s %s" % [str(s.icon), _skin_label(s)])
			ob.set_item_metadata(ob.item_count - 1, str(s.id))
			if str(s.id) == Unlocks.skin_id():
				cur = ob.item_count - 1
	ob.select(cur)
	ob.tooltip_text = L.fa(L.t("ui.rewards.skin_tip"), [ob.item_count - 1, total])
	ob.item_selected.connect(func(i: int):
		Unlocks.set_skin(str(ob.get_item_metadata(i)))
		if _eq_status != null and is_instance_valid(_eq_status):
			_eq_status.text = L.t("ui.rewards.skin_saved")
			_eq_status.add_theme_color_override("font_color", HubKit.GOOD))
	row.add_child(ob)
	parent.add_child(row)

## Prochain palier de niveau de compte (badge « lvl_<n> ») au-dessus du niveau actuel : {level, badge} ou {}.
func _next_level_reward(lvl: int) -> Dictionary:
	var best: Dictionary = {}
	for b in _cat:
		var id := str(b.id)
		if not id.begins_with("lvl_") or not id.substr(4).is_valid_int():
			continue
		var n := id.substr(4).to_int()
		if n > lvl and (best.is_empty() or n < int(best.level)):
			best = {"level": n, "badge": b}
	return best

func _skin_label(s: Dictionary) -> String:
	var en := str(s.get("labelEn", ""))
	return en if Data.lang == "en" and en != "" else str(s.get("labelFr", ""))

func _badge_by_id(id: String) -> Dictionary:
	for b in _cat:
		if str(b.id) == id:
			return b
	return {}

func _refresh_preview() -> void:
	if _preview_box == null or not is_instance_valid(_preview_box):
		return
	for ch in _preview_box.get_children():
		_preview_box.remove_child(ch)
		ch.queue_free()
	var t := _badge_by_id(_sel.title)
	var f := _badge_by_id(_sel.frame)
	var co := _badge_by_id(_sel.color)
	_preview_box.add_child(Cosmetics.name_plate(Cloud.pseudo(), Cosmetics.loc(t, "title") if not t.is_empty() else "",
		str(f.get("frame", "")) if not f.is_empty() else "", co.get("color") if not co.is_empty() else null, 20))

func _badge_tile(b: Dictionary) -> Control:
	var have := _owned.has(str(b.id))
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.28)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = Cosmetics.RARITY_COLORS[clampi(int(b.get("rarity", 1)) - 1, 0, 4)] if have else Color(1, 1, 1, 0.1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.modulate = Color.WHITE if have else Color(1, 1, 1, 0.42)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(HubKit.label(str(b.get("icon", "🏅")), UiTheme.PARCH, 28, false, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(HubKit.label(Cosmetics.loc(b, "label"), GOLD if have else UiTheme.PARCH, 12, true, true, HORIZONTAL_ALIGNMENT_CENTER))
	var tip := "%s\n%s" % [Cosmetics.loc(b, "label"), Cosmetics.loc(b, "desc")]
	if b.get("title_fr") != null:
		tip += "\n" + L.fa(L.t("ui.rewards.gives_title"), Cosmetics.loc(b, "title"))
	if b.get("frame") != null:
		tip += "\n" + L.fa(L.t("ui.rewards.gives_frame"), str(b.frame))
	if b.get("color") != null:
		tip += "\n" + L.t("ui.rewards.gives_color")
	p.tooltip_text = tip
	v.add_child(HubKit.label(Cosmetics.loc(b, "desc"), UiTheme.DIM, 11, false, true, HORIZONTAL_ALIGNMENT_CENTER))
	return p

func _equip() -> void:
	var r: Dictionary = await RankedRun.equip(_sel.title, _sel.frame, _sel.color)
	if not _alive() or _eq_status == null or not is_instance_valid(_eq_status):
		return
	_eq_status.text = L.t("ui.rewards.equipped") if r.ok else str(r.message)
	_eq_status.add_theme_color_override("font_color", HubKit.GOOD if r.ok else HubKit.BAD)

# ------------------------------------------------------------------ onglet Mes parties

func _show_runs() -> void:
	if not _signed():
		_body.add_child(HubKit.label(L.t("ui.hub.runs_need_account"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var card := HubKit.card()
	_body.add_child(card)
	var box := HubKit.vbox(4)
	card.add_child(box)
	box.add_child(HubKit.label(L.t("ui.hub.runs_intro"), UiTheme.DIM, 12))
	var wait := _wait(box)
	_load_runs(box, wait, _gen)

## Nombre de parties lues pour le résumé et l'histogramme (le tableau n'en montre que quelques-unes).
const RUNS_STATS_LIMIT := 100

func _load_runs(box: VBoxContainer, wait: Label, mine: int) -> void:
	var r: Dictionary = await RankedRun.my_runs(RUNS_STATS_LIMIT)
	if mine != _gen or not _alive():
		return
	wait.queue_free()
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	_runs = r.data
	_runs_ok = true
	_runs_holder = HubKit.vbox(4)
	box.add_child(_runs_holder)
	_render_runs(mine)
	# compte à rebours / temps écoulé à côté de « En cours » et « En attente » ; tant qu'une partie attend sa vérification, la liste se rafraîchit seule
	var tm := Timer.new()
	tm.wait_time = 1.0
	tm.autostart = true
	tm.timeout.connect(_tick_runs.bind(mine))
	box.add_child(tm)

## Dessine le tableau des parties (dans `_runs_holder`, reconstruit à chaque rafraîchissement).
func _render_runs(mine: int) -> void:
	for ch in _runs_holder.get_children():
		ch.queue_free()
	_run_clocks.clear()
	if _runs.is_empty():
		_runs_holder.add_child(HubKit.label(L.t("ui.hub.runs_none"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	_render_runs_stats()
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_runs_holder.add_child(g)
	_cell(g, L.t("ui.sadmin.col_date"), UiTheme.DIM, 12, 82, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.sadmin.col_mode"), UiTheme.DIM, 12, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.sadmin.col_status"), UiTheme.DIM, 12, 150, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.hub.col_score"), UiTheme.DIM, 12, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(g, L.t("ui.challenges.col_time"), UiTheme.DIM, 12, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	var n := clampi(_rows_fit(), 5, 10)
	for i in mini(n, _runs.size()):
		var x: Dictionary = _runs[i]
		var st := str(x.get("status", ""))
		var col := HubKit.GOOD if st == "verified" else (HubKit.BAD if st == "rejected" else (HubKit.WARN if st == "submitted" or st == "started" else UiTheme.DIM))
		_cell(g, SuperAdminModal.date(x.get("started_at")), UiTheme.PARCH, 13, 82, HORIZONTAL_ALIGNMENT_LEFT)
		_cell(g, SuperAdminModal.mode_name(str(x.get("difficulty", "")), str(x.get("kind", ""))), UiTheme.PARCH, 13, 0, HORIZONTAL_ALIGNMENT_LEFT)
		var base := L.t(STATUS_KEYS[st]) if STATUS_KEYS.has(st) else st
		var sl := _cell(g, base, col, 13, 150, HORIZONTAL_ALIGNMENT_LEFT)
		var since: Variant = x.get("submitted_at") if st == "submitted" and x.get("submitted_at") != null else x.get("started_at")
		if st == "submitted" or st == "started":
			_run_clocks.append({"label": sl, "base": base, "t0": _utc(since)})
			sl.text = "%s · %s" % [base, _elapsed(maxf(0.0, Time.get_unix_time_from_system() - _utc(since)))]
			sl.tooltip_text = L.t("ui.hub.wait_tip") if st == "submitted" else L.t("ui.hub.started_tip")
			sl.mouse_filter = Control.MOUSE_FILTER_STOP
		if st == "rejected" and x.get("reject_reason") != null:
			sl.tooltip_text = str(x.reject_reason)
			sl.mouse_filter = Control.MOUSE_FILTER_STOP
		_cell(g, str(int(x.score)) if x.get("score") != null else "–", UiTheme.PARCH, 13, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(g, Challenges.format_time(int(x.seconds)) if x.get("seconds") != null else "–", UiTheme.PARCH, 13, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	_runs_holder.add_child(HubKit.label(L.t("ui.hub.runs_legend"), UiTheme.DIM, 11))
	_modal.call_deferred("_fit")

## Résumé chiffré des parties du joueur et histogramme de ses scores (une barre par partie vérifiée, de la plus ancienne à la plus récente).
func _render_runs_stats() -> void:
	var verified: Array = _runs.filter(func(x): return str(x.get("status", "")) == "verified" and x.get("score") != null)
	if verified.is_empty():
		return
	var best := 0
	var total := 0
	for x in verified:
		best = maxi(best, int(x.score))
		total += int(x.score)
	var avg := "%.1f" % (float(total) / float(verified.size()))
	_runs_holder.add_child(HubKit.label(L.fa(L.t("ui.hub.runs_stats"), [_runs.size(), verified.size(), best, avg]), UiTheme.GOLD, 13))
	if verified.size() < 2:
		return
	var recent: Array = verified.slice(0, 20)
	recent.reverse()
	var vals: Array = []
	var labs: Array = []
	for x in recent:
		vals.append(int(x.score))
		labs.append(HubKit.short_date(x.get("started_at")))
	_runs_holder.add_child(HubKit.label(L.t("ui.hub.runs_chart"), UiTheme.DIM, 11))
	var bars := MiniBars.new().setup(vals, labs, Color("7fae4a"))
	_runs_holder.add_child(bars)

## Secondes UNIX (UTC) d'un horodatage ISO renvoyé par la base.
static func _utc(v: Variant) -> float:
	var t := str(v)
	return float(Time.get_unix_time_from_datetime_string(t.substr(0, 19))) if t.length() >= 19 else Time.get_unix_time_from_system()

## Durée écoulée : m:ss, puis « 1 h 05 », puis « 2 j ».
static func _elapsed(secs: float) -> String:
	var s := int(secs)
	if s < 3600:
		return "%d:%02d" % [s / 60, s % 60]
	if s < 86400:
		return "%d h %02d" % [s / 3600, (s % 3600) / 60]
	return "%d j" % (s / 86400)

func _tick_runs(mine: int) -> void:
	if mine != _gen or not _alive():
		return
	var now := Time.get_unix_time_from_system()
	for c in _run_clocks:
		if is_instance_valid(c.label):
			(c.label as Label).text = "%s · %s" % [c.base, _elapsed(maxf(0.0, now - float(c.t0)))]
	_run_poll += 1
	if _run_poll < 6 or _run_busy or not _runs.any(func(x): return str(x.get("status", "")) == "submitted"):
		return
	_run_poll = 0
	_run_busy = true
	var r: Dictionary = await RankedRun.my_runs(RUNS_STATS_LIMIT)
	_run_busy = false
	if mine != _gen or not _alive() or not r.ok or not (r.data is Array):
		return
	var sig := func(a: Array) -> String:
		return ",".join(a.map(func(x): return "%s:%s" % [str(x.get("id", "")), str(x.get("status", ""))]))
	if sig.call(r.data) != sig.call(_runs):
		_runs = r.data
		_render_runs(mine)
