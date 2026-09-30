class_name FrameBox
extends StyleBox
## Cadre « fer et bois rivetés » de l'original (border-image du CSS : image 120x120, découpe 40, bordure 18 px).
## Dessine : ombre intérieure, fond (teinte + saleté), puis les 8 morceaux de la bordure à la taille voulue.

const SRC := "res://assets/ui/orig/fr.png"
const SRC_PX := 480.0          # image rendue à x4 de l'SVG 120x120
static var _base: Image
static var _cache: Dictionary = {}     # taille réelle de la bordure -> ImageTexture
static var _grime: Texture2D
static var _scratch: Texture2D
static var _shade: Texture2D

var border_css: float = 18.0      # épaisseur de la bordure en px CSS de l'original
var fill: Color = Color("1d1813")
var use_grime: bool = true
var inner_shadow: float = 22.0    # px CSS (0 = aucune)
var inner_alpha: float = 0.8
var pad_css := Vector4(10, 10, 12, 10)   # padding CSS (gauche, haut, droite, bas)
var _tex: Texture2D
var _b: float = 18.0               # bordure en px de conception

func _init(border: float = 18.0, padding: Vector4 = Vector4(10, 10, 12, 10), fill_color: Color = Color("1d1813")) -> void:
	border_css = border
	pad_css = padding
	fill = fill_color
	UiMetrics.register(self)
	rescale()

func rescale() -> void:
	_b = UiMetrics.css(border_css)
	var real := maxi(4, roundi(_b * UiMetrics.s))
	if not _cache.has(real):
		if _base == null:
			_base = (load(SRC) as Texture2D).get_image()
		var img := _base.duplicate() as Image
		img.resize(real * 3, real * 3, Image.INTERPOLATE_LANCZOS)
		_cache[real] = ImageTexture.create_from_image(img)
	_tex = _cache[real]
	content_margin_left = _b + UiMetrics.css(pad_css.x)
	content_margin_top = _b + UiMetrics.css(pad_css.y)
	content_margin_right = _b + UiMetrics.css(pad_css.z)
	content_margin_bottom = _b + UiMetrics.css(pad_css.w)
	emit_changed()

static var _shade_rev: Texture2D

static func _shade_tex(rev: bool = false) -> Texture2D:
	if _shade == null:
		var img := Image.create(64, 4, false, Image.FORMAT_RGBA8)
		var img2 := Image.create(64, 4, false, Image.FORMAT_RGBA8)
		for x in 64:
			var a := pow(1.0 - float(x) / 63.0, 1.6)
			for y in 4:
				img.set_pixel(x, y, Color(0, 0, 0, a))
				img2.set_pixel(63 - x, y, Color(0, 0, 0, a))
		_shade = ImageTexture.create_from_image(img)
		_shade_rev = ImageTexture.create_from_image(img2)
	return _shade_rev if rev else _shade

func _draw(ci: RID, rect: Rect2) -> void:
	var b := _b
	var inner := Rect2(rect.position + Vector2(b, b), rect.size - Vector2(b, b) * 2.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		RenderingServer.canvas_item_add_rect(ci, inner, fill)
		if use_grime:
			if _grime == null:
				_grime = load("res://assets/ui/orig/grime.png")
			RenderingServer.canvas_item_add_texture_rect(ci, inner, _grime.get_rid(), true, Color(1, 1, 1, 1))
		# léger éclaircissement en haut : linear-gradient(rgba(255,230,190,.04), transparent 40%)
		var hh := inner.size.y * 0.4
		for i in 10:
			RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x, inner.position.y + hh * i / 10.0, inner.size.x, hh / 10.0 + 0.5), Color(1, 0.9, 0.75, 0.035 * (1.0 - float(i) / 10.0)))
		if inner_shadow > 0.0:
			# ombre intérieure (inset 0 0 22px rgba(0,0,0,.8)) : dégradé doux sur les quatre bords
			var sh := minf(UiMetrics.css(inner_shadow), minf(inner.size.x, inner.size.y) * 0.5)
			var n := 14
			for i in n:
				var a := inner_alpha * 0.62 * pow(1.0 - float(i) / float(n), 2.2)
				var t0 := sh * i / float(n)
				var st := sh / float(n) + 0.5
				var col := Color(0, 0, 0, a)
				RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + t0, inner.position.y + t0, st, inner.size.y - t0 * 2.0), col)
				RenderingServer.canvas_item_add_rect(ci, Rect2(inner.end.x - t0 - st, inner.position.y + t0, st, inner.size.y - t0 * 2.0), col)
				RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + t0, inner.position.y + t0, inner.size.x - t0 * 2.0, st), col)
				RenderingServer.canvas_item_add_rect(ci, Rect2(inner.position.x + t0, inner.end.y - t0 - st, inner.size.x - t0 * 2.0, st), col)
	# bordure : 4 coins + 4 côtés étirés (le centre n'est pas dessiné)
	var tw := _tex.get_width() / 3.0
	var r := rect
	var id := _tex.get_rid()
	var P := r.position
	var S := r.size
	var w := Color.WHITE
	var ci_add := func(dst: Rect2, src: Rect2):
		RenderingServer.canvas_item_add_texture_rect_region(ci, dst, id, src, w)
	ci_add.call(Rect2(P, Vector2(b, b)), Rect2(0, 0, tw, tw))
	ci_add.call(Rect2(P + Vector2(S.x - b, 0), Vector2(b, b)), Rect2(tw * 2, 0, tw, tw))
	ci_add.call(Rect2(P + Vector2(0, S.y - b), Vector2(b, b)), Rect2(0, tw * 2, tw, tw))
	ci_add.call(Rect2(P + S - Vector2(b, b), Vector2(b, b)), Rect2(tw * 2, tw * 2, tw, tw))
	ci_add.call(Rect2(P + Vector2(b, 0), Vector2(S.x - b * 2, b)), Rect2(tw, 0, tw, tw))
	ci_add.call(Rect2(P + Vector2(b, S.y - b), Vector2(S.x - b * 2, b)), Rect2(tw, tw * 2, tw, tw))
	ci_add.call(Rect2(P + Vector2(0, b), Vector2(b, S.y - b * 2)), Rect2(0, tw, tw, tw))
	ci_add.call(Rect2(P + Vector2(S.x - b, b), Vector2(b, S.y - b * 2)), Rect2(tw * 2, tw, tw, tw))

func _get_minimum_size() -> Vector2:
	return Vector2(content_margin_left + content_margin_right, content_margin_top + content_margin_bottom)
