extends Node
## Thème lava v2 (Les Forges du monde brisé) : matériaux, ambiance, kit volcanique (cotes des passages, plan déterministe, jamais sur un mur / départ / objet,
## désactivable), magma décorative (jamais sur une case spéciale, limites de lumières et d'effets, aucun nœud de collision), ancien rendu intact quand l'option est coupée.
## Nombre de surfaces « magma » (nappe de lave) du niveau construit.
func view_mesh_count_magma(lv: Dictionary, grid: DungeonGrid) -> int:
	var v := await LevelBuilder.build(lv, grid)
	var n := 0
	for mi in v.find_children("LevelMesh_*", "MeshInstance3D", false, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			if (mi as MeshInstance3D).mesh.surface_get_material(i) == LavaFx.slab_material():
				n += 1
	v.free()
	return n

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
	var tot := {"items": 0, "lights": 0, "embers": 0, "kit": 0, "breaches": 0}
	var kinds := {}
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
		for k in ["items", "lights", "embers", "breaches"]:
			tot[k] += int(LavaFx.last_stats.get(k, 0))
		if int(LavaFx.last_stats.get("lights", 0)) > LavaFx.MAX_LIGHTS + LavaFx.MAX_BREACH_LIGHTS or int(LavaFx.last_stats.get("embers", 0)) > LavaFx.MAX_EMBERS + LavaFx.MAX_BREACH_EMBERS:
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
		for f in p1.items:
			var cell := Vector2i(int(f.x), int(f.y))
			kinds[f.kind] = int(kinds.get(f.kind, 0)) + 1
			if grid.cell(cell.x, cell.y) != "." or special.has(cell) or KitDecor._near_special(special, grid, cell, 1):
				fails.append("élément de magma sur une case non libre : %s" % cell)
				break
			if grid.cell(cell.x + (f.d as Vector2i).x, cell.y + (f.d as Vector2i).y) != "#":
				fails.append("élément de magma hors d'un mur")
				break
		# brèches : déterministes, sur un mur plein épais d'au moins deux cases, jamais sur une case spéciale ni un pan évidé, nappe de lave présente
		var b1: Dictionary = LavaBreach.select(grid, lv, nd.niches, true)
		var b2: Dictionary = LavaBreach.select(grid, lv, nd.niches, true)
		if str(b1) != str(b2):
			fails.append("brèches non déterministes")
		for bk in b1:
			var bs: Dictionary = b1[bk]
			var bd: Vector2i = bs.d
			var bc := Vector2i(int(bs.x), int(bs.y))
			if grid.cell(bc.x, bc.y) != "." or LavaBreach._excluded(lv, nd.niches).has(bc) or grid.cell(bc.x + bd.x, bc.y + bd.y) != "#" or grid.cell(bc.x + bd.x * 2, bc.y + bd.y * 2) != "#":
				fails.append("brèche mal placée : %s" % bc)
				break
			if absf(float(bs.s)) > 1.0 or float(bs.depth) > 1.7:
				fails.append("brèche hors du pan ou trop profonde : %s" % bc)
				break
		if b1.size() > 0:
			var lvl_nodes: int = await view_mesh_count_magma(lv, grid)
			if lvl_nodes == 0:
				fails.append("brèches sans nappe de lave")
		# rendu repli : option coupée = ni kit ni magma, mêmes règles de génération
		Settings.lava_v2 = false
		var v0 := await LevelBuilder.build(lv, grid)
		if v0.find_child("KitDecor", true, false) != null or v0.find_child("LavaFx", true, false) != null:
			fails.append("ancien rendu lava altéré par le kit v2")
		v0.free()
		Settings.lava_v2 = true
	print("lava v2 : kit ", tot.kit, " modules, éléments de magma ", tot.items, " ", kinds, ", lumières ", tot.lights, ", braises ", tot.embers)
	if tot.breaches == 0:
		fails.append("aucune brèche sur les 3 niveaux")
	if tot.lights > (6 + LavaFx.MAX_BREACH_LIGHTS) * cfg.levels.size():
		fails.append("trop de lumières de magma")
	# la fracture est un maillage irrégulier : aucun sommet ne s'écarte de plus de 0,2 du mur ou du sol, rien ne déborde du pan
	var grid0 := DungeonGrid.new(cfg.levels[0])
	if tot.kit == 0:
		fails.append("aucun module posé")
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
