extends Node
## Chargement des données du jeu (extraites du build HTML Donjon3D).
## Accessible partout via l'autoload `Data`.

var config: Dictionary = {}
var class_talents: Dictionary = {}
var constants: Dictionary = {}
## Configuration de la partie en cours (donjon d'origine, aléatoire, personnalisé…). Vide = donjon d'origine.
var play_config: Dictionary = {}
## Provenance de la partie : "original", "random", "custom". « random » vaut `cameFromRandomGen` de l'original.
var play_origin: String = "original"

## Configuration d'origine (jamais modifiée) : sert au Donjon d'Origine et à la réinitialisation.
var original_config: Dictionary = {}
## Une session d'administration est déverrouillée (mot de passe saisi) : `adminUnlocked` de l'original.
var admin_unlocked: bool = false
## Vrai après « ▶ Jouer ce donjon » (ou le chargement d'une partie personnalisée) : `ownDungeonLaunched` de l'original.
var own_dungeon_launched: bool = false

const USER_CONFIG := "user://config.json"
const USER_PREFS := "user://prefs.cfg"

## Langue de l'interface (« fr » / « en »), mémorisée sur l'appareil.
var lang: String = "fr"

func set_lang(l: String) -> void:
	lang = l
	_apply_locale()
	var cf := ConfigFile.new()
	cf.load(USER_PREFS)
	cf.set_value("ui", "lang", l)
	cf.save(USER_PREFS)
	lang_changed.emit(l)

signal lang_changed(l: String)

func _apply_locale() -> void:
	if TranslationServer.get_translation_object("fr") == null or not (TranslationServer.get_translation_object("fr") is LangTranslation):
		var fr_content: Dictionary = {}
		var ff := FileAccess.open("res://data/lang/fr.json", FileAccess.READ)
		if ff != null:
			var fd = JSON.parse_string(ff.get_as_text())
			if fd is Dictionary:
				fr_content = fd.get("content", {})
		for code in ["fr", "en"]:
			var t := LangTranslation.new()
			t.load_language(code, fr_content)
			TranslationServer.add_translation(t)
	TranslationServer.set_locale("en" if lang == "en" else "fr")

func _ready() -> void:
	add_child(FloatingTip.new())
	var cf := ConfigFile.new()
	if cf.load(USER_PREFS) == OK:
		lang = str(cf.get_value("ui", "lang", "fr"))
	_apply_locale()
	get_window().size_changed.connect(_update_scale)
	_update_scale()
	original_config = _load_json("res://data/default_config.json")
	class_talents = _load_json("res://data/class_talents.json")
	constants = _load_json("res://data/game_constants.json")
	config = _load_user_config()
	if config.is_empty():
		config = original_config.duplicate(true)
	else:
		_upgrade_user_config()
	ensure_defaults(config)

## La configuration enregistrée sur l'appareil reçoit les nouveautés du jeu (icônes, objets, sorts, réglages) : copie de secours
## (config.v1.bak, une seule fois) puis réécriture.
func _upgrade_user_config() -> void:
	if int(config.get("configSchema", 1)) >= SaveMigrations.SCHEMA:
		return
	var bak := "user://config.v%d.bak" % int(config.get("configSchema", 1))
	if not FileAccess.file_exists(bak) and FileAccess.file_exists(USER_CONFIG):
		var bf := FileAccess.open(bak, FileAccess.WRITE)
		if bf != null:
			bf.store_string(FileAccess.get_file_as_string(USER_CONFIG))
	SaveMigrations.migrate_config(config, original_config)
	var f := FileAccess.open(USER_CONFIG, FileAccess.WRITE)
	if f != null:
		f.store_string(Saves.stringify(config))

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Fichier introuvable : " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func class_by_id(id: String) -> Dictionary:
	for c in config.get("classes", []):
		if c.get("id") == id:
			return c
	return {}

func spell_by_id(id: String) -> Dictionary:
	for s in config.get("spells", []):
		if s.get("id") == id:
			return s
	return {}

## Configuration éditée par l'administration. Comme le `CONFIG` unique de l'original : si une partie est suspendue
## (admin ouvert depuis le jeu), c'est la configuration de CETTE partie (même Dictionary que `gs.cfg`), sinon la configuration
## par défaut de l'appareil. Tous les onglets admin doivent passer par ici, jamais par `Data.config` directement.
func admin_config() -> Dictionary:
	if not resume_game.is_empty() and (resume_game.get("config") is Dictionary):
		return resume_game.config
	return config

