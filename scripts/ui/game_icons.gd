class_name GameIcons
extends RefCounted
## Jeu d'icônes dessinées au trait (SVG 24×24), rastérisées à la demande dans la couleur et la taille voulues :
## elles remplacent les emojis dans les écrans « plein cadre » (GameScreen). Nettes sur tous les écrans, aucune image à livrer.

const PATHS := {
	"dice": '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1.1" fill="{c}"/><circle cx="12" cy="12" r="1.1" fill="{c}"/><circle cx="15" cy="15" r="1.1" fill="{c}"/><circle cx="15" cy="9" r="1.1" fill="{c}"/><circle cx="9" cy="15" r="1.1" fill="{c}"/>',
	"trophy": '<path d="M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M12 14v4M8 20h8"/>',
	"sunrise": '<path d="M5 17a7 7 0 0 1 14 0M12 4v3M4.5 9.5l2 1.5M19.5 9.5l-2 1.5M3 20h18"/>',
	"calendar": '<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>',
	"flame": '<path d="M12 3c1 3.5 5 5.5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 .3 1.2 1 2 2 2 0-2-.5-5 1-8z"/>',
	"chat": '<path d="M4 5h16v11H9l-5 4z"/>',
	"user": '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20c.8-4 3.8-6 7.5-6s6.7 2 7.5 6"/>',
	"help": '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.4a2.5 2.5 0 1 1 3.4 2.3c-.7.3-1 .8-1 1.5M12 16.8v.2"/>',
	"bars": '<path d="M4 18V8M10 18V4M16 18v-7M22 18H2"/>',
	"medal": '<circle cx="12" cy="9" r="5"/><path d="M8.5 13.5 7 21l5-2.5 5 2.5-1.5-7.5"/>',
	"scroll": '<path d="M6 3h9l4 4v14H6z"/><path d="M9 11h7M9 15h7"/>',
	"friends": '<circle cx="9" cy="8" r="3.2"/><circle cx="17" cy="9" r="2.6"/><path d="M3 20c.6-3.4 3-5 6-5s5.4 1.6 6 5M16 14.5c2.6 0 4.4 1.3 5 4"/>',
	"swords": '<path d="M5 4l9 9M19 4l-9 9M4 20l3-1M20 20l-3-1M7 17l-2 2M17 17l2 2M3.5 3.5l3 .5M20.5 3.5l-3 .5"/>',
	"chevron": '<path d="M9 6l6 6-6 6"/>',
	"chevrons": '<path d="M6 6l6 6-6 6M13 6l6 6-6 6"/>',
	"back": '<path d="M19 12H5M11 6l-6 6 6 6"/>',
	"hourglass": '<path d="M6 3h12M6 21h12M7 3c0 5 5 6 5 9s-5 4-5 9M17 3c0 5-5 6-5 9s5 4 5 9"/>',
	"star": '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
	"stop": '<rect x="6" y="6" width="12" height="12" rx="1.5"/>',
	"save": '<path d="M5 4h11l3 3v13H5z"/><path d="M8 4v5h7V4M8 20v-6h8v6"/>',
	"tools": '<path d="M15 4a4.5 4.5 0 0 0-4 6L4 17l3 3 7-7a4.5 4.5 0 0 0 6-4l-3 3-3-1-1-3z"/>',
	"unlock": '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 7-2.5"/>',
	"lock": '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
	"scale": '<path d="M12 4v16M6 20h12M4 8h16M4 8l-2 6a3 3 0 0 0 4 0zM20 8l-2 6a3 3 0 0 0 4 0z"/>',
	"forbidden": '<circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/>',
	"repeat": '<path d="M4 12a8 8 0 0 1 13.5-5.8L20 8.5M20 4v4.5h-4.5M20 12a8 8 0 0 1-13.5 5.8L4 15.5M4 20v-4.5h4.5"/>',
	"target": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="0.9" fill="{c}"/>',
	"warn": '<path d="M12 3l10 17H2z"/><path d="M12 10v5M12 17.5v.1"/>',
	"gate": '<path d="M3 20V9l5-4 4 3 5-3 4 3v12z"/><path d="M9 20v-6a3 3 0 0 1 6 0v6"/>',
	"close": '<path d="M6 6l12 12M18 6L6 18"/>',
	"check": '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
	"crown": '<path d="M3 18L2 7l5 4 5-7 5 7 5-4-1 11z"/><path d="M3 21h18"/>',
}

static var _cache: Dictionary = {}

static func has(name: String) -> bool:
	return PATHS.has(name)

## SVG complet de l'icône `name` (viewBox 24, trait de la couleur `c`).
static func svg(name: String, c: Color, stroke: float = 1.7) -> String:
	var hex := "#" + c.to_html(false)
	var body := str(PATHS.get(name, "")).replace("{c}", hex)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [hex, str(stroke), body]

## Texture carrée de `px` pixels (mise en cache par nom, taille et couleur). null si l'icône n'existe pas.
static func tex(name: String, px: int, c: Color = Color("e8b45c"), stroke: float = 1.7) -> Texture2D:
	var key := "%s|%d|%s|%s" % [name, px, c.to_html(false), str(stroke)]
	if _cache.has(key):
		return _cache[key]
	if not PATHS.has(name):
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg(name, c, stroke), float(px) / 24.0) != OK:
		return null
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## TextureRect prêt à poser dans une mise en page.
static func rect(name: String, px: int, c: Color = Color("e8b45c"), stroke: float = 1.7) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name, px, c, stroke)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return r
