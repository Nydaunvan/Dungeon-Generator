extends SceneTree
## Teste « Mes donjons » : donjon vide, sauvegarde automatique, fenêtres. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_mydungeons.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/md"
	root.size = Vector2i(1280, 900)
	await process_frame
	var data = root.get_node("Data")
	var MD = load("res://scripts/core/my_dungeons.gd")
	# nettoyage des essais précédents
	for m in MD.list():
		MD.delete(m.id)
	# 1. donjon vide : ouvert, pas encore enregistré ; modifié : enregistré
	data.create_empty_dungeon()
	await create_timer(5.0).timeout
	print("après ouverture : ", MD.count(), " donjon(s) (attendu 0)")
	var cfg: Dictionary = data.admin_config()
	var lv: Dictionary = cfg.levels[0]
	print("niveau vide : monstres=", lv.monsters.size(), " objets=", lv.items.size(), " lignes=", lv.mapRows.size())
	cfg["title"] = "Ma crypte oubliée"
	data.save_config()
	print("après modification : ", MD.count(), " donjon(s) (attendu 1), current_id=", MD.current_id)
	# 2. deuxième donjon (base aléatoire modifiée) puis publication simulée
	var id2: String = MD.create(load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 1, 5), "", "Un donjon plein de rats pour s'échauffer.", true)
	MD.rename(id2, "Les caves aux rats")
	# 3. sortie : autosave puis home
	data.go_home()
	await create_timer(4.0).timeout
	var home = current_scene
	var host: Node = home._modal_layer
	load("res://scripts/ui/create_choice_modal.gd").open(host)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_choice.png")
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.5).timeout
	load("res://scripts/ui/my_dungeons_modal.gd").open(host)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_list.png")
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	await create_timer(0.5).timeout
	var G = load("res://scripts/ui/gallery_modal.gd").open(host)
	await create_timer(1.0).timeout
	for row in [{"id": "x1", "title": "Le temple englouti", "description": "Trois niveaux d'eau et d'ombre, pour groupes confirmés.", "downloads": 42, "created_at": "2026-10-09T10:00:00Z", "owner_id": "u1", "pseudo": "Nydaunvan"},
			{"id": "x2", "title": "Cave des gobelins", "description": "", "downloads": 3, "created_at": "2026-10-10T18:30:00Z", "owner_id": "u2", "pseudo": "Brouss"}]:
		G._list.add_child(G._card(row))
	G._flash("")
	G._modal._fit()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(pre + "_gallery.png")
	for m in MD.list():
		MD.delete(m.id)
	quit()
