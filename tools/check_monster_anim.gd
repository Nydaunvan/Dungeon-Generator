extends SceneTree
## Vérifie les animations des monstres : respiration au repos, réactions (touché/attaque/étourdi), mort animée, option coupée.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_monster_anim.gd
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(7.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var ents = m.ctrl.view.entities
	var node: Node3D = null
	var mid := ""
	for p in ents.monsters.keys():
		for e in ents.monsters[p]:
			if node == null and e.node.visible:
				node = e.node
				mid = str(e.def.id)
	var bad := 0
	if node == null:
		print("aucun monstre visible")
		quit(1)
		return
	var settings = root.get_node("Settings")
	settings.monster_anim = true
	settings.reduced_motion = false
	var lo := 9.0
	var hi := 0.0
	for i in 90:
		await process_frame
		lo = minf(lo, node.scale.y)
		hi = maxf(hi, node.scale.y)
	print("respiration scale.y : %.3f – %.3f" % [lo, hi])
	if hi - lo < 0.02:
		bad += 1
		print("ÉCHEC : pas de respiration")
	var sy_hit := 9.0
	ents.play(mid, "hit")
	for i in 12:
		await process_frame
		sy_hit = minf(sy_hit, node.scale.y)
	print("touché : scale.y min %.3f" % sy_hit)
	if sy_hit > lo - 0.03:
		bad += 1
		print("ÉCHEC : pas d'écrasement")
	await create_timer(0.8).timeout
	if node.has_meta("mat0"):
		bad += 1
		print("ÉCHEC : matériau d'origine non restauré")
	var sy_att := 0.0
	ents.play(mid, "attack")
	for i in 14:
		await process_frame
		sy_att = maxf(sy_att, node.scale.y)
	print("attaque : scale.y max %.3f" % sy_att)
	if sy_att < hi + 0.05:
		bad += 1
		print("ÉCHEC : pas de bond")
	await create_timer(0.8).timeout
	settings.monster_anim = false
	await create_timer(0.3).timeout
	print("option coupée : scale %s, y %.3f / repos %.3f" % [node.scale, node.position.y, float(node.get_meta("by"))])
	if not node.scale.is_equal_approx(Vector3.ONE) or absf(node.position.y - float(node.get_meta("by"))) > 0.001:
		bad += 1
		print("ÉCHEC : pose non remise à zéro")
	settings.monster_anim = true
	await create_timer(0.3).timeout
	ents.remove_monster(mid, true)
	await create_timer(0.2).timeout
	print("mort en cours : valide=%s alpha=%.2f" % [is_instance_valid(node), (node.material_override as StandardMaterial3D).albedo_color.a if is_instance_valid(node) else -1.0])
	if not is_instance_valid(node):
		bad += 1
		print("ÉCHEC : libéré trop tôt")
	await create_timer(0.8).timeout
	if is_instance_valid(node):
		bad += 1
		print("ÉCHEC : sprite jamais libéré")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
