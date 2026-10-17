extends Node
## Couche d'effets au-dessus de l'interface : un effet de monstre vise la carte (et non le bas de la vue), un soin aussi.
func _ready() -> void:
	VisualFx.force_forward = true
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var ov := CardFxOverlay.new()
	root.add_child(ov)
	get_window().size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var view := Control.new()
	view.position = Vector2(100, 50)
	view.size = Vector2(800, 500)
	root.add_child(view)
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 500)
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 70.0
	vp.add_child(cam)
	await get_tree().process_frame
	var centers := [Vector2(300, 700), Vector2(500, 700), Vector2(700, 700), Vector2(900, 700)]
	var tgt := {"pos": Vector3(0, 0, -4), "h": 1.5, "w": 1.0}
	var ctx := {"style": "shadow", "mode": "damage", "fromMonster": true, "victim": 2, "ally": 2, "caster": 0, "fx": "", "solo": false}
	var ok := ov.play("x", tgt, ctx, cam, view, vp, centers)
	await get_tree().process_frame
	var fx_nodes := 0
	for ch in ov._world.get_children():
		if ch is SpellFx3D:
			fx_nodes += 1
	# position d'une place : doit se reprojeter sur le centre de la carte 2 (700, 700)
	var back := ov._cam.unproject_position(ov._cam.project_position(centers[2] - ov.global_position, 1.5))
	var fov_ok := absf(ov._cam.fov - rad_to_deg(2.0 * atan(tan(deg_to_rad(35.0)) * ov.size.y / 500.0))) < 0.01
	# sort d'un héros (carte 1) : l'effet part de sa carte ; coup de monstre sur la carte 3
	var ctx2 := {"style": "arcane", "mode": "damage", "fx": "", "caster": 1, "ally": 1, "solo": false}
	var ok2 := ov.play("y", tgt, ctx2, cam, view, vp, centers)
	var ok3 := ov.play_action("hit", {"victim": 3, "solo": false}, cam, view, centers)
	await get_tree().process_frame
	var n_fx := 0
	var start_ok := false
	for ch in ov._world.get_children():
		if ch is SpellFx3D:
			n_fx += 1
			var f := ch as SpellFx3D
			if f.caster_idx == 1 and f.slot_px.size() == 4:
				var st: Vector3 = f._start_point()
				start_ok = ov._cam.unproject_position(st).distance_to(centers[1]) < 1.5
	# fontaine avec 3 héros : un soin par carte (3 places), pas de doublon sur la dernière
	var slots3 := ov._world.get_child_count()
	var probe := SpellFxStyles.new()
	probe.cam = ov._cam
	probe.apply_party_ctx({"slotPx": [Vector2(300, 700), Vector2(500, 700), Vector2(700, 700)]})
	var slots_ok: bool = probe._party_slots() == [0, 1, 2] and probe._party_ends(2.2)[0].distance_to(probe._party_ends(2.2)[1]) > 1.0
	# flèche de l'archer (carte 2) : part du centre de sa carte, sans décalage latéral
	var okb := ov.play_action("bow", {"caster": 2, "solo": false}, cam, view, centers, tgt, vp)
	var bow_ok := false
	for ch in ov._world.get_children():
		if ch is SpellFx3D and (ch as SpellFx3D).caster_idx == 2 and (ch as SpellFx3D).slot_px.size() == 4:
			bow_ok = ov._cam.unproject_position((ch as SpellFx3D)._start_point() + (ch as SpellFx3D)._side(1.1)).distance_to(centers[2]) < 1.5
	var good: bool = okb and bow_ok and slots_ok and ok2 and ok3 and n_fx >= 3 and start_ok and ok and fx_nodes >= 1 and back.distance_to(centers[2]) < 1.5 and fov_ok and ov.visible
	print("CARDFX fleche=", okb, bow_ok, " places=", slots_ok, " ok=", ok, " sort=", ok2, " coup=", ok3, " depart_carte=", start_ok, " n=", n_fx, " effets=", fx_nodes, " ecart=", back.distance_to(centers[2]), " fov=", ov._cam.fov, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
