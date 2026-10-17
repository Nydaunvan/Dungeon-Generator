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
	var good: bool = ok and fx_nodes >= 1 and back.distance_to(centers[2]) < 1.5 and fov_ok and ov.visible
	print("CARDFX ok=", ok, " effets=", fx_nodes, " ecart=", back.distance_to(centers[2]), " fov=", ov._cam.fov, " -> ", "OK" if good else "ECHEC")
	get_tree().quit(0 if good else 1)
