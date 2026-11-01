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
					if id == "torch_bracket" and (vv[k + 2] - vv[k]).cross(vv[k + 1] - vv[k]).dot(nn[k]) < -1e-9:
						fails.append("torch_bracket : sens des faces incohérent avec les normales")
		if id != "torch_bracket" and all_n > 0 and float(out_n) / float(all_n) < 0.65:      # heuristique (centre de la pièce) : une pièce inversée serait proche de 0 %
			fails.append("normales tournées vers l'intérieur : %s (%d/%d vers l'extérieur)" % [id, out_n, all_n])
		var lim: Vector3 = KitDecor.MODULES[id].size
		if id != "bracket" and id != "torch_bracket" and id != "ornament" and id != "rib" and id != "cornice":
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
	for need in ["plinth", "pilaster", "ogive", "pillar", "portal_door", "torch_bracket", "cornice", "portal_stair"]:
		if int(counts_all.get(need, 0)) == 0:
			fails.append("module jamais planifié : " + need)
	_check_atlas_test(fails)
	_check_sprite_fx(fails)
	_check_smoke(fails)
	_check_textures(fails)
	var uniq := {}
	for f in fails:
		uniq[f] = int(uniq.get(f, 0)) + 1
	for f in uniq:
		print("ECHEC ", f, " x", uniq[f])
	print("RESULTAT gothic -> %s" % ("OK" if fails.is_empty() else "ECHEC"))
	get_tree().quit()


## Textures du thème : tailles, raccord périodique, matière (métal nul, rugosité plausible), teintes froides et peu saturées, ordre mur > sol > plafond en luminosité, joints fins.
func _check_textures(fails: Array) -> void:
	var lum := {}
	for res in [["hd", 2048], ["lite", 1024]]:
		for part in ["wall", "floor", "ceil"]:
			var base := "res://assets/themes/gothic_%s/%s_" % [res[0], part]
			var imgs := {}
			for suffix in ["albedo.jpg", "normal.png", "orm.jpg"]:
				var im := Image.load_from_file(ProjectSettings.globalize_path(base + suffix))
				if im == null or im.is_empty():
					fails.append("texture illisible : " + base + suffix)
					continue
				if im.get_width() != res[1] or im.get_height() != res[1]:
					fails.append("taille de texture : %s%s = %dx%d (attendu %d)" % [base, suffix, im.get_width(), im.get_height(), res[1]])
				imgs[suffix] = im
			if imgs.size() < 3:
				continue
			var a: Image = imgs["albedo.jpg"]
			var n: int = res[1]
			var step := 8
			var sum := 0.0
			var cnt := 0
			var sat := 0.0
			var vals: Array = []
			for y in range(0, n, step):
				for x in range(0, n, step):
					var c := a.get_pixel(x, y)
					var l := c.get_luminance()
					sum += l
					vals.append(l)
					sat += (maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))) / maxf(maxf(c.r, maxf(c.g, c.b)), 0.01)
					cnt += 1
			var mean := sum / cnt
			vals.sort()
			var med: float = vals[vals.size() / 2]
			var joint := 0
			for v in vals:
				if v < med * 0.5:
					joint += 1
			var jf := float(joint) / vals.size()
			# raccord : écart entre bords opposés, comparé à l'écart moyen entre colonnes / lignes voisines
			var wrap_h := 0.0
			var near_h := 0.0
			var wrap_v := 0.0
			var near_v := 0.0
			for i in range(0, n, 4):
				wrap_h += absf(a.get_pixel(0, i).get_luminance() - a.get_pixel(n - 1, i).get_luminance())
				near_h += absf(a.get_pixel(n / 2, i).get_luminance() - a.get_pixel(n / 2 + 1, i).get_luminance())
				wrap_v += absf(a.get_pixel(i, 0).get_luminance() - a.get_pixel(i, n - 1).get_luminance())
				near_v += absf(a.get_pixel(i, n / 2).get_luminance() - a.get_pixel(i, n / 2 + 1).get_luminance())
			var seam := maxf(wrap_h, wrap_v) / maxf(maxf(near_h, near_v), 1e-6)
			var orm: Image = imgs["orm.jpg"]
			var metal := 0.0
			var rough := 0.0
			var k := 0
			for y in range(0, n, 32):
				for x in range(0, n, 32):
					var o := orm.get_pixel(x, y)
					metal += o.b
					rough += o.g
					k += 1
			metal /= k
			rough /= k
			print("texture %s %-5s : luminance %.3f saturation %.2f joints %.1f %% raccord x%.2f métal %.3f rugosité %.2f" % [res[0], part, mean, sat / cnt, jf * 100.0, seam, metal, rough])
			if res[0] == "hd":
				lum[part] = mean
			if seam > 3.0:
				fails.append("raccord visible de la texture %s %s (x%.1f)" % [res[0], part, seam])
			if metal > 0.03:
				fails.append("texture %s %s : métal non nul" % [res[0], part])
			if rough < 0.4 or rough > 0.95:
				fails.append("texture %s %s : rugosité moyenne %.2f hors de 0,4 à 0,95" % [res[0], part, rough])
			if sat / cnt > 0.30:
				fails.append("texture %s %s trop saturée (%.2f)" % [res[0], part, sat / cnt])
			if part == "wall" and (jf < 0.01 or jf > 0.09):
				fails.append("texture %s mur : part de joints %.1f %% hors de 1 à 9 %% (joints trop épais ou absents)" % [res[0], jf * 100.0])
	if lum.size() == 3 and not (lum["wall"] > lum["floor"] and lum["floor"] > lum["ceil"]):
		fails.append("ordre de luminosité mur > sol > plafond non respecté : %s" % [lum])


