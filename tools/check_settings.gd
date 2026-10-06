extends Control
## Vérifie les réglages graphiques : préréglages cohérents, détection de la machine, machine d'états de l'adaptation
## automatique, présence de tous les textes et ouverture de chaque onglet du menu Paramètres.
## Usage : godot --headless --path . res://tools/check_settings.tscn
## Le fichier user://settings.cfg est sauvegardé puis rétabli : les réglages réels ne sont pas touchés.

var bad := 0

func fail(msg: String) -> void:
	bad += 1
	print("ÉCART : ", msg)

func expect(cond: bool, msg: String) -> void:
	if not cond:
		fail(msg)

func _ready() -> void:
	var backup := FileAccess.get_file_as_bytes(Settings.CFG) if FileAccess.file_exists(Settings.CFG) else PackedByteArray()
	var had_file := FileAccess.file_exists(Settings.CFG)
	_presets()
	_detection()
	_first_launch()
	_flow()
	_adaptation()
	_calibration()
	_texts()
	await _menu()
	# rétablit le fichier de réglages d'origine
	if had_file:
		var f := FileAccess.open(Settings.CFG, FileAccess.WRITE)
		f.store_buffer(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.CFG))
	print("SETTINGS ", "OK" if bad == 0 else "%d écart(s)" % bad)
	get_tree().quit(1 if bad else 0)

# ------------------------------------------------------------------ préréglages

func _presets() -> void:
	var prev: Dictionary = {}
	for l in Settings.LEVELS:
		var v: Dictionary = Settings.preset_values(l)
		for k in Settings.OPTION_KEYS:
			expect(v.has(k), "préréglage %s : option %s absente" % [l, k])
		for k in Settings.INT_KEYS:
			expect(typeof(v[k]) == TYPE_INT, "%s.%s devrait être un entier" % [l, k])
		for k in Settings.FLOAT_KEYS:
			expect(typeof(v[k]) == TYPE_FLOAT, "%s.%s devrait être un flottant" % [l, k])
		for k in Settings.BOOL_KEYS:
			expect(typeof(v[k]) == TYPE_BOOL, "%s.%s devrait être un booléen" % [l, k])
		expect(float(v.res_scale) >= 0.4 and float(v.res_scale) <= 2.0, "%s : résolution hors limites" % l)
		expect(int(v.torch_lights) >= 1 and int(v.torch_lights) < TorchLayer.POOL - 2 + 1, "%s : torches (%d) ≥ réserve de rigs" % [l, v.torch_lights])
		if not prev.is_empty():   # chaque niveau est au moins aussi riche que le précédent
			for k in ["res_scale", "msaa", "aniso", "torch_lights", "particles", "view_distance", "flame_fps"]:
				expect(float(v[k]) >= float(prev[k]), "%s : %s (%s) < niveau précédent (%s)" % [l, k, v[k], prev[k]])
			for k in ["spell_lamps", "texture_hd"]:
				expect(not (bool(prev[k]) and not bool(v[k])), "%s : %s désactivé alors que le niveau précédent l'active" % [l, k])
		prev = v
	# les valeurs des préréglages doivent exister dans les listes déroulantes du menu
	for l in Settings.LEVELS:
		var v: Dictionary = Settings.preset_values(l)
		expect(SettingsModal.RES_VALUES.has(float(v.res_scale)), "%s : résolution absente du menu" % l)
		expect(SettingsModal.PARTICLE_VALUES.has(float(v.particles)), "%s : particules absentes du menu" % l)
		expect(SettingsModal.MSAA_VALUES.has(int(v.msaa)), "%s : MSAA absent du menu" % l)
		expect(SettingsModal.ANISO_VALUES.has(int(v.aniso)), "%s : anisotrope absent du menu" % l)
		expect(SettingsModal.TORCH_VALUES.has(int(v.torch_lights)), "%s : torches absentes du menu" % l)
		expect(SettingsModal.FLAME_VALUES.has(int(v.flame_fps)), "%s : flammes absentes du menu" % l)
		var in_dist := false
		for d in SettingsModal.DISTANCE_VALUES:
			in_dist = in_dist or is_equal_approx(float(d[0]), float(v.view_distance))
		expect(in_dist, "%s : distance absente du menu" % l)

# ------------------------------------------------------------------ détection

