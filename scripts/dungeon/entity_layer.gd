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
var merchant_node: Node3D = null
var fountains: Dictionary = {}  # id -> Fountain3D
var chests: Dictionary = {}     # id -> Chest3D
## Renvoie true si la fontaine `id` est utilisable (délai de recharge écoulé). Fournie par main.gd.
var fountain_ready: Callable = Callable()
var combat_info: Callable = Callable()   ## () -> {id, gauge 0..1} du monstre engagé au combat, ou {} (animations de combat)
var _poll := 0.0
const FOUNTAIN_SCALE := 0.8
const FOUNTAIN_OFFSET := 1.0    # décalage en diagonale : le joueur (au centre de la case) ne se retrouve pas dans le bassin

var _grid: DungeonGrid = null
var _level: Dictionary = {}

func populate(level: Dictionary, grid: DungeonGrid = null, sliced: bool = false) -> void:
	_grid = grid
	_level = level
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
		n.set_meta("by", n.position.y)                       # animations : hauteur de repos, phase propre, amplitude (boss plus lents)
		n.set_meta("ph", randf() * TAU)
		n.set_meta("boss", bool(m.get("isBoss", false)))
		n.visible = not bool(m.get("startHidden", false))
		add_child(n)
		_register(monsters, p, n, m)
	for it in level.get("items", []):
		if sliced:
			await Loader.slice()
		var type := str(it.get("type", ""))
		if type == "trap":
			var tkind := str(TrapRules.kind_of(it).id)
			if tkind == "dart" and (grid == null or bool(level.get("outdoor", false)) or LevelBuilder.dart_wall_dir(grid, level, int(it.x), int(it.y), str(it.id)) == Vector2i.ZERO):
				it["trapKind"] = "spikes"      # pas de mur où fixer le mécanisme (intersection, plein air) : ce piège devient des pointes au sol
				tkind = "spikes"
			var wd := Vector2i.ZERO         # fléchettes : mécanisme fixé au mur voisin de la dalle (à défaut de mur, simple décalque au sol)
			if tkind == "dart" and grid != null and not bool(level.get("outdoor", false)):
				wd = LevelBuilder.dart_wall_dir(grid, level, int(it.x), int(it.y), str(it.id))
			var dec: Node3D
			if tkind == "rune":      # cercle de runes gravé dans le sol (au niveau du sol, pas de décalque plat)
				dec = TrapRune.make()
				dec.position = Vector3(int(it.x) * LevelBuilder.CELL, 0.0, int(it.y) * LevelBuilder.CELL)
			elif wd != Vector2i.ZERO:
				dec = TrapDart.make(LevelBuilder.dart_height(int(it.x), int(it.y)))
				dec.position = Vector3((int(it.x) + wd.x * 0.5) * LevelBuilder.CELL, LevelBuilder.dart_height(int(it.x), int(it.y)), (int(it.y) + wd.y * 0.5) * LevelBuilder.CELL)
				dec.rotation.y = TrapDart.yaw_for(wd)
			elif tkind == "pit":      # fosse : pierre du thème du niveau
				dec = TrapPit.make(str(level.get("theme", "stone")))
				dec.position = Vector3(int(it.x) * LevelBuilder.CELL, 0.0, int(it.y) * LevelBuilder.CELL)
			else:
				dec = TrapDecals.make_mesh(tkind)
				dec.position = Vector3(int(it.x) * LevelBuilder.CELL, 0.0 if tkind == "pit" else 0.015, int(it.y) * LevelBuilder.CELL)
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
		if type == "chest":
			var ch := Chest3D.new()
			ch.name = "Chest_" + str(it.id)
			var wd: Vector2i = WALL_SIDES.get(str(it.get("wall", "N")), WALL_SIDES["N"])["d"]
			# posé contre son mur, face au centre de la case : il ne gêne jamais le passage
			ch.position = Vector3((int(it.x) + wd.x * 0.5) * LevelBuilder.CELL - wd.x * 0.55, 0.0, (int(it.y) + wd.y * 0.5) * LevelBuilder.CELL - wd.y * 0.55)
			ch.rotation.y = atan2(float(-wd.x), float(-wd.y))
			ch.visible = not bool(it.get("startHidden", false))
			add_child(ch)
			chests[str(it.id)] = ch
			_register(items, Vector2i(int(it.x), int(it.y)), ch, it)
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

