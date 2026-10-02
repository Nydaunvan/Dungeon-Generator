class_name IconResolver
extends RefCounted
## Résout une icône "@icon:xxx" en texture (planche d'objets / de monstres / vignette).

const MONSTER_SHEET := "res://assets/sheets/monsters_sheet.webp"
const ITEM_SHEET := "res://assets/sheets/items_sheet.webp"
## Icônes « Monstres (planche) » : indices 0 à 6 de la planche de monstres (comme `registerMonsterSprites` de l'original).
const NEW_MONSTER_IDS := ["mon_troll", "mon_gargoyle", "mon_werewolf", "mon_naga", "mon_mudgolem", "mon_cultist", "mon_cavegoblin"]
static var _cache: Dictionary = {}
static var _data_loader: DataUriLoader = null

## Charge un portrait « data:image/...;base64,... » (configuration HTML importée) via `load()` : le chemin renvoyé par
## `portrait_path` reste donc utilisable partout où l'on fait `load(chemin)`.
class DataUriLoader extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray()
	func _recognize_path(path: String, _type: StringName) -> bool:
		return path.contains("data:image/")
	func _handles_type(type: StringName) -> bool:
		return type == &"Texture2D" or type == &"ImageTexture" or type == &""
	func _get_resource_type(path: String) -> String:
		return "ImageTexture" if path.contains("data:image/") else ""
	func _load(path: String, _original: String, _sub: bool, _mode: int) -> Variant:
		return IconResolver.texture_from_data_uri(path.substr(path.find("data:image/")))

static func is_data_uri(s: String) -> bool:
	return s.begins_with("data:image/") and s.contains(";base64,")

## Décode une URI de données image en texture (PNG, WebP ou JPEG) ; null si invalide.
static func texture_from_data_uri(uri: String) -> Texture2D:
	var i := uri.find(";base64,")
	if i < 0:
		return null
	var raw := Marshalls.base64_to_raw(uri.substr(i + 8))
	var img := Image.new()
	var e := img.load_png_from_buffer(raw)
	if e != OK:
		e = img.load_webp_from_buffer(raw)
	if e != OK:
		e = img.load_jpg_from_buffer(raw)
	if e != OK:
		return null
	return ImageTexture.create_from_image(img)

static func portrait_path(c: Dictionary, cfg: Dictionary) -> String:
	var own := str(c.get("portrait", ""))
	if is_data_uri(own):
		if _data_loader == null:
			_data_loader = DataUriLoader.new()
			ResourceLoader.add_resource_format_loader(_data_loader)
		return own
	if own.begins_with("res://") and ResourceLoader.exists(own):
		return own
	var cls := Characters.class_def(cfg, str(c.get("classId", "")))
	var base := str(cls.get("evolvesFrom", cls.get("name", "guerrier")))
	base = base.to_lower().replace("ê", "e").replace("é", "e").replace("è", "e")
	var path := "res://assets/portraits/%s_0.webp" % base
	return path if ResourceLoader.exists(path) else ""

static func texture(icon: String) -> Texture2D:
	if _cache.has(icon):
		return _cache[icon]
	var id := icon.substr(6) if icon.begins_with("@icon:") else icon
	var consts: Dictionary = Data.constants
	var tex: Texture2D = null
	var legacy: Dictionary = consts.get("ITEM_SPRITE_LEGACY", {})
	var remake: Dictionary = consts.get("REMAKE_MAP", {})
	if NEW_MONSTER_IDS.has(id):
		tex = _cell(MONSTER_SHEET, NEW_MONSTER_IDS.find(id), 30, 220)
	elif legacy.has(id):
		tex = _cell(ITEM_SHEET, int(legacy[id]), 8, 128)
	elif remake.has(id):
		tex = _cell(MONSTER_SHEET, int(remake[id]), 30, 220)
	elif id.begins_with("spr_") and id.substr(4).is_valid_int():
		tex = _cell(ITEM_SHEET, int(id.substr(4)), 8, 128)
	elif ResourceLoader.exists("res://assets/icons/%s.webp" % id):
		tex = load("res://assets/icons/%s.webp" % id)
	elif ResourceLoader.exists("res://assets/icons/%s.png" % id):
		tex = load("res://assets/icons/%s.png" % id)
	_cache[icon] = tex
	return tex

static func _cell(sheet: String, index: int, cols: int, cell: int) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(sheet)
	at.region = Rect2((index % cols) * cell, (index / cols) * cell, cell, cell)
	return at
