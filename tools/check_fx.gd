extends SceneTree
## Parcours des effets visuels Forward+ (options fx_*) : environnement, matériaux (reflets, relief), ombres des torches, décalques de sang.
## Aucune erreur de script attendue ; les valeurs d'environnement sont vérifiées. Rendu OpenGL : les effets sont configurés mais non visibles.
## Usage : xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/check_fx.gd
func _init() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var vf = load("res://scripts/core/visual_fx.gd")
	vf.force_forward = true
	var st = root.get_node("Settings")
	st.set_preset("ultra")
	var bad := 0
	var env := Environment.new()
	for th in ["stone", "dirt", "damp", "ruins", "ice", "lava", "temple"]:
		vf.apply_environment(env, th, false)
		if not (env.adjustment_enabled and env.glow_enabled and env.ssao_enabled):
			bad += 1
			print("ÉCHEC : effets d'environnement manquants pour ", th)
		if (th in ["damp", "ice", "lava"]) != env.ssr_enabled:
			bad += 1
			print("ÉCHEC : reflets attendus seulement sur sols humides : ", th)
	vf.apply_environment(env, "stone", true)
	if env.ssao_enabled or env.adjustment_enabled:
		bad += 1
		print("ÉCHEC : le village ne doit pas avoir d'effets de donjon")
	st.set_preset("low")
	vf.apply_environment(env, "stone", false)
	if env.adjustment_enabled or env.glow_enabled or env.ssao_enabled:
		bad += 1
		print("ÉCHEC : le niveau Faible ne doit avoir aucun effet")
	st.set_preset("ultra")
	var tm = load("res://scripts/dungeon/theme_materials.gd")
	for th in ["stone", "ice", "lava"]:
		var mats: Dictionary = tm.for_theme(th)
		var w: StandardMaterial3D = mats["wall"]
		print(th, " relief=", w.heightmap_enabled, " rugosité sol=", (mats["floor"] as StandardMaterial3D).roughness)
		if not w.heightmap_enabled or w.heightmap_texture == null:
			bad += 1
			print("ÉCHEC : relief absent pour ", th)
	for v in 3:
		var t: Texture2D = vf.blood_texture(v)
		if t == null or t.get_width() != 128:
			bad += 1
			print("ÉCHEC : texture de sang ", v)
	# partie réelle : décalque posé à la mort d'un monstre
	var data = root.get_node("Data")
	var cfg: Dictionary = load("res://scripts/rules/dungeon_generator.gd").build_config(data.original_config, 3, 13, 11, "normal", [], 5, 1)
	data.launch(cfg, "random")
	await create_timer(6.0).timeout
	var m = current_scene
	for mo in get_nodes_in_group("modal"):
		mo.queue_free()
	var ents = m.ctrl.view.entities
	var n0: int = ents._blood_nodes.size()
	ents.add_blood(Vector2i(m.rig.gx, m.rig.gy))
	if ents._blood_nodes.size() != n0 + 1:
		bad += 1
		print("ÉCHEC : décalque non créé")
	await create_timer(1.0).timeout
	print("ombre de la torche du groupe : ", m.rig.torch.shadow_enabled)
	if not m.rig.torch.shadow_enabled:
		bad += 1
		print("ÉCHEC : ombre de la torche du groupe attendue en Ultra")
	print("anomalies : ", bad)
	quit(1 if bad > 0 else 0)