## Ouvre (avec animation) ou montre ouvert (sans) le coffre `id`.
func open_chest(id: String, animate: bool = true) -> void:
	var c = chests.get(id)
	if c != null and is_instance_valid(c):
		c.set_open(true, animate)

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
	_animate_monsters(delta)

# ------------------------------------------------------------------ animations des monstres (option « Animations des monstres »)
# Purement visuelles : aucune règle du jeu n'en dépend. Respiration + flottement au repos (coupés par « Mouvements réduits »),
# réactions courtes en combat : touché (écrasement, recul, éclair rouge), attaque (bond vers l'avant), étourdi (tremblement).

var _clock := 0.0
var _react: Dictionary = {}          # Node3D -> {kind, t, dur}
var _anim_dirty := false             # des sprites portent une déformation à remettre à zéro si l'option est coupée

const REACT_DUR := {"hit": 0.32, "attack": 0.42, "stun": 0.6}

## Joue une réaction courte sur le sprite du monstre `id`.
func play(id: String, kind: String) -> void:
	if not Settings.monster_anim:
		return
	for p in monsters.keys():
		for e in monsters[p]:
			if str(e.def.id) == id and is_instance_valid(e.node) and e.node.visible:
				_end_react(e.node)
				_react[e.node] = {"kind": kind, "t": 0.0, "dur": float(REACT_DUR.get(kind, 0.4))}
				if kind == "hit":
					var base: Material = e.node.material_override
					e.node.set_meta("mat0", base)
					var flash: StandardMaterial3D = base.duplicate()
					flash.albedo_color = Color(1.0, 0.35, 0.35)
					e.node.material_override = flash
				return

func _end_react(n: Node3D) -> void:
	if n.has_meta("mat0"):
		(n as MeshInstance3D).material_override = n.get_meta("mat0")
		n.remove_meta("mat0")
	_react.erase(n)

func _reset_pose(n: Node3D) -> void:
	if not n.has_meta("by"):
		return
	var off: Vector3 = n.get_meta("off", Vector3.ZERO)
	n.position.x -= off.x
	n.position.z -= off.z
	n.set_meta("off", Vector3.ZERO)
	n.scale = Vector3(float(n.get_meta("mirror", 1.0)), 1.0, 1.0)
	n.position.y = float(n.get_meta("by"))

func _animate_monsters(delta: float) -> void:
	if not Settings.monster_anim:
		if _anim_dirty:
			_anim_dirty = false
			for k in _react.keys():
				if is_instance_valid(k):
					_end_react(k)
			for p in monsters.keys():
				for e in monsters[p]:
					if is_instance_valid(e.node):
						_reset_pose(e.node)
		return
	_clock += delta
	var cb := _cam_basis()
	var idle: bool = not Settings.reduced_motion
	var ci: Dictionary = combat_info.call() if combat_info.is_valid() else {}
	var cid := str(ci.get("id", ""))
	var charge := clampf(float(ci.get("gauge", 0.0)), 0.0, 1.0)
	for p in monsters.keys():
		for e in monsters[p]:
			if not is_instance_valid(e.node):
				continue
			var n: Node3D = e.node
			if not n.visible or not n.has_meta("by"):
				continue
			_anim_dirty = true
			_pose(n, delta, cid != "" and str(e.def.id) == cid, charge, idle, cb)

func _cam_basis() -> Basis:
	var cam := get_viewport().get_camera_3d()
	return cam.global_transform.basis if cam != null else Basis.IDENTITY

