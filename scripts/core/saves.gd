class_name Saves
extends RefCounted
## Sauvegardes : 10 emplacements (user://saves/slot_N.json), export/import de fichier, conversion des sauvegardes du jeu HTML.
##
## Formats : un export Godot est un fichier {"format": "godot-1", "config", "save", "dungeonOrigin"} où « save » est l'état Godot
## (clés en snake_case : level_index, level_states, full_log…). Un export du jeu HTML est {config, save: STATE} (clés camelCase) :
## il s'importe sans perte (convertie par `from_js_state`) ; l'inverse (fichier Godot dans le jeu HTML) n'est pas garanti.

const SLOTS := 10
const DIR := "user://saves"
const BUILD_ID := "godot-1"
const OPENING_LOG := "Le groupe s'enfonce dans les ténèbres, seul le grincement d'une porte se refermant résonne encore."

## Icônes par défaut des anciennes versions : remplacées par celle de la classe (backfillClassIcons).
const OLD_CLASS_ICON_DEFAULTS := {
	"class_warrior": "🛡️", "class_archer": "🏹", "class_rogue": "🗡️", "class_mage": "🔮", "class_priest": "🙏",
	"class_berserker": "😤", "class_paladin": "⚜️", "class_magearcher": "🏹", "class_bladedancer": "⚔️",
	"class_thief": "🗝️", "class_assassin": "🥷", "class_elementalist": "🌪️", "class_warlock": "😈",
	"class_cleric": "✝️", "class_crusader": "🛡️"}

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

## Le texte est-il un JSON lisible (et pas « null », que `JSON.parse` accepte mais dont la lecture des champs échoue) ?
static func is_valid_json(text: String) -> bool:
	var jp := JSON.new()
	return jp.parse(text) == OK and jp.data != null

