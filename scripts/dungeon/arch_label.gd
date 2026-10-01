class_name ArchLabel
extends Control
## Panneau suspendu par deux chaînes au-dessus des arches du village (makeArchLabelSprite de l'original), dessiné une fois
## dans un SubViewport transparent puis affiché en sprite billboard.

const W := 512
const H := 260
var text := ""
var accent := Color.WHITE

static func make(text_: String, accent_: Color) -> Sprite3D:
	var vp := SubViewport.new()
	vp.size = Vector2i(W * 2, H * 2)   # rendu 2x pour la netteté
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	var lab := ArchLabel.new()
	lab.text = text_
	lab.accent = accent_
	lab.scale = Vector2(2, 2)
	lab.size = Vector2(W, H)
	vp.add_child(lab)
	var sp := Sprite3D.new()
	sp.add_child(vp)
	sp.texture = vp.get_texture()
	sp.pixel_size = 2.0 / float(W * 2)
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.transparent = true
	sp.shaded = false
	sp.double_sided = true
	sp.no_depth_test = false
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.centered = false
	sp.offset = Vector2(-W, -0.0)   # ancre en haut au centre (en pixels de texture, 2x)
	return sp

func _draw() -> void:
	# chaînes
	for cx in [150.0, 362.0]:
		var y := 8.0
		while y < 78.0:
			var pts := PackedVector2Array()
			for i in 25:
				var a := TAU * float(i) / 24.0
				pts.append(Vector2(cx + cos(a) * 6.0, y + sin(a) * 9.0))
			draw_polyline(pts, Color("4a4a4a"), 2.0, true)
			y += 16.0
	var sx := 48.0
	var sy := 78.0
	var sw := W - 96.0
	var sh := 150.0
	# plaque : dégradé vertical, coins 14 px, filet #5a3f22 de 6 px
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color("b08350")
	edge.set_corner_radius_all(14)
	edge.border_color = Color("5a3f22")
	edge.set_border_width_all(6)
	edge.anti_aliasing = true
	draw_style_box(edge, Rect2(sx - 3, sy - 3, sw + 6, sh + 6))
	var grad := Gradient.new()
	grad.set_color(0, Color("c8a06a"))
	grad.set_color(1, Color("9a7040"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var inner := Rect2(sx + 3, sy + 3, sw - 6, sh - 6)
	var clip := StyleBoxFlat.new()
	clip.bg_color = Color(1, 1, 1, 0)
	draw_texture_rect(gt, inner, false)
	# rivets
	for p in [Vector2(sx + 16, sy + 16), Vector2(sx + sw - 16, sy + 16), Vector2(sx + 16, sy + sh - 16), Vector2(sx + sw - 16, sy + sh - 16)]:
		draw_circle(p, 7.0, Color("4a4a4a"))
	# texte : taille réduite jusqu'à tenir dans la plaque
	var font: Font = UiTheme.font(UiTheme.F_TITLE_BOLD)
	var fs := 54
	var maxw := sw - 40.0
	while fs > 18 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 2
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc := font.get_ascent(fs)
	var base_y := sy + sh * 0.5 + 4.0 + (asc - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(W * 0.5 - ts.x * 0.5, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1a1208"))
	draw_rect(Rect2(sx + 16, sy + sh - 14, sw - 32, 5), accent)
