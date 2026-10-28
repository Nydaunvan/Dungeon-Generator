extends Node
## Écran « jeu vidéo » (GameScreen) et icônes dessinées (GameIcons), sans réseau : toutes les icônes se dessinent, le mode en ligne s'ouvre dessus,
## les touches Haut/Bas changent de mode, Entrée lance, Gauche/Droite changent d'onglet, Échap ferme, les règles se replient.
## Lancer : godot --headless --path . res://tools/check_game_screen.tscn
var fails := 0

func check(label: String, ok: bool) -> void:
	if ok:
		print("OK  : ", label)
	else:
		fails += 1
		print("ÉCHEC : ", label)

func fake(_m: int, _url: String, _h: PackedStringArray, _b: String) -> Dictionary:
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": 200, "body": "[]".to_utf8_buffer()}

func key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)

func _ready() -> void:
	var all_ok := true
	for n in GameIcons.PATHS:
		var t := GameIcons.tex(n, 32, Color.WHITE)
		if t == null or t.get_width() < 8:
			all_ok = false
			print("icône illisible : ", n)
	check("toutes les icônes se dessinent", all_ok)
	var used_ok := true
	for t in OnlineHub.TABS:
		used_ok = used_ok and GameIcons.has(t[2])
	for m in OnlineHub.PLAY_MODES:
		used_ok = used_ok and GameIcons.has(OnlineHub.MODE_GLYPH[m])
	check("onglets et modes ont leur icône", used_ok)
	check("icône inconnue : pas de plantage", GameIcons.tex("nexiste_pas", 16) == null)

	Cloud._transport = Callable(self, "fake")
	Cloud.url = "https://exemple.supabase.co"
	Cloud.key = "k"
	Cloud.session = {"access_token": "A", "refresh_token": "R", "expires_at": Time.get_unix_time_from_system() + 3000.0, "user_id": "p9", "pseudo": "Nyra"}
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var launched := [false]
	var h := OnlineHub.open(host, func(): launched[0] = true)
	await get_tree().create_timer(0.6).timeout
	check("le mode en ligne est un GameScreen plein cadre", h._modal is GameScreen and h._modal.is_in_group("modal"))
	check("onglets : texte en capitales", (h._tab_buttons["play"] as Button).text == L.t("ui.hub.tab_play").to_upper())
	check("règles repliées par défaut", h._body.find_children("*", "GridContainer", true, false).all(func(g): return not g.is_visible_in_tree()))
	key(KEY_DOWN)
	await get_tree().create_timer(0.3).timeout
	check("Bas : mode suivant (partie classée)", h._mode == "ranked")
	key(KEY_UP)
	await get_tree().create_timer(0.3).timeout
	check("Haut : retour à la partie libre", h._mode == "free")
	key(KEY_ENTER)
	await get_tree().create_timer(0.3).timeout
	check("Entrée : lance la partie libre et ferme l'écran", launched[0] and not h._alive())

	var h2 := OnlineHub.open(host, func(): pass)
	await get_tree().create_timer(0.4).timeout
	key(KEY_RIGHT)
	await get_tree().create_timer(0.3).timeout
	check("Droite : onglet Classements", h2._tab == "boards")
	key(KEY_LEFT)
	await get_tree().create_timer(0.3).timeout
	check("Gauche : onglet Jouer", h2._tab == "play")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().create_timer(0.3).timeout
	check("Échap ferme l'écran", not h2._alive())
	print("check_game_screen : ", "OK" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit()