## Remplace toute la configuration éditée (import, code de donjon, réinitialisation : `CONFIG = …` de l'original).
func set_admin_config(cfg: Dictionary) -> void:
	if not resume_game.is_empty() and (resume_game.get("config") is Dictionary):
		resume_game["config"] = cfg
	else:
		config = cfg

## Configuration utilisée par le jeu.
func active() -> Dictionary:
	return play_config if not play_config.is_empty() else config

# ------------------------------------------------------------------ lancement d'une partie

## Que devient la session d'administration au lancement ? (`adminUnlocked` de l'original)
const ADMIN_AUTO := -1      # verrouillée, sauf pour une partie personnalisée (inchangée)
const ADMIN_LOCK := 0
const ADMIN_UNLOCK := 1
const ADMIN_KEEP := 2

## Texte à ajouter au journal une fois la partie chargée (« 📂 Partie chargée depuis l'emplacement 3. »…), vide = rien.
var pending_log: String = ""
## Champs transitoires de la partie suspendue (jauges de combat…) à rétablir à la reprise depuis l'administration.
var pending_transient: Dictionary = {}

## Lance une partie avec la configuration donnée (copie profonde) puis ouvre la scène de jeu.
func launch(cfg: Dictionary, origin: String, admin_mode: int = ADMIN_AUTO) -> void:
	match admin_mode:
		ADMIN_AUTO:
			if origin != "custom":
				admin_unlocked = false
		ADMIN_LOCK:
			admin_unlocked = false
		ADMIN_UNLOCK:
			admin_unlocked = true
	resume_game = {}
	pending_save = {}
	pending_transient = {}
	pending_log = ""
	play_config = cfg.duplicate(true)
	play_origin = origin
	Loader.go("res://scenes/main.tscn", "game")

## Partie à restaurer au prochain lancement de la scène de jeu (vide = nouvelle partie).
var pending_save: Dictionary = {}

## Reprend une sauvegarde (emplacement, fichier importé) : {"config", "save", "origin", "log"?, "cfg_extra"?}.
## Sans configuration, garde celle de l'administration. Comme `loadFromSlot` : le donjon « custom » déverrouille l'admin.
func launch_save(data: Dictionary, admin_mode: int = ADMIN_AUTO) -> void:
	var cfg: Dictionary = data.get("config", {})
	if cfg.is_empty() or not cfg.has("levels"):
		cfg = active().duplicate(true)
	else:
		cfg = cfg.duplicate(true)
	repair_evolved_classes(cfg)
	var extra: Dictionary = data.get("cfg_extra", {})
	for k in extra:
		cfg[k] = extra[k]
	var origin := str(data.get("origin", "custom"))
	if admin_mode == ADMIN_AUTO:
		admin_mode = ADMIN_UNLOCK if origin == "custom" else ADMIN_LOCK
	if origin == "custom":
		config = cfg.duplicate(true)     # CONFIG = data.config : l'administration retrouve la configuration chargée
		own_dungeon_launched = true      # (écart voulu : sinon « Reprendre » disparaît de la bannière d'une partie chargée)
	var sv: Dictionary = (data.save as Dictionary).duplicate(true)
	var log_text := str(data.get("log", ""))
	launch(cfg, origin, admin_mode)
	Loader.set_kind("save")
	pending_save = sv
	pending_log = log_text

