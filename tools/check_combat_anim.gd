extends SceneTree
## Vérifie les animations du sprite AFFICHÉ pendant un combat (celui de la salle de combat, pas celui de la carte) : souffle plus ample, balancement, annonce de l'attaque quand la jauge approche du plein.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_combat_anim.gd -- [capture.png]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var ents = m.ctrl.view.entities
	var engaged := false
	for i in 400:
		if m.ctrl.model_in_combat():
			engaged = true
			break
		m._on_command("forward")
		await create_timer(0.35).timeout
		for mo in get_nodes_in_group("modal"):
			mo.queue_free()
	print("combat engagé : ", engaged)
	if not engaged:
		quit(1)
		return
	var stage = m.ctrl.view.stage
	print("salle de combat active : ", stage.active, " sprites : ", stage._nodes.size())
	if not stage.active or stage._nodes.is_empty():
		print("ÉCHEC : pas de sprite dans la salle de combat")
		quit(1)
		return
	var node: Node3D = null
	for k in stage._nodes.keys():
		node = stage._nodes[k].node
	var lo := 9.0
	var hi := 0.0
	var wind_max := 0.0
	var xmin := 99.0
	var xmax := -99.0
	var shot := false
	for i in 300:
		await process_frame
		if not is_instance_valid(node):
			break
		lo = minf(lo, node.scale.y)
		hi = maxf(hi, node.scale.y)
		if not ents._react.is_empty():
			continue
		var ci: Dictionary = ents.combat_info.call()
		wind_max = maxf(wind_max, float(ci.get("gauge", 0.0)))
		var off: Vector3 = node.get_meta("off", Vector3.ZERO)
		xmin = minf(xmin, off.length())
		xmax = maxf(xmax, off.length())
		if a.size() > 0 and not shot and float(ci.get("gauge", 0.0)) > 0.9:
			shot = true
			root.get_texture().get_image().save_png(a[0])
	print("scale.y %.3f – %.3f · décalage %.3f – %.3f · jauge max %.2f" % [lo, hi, xmin, xmax, wind_max])
	var bad := 0
	if hi - lo < 0.06:
		bad += 1
		print("ÉCHEC : souffle de combat trop faible")
	if xmax - xmin < 0.03:
		bad += 1
		print("ÉCHEC : pas de balancement")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
