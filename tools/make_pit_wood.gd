extends SceneTree
## Fabrique les textures du bois des planches de la fosse (TrapPit) : assets/misc/pit_wood_albedo.jpg et pit_wood_normal.png (1024 x 1024).
## godot --headless --path . --script res://tools/make_pit_wood.gd
## Veinage le long de l'axe vertical de l'image, cernes ondulés, pores, deux nœuds ; la carte de normales se déduit du relief (bords raccordés).

func _init() -> void:
	var n := 1024
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.seed = 4242
	var h := PackedFloat32Array()
	h.resize(n * n)
	var col := PackedFloat32Array()
	col.resize(n * n)
	var knots := [Vector2(0.28, 0.35), Vector2(0.72, 0.78)]
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var warp := noise.get_noise_2d(u * 3.0, v * 0.6) * 0.5
			var kd := 0.0
			for k in knots:
				var d := Vector2(u - k.x, (v - k.y) * 0.5).length()
				kd += clampf(1.0 - d / 0.07, 0.0, 1.0)
				warp += clampf(1.0 - d / 0.2, 0.0, 1.0) * 0.12 * sin(atan2(v - k.y, u - k.x) * 2.0)
			var ring := sin((u + warp) * 46.0) * 0.5 + 0.5
			ring = pow(ring, 1.7)
			var pores := noise.get_noise_2d(u * 140.0, v * 6.0) * 0.5 + 0.5
			var fine := noise.get_noise_2d(u * 380.0, v * 20.0)
			h[y * n + x] = ring * 0.55 + pores * 0.25 + fine * 0.08 - kd * 0.5
			col[y * n + x] = clampf(0.62 + ring * 0.3 - pores * 0.16 - kd * 0.38 + fine * 0.05, 0.0, 1.0)
	var cb := PackedByteArray()
	cb.resize(n * n * 3)
	var nb := PackedByteArray()
	nb.resize(n * n * 3)
	var light := Color(0.56, 0.43, 0.30)
	var dark := Color(0.27, 0.19, 0.12)
	for y in n:
		for x in n:
			var i := y * n + x
			var c := dark.lerp(light, col[i])
			cb[i * 3] = int(c.r * 255.0)
			cb[i * 3 + 1] = int(c.g * 255.0)
			cb[i * 3 + 2] = int(c.b * 255.0)
			var hl := h[y * n + (x + n - 1) % n]
			var hr := h[y * n + (x + 1) % n]
			var hu := h[((y + n - 1) % n) * n + x]
			var hd := h[((y + 1) % n) * n + x]
			var nv := Vector3((hl - hr) * 2.2, (hu - hd) * 2.2, 1.0).normalized()
			nb[i * 3] = int((nv.x * 0.5 + 0.5) * 255.0)
			nb[i * 3 + 1] = int((nv.y * 0.5 + 0.5) * 255.0)
			nb[i * 3 + 2] = int((nv.z * 0.5 + 0.5) * 255.0)
	Image.create_from_data(n, n, false, Image.FORMAT_RGB8, cb).save_jpg("res://assets/misc/pit_wood_albedo.jpg", 0.92)
	Image.create_from_data(n, n, false, Image.FORMAT_RGB8, nb).save_png("res://assets/misc/pit_wood_normal.png")
	print("textures du bois écrites")
	quit()