## Animation des combattants de la salle de combat (CombatStage) : ce sont d'autres sprites que ceux de la carte
## (ceux-ci sont cachés pendant le combat). Appelé à chaque image par la salle ; `nodes` = sprites affichés.
func animate_stage(nodes: Array, delta: float) -> void:
	if not Settings.monster_anim:
		for n in nodes:
			if is_instance_valid(n):
				_end_react(n)
				_reset_pose(n)
		return
	var cb := _cam_basis()
	var idle: bool = not Settings.reduced_motion
	var ci: Dictionary = combat_info.call() if combat_info.is_valid() else {}
	var charge := clampf(float(ci.get("gauge", 0.0)), 0.0, 1.0)
	for n in nodes:
		if is_instance_valid(n) and n.visible and n.has_meta("by"):
			_pose(n, delta, true, charge, idle, cb)

## Réaction courte sur un sprite précis (salle de combat).
func play_node(n: Node3D, kind: String) -> void:
	if not Settings.monster_anim or not is_instance_valid(n) or not n.visible or not n.has_meta("by"):
		return
	_end_react(n)
	_react[n] = {"kind": kind, "t": 0.0, "dur": float(REACT_DUR.get(kind, 0.4))}
	if kind == "hit":
		var base: Material = (n as MeshInstance3D).material_override
		n.set_meta("mat0", base)
		var flash: StandardMaterial3D = base.duplicate()
		flash.albedo_color = Color(1.0, 0.35, 0.35)
		(n as MeshInstance3D).material_override = flash

## Mort animée d'un sprite précis (salle de combat).
func die_node(n: Node3D) -> void:
	if Settings.monster_anim and is_instance_valid(n) and n.visible and n.has_meta("by"):
		_die(n as MeshInstance3D)
	elif is_instance_valid(n):
		n.queue_free()

func _pose(n: Node3D, delta: float, fighting: bool, charge: float, idle: bool, cb: Basis) -> void:
	var ph: float = n.get_meta("ph", 0.0)
	var h: float = n.get_meta("h", 1.0)
	var sy := 1.0
	var sx := 1.0
	var dy := 0.0
	var off := Vector3.ZERO
	if idle and not fighting:
		var boss: bool = n.get_meta("boss", false)
		sy += (0.018 if boss else 0.03) * sin(_clock * (1.6 if boss else 2.1) + ph)
		dy += (0.008 if boss else 0.014) * sin(_clock * 1.3 + ph * 1.7)
	# au combat (salle de combat) : le monstre reste immobile, seule l'attaque l'avance vers l'écran
	var r: Variant = _react.get(n)
	if r != null:
		r["t"] = float(r.t) + delta
		var k: float = float(r.t) / float(r.dur)
		if k >= 1.0:
			_end_react(n)
		else:
			var env := 1.0 - k
			var arc := sin(k * PI)
			match str(r.kind):
				"hit":
					if not fighting:
						sy -= 0.16 * env
						sx += 0.12 * env
						off -= cb.z * 0.14 * env                 # recul (s'éloigne de la caméra)
					var m := (n as MeshInstance3D).material_override as StandardMaterial3D
					if m != null:
						m.albedo_color = Color(1.0, 0.35 + 0.65 * k, 0.35 + 0.65 * k)
				"attack":
					if fighting:
						off += cb.z * 0.45 * arc                 # simple avancée vers l'écran
					else:
						sy += 0.16 * arc
						sx += 0.16 * arc
						dy += 0.06 * arc
						off += cb.z * 0.28 * arc                 # bond vers la caméra
				"stun":
					if not fighting:
						off += cb.x * 0.045 * sin(_clock * 46.0) * env
						sy -= 0.03 * env
	sx *= 1.0 - (sy - 1.0) * 0.5                                  # volume à peu près conservé
	n.scale = Vector3(sx * float(n.get_meta("mirror", 1.0)), sy, 1.0)
	n.position.y = float(n.get_meta("by")) + h * 0.5 * (sy - 1.0) + dy
	var prev: Vector3 = n.get_meta("off", Vector3.ZERO)
	n.position.x += off.x - prev.x
	n.position.z += off.z - prev.z
	n.set_meta("off", off)

const VILLAGE_NPC_SCALE := 0.68                          ## taille des PNJ du village (proportionnée aux maisons)
const NPC_FEET_GAP := {"blacksmith": 0.117, "talentmaster": 0.075}   ## marge transparente sous les pieds (part de la hauteur de l'image)

