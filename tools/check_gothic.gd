extends Node
## Thème gothic : matériaux créés (avec leur indicateur « provisoire » tant que les textures finales manquent), ambiance propre au thème sans effet
## sur les autres, kit d'architecture : plan de pose déterministe (même niveau -> même plan), jamais sur une case de mur, de départ ou d'objet,
## aucune arche près d'une porte ou d'un escalier, désactivable (aucun nœud ajouté), sans GLB rien n'est posé (hors boîtes de test).
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var DG = DungeonGenerator
	var fails: Array = []
	# matériaux
	var mats: Dictionary = ThemeMaterials.for_theme("gothic")
	for k in ["wall", "floor", "ceil"]:
		if not mats.has(k) or mats[k] == null:
			fails.append("matériau gothic manquant : " + k)
	print("matériaux gothic : ", mats.keys(), " ; provisoires : ", ThemeMaterials.gothic_placeholder)
	if ThemeMaterials.gothic_placeholder:
		print("ATTENTION : textures gothic_hd/lite absentes, matériaux provisoires")
	if ThemeMaterials.for_theme("stone").get("wall") == mats.get("wall"):
		fails.append("gothic partage le matériau de mur de stone")
	# ambiance
	if VisualFx.light_k("stone", "ambient_k") != 1.0 or VisualFx.light_k("ice", "torch_range_k") != 1.0:
		fails.append("l'ambiance gothic déborde sur les autres thèmes")
	if VisualFx.light_k("gothic", "torch_range_k") >= 1.0:
		fails.append("portée des torches gothic non limitée")
	for th in ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]:      # autres thèmes : valeurs d'origine de la torche du groupe (couleur ffb060, atténuation 1)
		if VisualFx.light_color(th, "player_color", Color("ffb060")) != Color("ffb060") or VisualFx.light_k(th, "player_atten", 1.0) != 1.0 \
				or VisualFx.light_k(th, "player_range_k") != 1.0 or VisualFx.light_k(th, "player_energy_k") != 1.0 or VisualFx.light_k(th, "torch_energy_k") != 1.0:
			fails.append("l'éclairage de %s a changé" % th)
	var env := Environment.new()
	VisualFx.apply_environment(env, "gothic", false)
	var amb := env.ambient_light_color
	if amb.b <= amb.r:
		fails.append("ambiance gothic non bleutée")
	var env2 := Environment.new()
	var amb_before := env2.ambient_light_color
	VisualFx.apply_environment(env2, "stone", false)
	if env2.ambient_light_color != amb_before:
		fails.append("l'ambiance de stone a changé")
	# modèles livrés : encombrement dans le cahier des charges, ouverture libre des arches et encadrements, origine au sol
	var glb_count := 0
	var opening := {"arch": Vector2(3.0, 3.5), "door_frame": Vector2(3.0, 3.4), "stair_frame": Vector2(3.0, 3.4)}
	KitDecor.placeholders = false
	KitDecor.reset_cache()
	var clear_zones := {      # baies en arc brisé : zones qui doivent rester vides (passage du joueur au centre, hauteur sous la clef)
		"ogive": [AABB(Vector3(-0.9, 0.0, -1.0), Vector3(1.8, 2.45, 2.0)), AABB(Vector3(-0.05, 0.0, -1.0), Vector3(0.1, 3.45, 2.0))],
		"portal_room": [AABB(Vector3(-0.9, 0.0, -1.0), Vector3(1.8, 2.45, 2.0)), AABB(Vector3(-0.05, 0.0, -1.0), Vector3(0.1, 3.45, 2.0))],
		"portal_door": [AABB(Vector3(-0.9, 0.0, -1.0), Vector3(1.8, 2.45, 2.0)), AABB(Vector3(-0.05, 0.0, -1.0), Vector3(0.1, 3.45, 2.0))],
		"portal_stair": [AABB(Vector3(-0.9, 0.0, -1.0), Vector3(1.8, 2.45, 2.0)), AABB(Vector3(-0.05, 0.0, -1.0), Vector3(0.1, 3.45, 2.0))],
		"rib": [AABB(Vector3(-2.0, 0.0, -1.0), Vector3(4.0, 2.9, 2.0))],      # nervure : rien sous 2,9 u (œil du joueur à 2, monstres <= 1,85)
	}
	for id in KitDecor.MODULES:
		if KitDecor._parts(id).is_empty():
			print("module absent (ni GLB ni généré) : ", id)
			continue
		glb_count += 1
		if clear_zones.has(id):
			for part in KitDecor._parts(id):
				var pm0: Mesh = part.mesh
				for si0 in pm0.get_surface_count():
					var ar0 := pm0.surface_get_arrays(si0)
					var vv0: PackedVector3Array = ar0[Mesh.ARRAY_VERTEX]
					for k0 in range(0, vv0.size() - 2, 3):
						var pts: Array = [vv0[k0], vv0[k0 + 1], vv0[k0 + 2], (vv0[k0] + vv0[k0 + 1] + vv0[k0 + 2]) / 3.0]
						for pt in pts:
							var q: Vector3 = (part.xf as Transform3D) * pt
							for zone in clear_zones[id]:
								if (zone as AABB).grow(-0.002).has_point(q):
									fails.append("baie obstruée (arc brisé) : %s %s" % [id, str(q)])
		var box := AABB()
		var first := true
		var gap: Vector2 = opening.get(id, Vector2.ZERO)
		for part in KitDecor._parts(id):
			var a: AABB = (part.xf as Transform3D) * (part.mesh as Mesh).get_aabb()
			box = a if first else box.merge(a)
			first = false
			if gap != Vector2.ZERO and not KitGeometry.PROCEDURAL.has(id) and ResourceLoader.exists(KitDecor.GLB_DIR + id + ".glb"):       # rien dans la baie : x dans ±gap.x/2, y de 0 à gap.y, sur toute la profondeur
				var hole := AABB(Vector3(-gap.x * 0.5 + 0.001, 0.0, -1.0), Vector3(gap.x - 0.002, gap.y - 0.001, 2.0))
				if a.intersects(hole):
					fails.append("baie obstruée : " + id)
		# normales (les GLB n'en ont pas : recalculées par KitDecor.flat_normals) : elles doivent regarder vers l'extérieur de chaque pièce
		var out_n := 0
		var all_n := 0
		for part in KitDecor._parts(id):
			var pm: Mesh = part.mesh
			var ctr: Vector3 = pm.get_aabb().get_center()
			for si in pm.get_surface_count():
				var arr := pm.surface_get_arrays(si)
				if arr[Mesh.ARRAY_NORMAL] == null:
					fails.append("normales absentes : " + id)
					continue
				var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				for k in range(0, vv.size() - 2, 3):
					var cen := (vv[k] + vv[k + 1] + vv[k + 2]) / 3.0
					all_n += 1
					if nn[k].dot(cen - ctr) > -0.01:
						out_n += 1
		if all_n > 0 and float(out_n) / float(all_n) < 0.65:      # heuristique (centre de la pièce) : une pièce inversée serait proche de 0 %
			fails.append("normales tournées vers l'intérieur : %s (%d/%d vers l'extérieur)" % [id, out_n, all_n])
		var lim: Vector3 = KitDecor.MODULES[id].size
		if id != "bracket" and id != "ornament" and id != "rib" and id != "cornice":
			if box.size.x > lim.x + 0.01 or box.size.y > lim.y + 0.01 or box.size.z > lim.z + 0.2:
				fails.append("encombrement dépassé : %s %s" % [id, str(box.size)])
			if absf(box.position.y) > 0.01:
				fails.append("origine hors du sol : " + id)
		if box.size.z > 1.9:
			fails.append("module trop profond : " + id)
		print("GLB ", id, " : ", box.position, box.size)
	# kit : sans GLB rien n'est posé, avec les GLB livrés il l'est
	var any_glb := glb_count > 0
	var planned_total := 0
	var counts_all := {}
	var cfg: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 4242)
	for lv0 in cfg.levels:
		var lv: Dictionary = lv0.duplicate(true)
		lv["theme"] = "gothic"
		var grid := DungeonGrid.new(lv)
		var view := await LevelBuilder.build(lv, grid)
		if (view.find_child("KitDecor", true, false) != null) != any_glb:
			fails.append("kit posé sans GLB, ou absent malgré les GLB")
		view.free()
		# boîtes de test : plan complet
		KitDecor.placeholders = true
		KitDecor.reset_cache()
		var avail := {}
		for id in KitDecor.MODULES:
			avail[id] = true
		var nd := LevelBuilder.niche_data(grid, lv, false)
		var p1: Array = await KitDecor.plan(lv, grid, nd.niches, nd.holes, avail)
		var p2: Array = await KitDecor.plan(lv, grid, nd.niches, nd.holes, avail)
		if p1.size() != p2.size():
			fails.append("plan non déterministe (taille)")
		else:
			for i in p1.size():
				if p1[i].id != p2[i].id or not (p1[i].xf as Transform3D).is_equal_approx(p2[i].xf):
					fails.append("plan non déterministe")
					break
		var special := KitDecor._special_cells(lv, RoomDecor._blocked_cells(lv), nd.niches)
		for it in p1:
			planned_total += 1
			counts_all[it.id] = int(counts_all.get(it.id, 0)) + 1
			var o: Vector3 = it.xf.origin
			var cx := int(floor((o.x + 2.0) / 4.0))
			var cz := int(floor((o.z + 2.0) / 4.0))
			if it.id == "arch":
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q := Vector2i(cx + dx, cz + dy)
						var ch := grid.cell(q.x, q.y)
						if ch == "D" or ch == "S" or special.has(q):
							fails.append("arche près d'une porte, d'un escalier ou d'un objet")
		# avec le kit actif et les boîtes : les nœuds existent ; désactivé : aucun
		var v2 := await LevelBuilder.build(lv, grid)
		if v2.find_child("KitDecor", true, false) == null and p1.size() > 0:
			fails.append("kit actif sans nœud")
		v2.free()
		KitDecor.enabled = false
		var v3 := await LevelBuilder.build(lv, grid)
		if v3.find_child("KitDecor", true, false) != null:
			fails.append("kit désactivé mais présent")
		v3.free()
		KitDecor.enabled = true
		KitDecor.placeholders = false
		KitDecor.reset_cache()
		# autres thèmes : jamais de kit
		var lv_s: Dictionary = lv.duplicate(true)
		lv_s["theme"] = "stone"
		var v4 := await LevelBuilder.build(lv_s, DungeonGrid.new(lv_s))
		if v4.find_child("KitDecor", true, false) != null:
			fails.append("kit posé sur un autre thème")
		v4.free()
	# arches : espacement, aucune arche près d'une porte/escalier/objet (déjà testé), nombre raisonnable sur des niveaux variés
	var arch_levels := 0
	var arch_total := 0
	for seed_i in 6:
		var cfg2: Dictionary = DG.build_config(Data.original_config, 3, 19, 15, "normal", [], 1, 900 + seed_i)
		for lv2 in cfg2.levels:
			var g2 := DungeonGrid.new(lv2)
			var nd2 := LevelBuilder.niche_data(g2, lv2, false)
			var sp2 := KitDecor._special_cells(lv2, RoomDecor._blocked_cells(lv2), nd2.niches)
			var ar: Array = KitDecor._arch_edges(lv2, g2, sp2, str(lv2.id).hash())
			var ar2: Array = KitDecor._arch_edges(lv2, g2, sp2, str(lv2.id).hash())
			if ar.size() != ar2.size():
				fails.append("arches non déterministes")
			arch_levels += 1
			arch_total += ar.size()
			for i in ar.size():
				for j in range(i + 1, ar.size()):
					if (ar[i].pos as Vector3).distance_to(ar[j].pos) < KitDecor.ARCH_GAP_ROOM * 4.0 - 0.01:
						fails.append("arches trop proches")
	print("arches : ", arch_total, " sur ", arch_levels, " niveaux")
	if arch_total < arch_levels * 2:
		fails.append("trop peu d'arches")
	print("modules planifiés (boîtes de test) : ", planned_total, " ", counts_all)
	if planned_total == 0:
		fails.append("aucun module planifié")
	for need in ["plinth", "pilaster", "ogive", "pillar", "portal_door", "bracket", "cornice", "portal_stair"]:
		if int(counts_all.get(need, 0)) == 0:
			fails.append("module jamais planifié : " + need)
	var uniq := {}
	for f in fails:
		uniq[f] = int(uniq.get(f, 0)) + 1
	for f in uniq:
		print("ECHEC ", f, " x", uniq[f])
	print("RESULTAT gothic -> %s" % ("OK" if fails.is_empty() else "ECHEC"))
	get_tree().quit()
