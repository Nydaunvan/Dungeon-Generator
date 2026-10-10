class_name OnlineHub
extends RefCounted
## Fenêtre unique du mode en ligne, dans le cadre habituel : un bandeau « mon compte » toujours visible, quatre onglets
##  🎮 Jouer (choix du mode : partie libre, partie classée, Hardcore du mois — avec ce que chacun implique),
##  🏆 Classements, 🏅 Récompenses, 📜 Mes parties.
## Rien ne défile en usage normal : chaque onglet tient dans la fenêtre (les lignes des classements s'adaptent à la hauteur disponible).

const TABS := [["play", "ui.hub.tab_play", "🎮"], ["boards", "ui.hub.tab_boards", "🏆"], ["rewards", "ui.hub.tab_rewards", "🏅"], ["runs", "ui.hub.tab_runs", "📜"]]
const MODES := ["free", "ranked", "hardcore"]
const MODE_ICON := {"free": "🎲", "ranked": "🏆", "hardcore": "🔥"}
const MODE_NAME := {"free": "ui.hub.mode_free", "ranked": "ui.hub.mode_ranked", "hardcore": "ui.hub.mode_hardcore"}
const MODE_TAG := {"free": "ui.hub.tag_free", "ranked": "ui.hub.tag_ranked", "hardcore": "ui.hub.tag_hardcore"}
const XP_MULT := {"easy": "×1", "normal": "×1,5", "hard": "×2", "hardcore": "×3"}
const STATUS_KEYS := {"started": "ui.hub.st_started", "submitted": "ui.hub.st_submitted", "verified": "ui.hub.st_verified",
	"rejected": "ui.hub.st_rejected", "expired": "ui.hub.st_expired"}
const GOLD := Color("e8b45c")

var _host: Node
var _modal: Modal
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
var _runs: Array = []
var _runs_ok := false
var _width := 760.0

## `on_launch` : appelé quand le joueur lance une partie libre (la fenêtre est alors fermée) ; `tab` : onglet affiché d'abord.
static func open(host: Node, on_launch: Callable = Callable(), tab: String = "play") -> OnlineHub:
	var h := OnlineHub.new()
	h._host = host
	h._on_launch = on_launch
	h._tab = tab
	var vp: Vector2 = host.get_viewport().get_visible_rect().size if host.is_inside_tree() else Vector2(1280, 720)
	h._width = clampf(vp.x * 0.94, 340.0, 940.0)
	h._modal = Modal.open(host, L.t("ui.hub.title"), h._width)
	h._modal.fit_ratio = 0.8
	h._modal.closed.connect(h._on_closed)
	Cloud.session_changed.connect(h._on_session)
	h._build()
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
	return _width < 640.0 or UiMetrics.portrait

func _online() -> bool:
	return Cloud.is_configured()

func _signed() -> bool:
	return Cloud.is_configured() and Cloud.is_signed_in()

# ------------------------------------------------------------------ structure

func _build() -> void:
	var c := _modal.content
	c.add_theme_constant_override("separation", 8)
	_strip_box = HubKit.vbox(0)
	c.add_child(_strip_box)
	_fill_strip()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	c.add_child(tabs)
	for t in TABS:
		var id: String = t[0]
		var b := HubKit.toggle("%s %s" % [t[2], L.t(t[1])] if not _narrow() else str(t[2]), id == _tab, func(): _show(id), 15, 10, 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = L.t(t[1])
		tabs.add_child(b)
		_tab_buttons[id] = b
	_body = HubKit.vbox(8)
	c.add_child(_body)
	_modal.set_buttons([{"text": L.t("ui.hub.back"), "cb": func(): _modal.close()}])
	_show(_tab)

func _show(tab: String) -> void:
	_tab = tab
	_gen += 1
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).button_pressed = t == tab
	for ch in _body.get_children():
		_body.remove_child(ch)
		ch.queue_free()
	match tab:
		"play": _show_play()
		"boards": _show_boards()
		"rewards": _show_rewards()
		"runs": _show_runs()
	_modal.call_deferred("_fit")

func _wait(parent: Control) -> Label:
	var l := HubKit.label(L.t("ui.hub.loading"), UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER)
	parent.add_child(l)
	return l

func _error(parent: Control, r: Dictionary) -> void:
	parent.add_child(HubKit.label(str(r.get("message", "")), HubKit.BAD, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER))

# ------------------------------------------------------------------ bandeau « mon compte »

