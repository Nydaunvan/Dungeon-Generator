extends Node
## Réglages du jeu (autoload `Settings`) : graphismes, affichage, accessibilité.
## Graphismes : quatre niveaux (Faible, Moyen, Élevé, Ultra) décrits dans data/quality_presets.json, un mode « Auto »
## (calibré à chaque lancement pour tenir la cible d'images/s, puis ajusté pendant la partie) et un mode « Personnalisé ».
## Tout est mémorisé dans user://settings.cfg (la section [sound] reste gérée par `Sound`).
## Les sous-systèmes lisent leurs options ici (`opt`, `pc`, `res_scale`…) et se mettent à jour sur le signal `changed`.

signal changed                                  ## une option appliquée a changé : relire ses valeurs
signal level_adapted(level: String, reason: String)   ## niveau modifié par l'adaptation automatique

const CFG := "user://settings.cfg"
const PRESETS_PATH := "res://data/quality_presets.json"
const LEVELS := ["low", "medium", "high", "ultra"]
const PRESET_IDS := ["auto", "low", "medium", "high", "ultra", "custom"]
const OPTION_KEYS := ["res_scale", "msaa", "aniso", "torch_lights", "particles", "spell_lamps", "view_distance", "texture_hd", "flame_fps"]
const INT_KEYS := ["msaa", "aniso", "torch_lights", "flame_fps"]
const FLOAT_KEYS := ["res_scale", "particles", "view_distance"]
const BOOL_KEYS := ["spell_lamps", "texture_hd"]
const TARGETS := [30, 45, 60]
const FPS_CAPS := [0, 30, 60, 120]

# adaptation dynamique
const WINDOW := 5.0         # secondes d'observation avant chaque décision
const COOLDOWN := 10.0      # délai minimal entre deux changements
const UP_STABLE := 45.0     # secondes de fluidité continue avant d'essayer un niveau supérieur
const PROBE_WATCH := 20.0   # après une montée : si ça rame dans ce délai, retour au niveau d'avant (et on s'y tient)
const SLOW_RATIO := 0.85    # « trop lent » = moins de 85 % de la cible
const DYN_MIN := 0.6        # résolution 3D dynamique : plancher (multiplicateur)
const DYN_STEP := 0.1

# calibration au lancement (mode Auto)
const CALIB_SETTLE := 0.8     # s d'attente après chaque changement de réglage, avant de mesurer
const CALIB_MEASURE := 1.5    # s de mesure par essai
const CALIB_MARGIN := 1.1     # un niveau est retenu s'il atteint cible × 1,1 (marge pour les creux)
const CALIB_HEADROOM := 1.3   # on ne tente le niveau supérieur que si la marge mesurée atteint cible × 1,1 × 1,3
const CALIB_MAX_STEPS := 12   # garde-fou

const _FALLBACK := {"res_scale": 1.0, "msaa": 0, "aniso": 4, "torch_lights": 5, "particles": 1.0, "spell_lamps": true,
	"view_distance": 1.0, "texture_hd": true, "flame_fps": 60}

var preset := "auto"
var level := "high"              # niveau effectif (base des options ; en « custom », sert seulement de point de départ)
var opts: Dictionary = {}        # options effectives (niveau ou personnalisées)
var custom: Dictionary = {}
var dyn_scale := 1.0             # multiplicateur de résolution 3D appliqué par l'adaptation (1 = aucun)
var auto_adapt := true
var target_fps := 60
var fps_cap := 0                 # 0 = illimité
var vsync := true
var reduced_motion := false
var perf_overlay := false
var ceiling := ""                # niveau maximal tenu lors des essais (mode Auto, mémorisé)
var detect_info: Dictionary = {}
var last_event: Dictionary = {}  # dernier ajustement automatique : {time, reason, level} (affiché dans Diagnostic)
var fps_window := 0.0            # dernière moyenne mesurée par l'adaptation
var calib_state := "pending"     # pending → running → done (une calibration par lancement, en mode Auto)
var calib_fps := 0.0             # images/s mesurées sans limite au niveau retenu
var calib_log: Array = []        # essais de la calibration : [{level, dyn, fps}]