## Importe un fichier complet (voir Saves.parse_import) : une configuration déverrouille l'admin (applyImportedData).
## Renvoie false si rien d'exploitable.
func launch_import(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var has_cfg: bool = (data.get("config") is Dictionary) and not (data.config as Dictionary).is_empty()
	var d: Dictionary = data.duplicate(true)
	if has_cfg:
		ensure_defaults(d.config)
	d["log"] = L.t("core.data.sauvegarde_importee_depuis_un")
	if (d.get("save") is Dictionary) and not (d.save as Dictionary).is_empty():
		launch_save(d, ADMIN_UNLOCK if has_cfg else ADMIN_AUTO)
		return true
	# configuration seule : nouvelle partie avec ce donjon (équivalent de `STATE = initialState()`)
	config = d.config.duplicate(true)
	save_config()
	own_dungeon_launched = false
	launch(config, str(d.get("origin", "custom")), ADMIN_UNLOCK)
	return true

func launch_original() -> void:
	launch(original_config, "original", ADMIN_LOCK)

## Reprise de la partie suspendue (`resumeCurrentGame` de l'original) : enregistre la configuration, répercute les définitions
## des personnages et l'état des niveaux sur la partie, puis rouvre la scène de jeu — sans écrire « Partie chargée ».
func resume_from_admin() -> void:
	_resume(true)

## Changement de langue en pleine partie : la partie est suspendue puis rouverte telle quelle, textes dans la nouvelle langue.
func reload_game(snap: Dictionary) -> void:
	resume_game = snap
	_resume(false)

func _resume(persist: bool) -> void:
	var g := resume_game
	if g.is_empty():
		return
	if persist:
		save_config()
	var cfg: Dictionary = g.config
	var gs := GameState.from_save(cfg, Saves.normalize(g.save))
	gs.sync_party_definitions()
	gs.sync_all_level_states()
	var sv := gs.to_save()
	var origin := str(g.get("origin", play_origin))
	var tr: Dictionary = g.get("transient", {})
	launch(cfg, origin, ADMIN_KEEP)
	pending_save = sv
	pending_transient = tr
	pending_log = ""

# ------------------------------------------------------------------ API pour l'onglet Niveaux (partie suspendue)

const MSG_NO_RUN := "common.aucune_partie_en_cours_lancez"
const MSG_LEVEL_NOT_IN_RUN := "core.data.ce_niveau_ne_fait_pas"

## Une partie suspendue existe (admin ouvert depuis le jeu).
func admin_has_run() -> bool:
	return not resume_game.is_empty() and (resume_game.get("save") is Dictionary) and not (resume_game.save as Dictionary).is_empty()

## Position du groupe dans la partie suspendue : {} sans partie, sinon {"level_id", "x", "y"}.
func admin_party_marker() -> Dictionary:
	if not admin_has_run():
		return {}
	var levels: Array = resume_game.config.get("levels", [])
	var sv: Dictionary = resume_game.save
	var idx := int(sv.get("level_index", 0))
	if idx < 0 or idx >= levels.size():
		return {}
	return {"level_id": str(levels[idx].id), "x": int(sv.get("px", 0)), "y": int(sv.get("py", 0))}

## Téléporte le groupe sur (x, y) du niveau donné. Renvoie "" si tout va bien, sinon le message d'erreur de l'original.
func admin_teleport_group(level_id: String, x: int, y: int) -> String:
	if not admin_has_run():
		return MSG_NO_RUN
	var levels: Array = resume_game.config.get("levels", [])
	var idx := -1
	for i in levels.size():
		if str(levels[i].id) == level_id:
			idx = i
	if idx < 0:
		return MSG_LEVEL_NOT_IN_RUN
	var gs := GameState.from_save(resume_game.config, Saves.normalize(resume_game.save))
	gs.level_index = idx
	gs.px = x
	gs.py = y
	var ls := gs.level_state(levels[idx])
	var k := "%d,%d" % [x, y]
	ls.get_or_add("visited", {})[k] = true
	ls.get_or_add("seen", {})[k] = true
	resume_game["save"] = gs.to_save()
	return ""

## Téléporte le groupe au village (`adminTeleportToVillage`) puis reprend la partie. Renvoie "" ou le message d'erreur.
func admin_teleport_village() -> String:
	if not admin_has_run():
		return MSG_NO_RUN
	var cfg: Dictionary = resume_game.config
	var gs := GameState.from_save(cfg, Saves.normalize(resume_game.save))
	gs.enter_village()
	resume_game["save"] = gs.to_save()
	resume_game["origin"] = "random"      # cameFromRandomGen = true : le village prend son sens dans le cycle des donjons
	_resume(false)
	return ""

# ------------------------------------------------------------------ configuration modifiable (administration)

func _load_user_config() -> Dictionary:
	if not FileAccess.file_exists(USER_CONFIG):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_CONFIG))
	if parsed is Dictionary and (parsed as Dictionary).has("levels") and (parsed as Dictionary).has("classes"):
		return parsed
	return {}

## Enregistre la configuration courante comme configuration par défaut de l'appareil (`saveConfigNow`).
func save_config() -> bool:
	var cfg := admin_config()
	var f := FileAccess.open(USER_CONFIG, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(Saves.stringify(cfg))
	if not is_same(cfg, config):
		config = cfg.duplicate(true)     # CONFIG est unique dans l'original : la config par défaut devient celle-ci
	return true

## « Réinitialiser aux valeurs par défaut » : configuration d'origine, enregistrée.
func reset_config() -> void:
	var fresh := original_config.duplicate(true)
	ensure_defaults(fresh)
	set_admin_config(fresh)
	save_config()

## Texte JSON de la configuration éditée (indentation de 2 espaces, comme `JSON.stringify(CONFIG, null, 2)`).
func export_json() -> String:
	return Saves.stringify(admin_config(), "  ")

## Nom de fichier d'export : titre dont toute suite de caractères hors [a-z0-9] devient « _ ».
static func export_name(title: String, suffix: String = "") -> String:
	var t := title if title != "" else "donjon"
	var re := RegEx.create_from_string("[^a-zA-Z0-9]+")
	return re.sub(t, "_", true) + suffix + ".json"

## Code de partage : « DGZ1 » + base64 du JSON compressé en gzip (même format que la version HTML).
func encode_code(cfg: Dictionary) -> String:
	var raw := Saves.stringify(cfg).to_utf8_buffer()
	return "DGZ1" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))