func _fill_strip() -> void:
	for ch in _strip_box.get_children():
		_strip_box.remove_child(ch)
		ch.queue_free()
	var card := HubKit.card(UiTheme.BRONZE, Color(0.1, 0.07, 0.04, 0.6), 10)
	_strip_box.add_child(card)
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	h.add_theme_constant_override("v_separation", 6)
	card.add_child(h)
	var left := HubKit.vbox(2)
	left.custom_minimum_size.x = 200
	h.add_child(left)
	if _signed():
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(HubKit.label("👤 " + Cloud.pseudo(), GOLD, 17, true, false))
		var lv := HubKit.label("", UiTheme.DIM, 13, false, false)
		lv.name = "Level"
		top.add_child(lv)
		left.add_child(top)
		var bar := HubKit.progress(0, 0, 1, 8)
		bar.name = "XpBar"
		left.add_child(bar)
		var xl := HubKit.label("", UiTheme.DIM, 12, false, false)
		xl.name = "XpText"
		left.add_child(xl)
		_load_xp()
	else:
		left.add_child(HubKit.label(L.t("ui.hub.offline_title") if _online() else L.t("ui.hub.unavailable_title"), GOLD, 16, true, false))
		left.add_child(HubKit.label(L.t("ui.hub.offline_text") if _online() else L.t("ui.challenges.not_configured"), UiTheme.DIM, 12))
	var right := HFlowContainer.new()
	right.add_theme_constant_override("h_separation", 6)
	right.add_theme_constant_override("v_separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = FlowContainer.ALIGNMENT_END
	h.add_child(right)
	if _online() and not _signed():
		right.add_child(HubKit.button(L.t("ui.hub.sign_in"), func(): AccountModal.open(_host), true, 34))
	if _signed():
		right.add_child(HubKit.button("💬 " + L.t("ui.chat.header"), func(): ChatModal.open(_host), false, 34))
		right.add_child(HubKit.button("👤 " + L.t("ui.cloud.header"), func(): AccountModal.open(_host), false, 34))
	right.add_child(HubKit.button(L.t("ui.help.how"), func(): DocModal.guide(_host, "defis"), false, 34))

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
	var lv := _strip_box.find_child("Level", true, false) as Label
	var bar := _strip_box.find_child("XpBar", true, false) as ProgressBar
	var xt := _strip_box.find_child("XpText", true, false) as Label
	if lv != null:
		lv.text = L.fa(L.t("ui.hub.level"), lvl)
	if bar != null:
		bar.min_value = lo
		bar.max_value = hi
		bar.value = _xp
	if xt != null:
		xt.text = L.fa(L.t("ui.hub.xp_next"), [hi - _xp, lvl + 1])

# ------------------------------------------------------------------ onglet Jouer

func _show_play() -> void:
	var tiles := (HBoxContainer.new() if not _narrow() else VBoxContainer.new()) as BoxContainer
	tiles.add_theme_constant_override("separation", 8)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(tiles)
	for m in MODES:
		tiles.add_child(_tile(m))
	var detail := HubKit.card(UiTheme.BRONZE_DARK, HubKit.CARD_BG, 14)
	_body.add_child(detail)
	var box := HubKit.vbox(8)
	detail.add_child(box)
	_fill_mode(box)
	if (_mode == "hardcore" or _mode == "ranked") and _signed() and not _runs_ok:
		_load_runs_for_play()

func _tile(m: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = m == _mode
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 58 if _narrow() else 74)
	HubKit.style_toggle(b, 10, 6)
	b.pressed.connect(func():
		_mode = m
		_show("play"))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := HubKit.label(str(MODE_ICON[m]), UiTheme.PARCH, 28, false, false, HORIZONTAL_ALIGNMENT_CENTER)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := HubKit.label(L.t(MODE_NAME[m]), GOLD if m == _mode else UiTheme.PARCH, 16, true)
	t1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t1)
	var t2 := HubKit.label(L.t(MODE_TAG[m]), UiTheme.DIM, 12)
	t2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t2)
	h.add_child(v)
	b.add_child(h)
	return b