var _levels: Dictionary = {}
var _auto_level := ""              # niveau du mode Auto ("" = machine pas encore détectée)
var _fullscreen_pref := -1       # -1 = réglage du projet ; 0/1 = choix mémorisé
var _settle := 8.0
var _acc_t := 0.0
var _acc_n := 0
var _since_change := 0.0
var _stable_t := 0.0
var _probe_from := ""
var _probe_left := 0.0
var _session_cap := 99
var _dyn_cap := 1.0              # résolution 3D dynamique maximale (fixée par la calibration)
var _cw := 0.0                   # attente avant la prochaine mesure de calibration
var _ct := 0.0
var _cn := 0
var _cphase := "down"            # down : on cherche le premier niveau qui tient ; up : on essaie plus haut
var _last_scene: Node
var _toast_layer: CanvasLayer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_presets()
	_load()
	_resolve()
	_apply_display()

# ------------------------------------------------------------------ lecture des options

func opt(key: String) -> Variant:
	return opts.get(key, _FALLBACK.get(key))

## Nombre de particules réellement émises pour `n` prévues (au moins 1).
func pc(n: int) -> int:
	return maxi(1, roundi(float(n) * float(opt("particles"))))

## Échelle de rendu 3D finale (option × multiplicateur dynamique).
func res_scale() -> float:
	return clampf(float(opt("res_scale")) * dyn_scale, 0.4, 2.0)

func msaa_mode() -> int:
	match int(opt("msaa")):
		2: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
		8: return Viewport.MSAA_8X
	return Viewport.MSAA_DISABLED

## Anticrénelage des petits rendus (dés) : jamais moins de 2× (peu coûteux sur une petite surface).
func dice_msaa_mode() -> int:
	return Viewport.MSAA_4X if int(opt("msaa")) >= 4 else Viewport.MSAA_2X

func aniso_mode() -> int:
	match int(opt("aniso")):
		2: return Viewport.ANISOTROPY_2X
		4: return Viewport.ANISOTROPY_4X
		8: return Viewport.ANISOTROPY_8X
		16: return Viewport.ANISOTROPY_16X
	return Viewport.ANISOTROPY_DISABLED

func torch_lights() -> int:
	return int(opt("torch_lights"))

func spell_lamps() -> bool:
	return bool(opt("spell_lamps"))

func view_distance() -> float:
	return float(opt("view_distance"))

func texture_hd() -> bool:
	return bool(opt("texture_hd"))

func flame_fps() -> int:
	return int(opt("flame_fps"))

## Amplitude des vacillements (flammes, lumières) : réduite si « mouvements réduits ».
func motion_k() -> float:
	return 0.25 if reduced_motion else 1.0

func is_web() -> bool:
	return OS.has_feature("web")

func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func level_name(l: String) -> String:
	return L.t("ui.settings.level_%s" % (l if LEVELS.has(l) else "custom"))

func preset_name(p: String) -> String:
	return L.t("ui.settings.preset_%s" % p) if PRESET_IDS.has(p) else p

func preset_values(l: String) -> Dictionary:
	return _clean((_levels.get(l, _FALLBACK) as Dictionary).duplicate())

# ------------------------------------------------------------------ modification

func set_preset(p: String) -> void:
	if not PRESET_IDS.has(p) or (p == "custom" and preset == "custom"):
		return
	if p == "custom":
		custom = opts.duplicate()
	preset = p
	dyn_scale = 1.0
	_dyn_cap = 1.0
	_clear_probe()
	_session_cap = 99
	if LEVELS.has(p):
		level = p
	elif p == "auto":
		level = _auto_level
	_restart_calibration()
	_commit()

