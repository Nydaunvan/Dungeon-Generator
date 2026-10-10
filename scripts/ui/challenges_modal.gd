class_name ChallengesModal
extends RefCounted
## Fenêtre qui s'ouvre avant la génération d'un donjon aléatoire : défis en cours et classements, puis « Lancer un donjon aléatoire »
## (qui mène aux réglages habituels). On peut toujours revenir au menu. Hors ligne ou sans compte, le jeu reste jouable.

const TOP := 10
const DIFF_KEYS := {"easy": "ui.challenges.diff_easy", "normal": "ui.challenges.diff_normal", "hard": "ui.challenges.diff_hard", "hardcore": "ui.challenges.diff_hardcore"}

var _host: Node
var _modal: Modal
var _on_launch: Callable
var _gen := 0                  # numéro du chargement en cours : un chargement périmé n'affiche plus rien

## `on_launch` : appelé quand le joueur choisit de lancer un donjon (la fenêtre est alors fermée).
static func open(host: Node, on_launch: Callable) -> ChallengesModal:
	var c := ChallengesModal.new()
	c._host = host
	c._on_launch = on_launch
	c._modal = Modal.open(host, L.t("ui.challenges.title"), 620.0)
	c._modal.closed.connect(c._on_closed)
	Cloud.session_changed.connect(c._on_session)
	c._buttons()
	c._load()
	return c

func _alive() -> bool:
	return is_instance_valid(_modal) and not _modal.is_queued_for_deletion()

func _on_closed() -> void:
	if Cloud.session_changed.is_connected(_on_session):
		Cloud.session_changed.disconnect(_on_session)

func _on_session() -> void:
	if _alive():
		_buttons()
		_load()

func _buttons() -> void:
	var specs: Array = [{"text": L.t("ui.challenges.launch"), "primary": true, "cb": _launch}]
	if Cloud.is_configured() and not Cloud.is_signed_in():
		specs.append({"text": L.t("ui.challenges.login"), "cb": func(): AccountModal.open(_host)})
	elif Cloud.is_configured():
		specs.append({"text": L.t("ui.challenges.refresh"), "cb": _load})
	specs.append({"text": L.t("ui.challenges.back"), "cb": func(): _modal.close()})
	_modal.set_buttons(specs)

func _launch() -> void:
	_modal.close()
	if _on_launch.is_valid():
		_on_launch.call()

func _clear() -> void:
	for c in _modal.content.get_children():
		_modal.content.remove_child(c)
		c.queue_free()

