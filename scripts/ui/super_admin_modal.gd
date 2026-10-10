class_name SuperAdminModal
extends RefCounted
## « Super admin » : parties classées de TEST (sans essai consommé, hors classements) et statistiques de toute la partie en ligne
## (vue d'ensemble, joueurs, parties). Réservé aux comptes présents dans la table `admins` du serveur : le serveur vérifie le rôle à
## chaque appel, l'écran n'est qu'une vitrine (voir SuperAdmin). Ni courriel ni journal d'actions n'y figurent.

const STATUSES := ["started", "submitted", "verified", "rejected", "expired"]
const GOLD := Color("ffd98a")
const BAD := Color("e08a7a")
const GOOD := Color("9cc79a")
const ROW_SIZE := 14

var _host: Node
var _modal: Modal
var _tab := "tests"
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

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _build() -> void:
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	_modal.content.add_child(tabs)
	for t in ["tests", "overview", "players", "runs", "chat"]:
		var b := Button.new()
		b.text = L.t("ui.sadmin.tab_" + t)
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
		"chat": _build_chat()

# ------------------------------------------------------------------ outils d'affichage

func _begin() -> int:
	_gen += 1
	_clear(_body)
	_list = null
	_status = null
	return _gen

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
	_cells(box, [L.t("ui.sadmin.col_player"), L.t("ui.sadmin.col_level"), L.t("ui.sadmin.col_xp"), L.t("ui.sadmin.col_runs_ok"), L.t("ui.sadmin.col_best"), L.t("ui.sadmin.col_last")], w, UiTheme.DIM)
	for p in rows:
		var name := str(p.get("pseudo", "?")) + (" 🛡️" if bool(p.get("admin", false)) else "")
		_cells(box, [name, num(p.get("level")), num(p.get("xp")), "%s/%s" % [num(p.get("verified")), num(p.get("runs"))], num(p.get("best_score")), date(p.get("last_run_at"))], w)
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
	_title(box, L.t("ui.sadmin.chat_words") % (wd.data.size() if wd.ok and wd.data is Array else 0))
	_note(box, L.t("ui.sadmin.chat_words_desc"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var e := LineEdit.new()
	e.max_length = 30
	e.placeholder_text = L.t("ui.sadmin.chat_word_hint")
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(e)
	var add := Button.new()
	add.text = L.t("ui.sadmin.chat_word_add")
	add.focus_mode = Control.FOCUS_NONE
	var do_add := func():
		var r: Dictionary = await SuperAdmin.chat_word_add(e.text)
		if mine != _gen or not _alive():
			return
		if r.ok:
			_fill_chat()
		else:
			_flash(str(r.message), BAD)
	add.pressed.connect(do_add)
	e.text_submitted.connect(func(_t): do_add.call())
	h.add_child(add)
	box.add_child(h)
	if wd.ok and wd.data is Array:
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 4)
		for w in wd.data:
			var b := Button.new()
			b.text = "%s ✕" % str(w)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = L.t("ui.sadmin.chat_word_remove")
			var word := str(w)
			b.pressed.connect(func():
				var r: Dictionary = await SuperAdmin.chat_word_remove(word)
				if mine == _gen and _alive():
					if r.ok:
						_fill_chat()
					else:
						_flash(str(r.message), BAD))
			fl.add_child(b)
		box.add_child(fl)
	_fit()

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