## Modifie une option graphique ; bascule en « Personnalisé » (à partir des valeurs en cours).
func set_option(key: String, value: Variant) -> void:
	if not OPTION_KEYS.has(key):
		return
	if preset != "custom":
		custom = opts.duplicate()
		preset = "custom"
		dyn_scale = 1.0
		_dyn_cap = 1.0
		_clear_probe()
		_restart_calibration()
	custom[key] = value
	_commit()

func set_auto_adapt(v: bool) -> void:
	auto_adapt = v
	if not v:
		dyn_scale = 1.0
		_dyn_cap = 1.0
		_clear_probe()
	_commit()

func set_target_fps(v: int) -> void:
	target_fps = v
	_commit()

func set_fps_cap(v: int) -> void:
	fps_cap = v
	_commit()

func set_vsync(v: bool) -> void:
	vsync = v
	_commit()

func set_reduced_motion(v: bool) -> void:
	reduced_motion = v
	_commit()

func set_perf_overlay(v: bool) -> void:
	perf_overlay = v
	_save()

func set_fullscreen(v: bool) -> void:
	_fullscreen_pref = 1 if v else 0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)
	_save()

func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

## Relance la détection de la machine (et oublie les limites apprises) ; en mode Auto, la calibration est refaite.
func redetect() -> void:
	ceiling = ""
	_session_cap = 99
	dyn_scale = 1.0
	_dyn_cap = 1.0
	_clear_probe()
	detect()
	if preset == "auto":
		level = _auto_level
	last_event = {}
	_restart_calibration()
	_commit()

## Remet tous les réglages graphiques par défaut (Auto, adaptation activée, détection refaite).
func reset_graphics() -> void:
	preset = "auto"
	auto_adapt = true
	target_fps = 60
	custom = preset_values("high")
	reduced_motion = false
	redetect()

## Laisse l'adaptation attendre `sec` secondes (chargement, changement de niveau…).
func settle(sec: float = 6.0) -> void:
	_settle = maxf(_settle, sec)
	_cw = maxf(_cw, minf(sec, 2.0))
	_ct = 0.0
	_cn = 0
	_reset_window()

func _commit() -> void:
	_resolve()
	_apply_display()
	_save()
	changed.emit()

## Types attendus des options (le JSON et le fichier de réglages peuvent rendre des flottants) ; valeurs manquantes complétées.
static func _clean(d: Dictionary) -> Dictionary:
	for k in OPTION_KEYS:
		var v: Variant = d.get(k, _FALLBACK[k])
		if INT_KEYS.has(k):
			d[k] = int(v)
		elif FLOAT_KEYS.has(k):
			d[k] = float(v)
		else:
			d[k] = bool(v)
	return d

func _resolve() -> void:
	opts = _clean(custom.duplicate() if preset == "custom" else preset_values(level))

func _apply_display() -> void:
	Engine.max_fps = maxi(0, fps_cap)
	if not is_web():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		if _fullscreen_pref >= 0 and is_fullscreen() != (_fullscreen_pref == 1):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen_pref == 1 else DisplayServer.WINDOW_MODE_WINDOWED)

# ------------------------------------------------------------------ fichier

func _load_presets() -> void:
	var txt := FileAccess.get_file_as_string(PRESETS_PATH)
	var d: Variant = JSON.parse_string(txt) if txt != "" else null
	if d is Dictionary and (d as Dictionary).get("levels") is Dictionary:
		_levels = (d as Dictionary).levels
	else:
		push_error("Settings : %s illisible, valeurs de secours utilisées" % PRESETS_PATH)
	for l in LEVELS:
		if not _levels.has(l):
			_levels[l] = _FALLBACK.duplicate()

