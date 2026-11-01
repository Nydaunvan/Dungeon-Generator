extends Node3D
## Rendu de contrôle du thème gothic (captures PNG) : niveau d'essai avec couloir droit, angle, T, croix, impasses, porte, escalier et salle.
## Usage : godot --path . --rendering-method gl_compatibility res://tools/render_gothic.tscn -- theme=gothic kit=1 out=/chemin/dossier
## Outil de contrôle seulement : jamais chargé par le jeu.
var theme := "gothic"
var kit := true
var out := "/tmp"
var shots := [
	["01_couloir_droit", 1, 1, 1], ["02_angle", 8, 1, 1], ["03_croix", 10, 3, 2], ["04_porte", 9, 5, 3],
	["05_escalier", 6, 5, 3], ["06_T", 12, 5, 1], ["07_salle", 10, 6, 2], ["08_salle_milieu", 10, 10, 2],
	["09_impasse", 16, 5, 1], ["10_porte_proche", 8, 5, 3],
	# x, y en cases (fractions admises), yaw supplémentaire (degrés), montée de la herse (unités) : la porte est entre les cases 6 et 8 (x = 7)
	["11_porte_oblique", 8.5, 5.25, 3, 28.0, 0.0], ["12_porte_dans_la_case", 7.0, 5.0, 3, 0.0, 0.0],
	["13_herse_mi_course", 8.3, 5.0, 3, 0.0, 2.3], ["14_porte_vue_de_cote", 9.0, 5.0, 2, 0.0, 0.0],
	["15_escalier_oblique", 5.5, 5.25, 3, 25.0, 0.0],
	# V3 : vues rapprochées (hauteur des yeux du joueur)
	["19_monstre_face", 10.0, 5.0, 1, 0.0, 0.0], ["20_monstre_oblique", 9.2, 5.0, 1, 20.0, 0.0], ["21_monstre_proche", 10.45, 5.0, 1, 0.0, 0.0],
	["22_monstre_salle", 10.0, 8.7, 2, 0.0, 0.0], ["16_mur_proche", 5.0, 0.75, 0, 12.0, 0.0], ["17_arche_proche", 10.0, 3.9, 2, 0.0, 0.0], ["18_torche_proche", 9.0, 5.15, 2, 0.0, 0.0],
]
var only: PackedStringArray = []
var fx := true      # false = sans netteté de shader, sans liseré froid (référence « avant »)
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
				"mon": mon = kv[1]
				"fx": fx = kv[1] == "1"
	KitDecor.enabled = kit
	if not fx:
		AtlasSpriteMaterial.sharpen = 0.0
	var W := 20
	var H := 13
	var g: Array = []
	for y in H:
		var row: Array = []
		for x in W:
			row.append("#")
		g.append(row)
	for x in range(1, 11): g[1][x] = "."
	for y in range(1, 9): g[y][10] = "."
	for x in range(4, 18): g[5][x] = "."
	for y in range(5, 8): g[y][14] = "."
	for y in range(8, 12):
		for x in range(8, 13): g[y][x] = "."
	g[5][7] = "D"
	g[5][3] = "S"
	var rows: Array = []
	for r in g:
		rows.append("".join(r))
	var monsters: Array = []
	if mon != "":
		monsters.append({"id": "m_test", "name": "Test", "icon": "@icon:" + mon, "x": 11, "y": 5, "force": 5, "dex": 5, "con": 5, "resistPhys": 0, "resistMagic": 0, "xpReward": 1, "goldReward": 1})
		monsters.append({"id": "m_test2", "name": "Test2", "icon": "@icon:" + mon, "x": 10, "y": 10, "force": 5, "dex": 5, "con": 5, "resistPhys": 0, "resistMagic": 0, "xpReward": 1, "goldReward": 1})
	var lv := {"id": "render_test", "name": "Essai", "theme": theme, "mapRows": rows, "startX": 1, "startY": 1,
		"doors": [{"x": 7, "y": 5, "id": "door_a", "locked": true}], "stairs": [{"x": 3, "y": 5, "id": "st_a", "locked": false}],
		"items": [], "monsters": monsters, "lightAmbient": 1.1, "lightTorch": 1.4}
	var grid := DungeonGrid.new(lv)
	var view := await LevelBuilder.build(lv, grid)
	add_child(view)
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
	if not fx:
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
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out)
	print("kit: ", KitDecor.last_stats, " ; matériaux provisoires : ", ThemeMaterials.gothic_placeholder)
	var leaf_y := {}
	for s in shots:
		if not only.is_empty() and not only.has(str(s[0]).substr(0, 2)):
			continue
		cam.position = Vector3(s[1] * 4.0, 2.0, s[2] * 4.0)
		cam.rotation = Vector3(0, -PI * 0.5 * s[3] + deg_to_rad(float(s[4]) if s.size() > 4 else 0.0), 0)
		for id in view.doors:
			for leaf in view.doors[id]:
				if not leaf_y.has(leaf):
					leaf_y[leaf] = leaf.position.y
				leaf.position.y = leaf_y[leaf] + (float(s[5]) if s.size() > 5 else 0.0)
		for i in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out, theme + ("_kit" if kit else "_nokit"), s[0]])
	get_tree().quit()
