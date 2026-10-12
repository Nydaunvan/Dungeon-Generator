extends SceneTree
## Qualité graphique au lancement d'une partie :
##  1. mode Auto : le résultat de calibration est mémorisé avec la signature de la machine et réutilisé au lancement suivant
##     (Ultra visible dès la première image) ; une autre machine / une autre cible de fluidité refait la mesure ;
##  2. préréglage Ultra : à la fin de l'écran de chargement, la vue 3D a déjà tous les réglages Ultra.
## Lancer (Xvfb requis) : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_quality_start.gd
var fails := 0
func check(label: String, cond: bool) -> void:
	print(("OK     " if cond else "ÉCHEC  "), label)
	if not cond:
		fails += 1

func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var S = root.get_node("Settings")
	var data = root.get_node("Data")
	# --- 1. mémorisation de la calibration (mode Auto)
	S.set_preset("auto")
	S._forget_calib()
	S.level = "ultra"
	S.dyn_scale = 0.9
	S._calib_finish(110.0)
	var cf := ConfigFile.new()
	check("calibration mémorisée (niveau ultra, échelle 0.9)", cf.load(S.CFG) == OK and str(cf.get_value("calib", "level", "")) == "ultra" and is_equal_approx(float(cf.get_value("calib", "dyn", 0.0)), 0.9))
	S._load()
	check("relance : niveau ultra restauré dès le chargement des réglages", S.level == "ultra" and is_equal_approx(S.dyn_scale, 0.9))
	check("relance : calibration considérée faite (aucune mesure visible)", S.calib_state == "done" and S.calib_restored)
	check("relance : l'adaptation peut encore monter (pas de plafond)", S._session_cap == 99 and is_equal_approx(S._dyn_cap, 1.0))
	cf.set_value("calib", "sig", "autre machine")
	cf.save(S.CFG)
	S._load()
	check("autre machine : la calibration est refaite", S.calib_state == "pending" and not S.calib_restored and S.level != "ultra")
	S.redetect()
	cf = ConfigFile.new()
	cf.load(S.CFG)
	check("nouvelle détection : résultat mémorisé effacé", not cf.has_section("calib"))
	# --- 2. préréglage Ultra : tout est appliqué à la fin du chargement
	S.set_preset("ultra")
	data.launch(data.original_config if false else load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 2, 11, 9, "normal", [], 7, 1), "random")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		var m = current_scene
		if m != null and m.get("layout") != null and m.get("_loading") == false and not root.get_node("Loader").is_active():
			break
		await process_frame
	var m = current_scene
	var vp: SubViewport = m.layout.sub_viewport
	check("Ultra : résolution 3D ×1,25", is_equal_approx(vp.scaling_3d_scale, 1.25))
	check("Ultra : anticrénelage 4×", vp.msaa_3d == Viewport.MSAA_4X)
	check("Ultra : filtrage anisotrope 16×", vp.anisotropic_filtering_level == Viewport.ANISOTROPY_16X)
	check("Ultra : textures HD", S.texture_hd() and S.level == "ultra")
	check("Ultra : la vue 3D dessine à la fin du chargement", vp.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE)
	S.set_preset("auto")
	S._forget_calib()
	print("ÉCHECS : ", fails)
	quit(1 if fails > 0 else 0)