func _load() -> void:
	var cf := ConfigFile.new()
	var ok := cf.load(CFG) == OK
	custom = preset_values("high")
	if ok:
		preset = str(cf.get_value("graphics", "preset", "auto"))
		auto_adapt = bool(cf.get_value("graphics", "auto_adapt", true))
		target_fps = int(cf.get_value("graphics", "target_fps", 60))
		var cu: Variant = cf.get_value("graphics", "custom", {})
		if cu is Dictionary:
			for k in OPTION_KEYS:
				if (cu as Dictionary).has(k):
					custom[k] = (cu as Dictionary)[k]
		fps_cap = int(cf.get_value("display", "fps_cap", 0))
		vsync = bool(cf.get_value("display", "vsync", true))
		_fullscreen_pref = int(cf.get_value("display", "fullscreen", -1))
		reduced_motion = bool(cf.get_value("access", "reduced_motion", false))
		if cf.has_section_key("diag", "perf_overlay"):
			perf_overlay = bool(cf.get_value("diag", "perf_overlay", false))
		else:   # ancien fichier du compteur de performances
			var old := ConfigFile.new()
			if old.load("user://perf.cfg") == OK:
				perf_overlay = bool(old.get_value("perf", "on", false))
	custom = _clean(custom)
	if not PRESET_IDS.has(preset):
		preset = "auto"
	if not TARGETS.has(target_fps):
		target_fps = 60
	if not FPS_CAPS.has(fps_cap):
		fps_cap = 0
	detect_info = _machine_info()
	_auto_level = _baseline_level()     # le niveau du mode Auto n'est pas mémorisé : il est recalibré à chaque lancement
	ceiling = ""
	level = preset if LEVELS.has(preset) else _auto_level
	calib_state = "pending" if preset == "auto" else "done"

func _save() -> void:
	var cf := ConfigFile.new()
	cf.load(CFG)
	cf.set_value("graphics", "preset", preset)
	cf.set_value("graphics", "auto_adapt", auto_adapt)
	cf.set_value("graphics", "target_fps", target_fps)
	cf.set_value("graphics", "custom", custom)
	cf.set_value("display", "fps_cap", fps_cap)
	cf.set_value("display", "vsync", vsync)
	cf.set_value("display", "fullscreen", _fullscreen_pref)
	cf.set_value("access", "reduced_motion", reduced_motion)
	cf.set_value("diag", "perf_overlay", perf_overlay)
	cf.save(CFG)

# ------------------------------------------------------------------ détection de la machine

## Classe un GPU d'après son nom : 0 = modeste (intégré, logiciel, mobile), 1 = intermédiaire, 2 = confortable, -1 = inconnu.
static func gpu_tier(gpu: String, vendor: String = "") -> int:
	var n := (gpu + " " + vendor).to_lower()
	for w in ["llvmpipe", "swiftshader", "softpipe", "software", "basic render", "virtualbox", "vmware", "svga", "parallels"]:
		if n.contains(w):
			return 0
	for w in ["adreno", "mali", "powervr", "videocore"]:
		if n.contains(w):
			return 0
	if n.contains("intel"):
		if n.contains(" arc"):
			return 2
		return 1 if n.contains("iris") else 0
	if n.contains("apple"):
		return 2
	if n.contains("nvidia") or n.contains("geforce"):
		for w in [" gt ", " gt1", " gt7", " gt 7", " mx", "gt 10"]:
			if n.contains(w):
				return 0
		return 2
	if n.contains("radeon") or n.contains("amd"):
		for w in ["radeon rx", "radeon pro", "radeon vii"]:
			if n.contains(w):
				return 2
		return 1
	return -1

## Niveau de départ conseillé pour une machine (jamais « ultra » : seul l'essai en jeu peut le valider).
static func suggest_level(web: bool, mobile: bool, tier: int, ram_gb: float, cpus: int) -> int:
	var idx := 1
	if mobile:
		idx = 0
	elif tier >= 0:
		idx = tier
	if web:
		idx = mini(idx, 2)
	if ram_gb > 0.0 and ram_gb <= 4.0:
		idx = mini(idx, 0)
	elif ram_gb > 0.0 and ram_gb <= 6.0:
		idx = mini(idx, 1)
	if cpus > 0 and cpus <= 2:
		idx = mini(idx, 0)
	return idx

