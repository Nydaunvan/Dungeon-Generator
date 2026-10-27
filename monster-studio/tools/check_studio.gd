extends Node
## Vérifie toute la chaîne sans IA : import d'image → silhouette de test → squelette (4 gabarits) → peau → animations → export .glb → relecture.
## Lancer : xvfb-run -a godot --path monster-studio res://tools/check_studio.tscn

var fails := 0

func check(label: String, cond: bool) -> void:
	print(("OK    " if cond else "ECHEC ") + label)
	if not cond:
		fails += 1

func _ready() -> void:
	await get_tree().process_frame
	# dossier de travail propre
	var d := DirAccess.open(Library.ROOT)
	if d != null:
		for sub in d.get_directories():
			var m := Monster.new()
			m.slug = sub
			Library.delete(m)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	# 1. import d'une image 2D (webp du jeu)
	var src := ProjectSettings.globalize_path("res://").path_join("../assets/monsters/boss_golem.webp")
	app.import_paths([src])
	await get_tree().process_frame
	check("image importée dans la bibliothèque", app.monsters.size() == 1 and app.monsters[0].has_source())
	var kinds := {"biped": "biped", "quadruped": "quadruped", "winged": "biped", "serpent": "serpent"}
	var n := 0
	for tpl in kinds:
		var m: Monster = app.cur
		if n > 0:
			var m2 := Library.import_image(src)
			app._reload_list(m2.slug)
			await get_tree().process_frame
			await get_tree().process_frame
			m = app.cur
		n += 1
		check("[%s] silhouette créée" % tpl, app.converter.use_test(m, kinds[tpl]))
		await app._load_model()
		check("[%s] modèle normalisé (hauteur 2, pieds à 0)" % tpl, not app.model.is_empty() and absf(app.model.aabb.size.y - 2.0) < 0.001 and absf(app.model.aabb.position.y) < 0.001)
		app.place_skeleton(tpl)
		var bones: Array = app.cur.rig.bones
		check("[%s] squelette placé (%d os)" % [tpl, bones.size()], bones.size() >= 8)
		# un parent précède toujours son enfant
		var seen := {}
		var order_ok := true
		for b in bones:
			if str(b.parent) != "" and not seen.has(str(b.parent)):
				order_ok = false
			seen[str(b.name)] = true
		check("[%s] ordre des os valide" % tpl, order_ok)
		await app.compute_skin()
		check("[%s] poids calculés" % tpl, not app.weights.is_empty())
		var w: PackedFloat32Array = app.weights[0].weights
		var wb: PackedInt32Array = app.weights[0].bones
		var sums_ok := true
		var in_range := true
		for v in range(0, w.size(), 4):
			var s := w[v] + w[v + 1] + w[v + 2] + w[v + 3]
			if absf(s - 1.0) > 0.001:
				sums_ok = false
		for x in wb:
			if x < 0 or x >= bones.size():
				in_range = false
		check("[%s] poids normalisés à 1 et indices d'os valides" % tpl, sums_ok and in_range)
		# animations : toutes présentes, chemins valides, mouvement réel
		var pl: AnimationPlayer = app.viewer.player
		check("[%s] lecteur d'animation présent" % tpl, pl != null)
		if pl == null:
			continue
		var all_names := true
		for an in AnimPresets.NAMES:
			if not pl.has_animation(an):
				all_names = false
		check("[%s] 5 animations" % tpl, all_names)
		var paths_ok := true
		for an in AnimPresets.NAMES:
			var a := pl.get_animation(an)
			for tr in a.get_track_count():
				var np := a.track_get_path(tr)
				if app.viewer.skeleton.find_bone(str(np).get_slice(":", 1)) < 0:
					paths_ok = false
		check("[%s] toutes les pistes visent un os existant" % tpl, paths_ok)
		var sk: Skeleton3D = app.viewer.skeleton
		var tip := sk.find_bone("head" if sk.find_bone("head") >= 0 else sk.get_bone_name(sk.get_bone_count() - 1))
		pl.play("attack")
		pl.seek(0.0, true)
		var p0 := sk.get_bone_global_pose(tip).origin
		pl.seek(0.4, true)
		var p1 := sk.get_bone_global_pose(tip).origin
		check("[%s] l'attaque déplace réellement l'os %s (%.2f)" % [tpl, sk.get_bone_name(tip), p0.distance_to(p1)], p0.distance_to(p1) > 0.02)
		pl.stop()
		# les sommets suivent les os : un sommet proche de l'os bougé se déplace
		var mi: MeshInstance3D = sk.get_child(0)
		pl.play("walk")
		pl.seek(0.25, true)
		await get_tree().process_frame
		var aabb_walk := mi.get_aabb()
		check("[%s] maillage lié au squelette (peau + skin)" % tpl, mi.skin != null and mi.get_skeleton_path() != NodePath())
		pl.stop()
		# 6. export .glb et relecture
		var out := "/tmp/studio_%s.glb" % tpl
		var res: String = await app.export_current(out)
		check("[%s] export .glb" % tpl, res == out and FileAccess.file_exists(out))
		var back := ModelIO.load_scene(out)
		check("[%s] .glb relisible" % tpl, back != null)
		if back != null:
			var sk2: Skeleton3D = null
			var ap2: AnimationPlayer = null
			var skinned := false
			var stack: Array = [back]
			while not stack.is_empty():
				var nd: Node = stack.pop_back()
				if nd is Skeleton3D:
					sk2 = nd
				if nd is AnimationPlayer:
					ap2 = nd
				if nd is MeshInstance3D and (nd as MeshInstance3D).skin != null:
					skinned = true
				stack.append_array(nd.get_children())
			check("[%s] squelette relu : %d os (attendu %d)" % [tpl, sk2.get_bone_count() if sk2 else -1, bones.size()], sk2 != null and sk2.get_bone_count() == bones.size())
			check("[%s] animations relues : %s" % [tpl, str(ap2.get_animation_list()) if ap2 else "aucune"], ap2 != null and ap2.has_animation("walk") and ap2.has_animation("death"))
			check("[%s] maillage skinné relu" % tpl, skinned)
			back.free()
	# couleurs de sommets (sortie de TripoSR) : le matériau doit les utiliser, même si le .glb fournit un matériau blanc
	var cst := SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	cst.set_color(Color(0.9, 0.2, 0.1))
	cst.add_vertex(Vector3(0, 0, 0))
	cst.set_color(Color(0.1, 0.9, 0.2))
	cst.add_vertex(Vector3(1, 0, 0))
	cst.set_color(Color(0.1, 0.2, 0.9))
	cst.add_vertex(Vector3(0, 2, 0))
	var cr := Node3D.new()
	var cmi := MeshInstance3D.new()
	cmi.mesh = cst.commit()
	cmi.material_override = StandardMaterial3D.new()
	cr.add_child(cmi)
	ModelIO.save_glb(cr, "/tmp/studio_colors.glb")
	cr.free()
	var cm := ModelIO.load_normalized("/tmp/studio_colors.glb")
	var cmat: Material = cm.surfaces[0].material if not cm.is_empty() else null
	check("couleurs de sommets conservées et utilisées par le matériau", cm.has("surfaces") and cm.surfaces[0].arrays[Mesh.ARRAY_COLOR] != null and cmat is BaseMaterial3D and (cmat as BaseMaterial3D).vertex_color_use_as_albedo)
	# orientation : un demi-tour inverse l'avant et le modèle reste normalisé ; le squelette est à replacer
	var before: AABB = app.model.aabb
	app._turn(Vector3(90, 0, 0))
	await get_tree().create_timer(0.5).timeout
	check("rotation du modèle : boîte changée, squelette effacé", app.model.aabb.size.is_equal_approx(before.size) == false and not app.cur.has_rig() and absf(app.model.aabb.size.y - 2.0) < 0.001)
	app._turn(Vector3(-90, 0, 0))
	await get_tree().create_timer(0.5).timeout
	check("rotation inverse : retour à l'orientation d'origine", app.cur.orient == Vector3.ZERO and app.model.aabb.size.is_equal_approx(before.size))
	app.place_skeleton("serpent")
	await app.compute_skin()
	# retouche : une clé ajoutée remplace la piste de l'os
	var sk3: Skeleton3D = app.viewer.skeleton
	app._cur_anim = "idle"
	app.anim_bone_opt.select(app.anim_bone_opt.item_count - 1)
	app.viewer.player.play("idle")
	app.viewer.player.seek(0.5, true)
	app.rot_sliders[0].value = 33.0
	app._insert_key()
	var bn: String = app._anim_bone_name()
	check("clé de pose enregistrée (%s)" % bn, app.cur.anim_keys.has("idle") and (app.cur.anim_keys.idle as Dictionary).has(bn))
	var reloaded := Monster.new()
	reloaded.slug = app.cur.slug
	reloaded.load_meta()
	check("clés conservées dans rig.json", reloaded.anim_keys.has("idle") and reloaded.has_rig())
	print("RESULTAT Monster Studio -> ", "OK" if fails == 0 else "%d ECHEC(S)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