func _text(parent: Control, text: String, color: Color = UiTheme.PARCH, size: int = 15, italic: bool = false, center: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if italic:
		l.add_theme_font_override("font", UiTheme.font(UiTheme.F_BODY_ITALIC))
	parent.add_child(l)
	return l

func _load() -> void:
	_gen += 1
	var mine := _gen
	_clear()
	var c := _modal.content
	if not Cloud.is_configured():
		_text(c, L.t("ui.challenges.not_configured"), UiTheme.DIM, 14, true)
		return
	if not Cloud.is_signed_in():
		_text(c, L.t("ui.challenges.need_account"), Color("e0b87a"), 14, true)
	else:
		_text(c, L.fa(L.t("ui.challenges.signed_as"), Cloud.pseudo()), UiTheme.DIM, 13, true)
	if Cloud.is_signed_in():
		RankedRun.flush_pending()
	_hardcore_section(mine)
	var wait := _text(c, L.t("ui.challenges.loading"), UiTheme.DIM, 14, true)
	Challenges.flush_pending()
	var r: Dictionary = await Challenges.list(true)
	if mine != _gen or not _alive():
		return
	wait.queue_free()
	if not r.ok:
		_text(c, str(r.message), Color("e08a7a"), 14)
		return
	if (r.data as Array).is_empty():
		_text(c, L.t("ui.challenges.none"), UiTheme.DIM, 14, true)
		return
	for ch in r.data:
		_section(ch, mine)

func _section(ch: Dictionary, mine: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.content.add_child(box)
	_text(box, "🏆 " + Challenges.title_of(ch), UiTheme.GOLD, 19)
	var desc := Challenges.description_of(ch)
	if desc != "":
		_text(box, desc, UiTheme.DIM, 13, true)
	var wait := _text(box, L.t("ui.challenges.loading_board"), UiTheme.DIM, 13, true)
	_fill_board(box, wait, ch, mine)
	_modal.call_deferred("_fit")

func _fill_board(box: VBoxContainer, wait: Label, ch: Dictionary, mine: int) -> void:
	var r: Dictionary = await Challenges.board(str(ch.id), 100)
	if mine != _gen or not _alive() or not is_instance_valid(box):
		return
	wait.queue_free()
	if not r.ok:
		_text(box, str(r.message), Color("e08a7a"), 13)
		return
	var rows: Array = r.data if r.data is Array else []
	if rows.is_empty():
		_text(box, L.t("ui.challenges.empty_board"), UiTheme.DIM, 14, true)
		_modal.call_deferred("_fit")
		return
	var me := Cloud.user_id()
	var shown: Array = []          # [rang, ligne]
	var my_row := -1
	for i in rows.size():
		if str(rows[i].get("player_id", "")) == me and me != "":
			my_row = i
		if i < TOP:
			shown.append([i + 1, rows[i]])
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	_cell(grid, "#", UiTheme.DIM, 12, false, 36, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(grid, L.t("ui.challenges.col_player"), UiTheme.DIM, 12, true, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(grid, Challenges.unit_label(str(ch.get("unit", "points"))), UiTheme.DIM, 12, false, 90, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(grid, L.t("ui.challenges.col_time"), UiTheme.DIM, 12, false, 70, HORIZONTAL_ALIGNMENT_RIGHT)
	if my_row >= TOP:
		shown.append([0, null])       # séparateur « … »
		shown.append([my_row + 1, rows[my_row]])
	var any_declared := false
	for e in shown:
		if e[1] == null:
			for k in 4:
				_cell(grid, "…", UiTheme.DIM, 14, k == 1, 0, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var row: Dictionary = e[1]
		var is_me := me != "" and str(row.get("player_id", "")) == me
		var color: Color = UiTheme.GOLD if is_me else UiTheme.PARCH
		var verified := bool(row.get("verified", false))
		if not verified:
			any_declared = true
		_cell(grid, str(e[0]), color, 15, false, 36, HORIZONTAL_ALIGNMENT_RIGHT)
		var name_cell := _cell(grid, str(row.get("pseudo", "?")) + (" ✔" if verified else ""), color, 15, true, 0, HORIZONTAL_ALIGNMENT_LEFT)
		name_cell.tooltip_text = _details(row)
		name_cell.mouse_filter = Control.MOUSE_FILTER_PASS
		_cell(grid, str(int(row.get("score", 0))), color, 15, false, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(grid, Challenges.format_time(int(row.get("seconds", -1))) if row.get("seconds") != null else "–", color, 15, false, 70, HORIZONTAL_ALIGNMENT_RIGHT)
	if my_row < 0 and Cloud.is_signed_in():
		_text(box, L.t("ui.challenges.not_ranked"), UiTheme.DIM, 12, true)
	if any_declared:
		_text(box, L.t("ui.challenges.declared_note"), UiTheme.DIM, 12, true)
	_modal.call_deferred("_fit")

func _cell(grid: GridContainer, text: String, color: Color, size: int, expand: bool, min_w: float, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align as HorizontalAlignment
	l.clip_text = true
	l.custom_minimum_size = Vector2(min_w, 0)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	grid.add_child(l)
	return l

## Infobulle d'une ligne : expéditions, difficulté, monstres vaincus.
func _details(row: Dictionary) -> String:
	var d: Dictionary = row.get("details") if row.get("details") is Dictionary else {}
	var parts: Array = []
	if d.has("expeditions"):
		parts.append(L.fa(L.t("ui.challenges.d_expeditions"), int(d.expeditions)))
	if str(d.get("difficulty", "")) != "":
		var diff := str(d.difficulty)
		parts.append(L.fa(L.t("ui.challenges.d_difficulty"), L.t(DIFF_KEYS[diff]) if DIFF_KEYS.has(diff) else diff))
	if d.has("kills"):
		parts.append(L.fa(L.t("ui.challenges.d_kills"), int(d.kills)))
	return "\n".join(parts)

# ------------------------------------------------------------------ Hardcore du mois

func _month_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d" % [int(d.year), int(d.month)]

## Texte d'un champ localisé d'une ligne du catalogue (« label », « desc », « title ») : français, ou anglais si la langue du jeu l'est.
func _loc(row: Dictionary, field: String) -> String:
	var en := str(row.get(field + "_en", ""))
	return en if Data.lang == "en" and en != "" else str(row.get(field + "_fr", ""))

func _hardcore_section(mine: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal.content.add_child(box)
	var key := _month_key()
	_text(box, "🔥 " + L.fa(L.t("ui.challenges.hc_title"), key.substr(5) + "/" + key.substr(0, 4)), Color("ff9a52"), 19)
	_text(box, L.t("ui.challenges.hc_desc"), UiTheme.DIM, 13, true)
	if Cloud.is_signed_in():
		var play := Button.new()
		play.text = L.t("ui.challenges.hc_play")
		play.focus_mode = Control.FOCUS_NONE
		play.pressed.connect(_ask_hardcore)
		box.add_child(play)
	else:
		_text(box, L.t("ui.challenges.hc_need_account"), Color("e0b87a"), 13, true)
	var rewards := HFlowContainer.new()
	rewards.add_theme_constant_override("h_separation", 8)
	rewards.add_theme_constant_override("v_separation", 4)
	rewards.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(rewards)
	var wait := _text(box, L.t("ui.challenges.loading_board"), UiTheme.DIM, 13, true)
	_fill_hardcore(box, rewards, wait, key, mine)
	_modal.call_deferred("_fit")

func _ask_hardcore() -> void:
	Dialogs.confirm(_host, L.t("ui.challenges.hc_play"), L.t("ui.challenges.hc_confirm"), _start_hardcore, L.t("ui.challenges.hc_go"), L.t("common.annuler"))

func _start_hardcore() -> void:
	var r: Dictionary = await RankedRun.launch("hardcore", "hardcore_month")
	if not r.ok and is_instance_valid(_host):
		Form.alert(_host, str(r.get("message", "")))

func _fill_hardcore(box: VBoxContainer, rewards: HFlowContainer, wait: Label, key: String, mine: int) -> void:
	var cat: Dictionary = await RankedRun.badges()
	var owned := {}
	if Cloud.is_signed_in():
		var mb: Dictionary = await RankedRun.my_badges()
		if mb.ok:
			for b in mb.data:
				owned[str(b.badge_id)] = true
	var board: Dictionary = await RankedRun.period_board("hardcore_month", key)
	if mine != _gen or not _alive() or not is_instance_valid(box):
		return
	wait.queue_free()
	if cat.ok:
		for b in cat.data:
			var l := Label.new()
			l.text = str(b.icon)
			l.add_theme_font_size_override("font_size", 26)
			l.mouse_filter = Control.MOUSE_FILTER_STOP
			var tip := "%s\n%s" % [_loc(b, "label"), _loc(b, "desc")]
			if b.get("title_fr") != null:
				tip += "\n" + L.fa(L.t("ui.challenges.hc_title_reward"), _loc(b, "title"))
			l.tooltip_text = tip
			l.modulate = Color.WHITE if owned.has(str(b.id)) else Color(1, 1, 1, 0.3)
			rewards.add_child(l)
	if not board.ok:
		_text(box, str(board.message), Color("e08a7a"), 13)
		return
	var rows: Array = board.data if board.data is Array else []
	if rows.is_empty():
		_text(box, L.t("ui.challenges.hc_empty"), UiTheme.DIM, 14, true)
		_modal.call_deferred("_fit")
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	_cell(grid, "#", UiTheme.DIM, 12, false, 36, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(grid, L.t("ui.challenges.col_player"), UiTheme.DIM, 12, true, 0, HORIZONTAL_ALIGNMENT_LEFT)
	_cell(grid, L.t("ui.challenges.unit_niveaux"), UiTheme.DIM, 12, false, 90, HORIZONTAL_ALIGNMENT_RIGHT)
	_cell(grid, L.t("ui.challenges.col_time"), UiTheme.DIM, 12, false, 70, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in mini(rows.size(), TOP):
		var row: Dictionary = rows[i]
		var col := Color(str(row.color)) if row.get("color") != null else UiTheme.PARCH
		var title := _loc(row, "title") if row.get("title_fr") != null else ""
		var nm := str(row.get("pseudo", "?")) + (" · " + title if title != "" else "")
		_cell(grid, str(i + 1), col, 15, false, 36, HORIZONTAL_ALIGNMENT_RIGHT)
		var nc := _cell(grid, nm + " ✔", col, 15, true, 0, HORIZONTAL_ALIGNMENT_LEFT)
		nc.tooltip_text = L.fa(L.t("ui.challenges.hc_level"), int(row.get("level", 1)))
		nc.mouse_filter = Control.MOUSE_FILTER_PASS
		_cell(grid, str(int(row.get("score", 0))), col, 15, false, 90, HORIZONTAL_ALIGNMENT_RIGHT)
		_cell(grid, Challenges.format_time(int(row.get("seconds", -1))), col, 15, false, 70, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(box, L.t("ui.challenges.hc_verified_note"), UiTheme.DIM, 12, true)
	_modal.call_deferred("_fit")
