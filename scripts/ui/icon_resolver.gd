class_name IconResolver
extends RefCounted
## Résout une icône "@icon:xxx" en texture (planche d'objets / de monstres / vignette).

const MONSTER_SHEET := "res://assets/sheets/monsters_sheet.webp"
const ITEM_SHEET := "res://assets/sheets/items_sheet.webp"
static var _cache: Dictionary = {}

static func portrait_path(c: Dictionary, cfg: Dictionary) -> String:
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
	if legacy.has(id):
		tex = _cell(ITEM_SHEET, int(legacy[id]), 8, 128)
	elif remake.has(id):
		tex = _cell(MONSTER_SHEET, int(remake[id]), 30, 220)
	elif id.begins_with("spr_") and id.substr(4).is_valid_int():
		tex = _cell(ITEM_SHEET, int(id.substr(4)), 8, 128)
	elif ResourceLoader.exists("res://assets/icons/%s.webp" % id):
		tex = load("res://assets/icons/%s.webp" % id)
	_cache[icon] = tex
	return tex

static func _cell(sheet: String, index: int, cols: int, cell: int) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(sheet)
	at.region = Rect2((index % cols) * cell, (index / cols) * cell, cell, cell)
	return at
