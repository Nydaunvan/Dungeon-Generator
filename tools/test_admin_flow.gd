extends SceneTree
## Porte d'accès, bannière (3 états), API de téléportation et enregistrement depuis l'administration.
var fails := 0
func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok: fails += 1

func _init() -> void:
	root.size = Vector2i(1280, 800)
	await process_frame
	var data = root.get_node("Data")
	# 1. porte d'accès, hors partie
	data.admin_unlocked = false
	data.resume_game = {}
	data.play_origin = "custom"
	var adm: Node = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(0.5).timeout
	check(not adm._main.visible and adm._gate.visible, "porte affichée quand verrouillé")
	adm._pw_input.text = "mauvais"
	adm._try_login()
	check(adm._pw_error.text == "Mot de passe incorrect." and not data.admin_unlocked, "mauvais mot de passe refusé")
	adm._pw_input.text = "admin123"
	adm._try_login()
	check(data.admin_unlocked and adm._main.visible, "admin123 accepté (adminPassword par défaut)")
	check(adm._banner.visible and adm._banner_text.text.begins_with("Vous configurez") and not adm._btn_resume.visible, "bannière état 1 : « Vous configurez votre propre donjon »")
	# message d'erreur de téléportation sans partie
	check(data.admin_teleport_group("x", 1, 1) == data.MSG_NO_RUN, "téléportation sans partie : message exact")
	check(data.admin_teleport_village() == data.MSG_NO_RUN, "village sans partie : message exact")
	# 2. partie aléatoire en cours
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 3)
	data.launch(cfg, "random")
	await create_timer(1.5).timeout
	var m = current_scene
	data.resume_game = m.snapshot()
	data.admin_unlocked = true
	adm.queue_free()
	adm = load("res://scenes/admin.tscn").instantiate()
	root.add_child(adm)
	await create_timer(0.5).timeout
	check(adm._banner.visible and adm._btn_play.text == "◀ Reprendre la partie en cours" and not adm._btn_resume.visible, "bannière état 2 : donjon aléatoire en cours")
	check(data.admin_teleport_group("inconnu", 1, 1) == data.MSG_LEVEL_NOT_IN_RUN, "niveau inconnu : message exact")
	var lid := str(cfg.levels[1].id)
	check(data.admin_teleport_group(lid, 2, 2) == "", "téléportation vers un niveau de la partie")
	check(data.admin_party_marker().level_id == lid, "marqueur du groupe mis à jour")
	# 3. donjon créé, partie lancée depuis l'admin
	data.play_origin = "custom"
	data.own_dungeon_launched = true
	adm._update_banner()
	check(adm._btn_resume.visible and adm._banner_text.text.begins_with("Vous pouvez reprendre"), "bannière état 3 : reprise + relance possibles")
	# partie terminée : plus de bouton reprendre
	data.resume_game.save["game_over"] = true
	adm._update_banner()
	check(not adm._btn_resume.visible and adm._banner_text.text.begins_with("Vous configurez"), "partie terminée exclue de gameActive")
	# 4. mot de passe personnalisé
	data.admin_config()["adminPassword"] = "sésame"
	data.admin_unlocked = false
	adm._show_state()
	adm._pw_input.text = "admin123"
	adm._try_login()
	check(not data.admin_unlocked, "ancien mot de passe refusé après changement")
	adm._pw_input.text = "sésame"
	adm._try_login()
	check(data.admin_unlocked, "nouveau mot de passe accepté")
	# 5. enregistrement : message d'état
	adm._select_tab("general")
	await create_timer(0.3).timeout
	adm.save()
	check(adm.admin_status != null and adm.admin_status.text.begins_with("Configuration enregistrée à "), "message : %s" % adm.admin_status.text)
	data.go_home()
	check(not data.admin_unlocked and data.resume_game.is_empty(), "retour à l'accueil reverrouille")
	print("ÉCHECS: %d" % fails)
	quit()