## PNJ fixe (forgeron, maître des talents) : grand sprite posé au sol.
func add_npc(icon: String, x: int, y: int) -> void:
	var village := _level != null and bool(_level.get("outdoor", false))
	var n := _make_sprite(icon, true, false, VILLAGE_NPC_SCALE if village else 1.0)
	if n == null:
		return
	_place_on_floor(n, Vector2i(x, y), icon)
	if village:       # dehors, les pieds touchent l'herbe : on retire la marge transparente sous le personnage
		n.position.y -= float(NPC_FEET_GAP.get(_icon_id(icon), 0.0)) * float(n.get_meta("h"))
		var sx := int(_level.get("streetX", 5))
		var away := Vector3(1, 0, 0) if x > sx else (Vector3(-1, 0, 0) if x < sx else Vector3(0, 0, -1))
		n.position -= away * 1.4          # le PNJ se tient au bord de sa case, côté rue : le groupe s'arrête tout près (la case reste bloquante)
	add_child(n)

## Marchand itinérant (sprite unique, déplaçable). `big` : grand format des PNJ du village.
func add_merchant(x: int, y: int, big: bool = false) -> void:
	release_stall()
	if merchant_node != null:
		merchant_node.queue_free()
		merchant_node = null
	if not big and _grid != null:
		var nd := LevelBuilder.merchant_niche_dir(_grid, x, y)
		if nd != Vector2i.ZERO:
			merchant_node = _make_stall(x, y, nd)
			return
	if big and ResourceLoader.exists(Merchant3D.WIZARD_GLB):
		var sx := int(_level.get("streetX", 5))
		var away := Vector2i(1, 0) if x > sx else (Vector2i(-1, 0) if x < sx else Vector2i(0, -1))   # dos au côté opposé au chemin central
		merchant_node = _make_village_stall(x, y, away)
		return
	var icon := "@icon:merchant" if big else "@icon:merchant_dungeon"
	var n := _make_sprite(icon, big, false, 1.0 if big else 1.2)
	if n == null:
		return
	_place_on_floor(n, Vector2i(x, y), icon)
	add_child(n)
	merchant_node = n

## Étal du marchand (Merchant3D, en vraie 3D) logé dans un décroché du mur : case (x, y), mur côté `d`.
## Le repère de l'étal a son devant en +Z et son fond à ~1 u derrière l'origine : on l'avance au fond du creux, face au couloir.
func _make_stall(x: int, y: int, d: Vector2i) -> Node3D:
	var sp := LevelBuilder.merchant_niche_spec(_grid, x, y)
	var sc := LevelBuilder.merchant_stall_scale(float(sp.w))
	var st := Merchant3D.acquire()
	st.scale = Vector3.ONE * sc
	var dv := Vector3(d.x, 0, d.y)
	var c := Vector3(x * LevelBuilder.CELL, 0.0, y * LevelBuilder.CELL)
	st.position = c + dv * (LevelBuilder.CELL * 0.5 + 1.22 * sc)
	st.rotation.y = LevelBuilder._rot(d)
	st.name = "MerchantStall"
	add_child(st)
	return st

## Étal du marchand posé en plein air dans la case (x, y), le dos tourné vers `away` : même étal et même magicien qu'au donjon.
func _make_village_stall(x: int, y: int, away: Vector2i) -> Node3D:
	var st := Merchant3D.acquire()
	var sc := 0.62
	st.scale = Vector3.ONE * sc
	var dv := Vector3(away.x, 0, away.y)
	st.position = Vector3(x * LevelBuilder.CELL, 0.0, y * LevelBuilder.CELL) - dv * 0.9      # avancé vers la rue, au bord de sa case : le groupe s'arrête tout près, la case reste bloquante
	st.rotation.y = LevelBuilder._rot(away)
	st.name = "MerchantStall"
	add_child(st)
	return st

## Rend l'étal 3D à la réserve (il resservira au prochain niveau de marchand sans être reconstruit).
func release_stall() -> void:
	if merchant_node is Merchant3D:
		Merchant3D.release(merchant_node as Merchant3D)
		merchant_node = null

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
	# x et z séparément : la hauteur (y) reste libre pour les animations des monstres
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position:x", target.x, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "position:z", target.z, 0.4).set_trans(Tween.TRANS_SINE)

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

