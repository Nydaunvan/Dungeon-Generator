extends Node
## Capture de l'étal du marchand ambulant (Merchant3D) et de son magicien, pour la maquette du village.
func _ready() -> void:
	get_viewport().transparent_bg = true
	var w := Node3D.new()
	add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.78, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	w.add_child(sun)
	var m := Merchant3D.new()
	m.build()
	w.add_child(m)
	var cam := Camera3D.new()
	cam.position = Vector3(1.2, 2.2, 8.5)
	cam.fov = 50
	w.add_child(cam)
	cam.look_at(Vector3(0, 1.7, 0))
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/stall.png")
	get_tree().quit()
