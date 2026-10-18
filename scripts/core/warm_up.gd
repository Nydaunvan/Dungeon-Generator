class_name WarmUp
extends RefCounted
## Préchauffage du rendu : au démarrage, une mini-scène (murs de chaque thème, portes, escalier, torches, fontaine, monstres,
## effets de sorts et de coups) est dessinée quelques images hors écran. Les shaders sont alors déjà compilés quand la partie
## s'ouvre : plus d'à-coup au chargement d'un donjon ni au premier sort lancé.

const SIZE := Vector2i(192, 128)
const THEMES := ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]

## Environnement de la partie (ténèbres + brouillard) : main.gd s'en sert aussi, pour que les variantes de shader soient les mêmes.
static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030201")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("40342a")
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("030201")
	env.fog_density = 0.035
	return env

## Niveau minimal qui contient tous les types d'éléments de décor : porte verrouillée, escalier, fontaine, piège, objet, monstre.
static func _mini_level(cfg: Dictionary, theme: String) -> Dictionary:
	var icon_m := "@icon:goblin"
	var icon_i := "@icon:chest"
	var levels: Array = cfg.get("levels", [])
	if not levels.is_empty():
		var l0: Dictionary = levels[0]
		var ms: Array = l0.get("monsters", [])
		if not ms.is_empty():
			icon_m = str(ms[0].get("icon", icon_m))
		for it in l0.get("items", []):
			if str(it.get("type", "")) == "chest" and str(it.get("icon", "")) != "":
				icon_i = str(it.icon)
				break
	return {
		"id": "warm", "name": "warm", "theme": theme,
		"mapRows": ["#######", "#.....#", "#..D..#", "#.....#", "#..S..#", "#######"],
		"doors": [{"id": "w_door", "x": 3, "y": 2, "locked": true}],
		"stairs": [{"id": "w_st", "x": 3, "y": 4, "locked": true, "action": {"type": "descend"}}],
		"items": [
			{"id": "w_fo", "type": "fountain", "x": 1, "y": 1},
			{"id": "w_tr", "type": "trap", "trapKind": "spikes", "x": 5, "y": 1},
			{"id": "w_tg", "type": "trap", "trapKind": "gas", "x": 1, "y": 3},
			{"id": "w_td", "type": "trap", "trapKind": "dart", "x": 1, "y": 2},
			{"id": "w_tp", "type": "trap", "trapKind": "pit", "x": 5, "y": 2},
			{"id": "w_tu", "type": "trap", "trapKind": "rune", "x": 5, "y": 4},
			{"id": "w_it", "type": "chest", "icon": icon_i, "x": 5, "y": 3},
		],
		"monsters": [{"id": "w_mo", "x": 3, "y": 1, "icon": icon_m}],
		"startX": 3, "startY": 3, "startDir": 0,
	}

## Préchauffage des icônes : toutes les images d'icônes, de portraits et de planches, ainsi que tous les symboles et emojis du texte du jeu,
## sont dessinés une fois hors écran pendant le chargement. Leur envoi à la carte graphique et la préparation des glyphes se font donc
## maintenant, et non au premier affichage d'une fenêtre (c'est ce qui faisait scintiller les icônes).
static func icons(host: Node) -> void:
	var tree := host.get_tree()
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 640)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)
	var grid := GridContainer.new()
	grid.columns = 25
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	vp.add_child(grid)
	var paths: Array = [IconResolver.MONSTER_SHEET, IconResolver.ITEM_SHEET]
	for d in ["icons", "portraits"]:
		for n in ResourceLoader.list_directory("res://assets/" + d):
			var name := String(n)
			for suf in [".import", ".remap"]:
				if name.ends_with(suf):
					name = name.trim_suffix(suf)
			var p := "res://assets/%s/%s" % [d, name]
			if name.get_extension().to_lower() in ["webp", "png"] and not paths.has(p):
				paths.append(p)
	for p in paths:
		var t := load(p) as Texture2D
		if t == null:
			continue
		var r := TextureRect.new()
		r.texture = t
		r.custom_minimum_size = Vector2(28, 28)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		grid.add_child(r)
	# symboles et emojis : tout ce qui est au-delà des lettres, dans les textes du jeu
	var seen := {}
	for f in ["res://data/lang/fr.json", "res://data/lang/en.json", "res://data/lang/help.fr.json", "res://data/lang/help.en.json"]:
		var text := FileAccess.get_file_as_string(f)
		for i in text.length():
			var c := text.unicode_at(i)
			if c >= 0x2190 and c != 0xFE0F and c != 0x200D:
				seen[c] = true
	var glyphs := ""
	for c in seen:
		glyphs += String.chr(int(c)) + " "
	var lab := Label.new()
	lab.theme = UiTheme.shared()
	lab.text = glyphs
	lab.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	lab.custom_minimum_size = Vector2(780, 0)
	lab.add_theme_font_size_override("font_size", 20)
	vp.add_child(lab)
	lab.position = Vector2(0, 420)
	for i in 3:
		await tree.process_frame
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.queue_free()

