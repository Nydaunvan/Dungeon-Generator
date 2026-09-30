class_name SvgArt
extends RefCounted
## Dessins SVG de l'interface d'origine (chaîne, crâne, médaillons…), rastérisés à la demande
## à la résolution voulue : nets sur tous les écrans, sans image intermédiaire.

static var _svgs: Dictionary = {}
static var _cache: Dictionary = {}

static func _load() -> void:
	if not _svgs.is_empty():
		return
	var f := FileAccess.open("res://data/ui_svgs.json", FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_svgs = d

static func svg(name: String) -> String:
	_load()
	return str(_svgs.get(name, ""))

## Texture du dessin `name` agrandie `scale` fois (1 = taille du SVG). Mise en cache par échelle arrondie.
static func tex(name: String, scale: float = 2.0) -> Texture2D:
	var s := snappedf(clampf(scale, 0.25, 16.0), 0.25)
	var key := "%s@%s" % [name, s]
	if _cache.has(key):
		return _cache[key]
	var src := svg(name)
	if src == "":
		return null
	var img := Image.new()
	if img.load_svg_from_string(src, s) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Taille d'origine (px) du dessin, lue dans width/height du SVG.
static func base_size(name: String) -> Vector2:
	var t := tex(name, 1.0)
	return t.get_size() if t != null else Vector2.ZERO
