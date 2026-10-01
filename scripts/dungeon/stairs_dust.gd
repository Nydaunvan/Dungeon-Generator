class_name StairsDust
extends RefCounted
## pulseStairsEffect de l'original : 10 grains de poussière additifs qui montent (ou descendent) autour de la caméra en 650 ms.

static var _tex: Texture2D

static func _texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.902, 0.843, 0.706, 0.9), Color(0.784, 0.706, 0.549, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex

static func pulse(parent: Node, camera: Camera3D, going_up: bool) -> void:
	var base := camera.global_position
	for i in 10:
		var s := Sprite3D.new()
		s.texture = _texture()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.transparent = true
		s.no_depth_test = false
		s.pixel_size = 0.18 / 64.0
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		var ang := randf() * TAU
		var r := 0.15 + randf() * 0.35
		var y0 := base.y - 0.3 + randf() * 0.3
		parent.add_child(s)
		s.global_position = Vector3(base.x + cos(ang) * r, y0, base.z + sin(ang) * r)
		var vy := (1.0 if going_up else -1.0) * (0.5 + randf() * 0.4)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "global_position:y", y0 + vy, 0.65)
		tw.tween_property(s, "modulate:a", 0.0, 0.65)
		tw.chain().tween_callback(s.queue_free)
