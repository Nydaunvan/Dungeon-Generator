extends SceneTree
## Capture de la carte « Défi de la semaine » (compte à rebours + infobulle de la semaine prochaine). Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_weekly.gd -- <sortie.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 900)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 7, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var hub = load("res://scripts/ui/online_hub.gd").open(current_scene._modals(), Callable(), "play")
	await create_timer(1.0).timeout
	var ends := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 3 * 3600 + 1234)
	hub._weekly = {"period": "2026-W41", "ends_at": ends, "rule": {"icon": "🏕️", "label_fr": "Sans repos", "label_en": "No rest", "desc_fr": "Aucune fontaine dans le donjon : chaque point de vie compte.", "desc_en": "No fountains."},
		"next": {"rule_id": "glass", "icon": "🥂", "label_fr": "Verre brisé", "label_en": "Broken glass"}}
	hub._mode = "weekly"
	hub._show("play")
	await create_timer(4.0).timeout
	var tip_owner: Control = null
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and str((n as Label).tooltip_text).contains("Début :") and n.is_visible_in_tree():
			tip_owner = n
		for ch in n.get_children():
			stack.append(ch)
	print("TIP ", tip_owner.tooltip_text if tip_owner != null else "introuvable")
	var st: Array = [root]
	while not st.is_empty():
		var n2: Node = st.pop_back()
		if n2 is Label and str((n2 as Label).tooltip_text).contains("Semaine prochaine") and n2.is_visible_in_tree():
			print("NEXT ", (n2 as Label).tooltip_text)
		for ch in n2.get_children():
			st.append(ch)
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/weekly.png")
	quit()
