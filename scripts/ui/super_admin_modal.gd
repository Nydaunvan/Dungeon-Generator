class_name SuperAdminModal
extends RefCounted
## « Administration » : écran de l'équipe (modérateur < super admin < développeur). Les onglets affichés dépendent du rôle ; le SERVEUR
## revérifie le rôle à chaque appel, l'écran n'est qu'une vitrine (voir SuperAdmin). Aucun courriel n'y figure.
##   modérateur : Modération (tchat + galerie), Joueurs, Équipe (lecture), Journal (ses actions)
##   super admin : + Vue d'ensemble, Parties, Tests, nomination des modérateurs, journal complet
##   développeur : + nomination des super admins, onglet Développeur (santé, maintenance, annonce, bannissements, classements)

const STATUSES := ["started", "submitted", "verified", "rejected", "expired"]
const GOLD := Color("ffd98a")
const BAD := Color("e08a7a")
const GOOD := Color("9cc79a")
const ROW_SIZE := 14

var _host: Node
var _modal: Modal
var _tab := "mod"
var _mod_sub := "chat"
var _log_action := ""
var _log_actor := ""
var _log_rows: Array = []
var _log_search: LineEdit
var _log_days := 7
var _log_limit := 100
var _gen := 0
var _body: VBoxContainer
var _list: VBoxContainer
var _tab_buttons: Dictionary = {}
var _status: Label
var _search: LineEdit
var _run_status := ""
var _run_tests := "all"

static func open(host: Node) -> SuperAdminModal:
	var s := SuperAdminModal.new()
	s._host = host
	s._modal = Modal.open(host, L.t("ui.sadmin.title"), 760.0)
	s._build()
	return s