func _detection() -> void:
	var cases := [
		["NVIDIA GeForce RTX 3060", 2], ["NVIDIA GeForce GTX 1050 Ti", 2], ["NVIDIA GeForce GT 710", 0],
		["AMD Radeon RX 6700 XT", 2], ["AMD Radeon(TM) Graphics", 1], ["Intel(R) UHD Graphics 620", 0],
		["Intel(R) Iris(R) Xe Graphics", 1], ["Intel(R) Arc(TM) A770", 2], ["llvmpipe (LLVM 20.1.2, 256 bits)", 0],
		["Apple M2", 2], ["Mali-G78", 0], ["Adreno (TM) 650", 0], ["quelque chose d'inconnu", -1]]
	for c in cases:
		var t: int = Settings.gpu_tier(c[0], "")
		expect(t == c[1], "gpu_tier(%s) = %d, attendu %d" % [c[0], t, c[1]])
	expect(Settings.suggest_level(false, false, 2, 16.0, 8) == 2, "PC confortable → Élevé")
	expect(Settings.suggest_level(false, false, 2, 16.0, 8) < 3, "jamais Ultra d'office")
	expect(Settings.suggest_level(false, false, 0, 16.0, 8) == 0, "GPU modeste → Faible")
	expect(Settings.suggest_level(false, false, 2, 4.0, 8) == 0, "4 Go de RAM → Faible")
	expect(Settings.suggest_level(false, false, 2, 6.0, 8) == 1, "6 Go de RAM → Moyen au plus")
	expect(Settings.suggest_level(false, false, 2, 16.0, 2) == 0, "2 cœurs → Faible")
	expect(Settings.suggest_level(true, false, 2, 16.0, 8) == 2, "Web → Élevé au plus")
	expect(Settings.suggest_level(true, true, 2, 16.0, 8) == 0, "mobile → Faible")
	expect(Settings.suggest_level(false, false, -1, 16.0, 8) == 1, "GPU inconnu → Moyen")

## Premier lancement (pas de fichier de réglages) : le mode Auto part du niveau détecté pour la machine.
func _first_launch() -> void:
	if FileAccess.file_exists(Settings.CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.CFG))
	Settings._auto_level = ""
	Settings.preset = "auto"
	Settings._load()
	Settings._resolve()
	expect(Settings._auto_level == Settings._baseline_level(), "premier lancement : niveau de départ (%s) attendu, obtenu %s" % [Settings._baseline_level(), Settings._auto_level])
	expect(Settings.calib_state == "pending", "premier lancement : calibration en attente")
	expect(Settings.level == Settings._auto_level and Settings.preset == "auto" and Settings.auto_adapt, "premier lancement : Auto, adaptation activée")

# ------------------------------------------------------------------ préréglage / personnalisé

func _flow() -> void:
	Settings.reset_graphics()
	expect(Settings.preset == "auto" and Settings.auto_adapt, "réinitialisation : Auto + adaptation")
	Settings.set_preset("ultra")
	expect(Settings.level == "ultra" and is_equal_approx(Settings.res_scale(), 1.25), "Ultra : résolution 125 %")
	expect(Settings.torch_lights() == 7, "Ultra : 7 torches")
	Settings.set_preset("low")
	expect(Settings.pc(10) == 4 and Settings.pc(1) == 1, "Faible : particules ×0,4 (10 → 4), jamais moins de 1")
	expect(not Settings.spell_lamps(), "Faible : pas de lueurs de sorts")
	Settings.set_option("torch_lights", 4)
	expect(Settings.preset == "custom" and Settings.torch_lights() == 4, "modifier une option bascule en Personnalisé")
	expect(is_equal_approx(float(Settings.opt("res_scale")), 0.6), "Personnalisé repart des valeurs du niveau en cours")
	Settings.set_preset("auto")
	expect(Settings.preset == "auto", "retour en Auto")
	Settings.set_reduced_motion(true)
	expect(is_equal_approx(Settings.motion_k(), 0.25), "mouvements réduits : amplitude ×0,25")
	Settings.set_reduced_motion(false)
	expect(Settings.msaa_mode() in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X], "mode MSAA valide")
	Settings.set_preset("high")
	expect(Settings.dice_msaa_mode() == Viewport.MSAA_4X, "dés en 4× à partir d'Élevé")
	Settings.set_preset("low")
	expect(Settings.dice_msaa_mode() == Viewport.MSAA_2X, "dés jamais sans anticrénelage")

# ------------------------------------------------------------------ adaptation automatique

