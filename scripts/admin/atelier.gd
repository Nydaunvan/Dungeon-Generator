class_name Atelier
extends RefCounted
## Éléments communs de l'atelier de création : en-tête de page, mémoire de la dernière section et des modifications récentes
## (fichier local `user://atelier.json`, hors configuration du donjon), et contrôles de cohérence du donjon.

const FILE := "user://atelier.json"
const MAX_RECENT := 6
const GOLD := Color("ffd88a")
const MUTED := Color("a8977a")
const CREAM := Color("f4e6c6")

static var _mem: Dictionary = {}
static var _loaded := false

# ------------------------------------------------------------------ mémoire locale

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_mem = d

static func _store() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_mem))

## Dernière section ouverte (pour « Reprendre là où tu t'es arrêté »).
static func last_section() -> String:
	_load()
	return str(_mem.get("last", ""))

static func visited(id: String) -> void:
	if id == "home":
		return
	_load()
	_mem["last"] = id
	_store()

## Une section vient d'être enregistrée : elle remonte en tête des modifications récentes.
static func touch(id: String) -> void:
	if id == "home":
		return
	_load()
	var list: Array = _mem.get("recent", [])
	for i in range(list.size() - 1, -1, -1):
		if str(list[i].get("section", "")) == id:
			list.remove_at(i)
	list.push_front({"section": id, "ts": Time.get_unix_time_from_system()})
	while list.size() > MAX_RECENT:
		list.pop_back()
	_mem["recent"] = list
	_store()

static func recent() -> Array:
	_load()
	return _mem.get("recent", [])

## « il y a 2 min », « hier »…
static func ago(ts: float) -> String:
	var d := maxf(0.0, Time.get_unix_time_from_system() - ts)
	if d < 60.0:
		return L.t("ui.atelier.ago_now")
	if d < 3600.0:
		return L.fa(L.t("ui.atelier.ago_min"), int(d / 60.0))
	if d < 86400.0:
		return L.fa(L.t("ui.atelier.ago_h"), int(d / 3600.0))
	if d < 172800.0:
		return L.t("ui.atelier.ago_yesterday")
	return L.fa(L.t("ui.atelier.ago_d"), int(d / 86400.0))

# ------------------------------------------------------------------ en-tête de page

## Nom de la rubrique (« CRÉER », « RÈGLES DU JEU », « PROJET ») qui contient la section.
static func kicker_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return L.t(str(g[0])) if str(g[0]) != "" else ""
	return ""

static func title_of(id: String) -> String:
	for g in AtelierSide.GROUPS:
		for it in g[1]:
			if str(it[0]) == id:
				return L.t(str(it[1]))
	return ""

## Titre de page : petit libellé de rubrique en capitales puis grand titre. Renvoie la rangée (pour y ajouter un contrôle à droite).
static func page_header(host: Control, id: String, title: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	host.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var k := Label.new()
	k.text = kicker_of(id)
	k.add_theme_font_override("font", GameWidgets.spaced(UiTheme.F_TITLE, 2))
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Color("9a8863"))
	col.add_child(k)
	var t := Label.new()
	t.text = title if title != "" else title_of(id)
	t.add_theme_font_override("font", UiTheme.font(UiTheme.F_TITLE_BOLD))
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", CREAM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	return row

# ------------------------------------------------------------------ contrôles du donjon

## Contrôles de cohérence du donjon en cours d'édition : [{"state": "ok"|"warn"|"bad", "title", "text"}, …].
static func checks() -> Array:
	var cfg: Dictionary = Data.admin_config()
	var out: Array = []
	var levels: Array = cfg.get("levels", [])
	var no_start: Array = []
	var no_exit: Array = []
	var no_rooms: Array = []
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var rows: Array = lv.get("mapRows", [])
		var sx := int(lv.get("startX", -1))
		var sy := int(lv.get("startY", -1))
		var ok_start := sy >= 0 and sy < rows.size() and sx >= 0 and sx < str(rows[sy]).length() and str(rows[sy])[sx] != "#"
		if not ok_start:
			no_start.append(i + 1)
		if (lv.get("stairs", []) as Array).is_empty() and not _has_stairs_cell(rows):
			no_exit.append(i + 1)
	for n in no_exit:
		out.append({"state": "bad", "title": L.fa(L.t("ui.atelier.chk_no_exit"), n), "text": L.t("ui.atelier.chk_no_exit_d")})
	for n in no_start:
		out.append({"state": "bad", "title": L.fa(L.t("ui.atelier.chk_no_start"), n), "text": L.t("ui.atelier.chk_no_start_d")})
	for n in no_rooms:
		out.append({"state": "warn", "title": L.fa(L.t("ui.atelier.chk_no_room"), n), "text": L.t("ui.atelier.chk_no_room_d")})
	var party: Array = cfg.get("party", [])
	if party.is_empty():
		out.append({"state": "bad", "title": L.t("ui.atelier.chk_no_party"), "text": L.t("ui.atelier.chk_no_party_d")})
	else:
		out.append({"state": "ok", "title": L.t("ui.atelier.chk_party_ok"), "text": L.fa(L.t("ui.atelier.chk_party_ok_d"), party.size())})
	if no_start.is_empty() and not levels.is_empty():
		out.append({"state": "ok", "title": L.t("ui.atelier.chk_start_ok"), "text": L.fa(L.t("ui.atelier.chk_start_ok_d"), [levels.size(), levels.size()])})
	if levels.is_empty():
		out.append({"state": "bad", "title": L.t("ui.atelier.chk_no_level"), "text": L.t("ui.atelier.chk_no_level_d")})
	return out

static func _has_stairs_cell(rows: Array) -> bool:
	for r in rows:
		if "S" in str(r):
			return true
	return false
