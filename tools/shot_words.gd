extends SceneTree
## Capture de la liste des mots interdits (données factices). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_words.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var pre: String = a[0] if a.size() > 0 else "/tmp/words"
	root.size = Vector2i(1280, 800)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var S = load("res://scripts/ui/super_admin_modal.gd")
	var s = S.new()
	s._host = current_scene._modals()
	s._modal = load("res://scripts/ui/modal.gd").open(s._host, "Super admin", 760.0)
	s._list = VBoxContainer.new()
	s._modal.content.add_child(s._list)
	var w := ["BITE","CON","CONNARD","SALOPE","PUTE","MERDE","ENCULÉ","NIQUE","FDP","HEIL HITLER","KILL YOURSELF","SALE ARABE","PD","TG","BATARD","BÂTARD","ABRUTI","CRETIN","DEBILE","ZOB","NAZI","SALAUD","CHIER","ÉCOEURANT"]
	s._words_section(s._list, {"ok": true, "data": w}, s._gen)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(pre + "_all.png")
	var le: LineEdit = s._list.find_children("*", "LineEdit", true, false)[0]
	le.text = "ba"
	le.text_changed.emit("ba")
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(pre + "_search.png")
	quit()
