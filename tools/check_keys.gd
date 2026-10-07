extends Node
## Touches du clavier : valeurs par défaut par langue, réassignation, conflits, mémorisation, onglet Paramètres › Commandes.
## godot --headless --path . res://tools/check_keys.tscn

const TMP := "user://check_keys.cfg"
var _bad := 0

func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	Keybinds.cfg_path = TMP
	Keybinds.reload()
	_defaults()
	_events()
	_assign()
	_persist()
	await _settings_tab()
	Keybinds.reset_all()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("OK : touches du clavier" if _bad == 0 else "%d écart(s)" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)

func _ck(ok: bool, what: String) -> void:
	if not ok:
		_bad += 1
		print("ÉCART : ", what)

func _key(code: int, phys: int = 0, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code as Key
	e.physical_keycode = (phys if phys != 0 else code) as Key
	e.alt_pressed = alt
	return e

func _defaults() -> void:
	Keybinds.lang_override = "fr"
	_ck(Keybinds.keys("forward") == [KEY_Z, KEY_UP], "FR : avancer = Z, ↑")
	_ck(Keybinds.keys("turn_left") == [KEY_Q, KEY_LEFT], "FR : tourner à gauche = Q, ←")
	_ck(Keybinds.keys("turn_right") == [KEY_D, KEY_RIGHT], "FR : tourner à droite = D, →")
	Keybinds.lang_override = "en"
	_ck(Keybinds.keys("forward") == [KEY_W, KEY_UP], "EN : avancer = W, ↑")
	_ck(Keybinds.keys("turn_left") == [KEY_A, KEY_LEFT], "EN : tourner à gauche = A, ←")
	_ck(Keybinds.keys("strafe_left") == [KEY_Q], "EN : pas de côté à gauche = Q")
	# toutes les actions ont des touches par défaut dans les deux langues, sans doublon dans une langue
	for l in ["fr", "en"]:
		Keybinds.lang_override = l
		var seen := {}
		for id in Keybinds.ids():
			var ks := Keybinds.keys(id)
			_ck(not ks.is_empty(), "%s : %s sans touche" % [l, id])
			for k in ks:
				_ck(not seen.has(k), "%s : touche %s en double (%s / %s)" % [l, Keybinds.label(int(k)), id, seen.get(k, "")])
				seen[k] = id
	Keybinds.lang_override = "fr"

func _events() -> void:
	Keybinds.lang_override = "fr"
	_ck(Keybinds.action_for(_key(KEY_Z)) == "forward", "FR : Z avance")
	_ck(Keybinds.action_for(_key(KEY_W)) == "", "FR : W ne fait rien")
	Keybinds.lang_override = "en"
	_ck(Keybinds.action_for(_key(KEY_W)) == "forward", "EN : W avance")
	_ck(Keybinds.action_for(_key(KEY_Z)) == "", "EN : Z ne fait rien")
	Keybinds.lang_override = "fr"
	_ck(Keybinds.action_for(_key(KEY_AMPERSAND, KEY_1)) == "slot_1", "AZERTY : la touche « 1 » (rangée du haut, sans Maj) = emplacement 1")
	_ck(Keybinds.action_for(_key(KEY_KP_ENTER)) == "interact", "Entrée du pavé numérique = interagir")
	_ck(Keybinds.action_for(_key(KEY_Z, 0, true)) == "", "Alt + touche : ignoré")
	_ck(Keybinds.matches("perf", _key(KEY_F3)), "F3 = compteur de performances")
	_ck(Keybinds.label(KEY_SPACE) == "Espace", "libellé français de la barre d'espace")
	Keybinds.lang_override = "en"
	_ck(Keybinds.label(KEY_SPACE) == "Space" and Keybinds.label(KEY_UP) == "↑", "libellés anglais")
	Keybinds.lang_override = "fr"

func _assign() -> void:
	Keybinds.reset_all()
	var lost := Keybinds.assign("forward", 0, KEY_T)
	_ck(lost.is_empty(), "touche libre : aucun conflit")
	_ck(Keybinds.keys("forward") == [KEY_T, KEY_UP] and Keybinds.is_custom("forward"), "avancer = T, ↑ après réassignation")
	_ck(Keybinds.action_for(_key(KEY_T)) == "forward" and Keybinds.action_for(_key(KEY_Z)) == "", "T avance, Z ne fait plus rien")
	lost = Keybinds.assign("back", 0, KEY_UP)   # ↑ était sur « avancer »
	_ck(lost == ["forward"], "conflit : ↑ retirée de « avancer » (%s)" % str(lost))
	_ck(Keybinds.keys("forward") == [KEY_T] and Keybinds.keys("back") == [KEY_UP, KEY_DOWN], "après conflit : avancer = T ; reculer = ↑, ↓")
	Keybinds.assign("back", 1, KEY_UP)   # même touche dans les deux emplacements : un seul reste
	_ck(Keybinds.keys("back") == [KEY_UP], "une action ne garde pas deux fois la même touche")
	Keybinds.clear_slot("back", 1)
	_ck(Keybinds.keys("back").is_empty() and Keybinds.text("back") == "—", "emplacements vidés")
	Keybinds.reset("back")
	Keybinds.reset("forward")
	_ck(Keybinds.keys("back") == [KEY_S, KEY_DOWN] and not Keybinds.is_custom("back"), "rétablissement d'une action")
	# redonner à une action ses touches par défaut efface sa personnalisation
	Keybinds.assign("forward", 0, KEY_T)
	Keybinds.assign("forward", 0, KEY_Z)
	_ck(not Keybinds.is_custom("forward"), "retour aux touches par défaut : plus de personnalisation")
	Keybinds.reset_all()

func _persist() -> void:
	Keybinds.reset_all()
	Keybinds.assign("map", 0, KEY_N)
	Keybinds.assign("flee", 1, KEY_V)
	Keybinds.reload()
	_ck(Keybinds.keys("map") == [KEY_N] and Keybinds.keys("flee") == [KEY_C, KEY_V], "mémorisation après rechargement du fichier")
	# une commande modifiée garde le choix dans les deux langues ; les autres suivent la langue
	Keybinds.assign("forward", 0, KEY_T)
	Keybinds.lang_override = "en"
	_ck(Keybinds.keys("forward") == [KEY_T, KEY_UP], "commande modifiée : choix gardé en anglais")
	_ck(Keybinds.keys("turn_left") == [KEY_A, KEY_LEFT], "commande intacte : suit la langue (anglais)")
	Keybinds.lang_override = "fr"
	# les autres sections du fichier sont conservées
	var cf := ConfigFile.new()
	cf.load(TMP)
	cf.set_value("sound", "music", 0.3)
	cf.save(TMP)
	Keybinds.assign("inventory", 0, KEY_B)
	cf.load(TMP)
	_ck(is_equal_approx(float(cf.get_value("sound", "music", 0.0)), 0.3), "les autres réglages du fichier sont conservés")
	Keybinds.reset_all()

func _settings_tab() -> void:
	Keybinds.reset_all()
	Keybinds.lang_override = ""
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var m := SettingsModal.open(host, "controls")
	await get_tree().process_frame
	await get_tree().process_frame
	var ctl = m.get_meta("settings_ctl")
	var rows := 0
	for ch in ctl._body.get_children():
		if ch is HBoxContainer and ch.get_child_count() == 4:
			rows += 1
	_ck(rows == Keybinds.ACTIONS.size(), "onglet Commandes : %d lignes (attendu %d)" % [rows, Keybinds.ACTIONS.size()])
	# réassignation par une vraie pression de touche
	var btn: Button = null
	for ch in ctl._body.get_children():
		if ch is HBoxContainer and ch.get_child_count() == 4 and (ch.get_child(1) as Button).text == Keybinds.label(int(Keybinds.slots("map")[0])):
			btn = ch.get_child(1)
			break
	_ck(btn != null, "bouton de la carte trouvé")
	if btn != null:
		btn.pressed.emit()
		await get_tree().process_frame
		_ck(ctl._capture != null, "écoute de la touche démarrée")
		Input.parse_input_event(_key(KEY_ESCAPE))
		await get_tree().process_frame
		_ck(ctl._capture == null and is_instance_valid(m) and not m.is_queued_for_deletion(), "Échap annule l'écoute sans fermer la fenêtre")
		btn.pressed.emit()
		await get_tree().process_frame
		Input.parse_input_event(_key(KEY_N))
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_ck(Keybinds.keys("map") == [KEY_N], "touche N assignée à la carte par l'onglet")
	m.queue_free()
	host.queue_free()