static func parse(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return normalize(parsed)
	return {}

## `JSON.stringify` à la manière de JavaScript : un nombre entier s'écrit sans « .0 » ; `indent` vide = compact.
static func stringify(v, indent: String = "") -> String:
	var sb := PackedStringArray()
	_write(sb, v, indent, "")
	return "".join(sb)

static func _write(sb: PackedStringArray, v, indent: String, cur: String) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				sb.append("{}")
				return
			var inner := cur + indent
			sb.append("{")
			var first := true
			for k in d:
				if not first:
					sb.append(",")
				first = false
				if indent != "":
					sb.append("\n" + inner)
				sb.append(JSON.stringify(str(k)))
				sb.append(": " if indent != "" else ":")
				_write(sb, d[k], indent, inner)
			if indent != "":
				sb.append("\n" + cur)
			sb.append("}")
		TYPE_ARRAY:
			var a: Array = v
			if a.is_empty():
				sb.append("[]")
				return
			var inner2 := cur + indent
			sb.append("[")
			for i in a.size():
				if i > 0:
					sb.append(",")
				if indent != "":
					sb.append("\n" + inner2)
				_write(sb, a[i], indent, inner2)
			if indent != "":
				sb.append("\n" + cur)
			sb.append("]")
		TYPE_FLOAT:
			var f: float = v
			if is_nan(f) or is_inf(f):
				sb.append("null")
			elif is_equal_approx(f, round(f)) and absf(f) < 9.0e15:
				sb.append(str(int(f)))
			else:
				sb.append(str(f))
		TYPE_INT:
			sb.append(str(v))
		TYPE_BOOL:
			sb.append("true" if v else "false")
		TYPE_NIL:
			sb.append("null")
		TYPE_STRING, TYPE_STRING_NAME:
			sb.append(JSON.stringify(str(v)))
		_:
			sb.append(JSON.stringify(v))

# ------------------------------------------------------------------ emplacements

static func write_slot(i: int, cfg: Dictionary, save: Dictionary, origin: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(stringify({"format": "godot-1", "config": cfg, "save": save, "savedAt": Time.get_unix_time_from_system() * 1000.0,
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
	var title := str(d.get("config", {}).get("title", "")) if (d.get("config") is Dictionary) else ""
	return {"title": title if title != "" else "(Sans titre)", "savedAt": float(d.get("savedAt", 0)),
		"party": ", ".join(party) if not party.is_empty() else "Groupe inconnu", "origin": str(d.get("dungeonOrigin", "random"))}

## Date locale « JJ/MM/AAAA HH:MM:SS » (comme `toLocaleString()` en français) d'un horodatage en millisecondes.
static func local_date(ms: float) -> String:
	if ms <= 0.0:
		return ""
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var dt := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0) + bias * 60)
	return "%02d/%02d/%04d %02d:%02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute, dt.second]

static func origin_label(o: String) -> String:
	return "🏰 Donjon d'Origine" if o == "original" else ("🛠️ Donjon personnalisé" if o == "custom" else "🎲 Donjon aléatoire")

# ------------------------------------------------------------------ fichier complet

static func export_text(cfg: Dictionary, save: Dictionary, origin: String) -> String:
	return stringify({"format": "godot-1", "config": cfg, "save": save, "dungeonOrigin": origin}, "  ")

## Analyse un fichier/texte importé (`applyImportedData`). Renvoie {"config": Dictionary|{}, "save": Dictionary|{}, "origin": String,
## "cfg_extra": Dictionary} ou {} si rien n'est reconnu. Accepte : fichier Godot, configuration seule, sauvegarde du jeu HTML
## ({config, save}, STATE nu, ou configuration nue).
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
	var extra := {}
	if raw is Dictionary:
		if (raw as Dictionary).has("level_index"):
			save = raw
		else:
			save = from_js_state(raw, cfg)
			extra = js_cfg_extra(raw)
			for k in extra:
				if not cfg.is_empty():
					cfg[k] = extra[k]
	if cfg.is_empty() and save.is_empty():
		return {}
	return {"config": cfg, "save": save, "origin": str(d.get("dungeonOrigin", "custom")), "cfg_extra": extra if cfg.is_empty() else {}}

## Texte d'un journal du jeu HTML sans sa mise en forme (balises <span>…).
static func strip_tags(s: String) -> String:
	var re := RegEx.create_from_string("<[^>]+>")
	return re.sub(s, "", true).replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")

## Champs de configuration que l'état du jeu HTML porte (STATE.runModifierIds, originalDungeonDims, baseDifficulty) et que
## Godot lit dans la configuration (cfg.runModifierIds, cfg.genDims, cfg.genDifficulty — voir rules/village.gd).
static func js_cfg_extra(js: Dictionary) -> Dictionary:
	var out := {}
	if js.get("runModifierIds") is Array:
		out["runModifierIds"] = (js.runModifierIds as Array).duplicate()
	if js.get("originalDungeonDims") is Dictionary:
		out["genDims"] = (js.originalDungeonDims as Dictionary).duplicate()
	if js.get("baseDifficulty") != null and str(js.baseDifficulty) != "":
		out["genDifficulty"] = str(js.baseDifficulty)
	return out

## Convertit l'état du jeu HTML (STATE) en sauvegarde Godot.
static func from_js_state(js: Dictionary, cfg: Dictionary) -> Dictionary:
	var out := {"level_index": int(js.get("levelIndex", 0)), "px": int(js.get("x", 1)), "py": int(js.get("y", 1)), "pdir": int(js.get("dir", 0)),
		"party": js.get("party", []), "gold": int(js.get("gold", 0)), "inventory": js.get("inventory", []),
		"active_char_id": str(js.get("activeCharId", "")), "last_attacker_id": "", "stats": js.get("stats", {}), "bestiary": js.get("bestiary", {}),
		"game_over": bool(js.get("gameOver", false)), "won": bool(js.get("won", false))}
	var log_lines: Array = []
	for l in js.get("log", []):
		log_lines.append(strip_tags(str(l)))
	out["log_lines"] = log_lines
	out["run_number"] = maxi(1, int(js.get("runNumber", 1)))
	out["run_mods_chosen"] = js.get("runModifierIds") is Array
	out["in_village"] = bool(js.get("inVillage", false))
	if js.get("villagePrevLevels") is Array:
		out["village_prev"] = {"levels": js.villagePrevLevels, "level_index": int(js.get("villagePrevLevelIndex", 0)), "x": int(js.get("villagePrevX", 1)),
			"y": int(js.get("villagePrevY", 1)), "dir": int(js.get("villagePrevDir", 0))}
	# journal complet (fullLog) ; à défaut, reconstruit depuis le journal court comme `migrateStateLevelStates`
	var full: Array = []
	if js.get("fullLog") is Array:
		for e in js.fullLog:
			if e is Dictionary:
				var ent := {"type": str(e.get("type", "entry")), "text": strip_tags(str(e.get("text", "")))}
				if ent.type == "entry":
					ent["playerHit"] = bool(e.get("playerHit", false))
				full.append(ent)
	else:
		full.append({"type": "divider", "text": "Expédition n°%d — %s" % [int(out.run_number), str(cfg.get("title", ""))]})
		for l in log_lines:
			full.append({"type": "entry", "text": l, "playerHit": false})
	out["full_log"] = full
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
			"items_state": jls.get("items", {}), "opened_doors": {}, "door_unlocked": {},
			"transitionRegenDone": bool(jls.get("transitionRegenDone", false)), "stairsPromptShown": bool(js.get("stairsPromptShown", {}).get(lid, false)) if js.get("stairsPromptShown") is Dictionary else false}
		for id in ls.items_state:
			if ls.items_state[id].get("taken", false):
				ls.taken_items[id] = true
		for id in jls.get("doors", {}):
			if not jls.doors[id].get("locked", true):
				ls.door_unlocked[id] = true
				ls.opened_doors[id] = true
		if jls.get("merchant") is Dictionary:
			var m: Dictionary = jls.merchant
			ls["merchant"] = {"x": int(m.get("x", 0)), "y": int(m.get("y", 0)), "discovered": bool(m.get("discovered", false)), "offers": m.get("offers")}
		for kind in ["seen", "visited"]:
			var d := {}
			for c in jls.get(kind, []):
				d[str(c)] = true
			ls[kind] = d
		states[lid] = ls
	out["level_states"] = states
	return out

## Migrations d'une sauvegarde chargée (`migrateStateLevelStates`, `backfillMissingStartSpells`, `backfillClassIcons`) :
## compléments par défaut pour les anciennes sauvegardes et celles du jeu HTML. Sans effet sur une sauvegarde déjà complète.
static func migrate_save(save: Dictionary, cfg: Dictionary) -> void:
	if not (save.get("inventory") is Array):
		save["inventory"] = []
	if not save.has("gold"):
		save["gold"] = 0
	var party: Array = save.get("party", [])
	var sta: Dictionary = cfg.get("staminaSettings", {}) if (cfg.get("staminaSettings") is Dictionary) else {}
	for c in party:
		if c.get("inventory") is Array:
			(save.inventory as Array).append_array(c.inventory)
			c.erase("inventory")
		if not c.has("stamina"):
			c["stamina"] = 0
		if not c.has("maxStamina"):
			c["maxStamina"] = int(sta.get("max", 100)) if sta.get("max") != null else 100
		if not (c.get("talents") is Array):
			c["talents"] = []
	if not (save.get("stats") is Dictionary) or (save.stats as Dictionary).is_empty():
		save["stats"] = {"monstersKilled": 0, "bossesKilled": 0, "trapsTriggered": 0, "goldEarnedTotal": int(save.get("gold", 0)), "xpEarnedTotal": 0,
			"itemsFound": 0, "itemsBought": 0, "itemsSold": 0, "potionsUsed": 0, "spellsCast": 0,
			"dungeonsCompleted": maxi(1, int(save.get("run_number", 1))) - 1, "doorsUnlocked": 0, "fountainsUsed": 0}
	if not (save.stats.get("perChar") is Dictionary):
		save.stats["perChar"] = {}
	if not (save.get("full_log") is Array):
		var run := maxi(1, int(save.get("run_number", 1)))
		var fl: Array = [{"type": "divider", "text": "Expédition n°%d — %s" % [run, str(cfg.get("title", ""))]}]
		for l in save.get("log_lines", []):
			fl.append({"type": "entry", "text": str(l), "playerHit": false})
		save["full_log"] = fl
	var lstates: Dictionary = save.get("level_states", {})
	for lid in lstates:
		var lvl := _level(cfg, str(lid))
		if lvl.is_empty():
			continue
		var ls: Dictionary = lstates[lid]
		if not ls.has("last_engaged_id") or ls.last_engaged_id == null:
			ls["last_engaged_id"] = ""
		var mons: Dictionary = ls.get("monsters", {})
		for m in lvl.get("monsters", []):
			var st = mons.get(str(m.id))
			if st is Dictionary:
				if not st.has("x"):
					st["x"] = int(m.get("x", 0))
					st["y"] = int(m.get("y", 0))
				if not (st.get("contrib") is Dictionary):
					st["contrib"] = {}
	# sorts de départ et icônes de classe
	for c in party:
		var cls := Characters.class_def(cfg, str(c.get("classId", "")))
		if cls.is_empty():
			continue
		if (c.get("spellsKnown", []) as Array).is_empty():
			var base := _base_class(cfg, cls)
			var prog: Array = base.get("spellProgression", []) if not base.is_empty() else cls.get("spellProgression", [])
			for e in prog:
				if int(e.get("level", 0)) == 1:
					c["spellsKnown"] = [e.spellId]
					break
		var old: String = OLD_CLASS_ICON_DEFAULTS.get(str(c.get("classId", "")), "")
		if old != "" and str(c.get("icon", "")) == old:
			c["icon"] = cls.get("icon", old)

static func _level(cfg: Dictionary, id: String) -> Dictionary:
	for l in cfg.get("levels", []):
		if str(l.get("id", "")) == id:
			return l
	return {}

## `baseClassOf` : classe de base d'une classe évoluée (par son nom d'« evolvesFrom »).
static func _base_class(cfg: Dictionary, cls: Dictionary) -> Dictionary:
	var from := str(cls.get("evolvesFrom", ""))
	if from == "" or not ["Guerrier", "Archer", "Roublard", "Mage", "Prêtre", "Barde"].has(from):
		return {}
	for c in cfg.get("classes", []):
		if str(c.get("name", "")) == from:
			return c
	return {}