func detect() -> void:
	detect_info = _machine_info()
	_auto_level = _baseline_level()

## Niveau de départ du mode Auto : Moyen (textures Standard 1024), ou Faible si la machine est clairement modeste.
func _baseline_level() -> String:
	return LEVELS[clampi(LEVELS.find(str(detect_info.get("level", "medium"))), 0, 1)]

func _machine_info() -> Dictionary:
	var gpu := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var phys := int(OS.get_memory_info().get("physical", 0))
	var ram_gb := float(phys) / 1073741824.0 if phys > 0 else 0.0
	var cpus := OS.get_processor_count()
	var tier := gpu_tier(gpu, vendor)
	var idx := suggest_level(is_web(), is_mobile(), tier, ram_gb, cpus)
	return {"gpu": gpu, "vendor": vendor, "ram_gb": ram_gb, "cpus": cpus, "tier": tier,
		"platform": "mobile" if is_mobile() else ("web" if is_web() else "pc"), "level": LEVELS[idx]}

# ------------------------------------------------------------------ adaptation dynamique

func _process(delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		settle(8.0)
	if calib_state != "done":
		_calibrate(delta)
		_reset_window()
		return
	if not _adapt_active():
		_reset_window()
		return
	if _settle > 0.0:
		_settle -= delta
		return
	if delta > 2.0:     # blocage ponctuel (fenêtre déplacée, chargement) : ignoré ; en dessous, la moyenne sur WINDOW le dilue
		return
	_since_change += delta
	_acc_t += delta
	_acc_n += 1
	if _probe_left > 0.0:
		_probe_left -= delta
	if _acc_t >= WINDOW:
		fps_window = float(_acc_n) / _acc_t
		_evaluate(fps_window)
		_acc_t = 0.0
		_acc_n = 0

func _in_game() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.scene_file_path == "res://scenes/main.tscn"

## Partie en cours, visible et active : les images/s mesurées sont représentatives.
func _in_play() -> bool:
	if not _in_game() or get_tree().paused or Loader.is_active():
		return false
	if not is_web() and not DisplayServer.window_is_focused():   # fenêtre en arrière-plan : mesure faussée (le navigateur suspend déjà l'animation d'un onglet masqué)
		return false
	return true

func _adapt_active() -> bool:
	return auto_adapt and preset != "custom" and _in_play()

func _reset_window() -> void:
	_acc_t = 0.0
	_acc_n = 0

func _target() -> float:
	var t := float(target_fps)
	if fps_cap > 0:
		t = minf(t, float(fps_cap))
	return t

func _max_idx() -> int:
	var cap := 3
	if LEVELS.has(preset):
		cap = LEVELS.find(preset)
	elif preset == "auto" and (is_web() or is_mobile()):
		cap = 2
	if preset == "auto" and ceiling != "":
		cap = mini(cap, LEVELS.find(ceiling))
	return mini(cap, _session_cap)

func _evaluate(avg: float) -> void:
	var slow := avg < _target() * SLOW_RATIO
	if slow:
		_stable_t = 0.0
		if _probe_from != "":
			_revert_probe()
		elif _since_change >= COOLDOWN:
			_step_down()
		return
	_stable_t += WINDOW
	if _probe_from != "" and _probe_left <= 0.0:
		_probe_from = ""      # l'essai a tenu : le niveau est validé
	if _probe_from == "" and _stable_t >= UP_STABLE and _since_change >= COOLDOWN:
		_step_up()

func _step_down() -> void:
	var idx := LEVELS.find(level)
	if dyn_scale > DYN_MIN + 0.001:
		dyn_scale = maxf(DYN_MIN, snappedf(dyn_scale - DYN_STEP, 0.01))
		_adapted("", "dyn_down")
	elif idx > 0:
		level = LEVELS[idx - 1]
		dyn_scale = 1.0
		_dyn_cap = 1.0
		_adapted(level, "down")

func _step_up() -> void:
	var idx := LEVELS.find(level)
	if dyn_scale < _dyn_cap - 0.001:      # jamais au-delà de ce que la calibration a validé
		dyn_scale = minf(_dyn_cap, snappedf(dyn_scale + DYN_STEP, 0.01))
		_adapted("", "dyn_up")
	elif _dyn_cap >= 0.999 and idx < _max_idx():
		_probe_from = level
		_probe_left = PROBE_WATCH
		level = LEVELS[idx + 1]
		_adapted(level, "up")
	else:
		_stable_t = 0.0

func _revert_probe() -> void:
	level = _probe_from
	_session_cap = LEVELS.find(level)
	if preset == "auto":
		ceiling = level
	_clear_probe()
	_adapted(level, "revert")

func _clear_probe() -> void:
	_probe_from = ""
	_probe_left = 0.0
	_stable_t = 0.0
	_since_change = 0.0
	_reset_window()

func _adapted(new_level: String, reason: String) -> void:
	_since_change = 0.0
	_stable_t = 0.0
	_reset_window()
	_settle = 2.0
	if preset == "auto":
		_auto_level = level
	_resolve()
	_save()
	last_event = {"time": Time.get_time_string_from_system(), "reason": reason, "level": level, "dyn": dyn_scale}
	changed.emit()
	if new_level != "":
		var key := "ui.settings.toast_down" if reason == "down" else ("ui.settings.toast_up" if reason == "up" else "ui.settings.toast_revert")
		_show_toast(L.t(key) % level_name(new_level))
		level_adapted.emit(new_level, reason)

# ------------------------------------------------------------------ calibration au lancement

## À chaque lancement (mode Auto), les premières secondes de jeu servent à mesurer la machine SANS limite d'images/s
## (V-Sync levé) : on part de Moyen (textures Standard), on ne réduit que le nécessaire pour tenir la cible (≥ 60 i/s)
## et on ne monte que si la marge mesurée est nette. Rien n'est mémorisé : la mesure est refaite à chaque lancement.
func _restart_calibration() -> void:
	calib_state = "pending" if preset == "auto" else "done"
	calib_log = []
	calib_fps = 0.0
	_cw = 1.0
	_ct = 0.0
	_cn = 0

func _calib_max_idx() -> int:
	return 2 if (is_web() or is_mobile()) else 3

func _calibrate(delta: float) -> void:
	if preset != "auto":
		calib_state = "done"
		return
	if not _in_play():
		return                      # on attend : pas en jeu, chargement, pause ou fenêtre inactive
	if _cw > 0.0:
		_cw -= delta
		return
	if calib_state == "pending":
		_calib_begin()
		return
	if delta > 1.0:                 # blocage isolé (compilation, fenêtre déplacée) : pas représentatif
		return
	_ct += delta
	_cn += 1
	if _ct < CALIB_MEASURE or (_cn < 8 and _ct < 6.0):
		return
	_calib_decide(float(_cn) / _ct)

func _calib_begin() -> void:
	calib_state = "running"
	calib_log = []
	calib_fps = 0.0
	_cphase = "down"
	level = _baseline_level()
	dyn_scale = 1.0
	_dyn_cap = 1.0
	Engine.max_fps = 0                # mesure de la vraie capacité : ni limite d'images, ni V-Sync (sauf navigateur)
	if not is_web():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_calib_next()

func _calib_next() -> void:
	_resolve()
	changed.emit()
	_cw = CALIB_SETTLE
	_ct = 0.0
	_cn = 0

## Un essai mesuré à `f` images/s : on garde ce réglage s'il tient la cible, sinon on réduit le strict nécessaire.
func _calib_decide(f: float) -> void:
	var need := _target() * CALIB_MARGIN
	var idx := LEVELS.find(level)
	calib_log.append({"level": level, "dyn": dyn_scale, "fps": f})
	if calib_log.size() >= CALIB_MAX_STEPS:
		_calib_finish(f)
		return
	if _cphase == "down":
		if f >= need:
			calib_fps = f
			if calib_log.size() == 1 and f >= need * CALIB_HEADROOM and idx < _calib_max_idx():
				_cphase = "up"           # grande marge dès le départ : on tente le niveau au-dessus
				level = LEVELS[idx + 1]
				_calib_next()
				return
			_calib_finish(f)
			return
		if dyn_scale > DYN_MIN + 0.001:
			# le coût suit à peu près le nombre de pixels (∝ échelle²) : échelle visée = échelle × √(mesure / besoin)
			var k := clampf(sqrt(f / need) * 0.97, 0.5, 1.0 - DYN_STEP * 0.5)
			dyn_scale = maxf(DYN_MIN, snappedf(dyn_scale * k, 0.01))
		elif idx > 0:
			level = LEVELS[idx - 1]      # même au plus bas de la résolution : seul recours, on descend d'un niveau
			dyn_scale = 1.0
		else:
			_calib_finish(f)             # tout est au plus bas : la machine n'a pas mieux à offrir
			return
		_calib_next()
		return
	# phase « up » : un niveau supérieur est essayé tant que la marge le justifie
	if f >= need:
		calib_fps = f
		if f >= need * CALIB_HEADROOM and idx < _calib_max_idx():
			level = LEVELS[idx + 1]
			_calib_next()
			return
		_calib_finish(f)
		return
	level = LEVELS[idx - 1]              # le niveau essayé ne tient pas : on revient au précédent, déjà validé
	dyn_scale = 1.0
	_calib_finish(calib_fps)

func _calib_finish(f: float) -> void:
	calib_state = "done"
	calib_fps = f
	_session_cap = LEVELS.find(level)    # l'adaptation en jeu ne monte pas au-dessus de ce que la mesure a validé
	_dyn_cap = dyn_scale
	_auto_level = level
	_clear_probe()
	_settle = 3.0
	_resolve()
	_apply_display()                     # rétablit V-Sync et limite d'images choisis par le joueur
	last_event = {"time": Time.get_time_string_from_system(), "reason": "calib", "level": level, "dyn": dyn_scale}
	changed.emit()
	if level != _baseline_level() or dyn_scale < 0.999:
		_show_toast(L.t("ui.settings.toast_calib") % level_name(level))

## Résumé de la calibration pour l'onglet Diagnostic.
func calib_text() -> String:
	if preset != "auto":
		return L.t("ui.settings.calib_none")
	match calib_state:
		"running": return L.t("ui.settings.calib_running")
		"done": return L.f("ui.settings.calib_done", {"level": level_name(level), "res": roundi(res_scale() * 100.0), "fps": roundi(calib_fps)})
	return L.t("ui.settings.calib_pending")

# ------------------------------------------------------------------ message discret

func _show_toast(text: String) -> void:
	if _toast_layer == null:
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 119
		_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_toast_layer)
		_toast = PanelContainer.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.72)
		sb.border_color = Color("7a5a2c")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(8)
		_toast.add_theme_stylebox_override("panel", sb)
		_toast_label = Label.new()
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_label.add_theme_font_size_override("font_size", 14)
		_toast_label.add_theme_color_override("font_color", Color("e8dcc0"))
		_toast.add_child(_toast_label)
		_toast_layer.add_child(_toast)
	_toast_label.text = text
	_toast.reset_size()
	_toast.position = Vector2((get_viewport().get_visible_rect().size.x - _toast.size.x) * 0.5, 10.0)
	_toast.modulate.a = 0.0
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(3.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
