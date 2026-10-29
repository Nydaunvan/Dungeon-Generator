extends SceneTree
## Capture de « Lumière sacrée » (effet holy_light) au-dessus d'un sol visible : le pilier doit toucher le sol.
## Lancer : xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/shot_holy_light.gd -- out=/tmp/holy
func _init() -> void:
	root.size = Vector2i(960, 600)
	await process_frame
	var out := "/tmp/holy"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var lib = load("res://scripts/dungeon/spell_fx_library.gd")
	var vf = load("res://scripts/core/visual_fx.gd")
	vf.force_forward = true
	root.get_node("Settings").set_preset("ultra")
	var host := Node3D.new()
	root.add_child(host)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.02, 0.02, 0.03)
	host.add_child(env)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.2, 0.18)
	floor_mi.material_override = fm
	host.add_child(floor_mi)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 20, 0)
	dl.light_energy = 0.5
	host.add_child(dl)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 0)
	cam.fov = 70.0
	host.add_child(cam)
	cam.current = true
	var target := {"pos": Vector3(0, 0.95, -4.0), "h": 1.7, "w": 1.0}
	lib.cast(host, cam, "shot", target, {"id": "spell_holy1", "style": "holy", "mode": "damage", "fx": "holy_light", "fxTint": "", "fxPower": 1.0, "targets": [], "ally": 0, "caster": 0})
	for i in 3:
		await create_timer(0.3).timeout
		await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [out, i])
	quit()
