extends SceneTree
## Capture de l'infobulle de sort. Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_spelltip.gd -- <sortie.png>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	var gs = m.gs
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var host := Control.new()
	host.position = Vector2(500, 600)
	host.size = Vector2(60, 40)
	m.add_child(host)
	var ST = load("res://scripts/ui/spell_tip.gd")
	var sp: Dictionary = {}
	for s in gs.cfg.spells:
		if str(s.get("mode", "")) == "healSingle":
			sp = s
			break
	await ST.show_for(host, sp, 0, gs.party[2])
	await create_timer(0.8).timeout
	var t = ST._inst
	print("tip pos ", t.position, " size ", t.size, " min ", t.get_combined_minimum_size(), " label ", t._label.size)
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/spelltip.png")
	quit()