## Scripts d'effets dont les textures et maillages sont fabriqués à la demande (fonctions statiques sans argument qui les renvoient).
const FX_SCRIPTS := ["spell_fx_3d", "spell_fx_kit", "spell_fx_styles", "spell_fx_nature", "spell_fx_bard", "spell_fx_holy", "spell_fx_shadow", "spell_fx_physical", "spell_fx_fire", "spell_fx_ice", "spell_fx_arcane"]

## Fabrique d'avance les textures et maillages des effets de sorts (images procédurales calculées pixel par pixel), UNE par image :
## la préparation des effets n'a plus qu'à les trouver prêts, et l'écran de chargement ne se fige plus pour les calculer.
## (Sur un fil de travail, ces fonctions déclenchent des erreurs d'affichage du texte : elles restent sur le fil principal.)
static func pregen_effect_resources(tree: SceneTree) -> void:
	# la grande texture de runes (512², calcul pur) est la seule à bloquer ~90 ms : elle se calcule sur un fil de travail
	var rune := WorkerThreadPool.add_task(func(): load("res://scripts/dungeon/spell_fx_kit.gd")._rune_tex())
	await _pregen_others(tree)
	while not WorkerThreadPool.is_task_completed(rune):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(rune)

static func _pregen_others(tree: SceneTree) -> void:
	for n in FX_SCRIPTS:
		var scr := load("res://scripts/dungeon/%s.gd" % n) as GDScript
		if scr == null:
			continue
		for m in scr.get_script_method_list():
			var mn := str(m.get("name", ""))
			if int(m.get("flags", 0)) & METHOD_FLAG_STATIC == 0 or not (m.get("args", []) as Array).is_empty() or not mn.begins_with("_"):
				continue
			var ret: Dictionary = m.get("return", {})
			if int(ret.get("type", 0)) != TYPE_OBJECT:
				continue
			if mn == "_rune_tex":
				continue
			if str(ret.get("class_name", "")) in ["Texture2D", "ArrayMesh", "Mesh", "ImageTexture"]:
				var t0 := Time.get_ticks_usec()
				scr.call(mn)
				if OS.get_environment("LOAD_PROBE") != "":
					print("PREGEN ", n, ".", mn, " ", (Time.get_ticks_usec() - t0) / 1000, " ms")
				await tree.process_frame