## Simule des fenêtres de mesure : `n` fenêtres à `fps` images par seconde, en laissant passer le délai entre deux changements.
func _windows(n: int, fps: float) -> void:
	for i in n:
		Settings._since_change = 100.0
		Settings._evaluate(fps)

func _adaptation() -> void:
	Settings.reset_graphics()
	Settings.set_preset("auto")
	Settings.level = "high"
	Settings._auto_level = "high"
	Settings._resolve()
	Settings.dyn_scale = 1.0
	Settings.target_fps = 60
	Settings.fps_cap = 0
	# 1) trop lent : d'abord la résolution 3D (4 crans), puis le niveau
	_windows(4, 20.0)
	expect(is_equal_approx(Settings.dyn_scale, 0.6) and Settings.level == "high", "lenteur : résolution 3D réduite d'abord (dyn=%s, niveau=%s)" % [Settings.dyn_scale, Settings.level])
	_windows(1, 20.0)
	expect(Settings.level == "medium" and is_equal_approx(Settings.dyn_scale, 1.0), "lenteur persistante : niveau Moyen, résolution rétablie")
	_windows(10, 20.0)
	expect(Settings.level == "low", "jusqu'à Faible au plus bas (niveau=%s)" % Settings.level)
	_windows(10, 20.0)
	expect(Settings.level == "low" and Settings.dyn_scale >= 0.6 - 0.001, "ne descend pas sous Faible / 60 %")
	# 2) la machine suit : remontée par essai
	Settings.dyn_scale = 1.0
	Settings._stable_t = 0.0
	_windows(10, 60.0)
	expect(Settings.level == "medium" and Settings._probe_from == "low", "fluide longtemps : essai du niveau Moyen")
	# 3) l'essai échoue : retour et plafond mémorisé
	_windows(1, 20.0)
	expect(Settings.level == "low" and Settings.ceiling == "low", "essai raté : retour à Faible, plafond mémorisé")
	_windows(30, 60.0)
	expect(Settings.level == "low", "plafond respecté : pas de nouvel essai")
	# 4) une nouvelle détection oublie le plafond
	Settings.redetect()
	expect(Settings.ceiling == "", "redétection : plafond oublié")
	# 5) niveau fixe : sert de plafond, jamais au-dessus
	Settings.set_preset("medium")
	Settings.level = "low"
	Settings._resolve()
	_windows(30, 60.0)
	expect(Settings.level == "medium", "niveau fixe Moyen : remonte jusqu'à Moyen (niveau=%s)" % Settings.level)
	_windows(30, 60.0)
	expect(Settings.level == "medium", "…et pas au-delà")
	# 6) la limite d'images par seconde abaisse la cible (sinon tout paraîtrait lent)
	Settings.set_fps_cap(30)
	expect(Settings._target() == 30.0, "limite 30 i/s : cible 30")
	Settings.set_fps_cap(0)
	# 7) adaptation désactivable
	Settings.set_auto_adapt(false)
	expect(not Settings._adapt_active(), "adaptation désactivée : inactive")
	Settings.set_auto_adapt(true)
	Settings.set_preset("custom")
	expect(not Settings._adapt_active(), "mode Personnalisé : adaptation inactive")
	Settings.reset_graphics()

# ------------------------------------------------------------------ textes

func _texts() -> void:
	var keys: Array = []
	for l in Settings.LEVELS + ["custom"]:
		keys.append("ui.settings.level_%s" % l)
	for p in Settings.PRESET_IDS:
		keys.append("ui.settings.preset_%s" % p)
		keys.append("ui.settings.preset_hint_%s" % p)
	for d in SettingsModal.DISTANCE_VALUES:
		keys.append("ui.settings.dist_%s" % d[1])
	for p in ["pc", "web", "mobile"]:
		keys.append("ui.settings.platform_%s" % p)
	for e in ["down", "up", "revert", "dyn_down", "dyn_up", "calib"]:
		keys.append("ui.settings.event_%s" % e)
	for c in ["diag_calib", "calib_pending", "calib_running", "calib_none", "calib_done", "toast_calib"]:
		keys.append("ui.settings.%s" % c)
	for t in SettingsModal.TABS:
		keys.append(t[1])
	for k in keys:
		expect(L.t(k) != k, "texte manquant : %s" % k)

# ------------------------------------------------------------------ calibration au lancement

