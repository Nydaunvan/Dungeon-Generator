class_name UiMetrics
extends RefCounted
## Échelle de l'interface : 1 px CSS de l'original = 1 px réel à l'écran (bureau), exprimé en px de conception.
## `s` = pixels réels par pixel de conception (fenêtre / zone visible). Les cadres en dépendent.

static var s: float = 1.0
static var portrait: bool = false
static var _boxes: Array = []

static func update(node: Node) -> bool:
	var win := node.get_window()
	var vr := node.get_viewport().get_visible_rect().size
	if vr.x <= 0.0:
		return false
	var ns := float(win.size.x) / vr.x
	var np := win.size.x < win.size.y * 1.05
	var changed := not is_equal_approx(ns, s) or np != portrait
	s = ns
	portrait = np
	if changed:
		for b in _boxes:
			if is_instance_valid(b):
				b.rescale()
	return changed

## px CSS de l'original -> px de conception. Sur mobile (portrait) l'original réduit déjà ses tailles : on garde ses valeurs mobiles.
static func css(px: float) -> float:
	return px if not portrait else px * 1.15

static func register(b) -> void:
	_boxes.append(b)

static var _tcache: Dictionary = {}

## Texture d'`assets/ui/orig` ramenée exactement à la taille réelle voulue (nette, sans crénelage). `size_css` en px CSS.
static func tex(name: String, size_css: Vector2) -> Texture2D:
	var d := design_size(size_css)
	var real := Vector2i(maxi(1, roundi(d.x * s)), maxi(1, roundi(d.y * s)))
	var key := "%s|%d|%d" % [name, real.x, real.y]
	if not _tcache.has(key):
		var src := load("res://assets/ui/orig/%s.png" % name) as Texture2D
		var img := src.get_image()
		img.resize(real.x, real.y, Image.INTERPOLATE_LANCZOS)
		_tcache[key] = ImageTexture.create_from_image(img)
	return _tcache[key]

## Même chose mais renvoie aussi la taille de dessin en px de conception.
static func design_size(size_css: Vector2) -> Vector2:
	return Vector2(css(size_css.x), css(size_css.y))

## rem de l'original (html{font-size:18px}) -> px de conception
static func rem(v: float) -> float:
	return css(18.0 * v)
