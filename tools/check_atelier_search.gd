extends Node
## Recherche de l'atelier (Ctrl K / champ en haut du menu) après un passage dans l'éditeur de niveaux.
## godot --path . res://tools/check_atelier_search.tscn -- [largeur] [hauteur] [langue]   (écran requis : xvfb-run)
var fails := 0

func check(label: String, cond: bool) -> void:
	print(("ok     " if cond else "ÉCHEC  "), label)
	if not cond:
		fails += 1

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]) if a.size() > 0 else 1280
	var h := int(a[1]) if a.size() > 1 else 800
	get_window().size = Vector2i(w, h)
	if a.size() > 2:
		Data.set_lang(a[2])
	await get_tree().process_frame
	Data.admin_unlocked = true
	var adm: Control = load("res://scenes/admin.tscn").instantiate()
	add_child(adm)
	await get_tree().create_timer(0.8).timeout
	print("[1] éditeur de niveaux")
	adm._select_tab("levels")
	await get_tree().create_timer(1.0).timeout
	var lv: Dictionary = AdminLevels._current()
	lv["name"] = str(lv.get("name", "")) + " "
	Ax.changed()
	print("[2] retour à l'accueil de l'atelier")
	Ax.flush()
	adm.go("home")
	await get_tree().create_timer(0.6).timeout
	print("[3] clic sur le champ de recherche")
	adm._side.search_pressed.emit()
	await get_tree().create_timer(0.6).timeout
	var layer: Node = adm.modals()
	check("la fenêtre de recherche est ouverte", layer.get_child_count() > 0 and layer.get_child(layer.get_child_count() - 1) is AtelierSearch)
	var s: AtelierSearch = layer.get_child(layer.get_child_count() - 1)
	for q in ["", "niveau", "level", "pv", "ö", "zzzzzz"]:
		s._edit.text = q
		s._refresh()
		await get_tree().process_frame
	check("une saisie sans correspondance ne donne aucun résultat", s._results.is_empty())
	s._edit.text = "niveau"
	s._refresh()
	check("« niveau » trouve des résultats", not s._results.is_empty())
	for i in mini(s._results.size(), 12):
		s._sel = i
		s._draw_list()
	var target := str(s._results[0].section)
	s._pick(0)
	await get_tree().create_timer(0.8).timeout
	check("un résultat ouvre sa page (%s)" % target, adm._tab == target)
	check("la fenêtre de recherche est refermée", not (adm.modals().get_child_count() > 0 and not adm.modals().get_child(0).is_queued_for_deletion()))
	print("RECHERCHE_ATELIER ", "OK" if fails == 0 else "ECHEC")
	get_tree().quit(0 if fails == 0 else 1)