func _fill_mode(box: VBoxContainer) -> void:
	var cols := 1 if _narrow() else 2
	match _mode:
		"free":
			box.add_child(HubKit.label("🎲  " + L.t("ui.hub.mode_free"), GOLD, 20, true, false))
			box.add_child(HubKit.label(L.t("ui.hub.free_desc"), UiTheme.PARCH, 14))
			if _on_launch.is_valid():
				box.add_child(HubKit.button(L.t("ui.hub.free_play"), func():
					_modal.close()
					_on_launch.call(), true, 46))
			else:
				box.add_child(HubKit.label(L.t("ui.hub.free_home"), UiTheme.DIM, 13, false, true, HORIZONTAL_ALIGNMENT_CENTER))
			HubKit.facts(box, [
				["📊", L.t("ui.hub.f_board"), L.t("ui.hub.free_board")],
				["⏹", L.t("ui.hub.f_quit"), L.t("ui.hub.free_quit")],
				["💾", L.t("ui.hub.f_save"), L.t("ui.hub.free_save")],
				["🛠", L.t("ui.hub.f_editor"), L.t("ui.hub.free_editor")],
			], cols)
		"ranked":
			box.add_child(HubKit.label("🏆  " + L.t("ui.hub.mode_ranked"), GOLD, 20, true, false))
			box.add_child(HubKit.label(L.t("ui.hub.ranked_desc"), UiTheme.PARCH, 14))
			var chips := HFlowContainer.new()
			chips.add_theme_constant_override("h_separation", 6)
			chips.add_theme_constant_override("v_separation", 6)
			box.add_child(chips)
			for d in RankedRun.DIFFICULTIES:
				chips.add_child(HubKit.toggle("%s · XP %s" % [L.t(ChallengesModal.DIFF_KEYS[d]), XP_MULT[d]], d == _diff, func():
					_diff = d
					_show("play"), 14, 12, 7))
			_cta(box, "ranked")
			box.add_child(HubKit.label(L.t("ui.hub.ranked_dungeon"), UiTheme.DIM, 12))
			HubKit.facts(box, [
				["⚖", L.t("ui.hub.f_fair"), L.t("ui.hub.ranked_fair")],
				["📊", L.t("ui.hub.f_board"), L.t("ui.hub.ranked_board")],
				["⏹", L.t("ui.hub.f_quit"), L.t("ui.hub.ranked_quit")],
				["⭐", L.t("ui.hub.f_reward"), L.t("ui.hub.ranked_reward")],
				["🚫", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
				["🔁", L.t("ui.hub.f_tries"), L.t("ui.hub.ranked_tries")],
			], cols)
		"hardcore":
			var key := _month_key()
			box.add_child(HubKit.label("🔥  " + L.fa(L.t("ui.hub.hc_title"), key.substr(5) + "/" + key.substr(0, 4)), HubKit.FIRE, 20, true, false))
			box.add_child(HubKit.label(L.t("ui.hub.hc_desc"), UiTheme.PARCH, 14))
			_cta(box, "hardcore")
			HubKit.facts(box, [
				["🎯", L.t("ui.hub.f_dungeon"), L.t("ui.hub.hc_dungeon")],
				["⏳", L.t("ui.hub.f_tries"), L.t("ui.hub.hc_tries"), HubKit.WARN],
				["⏹", L.t("ui.hub.f_quit"), L.t("ui.hub.hc_quit")],
				["📊", L.t("ui.hub.f_board"), L.t("ui.hub.hc_board")],
				["🎖", L.t("ui.hub.f_reward"), L.t("ui.hub.hc_reward")],
				["🚫", L.t("ui.hub.f_forbidden"), L.t("ui.hub.ranked_forbidden"), HubKit.WARN],
			], cols)

func _month_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d" % [int(d.year), int(d.month)]

## Bas de fiche : état (essai du jour, partie en attente…) et bouton de lancement.
func _cta(box: VBoxContainer, mode: String) -> void:
	var status := HubKit.label("", UiTheme.DIM, 13, true, true, HORIZONTAL_ALIGNMENT_CENTER)
	status.name = "CtaStatus"
	box.add_child(status)
	if not _online():
		status.text = L.t("ui.challenges.not_configured")
		return
	if not _signed():
		status.text = L.t("ui.hub.need_account")
		status.add_theme_color_override("font_color", HubKit.WARN)
		box.add_child(HubKit.button(L.t("ui.hub.sign_in"), func(): AccountModal.open(_host), true, 46))
		return
	var b := HubKit.button(L.t("ui.hub.ranked_play") if mode == "ranked" else L.t("ui.hub.hc_play"), func(): _ask(mode), true, 46)
	b.name = "CtaButton"
	box.add_child(b)
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
		status.text = L.fa(L.t("ui.hub.pending"), pending) if pending > 0 else ""

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

func _ask(mode: String) -> void:
	if mode == "hardcore":
		Dialogs.confirm(_host, L.t("ui.hub.hc_play"), L.t("ui.hub.hc_confirm"), func(): _start("hardcore", "hardcore_month"), L.t("ui.challenges.hc_go"), L.t("common.annuler"))
	else:
		Dialogs.confirm(_host, L.t("ui.hub.ranked_play"), L.fa(L.t("ui.hub.ranked_confirm"), L.t(ChallengesModal.DIFF_KEYS[_diff])),
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
		srcs.add_child(HubKit.toggle("%s %s" % [MODE_ICON[s], L.t(MODE_NAME[s])], s == _src, func():
			_src = s
			_show("boards"), 14, 12, 7))
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
	var intro: String = {"free": "ui.hub.bd_free", "ranked": "ui.hub.bd_ranked", "hardcore": "ui.hub.bd_hardcore"}[_src]
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
		box.add_child(HubKit.label(L.t("ui.challenges.empty_board") if _src == "free" else (L.t("ui.ranked.empty") if _src == "ranked" else L.t("ui.challenges.hc_empty")), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		_modal.call_deferred("_fit")
		return
	_board_table(box, rows, unit)
	_modal.call_deferred("_fit")

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
		var plate := Cosmetics.name_plate(str(row.get("pseudo", "?")) + (" ✔" if verified else ""), title,
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
	var total_xp := 0
	if xp.ok and xp.data is Array and not (xp.data as Array).is_empty():
		total_xp = int(xp.data[0].get("xp", 0))
	if eq.ok and eq.data is Array and not (eq.data as Array).is_empty():
		var e: Dictionary = eq.data[0]
		_sel = {"title": str(e.get("title_badge", "")) if e.get("title_badge") != null else "",
			"frame": str(e.get("frame_badge", "")) if e.get("frame_badge") != null else "",
			"color": str(e.get("color_badge", "")) if e.get("color_badge") != null else ""}
	_build_rewards(total_xp)

func _build_rewards(total_xp: int) -> void:
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(HubKit.button(L.t("ui.rewards.equip"), _equip, true, 34))
	_eq_status = HubKit.label("", UiTheme.DIM, 12, false, true)
	row.add_child(_eq_status)
	v2.add_child(row)
	v2.add_child(HubKit.label(L.t("ui.rewards.equip_hint"), UiTheme.DIM, 11))
	# badges
	var g := GridContainer.new()
	g.columns = 3 if _narrow() else 5
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(g)
	for b in _cat:
		g.add_child(_badge_tile(b))
	_modal.call_deferred("_fit")

func _picker(parent: Control, kind: String, label: String, offers: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := HubKit.label(label, UiTheme.DIM, 13, false, false)
	l.custom_minimum_size.x = 100
	row.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

func _load_runs(box: VBoxContainer, wait: Label, mine: int) -> void:
	var r: Dictionary = await RankedRun.my_runs()
	if mine != _gen or not _alive():
		return
	wait.queue_free()
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	_runs = r.data
	_runs_ok = true
	if _runs.is_empty():
		box.add_child(HubKit.label(L.t("ui.hub.runs_none"), UiTheme.DIM, 14, false, true, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(g)
	_cell(g, L.t("ui.sadmin.col_date"), UiTheme.DIM, 12, 82, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.sadmin.col_mode"), UiTheme.DIM, 12, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.sadmin.col_status"), UiTheme.DIM, 12, 110, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(g, L.t("ui.challenges.unit_niveaux"), UiTheme.DIM, 12, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(g, L.t("ui.challenges.col_time"), UiTheme.DIM, 12, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	var n := clampi(_rows_fit(), 5, 10)
	for i in mini(n, _runs.size()):
		var x: Dictionary = _runs[i]
		var st := str(x.get("status", ""))
		var col := HubKit.GOOD if st == "verified" else (HubKit.BAD if st == "rejected" else (HubKit.WARN if st == "submitted" or st == "started" else UiTheme.DIM))
		_cell(g, SuperAdminModal.date(x.get("started_at")), UiTheme.PARCH, 13, 82, HORIZONTAL_ALIGNMENT_LEFT)
		_cell(g, SuperAdminModal.mode_name(str(x.get("difficulty", "")), str(x.get("kind", ""))), UiTheme.PARCH, 13, 0, HORIZONTAL_ALIGNMENT_LEFT)
		var sl := _cell(g, L.t(STATUS_KEYS[st]) if STATUS_KEYS.has(st) else st, col, 13, 110, HORIZONTAL_ALIGNMENT_LEFT)
		if st == "rejected" and x.get("reject_reason") != null:
			sl.tooltip_text = str(x.reject_reason)
			sl.mouse_filter = Control.MOUSE_FILTER_STOP
		_cell(g, str(int(x.score)) if x.get("score") != null else "–", UiTheme.PARCH, 13, 60, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(g, Challenges.format_time(int(x.seconds)) if x.get("seconds") != null else "–", UiTheme.PARCH, 13, 60, HORIZONTAL_ALIGNMENT_RIGHT)
	box.add_child(HubKit.label(L.t("ui.hub.runs_legend"), UiTheme.DIM, 11))
	_modal.call_deferred("_fit")
