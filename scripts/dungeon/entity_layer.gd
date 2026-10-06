class_name EntityLayer
extends Node3D
## Monstres, objets et décors muraux du niveau, affichés en sprites (billboards) posés au sol,
## comme dans le JS (updateMonsters / buildPlacedDecor). Pour l'instant statiques et sans combat.

const MONSTER_SHEET := "res://assets/sheets/monsters_sheet.webp"
const MONSTER_COLS := 30
const ITEM_SHEET := "res://assets/sheets/items_sheet.webp"
const ITEM_COLS := 8
const ITEM_ROWS := 23
const NEW_MONSTER_IDS := ["mon_troll", "mon_gargoyle", "mon_werewolf", "mon_naga", "mon_mudgolem", "mon_cultist", "mon_cavegoblin"]
const MON_HEIGHTS := [
	["rat|bat", 0.8], ["snake|crab|mushroom|centipede", 0.9], ["slime|imp", 1.0],
	["goblin|gnoll|harpy|mimic", 1.2], ["spider", 1.1],
	["skeleton|zombie|wolf|ghost|lizardman|gargoyle|darkpanther|wraith", 1.4],
	["orc|mummy|beholder", 1.55], ["drake", 1.7], ["elemental", 1.6],
	["minotaur", 1.9], ["ogre", 2.1], ["golem", 1.75],
]
const WALL_SIDES := {
	"N": {"d": Vector2i(0, -1)}, "S": {"d": Vector2i(0, 1)},
	"E": {"d": Vector2i(1, 0)}, "O": {"d": Vector2i(-1, 0)},
}

static var _mats: Dictionary = {}

var monsters: Dictionary = {}   # Vector2i -> Array[{node, def}]
var items: Dictionary = {}      # Vector2i -> Array[{node, def}]
var merchant_node: MeshInstance3D = null
var fountains: Dictionary = {}  # id -> Fountain3D
## Renvoie true si la fontaine `id` est utilisable (délai de recharge écoulé). Fournie par main.gd.
var fountain_ready: Callable = Callable()
var _poll := 0.0
const FOUNTAIN_SCALE := 0.8
const FOUNTAIN_OFFSET := 1.0    # décalage en diagonale : le joueur (au centre de la case) ne se retrouve pas dans le bassin

func populate(level: Dictionary, grid: DungeonGrid = null, sliced: bool = false) -> void:
	if bool(level.get("outdoor", false)):
		if level.get("blacksmith") is Dictionary:
			add_npc("@icon:blacksmith", int(level.blacksmith.x), int(level.blacksmith.y))
		if level.get("talentMaster") is Dictionary:
			add_npc("@icon:talentmaster", int(level.talentMaster.x), int(level.talentMaster.y))
	for m in level.get("monsters", []):
		if sliced:
			await Loader.slice()
		var n := _make_sprite(str(m.get("icon", "")), bool(m.get("isBoss", false)), false)
		if n == null:
			continue
		var p := Vector2i(int(m.x), int(m.y))
		_place_on_floor(n, p, str(m.get("icon", "")))
		n.visible = not bool(m.get("startHidden", false))
		add_child(n)
		_register(monsters, p, n, m)
	for it in level.get("items", []):
		if sliced:
			await Loader.slice()
		var type := str(it.get("type", ""))
		if type == "trap":
			var dec := TrapDecals.make_mesh(str(it.get("trapKind", "spikes")))
			dec.position = Vector3(int(it.x) * LevelBuilder.CELL, 0.015, int(it.y) * LevelBuilder.CELL)
			dec.name = "Trap_" + str(it.id)
			dec.visible = not bool(it.get("startHidden", false))
			add_child(dec)
			_register(items, Vector2i(int(it.x), int(it.y)), dec, it)
			continue
		if type == "fountain":
			var f := Fountain3D.new()
			var nd: Vector2i = Vector2i.ZERO
			if grid != null and not bool(level.get("outdoor", false)):
				nd = LevelBuilder.fountain_niche_dir(grid, int(it.x), int(it.y), str(it.id))
			f.name = "Fountain_" + str(it.id)
			f.scale = Vector3.ONE * FOUNTAIN_SCALE
			var hsh := absi(str(it.id).hash())
			var sx := 1.0 if (hsh & 1) == 0 else -1.0
			var sz := 1.0 if (hsh & 2) == 0 else -1.0
			f.position = Vector3(int(it.x) * LevelBuilder.CELL + sx * FOUNTAIN_OFFSET, 0.0, int(it.y) * LevelBuilder.CELL + sz * FOUNTAIN_OFFSET)
			f.rotation.y = float(hsh % 8) * PI / 4.0
			if nd != Vector2i.ZERO:     # logée dans un décroché du mur, face au couloir
				var pose := LevelBuilder.fountain_niche_pose(int(it.x), int(it.y), nd)
				f.position = pose.pos
				f.rotation.y = pose.yaw
			f.visible = not bool(it.get("startHidden", false))
			add_child(f)
			fountains[str(it.id)] = f
			_register(items, Vector2i(int(it.x), int(it.y)), f, it)
			continue
		var n := _make_sprite(str(it.get("icon", "")), false, true)
		if n == null:
			continue
		var p := Vector2i(int(it.x), int(it.y))
		if type == "decor" and it.get("wall", "") != "":
			_place_on_wall(n, p, str(it.wall))
		else:
			_place_on_floor(n, p, str(it.get("icon", "")), true)
		n.visible = not bool(it.get("startHidden", false))
		add_child(n)
		if type != "decor" or str(it.get("wall", "")) == "":
			_register(items, p, n, it)

