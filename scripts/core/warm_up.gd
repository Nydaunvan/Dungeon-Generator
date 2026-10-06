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
			{"id": "w_it", "type": "chest", "icon": icon_i, "x": 5, "y": 3},
		],
		"monsters": [{"id": "w_mo", "x": 3, "y": 1, "icon": icon_m}],
		"startX": 3, "startY": 3, "startDir": 0,
	}

static func run(host: Node, progress: Callable) -> void:
	var tree := host.get_tree()
	var cfg: Dictionary = Data.active()
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var we := WorldEnvironment.new()
	we.environment = make_environment()
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
	for kind in SpellFxStyles.ACTIONS:
		steps.append(func():
			SpellFxStyles.cast_action(root, rig.camera, kind, {}))

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