## Lance une calibration et lui donne, pour chaque essai, les images/s fournies (dans l'ordre) ; renvoie le nombre d'essais.
func _calib_run(fps_list: Array) -> int:
	Settings.reset_graphics()
	Settings.set_preset("auto")
	Settings.target_fps = 60
	Settings.fps_cap = 0
	Settings.detect_info["level"] = "medium"
	Settings.calib_state = "pending"
	Settings._calib_begin()
	var n := 0
	while Settings.calib_state != "done" and n < 30:
		var f: float = float(fps_list[mini(n, fps_list.size() - 1)])
		Settings._calib_decide(f)
		n += 1
	return n

func _calibration() -> void:
	var web := Settings.is_web() or Settings.is_mobile()
	var top := "high" if web else "ultra"
	# machine très rapide : on monte tant que la marge est nette (Élevé sur navigateur, Ultra sur PC)
	_calib_run([300.0, 250.0, 200.0])
	expect(Settings.level == top and Settings.dyn_scale == 1.0, "calibration rapide : %s attendu, obtenu %s (dyn %s)" % [top, Settings.level, Settings.dyn_scale])
	# marge correcte : Moyen suffit, on ne cherche pas la performance absolue
	_calib_run([80.0])
	expect(Settings.level == "medium" and Settings.dyn_scale == 1.0, "calibration 80 i/s : Moyen sans réduction (obtenu %s, dyn %s)" % [Settings.level, Settings.dyn_scale])
	expect(not Settings.texture_hd(), "calibration 80 i/s : textures Standard")
	# juste au-dessus de la cible, sans marge : on reste à Moyen
	_calib_run([70.0])
	expect(Settings.level == "medium" and Settings.dyn_scale == 1.0, "calibration 70 i/s : Moyen conservé")
	# machine lente : on réduit la résolution 3D d'abord, jamais le niveau tant que la résolution suffit
	_calib_run([40.0, 70.0])
	expect(Settings.level == "medium" and Settings.dyn_scale < 1.0 and Settings.dyn_scale >= Settings.DYN_MIN, "calibration 40 i/s : résolution réduite (niveau %s, dyn %s)" % [Settings.level, Settings.dyn_scale])
	expect(is_equal_approx(Settings._dyn_cap, Settings.dyn_scale), "calibration lente : plafond de résolution mémorisé")
	# l'adaptation en jeu ne dépasse pas ce qui a été mesuré
	Settings._step_up()
	expect(Settings.dyn_scale <= Settings._dyn_cap + 0.001 and Settings.level == "medium", "après calibration : pas de remontée au-delà du plafond")
	# machine très lente : on finit au plus bas, sans boucler
	var n := _calib_run([5.0])
	expect(Settings.level == "low" and Settings.calib_state == "done" and n < 30, "calibration 5 i/s : Faible et terminée (%s essais)" % n)
	# essai du niveau supérieur raté : retour au niveau validé
	_calib_run([200.0, 20.0])
	expect(Settings.level == "medium" and Settings.dyn_scale == 1.0 and Settings.calib_state == "done", "essai supérieur raté : retour à Moyen (obtenu %s)" % Settings.level)
	# réglage manuel : pas de calibration
	Settings.set_preset("high")
	expect(Settings.calib_state == "done", "préréglage manuel : pas de calibration")
	Settings.set_preset("auto")
	expect(Settings.calib_state == "pending", "retour en Auto : nouvelle calibration")
	# V-Sync et limite rétablis à la fin
	_calib_run([80.0])
	expect(Engine.max_fps == (Settings.fps_cap if Settings.fps_cap > 0 else 0) or Settings.fps_cap == 0, "limite d'images rétablie après calibration")
	expect(Settings.calib_text() != "" and Settings.calib_text() != "ui.settings.calib_done", "texte de calibration")

# ------------------------------------------------------------------ menu

func _menu() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lang in ["fr", "en"]:
		Data.set_lang(lang)
		for t in SettingsModal.TABS:
			var m := SettingsModal.open(self, t[0])
			await get_tree().process_frame
			await get_tree().process_frame
			expect(is_instance_valid(m) and m.content.get_child_count() > 0, "onglet %s (%s) vide" % [t[0], lang])
			m.queue_free()
			await get_tree().process_frame
	# les interactions du menu
	var m2 := SettingsModal.open(self, "graphics")
	await get_tree().process_frame
	var ctl: SettingsModal = m2.get_meta("settings_ctl")
	Settings.set_preset("high")
	ctl._show("graphics")
	await get_tree().process_frame
	expect(ctl._body.get_child_count() > 8, "onglet Graphismes : contenu attendu")
	m2.queue_free()
	Data.set_lang("fr")
