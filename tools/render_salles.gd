extends Node3D
## Rendu de contrôle du thème gothic (captures PNG) : niveau d'essai avec couloir droit, angle, T, croix, impasses, porte, escalier et salle.
## Usage : godot --path . --rendering-method gl_compatibility res://tools/render_gothic.tscn -- theme=gothic kit=1 out=/chemin/dossier
## Outil de contrôle seulement : jamais chargé par le jeu.
var theme := "gothic"
var kit := true
var out := "/tmp"
var shots := [
	# nom, x, y (cases, fractions admises), direction (0 = -z, 1 = +x, 2 = +z, 3 = -x), lacet supplémentaire (°), 0, inclinaison (°), hauteur des yeux
	["01_autel_face", 3.2, 5.0, 1, 0.0, 0.0, 0.0],
	["02_autel_oblique", 3.4, 7.8, 1, -24.0, 0.0, -4.0],
	["03_autel_proche", 3.9, 5.0, 1, 0.0, 0.0, -10.0, 1.7],
	["04_autel_detail", 4.3, 5.0, 1, 0.0, 0.0, -22.0, 1.8],
	["05_candelabre", 4.9, 5.0, 1, -28.0, 0.0, -6.0, 1.5],
	["06_bibliotheque", 18.0, 5.0, 1, 0.0, 0.0, -6.0, 1.7],
	["07_commune", 25.0, 5.0, 1, 0.0, 0.0, 0.0],
	["08_tresor", 37.0, 5.0, 1, 0.0, 0.0, 0.0],
	["09_armes", 13.0, 15.0, 1, 0.0, 0.0, 0.0],
	["10_cellier", 25.0, 15.0, 1, 0.0, 0.0, 0.0],
	["11_repaire", 37.0, 15.0, 1, 0.0, 0.0, 0.0],
	["12_ruine", 49.0, 15.0, 1, 0.0, 0.0, 0.0],
	["13_humide", 49.0, 5.0, 1, 0.0, 0.0, 0.0],
	["14_marche", 61.0, 15.0, 1, 0.0, 0.0, 0.0],
	["15_sol_proche", 2.4, 5.0, 1, 0.0, 0.0, -50.0, 1.6],
]
var only: PackedStringArray = []
var lit := 0.0      # lumière d'inspection (outil seulement) : 0 = éclairage réel du jeu
var fx := true      # false = sans netteté de shader, sans liseré froid (référence « avant »)
var fxmode := ""    # "rim" = liseré seul, "sharp" = netteté seule (diagnostic)
var mon := ""      # id d'un monstre Atlas Noir à poser dans le couloir (ex. mon_veilleur_os) ; vide = aucun, les autres vues restent identiques

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"theme": theme = kv[1]
				"kit": kit = kv[1] == "1"
				"out": out = kv[1]
				"only": only = kv[1].split(",")
				"lit": lit = float(kv[1])
				"mon": mon = kv[1]
				"fx": fx = kv[1] == "1"
				"fxmode": fxmode = kv[1]
				"outline": AtlasSpriteMaterial.outline = float(kv[1])
	KitDecor.enabled = kit
	Settings.set_option("particles", 1.0)      # réglage « Particules » par défaut du jeu (le rendu d'essai ne lit pas les préférences)
	if not fx or fxmode == "rim":
		AtlasSpriteMaterial.sharpen = 0.0
	var W := 72
	var H := 22
	var g: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append("#")
		g.append(row)
	var styles := {}
	var specs := [[1, 1, 10, 9, "autel"], [12, 1, 9, 9, "bibliotheque"], [23, 1, 9, 9, "commune"], [34, 1, 9, 9, "tresor"], [45, 1, 9, 9, "humide"],
		[12, 11, 9, 9, "armes"], [23, 11, 9, 9, "cellier"], [34, 11, 9, 9, "repaire"], [45, 11, 9, 9, "ruine"], [56, 11, 9, 9, "marche"]]
	for sp in specs:
		for y in range(sp[1], sp[1] + sp[3]):
			for x in range(sp[0], sp[0] + sp[2]):
				g[y][x] = "."
		styles["%d,%d" % [sp[0], sp[1]]] = sp[4]
		if sp[0] > 1:
			g[sp[1] + 4][sp[0] - 1] = "."
	g[10][5] = "."
	var rows: Array = []
	for r in g:
		rows.append("".join(r))
	var monsters: Array = []
	if mon != "":
		monsters.append({"id": "m_test", "name": "Test", "icon": "@icon:" + mon, "x": 11, "y": 5, "force": 5, "dex": 5, "con": 5, "resistPhys": 0, "resistMagic": 0, "xpReward": 1, "goldReward": 1})
		monsters.append({"id": "m_test2", "name": "Test2", "icon": "@icon:" + mon, "x": 10, "y": 10, "force": 5, "dex": 5, "con": 5, "resistPhys": 0, "resistMagic": 0, "xpReward": 1, "goldReward": 1})
	var lv := {"id": "render_test", "name": "Essai", "theme": theme, "mapRows": rows, "startX": 2, "startY": 2,
		"doors": [], "stairs": [], "roomStyles": styles,
		"items": [], "monsters": monsters, "lightAmbient": 1.1, "lightTorch": 1.4}
	var grid := DungeonGrid.new(lv)
	var view := await LevelBuilder.build(lv, grid)
	add_child(view)
	for r in view.torches._rigs:      # le rendu logiciel est trop lent pour laisser la fumée se former : on avance sa simulation de quelques secondes
		r.smoke.preprocess = 4.0
		r.sparks.preprocess = 1.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("030201")
	env.fog_enabled = true
	env.fog_light_color = Color("030201")
	env.fog_density = 0.035
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("40342a")
	env.ambient_light_energy = 1.1
	VisualFx.apply_environment(env, theme, false)
	AtlasSpriteMaterial.apply_theme(theme)
	if not fx or fxmode == "sharp":
		RenderingServer.global_shader_parameter_set("atlas_rim_k", 0.0)
	env.ambient_light_energy = 1.1 * VisualFx.light_k(theme, "ambient_k")
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	view.torches.light_scale = 1.0
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 100.0
	add_child(cam)
	cam.current = true
	var torch := OmniLight3D.new()
	torch.light_color = VisualFx.light_color(theme, "player_color", Color("ffb060"))      # comme main.gd
	torch.light_energy = 2.0 * VisualFx.light_k(theme, "player_energy_k")
	torch.omni_range = LevelBuilder.CELL * 6.0 * VisualFx.light_k(theme, "player_range_k")
	torch.omni_attenuation = VisualFx.light_k(theme, "player_atten", 1.0)
	cam.add_child(torch)
	if lit > 0.0:
		var insp := OmniLight3D.new()
		insp.light_color = Color("c9c4d8")
		insp.light_energy = lit
		insp.omni_range = 12.0
		insp.position = Vector3(0, 1.0, 1.5)
		cam.add_child(insp)
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out)
	print("kit: ", KitDecor.last_stats, " ; matériaux provisoires : ", ThemeMaterials.gothic_placeholder)
	var leaf_y := {}
	for s in shots:
		if not only.is_empty() and not only.has(str(s[0]).substr(0, 2)):
			continue
		cam.position = Vector3(s[1] * 4.0, float(s[7]) if s.size() > 7 else 2.0, s[2] * 4.0)
		cam.rotation = Vector3(deg_to_rad(float(s[6]) if s.size() > 6 else 0.0), -PI * 0.5 * s[3] + deg_to_rad(float(s[4]) if s.size() > 4 else 0.0), 0)
		for id in view.doors:
			for leaf in view.doors[id]:
				if not leaf_y.has(leaf):
					leaf_y[leaf] = leaf.position.y
				leaf.position.y = leaf_y[leaf] + (float(s[5]) if s.size() > 5 else 0.0)
		for i in (160 if str(s[0]).begins_with("27") else 40):      # la fumée a besoin de temps pour s'installer
			await get_tree().process_frame
		if str(s[0]).begins_with("27"):
			for r in view.torches._rigs:
				if r.torch >= 0 and r.root.global_position.distance_to(cam.global_position) < 6.0:
					print("fumée : n=", r.smoke.amount, " émet=", r.smoke.emitting, " durée=", r.smoke.lifetime, " préchauffe=", r.smoke.preprocess, " vitesse=", r.smoke.speed_scale, " pos=", r.smoke.global_position, " vis=", r.smoke.is_visible_in_tree())
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out, theme + ("_kit" if kit else "_nokit"), s[0]])
	get_tree().quit()
