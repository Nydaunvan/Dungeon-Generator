class_name Saves
extends RefCounted
## Sauvegardes : 10 emplacements (user://saves/slot_N.json), export/import de fichier, conversion des sauvegardes du jeu HTML.

const SLOTS := 10
const DIR := "user://saves"
const BUILD_ID := "godot-1"

static func _path(i: int) -> String:
	return "%s/slot_%d.json" % [DIR, i]

## Les nombres lus dans un JSON sont des flottants : on rend leur type entier quand c'est le cas.
static func normalize(v):
	if v is Dictionary:
		var d: Dictionary = v
		for k in d.keys():
			d[k] = normalize(d[k])
		return d
	if v is Array:
		var a: Array = v
		for i in a.size():
			a[i] = normalize(a[i])
		return a
	if v is float and is_equal_approx(v, round(v)) and absf(v) < 9.0e15:
		return int(v)
	return v

static func parse(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return normalize(parsed)
	return {}

# ------------------------------------------------------------------ emplacements

static func write_slot(i: int, cfg: Dictionary, save: Dictionary, origin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"format": "godot-1", "config": cfg, "save": save, "savedAt": Time.get_unix_time_from_system() * 1000.0,
		"buildId": BUILD_ID, "dungeonOrigin": origin}))
	return true

static func read_slot(i: int) -> Dictionary:
	if not FileAccess.file_exists(_path(i)):
		return {}
	return parse(FileAccess.get_file_as_string(_path(i)))

static func delete_slot(i: int) -> void:
	if FileAccess.file_exists(_path(i)):
		DirAccess.remove_absolute(_path(i))

static func has_any() -> bool:
	for i in SLOTS:
		if FileAccess.file_exists(_path(i)):
			return true
	return false

## Résumé d'un emplacement pour la liste, ou {} s'il est vide.
static func summary(i: int) -> Dictionary:
	var d := read_slot(i)
	if d.is_empty():
		return {}
	var party: Array = []
	for c in d.get("save", {}).get("party", []):
		party.append("%s (Nv.%d)" % [c.get("name", "?"), int(c.get("level", 1))])
	return {"title": str(d.get("config", {}).get("title", "(Sans titre)")), "savedAt": float(d.get("savedAt", 0)),
		"party": ", ".join(party), "origin": str(d.get("dungeonOrigin", "random"))}

static func origin_label(o: String) -> String:
	return "🏰 Donjon d'Origine" if o == "original" else ("🛠️ Donjon personnalisé" if o == "custom" else "🎲 Donjon aléatoire")

# ------------------------------------------------------------------ fichier complet

static func export_text(cfg: Dictionary, save: Dictionary, origin: String) -> String:
	return JSON.stringify({"format": "godot-1", "config": cfg, "save": save, "dungeonOrigin": origin}, "  ")

## Analyse un fichier/texte importé. Renvoie {"config": Dictionary|{}, "save": Dictionary|{}, "origin": String} ou {} si inconnu.
## Accepte : fichier Godot, configuration seule, sauvegarde du jeu HTML (eob_save_v4, avec ou sans configuration).
static func parse_import(text: String) -> Dictionary:
	var d := parse(text)
	if d.is_empty():
		return {}
	var cfg: Dictionary = {}
	var save: Dictionary = {}
	if d.get("config") is Dictionary:
		cfg = d.config
	elif d.has("levels") and d.has("title"):
		cfg = d
	var raw = d.get("save")
	if not (raw is Dictionary) and d.has("levelIndex") and d.has("party"):
		raw = d
	if raw is Dictionary:
		save = raw if (raw as Dictionary).has("level_index") else from_js_state(raw, cfg)
	if cfg.is_empty() and save.is_empty():
		return {}
	return {"config": cfg, "save": save, "origin": str(d.get("dungeonOrigin", "custom"))}

## Convertit l'état du jeu HTML (STATE) en sauvegarde Godot.
static func from_js_state(js: Dictionary, cfg: Dictionary) -> Dictionary:
	var out := {"level_index": int(js.get("levelIndex", 0)), "px": int(js.get("x", 1)), "py": int(js.get("y", 1)), "pdir": int(js.get("dir", 0)),
		"party": js.get("party", []), "gold": int(js.get("gold", 0)), "inventory": js.get("inventory", []),
		"active_char_id": str(js.get("activeCharId", "")), "last_attacker_id": "", "stats": js.get("stats", {}), "bestiary": js.get("bestiary", {}),
		"game_over": bool(js.get("gameOver", false)), "won": bool(js.get("won", false)), "log_lines": js.get("log", [])}
	for c in out.party:
		if not c.has("statusEffects"):
			c["statusEffects"] = []
		if not c.has("spellCooldowns"):
			c["spellCooldowns"] = {}
	var states := {}
	var js_states: Dictionary = js.get("levelStates", {})
	for lid in js_states:
		var jls: Dictionary = js_states[lid]
		var ls := {"monsters": jls.get("monsters", {}), "taken_items": {}, "last_engaged_id": str(jls.get("lastEngagedId", "") if jls.get("lastEngagedId") != null else ""),
			"items_state": jls.get("items", {}), "opened_doors": {}, "door_unlocked": {}}
		for id in ls.items_state:
			if ls.items_state[id].get("taken", false):
				ls.taken_items[id] = true
		for id in jls.get("doors", {}):
			if not jls.doors[id].get("locked", true):
				ls.door_unlocked[id] = true
				ls.opened_doors[id] = true
		if jls.get("merchant") is Dictionary:
			var m: Dictionary = jls.merchant
			ls["merchant"] = {"x": int(m.get("x", 0)), "y": int(m.get("y", 0)), "discovered": bool(m.get("discovered", false)), "offers": null}
		for kind in ["seen", "visited"]:
			var d := {}
			for c in jls.get(kind, []):
				d[str(c)] = true
			ls[kind] = d
		states[lid] = ls
	out["level_states"] = states
	return out