## Donjon de test Atlas Noir : thème gothic sur tous les niveaux intérieurs, plans et monstres inchangés, générateur normal intact (aucun thème gothic tiré au hasard).
func _check_atlas_test(fails: Array) -> void:
	if DungeonGenerator.THEMES.has("gothic"):
		fails.append("gothic ne doit pas faire partie des thèmes tirés au hasard")
	DungeonGenerator.atlas_only = true
	var cfg: Dictionary = DungeonGenerator.build_config(Data.config, 4, 15, 13, "normal", [])
	DungeonGenerator.atlas_only = false
	var without_theme := func(levels: Array) -> String:
		var copy: Array = []
		for lv in levels:
			var c: Dictionary = (lv as Dictionary).duplicate(true)
			c.erase("theme")
			copy.append(c)
		return JSON.stringify(copy)
	var before: String = without_theme.call(cfg.levels)
	var changed := DungeonGenerator.apply_gothic(cfg)
	var indoor := 0
	for lv in cfg.levels:
		if not bool(lv.get("outdoor", false)):
			indoor += 1
			if str(lv.theme) != "gothic":
				fails.append("donjon Atlas Noir : un niveau intérieur n'est pas en gothic")
	if before != without_theme.call(cfg.levels):
		fails.append("donjon Atlas Noir : le plan ou les monstres ont changé en passant en gothic")
	print("donjon Atlas Noir : %d niveaux intérieurs, %d passés en gothic (plans et monstres identiques)" % [indoor, changed])
	if indoor == 0:
		fails.append("donjon Atlas Noir : aucun niveau intérieur")


## Effets des monstres Atlas Noir : liseré froid seulement dans les thèmes qui le déclarent (gothic).
func _check_sprite_fx(fails: Array) -> void:
	if VisualFx.light_k("gothic", "sprite_rim_k", 0.0) <= 0.0:
		fails.append("gothic doit déclarer sprite_rim_k")
	for th in ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]:
		if VisualFx.light_k(th, "sprite_rim_k", 0.0) != 0.0:
			fails.append("le thème %s ne doit pas avoir de liseré de sprite" % th)
	print("effets des sprites : liseré réservé au gothic")

## Fumée des torches : plus discrète, plus lente et plus sombre dans le gothic, valeurs d'origine ailleurs, et un rig réutilisé d'un thème à l'autre
## retrouve exactement les réglages du thème servi.
func _check_smoke(fails: Array) -> void:
	var g := CPUParticles3D.new()
	var s := CPUParticles3D.new()
	TorchLayer._style_smoke(g, "gothic")
	TorchLayer._style_smoke(s, "stone")
	var alpha_g := 0.0
	var alpha_s := 0.0
	var lum_g := 0.0
	var lum_s := 0.0
	for i in g.color_ramp.get_point_count():
		alpha_g = maxf(alpha_g, g.color_ramp.get_color(i).a)
		lum_g = maxf(lum_g, g.color_ramp.get_color(i).get_luminance() * g.color_ramp.get_color(i).a)
	for i in s.color_ramp.get_point_count():
		alpha_s = maxf(alpha_s, s.color_ramp.get_color(i).a)
		lum_s = maxf(lum_s, s.color_ramp.get_color(i).get_luminance() * s.color_ramp.get_color(i).a)
	if alpha_g > alpha_s * 0.8:
		fails.append("fumée gothic pas assez transparente (%.2f contre %.2f, 80 %% au plus)" % [alpha_g, alpha_s])
	if lum_g > lum_s * 0.75:
		fails.append("fumée gothic pas assez sombre/discrète (%.3f contre %.3f)" % [lum_g, lum_s])
	if g.initial_velocity_max >= s.initial_velocity_max or g.scale_amount_max >= s.scale_amount_max or g.amount > s.amount:
		fails.append("fumée gothic pas plus lente, plus petite et moins fournie")
	var c0 := g.color_ramp.get_color(1)
	if not (c0.r > c0.g and c0.g > c0.b):
		fails.append("fumée gothic pas légèrement chaude (gris r > g > b)")
	if absf(s.initial_velocity_min - 0.20) > 1e-6 or absf(s.lifetime - 2.8) > 1e-6 or absf(alpha_s - TorchLayer.SMOKE_ALPHA) > 1e-6 or s.spread != 18.0:
		fails.append("la fumée des autres thèmes a changé")
	TorchLayer._style_smoke(g, "stone")      # rig réutilisé : plus rien du gothic
	if absf(g.initial_velocity_max - 0.34) > 1e-6 or g.angle_max != 0.0 or g.amount != s.amount:
		fails.append("un rig gothic réutilisé garde ses réglages de fumée")
	print("fumée des torches : gothic alpha %.2f / lum %.3f, autres alpha %.2f / lum %.3f" % [alpha_g, lum_g, alpha_s, lum_s])
	g.free()
	s.free()