## Décode un code de partage. Renvoie {} si le code est invalide.
func decode_code(code: String) -> Dictionary:
	var ws := RegEx.create_from_string("\\s+")
	code = ws.sub(code.strip_edges(), "", true)
	var json := ""
	if code.begins_with("DGZ1"):
		var packed := Marshalls.base64_to_raw(code.substr(4))
		if packed.is_empty():
			return {}
		var raw := packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		json = raw.get_string_from_utf8()
	elif code.begins_with("DRAW1"):
		json = Marshalls.base64_to_raw(code.substr(5)).get_string_from_utf8()
	else:
		return {}
	var jp := JSON.new()
	if jp.parse(json) != OK:
		return {}
	return jp.data if jp.data is Dictionary else {}

# ------------------------------------------------------------------ complétion d'une configuration (loadConfig)

const BASE_EVOLUTIONS := {"Guerrier": ["Berserker", "Paladin"], "Archer": ["Mage-Archer", "Danselame"], "Roublard": ["Voleur", "Assassin"],
	"Mage": ["Élémentaliste", "Sorcier"], "Prêtre": ["Clerc", "Croisé"]}

## Complète les champs absents d'une configuration (anciennes sauvegardes, fichiers incomplets) : comme `loadConfig`,
## `ensureGrowthDefaults` et `repairEvolvedClasses`. Ne purge rien ; les migrations `_contentVersion` n'ont pas été portées
## (la configuration par défaut du portage les inclut déjà).
func ensure_defaults(cfg: Dictionary) -> void:
	var dc := original_config
	if not (cfg.get("itemLibrary") is Array) and dc.get("itemLibrary") is Array:
		cfg["itemLibrary"] = (dc.itemLibrary as Array).duplicate(true)
	if not (cfg.get("classTalents") is Dictionary):
		cfg["classTalents"] = class_talents.duplicate(true)
	else:
		var all: Dictionary = cfg.classTalents
		for c in cfg.get("classes", []):
			var cid := str(c.get("id", ""))
			if not all.has(cid) and class_talents.has(cid):
				all[cid] = (class_talents[cid] as Array).duplicate(true)
	if not (cfg.get("staminaSettings") is Dictionary):
		cfg["staminaSettings"] = (dc.get("staminaSettings", {}) as Dictionary).duplicate(true)
	if not cfg.has("fountainCooldownMinutes"):
		cfg["fountainCooldownMinutes"] = 10
	if not (cfg.get("xpSettings") is Dictionary):
		cfg["xpSettings"] = {"healRatio": 0.8}
	_ensure_growth_defaults(cfg)
	for p in cfg.get("party", []):
		if not (p.get("startEquipment") is Dictionary):
			p["startEquipment"] = {}
		if not p.get("inventorySlots", 0):
			p["inventorySlots"] = 8
		if not p.has("maxStamina"):
			p["maxStamina"] = 100
	for s in cfg.get("spells", []):
		if not s.has("staminaCost"):
			s["staminaCost"] = 15
		if str(s.get("mode", "")) == "":
			s["mode"] = "damage"
	for c in cfg.get("classes", []):
		if not (c.get("spellProgression") is Array):
			c["spellProgression"] = []
		if not (c.get("evolvesTo") is Array):
			c["evolvesTo"] = [null, null]
		c.erase("isBase")
	repair_evolved_classes(cfg)

