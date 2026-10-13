extends SceneTree
## Vérifie le sprite AFFICHÉ pendant un combat (celui de la salle de combat) : immobile au repos, avance seulement vers l'écran quand le monstre attaque.
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
	var omax := 0.0
	for i in 200:
		await process_frame
		if not is_instance_valid(node):
			break
		if not ents._react.is_empty():
			continue          # une attaque du monstre est en cours : ce n'est pas le repos
		lo = minf(lo, node.scale.y)
		hi = maxf(hi, node.scale.y)
		var off0: Vector3 = node.get_meta("off", Vector3.ZERO)
		omax = maxf(omax, off0.length())
	print("repos : scale.y %.3f – %.3f · décalage max %.3f" % [lo, hi, omax])
	var bad := 0
	if hi - lo > 0.001 or omax > 0.001:
		bad += 1
		print("ÉCHEC : le monstre bouge au repos")
	stage.react(stage.mon_id, "attack")
	var amax := 0.0
	var smax := 0.0
	for i in 40:
		await process_frame
		var off1: Vector3 = node.get_meta("off", Vector3.ZERO)
		amax = maxf(amax, off1.length())
		smax = maxf(smax, absf(node.scale.y - 1.0))
	print("attaque : avancée %.3f · déformation %.3f" % [amax, smax])
	if amax < 0.2:
		bad += 1
		print("ÉCHEC : pas d'avancée à l'attaque")
	if smax > 0.001:
		bad += 1
		print("ÉCHEC : déformation du sprite à l'attaque")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