## Met à jour l'eau des fontaines (active / tarie) ; `instant` : sans transition (chargement du niveau).
func refresh_fountains(instant: bool = false) -> void:
	if not fountain_ready.is_valid():
		return
	for id in fountains.keys():
		var f = fountains[id]
		if not is_instance_valid(f):
			continue
		var on: bool = fountain_ready.call(id)
		if instant or f.active != on:
			f.set_active(on, instant)

func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0 and not fountains.is_empty():
		_poll = 1.0
		refresh_fountains()

## PNJ fixe (forgeron, maître des talents) : grand sprite posé au sol.
func add_npc(icon: String, x: int, y: int) -> void:
	var n := _make_sprite(icon, true, false)
	if n == null:
		return
	_place_on_floor(n, Vector2i(x, y), icon)
	add_child(n)

## Marchand itinérant (sprite unique, déplaçable). `big` : grand format des PNJ du village.
func add_merchant(x: int, y: int, big: bool = false) -> void:
	if merchant_node != null:
		merchant_node.queue_free()
	var icon := "@icon:merchant" if big else "@icon:merchant_dungeon"   # le village garde son marchand d'origine
	var n := _make_sprite(icon, big, false, 1.0 if big else 1.2)
	if n == null:
		return
	_place_on_floor(n, Vector2i(x, y), icon)
	add_child(n)
	merchant_node = n

func move_merchant(x: int, y: int) -> void:
	if merchant_node != null:
		_slide(merchant_node, Vector2i(x, y))

## Déplace le sprite d'un monstre vers la case (x, y) avec un court glissement.
func move_monster(id: String, x: int, y: int, instant: bool = false) -> void:
	for p in monsters.keys():
		var list: Array = monsters[p]
		for i in list.size():
			if str(list[i].def.id) == id:
				var e: Dictionary = list[i]
				list.remove_at(i)
				var np := Vector2i(x, y)
				if not monsters.has(np):
					monsters[np] = []
				monsters[np].append(e)
				_slide(e.node, np, instant)
				return

func _slide(n: Node3D, p: Vector2i, instant: bool = false) -> void:
	var target := Vector3(p.x * LevelBuilder.CELL, n.position.y, p.y * LevelBuilder.CELL)
	if instant:
		n.position = target
		return
	create_tween().tween_property(n, "position", target, 0.4).set_trans(Tween.TRANS_SINE)

func _register(dict: Dictionary, p: Vector2i, node: Node3D, def: Dictionary) -> void:
	if not dict.has(p):
		dict[p] = []
	dict[p].append({"node": node, "def": def})

func monster_at(x: int, y: int) -> Dictionary:
	var list: Array = monsters.get(Vector2i(x, y), [])
	return list[0].def if list.size() > 0 else {}

## Ramasse (retire) les objets de la case ; renvoie leurs définitions.
func take_items_at(x: int, y: int) -> Array:
	var out: Array = []
	var p := Vector2i(x, y)
	for e in items.get(p, []):
		e.node.queue_free()
		out.append(e.def)
	items.erase(p)
	return out

## Révèle (ou cache) un objet / un monstre « caché » (startHidden) : interrupteur, butin…
func set_item_visible(id: String, on: bool) -> void:
	for p in items.keys():
		for e in items[p]:
			if str(e.def.id) == id and is_instance_valid(e.node):
				e.node.visible = on

func set_monster_visible(id: String, on: bool) -> void:
	for p in monsters.keys():
		for e in monsters[p]:
			if str(e.def.id) == id and is_instance_valid(e.node):
				e.node.visible = on

func remove_monster(id: String) -> void:
	for p in monsters.keys():
		var keep: Array = []
		for e in monsters[p]:
			if str(e.def.id) == id:
				e.node.queue_free()
			else:
				keep.append(e)
		monsters[p] = keep

func remove_item(id: String) -> void:
	for p in items.keys():
		var keep: Array = []
		for e in items[p]:
			if str(e.def.id) == id:
				e.node.queue_free()
			else:
				keep.append(e)
		items[p] = keep

# ---------------------------------------------------------------- sprites

func _icon_id(icon: String) -> String:
	return icon.substr(6) if icon.begins_with("@icon:") else icon