## `ensureGrowthDefaults` : réglages d'endurance, progression au niveau, coût du Maître des Talents.
func _ensure_growth_defaults(cfg: Dictionary) -> void:
	if not (cfg.get("staminaSettings") is Dictionary):
		cfg["staminaSettings"] = (original_config.get("staminaSettings", {}) as Dictionary).duplicate(true)
	var sta: Dictionary = cfg.staminaSettings
	if not (sta.get("victoryGainPct") is Dictionary):
		sta["victoryGainPct"] = {"easy": 4, "normal": 6, "hard": 9, "hardcore": 13}
	if not sta.has("levelTransitionHpPct"):
		sta["levelTransitionHpPct"] = 25
	if not sta.has("levelTransitionStaPct"):
		sta["levelTransitionStaPct"] = 35
	if not (cfg.get("levelUpGrowth") is Dictionary):
		cfg["levelUpGrowth"] = {"statPerLevel": 0.4, "staminaPerLevel": 2}
	if not cfg.has("talentMasterBaseCost"):
		cfg["talentMasterBaseCost"] = 80

## `repairEvolvedClasses` : prêtre (ordre des sorts), classes évoluées manquantes, liens d'évolution des classes de base.
func repair_evolved_classes(cfg: Dictionary) -> void:
	if not (cfg.get("classes") is Array):
		return
	var classes: Array = cfg.classes
	var priest: Dictionary = {}
	for c in classes:
		if c.get("id") == "class_priest":
			priest = c
	if not priest.is_empty() and (priest.get("allowedSpellIds") is Array):
		var ids: Array = priest.allowedSpellIds
		if ids.size() > 0 and ids[0] == "spell_holy1" and ids.has("spell_heal1"):
			var rest: Array = ids.filter(func(id): return id != "spell_heal1" and id != "spell_holy1")
			priest["allowedSpellIds"] = ["spell_heal1", "spell_holy1"] + rest
	for base_name in BASE_EVOLUTIONS:
		for evo_name in BASE_EVOLUTIONS[base_name]:
			var has := false
			for c in classes:
				if c.get("name") == evo_name:
					has = true
			if not has:
				for dcls in original_config.get("classes", []):
					if dcls.get("name") == evo_name:
						classes.append((dcls as Dictionary).duplicate(true))
						break
	for c in classes:
		var evo = c.get("evolvesTo")
		var is_empty := not (evo is Array) or (evo as Array).all(func(x): return x == null or str(x) == "")
		var allowed = BASE_EVOLUTIONS.get(str(c.get("name", "")))
		if is_empty and allowed != null:
			var found: Array = []
			for n in allowed:
				var fid = null
				for x in classes:
					if x.get("name") == n:
						fid = x.get("id")
						break
				found.append(fid)
			if found.any(func(x): return x != null):
				c["evolvesTo"] = found
				if not c.has("evolveLevel"):
					c["evolveLevel"] = 5

## Portrait (téléphone) : la base 1280×720 rendrait l'interface minuscule ; on agrandit pour viser ~540 unités de large.
## Dans la scène de jeu, l'interface est dessinée sur une zone de conception 1600 x 1000 (comme la page de l'original) puis
## réduite/agrandie pour toujours tout afficher, sans ascenseur, quelle que soit la définition de l'écran.
const GAME_DESIGN := Vector2(1600.0, 1000.0)
var game_scale_mode: bool = false:
	set(v):
		game_scale_mode = v
		_update_scale()

func _update_scale() -> void:
	var win := get_window()
	var sz := Vector2(win.size)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var base := minf(sz.x / 1280.0, sz.y / 720.0)
	var factor := 1.0
	if sz.x < sz.y * 1.05:
		factor = clampf((sz.x / 540.0) / base, 1.0, 8.0)
	elif game_scale_mode:
		var real := minf(sz.x / GAME_DESIGN.x, sz.y / GAME_DESIGN.y)
		factor = real / base
	win.content_scale_factor = factor

## « Créer votre propre donjon » : part d'un donjon aléatoire modifiable dans l'administration (`startCreateOwnDungeon`).
func create_own_dungeon() -> void:
	resume_game = {}
	config = DungeonGenerator.build_config(original_config, 3, 13, 11, "normal", [])
	config.erase("runModifierIds")
	config.erase("genDims")
	ensure_defaults(config)
	save_config()
	admin_unlocked = true
	play_origin = "custom"
	own_dungeon_launched = false
	Loader.go("res://scenes/admin.tscn", "admin")

## Partie en cours mise de côté pendant qu'on ouvre l'administration depuis le jeu : {"config", "save", "origin", "transient"}.
var resume_game: Dictionary = {}

func open_admin() -> void:
	Loader.go("res://scenes/admin.tscn", "admin")

## Retour à l'accueil (`switchView('home')`) : verrouille l'administration et oublie la partie suspendue.
func go_home() -> void:
	resume_game = {}
	admin_unlocked = false
	play_origin = "original"
	Sound.stop_ambient()
	Loader.go("res://scenes/home.tscn", "home")