static func run(host: Node, progress: Callable) -> void:
	var tree := host.get_tree()
	var cfg: Dictionary = Data.active()
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# même anticrénelage et mêmes effets d'environnement que la vue de jeu (voir Main._apply_quality / _apply_fx) : le moteur compile un pipeline
	# par format d'image (MSAA, occlusion ambiante…) ; chauffer avec d'autres réglages laissait la première apparition de chaque effet (rage…) compiler en plein jeu
	vp.msaa_3d = Settings.msaa_mode() as Viewport.MSAA
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var we := WorldEnvironment.new()
	we.environment = make_environment()
	VisualFx.apply_environment(we.environment, "stone", false)
	root.add_child(we)
	var rig := PlayerRig.new()
	root.add_child(rig)
	rig.camera.current = true
	var steps: Array = []

	# 1. couloir complet d'un thème : murs, sol, plafond, porte, escalier, torches, fontaine, objets, monstre
	var level := _mini_level(cfg, "stone")
	var grid := DungeonGrid.new(level)
	var view: LevelView = await LevelBuilder.build(level, grid, true)
	root.add_child(view)
	var poses := [[3, 3, 0], [3, 3, 2], [3, 3, 3], [3, 3, 1]]
	for p in poses:
		steps.append(func():
			rig.place(grid, p[0], p[1], p[2]))
	# 2. matériaux de chaque thème (la pierre a des normales et de l'occlusion : variante de shader à part)
	var mats_root := Node3D.new()
	root.add_child(mats_root)
	for th in THEMES:
		var tm: Dictionary = ThemeMaterials.for_theme(th)
		var gm := ProceduralTextures.grille_material(th)
		steps.append(func():
			for c in mats_root.get_children():
				c.queue_free()
			var i := 0
			for m in [tm.get("wall"), tm.get("floor"), tm.get("ceil"), gm]:
				var q := MeshInstance3D.new()
				q.mesh = QuadMesh.new()
				(q.mesh as QuadMesh).size = Vector2(1.2, 1.2)
				q.material_override = m
				q.position = rig.position + Vector3(-1.5 + float(i) * 1.0, 0.0, -2.5)   # devant la caméra (regard vers le nord)
				mats_root.add_child(q)
				i += 1
			rig.place(grid, 3, 3, 0))
	# 3. effets de sorts et de coups
	var styles := {}
	for sp in cfg.get("spells", []):
		var k := "%s|%s" % [sp.get("style", "arcane"), sp.get("mode", "damage")]
		if not styles.has(k):
			styles[k] = {"style": str(sp.get("style", "arcane")), "mode": str(sp.get("mode", "damage")), "status": str(sp.get("statusEffect", "")), "id": str(sp.get("id", ""))}
	for k in styles:
		var st: Dictionary = styles[k]
		steps.append(func():
			rig.place(grid, 3, 3, 0)
			var ctx := {"style": st.style, "mode": st.mode, "status": st.status, "targets": [], "ally": 0, "caster": 0}
			if SpellFx3D.has(st.id):
				SpellFx3D.cast(root, rig.camera, st.id, {})
			SpellFxStyles.cast_spell(root, rig.camera, st.id, {}, ctx))
	# effets avancés du catalogue (shaders, particules GPU, rubans, lentille) : compilés eux aussi avant la première partie
	for fxid in SpellFxLibrary.CATALOG:
		var fe: Dictionary = SpellFxLibrary.CATALOG[fxid]
		steps.append(func():
			rig.place(grid, 3, 3, 0)
			var fctx := {"style": str((fe.styles as Array)[0]), "mode": str((fe.modes as Array)[0]), "status": "", "targets": [], "ally": 0, "caster": 0,
				"fx": str(fxid), "fxTint": "", "fxPower": 1.0}
			SpellFxLibrary.cast(root, rig.camera, "warm_" + str(fxid), {}, fctx))
	# capacités de monstres (autre script, autre sens de tir) : une famille par école
	for school in ["fire", "ice", "nature", "physical"]:
		steps.append(func():
			rig.place(grid, 3, 3, 0)
			var mctx := {"style": school, "mode": "damage", "status": "", "targets": [], "ally": 1, "caster": 0, "fx": "", "fxTint": "", "fxPower": 1.0,
				"fromMonster": true, "victim": 1}
			SpellFxLibrary.cast(root, rig.camera, "warm_monster", {"pos": Vector3(0, 0.95, -4.0), "h": 1.7, "w": 1.0}, mctx))
	for kind in SpellFxStyles.ACTIONS:
		steps.append(func():
			SpellFxStyles.cast_action(root, rig.camera, kind, {}))
	# aura et entrée en rage des monstres (shader de flammes, braises, onde de choc) : compilées avant le premier combat
	steps.append(func():
		rig.place(grid, 3, 3, 0)
		var aura := CombatStage._make_rage_aura()
		root.add_child(aura)
		aura.position = rig.position + Vector3(0, 0.9, -3.0)
		CombatStage._size_rage(aura, 1.6)
		CombatStage._rage_burst(aura, true)
		tree.create_timer(2.5).timeout.connect(func(): if is_instance_valid(aura): aura.queue_free()))
	# effets persistants des statuts (monstres : mélange additif ; cartes des héros : mélange normal)
	for mix in [false, true]:
		steps.append(func():
			rig.place(grid, 3, 3, 0)
			var sa := StatusAura.new()
			sa.mix_mode = mix
			root.add_child(sa)
			sa.position = rig.position + Vector3(0, 0.9, -3.0)
			sa.ext = Vector2(1.2, 1.8)
			sa.set_looks(StatusAura.LOOKS.duplicate())
			tree.create_timer(2.0).timeout.connect(func(): if is_instance_valid(sa): sa.queue_free()))

	await tree.process_frame
	var n := maxi(steps.size(), 1)
	for i in steps.size():
		steps[i].call()
		await tree.process_frame
		await tree.process_frame     # deux images : le premier dessin compile, le second confirme
		progress.call(float(i + 1) / float(n))
	# plus de dessin hors écran ; les effets finissent de jouer d'eux-mêmes (en tâche de fond) avant que la mini-scène disparaisse
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_cleanup(tree, vp)

static func _cleanup(tree: SceneTree, vp: SubViewport) -> void:
	var t0 := Time.get_ticks_msec()
	while SpellFx3D.busy() and Time.get_ticks_msec() - t0 < 6000:
		await tree.create_timer(0.25).timeout
	await tree.create_timer(1.5).timeout     # reste de particules et de minuteries en cours
	if is_instance_valid(vp):
		vp.queue_free()
