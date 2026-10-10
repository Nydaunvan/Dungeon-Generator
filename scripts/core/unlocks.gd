class_name Unlocks
extends RefCounted
## Ce que le compte a débloqué et que le jeu utilise HORS LIGNE : badges possédés (copie du serveur, gardée dans user://unlocks.json) et
## apparence des héros choisie. Les règles du Défi de la semaine réussies deviennent des modificateurs d'expédition en partie libre ;
## les apparences changent seulement la couleur de l'anneau des portraits (aucun effet sur la partie).

const PATH := "user://unlocks.json"

static var _loaded := false
static var _owned: Dictionary = {}
static var _uid := ""
static var _skin := ""

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		_uid = str(d.get("uid", ""))
		_skin = str(d.get("skin", ""))
		for id in d.get("owned", []):
			_owned[str(id)] = true

static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"uid": _uid, "skin": _skin, "owned": _owned.keys()}))

## Le cache appartient au dernier compte connecté : un autre compte ne profite pas de ses déblocages.
static func _mine() -> bool:
	_load()
	return not Cloud.is_signed_in() or _uid == "" or _uid == Cloud.user_id()

static func has_badge(id: String) -> bool:
	_load()
	return _mine() and _owned.has(id)

## Remplace la liste des badges possédés (réponse du serveur).
static func set_owned(ids: Array) -> void:
	_load()
	var uid := Cloud.user_id() if Cloud.is_signed_in() else _uid
	if uid != _uid:
		_skin = ""
	_uid = uid
	_owned = {}
	for id in ids:
		_owned[str(id)] = true
	if _skin != "" and not skin_available(_skin):
		_skin = ""
	_save()

## Relit les badges du compte connecté.
static func refresh() -> void:
	if not Cloud.is_signed_in():
		return
	var r: Dictionary = await RankedRun.my_badges()
	if r.ok and r.data is Array:
		set_owned((r.data as Array).map(func(b): return str(b.get("badge_id", ""))))

## Modificateurs d'expédition réservés au Défi de la semaine que le joueur a débloqués (règle réussie en entier).
static func unlocked_modifiers() -> Array:
	return DungeonGenerator.all_modifiers().filter(func(m): return bool(m.get("weeklyOnly", false)) and str(m.get("unlockBadge", "")) != "" and has_badge(str(m.unlockBadge)))

# ------------------------------------------------------------------ apparence des héros

static func skins() -> Array:
	return Data.constants.get("HERO_SKINS", [])

static func skin_def(id: String) -> Dictionary:
	for s in skins():
		if str(s.id) == id:
			return s
	return {}

static func skin_available(id: String) -> bool:
	var s := skin_def(id)
	return not s.is_empty() and has_badge(str(s.get("unlockBadge", "")))

static func skin_id() -> String:
	_load()
	return _skin if skin_available(_skin) else ""

static func set_skin(id: String) -> void:
	_load()
	_skin = id if id == "" or skin_available(id) else ""
	_save()

## Couleur de l'anneau des portraits (alpha 0 = aucune apparence choisie).
static func skin_color() -> Color:
	var s := skin_def(skin_id())
	return Color(str(s.color)) if not s.is_empty() else Color(0, 0, 0, 0)
