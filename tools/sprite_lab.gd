extends SceneTree
## Banc d'essai de netteté d'un sprite : un quad face à une caméra orthogonale, sans lumière ni effet, à une échelle texel/pixel donnée.
## xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --script res://tools/sprite_lab.gd -- tex=res://assets/monsters/mon_veilleur_m01.webp ratio=0.384 filter=aniso out=/tmp/lab.png [bias=-1] [aa=2]
func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	root.size = Vector2i(1600, 900)
	await process_frame
	root.msaa_3d = Viewport.MSAA_2X if int(args.get("aa", 0)) == 2 else Viewport.MSAA_DISABLED
	root.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
	var tex: Texture2D = load(str(args.tex))
	if str(args.get("mips", "")) == "lanczos":            # chaîne de mipmaps recalculée au runtime avec un vrai filtre (au lieu du filtre boîte de l'import)
		tex = _lanczos_mips(tex.get_image())
	var side_px := float(tex.get_width()) * float(args.get("ratio", 0.384))       # côté du quad à l'écran, en pixels
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0                                                                   # 9 unités sur 900 px : 100 px par unité
	cam.position = Vector3(0, 0, 5)
	root.add_child(cam)
	var q := QuadMesh.new()
	q.size = Vector2.ONE * side_px / 100.0
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var shader := Shader.new()
	var b := float(args.get("bias", 0.0))
	shader.code = "shader_type spatial; render_mode unshaded, blend_mix, cull_disabled; uniform sampler2D t : source_color, filter_linear_mipmap_anisotropic; uniform float bias = 0.0; void fragment(){ vec4 c = texture(t, UV, bias); ALBEDO = c.rgb; ALPHA = c.a; }"
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("t", tex)
	m.set_shader_parameter("bias", b)
	mi.material_override = m
	root.add_child(mi)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.16, 0.19)
	env.environment = e
	root.add_child(env)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(str(args.get("out", "/tmp/lab.png")))
	quit()

## Image avec une chaîne de mipmaps où chaque niveau est un sous-échantillonnage Lanczos du niveau précédent.
static func _lanczos_mips(src: Image) -> ImageTexture:
	var base := src.duplicate() as Image
	if base.is_compressed():
		base.decompress()
	base.clear_mipmaps()                                   # l'image d'un CompressedTexture2D porte déjà ses mipmaps : on repart du niveau 0
	base.convert(Image.FORMAT_RGBA8)
	var data := PackedByteArray()
	var cur := base
	var w := base.get_width()
	var h := base.get_height()
	data.append_array(cur.get_data())
	while w > 1 or h > 1:
		w = maxi(1, w >> 1)
		h = maxi(1, h >> 1)
		var nx := cur.duplicate() as Image
		nx.resize(w, h, Image.INTERPOLATE_LANCZOS)
		data.append_array(nx.get_data())
		cur = nx
	var out := Image.create_from_data(base.get_width(), base.get_height(), true, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(out)