func _entity_height(icon: String, is_boss: bool, is_item: bool) -> float:
	var id := _icon_id(icon)
	var consts: Dictionary = Data.constants
	if is_boss:
		var bk := id.trim_prefix("boss_")
		var bh: Dictionary = consts.get("BOSS_HEIGHTS", {})
		if bh.has(bk):
			return float(bh[bk])
	var kind := id.trim_prefix("mon_").trim_prefix("boss_")
	for row in MON_HEIGHTS:
		var re := RegEx.create_from_string(row[0])
		if re.search(kind) != null:
			return float(row[1])
	if is_item:
		var ov: Dictionary = consts.get("ITEM_HEIGHT_OVERRIDE", {})
		return float(ov.get(id, 1.0))
	return 2.2 if is_boss else 1.5

func _make_sprite(icon: String, is_boss: bool, is_item: bool, mult: float = 1.0) -> MeshInstance3D:
	var mat := _material_for(icon, is_boss, is_item)
	if mat == null:
		return null
	var h := _entity_height(icon, is_boss, is_item) * 1.3 * mult
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(h, h)
	mi.mesh = q
	mi.material_override = mat
	mi.set_meta("h", h)
	return mi

## Décalage vertical d'ancrage (fraction de la hauteur) propre à certaines icônes.
func anchor_offset(icon: String) -> float:
	var anchors: Dictionary = Data.constants.get("ANCHOR_OFFSET", {})
	return float(anchors.get(_icon_id(icon), 0.0))

func _place_on_floor(n: MeshInstance3D, p: Vector2i, icon: String, is_item: bool = false) -> void:
	var h: float = n.get_meta("h")
	var anchors: Dictionary = Data.constants.get("ANCHOR_OFFSET", {})
	var off := float(anchors.get(_icon_id(icon), 0.0)) * h
	n.position = Vector3(p.x * LevelBuilder.CELL, h * 0.5 + 0.02 + off, p.y * LevelBuilder.CELL)

func _place_on_wall(n: MeshInstance3D, p: Vector2i, side: String) -> void:
	var d: Vector2i = WALL_SIDES.get(side, WALL_SIDES["N"])["d"]
	(n.mesh as QuadMesh).size = Vector2(0.62, 0.62)
	n.position = Vector3(p.x * LevelBuilder.CELL + d.x * LevelBuilder.CELL * 0.47, LevelBuilder.CELL * 0.55,
			p.y * LevelBuilder.CELL + d.y * LevelBuilder.CELL * 0.47)

## Matériau (sprite face caméra) pour une icône "@icon:xxx" : planche de monstres, planche d'objets
## ou vignette individuelle (boss). Renvoie null si aucune image n'est connue.
func _material_for(icon: String, is_boss: bool, is_item: bool) -> StandardMaterial3D:
	var id := _icon_id(icon)
	var key := ("B|" if is_boss else "M|") + id
	if _mats.has(key):
		return _mats[key]
	var mat: StandardMaterial3D = null
	var consts: Dictionary = Data.constants
	var remake: Dictionary = consts.get("REMAKE_MAP", {})
	var legacy: Dictionary = consts.get("ITEM_SPRITE_LEGACY", {})
	var single := "res://assets/icons/%s.webp" % id
	if not ResourceLoader.exists(single):
		single = "res://assets/icons/%s.png" % id
	var hd := "res://assets/monsters/%s.webp" % id
	if NEW_MONSTER_IDS.has(id):
		mat = _monster_cell(NEW_MONSTER_IDS.find(id))
	elif remake.has(id) and not is_boss:
		mat = _monster_cell(int(remake[id]))
	elif ResourceLoader.exists(hd):
		mat = _base_material(load(hd))      # vignette individuelle agrandie ×2 (Lanczos + netteté)
	elif legacy.has(id):
		mat = _sheet_material(ITEM_SHEET, int(legacy[id]), ITEM_COLS, ITEM_ROWS)
	elif id.begins_with("spr_") and id.substr(4).is_valid_int():
		mat = _sheet_material(ITEM_SHEET, int(id.substr(4)), ITEM_COLS, ITEM_ROWS)
	elif ResourceLoader.exists(single):
		mat = _base_material(load(single))
	_mats[key] = mat
	return mat

## Cellule de la planche des monstres, pré-découpée et agrandie ×2 (mipmaps propres à chaque sprite, sans bavure entre voisins).
static func _monster_cell(index: int) -> StandardMaterial3D:
	var path := "res://assets/monsters/m%02d.webp" % index
	if ResourceLoader.exists(path):
		return _base_material(load(path))
	return _sheet_material(MONSTER_SHEET, index, MONSTER_COLS, 1)

static func _base_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func _sheet_material(path: String, index: int, cols: int, rows: int) -> StandardMaterial3D:
	var m := _base_material(load(path))
	var c := index % cols
	var r := index / cols
	m.uv1_scale = Vector3(1.0 / cols, 1.0 / rows, 1.0)
	m.uv1_offset = Vector3(float(c) / cols, float(r) / rows, 0.0)
	return m