## Tache de sang au sol sous un monstre qui meurt (Forward+, option « Taches de sang ») : décalque propre à la case, sans hasard de jeu.
const MAX_BLOOD := 48
var _blood_nodes: Array = []

func add_blood(p: Vector2i) -> void:
	if not (VisualFx.is_forward() and bool(Settings.opt("fx_decals"))):
		return
	var h := absi(("blood|%d|%d|%d" % [p.x, p.y, _blood_nodes.size()]).hash())
	var d := Decal.new()
	d.size = Vector3(LevelBuilder.CELL * 0.8, 1.2, LevelBuilder.CELL * 0.8)
	d.texture_albedo = VisualFx.blood_texture(h)
	d.modulate = Color(1, 1, 1, 0.9)
	d.upper_fade = 0.5
	d.lower_fade = 0.5
	d.position = Vector3(p.x * LevelBuilder.CELL + float(h % 100) / 100.0 - 0.5, 0.3, p.y * LevelBuilder.CELL + float((h / 100) % 100) / 100.0 - 0.5)
	d.rotation.y = float(h % 628) / 100.0
	add_child(d)
	_blood_nodes.append(d)
	if _blood_nodes.size() > MAX_BLOOD:
		var old: Node = _blood_nodes.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func remove_monster(id: String, animate: bool = false) -> void:
	for p in monsters.keys():
		var keep: Array = []
		for e in monsters[p]:
			if str(e.def.id) == id:
				if animate:
					add_blood(p)
				var stage = get_parent().get("stage") if get_parent() != null else null
				if stage != null and stage.active:
					stage.die_all()             # salle de combat : les sprites affichés s'effondrent aussi
				if animate and Settings.monster_anim and is_instance_valid(e.node) and e.node.visible:
					_die(e.node)
				else:
					e.node.queue_free()
			else:
				keep.append(e)
		monsters[p] = keep

## Mort d'un monstre : il s'affaisse et s'efface (0,5 s), puis le sprite est libéré.
func _die(n: MeshInstance3D) -> void:
	_end_react(n)
	_reset_pose(n)
	var m: StandardMaterial3D = (n.material_override as StandardMaterial3D).duplicate()
	n.material_override = m
	var h: float = n.get_meta("h", 1.0)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "scale:y", 0.25, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(n, "position:y", n.position.y - h * 0.375, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(n.queue_free)

## Piège désamorcé : les pointes rentrent dans leur plaque, la vapeur cesse (le piège reste en place, inoffensif) ; les autres objets disparaissent.
func disarm_item(id: String, animate: bool = true) -> void:
	var done := false
	for p in items.keys():
		for e in items[p]:
			if str(e.def.id) == id and is_instance_valid(e.node):
				if e.node.has_meta("spikes"):
					TrapSpikes.retract(e.node, animate)
					done = true
				elif e.node.has_meta("trap_gas"):
					TrapGas.stop(e.node, animate)
					done = true
				elif e.node.has_meta("trap_dart"):
					TrapDart.retract(e.node, animate)
					done = true
				elif e.node.has_meta("trap_pit"):
					TrapPit.cover(e.node, animate)
					done = true
				elif e.node.has_meta("trap_rune"):
					TrapRune.stop(e.node, animate)
					done = true
	if not done:
		remove_item(id)

## Piège déclenché qui reste en place : salve de fléchettes tirée du mur, gerbe de flammes de la rune (il se recharge).
func fire_item(id: String) -> void:
	for p in items.keys():
		for e in items[p]:
			if str(e.def.id) != id or not is_instance_valid(e.node):
				continue
			if e.node.has_meta("trap_dart"):
				TrapDart.fire(e.node)
			elif e.node.has_meta("trap_rune"):
				TrapRune.fire(e.node)

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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF       # un sprite plat ne doit pas projeter d'ombre de carton
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
	elif id.begins_with("spr_") and id.substr(4).is_valid_int() and not ResourceLoader.exists(single):
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