## Onglets visibles pour un rang (1 modérateur, 2 super admin, 3 développeur).
static func tabs_for_rank(rank: int) -> Array:
	var out: Array = ["mod", "players", "team", "log"]
	if rank >= 2:
		out.append_array(["overview", "runs", "suspects", "tests"])
	if rank >= 3:
		out.append("dev")
	return out

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _build() -> void:
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	_modal.content.add_child(tabs)
	for t in tabs_for_rank(SuperAdmin.rank()):
		var b := Button.new()
		b.text = L.t("ui.sadmin.tab_" + t) + (" (%d)" % SuperAdmin.pending() if t == "mod" and SuperAdmin.pending() > 0 else (" (%d)" % SuperAdmin.pending_suspects() if t == "suspects" and SuperAdmin.pending_suspects() > 0 else ""))
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = t == _tab
		b.pressed.connect(func(): _show(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_modal.content.add_child(_body)
	_modal.set_buttons([
		{"text": L.t("ui.sadmin.refresh"), "primary": true, "cb": func(): _show(_tab)},
		{"text": L.t("common.fermer"), "cb": func(): _modal.close()},
	])
	_show(_tab)

func _show(tab: String) -> void:
	_tab = tab
	for t in _tab_buttons:
		(_tab_buttons[t] as Button).button_pressed = t == tab
	match tab:
		"tests": _build_tests()
		"overview": _load_overview()
		"players": _build_players()
		"runs": _build_runs()
		"suspects": _build_suspects()
		"mod": _build_player_reports() if _mod_sub == "players" else (_build_chat() if _mod_sub == "chat" else _build_gallery())
		"team": _build_team()
		"log": _build_log()
		"dev": _build_dev()

# ------------------------------------------------------------------ outils d'affichage

func _begin() -> int:
	_gen += 1
	_clear(_body)
	_list = null
	_status = null
	if _tab == "mod":
		_mod_bar()
	return _gen

## Tchat / Galerie, avec le nombre de signalements à traiter.
func _mod_bar() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	for sub in ["chat", "gallery", "players"]:
		var n := SuperAdmin.pending_chat() if sub == "chat" else (SuperAdmin.pending_gallery() if sub == "gallery" else SuperAdmin.pending_players())
		var b := Button.new()
		b.text = L.t("ui.sadmin.sub_players" if sub == "players" else "ui.sadmin.tab_" + sub) + (" (%d)" % n if n > 0 else "")
		b.toggle_mode = true
		b.button_pressed = _mod_sub == sub
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			_mod_sub = sub
			_show("mod"))
		bar.add_child(b)
	_body.add_child(bar)

func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _fit() -> void:
	if _alive():
		_modal.call_deferred("_fit")

func _label(text: String, color: Color = UiTheme.PARCH, size: int = ROW_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _note(parent: Control, text: String, color: Color = UiTheme.DIM, center: bool = true) -> Label:
	var l := _label(text, color, 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	_fit()
	return l

func _wait(parent: Control) -> void:
	_note(parent, L.t("ui.sadmin.loading"))

func _error(parent: Control, r: Dictionary) -> void:
	_note(parent, str(r.get("message", "")), BAD)

func _title(parent: Control, text: String) -> void:
	var l := _label(text, GOLD, 16)
	l.add_theme_constant_override("line_spacing", 0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(l)
	parent.add_child(m)

## Ligne « libellé … valeur ».
func _kv(parent: Control, label: String, value: String, color: Color = UiTheme.PARCH) -> void:
	var h := HBoxContainer.new()
	var a := _label(label, UiTheme.DIM)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := _label(value, color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	parent.add_child(h)

## Ligne de tableau : `widths[i]` = largeur minimale de la colonne (0 = prend la place restante, texte à gauche).
func _cells(parent: Control, cells: Array, widths: Array, color: Color = UiTheme.PARCH) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for i in cells.size():
		var l := _label(str(cells[i]), color)
		if float(widths[i]) <= 0.0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(float(widths[i]), 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	parent.add_child(h)
	return h

static func num(v: Variant) -> String:
	if v == null:
		return "—"
	if v is float:
		if v == floorf(v):
			return str(int(v))
		return String.num(v, 2)
	return str(v)

## Durée en secondes -> « 45 s », « 12 min », « 3 h 05 ».
static func age(sec: Variant) -> String:
	if sec == null:
		return "—"
	var s := int(sec)
	if s < 60:
		return "%d s" % s
	if s < 3600:
		return "%d min" % (s / 60)
	return "%d h %02d" % [s / 3600, (s % 3600) / 60]

## Date ISO du serveur (UTC) -> « jj/mm hh:mm » à l'heure de l'ordinateur.
static func date(v: Variant) -> String:
	if v == null:
		return "—"
	var s := str(v)
	if s.length() < 19:
		return s
	var t := Time.get_unix_time_from_datetime_string(s.substr(0, 19))
	t += int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(int(t))
	return "%02d/%02d %02d:%02d" % [d.day, d.month, d.hour, d.minute]

static func mode_name(difficulty: String, kind: String = "difficulty") -> String:
	if kind == "hardcore_month":
		return L.t("ui.sadmin.mode_month")
	if kind == "weekly":
		return L.t("ui.hub.mode_weekly")
	if kind == "daily":
		return L.t("ui.hub.mode_daily")
	if ChallengesModal.DIFF_KEYS.has(difficulty):
		return L.t(ChallengesModal.DIFF_KEYS[difficulty])
	return difficulty

static func status_name(s: String) -> String:
	return L.t("ui.sadmin.status_" + s) if STATUSES.has(s) else s

# ------------------------------------------------------------------ onglet Tests

func _build_tests() -> void:
	_begin()
	_note(_body, L.t("ui.sadmin.tests_desc"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	for d in RankedRun.DIFFICULTIES:
		_test_button(grid, L.t("ui.sadmin.test_start") % L.t(ChallengesModal.DIFF_KEYS[d]), d, "difficulty")
	var hc := _test_button(grid, L.t("ui.sadmin.test_month"), "hardcore", "hardcore_month")
	hc.tooltip_text = L.t("ui.sadmin.test_month_hint")
	var wk := _test_button(grid, L.t("ui.sadmin.test_weekly"), "normal", "weekly")
	wk.tooltip_text = L.t("ui.sadmin.test_weekly_hint")
	_status = Form.status_label(_body)
	_note(_body, L.t("ui.sadmin.test_month_hint"))
	var purge := Button.new()
	purge.text = L.t("ui.sadmin.purge")
	purge.focus_mode = Control.FOCUS_NONE
	purge.pressed.connect(func():
		Dialogs.confirm(_host, L.t("ui.sadmin.purge"), L.t("ui.sadmin.purge_confirm"), _purge, L.t("common.confirmer"), L.t("common.annuler")))
	_body.add_child(purge)
	_fit()

func _test_button(parent: Control, text: String, difficulty: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(func(): _launch(difficulty, kind))
	parent.add_child(b)
	return b

func _say(text: String, bad: bool = false) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", BAD if bad else GOOD)

func _launch(difficulty: String, kind: String) -> void:
	_say(L.t("ui.sadmin.launching"))
	var r: Dictionary = await SuperAdmin.launch_test(difficulty, kind)
	if not r.ok and _alive():
		_say(str(r.get("message", "")), true)

func _purge() -> void:
	var r: Dictionary = await SuperAdmin.purge_tests()
	if not _alive():
		return
	if r.ok:
		_say(L.t("ui.sadmin.purge_done") % int(r.data if r.data != null else 0))
	else:
		_say(str(r.message), true)

# ------------------------------------------------------------------ onglet Vue d'ensemble

func _load_overview() -> void:
	var mine := _begin()
	_wait(_body)
	var r: Dictionary = await SuperAdmin.overview()
	if mine != _gen or not _alive():
		return
	_clear(_body)
	if not r.ok or not (r.data is Dictionary):
		_error(_body, r)
		return
	var d: Dictionary = r.data
	_note(_body, L.t("ui.sadmin.generated") % date(d.get("generated_at")))
	var p: Dictionary = d.get("players", {})
	_title(_body, L.t("ui.sadmin.sec_players"))
	_kv(_body, L.t("ui.sadmin.players_total"), num(p.get("total")))
	_kv(_body, L.t("ui.sadmin.players_new24"), num(p.get("new_24h")))
	_kv(_body, L.t("ui.sadmin.players_new7"), num(p.get("new_7d")))
	_kv(_body, L.t("ui.sadmin.players_active24"), num(p.get("active_24h")))
	_kv(_body, L.t("ui.sadmin.players_active7"), num(p.get("active_7d")))
	_kv(_body, L.t("ui.sadmin.players_admins"), num(p.get("admins")))
	var ru: Dictionary = d.get("runs", {})
	_title(_body, L.t("ui.sadmin.sec_runs"))
	_kv(_body, L.t("ui.sadmin.runs_total"), num(ru.get("total")))
	_kv(_body, L.t("ui.sadmin.runs_today"), num(ru.get("today")))
	_kv(_body, L.t("ui.sadmin.runs_tests"), num(ru.get("tests")))
	var by_status: Dictionary = ru.get("by_status", {})
	for s in STATUSES:
		_kv(_body, "   " + status_name(s), num(by_status.get(s, 0)))
	var modes: Array = ru.get("by_mode", [])
	if not modes.is_empty():
		_title(_body, L.t("ui.sadmin.sec_modes"))
		var w := [0, 56, 70, 64, 64, 64]
		_cells(_body, [L.t("ui.sadmin.col_mode"), L.t("ui.sadmin.col_runs"), L.t("ui.sadmin.col_verified"), L.t("ui.sadmin.col_avg"), L.t("ui.sadmin.col_best"), L.t("ui.sadmin.col_time")], w, UiTheme.DIM)
		for m in modes:
			var mode := str(m.get("mode", ""))
			_cells(_body, [mode_name(mode, mode), num(m.get("runs")), num(m.get("verified")), num(m.get("avg_score")), num(m.get("best_score")), age(m.get("avg_seconds"))], w)
	var q: Dictionary = d.get("queue", {})
	_title(_body, L.t("ui.sadmin.sec_queue"))
	_kv(_body, L.t("ui.sadmin.queue_submitted"), num(q.get("submitted")), BAD if int(q.get("submitted", 0)) > 0 else UiTheme.PARCH)
	_kv(_body, L.t("ui.sadmin.queue_oldest"), age(q.get("oldest_seconds")))
	_kv(_body, L.t("ui.sadmin.queue_progress"), num(q.get("in_progress")))
	var hc: Dictionary = d.get("hardcore", {})
	_title(_body, L.t("ui.sadmin.sec_hardcore"))
	_kv(_body, L.t("ui.sadmin.hc_period"), str(hc.get("period", "—")))
	_kv(_body, L.t("ui.sadmin.hc_attempts_today"), num(hc.get("attempts_today")))
	_kv(_body, L.t("ui.sadmin.hc_attempts_month"), num(hc.get("attempts_month")))
	_kv(_body, L.t("ui.sadmin.hc_players"), num(hc.get("players_month")))
	_kv(_body, L.t("ui.sadmin.hc_verified"), num(hc.get("verified_month")))
	_kv(_body, L.t("ui.sadmin.hc_best"), num(hc.get("best_month")))
	_kv(_body, L.t("ui.sadmin.hc_closed"), date(hc.get("closed_at")) if hc.get("closed_at") != null else L.t("ui.sadmin.no"))
	var rw: Dictionary = d.get("rewards", {})
	_title(_body, L.t("ui.sadmin.sec_rewards"))
	_kv(_body, L.t("ui.sadmin.xp_total"), num(rw.get("xp_total")))
	_kv(_body, L.t("ui.sadmin.badges_awarded"), num(rw.get("badges_awarded")))
	_kv(_body, L.t("ui.sadmin.cosmetics"), num(rw.get("cosmetics_equipped")))
	for b in rw.get("badges", []):
		_kv(_body, "   " + str(b.get("badge", "?")), num(b.get("n")))
	_stats_section(_body)
	var versions: Array = ru.get("by_version", [])
	if not versions.is_empty():
		_title(_body, L.t("ui.sadmin.sec_versions"))
		for v in versions:
			_kv(_body, str(v.get("version", "?")), num(v.get("runs")))
	var rej: Array = ru.get("reject_reasons", [])
	if not rej.is_empty():
		_title(_body, L.t("ui.sadmin.sec_rejects"))
		for x in rej:
			_kv(_body, str(x.get("reason", "?")), num(x.get("n")), BAD)
	var o: Dictionary = d.get("other", {})
	_title(_body, L.t("ui.sadmin.sec_other"))
	_kv(_body, L.t("ui.sadmin.other_dungeons"), "%s (%s %s)" % [num(o.get("dungeons")), num(o.get("dungeons_public")), L.t("ui.sadmin.public")])
	_kv(_body, L.t("ui.sadmin.other_reports"), num(o.get("dungeon_reports")))
	_kv(_body, L.t("ui.sadmin.other_challenges"), num(o.get("challenges")))
	_kv(_body, L.t("ui.sadmin.other_declared"), num(o.get("declared_scores")))
	_kv(_body, L.t("ui.sadmin.other_replay"), num(o.get("replay_runs")))
	_fit()

# ------------------------------------------------------------------ onglet Joueurs

func _build_players() -> void:
	_begin()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_search = LineEdit.new()
	_search.placeholder_text = L.t("ui.sadmin.search_hint")
	_search.max_length = 20
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_submitted.connect(func(_t): _fill_players())
	h.add_child(_search)
	var b := Button.new()
	b.text = L.t("ui.sadmin.search")
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_fill_players)
	h.add_child(b)
	_body.add_child(h)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_body.add_child(_list)
	_fill_players()

func _fill_players() -> void:
	var box := _list
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var r: Dictionary = await SuperAdmin.players(_search.text.strip_edges() if _search != null and is_instance_valid(_search) else "")
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	var rows: Array = r.data
	if rows.is_empty():
		_note(box, L.t("ui.sadmin.none"))
		return
	var w := [0, 40, 60, 62, 52, 92]
	var head := _cells(box, [L.t("ui.sadmin.col_player"), L.t("ui.sadmin.col_level"), L.t("ui.sadmin.col_xp"), L.t("ui.sadmin.col_runs_ok"), L.t("ui.sadmin.col_best"), L.t("ui.sadmin.col_last")], w, UiTheme.DIM)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(70, 0)
	head.add_child(pad)
	for p in rows:
		var pid := str(p.get("id", ""))
		var name := _mark(str(p.get("role", ""))) + str(p.get("pseudo", "?")) + (" 🔇" if bool(p.get("muted", false)) else "") + (" 🚫" if bool(p.get("banned", false)) else "")
		var row := _cells(box, [name, num(p.get("level")), num(p.get("xp")), "%s/%s" % [num(p.get("verified")), num(p.get("runs"))], num(p.get("best_score")), date(p.get("last_run_at"))], w)
		var cb := Button.new()
		cb.text = L.t("ui.sadmin.card_btn")
		cb.focus_mode = Control.FOCUS_NONE
		cb.custom_minimum_size = Vector2(70, 0)
		cb.pressed.connect(func(): _open_card(pid))
		row.add_child(cb)
	_note(box, L.t("ui.sadmin.shown") % rows.size())

# ------------------------------------------------------------------ onglet Parties

func _build_runs() -> void:
	_begin()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var st := OptionButton.new()
	st.add_item(L.t("ui.sadmin.all_status"))
	for s in STATUSES:
		st.add_item(status_name(s))
	st.select(0 if _run_status == "" else STATUSES.find(_run_status) + 1)
	st.item_selected.connect(func(i: int):
		_run_status = "" if i == 0 else STATUSES[i - 1]
		_fill_runs())
	h.add_child(st)
	var tt := OptionButton.new()
	tt.add_item(L.t("ui.sadmin.tests_all"))
	tt.add_item(L.t("ui.sadmin.tests_only"))
	tt.add_item(L.t("ui.sadmin.tests_none"))
	tt.select(["all", "only", "none"].find(_run_tests))
	tt.item_selected.connect(func(i: int):
		_run_tests = ["all", "only", "none"][i]
		_fill_runs())
	h.add_child(tt)
	_body.add_child(h)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_body.add_child(_list)
	_fill_runs()

func _fill_runs() -> void:
	var box := _list
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var r: Dictionary = await SuperAdmin.runs(_run_status, _run_tests)
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	var rows: Array = r.data
	if rows.is_empty():
		_note(box, L.t("ui.sadmin.none"))
		return
	var w := [88, 0, 74, 74, 38, 50]
	_cells(box, [L.t("ui.sadmin.col_date"), L.t("ui.sadmin.col_player"), L.t("ui.sadmin.col_mode"), L.t("ui.sadmin.col_status"), L.t("ui.sadmin.col_score"), L.t("ui.sadmin.col_time")], w, UiTheme.DIM)
	for x in rows:
		var mode := mode_name(str(x.get("difficulty", "")), str(x.get("kind", ""))) + (" 🧪" if bool(x.get("test", false)) else "")
		var status := str(x.get("status", ""))
		var row := _cells(box, [date(x.get("started_at")), str(x.get("pseudo", "?")), mode, status_name(status), num(x.get("score")), age(x.get("seconds"))], w,
			BAD if status == "rejected" else UiTheme.PARCH)
		(row.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if x.get("reject_reason") != null:
			_note(box, "↳ %s" % str(x.get("reject_reason")), BAD, false)
	_note(box, L.t("ui.sadmin.shown") % rows.size())

# ------------------------------------------------------------------ onglet Tchat

func _build_chat() -> void:
	_begin()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_body.add_child(_list)
	_fill_chat()

func _fill_chat() -> void:
	var box := _list
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var st: Dictionary = await SuperAdmin.chat_stats()
	if mine != _gen or not _alive():
		return
	var rp: Dictionary = await SuperAdmin.chat_reports()
	if mine != _gen or not _alive():
		return
	var wd: Dictionary = await SuperAdmin.chat_words()
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not st.ok or not (st.data is Dictionary):
		_error(box, st)
		return
	var d: Dictionary = st.data
	_title(box, L.t("ui.sadmin.chat_stats"))
	_kv(box, L.t("ui.sadmin.chat_msgs_24h"), "%s (%s)" % [num(d.get("messages_24h")), L.t("ui.sadmin.chat_authors") % num(d.get("authors_24h"))])
	_kv(box, L.t("ui.sadmin.chat_msgs_total"), num(d.get("messages_total")))
	_kv(box, L.t("ui.sadmin.chat_deleted"), num(d.get("deleted_total")))
	_kv(box, L.t("ui.sadmin.chat_mutes"), num(d.get("mutes_active")))
	_kv(box, L.t("ui.sadmin.chat_blocks"), num(d.get("blocks")))
	_title(box, L.t("ui.sadmin.chat_reports") % num(d.get("reports_pending")))
	_status = Form.status_label(box)
	if not rp.ok or not (rp.data is Array):
		_error(box, rp)
	elif (rp.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.chat_no_reports"))
	else:
		for x in rp.data:
			_report_card(box, x)
	_words_section(box, wd, mine)

## Retire les accents et les majuscules : sert au tri et à la recherche.
static func _fold(t: String) -> String:
	var r := t.to_lower()
	for pair in [["àâä", "a"], ["éèêë", "e"], ["îï", "i"], ["ôö", "o"], ["ùûü", "u"], ["ç", "c"], ["ÿ", "y"], ["œ", "oe"]]:
		for ch in pair[0]:
			r = r.replace(ch, pair[1])
	return r

## Liste des mots interdits : une seule zone de saisie qui sert à chercher ET à ajouter, mots classés par lettre
## (les expressions de plusieurs mots à part) dans une zone défilante de hauteur fixe.
func _words_section(box: Control, wd: Dictionary, mine: int) -> void:
	var words: Array = []
	if wd.ok and wd.data is Array:
		for w in wd.data:
			words.append(str(w))
	words.sort_custom(func(x: String, y: String) -> bool: return _fold(x) < _fold(y))
	_title(box, L.t("ui.sadmin.chat_words") % words.size())
	_note(box, L.t("ui.sadmin.chat_words_desc"))
	if not (wd.ok and wd.data is Array):
		_error(box, wd)
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var e := LineEdit.new()
	e.max_length = 30
	e.clear_button_enabled = true
	e.placeholder_text = L.t("ui.sadmin.chat_word_search")
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(e)
	var add := Button.new()
	add.text = L.t("ui.sadmin.chat_word_add")
	add.focus_mode = Control.FOCUS_NONE
	h.add_child(add)
	box.add_child(h)
	var count := _label("", UiTheme.DIM, 12)
	box.add_child(count)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 250)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	box.add_child(sc)
	var remove := func(word: String):
		var r: Dictionary = await SuperAdmin.chat_word_remove(word)
		if mine == _gen and _alive():
			if r.ok:
				_fill_chat()
			else:
				_flash(str(r.message), BAD)
	var render := func():
		_clear(inner)
		var q := _fold(e.text.strip_edges())
		var groups: Dictionary = {}
		var shown := 0
		for w in words:
			if q != "" and not _fold(w).contains(q):
				continue
			shown += 1
			var key := "…" if w.contains(" ") else _fold(w).left(1).to_upper()
			if not groups.has(key):
				groups[key] = []
			groups[key].append(w)
		count.text = L.t("ui.sadmin.chat_word_count") % [shown, words.size()]
		var exact := false
		for w in words:
			if _fold(w) == q:
				exact = true
		add.disabled = q == "" or exact
		if shown == 0:
			inner.add_child(_note_free(L.t("ui.sadmin.chat_word_none")))
			return
		var keys := groups.keys()
		keys.sort_custom(func(x: String, y: String) -> bool:
			if x == "…" or y == "…":
				return y == "…" and x != "…"
			return x < y)
		for k in keys:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var head := _label(L.t("ui.sadmin.chat_word_phrases") if k == "…" else k, GOLD, 15)
			head.custom_minimum_size = Vector2(26 if k != "…" else 0, 0)
			head.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			if k == "…":
				inner.add_child(head)
				row = null
			else:
				row.add_child(head)
			var fl := HFlowContainer.new()
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fl.add_theme_constant_override("h_separation", 5)
			fl.add_theme_constant_override("v_separation", 4)
			for w in groups[k]:
				var b := Button.new()
				b.text = "%s ✕" % w
				b.focus_mode = Control.FOCUS_NONE
				b.add_theme_font_size_override("font_size", 12)
				b.tooltip_text = L.t("ui.sadmin.chat_word_remove")
				var word: String = w
				b.pressed.connect(func(): remove.call(word))
				fl.add_child(b)
			if row == null:
				inner.add_child(fl)
			else:
				row.add_child(fl)
				inner.add_child(row)
	var do_add := func():
		if add.disabled:
			return
		var r: Dictionary = await SuperAdmin.chat_word_add(e.text)
		if mine != _gen or not _alive():
			return
		if r.ok:
			_fill_chat()
		else:
			_flash(str(r.message), BAD)
	add.pressed.connect(do_add)
	e.text_submitted.connect(func(_t): do_add.call())
	e.text_changed.connect(func(_t): render.call())
	render.call()
	_fit()

func _note_free(text: String) -> Label:
	var l := _label(text, UiTheme.DIM, 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _flash(text: String, color: Color = UiTheme.DIM) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text
		_status.add_theme_color_override("font_color", color)

## Un message signalé : auteur, salon, texte, nombre de signalements et motifs, puis les trois décisions.
func _report_card(box: Control, x: Dictionary) -> void:
	var mine := _gen
	var id := int(x.get("message_id", 0))
	var pid := str(x.get("player_id", ""))
	var pseudo := str(x.get("pseudo", "?"))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	var head := "%s · %s · %s · %s" % [pseudo, Chat.room_name(str(x.get("room", ""))), date(x.get("created_at")), L.t("ui.sadmin.chat_n_reports") % num(x.get("reports"))]
	card.add_child(_label(head, GOLD, 13))
	var body := _label(str(x.get("body", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	card.add_child(body)
	var reasons: Variant = x.get("reasons")
	if reasons is Array and not (reasons as Array).is_empty():
		_note(card, "↳ " + " | ".join((reasons as Array).map(func(r): return str(r))), UiTheme.DIM, false)
	if x.get("muted_until") != null:
		_note(card, L.t("ui.sadmin.chat_muted_until") % date(x.get("muted_until")), BAD, false)
	var act := HFlowContainer.new()
	act.add_theme_constant_override("h_separation", 6)
	var specs := [
		[L.t("ui.sadmin.chat_delete"), func(): return await SuperAdmin.chat_delete(id), false],
		[L.t("ui.sadmin.chat_mute_24h"), func(): return await SuperAdmin.chat_mute(pid, 1440, "signalement"), false],
		[L.t("ui.sadmin.chat_dismiss"), func(): return await SuperAdmin.chat_dismiss(id), false],
	]
	if x.get("muted_until") != null:
		specs.append([L.t("ui.sadmin.chat_unmute"), func(): return await SuperAdmin.chat_unmute(pid), false])
	for sp in specs:
		var b := Button.new()
		b.text = str(sp[0])
		b.focus_mode = Control.FOCUS_NONE
		var fn: Callable = sp[1]
		b.pressed.connect(func():
			b.disabled = true
			var r: Dictionary = await fn.call()
			if mine != _gen or not _alive():
				return
			if r.ok:
				_fill_chat()
			else:
				b.disabled = false
				_flash(str(r.message), BAD))
		act.add_child(b)
	card.add_child(act)
	var sep := HSeparator.new()
	card.add_child(sep)
	box.add_child(card)

# ------------------------------------------------------------------ onglet Galerie (modération des donjons publiés)

func _build_gallery() -> void:
	_begin()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_body.add_child(_list)
	_fill_gallery()

func _fill_gallery() -> void:
	var box := _list
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var st: Dictionary = await SuperAdmin.gallery_stats()
	if mine != _gen or not _alive():
		return
	var rp: Dictionary = await SuperAdmin.gallery_reports()
	if mine != _gen or not _alive():
		return
	var bn: Dictionary = await SuperAdmin.gallery_bans()
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not st.ok or not (st.data is Dictionary):
		_error(box, st)
		return
	var d: Dictionary = st.data
	_title(box, L.t("ui.sadmin.gal_stats"))
	_kv(box, L.t("ui.sadmin.gal_public"), "%s / %s" % [num(d.get("public")), num(d.get("total"))])
	_kv(box, L.t("ui.sadmin.gal_downloads"), num(d.get("downloads")))
	_kv(box, L.t("ui.sadmin.gal_bans"), num(d.get("bans")))
	_title(box, L.t("ui.sadmin.gal_reports") % num(d.get("reports_pending")))
	_status = Form.status_label(box)
	if not rp.ok or not (rp.data is Array):
		_error(box, rp)
	elif (rp.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.gal_no_reports"))
	else:
		for x in rp.data:
			_gallery_card(box, x)
	_title(box, L.t("ui.sadmin.gal_banned_title"))
	if not bn.ok or not (bn.data is Array):
		_error(box, bn)
	elif (bn.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.gal_banned_none"))
	else:
		for b in bn.data:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var txt := "%s · %s%s" % [str(b.get("pseudo", "?")), date(b.get("created_at")), (" · " + str(b.get("reason"))) if b.get("reason") != null else ""]
			var l := _label(txt)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			h.add_child(l)
			var pid := str(b.get("player_id", ""))
			var ub := Button.new()
			ub.text = L.t("ui.sadmin.gal_unban")
			ub.focus_mode = Control.FOCUS_NONE
			ub.pressed.connect(func():
				ub.disabled = true
				var r: Dictionary = await SuperAdmin.gallery_unban(pid)
				if mine == _gen and _alive():
					if r.ok:
						_fill_gallery()
					else:
						ub.disabled = false
						_flash(str(r.message), BAD))
			h.add_child(ub)
			box.add_child(h)
	_fit()

## Un donjon signalé : titre, auteur, état, nombre de signalements et motifs, puis les décisions.
func _gallery_card(box: Control, x: Dictionary) -> void:
	var mine := _gen
	var did := str(x.get("dungeon_id", ""))
	var pid := str(x.get("player_id", ""))
	var pseudo := str(x.get("pseudo", "?"))
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	var state := L.t("ui.sadmin.gal_state_public") if bool(x.get("is_public", false)) else L.t("ui.sadmin.gal_state_private")
	card.add_child(_label("%s — %s" % [str(x.get("title", "")), pseudo], GOLD, 14))
	var info := "%s · %s · ⬇ %s · %s" % [state, date(x.get("created_at")), num(x.get("downloads")), L.t("ui.sadmin.chat_n_reports") % num(x.get("reports"))]
	card.add_child(_label(info, UiTheme.DIM, 12))
	var desc := str(x.get("description", ""))
	if desc != "":
		var dl := _label(desc.left(240))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 60
		card.add_child(dl)
	var reasons: Variant = x.get("reasons")
	if reasons is Array and not (reasons as Array).is_empty():
		_note(card, "↳ " + " | ".join((reasons as Array).map(func(r): return str(r))), UiTheme.DIM, false)
	if bool(x.get("banned", false)):
		_note(card, L.t("ui.sadmin.gal_author_banned"), BAD, false)
	var act := HFlowContainer.new()
	act.add_theme_constant_override("h_separation", 6)
	act.add_theme_constant_override("v_separation", 4)
	var after := func(r: Dictionary, b: Button):
		if mine != _gen or not _alive():
			return
		if r.ok:
			_fill_gallery()
		else:
			b.disabled = false
			_flash(str(r.message), BAD)
	var specs: Array = []
	if bool(x.get("is_public", false)):
		specs.append([L.t("ui.sadmin.gal_view"), func(b: Button):
			var r: Dictionary = await MyDungeons.download(did)
			if mine == _gen and _alive():
				b.disabled = false
				_flash(L.t("ui.gallery.added_long") if r.ok else str(r.get("message", "")), GOOD if r.ok else BAD)])
		specs.append([L.t("ui.sadmin.gal_unpublish"), func(b: Button): after.call(await SuperAdmin.gallery_unpublish(did), b)])
	specs.append([L.t("ui.sadmin.gal_dismiss"), func(b: Button): after.call(await SuperAdmin.gallery_dismiss(did), b)])
	if SuperAdmin.is_super():
		specs.append([L.t("ui.sadmin.gal_delete"), func(b: Button):
			b.disabled = false
			Dialogs.confirm(_host, L.t("ui.sadmin.gal_delete"), L.fa(L.t("ui.sadmin.gal_delete_confirm"), str(x.get("title", ""))), func():
				after.call(await SuperAdmin.gallery_delete(did), b), L.t("common.confirmer"))])
	if not bool(x.get("banned", false)):
		specs.append([L.t("ui.sadmin.gal_ban"), func(b: Button):
			b.disabled = false
			_sanction_dialog("gallery", pid, pseudo, func(): after.call({"ok": true}, b))])
	for sp in specs:
		var b := Button.new()
		b.text = str(sp[0])
		b.focus_mode = Control.FOCUS_NONE
		var fn: Callable = sp[1]
		b.pressed.connect(func():
			b.disabled = true
			fn.call(b))
		act.add_child(b)
	card.add_child(act)
	card.add_child(HSeparator.new())
	box.add_child(card)

# ------------------------------------------------------------------ rôles : outils communs

## Icône du rôle suivie d'une espace ("" pour un joueur ordinaire).
static func _mark(role: String) -> String:
	var m := str(StaffBadges.MARKS.get(role, ""))
	return m + " " if m != "" else ""

func _btn(parent: Control, text: String, cb: Callable, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if danger:
		b.add_theme_color_override("font_color", BAD)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _flow(parent: Control) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	parent.add_child(f)
	return f

## Exécute une action serveur puis appelle `then` (rechargement) ; l'erreur éventuelle s'affiche dans la ligne d'état.
func _run(fn: Callable, then: Callable, b: Button = null) -> void:
	var mine := _gen
	if b != null:
		b.disabled = true
	var r: Dictionary = await fn.call()
	if mine != _gen or not _alive():
		return
	if r.ok:
		then.call()
	else:
		if b != null:
			b.disabled = false
		_flash(str(r.get("message", "")), BAD)

## Confirmation simple.
func _ask(title: String, text: String, yes: Callable) -> void:
	Dialogs.confirm(_host, title, text, yes, L.t("common.confirmer"))

## Confirmation à deux étapes : la première fenêtre explique, la seconde demande de taper le mot `word`.
func _typed_confirm(title: String, text: String, word: String, on_ok: Callable) -> void:
	Dialogs.confirm(_host, title, text, func():
		var m := Modal.open(_host, title, 460.0)
		m.add_text(L.fa(L.t("ui.sadmin.typed_hint"), word), UiTheme.PARCH, 15)
		var le := LineEdit.new()
		le.placeholder_text = word
		m.content.add_child(le)
		m.set_buttons([
			{"text": L.t("common.confirmer"), "primary": true, "cb": func():
				if le.text.strip_edges() == word:
					m.close()
					on_ok.call()
				else:
					le.text = ""
					le.placeholder_text = L.t("ui.sadmin.typed_wrong")},
			{"text": L.t("common.annuler"), "cb": func(): m.close()},
		])
		le.grab_focus(), L.t("common.confirmer"))

# ------------------------------------------------------------------ fiche d'un joueur

func _open_card(pid: String) -> void:
	var mine := _begin()
	_wait(_body)
	var r: Dictionary = await SuperAdmin.player_card(pid)
	if mine != _gen or not _alive():
		return
	_clear(_body)
	if not r.ok or not (r.data is Dictionary):
		_error(_body, r)
		_btn(_body, L.t("ui.sadmin.back"), func(): _show(_tab))
		return
	var d: Dictionary = r.data
	var back_tab := _tab
	var reload := func(): _open_card(pid)
	_btn(_body, L.t("ui.sadmin.back"), func(): _show(back_tab))
	var role := str(d.get("role", "")) if d.get("role") != null else ""
	var target_rank := int(d.get("rank", 0))
	var my_rank := SuperAdmin.rank()
	_title(_body, "%s%s" % [_mark(role), str(d.get("pseudo", "?"))])
	_kv(_body, L.t("ui.sadmin.card_role"), StaffBadges.role_name(role) if role != "" else L.t("ui.sadmin.role_player"), GOLD if role != "" else UiTheme.PARCH)
	_kv(_body, L.t("ui.sadmin.card_since"), date(d.get("created_at")))
	_status = Form.status_label(_body)
	# sanctions en cours
	_title(_body, L.t("ui.sadmin.card_sanctions"))
	var any := false
	var mute: Variant = d.get("mute")
	if mute is Dictionary:
		any = true
		_kv(_body, L.t("ui.sadmin.card_mute"), L.fa(L.t("ui.sadmin.until"), date((mute as Dictionary).get("until"))), BAD)
	if d.get("gallery_ban") is Dictionary:
		any = true
		_kv(_body, L.t("ui.sadmin.card_gallery_ban"), str((d.gallery_ban as Dictionary).get("reason", "")) if (d.gallery_ban as Dictionary).get("reason") != null else "—", BAD)
	var ab: Variant = d.get("account_ban")
	if ab is Dictionary:
		any = true
		var until: Variant = (ab as Dictionary).get("until")
		_kv(_body, L.t("ui.sadmin.card_account_ban"), L.t("ui.sadmin.forever") if until == null else L.fa(L.t("ui.sadmin.until"), date(until)), BAD)
	if not any:
		_note(_body, L.t("ui.sadmin.card_none"), UiTheme.DIM, false)
	# actions : seulement sur un rang strictement inférieur au sien (le serveur l'impose aussi)
	if my_rank > target_rank:
		_title(_body, L.t("ui.sadmin.card_actions"))
		var act := _flow(_body)
		if mute is Dictionary:
			_btn(act, L.t("ui.sadmin.chat_unmute"), func(): _run(func(): return await SuperAdmin.chat_unmute(pid), reload))
		else:
			_btn(act, L.t("ui.sadmin.mute_btn"), func(): _sanction_dialog("mute", pid, str(d.get("pseudo", "?")), reload))
		if d.get("gallery_ban") is Dictionary:
			_btn(act, L.t("ui.sadmin.gal_unban"), func(): _run(func(): return await SuperAdmin.gallery_unban(pid), reload))
		else:
			_btn(act, L.t("ui.sadmin.gal_ban"), func(): _sanction_dialog("gallery", pid, str(d.get("pseudo", "?")), reload))
		_role_buttons(act, pid, str(d.get("pseudo", "?")), target_rank, reload)
		if my_rank >= 3:
			if ab is Dictionary:
				_btn(act, L.t("ui.sadmin.acc_unban"), func(): _run(func(): return await SuperAdmin.account_unban(pid), reload))
			else:
				_btn(act, L.t("ui.sadmin.acc_ban"), func(): _ban_dialog(pid, str(d.get("pseudo", "?")), reload), true)
	# derniers messages publics
	_title(_body, L.t("ui.sadmin.card_messages"))
	var msgs: Variant = d.get("messages")
	if msgs is Array and not (msgs as Array).is_empty():
		for m in msgs:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var mid := int(m.get("id", 0))
			var deleted := bool(m.get("deleted", false))
			var l := _label("%s · %s · %s" % [date(m.get("created_at")), Chat.room_name(str(m.get("room", ""))), str(m.get("body", ""))], UiTheme.DIM if deleted else UiTheme.PARCH, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.x = 60
			h.add_child(l)
			if not deleted and my_rank > target_rank:
				_btn(h, L.t("ui.sadmin.chat_delete"), func(): _run(func(): return await SuperAdmin.chat_delete(mid), reload))
			_body.add_child(h)
	else:
		_note(_body, L.t("ui.sadmin.card_no_messages"), UiTheme.DIM, false)
	if my_rank >= 3:
		_runs_section(pid)
	# notes internes et historique complet
	var extra := VBoxContainer.new()
	extra.add_theme_constant_override("separation", 3)
	_body.add_child(extra)
	_fill_card_extras(extra, pid, my_rank)
	_fit()

## Boutons de nomination / retrait selon mon rang et celui de la cible (le serveur revérifie).
func _role_buttons(parent: Control, pid: String, pseudo: String, target_rank: int, reload: Callable) -> void:
	var my_rank := SuperAdmin.rank()
	if my_rank < 2:
		return
	var set_role := func(new_role: String, title_key: String, text_key: String):
		_ask(L.t(title_key), L.fa(L.t(text_key), pseudo), func(): _run(func(): return await SuperAdmin.set_role(pid, new_role), reload))
	if target_rank == 0:
		_btn(parent, L.t("ui.sadmin.role_make_mod"), func(): set_role.call("moderator", "ui.sadmin.role_make_mod", "ui.sadmin.role_make_mod_q"))
	elif target_rank == 1:
		_btn(parent, L.t("ui.sadmin.role_remove_mod"), func(): set_role.call("none", "ui.sadmin.role_remove_mod", "ui.sadmin.role_remove_mod_q"), true)
	if my_rank >= 3:
		if target_rank <= 1:
			_btn(parent, L.t("ui.sadmin.role_make_super"), func(): set_role.call("super_admin", "ui.sadmin.role_make_super", "ui.sadmin.role_make_super_q"))
		elif target_rank == 2:
			_btn(parent, L.t("ui.sadmin.role_demote_mod"), func(): set_role.call("moderator", "ui.sadmin.role_demote_mod", "ui.sadmin.role_demote_mod_q"))
			_btn(parent, L.t("ui.sadmin.role_remove_super"), func(): set_role.call("none", "ui.sadmin.role_remove_super", "ui.sadmin.role_remove_super_q"), true)

## Bannissement de compte : durée et motif.
func _ban_dialog(pid: String, pseudo: String, reload: Callable) -> void:
	_sanction_dialog("account", pid, pseudo, reload)

const WHY_COUNT := 6

## Sanction à durée choisie et motif type : "mute" (tchat, en minutes), "gallery" (publication) ou "account" (compte, développeur).
## La levée est automatique à l'échéance (le serveur compare à l'heure).
func _sanction_dialog(kind: String, pid: String, pseudo: String, reload: Callable) -> void:
	var title_key: String = {"mute": "ui.sadmin.mute_btn", "gallery": "ui.sadmin.gal_ban", "account": "ui.sadmin.acc_ban"}[kind]
	var m := Modal.open(_host, L.t(title_key), 460.0)
	m.add_text(L.fa(L.t("ui.sadmin.sanction_q_" + kind), pseudo), UiTheme.PARCH, 15)
	var amounts: Array = [60, 1440, 10080, 43200] if kind == "mute" else [24, 168, 720, 0]
	var names: Array = ["ui.sadmin.dur_h1", "ui.sadmin.dur_0", "ui.sadmin.dur_1", "ui.sadmin.dur_2"] if kind == "mute" else ["ui.sadmin.dur_0", "ui.sadmin.dur_1", "ui.sadmin.dur_2", "ui.sadmin.dur_3"]
	var ob := OptionButton.new()
	for n in names:
		ob.add_item(L.t(n))
	m.content.add_child(ob)
	var why := OptionButton.new()
	for i in WHY_COUNT:
		why.add_item(L.t("ui.sadmin.why_%d" % i))
	m.content.add_child(why)
	var free := LineEdit.new()
	free.placeholder_text = L.t("ui.sadmin.reason_hint")
	free.max_length = 120
	m.content.add_child(free)
	m.set_buttons([
		{"text": L.t("common.confirmer"), "primary": true, "cb": func():
			var amount: int = amounts[ob.selected]
			var reason := why.get_item_text(why.selected)
			if free.text.strip_edges() != "":
				reason += " — " + free.text.strip_edges()
			m.close()
			var go := func() -> Dictionary:
				match kind:
					"mute": return await SuperAdmin.chat_mute(pid, amount, reason)
					"gallery": return await SuperAdmin.gallery_ban_for(pid, amount, reason)
				return await SuperAdmin.account_ban(pid, amount, reason)
			_run(go, reload)},
		{"text": L.t("common.annuler"), "cb": func(): m.close()},
	])

# ------------------------------------------------------------------ onglet Équipe

func _build_team() -> void:
	var mine := _begin()
	_wait(_body)
	var r: Dictionary = await SuperAdmin.team()
	if mine != _gen or not _alive():
		return
	_clear(_body)
	if not r.ok or not (r.data is Array):
		_error(_body, r)
		return
	_status = Form.status_label(_body)
	var my_id := Cloud.user_id()
	var my_rank := SuperAdmin.rank()
	for x in r.data:
		var role := str(x.get("role", ""))
		var pid := str(x.get("player_id", ""))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label("%s%s — %s" % [_mark(role), str(x.get("pseudo", "?")), StaffBadges.role_name(role)], GOLD, 15))
		var by := str(x.get("granted_by_pseudo", "")) if x.get("granted_by_pseudo") != null else ""
		var since := L.fa(L.t("ui.sadmin.team_since"), date(x.get("granted_at")))
		info.add_child(_label(since + ((" · " + L.fa(L.t("ui.sadmin.team_by"), by)) if by != "" else ""), UiTheme.DIM, 12))
		h.add_child(info)
		_btn(h, L.t("ui.sadmin.card_btn"), func(): _open_card(pid))
		if pid != my_id and int(x.get("rank", 0)) < my_rank:
			var rk := int(x.get("rank", 0))
			if rk <= 1 or my_rank >= 3:
				_btn(h, L.t("ui.sadmin.team_remove"), func():
					_ask(L.t("ui.sadmin.team_remove"), L.fa(L.t("ui.sadmin.team_remove_q"), str(x.get("pseudo", "?"))),
						func(): _run(func(): return await SuperAdmin.set_role(pid, "none"), func(): _show("team"))), true)
		_body.add_child(h)
		_body.add_child(HSeparator.new())
	if my_rank >= 2:
		_title(_body, L.t("ui.sadmin.team_add"))
		_note(_body, L.t("ui.sadmin.team_add_hint"), UiTheme.DIM, false)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		_search = LineEdit.new()
		_search.placeholder_text = L.t("ui.sadmin.search_hint")
		_search.max_length = 20
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(_search)
		_list = VBoxContainer.new()
		_list.add_theme_constant_override("separation", 4)
		_search.text_submitted.connect(func(_t): _fill_candidates())
		_btn(line, L.t("ui.sadmin.search"), _fill_candidates)
		_body.add_child(line)
		_body.add_child(_list)
	_fit()

## Résultats de recherche pour nommer quelqu'un (8 au plus).
func _fill_candidates() -> void:
	var box := _list
	if box == null or _search == null:
		return
	var q := _search.text.strip_edges()
	if q == "":
		_clear(box)
		return
	var mine := _gen
	_clear(box)
	_wait(box)
	var r: Dictionary = await SuperAdmin.players(q, 8, 0)
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	if (r.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.none"))
	for p in r.data:
		var pid := str(p.get("id", ""))
		var pseudo := str(p.get("pseudo", "?"))
		var rank := int(SuperAdmin.RANKS.get(str(p.get("role", "")) if p.get("role") != null else "", 0))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := _label("%s%s" % [_mark(str(p.get("role", "")) if p.get("role") != null else ""), pseudo])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		_btn(h, L.t("ui.sadmin.card_btn"), func(): _open_card(pid))
		if rank < SuperAdmin.rank():
			var do := func(role: String, q_key: String):
				_ask(L.t("ui.sadmin.team_add"), L.fa(L.t(q_key), pseudo), func(): _run(func(): return await SuperAdmin.set_role(pid, role), func(): _show("team")))
			if rank == 0:
				_btn(h, L.t("ui.sadmin.role_make_mod"), func(): do.call("moderator", "ui.sadmin.role_make_mod_q"))
			if SuperAdmin.is_dev() and rank <= 1:
				_btn(h, L.t("ui.sadmin.role_make_super"), func(): do.call("super_admin", "ui.sadmin.role_make_super_q"))
		box.add_child(h)
	_fit()

# ------------------------------------------------------------------ onglet Journal

const LOG_ACTIONS := ["chat_mute", "chat_unmute", "chat_delete", "chat_word_add", "chat_word_remove", "gallery_ban", "gallery_unban",
	"gallery_unpublish", "gallery_delete", "role_set", "role_remove", "account_ban", "account_unban", "announce", "announce_clear",
	"maintenance", "board_reset", "run_cancel", "run_view", "note_add", "note_delete", "report_handle", "flag_set"]
const LOG_PERIODS := [1, 7, 30, 0]

static func _action_name(a: String) -> String:
	var k := "ui.sadmin.act_" + a
	var t := L.t(k)
	return a if t == k else t

## Détail lisible d'une entrée du journal.
static func _detail_text(a: String, d: Variant) -> String:
	if not (d is Dictionary):
		return ""
	var x: Dictionary = d
	var parts: Array[String] = []
	for k in ["title", "word", "body", "role", "previous", "reason", "message", "hours", "kind", "period", "difficulty", "runs", "run", "note", "count", "key", "value"]:
		if x.get(k) != null and str(x.get(k)) != "":
			parts.append("%s: %s" % [k, str(x.get(k))])
	if x.get("until") != null:
		parts.append("→ " + date(x.get("until")))
	if x.get("ranked_closed") != null:
		parts.append("%s: %s · %s: %s" % ["classé fermé", str(x.get("ranked_closed")), "tchat fermé", str(x.get("chat_closed"))])
	return " · ".join(parts)

func _since_iso() -> String:
	if _log_days <= 0:
		return ""
	return Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - _log_days * 86400) + "Z"

func _build_log() -> void:
	_begin()
	var f := _flow(_body)
	var act := OptionButton.new()
	act.add_item(L.t("ui.sadmin.log_all"))
	var sel := 0
	for i in LOG_ACTIONS.size():
		act.add_item(_action_name(LOG_ACTIONS[i]))
		if LOG_ACTIONS[i] == _log_action:
			sel = i + 1
	act.select(sel)
	act.item_selected.connect(func(i: int):
		_log_action = "" if i == 0 else str(LOG_ACTIONS[i - 1])
		_log_limit = 100
		_fill_log())
	f.add_child(act)
	var per := OptionButton.new()
	var psel := 0
	for i in LOG_PERIODS.size():
		per.add_item(L.t("ui.sadmin.log_p%d" % i))
		if LOG_PERIODS[i] == _log_days:
			psel = i
	per.select(psel)
	per.item_selected.connect(func(i: int):
		_log_days = int(LOG_PERIODS[i])
		_log_limit = 100
		_fill_log())
	f.add_child(per)
	if SuperAdmin.is_super():
		var who := OptionButton.new()
		who.add_item(L.t("ui.sadmin.log_everyone"))
		who.item_selected.connect(func(i: int):
			_log_actor = "" if i == 0 else str(who.get_item_metadata(i))
			_log_limit = 100
			_fill_log())
		f.add_child(who)
		_fill_actor_picker(who)
		_btn(f, L.t("ui.sadmin.log_export"), _export_log)
	_log_search = LineEdit.new()
	_log_search.placeholder_text = L.t("ui.sadmin.log_search")
	_log_search.clear_button_enabled = true
	_log_search.custom_minimum_size.x = 180
	_log_search.text_changed.connect(func(_t: String): _render_log())
	f.add_child(_log_search)
	if SuperAdmin.rank() < 2:
		_note(_body, L.t("ui.sadmin.log_mine"), UiTheme.DIM, false)
	_status = Form.status_label(_body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_body.add_child(_list)
	_fill_log()

func _fill_log() -> void:
	var box := _list
	if box == null:
		return
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var r: Dictionary = await SuperAdmin.log_list(_log_action, _since_iso(), _log_limit, 0, _log_actor)
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	_log_rows = r.data
	_render_log()

## Affiche les lignes chargées, filtrées par le texte cherché (pseudo, action, détail).
func _render_log() -> void:
	var box := _list
	if box == null or not is_instance_valid(box):
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var q := _fold(_log_search.text.strip_edges()) if _log_search != null and is_instance_valid(_log_search) else ""
	var rows: Array = []
	for x in _log_rows:
		var hay := _fold("%s %s %s %s %s" % [str(x.get("actor_pseudo", "")), str(x.get("target_pseudo", "")), _action_name(str(x.get("action", ""))), str(x.get("action", "")), _detail_text(str(x.get("action", "")), x.get("detail"))])
		if q == "" or hay.contains(q):
			rows.append(x)
	if rows.is_empty():
		_note(box, L.t("ui.sadmin.log_none"))
		return
	for x in rows:
		var who := str(x.get("actor_pseudo", "?")) if x.get("actor_pseudo") != null else "—"
		var tgt := (" → " + str(x.get("target_pseudo"))) if x.get("target_pseudo") != null else ""
		var l := _label("%s · %s · %s%s" % [date(x.get("created_at")), who, _action_name(str(x.get("action", ""))), tgt], UiTheme.PARCH, 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 60
		box.add_child(l)
		var det := _detail_text(str(x.get("action", "")), x.get("detail"))
		if det != "":
			var dl := _label("   " + det, UiTheme.DIM, 12)
			dl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			dl.custom_minimum_size.x = 60
			box.add_child(dl)
	if _log_rows.size() >= _log_limit:
		_btn(box, L.t("ui.sadmin.log_more"), func():
			_log_limit += 100
			_fill_log())
	_fit()

func _fill_actor_picker(pick: OptionButton) -> void:
	var r: Dictionary = await SuperAdmin.team()
	if not _alive() or not is_instance_valid(pick) or not r.ok or not (r.data is Array):
		return
	for x in r.data:
		pick.add_item(str(x.get("pseudo", "?")))
		pick.set_item_metadata(pick.item_count - 1, str(x.get("player_id", "")))
		if str(x.get("player_id", "")) == _log_actor:
			pick.select(pick.item_count - 1)

## Exporte le journal filtré (jusqu'à 2000 lignes) en CSV.
func _export_log() -> void:
	_flash(L.t("ui.sadmin.loading"))
	var rows: Array = []
	for page in 4:
		var r: Dictionary = await SuperAdmin.log_list(_log_action, _since_iso(), 500, page * 500, _log_actor)
		if not _alive():
			return
		if not r.ok or not (r.data is Array):
			_flash(str(r.get("message", "")), BAD)
			return
		rows.append_array(r.data)
		if (r.data as Array).size() < 500:
			break
	var out := PackedStringArray(["date_utc,acteur,action,cible,detail"])
	for x in rows:
		var cells := [str(x.get("created_at", "")), str(x.get("actor_pseudo", "")) if x.get("actor_pseudo") != null else "",
			str(x.get("action", "")), str(x.get("target_pseudo", "")) if x.get("target_pseudo") != null else "", JSON.stringify(x.get("detail", {}))]
		out.append(",".join(cells.map(func(c): return '"%s"' % str(c).replace('"', '""'))))
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	Files.save_text(_host, "journal_%s.csv" % stamp, "\n".join(out) + "\n", func(msg: String): _flash(msg, GOOD), "text/csv", "*.csv ; Fichier CSV")

# ------------------------------------------------------------------ onglet Développeur

func _build_dev() -> void:
	var mine := _begin()
	_wait(_body)
	var h: Dictionary = await SuperAdmin.health()
	var bans: Dictionary = await SuperAdmin.account_bans()
	var bd: Dictionary = await SuperAdmin.boards()
	if mine != _gen or not _alive():
		return
	_clear(_body)
	if not h.ok or not (h.data is Dictionary):
		_error(_body, h)
		return
	var d: Dictionary = h.data
	_status = Form.status_label(_body)
	_flags_section(_body)
	# santé du serveur
	_title(_body, L.t("ui.sadmin.dev_health"))
	_kv(_body, L.t("ui.sadmin.dev_queue"), "%s (%s)" % [num(d.get("queue")), age(d.get("oldest_queue_seconds"))], GOOD if int(d.get("queue", 0)) == 0 else GOLD)
	_kv(_body, L.t("ui.sadmin.dev_in_progress"), num(d.get("in_progress")))
	_kv(_body, L.t("ui.sadmin.dev_stuck"), num(d.get("stuck_started")), GOOD if int(d.get("stuck_started", 0)) == 0 else BAD)
	_kv(_body, L.t("ui.sadmin.dev_expired_24h"), num(d.get("expired_24h")))
	_kv(_body, L.t("ui.sadmin.dev_chat_24h"), num(d.get("chat_24h")))
	_kv(_body, L.t("ui.sadmin.dev_actions_24h"), num(d.get("staff_actions_24h")))
	_kv(_body, L.t("ui.sadmin.dev_db"), _bytes(d.get("db_bytes")))
	var rj: Variant = d.get("rejected_24h")
	if rj is Array and not (rj as Array).is_empty():
		_note(_body, L.t("ui.sadmin.dev_rejected") + " " + ", ".join((rj as Array).map(func(x): return "%s ×%s" % [str(x.get("reason", "?")), num(x.get("n"))])), UiTheme.DIM, false)
	var tb: Variant = d.get("tables")
	if tb is Array and not (tb as Array).is_empty():
		_note(_body, L.t("ui.sadmin.dev_tables") + " " + ", ".join((tb as Array).map(func(x): return "%s %s" % [str(x.get("name", "?")), _bytes(x.get("bytes"))])), UiTheme.DIM, false)
	# maintenance
	_title(_body, L.t("ui.sadmin.dev_maint"))
	var st: Dictionary = d.get("server_state", {}) if d.get("server_state") is Dictionary else {}
	var c_ranked := CheckBox.new()
	c_ranked.text = L.t("ui.sadmin.dev_close_ranked")
	c_ranked.button_pressed = bool(st.get("ranked_closed", false))
	_body.add_child(c_ranked)
	var c_chat := CheckBox.new()
	c_chat.text = L.t("ui.sadmin.dev_close_chat")
	c_chat.button_pressed = bool(st.get("chat_closed", false))
	_body.add_child(c_chat)
	var msg := LineEdit.new()
	msg.placeholder_text = L.t("ui.sadmin.dev_maint_msg")
	msg.max_length = 300
	msg.text = str(st.get("message", "")) if st.get("message") != null else ""
	_body.add_child(msg)
	_btn(_body, L.t("ui.sadmin.dev_apply"), func(): _run(func(): return await SuperAdmin.set_server_state(c_ranked.button_pressed, c_chat.button_pressed, msg.text.strip_edges()),
		func():
			ServerNotice.refresh(true)
			_flash(L.t("ui.sadmin.dev_done"), GOOD)))
	# annonce
	_title(_body, L.t("ui.sadmin.dev_announce"))
	var ann := LineEdit.new()
	ann.placeholder_text = L.t("ui.sadmin.dev_announce_hint")
	ann.max_length = 400
	_body.add_child(ann)
	var line := _flow(_body)
	var dur := OptionButton.new()
	var hours := [1, 6, 24, 72, 168]
	for i in hours.size():
		dur.add_item(L.t("ui.sadmin.ann_%d" % i))
	dur.select(2)
	line.add_child(dur)
	_btn(line, L.t("ui.sadmin.dev_publish"), func():
		if ann.text.strip_edges() == "":
			return
		_run(func(): return await SuperAdmin.announce(ann.text.strip_edges(), int(hours[dur.selected])),
			func():
				ServerNotice.refresh(true)
				ann.text = ""
				_flash(L.t("ui.sadmin.dev_done"), GOOD)))
	_btn(line, L.t("ui.sadmin.dev_withdraw"), func(): _run(func(): return await SuperAdmin.announce_clear(),
		func():
			ServerNotice.refresh(true)
			_flash(L.t("ui.sadmin.dev_done"), GOOD)))
	# comptes bannis
	_title(_body, L.t("ui.sadmin.dev_bans"))
	if bans.ok and bans.data is Array and not (bans.data as Array).is_empty():
		for b in bans.data:
			var pid := str(b.get("player_id", ""))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var l := _label("%s — %s%s" % [str(b.get("pseudo", "?")), L.t("ui.sadmin.forever") if b.get("until") == null else L.fa(L.t("ui.sadmin.until"), date(b.get("until"))),
				(" · " + str(b.get("reason"))) if b.get("reason") != null else ""], UiTheme.PARCH, 13)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 60
			row.add_child(l)
			_btn(row, L.t("ui.sadmin.acc_unban"), func(): _run(func(): return await SuperAdmin.account_unban(pid), func(): _show("dev")))
			_body.add_child(row)
	else:
		_note(_body, L.t("ui.sadmin.dev_no_bans"), UiTheme.DIM, false)
	# réinitialisation d'un classement
	_title(_body, L.t("ui.sadmin.dev_boards"))
	_note(_body, L.t("ui.sadmin.dev_boards_hint"), UiTheme.DIM, false)
	var boards: Array = bd.data if bd.ok and bd.data is Array else []
	if boards.is_empty():
		_note(_body, L.t("ui.sadmin.none"), UiTheme.DIM, false)
	else:
		var ob := OptionButton.new()
		for x in boards:
			ob.add_item("%s%s — %s %s" % [mode_name(str(x.get("difficulty", "")) if x.get("difficulty") != null else "", str(x.get("kind", ""))),
				(" " + str(x.get("period"))) if x.get("period") != null else "", num(x.get("verified")), L.t("ui.sadmin.dev_runs_word")])
		_body.add_child(ob)
		_btn(_body, L.t("ui.sadmin.dev_reset"), func():
			var x: Dictionary = boards[ob.selected]
			var kind := str(x.get("kind", ""))
			var period := str(x.get("period", "")) if x.get("period") != null else ""
			var diff := str(x.get("difficulty", "")) if x.get("difficulty") != null else ""
			_typed_confirm(L.t("ui.sadmin.dev_reset"), L.fa(L.t("ui.sadmin.dev_reset_q"), ob.get_item_text(ob.selected)), "REINITIALISER", func():
				var r: Dictionary = await SuperAdmin.reset_board(kind, period, diff, "REINITIALISER")
				if _alive():
					_flash(L.fa(L.t("ui.sadmin.dev_reset_done"), int(r.data if r.data != null else 0)) if r.ok else str(r.get("message", "")), GOOD if r.ok else BAD)), true)
	# annulation d'une partie
	_title(_body, L.t("ui.sadmin.dev_cancel"))
	_note(_body, L.t("ui.sadmin.dev_cancel_hint"), UiTheme.DIM, false)
	var run_id := LineEdit.new()
	run_id.placeholder_text = L.t("ui.sadmin.dev_cancel_id")
	run_id.max_length = 40
	_body.add_child(run_id)
	_btn(_body, L.t("ui.sadmin.dev_cancel_btn"), func():
		var id := run_id.text.strip_edges()
		if id == "":
			return
		_typed_confirm(L.t("ui.sadmin.dev_cancel_btn"), L.fa(L.t("ui.sadmin.dev_cancel_q"), id), "ANNULER", func():
			var r: Dictionary = await SuperAdmin.cancel_run(id, "annulation")
			if _alive():
				_flash(L.t("ui.sadmin.dev_done") if r.ok else str(r.get("message", "")), GOOD if r.ok else BAD)), true)
	_fit()

static func _bytes(v: Variant) -> String:
	if v == null:
		return "—"
	var b := float(v)
	if b >= 1048576.0:
		return "%.1f Mo" % (b / 1048576.0)
	return "%d Ko" % int(b / 1024.0)

# ------------------------------------------------------------------ parties d'un joueur : revoir / CSV (développeur)

## Section « Parties » de la fiche : 30 dernières parties, avec « Revoir » (dans le moteur) et « CSV ».
func _runs_section(pid: String) -> void:
	_title(_body, L.t("ui.sadmin.card_runs"))
	_note(_body, L.t("ui.sadmin.card_runs_dev"), UiTheme.DIM, false)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_body.add_child(box)
	_fill_runs_section(box, pid)

func _fill_runs_section(box: VBoxContainer, pid: String) -> void:
	var mine := _gen
	_wait(box)
	var r: Dictionary = await SuperAdmin.player_runs(pid)
	if mine != _gen or not _alive():
		return
	_clear(box)
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	if (r.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.card_no_runs"), UiTheme.DIM, false)
		return
	for x in r.data:
		var id := str(x.get("id", ""))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var txt := "%s · %s%s · %s · %s · v%s" % [date(x.get("started_at")), mode_name(str(x.get("difficulty", "")), str(x.get("kind", ""))),
			(" 🧪" if bool(x.get("test", false)) else ""), status_name(str(x.get("status", ""))),
			("%s pts" % num(x.get("score"))) if x.get("score") != null else "—", str(x.get("game_version", "?"))]
		if x.get("seconds") != null:
			txt += " · " + age(x.get("seconds"))
		if bool(x.get("has_log", false)):
			txt += " · %s act." % num(x.get("actions"))
		else:
			txt += " · " + L.t("ui.sadmin.run_nolog")
		var l := _label(txt, UiTheme.PARCH, 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 60
		h.add_child(l)
		if bool(x.get("has_log", false)):
			_btn(h, L.t("ui.sadmin.run_watch"), func(): _watch(id))
			_btn(h, L.t("ui.sadmin.run_csv"), func(): _export_csv(id))
		box.add_child(h)
	_fit()

## Charge une partie complète (avec journal) puis appelle `then(meta)`.
func _with_run(id: String, then: Callable) -> void:
	_flash(L.t("ui.sadmin.run_loading"))
	var r: Dictionary = await SuperAdmin.run_log(id)
	if not _alive():
		return
	if not r.ok or not (r.data is Dictionary):
		_flash(str(r.get("message", "")), BAD)
		return
	_flash("")
	then.call(r.data)

## Lance le rejeu : la fenêtre d'administration se ferme, le jeu démarre avec la barre de commandes du rejeu.
func _watch(id: String) -> void:
	_with_run(id, func(meta: Dictionary):
		var err := ReplayLive.open(meta)
		if err != "":
			_flash(err, BAD)
		else:
			_modal.close())

func _export_csv(id: String) -> void:
	_with_run(id, func(meta: Dictionary):
		if not (meta.get("log") is Array) or (meta.log as Array).is_empty():
			_flash(L.t("ui.replay.no_log"), BAD)
			return
		Files.save_text(_host, RunExport.file_name(meta, "csv"), RunExport.to_csv(meta), func(msg: String): _flash(msg, GOOD), "text/csv;charset=utf-8", "*.csv ; Fichier CSV"))

# ------------------------------------------------------------------ joueurs signalés (sous-onglet Modération)

func _build_player_reports() -> void:
	_begin()
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_body.add_child(_list)
	_fill_player_reports()

func _fill_player_reports() -> void:
	var box := _list
	_gen += 1
	var mine := _gen
	_clear(box)
	_wait(box)
	var r: Dictionary = await SuperAdmin.player_reports()
	if mine != _gen or not _alive():
		return
	_clear(box)
	_status = Form.status_label(box)
	_title(box, L.t("ui.sadmin.pr_title"))
	_note(box, L.t("ui.sadmin.pr_desc"))
	if not r.ok or not (r.data is Array):
		_error(box, r)
		return
	if (r.data as Array).is_empty():
		_note(box, L.t("ui.sadmin.pr_none"))
		return
	for x in r.data:
		var pid := str(x.get("player_id", ""))
		var pseudo := str(x.get("pseudo", "?"))
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.add_child(_label("%s%s%s · %s · %s" % [pseudo, " 🔇" if x.get("muted_until") != null else "", " 🚫" if bool(x.get("banned", false)) else "",
			L.t("ui.sadmin.chat_n_reports") % num(x.get("reports")), date(x.get("last_report"))], GOLD, 13))
		var reasons: Variant = x.get("reasons")
		if reasons is Array and not (reasons as Array).is_empty():
			_note(card, "↳ " + " | ".join((reasons as Array).map(func(rs): return str(rs))), UiTheme.DIM, false)
		var act := _flow(card)
		_btn(act, L.t("ui.sadmin.card_btn"), func(): _open_card(pid))
		_btn(act, L.t("ui.sadmin.pr_handle"), func(): _note_dialog(L.t("ui.sadmin.pr_handle"), L.fa(L.t("ui.sadmin.pr_handle_q"), pseudo), func(txt: String):
			_run(func(): return await SuperAdmin.player_report_handle(pid, txt), _fill_player_reports)))
		if x.get("muted_until") == null:
			_btn(act, L.t("ui.sadmin.chat_mute_24h"), func(): _run(func(): return await SuperAdmin.chat_mute(pid, 1440, "signalement"), _fill_player_reports))
		card.add_child(HSeparator.new())
		box.add_child(card)
	_fit()

## Fenêtre avec une zone de texte facultative ; `ok` reçoit le texte saisi.
func _note_dialog(title: String, question: String, ok: Callable, max_len: int = 300) -> void:
	var m := Modal.open(_host, title, 460.0)
	m.add_text(question, UiTheme.PARCH, 15)
	var le := LineEdit.new()
	le.max_length = max_len
	le.placeholder_text = L.t("ui.sadmin.note_hint")
	m.content.add_child(le)
	m.set_buttons([
		{"text": L.t("common.confirmer"), "primary": true, "cb": func():
			var txt := le.text.strip_edges()
			m.close()
			ok.call(txt)},
		{"text": L.t("common.annuler"), "cb": func(): m.close()},
	])

# ------------------------------------------------------------------ fiche joueur : notes internes et historique

func _fill_card_extras(box: VBoxContainer, pid: String, my_rank: int) -> void:
	var mine := _gen
	_wait(box)
	var nr: Dictionary = await SuperAdmin.notes(pid)
	var hr: Dictionary = await SuperAdmin.history(pid)
	if mine != _gen or not _alive():
		return
	_clear(box)
	# notes internes (visibles de l'équipe seulement)
	_title(box, L.t("ui.sadmin.notes_title"))
	_note(box, L.t("ui.sadmin.notes_desc"), UiTheme.DIM, false)
	var me := Cloud.user_id()
	if nr.ok and nr.data is Array:
		for n in nr.data:
			var nid := int(n.get("id", 0))
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			var l := _label("%s · %s · %s" % [date(n.get("created_at")), str(n.get("author_pseudo", "—")) if n.get("author_pseudo") != null else "—", str(n.get("body", ""))], UiTheme.PARCH, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.x = 60
			h.add_child(l)
			if str(n.get("author", "")) == me or my_rank >= 2:
				_btn(h, "✕", func(): _run(func(): return await SuperAdmin.note_delete(nid), func(): _fill_card_extras(box, pid, my_rank)))
			box.add_child(h)
		if (nr.data as Array).is_empty():
			_note(box, L.t("ui.sadmin.notes_none"), UiTheme.DIM, false)
	else:
		_error(box, nr)
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 8)
	var le := LineEdit.new()
	le.max_length = 500
	le.placeholder_text = L.t("ui.sadmin.notes_hint")
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.add_child(le)
	var go := func():
		var txt := le.text.strip_edges()
		if txt == "":
			return
		_run(func(): return await SuperAdmin.note_add(pid, txt), func(): _fill_card_extras(box, pid, my_rank))
	_btn(add, L.t("ui.sadmin.notes_add"), go)
	le.text_submitted.connect(func(_t: String): go.call())
	box.add_child(add)
	# historique
	_title(box, L.t("ui.sadmin.hist_title"))
	if not hr.ok or not (hr.data is Dictionary):
		_error(box, hr)
		_fit()
		return
	var d: Dictionary = hr.data
	var c: Dictionary = d.get("counts", {})
	_kv(box, L.t("ui.sadmin.hist_chat_reported"), num(c.get("chat_reported")), GOLD if int(c.get("chat_reported", 0)) > 0 else UiTheme.PARCH)
	_kv(box, L.t("ui.sadmin.hist_chat_deleted"), num(c.get("chat_deleted")))
	_kv(box, L.t("ui.sadmin.hist_gallery_reported"), num(c.get("gallery_reported")), GOLD if int(c.get("gallery_reported", 0)) > 0 else UiTheme.PARCH)
	_kv(box, L.t("ui.sadmin.hist_player_reported"), num(c.get("player_reported")), GOLD if int(c.get("player_reported", 0)) > 0 else UiTheme.PARCH)
	_kv(box, L.t("ui.sadmin.hist_runs_rejected"), num(c.get("runs_rejected")), BAD if int(c.get("runs_rejected", 0)) > 0 else UiTheme.PARCH)
	var ps: Array = d.get("pseudos", [])
	if ps.size() > 1:
		_note(box, L.t("ui.sadmin.hist_pseudos") + " " + " ← ".join(ps.map(func(x): return "%s (%s)" % [str(x.get("pseudo", "?")), date(x.get("changed_at"))])), UiTheme.DIM, false)
	var acts: Array = d.get("actions", [])
	if acts.is_empty():
		_note(box, L.t("ui.sadmin.hist_none"), UiTheme.DIM, false)
	for x in acts:
		var det := _detail_text(str(x.get("action", "")), x.get("detail"))
		var l := _label("%s · %s · %s%s" % [date(x.get("created_at")), _action_name(str(x.get("action", ""))), str(x.get("actor_pseudo", "—")) if x.get("actor_pseudo") != null else "—", (" · " + det) if det != "" else ""], UiTheme.DIM, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size.x = 60
		box.add_child(l)
	_fit()

# ------------------------------------------------------------------ onglet Suspectes (super admin)

func _build_suspects() -> void:
	var mine := _begin()
	_wait(_body)
	var r: Dictionary = await SuperAdmin.suspect_runs(14)
	if mine != _gen or not _alive():
		return
	_clear(_body)
	_status = Form.status_label(_body)
	_note(_body, L.t("ui.sadmin.sus_desc"))
	if not r.ok or not (r.data is Array):
		_error(_body, r)
		return
	if (r.data as Array).is_empty():
		_note(_body, L.t("ui.sadmin.sus_none"), GOOD)
		return
	for x in r.data:
		var pid := str(x.get("player_id", ""))
		var id := str(x.get("run_id", ""))
		var flags: Array = x.get("flags", [])
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		var tags := " · ".join(flags.map(func(f): return L.t("ui.sadmin.sus_flag_" + str(f))))
		card.add_child(_label("%s · %s · %s" % [str(x.get("pseudo", "?")), mode_name(str(x.get("difficulty", "")), ""), tags], GOLD, 13))
		var info := "%s · %s · %s" % [date(x.get("at")), status_name(str(x.get("status", ""))),
			("%s pts" % num(x.get("score"))) if x.get("score") != null else "—"]
		if x.get("seconds") != null:
			info += " · " + age(x.get("seconds"))
		if x.get("ratio") != null:
			info += " · " + L.fa(L.t("ui.sadmin.sus_ratio"), [int(round(float(x.get("ratio")) * 100.0))])
		if x.get("reject_reason") != null:
			info += " · " + str(x.get("reject_reason"))
		card.add_child(_label(info, UiTheme.PARCH, 12))
		var act := _flow(card)
		_btn(act, L.t("ui.sadmin.card_btn"), func(): _open_card(pid))
		if SuperAdmin.is_dev() and bool(x.get("has_log", false)):
			_btn(act, L.t("ui.sadmin.run_watch"), func(): _watch(id))
			_btn(act, L.t("ui.sadmin.run_csv"), func(): _export_csv(id))
		card.add_child(HSeparator.new())
		_body.add_child(card)
	_fit()

# ------------------------------------------------------------------ statistiques d'activité (vue d'ensemble)

func _stats_section(box: VBoxContainer) -> void:
	_title(box, L.t("ui.sadmin.stats_title"))
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	box.add_child(holder)
	_fill_stats(holder, 14)

func _fill_stats(holder: VBoxContainer, days: int) -> void:
	var mine := _gen
	_clear(holder)
	_wait(holder)
	var r: Dictionary = await SuperAdmin.stats(days)
	if mine != _gen or not _alive() or not is_instance_valid(holder):
		return
	_clear(holder)
	if not r.ok or not (r.data is Dictionary):
		_error(holder, r)
		return
	var f := _flow(holder)
	for dd in [7, 14, 30, 90]:
		var b := _btn(f, L.fa(L.t("ui.sadmin.stats_days"), [dd]), func(): _fill_stats(holder, dd))
		b.toggle_mode = true
		b.button_pressed = dd == days
	var rows: Array = (r.data as Dictionary).get("days", [])
	var labels: Array = rows.map(func(x): return str(x.get("day", "")).substr(5))
	var series := [["signups", "ui.sadmin.stats_signups", Color("9cc79a")], ["runs", "ui.sadmin.stats_runs", Color("d4a24c")],
		["chat", "ui.sadmin.stats_chat", Color("7aa7d6")], ["dungeons", "ui.sadmin.stats_dungeons", Color("c58ad6")]]
	for sp in series:
		var vals: Array = rows.map(func(x): return int(x.get(sp[0], 0)))
		var total := 0
		for v in vals:
			total += int(v)
		holder.add_child(_label("%s — %s" % [L.t(sp[1]), L.fa(L.t("ui.sadmin.stats_total"), [total])], GOLD, 13))
		holder.add_child(MiniBars.new().setup(vals, labels, sp[2]))
	_fit()

# ------------------------------------------------------------------ réglages à distance (développeur)

func _flags_section(box: VBoxContainer) -> void:
	_title(box, L.t("ui.sadmin.flags_title"))
	_note(box, L.t("ui.sadmin.flags_desc"), UiTheme.DIM, false)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	box.add_child(holder)
	_fill_flags(holder)

func _fill_flags(holder: VBoxContainer) -> void:
	await ServerFlags.refresh(true)
	if not _alive() or not is_instance_valid(holder):
		return
	_clear(holder)
	for key in ["gallery_publish", "reports_enabled"]:
		var on := ServerFlags.is_on(key, true)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := _label(L.t("ui.sadmin.flag_" + key), UiTheme.PARCH, 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var b := _btn(h, L.t("ui.sadmin.flag_open") if on else L.t("ui.sadmin.flag_closed"), func():
			_run(func(): return await SuperAdmin.flag_set(key, not on), func(): _fill_flags(holder)))
		b.add_theme_color_override("font_color", GOOD if on else BAD)
		holder.add_child(h)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	var ql := _label(L.t("ui.sadmin.flag_queue_alert"), UiTheme.PARCH, 14)
	ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q.add_child(ql)
	var sp := SpinBox.new()
	sp.min_value = 1
	sp.max_value = 999
	sp.value = ServerFlags.number("queue_alert", 5)
	q.add_child(sp)
	_btn(q, L.t("ui.sadmin.flag_save"), func(): _run(func(): return await SuperAdmin.flag_set("queue_alert", int(sp.value)), func(): _fill_flags(holder)))
	holder.add_child(q)
	_fit()
