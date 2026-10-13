extends SceneTree
## Capture du brouillard en mouvement (niveau avec brume forcée), à plusieurs secondes d'intervalle.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/shot_mist.gd -- <préfixe>
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var fm = load("res://scripts/dungeon/fog_mist.gd")
	fm.force = 1
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var mist = m.level_node.get_node_or_null("FogMist")
	print("brume présente : ", mist != null, " bancs : ", mist._banks.size() if mist != null else 0)
	if m.ctrl.model_in_combat():
		m.ctrl.flee()
		await create_timer(1.0).timeout
	m.wand.set_process(false)          # pas de monstre errant : on regarde le couloir
	for i in 2:
		m._on_command("forward")
		await create_timer(0.5).timeout
	for k in 3:
		await create_timer(2.5).timeout
		if a.size() > 0:
			root.get_texture().get_image().save_png("%s_%d.png" % [a[0], k])
	quit(0)
