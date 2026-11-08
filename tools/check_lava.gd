extends Node
## Thème lava v2 (Les Forges du monde brisé) : matériaux, ambiance, kit volcanique (cotes des passages, plan déterministe, jamais sur un mur / départ / objet,
## désactivable), magma décorative (jamais sur une case spéciale, limites de lumières et d'effets, aucun nœud de collision), ancien rendu intact quand l'option est coupée.
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var DG = DungeonGenerator
	var fails: Array = []
	Settings.lava_v2 = true
	for k in ["wall", "floor", "ceil"]:
		var m = ThemeMaterials.for_theme("lava").get(k)
		if m == null or not (m as StandardMaterial3D).albedo_texture:
			fails.append("matériau lava v2 sans texture : " + k)
	if ThemeMaterials.for_theme("lava").get("wall") == ThemeMaterials.for_theme("gothic").get("wall"):
		fails.append("lava partage le mur du gothic")
	# cotes des passages : ouverture libre >= 3,0 x 3,5 et aucune pierre dans la baie
	KitDecor.reset_cache()
	for id in ["arch", "portal_room", "portal_door", "portal_stair"]:
		var o := KitGeometryLava.opening(id)
		if o.x < 3.0 or o.y < 3.5:
			fails.append("ouverture trop petite : %s %s" % [id, o])
		var mesh := KitGeometryLava.build(id)
		var arr := mesh.surface_get_arrays(0)
		var hw := o.x * 0.5
		for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.x) < hw - 0.06 and v.y < o.y - 0.001 and v.y > 0.03:
				fails.append("pierre dans la baie de %s : %s" % [id, v])
				break
		print("passage ", id, " : ", o)
	var pil := KitGeometryLava.build("pillar")
	var pb := pil.get_aabb()
	if pb.size.x > 0.95 or pb.size.z > 0.95 or pb.position.y < -0.01 or pb.end.y > 4.06:
		fails.append("pilier hors emprise : %s" % pb)
	var cfg: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 4242)
	var tot := {"floor": 0, "wall": 0, "lights": 0, "embers": 0, "kit": 0}
	for lv0 in cfg.levels:
		var lv: Dictionary = lv0.duplicate(true)
		lv["theme"] = "lava"
		var grid := DungeonGrid.new(lv)
		var view := await LevelBuilder.build(lv, grid)
		if view.find_child("KitDecor", true, false) == null:
			fails.append("kit volcanique absent")
		else:
			tot.kit += int(KitDecor.last_stats.get("total", 0))
		if view.find_child("LavaFx", true, false) == null and LavaFx.last_stats.is_empty():
			fails.append("magma absente")
		for k in ["floor", "wall", "lights", "embers"]:
			tot[k] += int(LavaFx.last_stats.get(k, 0))
		if int(LavaFx.last_stats.get("lights", 0)) > LavaFx.MAX_LIGHTS or int(LavaFx.last_stats.get("embers", 0)) > LavaFx.MAX_EMBERS:
			fails.append("trop de lumières ou de braises")
		var fx := view.find_child("LavaFx", true, false)
		if fx != null:
			for n in fx.find_children("*", "CollisionObject3D", true, false):
				fails.append("collision dans la magma")
		view.free()
		var nd := LevelBuilder.niche_data(grid, lv, false)
		var p1: Dictionary = LavaFx.plan(lv, grid, nd.niches, nd.holes)
		var p2: Dictionary = LavaFx.plan(lv, grid, nd.niches, nd.holes)
		if str(p1) != str(p2):
			fails.append("plan de magma non déterministe")
		var special := KitDecor._special_cells(lv, RoomDecor._blocked_cells(lv), nd.niches)
		for f in p1.floor:
			var cx := int(roundf(((f.pos as Vector3).x - f.d.x * 2.0) / LevelBuilder.CELL))
			var cy := int(roundf(((f.pos as Vector3).z - f.d.y * 2.0) / LevelBuilder.CELL))
			var cell := Vector2i(cx, cy)
			if grid.cell(cx, cy) != "." or special.has(cell):
				fails.append("fissure sur une case non libre : %s" % cell)
				break
		# rendu repli : option coupée = ni kit ni magma, mêmes règles de génération
		Settings.lava_v2 = false
		var v0 := await LevelBuilder.build(lv, grid)
		if v0.find_child("KitDecor", true, false) != null or v0.find_child("LavaFx", true, false) != null:
			fails.append("ancien rendu lava altéré par le kit v2")
		v0.free()
		Settings.lava_v2 = true
	print("lava v2 : kit ", tot.kit, " modules, magma sol ", tot.floor, ", failles ", tot.wall, ", lumières ", tot.lights, ", braises ", tot.embers)
	if tot.kit == 0:
		fails.append("aucun module posé")
	if tot.floor + tot.wall == 0:
		fails.append("aucune magma posée sur les 3 niveaux")
	# autres thèmes : ni kit ni magma
	for th in ["stone", "dirt", "damp", "ruins", "ice", "temple"]:
		var lv: Dictionary = cfg.levels[0].duplicate(true)
		lv["theme"] = th
		var view := await LevelBuilder.build(lv, DungeonGrid.new(lv))
		if view.find_child("KitDecor", true, false) != null or view.find_child("LavaFx", true, false) != null:
			fails.append("kit ou magma posé sur le thème " + th)
		view.free()
	if fails.is_empty():
		print("check_lava : OK")
	else:
		for f in fails:
			printerr("ÉCHEC : ", f)
		printerr("check_lava : ", fails.size(), " échec(s)")
	get_tree().quit(0 if fails.is_empty() else 1)
